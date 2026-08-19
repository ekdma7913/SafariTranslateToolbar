# GitHub 연결 및 유지보수 안내

이 문서는 이 디렉터리를 GitHub 저장소의 작업 폴더로 계속 사용하는 흐름을 설명합니다. `origin`이 한 번 연결된 뒤에는 여기에서 수정하고 커밋한 내용이 `git push`를 통해 GitHub에 반영됩니다.

## 최초 공개 전에

1. `./scripts/source-audit.sh`로 권한과 개인정보 관련 금지 항목을 검사합니다.
2. `git status --short`와 `git diff --check`로 업로드 범위를 확인합니다.
3. 커밋 작성자 이메일이 GitHub의 `users.noreply.github.com` 주소인지 확인합니다.
4. 공증된 DMG의 서명, staple, Gatekeeper 평가를 검사합니다.
5. 실제 Safari에서 설치·번역 흐름을 확인합니다.
6. 공개 저장소를 만들고 로컬 `main`을 `origin/main`에 push합니다.
7. GitHub Release를 만들고 DMG와 `.sha256` 파일을 첨부합니다.

DMG는 용량 때문이 아니라 소스와 배포물을 분리하기 위해 Git으로 추적하지 않습니다. 사용자는 Release에서 DMG를 받고, 개발자는 소스 저장소에서 변경 이력을 관리합니다.

## 평소 버그 수정 흐름

먼저 GitHub Issue에서 재현 조건을 확인하고 이 폴더에서 다음 순서로 작업합니다.

```sh
git switch main
git pull --ff-only
git switch -c fix/간단한-버그-이름

# Xcode 또는 편집기에서 수정
./scripts/source-audit.sh
xcodebuild \
  -project SafariTranslateToolbar/SafariTranslateToolbar.xcodeproj \
  -scheme SafariTranslateToolbar \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build

git status --short
git diff --check
git add 수정한파일1 수정한파일2
git commit -m "Fix: 수정 내용을 짧게 설명"
git push -u origin fix/간단한-버그-이름
```

GitHub에서 Pull Request를 만들고 변경 내용을 검토한 뒤 `main`에 병합합니다. 작은 프로젝트라도 바로 `main`에 push하기보다 브랜치와 Pull Request를 쓰면 어떤 버그를 왜 고쳤는지 추적하고 되돌리기 쉽습니다.

## 새 버전 배포 흐름

1. `Config/release.env`, 확장 `manifest.json`, Xcode 프로젝트의 버전과 빌드 번호를 함께 올립니다.
2. `./scripts/release.sh --notarize`를 실행합니다.
3. `./scripts/verify-release.sh --dmg dist/파일명.dmg --notarized`를 실행합니다.
4. DMG 설치와 Safari 번역을 실제로 확인합니다.
5. 변경을 커밋하고 `main`에 반영합니다.
6. 같은 버전의 Git 태그와 GitHub Release를 만든 뒤 DMG와 `.sha256`을 첨부합니다.

이미 공개한 Release 파일을 같은 이름으로 조용히 교체하지 않습니다. 수정이 필요하면 버전을 올려 새 Release를 만들어야 사용자가 어떤 바이너리를 받았는지 확인할 수 있습니다.

## 개인정보와 비밀정보 주의

- Apple ID, 앱 전용 암호, API 키, 인증서 개인 키, `.p8`·`.p12` 파일은 커밋하지 않습니다.
- `dist/`, `build/`, `.DS_Store`, 공증 결과 JSON은 `.gitignore`로 제외됩니다.
- `git add .` 전에 반드시 `git status --short`로 대상 파일을 봅니다.
- 비밀정보를 한 번이라도 커밋했다면 `.gitignore`만 추가해서는 해결되지 않습니다. 해당 비밀을 폐기·재발급하고 Git 이력도 정리해야 합니다.
- GitHub Issue에는 방문한 사이트 주소, 페이지 내용, Apple ID, 시스템 로그의 개인 경로를 올리지 않습니다.

## Issue 처리 기본 순서

1. 중복 Issue인지 확인합니다.
2. macOS·Safari·앱 버전과 재현 절차를 확인합니다.
3. 재현되면 `bug` 라벨을 붙이고 수정 브랜치를 만듭니다.
4. 수정 후 Issue 번호를 Pull Request에 연결합니다.
5. 배포가 필요한 수정이면 새 버전 Release를 만들고 Issue에 해당 Release를 안내합니다.
