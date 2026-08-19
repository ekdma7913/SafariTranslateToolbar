#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
PROJECT_DIR="${ROOT_DIR}/SafariTranslateToolbar"
PROJECT_FILE="${PROJECT_DIR}/SafariTranslateToolbar.xcodeproj"
SCHEME="SafariTranslateToolbar"
PRODUCT_NAME="SafariTranslateToolbar"
DISPLAY_NAME="Safari Translate Toolbar"
DIST_DIR="${ROOT_DIR}/dist"
BUILD_DIR="${ROOT_DIR}/build"

source "${ROOT_DIR}/Config/release.env"

notarize_after_build=false

fail() {
    print -u2 -- "오류: $1"
    exit 1
}

case "${1:-}" in
    "") ;;
    --notarize) notarize_after_build=true ;;
    *) fail "사용법: ./scripts/release.sh [--notarize]" ;;
esac

"${SCRIPT_DIR}/source-audit.sh"

identity="${DEVELOPER_ID_IDENTITY:-}"
if [[ -z "${identity}" ]]; then
    identity="$(security find-identity -v -p codesigning | awk -v team="(${TEAM_ID})" '
        /Developer ID Application:/ && index($0, team) { print $2; exit }
    ')"
fi

[[ -n "${identity}" ]] || \
    fail "Team ${TEAM_ID}의 Developer ID Application 인증서와 개인 키를 찾지 못했습니다."

mkdir -p "${DIST_DIR}" "${BUILD_DIR}"
work_dir="$(mktemp -d "${BUILD_DIR}/release.XXXXXX")"
[[ "${work_dir}" == "${BUILD_DIR}/release."* ]] || fail "안전한 임시 빌드 경로를 만들지 못했습니다."
trap 'rm -rf -- "${work_dir}"' EXIT INT TERM

archive_path="${work_dir}/${PRODUCT_NAME}.xcarchive"
export_path="${work_dir}/Export"
derived_data_path="${work_dir}/DerivedData"
app_path="${export_path}/${PRODUCT_NAME}.app"
dmg_root="${work_dir}/DMG"
unsigned_dmg="${work_dir}/${PRODUCT_NAME}-${MARKETING_VERSION}.dmg"
output_dmg="${DIST_DIR}/${PRODUCT_NAME}-${MARKETING_VERSION}.dmg"
output_name="${PRODUCT_NAME}-${MARKETING_VERSION}.dmg"

print -- "Developer ID Release 아카이브 생성 중..."
xcodebuild \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "${archive_path}" \
    -derivedDataPath "${derived_data_path}" \
    -hideShellScriptEnvironment \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="${identity}" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
    MARKETING_VERSION="${MARKETING_VERSION}" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    clean archive

print -- "Developer ID 배포 앱 내보내는 중..."
xcodebuild \
    -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${export_path}" \
    -exportOptionsPlist "${ROOT_DIR}/Config/ExportOptions.plist" \
    -hideShellScriptEnvironment

[[ -d "${app_path}" ]] || fail "내보낸 앱을 찾지 못했습니다: ${app_path}"
"${SCRIPT_DIR}/verify-release.sh" --app "${app_path}"

mkdir -p "${dmg_root}"
ditto "${app_path}" "${dmg_root}/${PRODUCT_NAME}.app"
ln -s /Applications "${dmg_root}/Applications"
ditto "${ROOT_DIR}/DMG_INSTALL.txt" "${dmg_root}/Install Guide.txt"
ditto "${ROOT_DIR}/DMG_INSTALL.ko.txt" "${dmg_root}/설치 안내.txt"

print -- "UDZO DMG 생성 및 서명 중..."
hdiutil create \
    -volname "${DISPLAY_NAME}" \
    -srcfolder "${dmg_root}" \
    -format UDZO \
    -ov \
    "${unsigned_dmg}"

codesign \
    --force \
    --sign "${identity}" \
    --timestamp \
    --identifier "${APP_BUNDLE_ID}.dmg" \
    "${unsigned_dmg}"

"${SCRIPT_DIR}/verify-release.sh" \
    --app "${dmg_root}/${PRODUCT_NAME}.app" \
    --dmg "${unsigned_dmg}"

mv -f "${unsigned_dmg}" "${output_dmg}"
print -- "서명된 DMG 생성 완료: ${output_dmg}"

if [[ "${notarize_after_build}" == true ]]; then
    "${SCRIPT_DIR}/notarize.sh" "${output_dmg}" "${NOTARY_PROFILE}"
else
    print -- "외부 배포 전 공증 필요: ./scripts/notarize.sh '${output_dmg}'"
fi

(
    cd "${DIST_DIR}"
    shasum -a 256 "${output_name}" >"${output_name}.sha256"
)
print -- "SHA-256 파일 생성 완료: ${output_dmg}.sha256"
