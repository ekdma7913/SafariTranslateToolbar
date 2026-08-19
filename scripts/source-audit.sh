#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
PROJECT_DIR="${ROOT_DIR}/SafariTranslateToolbar"
PROJECT_FILE="${PROJECT_DIR}/SafariTranslateToolbar.xcodeproj/project.pbxproj"
APP_INFO="${PROJECT_DIR}/SafariTranslateToolbar/Info.plist"
EXTENSION_INFO="${PROJECT_DIR}/SafariTranslateToolbar Extension/Info.plist"
EXTENSION_ENTITLEMENTS="${PROJECT_DIR}/SafariTranslateToolbar Extension/SafariTranslateToolbarExtension.entitlements"
MANIFEST="${PROJECT_DIR}/SafariTranslateToolbar Extension/Resources/manifest.json"
BACKGROUND="${PROJECT_DIR}/SafariTranslateToolbar Extension/Resources/background.js"

source "${ROOT_DIR}/Config/release.env"

fail() {
    print -u2 -- "오류: $1"
    exit 1
}

for plist in \
    "${APP_INFO}" \
    "${EXTENSION_INFO}" \
    "${EXTENSION_ENTITLEMENTS}" \
    "${ROOT_DIR}/Config/ExportOptions.plist" \
    "${PROJECT_FILE}"
do
    plutil -lint "${plist}" >/dev/null || fail "형식이 잘못된 파일: ${plist}"
done

manifest_version="$(plutil -extract version raw -o - "${MANIFEST}")"
[[ "${manifest_version}" == "${MARKETING_VERSION}" ]] || \
    fail "manifest 버전(${manifest_version})과 릴리스 버전(${MARKETING_VERSION})이 다릅니다."

permission="$(plutil -extract permissions.0 raw -o - "${MANIFEST}")"
[[ "${permission}" == "nativeMessaging" ]] || \
    fail "확장 권한은 nativeMessaging 하나만 허용됩니다."

if plutil -extract permissions.1 raw -o - "${MANIFEST}" >/dev/null 2>&1; then
    fail "manifest에 불필요한 두 번째 권한이 있습니다."
fi

for forbidden_key in host_permissions content_scripts externally_connectable; do
    if plutil -extract "${forbidden_key}" raw -o - "${MANIFEST}" >/dev/null 2>&1; then
        fail "manifest에 개인정보 접근 범위를 넓히는 ${forbidden_key} 항목이 있습니다."
    fi
done

rg -Fq "\"${APP_BUNDLE_ID}\"" "${BACKGROUND}" || \
    fail "background.js의 native messaging 앱 ID가 일치하지 않습니다."

if rg -Fq 'kAXValueAttribute' "${PROJECT_DIR}" --glob '*.swift'; then
    fail "Safari 페이지의 값이 노출될 수 있는 AXValue 읽기가 있습니다."
fi

if rg -n \
    'URLSession|NSURLConnection|NWConnection|CFNetwork|XMLHttpRequest|WebSocket|fetch\(|FileManager|NSPasteboard|UIPasteboard' \
    "${PROJECT_DIR}" \
    --glob '*.swift' \
    --glob '*.js'
then
    fail "네트워크, 파일 또는 클립보드 접근 코드가 추가되었습니다."
fi

registered_scheme="$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw -o - "${APP_INFO}")"
[[ "${registered_scheme}" == "${URL_SCHEME}" ]] || \
    fail "앱 URL scheme이 릴리스 설정과 다릅니다."

rg -Fq "PRODUCT_BUNDLE_IDENTIFIER = \"${APP_BUNDLE_ID}\"" "${PROJECT_FILE}" || \
    fail "앱 bundle ID가 프로젝트에 고정되지 않았습니다."
rg -Fq "PRODUCT_BUNDLE_IDENTIFIER = \"${EXTENSION_BUNDLE_ID}\"" "${PROJECT_FILE}" || \
    fail "확장 bundle ID가 프로젝트에 고정되지 않았습니다."
rg -Fq "DEVELOPMENT_TEAM = ${TEAM_ID}" "${PROJECT_FILE}" || \
    fail "Developer Team이 프로젝트에 설정되지 않았습니다."

extension_sandbox="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "${EXTENSION_ENTITLEMENTS}")"
[[ "${extension_sandbox}" == "true" ]] || fail "확장 App Sandbox가 꺼져 있습니다."

if rg -n \
    'local\.codex|local\.yu|codexsafaritranslate|Created by|/Users/|com\.apple\.security\.network|ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES' \
    "${ROOT_DIR}" \
    --glob '!build/**' \
    --glob '!dist/**' \
    --glob '!scripts/source-audit.sh'
then
    fail "이전 식별자, 개인 경로 또는 네트워크 권한 흔적이 남아 있습니다."
fi

for script in "${SCRIPT_DIR}"/*.sh; do
    zsh -n "${script}" || fail "셸 문법 오류: ${script}"
done

print -- "소스/권한/식별자 점검 통과"
