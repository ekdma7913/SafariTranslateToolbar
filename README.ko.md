# Safari 번역 툴바

[KO](README.ko.md) | [EN](README.md)

Safari 주소창 옆 도구 막대 버튼으로 Safari의 **기존 Apple 번역 기능**을 실행하는 macOS 앱과 Safari Web Extension입니다. 별도 번역 서버나 페이지 스크립트를 사용하지 않습니다.

## 현재 상태

- 앱: `com.team95788x96a7.safari-translate-toolbar`
- 확장: `com.team95788x96a7.safari-translate-toolbar.Extension`
- 버전: `1.1.0 (2)`
- 지원 언어: 영어, 한국어
- 최소 macOS: 13.0
- 아키텍처: Apple Silicon `arm64` + Intel `x86_64`
- 배포: Developer ID 서명, Hardened Runtime, Apple 공증 및 스테이플된 DMG

앱·확장 Bundle ID와 Team ID는 공개 후 바꾸지 마세요. 이 값과 Developer ID 서명 계열이 안정적이어야 macOS가 업데이트를 같은 앱으로 인식하고 손쉬운 사용 권한도 가능한 한 유지합니다.

## 다운로드

일반 사용자는 [GitHub Releases](https://github.com/ekdma7913/SafariTranslateToolbar/releases/latest)에서 최신 `SafariTranslateToolbar-버전.dmg`를 다운로드합니다. 같은 릴리스의 `.sha256` 파일로 무결성을 확인할 수 있습니다.

```sh
shasum -a 256 -c SafariTranslateToolbar-1.1.0.dmg.sha256
```

## 언어 지원

macOS의 앱별 선호 언어가 있으면 그 설정을 따르고, 없으면 시스템 언어를 따릅니다.

- 한국어 환경: 앱·확장 이름, 도구 막대 설명, 오류 안내가 한국어로 표시됩니다.
- 그 밖의 환경: 영어가 기본 언어로 표시됩니다.

Safari가 번역할 목표 언어는 이 앱의 표시 언어와 별개입니다. 실제 번역 언어는 Safari와 macOS의 언어 설정 및 Apple 번역 지원 여부에 따라 Safari가 결정합니다.

## 동작 구조

```text
Safari 도구 막대 버튼
  → nativeMessaging으로 로컬 확장 핸들러 호출
  → 고유 URL scheme으로 컨테이너 앱 실행
  → 손쉬운 사용 API로 Safari의 보기 > 번역 메뉴 선택
  → Safari의 Apple 번역 실행
```

Safari에는 확장 프로그램이 내장 Apple 번역을 직접 호출하는 공개 API가 없습니다. 따라서 컨테이너 앱이 Safari의 현재 UI에 있는 번역 명령을 누릅니다. Safari/macOS에서 메뉴 구조나 번역 문구가 크게 바뀌면 접근성 탐색 로직을 업데이트해야 할 수 있습니다.

## 사용자 설치

외부 배포본은 반드시 **공증 완료된 DMG**를 사용합니다.

1. DMG를 열고 `SafariTranslateToolbar.app`을 `Applications`로 복사합니다.
2. 응용 프로그램 폴더에서 앱을 한 번 실행합니다.
3. Safari 설정 > 확장 프로그램에서 `Safari 번역 버튼`을 켭니다.
4. 버튼이 보이지 않으면 Safari 도구 막대 사용자화에서 추가합니다.
5. 번역 가능한 페이지에서 버튼을 누릅니다.
6. macOS가 최초 한 번 요청하는 손쉬운 사용 권한을 허용합니다.

서명·공증된 배포본에서는 Safari의 `서명되지 않은 확장 프로그램 허용`을 켤 필요가 없습니다. 권한을 거부했거나 수동 초기화했다면 시스템 설정의 `개인정보 보호 및 보안 > 손쉬운 사용`에서 앱을 직접 켜야 합니다. 앱은 거부 후 시스템 팝업을 반복해서 띄우지 않습니다.

## 개발 및 릴리스

필요 조건:

- Xcode와 macOS SDK
- Team `95788X96A7`의 개인 키가 연결된 유효한 Developer ID Application 인증서
- 공증할 때만 Apple ID용 앱 전용 암호 또는 App Store Connect API 키

```sh
./scripts/source-audit.sh
./scripts/release.sh
./scripts/configure-notary.sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.1.0.dmg
```

빌드부터 공증까지 한 번에 실행하려면 `./scripts/release.sh --notarize`를 사용합니다. Apple ID와 앱 전용 암호는 `notarytool`의 대화형 프롬프트에만 입력하고 프로젝트에 저장하지 않습니다.

자세한 내용은 [배포 문서](docs/DISTRIBUTION.ko.md), [개인정보 문서](docs/PRIVACY.ko.md), [GitHub 유지보수 안내](docs/GITHUB_WORKFLOW.ko.md)를 참고하세요.

## 라이선스

소스 코드는 [MIT License](LICENSE)로 공개됩니다.

## 주요 파일

- `SafariTranslateToolbar/.../AppDelegate.swift`: Safari 번역 메뉴 실행과 현지화된 오류 안내
- `SafariTranslateToolbar/.../*.lproj`: macOS 앱·확장의 영어/한국어 문자열
- `SafariTranslateToolbar/... Extension/Resources/_locales`: WebExtension 영어/한국어 문자열
- `scripts/source-audit.sh`: 권한·개인정보·현지화 리소스 점검
- `scripts/release.sh`: 서명된 universal 앱과 DMG 생성
- `scripts/verify-release.sh`: 서명, entitlement, 아키텍처, 현지화 리소스 검증

## Apple 공식 문서

- [Localizing your app](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LocalizingYourApp/LocalizingYourApp.html)
- [Creating a Safari web extension](https://developer.apple.com/documentation/safariservices/creating-a-safari-web-extension)
- [Distributing your Safari web extension](https://developer.apple.com/documentation/safariservices/distributing-your-safari-web-extension)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
