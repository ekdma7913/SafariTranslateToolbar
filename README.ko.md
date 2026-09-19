# Safari 번역 툴바

[KO](README.ko.md) | [EN](README.md)

Safari 주소창 옆 도구 막대 버튼으로 Safari의 **기존 Apple 번역 기능**을 실행하는 macOS 앱과 Safari Web Extension입니다. 별도 번역 서버나 페이지 스크립트를 사용하지 않습니다.

## 현재 상태

- 앱: `com.team95788x96a7.safari-translate-toolbar`
- 확장: `com.team95788x96a7.safari-translate-toolbar.Extension`
- 소스 버전: `1.2.1 (6)`; 공개 배포 파일은 GitHub Releases 참고
- 지원 언어: 영어, 한국어
- 최소 macOS: 13.0
- 아키텍처: Apple Silicon `arm64` + Intel `x86_64`
- 배포: Developer ID 서명, Hardened Runtime, Apple 공증 및 스테이플된 DMG

앱·확장 Bundle ID와 Team ID는 공개 후 바꾸지 마세요. 이 값과 Developer ID 서명 계열이 안정적이어야 macOS가 업데이트를 같은 앱으로 인식하고 손쉬운 사용 권한도 가능한 한 유지합니다.

## 다운로드

일반 사용자는 [GitHub Releases](https://github.com/ekdma7913/SafariTranslateToolbar/releases/latest)에서 최신 `SafariTranslateToolbar-버전.dmg`를 다운로드합니다. 같은 릴리스의 `.sha256` 파일로 무결성을 확인할 수 있습니다.

```sh
shasum -a 256 -c SafariTranslateToolbar-1.2.1.dmg.sha256
```

## 언어 지원

macOS의 앱별 선호 언어가 있으면 그 설정을 따르고, 없으면 시스템 언어를 따릅니다.

- 한국어 환경: 앱·확장 이름, 도구 막대 설명, 오류 안내가 한국어로 표시됩니다.
- 그 밖의 환경: 영어가 기본 언어로 표시됩니다.

Safari가 번역할 목표 언어는 이 앱의 표시 언어와 별개입니다. 실제 번역 언어는 Safari와 macOS의 언어 설정 및 Apple 번역 지원 여부에 따라 Safari가 결정합니다.

## 동작 구조

한 번 누르면 번역하고 다시 누르면 원문으로 돌아갑니다. 확인된 번역 상태는 원 안의
체크 표시, 원문 상태는 기본 번역 아이콘, 처리 중에는 모래시계로 표시합니다.
상태를 확인하지 못하면 기본 아이콘과 안내 툴팁을 사용합니다. 아이콘 위에 글자 배지를
겹치지 않습니다. Safari가 색을 결정하므로 모양으로 상태를 구분하며, 처리 중 연속 클릭은 무시합니다.

표시는 이 버튼으로 마지막 확인한 상태이며 Safari 메뉴의 상시 감시 결과는 아닙니다.
페이지 이동이나 브라우저 재시작 시 초기화되고, Safari 메뉴에서 직접 바꾼 상태는
다음 클릭에 다시 확인합니다. 실제 동작은 아이콘과 무관하게 Safari의 현재 메뉴 상태를
읽어 번역 또는 원문 복귀를 결정합니다.
확인한 동작과 남은 테스트는 [토글 검증 범위와 제한](docs/TOGGLE.ko.md)을 참고하세요.

```text
Safari 도구 막대 버튼
  → nativeMessaging으로 로컬 확장 핸들러 호출
  → 고유 URL scheme으로 컨테이너 앱 실행
  → 손쉬운 사용 API로 Safari의 번역 또는 원본 보기 선택
  → 앱이 메뉴 상태를 확인한 뒤 네이티브 메시지로 응답
  → 요청한 탭의 버튼 표시 갱신
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

서명·공증된 배포본에서는 Safari의 `서명되지 않은 확장 프로그램 허용`을 켤 필요가 없습니다. 권한을 거부했거나 초기화했다면 시스템 설정 > 개인정보 보호 및 보안에서 macOS 27은 `기기 제어 및 데이터 접근`, 이전 버전은 `손쉬운 사용`을 열어 앱을 켜 주세요. 시스템 권한 팝업은 반복 요청하지 않으며, 권한이 없는 상태로 번역 버튼을 누르면 복구 방법을 안내합니다.

## 개발 및 릴리스

현재 작업 소스에는 macOS 27 / Safari 27 대응 개선이 포함되어 있습니다.
[호환성 점검 결과와 남은 설치 테스트](docs/MACOS27.ko.md)를 참고하세요.
기존 설치 앱은 자동으로 업데이트되지 않습니다. 새 DMG를 다운로드하여 설치해 주세요.

필요 조건:

- Xcode와 macOS SDK
- 버튼 상태 회귀 테스트용 Node.js 18 이상
- Team `95788X96A7`의 개인 키가 연결된 유효한 Developer ID Application 인증서
- 공증할 때만 Apple ID용 앱 전용 암호 또는 App Store Connect API 키

```sh
./scripts/source-audit.sh
./scripts/test.sh
./scripts/release.sh
./scripts/configure-notary.sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.2.1.dmg
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
