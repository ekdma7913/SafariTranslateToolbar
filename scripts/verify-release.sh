#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
source "${ROOT_DIR}/Config/release.env"

app_path=""
dmg_path=""
require_notarization=false

fail() {
    print -u2 -- "오류: $1"
    exit 1
}

while (( $# > 0 )); do
    case "$1" in
        --app)
            (( $# >= 2 )) || fail "--app 뒤에 경로가 필요합니다."
            app_path="$2"
            shift 2
            ;;
        --dmg)
            (( $# >= 2 )) || fail "--dmg 뒤에 경로가 필요합니다."
            dmg_path="$2"
            shift 2
            ;;
        --notarized)
            require_notarization=true
            shift
            ;;
        *)
            fail "알 수 없는 인자: $1"
            ;;
    esac
done

[[ -n "${app_path}" || -n "${dmg_path}" ]] || \
    fail "--app 또는 --dmg 중 하나가 필요합니다."

verify_signed_code() {
    local code_path="$1"
    local expected_identifier="$2"
    local metadata

    codesign --verify --strict --verbose=2 "${code_path}"
    metadata="$(codesign -d --verbose=4 "${code_path}" 2>&1)"

    [[ "${metadata}" == *"Identifier=${expected_identifier}"* ]] || \
        fail "서명 identifier가 다릅니다: ${code_path}"
    [[ "${metadata}" == *"Authority=Developer ID Application:"* ]] || \
        fail "Developer ID Application 서명이 아닙니다: ${code_path}"
    [[ "${metadata}" == *"TeamIdentifier=${TEAM_ID}"* ]] || \
        fail "서명 Team ID가 다릅니다: ${code_path}"
    [[ "${metadata}" == *"Timestamp="* ]] || \
        fail "secure timestamp가 없습니다: ${code_path}"
    [[ "${metadata}" == *"runtime"* ]] || \
        fail "Hardened Runtime 서명이 아닙니다: ${code_path}"
}

verify_universal_binary() {
    local binary_path="$1"
    local architectures
    architectures="$(lipo -archs "${binary_path}")"

    [[ " ${architectures} " == *" arm64 "* ]] || \
        fail "arm64 아키텍처가 없습니다: ${binary_path}"
    [[ " ${architectures} " == *" x86_64 "* ]] || \
        fail "x86_64 아키텍처가 없습니다: ${binary_path}"
}

if [[ -n "${app_path}" ]]; then
    [[ -d "${app_path}" ]] || fail "앱을 찾을 수 없습니다: ${app_path}"

    extension_path="${app_path}/Contents/PlugIns/SafariTranslateToolbar Extension.appex"
    [[ -d "${extension_path}" ]] || fail "내장 Safari 확장을 찾을 수 없습니다."

    app_identifier="$(plutil -extract CFBundleIdentifier raw -o - "${app_path}/Contents/Info.plist")"
    extension_identifier="$(plutil -extract CFBundleIdentifier raw -o - "${extension_path}/Contents/Info.plist")"
    [[ "${app_identifier}" == "${APP_BUNDLE_ID}" ]] || fail "앱 bundle ID가 다릅니다."
    [[ "${extension_identifier}" == "${EXTENSION_BUNDLE_ID}" ]] || fail "확장 bundle ID가 다릅니다."

    codesign --verify --deep --strict --verbose=2 "${app_path}"
    verify_signed_code "${app_path}" "${APP_BUNDLE_ID}"
    verify_signed_code "${extension_path}" "${EXTENSION_BUNDLE_ID}"

    app_executable="$(plutil -extract CFBundleExecutable raw -o - "${app_path}/Contents/Info.plist")"
    extension_executable="$(plutil -extract CFBundleExecutable raw -o - "${extension_path}/Contents/Info.plist")"
    verify_universal_binary "${app_path}/Contents/MacOS/${app_executable}"
    verify_universal_binary "${extension_path}/Contents/MacOS/${extension_executable}"

    temporary_dir="$(mktemp -d "${TMPDIR%/}/safari-translate-entitlements.XXXXXX")"
    trap 'rm -rf -- "${temporary_dir}"' EXIT INT TERM

    app_entitlements="${temporary_dir}/app.plist"
    extension_entitlements="${temporary_dir}/extension.plist"
    codesign -d --entitlements :- "${app_path}" >"${app_entitlements}" 2>/dev/null || true
    codesign -d --entitlements :- "${extension_path}" >"${extension_entitlements}" 2>/dev/null

    if rg -q 'com\.apple\.security\.(app-sandbox|network)|com\.apple\.security\.get-task-allow' "${app_entitlements}"; then
        fail "컨테이너 앱에 불필요한 entitlement가 있습니다."
    fi

    extension_sandbox="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "${extension_entitlements}")"
    [[ "${extension_sandbox}" == "true" ]] || fail "서명된 확장의 App Sandbox가 꺼져 있습니다."
    extension_key_count="$(rg -c '<key>' "${extension_entitlements}")"
    [[ "${extension_key_count}" == "1" ]] || fail "확장에 App Sandbox 이외의 entitlement가 있습니다."

    print -- "서명된 앱 검증 통과: ${app_path}"
fi

if [[ -n "${dmg_path}" ]]; then
    [[ -f "${dmg_path}" ]] || fail "DMG를 찾을 수 없습니다: ${dmg_path}"

    hdiutil verify "${dmg_path}"
    codesign --verify --strict --verbose=2 "${dmg_path}"
    dmg_metadata="$(codesign -d --verbose=4 "${dmg_path}" 2>&1)"
    [[ "${dmg_metadata}" == *"Authority=Developer ID Application:"* ]] || \
        fail "DMG가 Developer ID Application으로 서명되지 않았습니다."
    [[ "${dmg_metadata}" == *"TeamIdentifier=${TEAM_ID}"* ]] || \
        fail "DMG 서명 Team ID가 다릅니다."
    [[ "${dmg_metadata}" == *"Timestamp="* ]] || fail "DMG에 secure timestamp가 없습니다."

    if [[ "${require_notarization}" == true ]]; then
        xcrun stapler validate "${dmg_path}"
        spctl --assess \
            --type open \
            --context context:primary-signature \
            --verbose=4 \
            "${dmg_path}"
    fi

    print -- "서명된 DMG 검증 통과: ${dmg_path}"
fi
