# Developer ID 및 DMG 배포 절차

[English](DISTRIBUTION.md) | 한국어

## 1. 배포 모델

이 프로젝트는 Mac App Store가 아닌 웹 다운로드 방식으로 배포합니다. 모든 실행 코드를 Developer ID Application으로 서명하고, DMG를 Apple 공증 서비스에 제출한 뒤 티켓을 스테이플합니다. 내장 Safari 확장은 컨테이너 앱 안에 포함되며 앱과 같은 Team으로 서명됩니다.

## 2. 서명 설정

- 컨테이너 앱: App Sandbox `NO`, Hardened Runtime `YES`
- Safari 확장: App Sandbox `YES`, Hardened Runtime `YES`
- 앱과 확장: Release에서 Developer ID Application과 secure timestamp 사용
- `get-task-allow`, 네트워크, 사용자 선택 파일, App Group capability 없음

앱은 Apple의 `SafariServices`, `AppKit/Cocoa`, `ApplicationServices`만 사용하며 제3자 라이브러리나 원격 서비스가 없습니다.

## 3. 서명 DMG 생성

```sh
./scripts/release.sh
```

스크립트는 소스·권한·현지화 리소스를 점검하고, universal Xcode Archive를 만든 뒤 서명된 앱과 영어/한국어 설치 안내가 포함된 UDZO DMG 및 `.sha256` 파일을 생성합니다. 인증서 이름은 소스에 기록하지 않고 Team ID가 같은 identity를 Keychain에서 찾습니다.

## 4. 공증 자격 증명

```sh
./scripts/configure-notary.sh
```

Apple ID와 앱 전용 암호는 Apple의 대화형 입력에서만 제공되고 macOS Keychain에 저장됩니다. 저장소, 환경 파일, README, 셸 히스토리에 암호를 넣지 마세요. App Store Connect API 키의 `.p8` 파일도 저장소에 복사하지 않습니다.

## 5. 공증 및 스테이플

```sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.1.0.dmg
```

스크립트는 DMG 서명 검사, `notarytool submit --wait`, 결과·로그 저장, Accepted 상태 확인, staple 및 Gatekeeper 평가를 수행합니다.

## 6. 배포 전 실제 확인

1. DMG에 quarantine이 적용된 상태로 설치합니다.
2. 앱을 `/Applications`에 복사합니다.
3. 첫 실행에서 Gatekeeper 경고 없이 Safari 확장 설정이 열리는지 봅니다.
4. 영어와 한국어 환경에서 앱·확장 이름 및 안내가 맞는지 봅니다.
5. Safari에서 확장을 켜고 도구 막대 버튼을 확인합니다.
6. 번역 가능한 페이지에서 손쉬운 사용 권한을 허용하고 번역을 실행합니다.
7. 재실행·재부팅 후 권한과 동작이 유지되는지 확인합니다.
8. 권한 거부 후 요청이 반복되지 않는지 확인합니다.

## 7. GitHub Release

공증과 실제 확인을 마친 DMG만 GitHub Release에 첨부합니다. `dist/`는 Git으로 추적하지 않습니다.

```sh
gh release create v1.1.0 \
  dist/SafariTranslateToolbar-1.1.0.dmg \
  dist/SafariTranslateToolbar-1.1.0.dmg.sha256 \
  --title "Safari Translate Toolbar 1.1.0" \
  --notes-file docs/RELEASE_NOTES_1.1.0.md
```

이미 공개한 파일을 같은 이름으로 조용히 교체하지 말고, 수정 시 버전을 올려 새 Release를 만듭니다.

## 8. 공개 후 유지할 값

- 앱·확장 Bundle ID
- Developer Team ID
- URL scheme
- 앱 실행 파일 이름
- `/Applications` 설치 흐름

인증서가 만료되면 같은 Team의 새 Developer ID Application 인증서로 다음 릴리스를 서명합니다.
