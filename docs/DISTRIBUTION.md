# Developer ID 및 DMG 배포 절차

## 1. 배포 모델

이 프로젝트는 Mac App Store가 아닌 웹사이트·파일 다운로드 방식으로 배포합니다. Apple 공식 직접 배포 흐름에 따라 모든 실행 코드를 Developer ID Application으로 서명하고, 최외곽 DMG를 Apple 공증 서비스에 제출한 뒤 티켓을 스테이플합니다.

확장 프로그램용 별도 설치 파일은 만들지 않습니다. `SafariTranslateToolbar Extension.appex`는 컨테이너 앱 안에 포함되며, 앱과 같은 Team으로 서명됩니다.

## 2. 서명 설정의 이유

- 컨테이너 앱: App Sandbox `NO`, Hardened Runtime `YES`
  - Safari UI를 손쉬운 사용 API로 제어해야 하므로 직접 배포 앱의 샌드박스를 끕니다.
- Safari 확장: App Sandbox `YES`, Hardened Runtime `YES`
  - entitlement는 `com.apple.security.app-sandbox = true` 하나뿐입니다.
- 앱과 확장: Release에서 `Developer ID Application`, secure timestamp 사용
- Release: `get-task-allow`와 Xcode base entitlement 주입 금지
- 네트워크, 사용자 선택 파일, App Group capability 없음

앱에서 사용하는 Apple 프레임워크는 `SafariServices`, `AppKit/Cocoa`, `ApplicationServices`뿐이며 제3자 라이브러리나 원격 서비스가 없습니다.

## 3. 서명 DMG 생성

```sh
./scripts/release.sh
```

스크립트가 수행하는 일:

1. manifest 권한, 식별자, 개인 경로 흔적을 정적 점검합니다.
2. shared scheme의 Release 구성으로 universal Xcode Archive를 생성합니다.
3. `developer-id` 방식으로 distribution-signed 앱을 export합니다.
4. 앱과 내장 확장의 Team, Bundle ID, timestamp, Hardened Runtime, entitlement, 아키텍처를 검증합니다.
5. 앱과 `/Applications` 링크를 포함한 읽기 전용 zip 압축 UDZO DMG를 만듭니다.
6. DMG를 Developer ID Application으로 서명하고 무결성을 검증합니다.
7. 최종 DMG와 같은 이름의 `.sha256` 무결성 파일을 만듭니다. 파일 안에는 로컬 절대 경로가 들어가지 않습니다.

인증서 이름은 소스에 기록하지 않습니다. 스크립트가 Team ID와 일치하는 Developer ID Application identity를 Keychain에서 찾습니다. 인증서를 갱신해도 설정 파일의 개인 이름이나 인증서 해시를 수정할 필요가 없습니다.

## 4. 공증 자격 증명 저장

```sh
./scripts/configure-notary.sh
```

프로필 기본 이름은 `safari-translate-notary`입니다. Apple ID와 앱 전용 암호는 Apple의 `notarytool` 대화형 입력에서만 제공되며 macOS Keychain에 저장됩니다. 저장소, 환경 파일, README, 셸 히스토리에 암호를 넣지 마세요.

조직에서 App Store Connect API 키를 쓸 경우에는 Apple 공식 `notarytool store-credentials` 옵션으로 별도 프로필을 만든 뒤 `NOTARY_PROFILE`만 바꿀 수 있습니다. `.p8` 키는 이 저장소에 복사하지 않습니다.

## 5. 공증 및 스테이플

```sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.0.0.dmg
```

스크립트는 다음을 수행합니다.

1. 공증 전 DMG 서명을 검증합니다.
2. `notarytool submit --wait`로 제출합니다.
3. 제출 결과를 `dist/notarization-result.json`에 저장합니다.
4. 상세 로그를 `dist/notarization-log.json`에 저장합니다.
5. 상태가 `Accepted`일 때만 `stapler staple`을 실행합니다.
6. staple, DMG 서명, `spctl` Gatekeeper 평가를 최종 확인합니다.

`altool`은 사용하지 않습니다. Apple은 공증 제출에 `notarytool` 사용을 요구합니다.

## 6. 배포 전 수동 확인

자동 검증 뒤에도 아래 실제 사용자 흐름을 별도 Mac 또는 새 사용자 계정에서 확인합니다.

1. DMG를 웹 다운로드나 AirDrop으로 전달해 quarantine이 적용되게 합니다.
2. DMG를 열고 앱을 `/Applications`에 복사합니다.
3. 앱을 처음 실행했을 때 Gatekeeper 경고 없이 Safari 확장 설정이 열리는지 확인합니다.
4. Safari에서 확장을 켜고 도구 막대 버튼이 나타나는지 확인합니다.
5. 번역 가능한 페이지에서 최초 손쉬운 사용 요청을 허용합니다.
6. 버튼을 다시 눌렀을 때 Safari의 Apple 번역이 실행되는지 확인합니다.
7. 앱과 Safari를 재실행하고 Mac도 재부팅한 뒤 권한과 동작이 유지되는지 확인합니다.
8. 권한을 거부했을 때 시스템 요청이 무한 반복되지 않는지 확인합니다.

## 7. GitHub Release 업로드

공증과 수동 확인을 모두 마친 DMG만 GitHub Release에 첨부합니다. 소스 저장소에서는 `dist/`를 추적하지 않습니다.

```sh
gh release create v1.0.0 \
  dist/SafariTranslateToolbar-1.0.0.dmg \
  dist/SafariTranslateToolbar-1.0.0.dmg.sha256 \
  --title "Safari 번역 툴바 1.0.0" \
  --notes-file release-notes.md
```

태그와 앱 버전을 일치시키고, 업로드가 끝나면 브라우저의 Release 페이지에서 두 파일이 실제로 다운로드되는지 확인합니다.

## 8. 공개 후 유지해야 하는 값

- 앱 Bundle ID
- 확장 Bundle ID
- Developer Team ID
- URL scheme
- 앱 실행 파일 이름
- `/Applications` 설치 흐름

인증서가 만료되면 같은 Team의 새 Developer ID Application 인증서로 다음 릴리스를 서명합니다. 이미 유효한 인증서로 timestamp·공증된 과거 릴리스는 그 서명 시점을 검증할 수 있습니다.
