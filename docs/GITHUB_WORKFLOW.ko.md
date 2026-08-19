# GitHub 연결 및 유지보수 안내

[English](GITHUB_WORKFLOW.md) | 한국어

이 디렉터리는 GitHub 저장소의 로컬 작업 폴더입니다. 여기에서 수정·검증·커밋한 뒤 `git push`하면 GitHub에 반영됩니다.

## 평소 버그 수정 흐름

```sh
git switch main
git pull --ff-only
git switch -c fix/간단한-버그-이름

# 수정 후
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

GitHub에서 Pull Request를 만들고 검토 후 `main`에 병합합니다. 브랜치와 Pull Request를 쓰면 변경 이유를 추적하고 되돌리기 쉽습니다.

## 새 버전 배포 흐름

1. `Config/release.env`, 확장 manifest, Xcode 프로젝트의 버전과 빌드 번호를 함께 올립니다.
2. `./scripts/release.sh --notarize`를 실행합니다.
3. `./scripts/verify-release.sh --dmg dist/파일명.dmg --notarized`를 실행합니다.
4. DMG 설치와 영어/한국어 표시 및 Safari 번역을 실제로 확인합니다.
5. 변경을 커밋하고 `main`에 반영합니다.
6. 같은 버전의 태그와 GitHub Release를 만들고 DMG와 `.sha256`을 첨부합니다.

## 개인정보와 비밀정보

- Apple ID, 앱 전용 암호, API 키, 인증서 개인 키, `.p8`·`.p12` 파일을 커밋하지 않습니다.
- `dist/`, `build/`, `.DS_Store`, 공증 결과 JSON은 `.gitignore`로 제외합니다.
- `git add .` 전에 `git status --short`로 대상을 확인합니다.
- 비밀정보를 커밋했다면 `.gitignore`만으로 해결되지 않습니다. 비밀을 폐기·재발급하고 Git 이력을 정리해야 합니다.
- Issue에 방문 사이트 주소, 페이지 내용, Apple ID, 개인 홈 경로를 올리지 않습니다.

## Issue 처리

1. 중복 여부와 macOS·Safari·앱 버전, 재현 절차를 확인합니다.
2. 재현되면 수정 브랜치를 만들고 Issue 번호를 Pull Request에 연결합니다.
3. 배포가 필요하면 새 버전 Release를 만들고 Issue에 안내합니다.
