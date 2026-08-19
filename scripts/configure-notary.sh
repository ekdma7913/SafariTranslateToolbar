#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
source "${ROOT_DIR}/Config/release.env"

profile="${1:-${NOTARY_PROFILE}}"

print -- "notarytool 프로필 '${profile}'을 Keychain에 저장합니다."
print -- "Team ID: ${TEAM_ID}"
print -- "Apple ID와 앱 전용 암호는 아래 Apple 도구의 보안 프롬프트에만 입력하세요."
print -- "이 프로젝트의 파일이나 셸 인자에는 자격 증명을 저장하지 않습니다."

xcrun notarytool store-credentials "${profile}"

