# Safari 번역 툴바

Safari 주소창 옆 도구 막대 버튼으로 Safari의 **기존 Apple 번역 기능**을 실행하는 macOS 앱과 Safari Web Extension입니다. 이 폴더는 이전 로컬·ad-hoc 프로젝트를 복제한 것이 아니라, Apple의 변환 도구로 새 Xcode 프로젝트를 만든 뒤 필요한 번역 로직만 옮긴 배포용 프로젝트입니다.

## 현재 상태

- 앱: `com.team95788x96a7.safari-translate-toolbar`
- 확장: `com.team95788x96a7.safari-translate-toolbar.Extension`
- 버전: `1.0.0 (1)`
- 최소 macOS: 13.0
- 아키텍처: Apple Silicon `arm64` + Intel `x86_64`
- Release 서명: Developer ID Application + Hardened Runtime + secure timestamp
- 배포 형식: 서명된 UDZO DMG, 이후 Apple 공증 및 스테이플

앱·확장 Bundle ID와 Team ID는 첫 공개 후 바꾸지 마세요. 이 값과 Developer ID 서명 계열이 안정적이어야 macOS가 업데이트를 같은 앱으로 인식하고 손쉬운 사용 권한도 가능한 한 유지합니다.

## 다운로드

일반 사용자는 소스의 `dist/` 폴더가 아니라 [GitHub Releases](https://github.com/ekdma7913/SafariTranslateToolbar/releases/latest)에서 최신 `SafariTranslateToolbar-버전.dmg`를 다운로드합니다. 같은 릴리스의 `.sha256` 파일로 다운로드 무결성을 확인할 수 있습니다.

```sh
shasum -a 256 -c SafariTranslateToolbar-1.0.0.dmg.sha256
```

## 동작 구조

```text
Safari 도구 막대 버튼
  → nativeMessaging으로 로컬 확장 핸들러 호출
  → 고유 URL scheme으로 컨테이너 앱 실행
  → 손쉬운 사용 API로 Safari의 보기 > 번역 메뉴 선택
  → Safari의 Apple 번역 실행
```

Safari에는 확장 프로그램이 내장 Apple 번역을 직접 호출하는 공개 API가 없습니다. 그래서 확장은 번역 서비스나 페이지 스크립트를 대신 사용하지 않고, 컨테이너 앱이 Safari의 현재 UI에 있는 번역 명령을 누릅니다. Safari/macOS에서 메뉴 구조나 번역 문구가 크게 바뀌면 접근성 탐색 로직을 업데이트해야 할 수 있습니다.

## 사용자 설치

외부 배포본은 반드시 **공증 완료된 DMG**를 사용합니다.

1. DMG를 열고 `SafariTranslateToolbar.app`을 `Applications`로 복사합니다.
2. 응용 프로그램 폴더에서 앱을 한 번 실행합니다.
3. 열린 Safari 설정의 확장 프로그램에서 `Safari 번역 버튼`을 켭니다.
4. 버튼이 보이지 않으면 Safari 도구 막대 사용자화에서 추가합니다.
5. 번역 가능한 페이지에서 버튼을 누릅니다.
6. macOS가 최초 한 번 요청하는 손쉬운 사용 권한을 허용합니다.

서명·공증된 배포본에서는 Safari의 `서명되지 않은 확장 프로그램 허용`을 켤 필요가 없습니다. 손쉬운 사용 요청을 거부했거나 권한을 수동 초기화했다면 시스템 설정의 `개인정보 보호 및 보안 > 손쉬운 사용`에서 직접 앱을 켜야 합니다. 앱은 거부 후 같은 시스템 팝업을 반복해서 띄우지 않습니다.

## 개발 및 릴리스

필요 조건:

- Xcode와 macOS SDK
- Team `95788X96A7`의 개인 키가 연결된 유효한 Developer ID Application 인증서
- 공증할 때만 Apple ID용 앱 전용 암호 또는 App Store Connect API 키

소스와 최소 권한 설정 점검:

```sh
./scripts/source-audit.sh
```

Developer ID로 앱과 DMG를 빌드·서명:

```sh
./scripts/release.sh
```

처음 한 번 공증 자격 증명을 macOS Keychain에 저장:

```sh
./scripts/configure-notary.sh
```

Apple ID와 앱 전용 암호는 `notarytool`의 대화형 프롬프트에만 입력합니다. 프로젝트 파일이나 명령행 인자에는 저장하지 않습니다.

기존 서명 DMG를 공증하고 티켓을 스테이플:

```sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.0.0.dmg
```

빌드부터 공증까지 한 번에 실행:

```sh
./scripts/release.sh --notarize
```

공증 전 DMG는 개발 점검용일 뿐 다른 사람에게 배포하지 마세요. 세부 절차와 검증 항목은 [배포 문서](docs/DISTRIBUTION.md), 데이터 접근 범위는 [개인정보 문서](docs/PRIVACY.md)를 참고하세요.

처음 GitHub에 연결하거나 공개 후 버그를 수정하는 순서는 [GitHub 유지보수 안내](docs/GITHUB_WORKFLOW.md)에 정리되어 있습니다. 버그 제보 시에는 GitHub Issues의 양식을 사용합니다.

## 라이선스

소스 코드는 [MIT License](LICENSE)로 공개됩니다.

## 버전 올리기

릴리스 전에 다음 값을 같은 버전으로 맞춥니다.

1. `Config/release.env`의 `MARKETING_VERSION`과 `BUILD_NUMBER`
2. 확장 `manifest.json`의 `version`
3. Xcode 프로젝트의 `MARKETING_VERSION`과 `CURRENT_PROJECT_VERSION`

`source-audit.sh`가 manifest와 릴리스 버전 불일치를 차단합니다. 새 Developer ID 인증서를 발급받더라도 Team ID와 Bundle ID는 그대로 유지합니다.

## 주요 파일

- `SafariTranslateToolbar/.../AppDelegate.swift`: Safari 번역 메뉴를 찾고 실행하며, 손쉬운 사용 요청을 한 번만 관리합니다.
- `SafariTranslateToolbar/... Extension/SafariWebExtensionHandler.swift`: 확장의 `translate` 명령만 검증해 로컬 앱으로 전달합니다.
- `SafariTranslateToolbar/... Extension/Resources/manifest.json`: 도구 막대 버튼과 `nativeMessaging` 단일 권한을 선언합니다.
- `Config/release.env`: 공개 가능한 제품 식별자·버전·Team 설정입니다. 비밀 값은 금지합니다.
- `scripts/release.sh`: Xcode Archive, Developer ID export, UDZO DMG 생성과 서명을 재현합니다.
- `scripts/notarize.sh`: `notarytool`, 공증 로그, staple, Gatekeeper 검증을 처리합니다.
- `scripts/source-audit.sh`: 이전 식별자·개인 경로·페이지/네트워크 권한 재유입을 검사합니다.
- `scripts/verify-release.sh`: 서명 주체, timestamp, Hardened Runtime, universal binary, entitlement를 검사합니다.

## Apple 공식 문서

- [Distributing your Safari web extension](https://developer.apple.com/documentation/safariservices/distributing-your-safari-web-extension)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac)
- [Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
