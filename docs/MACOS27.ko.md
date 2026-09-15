# macOS 27 호환성 점검

[KO](MACOS27.ko.md) | [EN](MACOS27.md)

## 환경과 범위

2026년 9월 15일 확인: macOS 27.0 (26A428), Safari 27.0,
Xcode 27.0 (27A266a), macOS 27 SDK, Apple Silicon.
1.1.1(빌드 4)을 서명·공증하고 DMG에서 로컬 설치했습니다. 기존 설치 앱은 백업했습니다.
이 문서는 v1.1.1의 검증 기록이며, 이전 v1.1.0 배포 파일은 별도로 유지합니다.

## 확인한 사항과 수정

- Safari 27의 실제 컨트롤에서 `SafariViewMenu`, `TranslationMenu`,
  `Translate-ko_KR`, `TranslationButton`, `ViewOriginalTranslation`을 확인했습니다.
  이 식별자와 `Translate-` 언어 명령 접두사를 우선 사용하고, 기존 언어별 문구
  탐색도 유지합니다. 관찰한 내부 식별자이므로 Apple이 향후 호환성을 보장하는
  API는 아닙니다.
- 번역 하위 메뉴를 연 다음 언어 명령을 실행합니다. 번역 후에도 버튼에
  ‘번역 사용 가능’이 표시될 수 있어, `ViewOriginalTranslation`의 활성 여부로
  이미 번역된 페이지도 판별합니다.
- Safari 활성화와 포커스 창이 준비될 때까지 잠시 기다립니다. macOS 14 이상에서는
  협력적 활성화 API를 사용합니다. 다른 앱으로 전환되면 컨트롤 누르기를 중단하고,
  메뉴 취소 동작과 Safari 전용 Escape 입력으로 메뉴를 닫습니다.
- `AXWebArea`에서 탐색을 중단하고, 역할을 읽을 수 없는 요소를 제외하며, 탐색 대기열의
  크기도 제한합니다. 웹페이지 자체의 도구 막대·메뉴를 Safari 컨트롤로 오인하지 않습니다.
- 순수 매칭·탐색 정책을 `nonisolated`로 선언하여 프로젝트의 기본 MainActor 설정에서
  발생하는 actor 격리 경고를 제거했습니다.
- 이미 요청한 권한이 없으면 명시적인 번역 시도 때 복구 안내를 표시합니다. 시스템 권한
  창은 반복 요청하지 않으며, 설치 안내에 macOS 27에서 바뀐 권한 패널 이름을 반영했습니다.
- 선택적으로 `--diagnose`를 실행하면 앱 버전·macOS 주 버전·손쉬운 사용 신뢰 상태만
  출력합니다. Safari를 탐색하거나 보고서를 저장하지 않습니다.

최소 지원 버전은 macOS 13을 유지하며, 앱과 확장은 모두 `arm64`와 `x86_64`를
포함합니다. Xcode 27은 이전 macOS용 universal 빌드를 지원하므로, 개발 Mac을
업데이트했다는 이유만으로 기존 사용자의 지원을 중단할 필요는 없습니다.

## 재현 명령과 결과

```sh
./scripts/source-audit.sh
./scripts/test.sh
xcodebuild -project SafariTranslateToolbar/SafariTranslateToolbar.xcodeproj \
  -scheme SafariTranslateToolbar -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/macos27-validation \
  CODE_SIGNING_ALLOWED=NO ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
git diff --check
# 설정된 Developer ID와 공증 자격 증명이 필요합니다:
./scripts/release.sh --notarize
"/Applications/SafariTranslateToolbar.app/Contents/MacOS/SafariTranslateToolbar" --diagnose
```

- 소스 점검과 서명 없는 universal 빌드 통과. `lipo -archs`로 앱·확장 모두 두 아키텍처를
  확인했습니다. 제한된 빌드 환경의 Simulator 서비스 경고는 macOS 빌드를 막지 않았습니다.
- XCTest 회귀 테스트 6개 통과: 언어·식별자 매칭, 다른 명령·확장 제외, 웹 콘텐츠 탐색 차단,
  역할 확인 실패 처리, 탐색 깊이·개수 제한을 검사합니다. `scripts/test.sh`는 실제 제품의
  정책 코드를 별도 테스트 진입점과 함께 컴파일합니다. Xcode 26.6 이상이 필요하며
  손쉬운 사용 권한을 요청하지 않습니다. 릴리스 패키징 전에도 자동 실행합니다.
- 설치된 빌드 4의 확장 도구 막대 버튼으로 `https://example.com`이 영문에서 한국어로
  번역되는 것을 확인했습니다. 다시 눌러도 번역 상태가 유지되고 오류나 열린 메뉴가
  남지 않았습니다. 번역된 테스트 탭은 확인할 수 있도록 열어 두었습니다.
- 서명된 universal DMG의 공증·스테이플링·Gatekeeper 검사에 통과했습니다. 설치된
  실행 파일은 DMG와 일치하며, 설치 경로의 확장만 등록된 상태를 확인했습니다.
  이 Mac에서는 기존 확장 활성화와 손쉬운 사용 신뢰 상태가 유지됐습니다.
- DMG SHA-256:
  `e2f58c1a29bcd1a047abdbf7b16359ec885e7371ac938d07415642647e10a734`.

## 남은 수동 확인

`about:blank`의 번역 불가 테스트에서는 UI 자동화로 오류 안내를 확인하지 못했습니다.
확장 버튼과 URL 명령 직접 실행 모두 결과를 확정하지 못했으므로, 통과나 앱 결함으로
단정하지 않고 미검증으로 남깁니다. 빈 테스트 탭은 닫았습니다.

권한 거부·초기화, 여러 창, 전체 화면, 영어 시스템 UI, 이전 macOS, Intel 기기 실행은
별도 검증이 필요합니다. universal 컴파일 성공이 해당 환경의 실행 검증을 뜻하지는 않습니다.

OS 업데이트로 권한이 초기화되면 시스템 설정 > 개인정보 보호 및 보안에서 앱을 활성화하세요.
이 한국어 macOS 27에서는 패널 이름이 ‘기기 제어 및 데이터 접근’이며, 이전 버전에서는
‘손쉬운 사용’입니다. 앱은 시스템 권한 창을 반복 요청하지 않지만, 권한 없이 명시적으로
실행하면 복구 방법을 안내합니다.

## 참고 자료

- [macOS 27 릴리스 노트](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Safari 27 릴리스 노트](https://developer.apple.com/documentation/safari-release-notes/safari-27-release-notes)
- [Xcode 27 릴리스 노트: Intel 지원 변경](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [앱 간 협력적 활성화](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(from:options:))
