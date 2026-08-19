#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="${ROOT_DIR}/dist"
source "${ROOT_DIR}/Config/release.env"

dmg_path="${1:-${DIST_DIR}/SafariTranslateToolbar-${MARKETING_VERSION}.dmg}"
profile="${2:-${NOTARY_PROFILE}}"
result_path="${DIST_DIR}/notarization-result.json"
log_path="${DIST_DIR}/notarization-log.json"

fail() {
    print -u2 -- "오류: $1"
    exit 1
}

[[ -f "${dmg_path}" ]] || fail "공증할 DMG를 찾지 못했습니다: ${dmg_path}"
mkdir -p "${DIST_DIR}"

"${SCRIPT_DIR}/verify-release.sh" --dmg "${dmg_path}"

print -- "Apple 공증 서비스에 DMG 제출 중..."
if ! xcrun notarytool submit "${dmg_path}" \
    --keychain-profile "${profile}" \
    --wait \
    --output-format json >"${result_path}"
then
    print -u2 -- "공증 제출에 실패했습니다. 프로필이 없다면 먼저 ./scripts/configure-notary.sh 를 실행하세요."
    exit 1
fi

submission_id="$(plutil -extract id raw -o - "${result_path}")"
status="$(plutil -extract status raw -o - "${result_path}")"

if ! xcrun notarytool log "${submission_id}" \
    --keychain-profile "${profile}" \
    "${log_path}"
then
    print -u2 -- "경고: 공증 결과 로그를 내려받지 못했습니다. 제출 ID: ${submission_id}"
fi

[[ "${status}" == "Accepted" ]] || \
    fail "공증 상태가 ${status}입니다. ${log_path}를 확인하세요."

print -- "공증 티켓을 DMG에 스테이플하는 중..."
xcrun stapler staple "${dmg_path}"
"${SCRIPT_DIR}/verify-release.sh" --dmg "${dmg_path}" --notarized

print -- "공증·스테이플 완료: ${dmg_path}"

