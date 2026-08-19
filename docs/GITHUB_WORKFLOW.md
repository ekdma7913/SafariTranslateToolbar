# GitHub maintenance workflow

English | [한국어](GITHUB_WORKFLOW.ko.md)

This directory is the local working copy of the GitHub repository. Changes made and verified here are published with a commit and `git push`.

## Routine bug-fix flow

```sh
git switch main
git pull --ff-only
git switch -c fix/short-bug-name

# Make the change, then verify it
./scripts/source-audit.sh
xcodebuild \
  -project SafariTranslateToolbar/SafariTranslateToolbar.xcodeproj \
  -scheme SafariTranslateToolbar \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build

git status --short
git diff --check
git add path/to/changed-file
git commit -m "Fix: briefly describe the change"
git push -u origin fix/short-bug-name
```

Open a Pull Request on GitHub and merge it into `main` after review. Even for a small project, branches and Pull Requests preserve why a change was made and make rollback easier.

## New release flow

1. Update the version and build number together in `Config/release.env`, the extension manifest, and the Xcode project.
2. Run `./scripts/release.sh --notarize`.
3. Run `./scripts/verify-release.sh --dmg dist/filename.dmg --notarized`.
4. Test DMG installation, English/Korean presentation, and Safari translation.
5. Commit and merge the source change into `main`.
6. Create the matching Git tag and GitHub Release, attaching the DMG and `.sha256` file.

## Privacy and secrets

- Never commit an Apple ID, app-specific password, API key, certificate private key, `.p8`, or `.p12` file.
- `.gitignore` excludes `dist/`, `build/`, `.DS_Store`, and notarization result JSON.
- Check `git status --short` before `git add`.
- If a secret was committed, adding it to `.gitignore` is not enough. Revoke and replace it, then clean the Git history.
- Do not post visited URLs, page content, Apple IDs, or personal home-directory paths in Issues.

## Issue handling

1. Check for duplicates and collect the macOS, Safari, and app versions plus reproduction steps.
2. Reproduce the issue, create a fix branch, and link the Issue in the Pull Request.
3. If users need a new binary, publish a new versioned Release and link it from the Issue.
