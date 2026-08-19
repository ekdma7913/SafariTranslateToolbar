# 개인정보 및 권한 점검

[English](PRIVACY.md) | 한국어

## 수집하는 데이터

없습니다.

이 앱은 계정, 서버, 네트워크 요청, 분석 SDK, 광고 SDK, 충돌 수집기, 업데이트 추적기, 원격 로그를 사용하지 않습니다. 소스에도 개발자 개인 이름, 이메일, 사용자 홈 경로, Apple ID, 공증 암호를 저장하지 않습니다.

서명된 앱 파일에는 Apple이 발급한 Developer ID 인증서의 법적 서명자 이름과 Team ID가 표시됩니다. 이는 Gatekeeper가 배포자를 검증하는 공개 서명 정보입니다. 소스 설정에는 공개 식별에 필요한 Team ID만 들어 있습니다.

## Safari 확장 권한

manifest가 선언하는 권한은 `nativeMessaging` 하나입니다.

- 웹페이지 내용 읽기 권한 없음
- 모든 웹사이트 접근 권한 없음
- content script 없음
- 탭의 URL·제목 수집 없음
- 클립보드 권한 없음
- 네트워크 권한 없음

`nativeMessaging`은 버튼 클릭 시 `{ "command": "translate" }`라는 고정된 로컬 명령을 컨테이너 앱에 전달하는 데만 씁니다. 페이지 본문, URL, 쿠키, 입력 내용은 전달하지 않습니다.

## macOS 손쉬운 사용 권한

Safari는 내장 Apple 번역을 확장에서 직접 실행하는 공개 API를 제공하지 않습니다. 따라서 컨테이너 앱이 손쉬운 사용 API로 현재 Safari 창의 번역 메뉴를 찾아 누릅니다.

- 대상 프로세스를 Bundle ID `com.apple.Safari`로 고정
- 역할 정보로 Safari 도구 막대·메뉴·팝오버 범위를 탐색
- 번역 관련 컨트롤의 제목·설명·도움말·식별자만 검색
- 페이지 입력값이 노출될 수 있는 `AXValue`는 읽지 않음
- 검색 결과를 파일이나 네트워크에 기록하지 않음
- 페이지 본문을 읽거나 저장하지 않음
- 번역 명령 실행 후 앱 즉시 종료

권한 상태는 macOS의 TCC가 관리합니다. 앱은 시스템 권한 요청을 이미 시도했는지를 나타내는 boolean 하나만 `UserDefaults`에 저장하며, 사용자 정보는 저장하지 않습니다.

## App Sandbox와 entitlement

- 컨테이너 앱: Safari UI 자동화를 위해 App Sandbox를 사용하지 않음
- 내장 Safari 확장: App Sandbox 사용
- 네트워크·파일·App Group·`get-task-allow` entitlement 없음
- 두 실행 타깃 모두 Hardened Runtime 사용

릴리스 스크립트는 `AXValue`, 네트워크·파일·클립보드 API, 확장 권한 또는 현지화 리소스가 의도치 않게 변경되면 실패합니다.
