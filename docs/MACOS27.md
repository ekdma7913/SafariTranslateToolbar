# macOS 27 compatibility review

[KO](MACOS27.ko.md) | [EN](MACOS27.md)

## Environment and scope

Checked on September 15, 2026: macOS 27.0 (26A428), Safari 27.0,
Xcode 27.0 (27A266a), macOS 27 SDK, Apple silicon.
Version 1.1.1 (build 4) was signed, notarized, and installed locally from its DMG.
The previous installed app was backed up. This report records validation for
v1.1.1; the older v1.1.0 release assets are preserved separately.

## Findings and changes

- Safari 27 exposes `SafariViewMenu`, `TranslationMenu`, `Translate-ko_KR`,
  `TranslationButton`, and `ViewOriginalTranslation` in its native controls.
  Prefer these identifiers and the `Translate-` language-command prefix,
  with localized labels as fallback. Identifiers are observed implementation
  details, not an Apple compatibility guarantee.
- Open the translation submenu before invoking a language command.
  An enabled `ViewOriginalTranslation` identifies an already translated page:
  the toolbar can still say “Translation Available” after translation.
- Wait briefly for Safari activation and focused-window availability. On
  macOS 14+, use cooperative activation. Stop pressing controls when another
  app becomes frontmost; use targeted menu cancellation instead of global Escape.
- Stop traversal at `AXWebArea`, skip unreadable roles, and bound the traversal
  queue. A webpage's own toolbar/menu must never be treated as Safari chrome.
- Mark pure matching/traversal policies `nonisolated`, eliminating actor-isolation
  warnings under the project's default MainActor configuration.
- When a previously requested permission is missing, show localized recovery
  guidance on an explicit translation attempt without repeating the system prompt.
  Include macOS 27's renamed permission panel in installation guidance.
- Add optional `--diagnose` output limited to app version, macOS major version,
  and Accessibility trust status; it does not inspect Safari or save a report.

The minimum deployment target remains macOS 13. Both executables retain
`arm64` and `x86_64`. Xcode 27 still supports universal back-deployment;
there is no need to drop older users just to build on macOS 27.

## Reproduction and results

```sh
./scripts/source-audit.sh
./scripts/test.sh
xcodebuild -project SafariTranslateToolbar/SafariTranslateToolbar.xcodeproj \
  -scheme SafariTranslateToolbar -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/macos27-validation \
  CODE_SIGNING_ALLOWED=NO ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
git diff --check
# Requires the configured Developer ID and notarization credentials:
./scripts/release.sh --notarize
"/Applications/SafariTranslateToolbar.app/Contents/MacOS/SafariTranslateToolbar" --diagnose
```

- Source audit and unsigned universal build passed; `lipo -archs` confirmed both
  architectures in the app and embedded extension. Simulator-service warnings
  occurred in the restricted build environment but did not prevent the macOS build.
- Six XCTest regressions passed: localized/identifier matching, exclusion of
  other actions/extensions, web-content pruning, unknown roles, and traversal budgets.
  `scripts/test.sh` compiles production policies with a separate test entry point;
  it needs Xcode 26.6 or later and does not request Accessibility permission.
  Release packaging now runs these tests first.
- Installed build 4's extension toolbar button translated `https://example.com`
  from English to Korean. Clicking it again preserved the translated page without
  an error or a lingering menu. The translated test tab was left open.
- The signed universal DMG passed notarization, stapling, and Gatekeeper checks.
  The installed executable matched the DMG, and only the installed extension
  remained registered. Existing extension enablement and Accessibility trust
  were retained on this Mac.
- DMG SHA-256:
  `e2f58c1a29bcd1a047abdbf7b16359ec885e7371ac938d07415642647e10a734`.

## Remaining manual checks

The `about:blank` unavailable-translation test did not produce a verifiable error
dialog through UI automation; neither extension dispatch nor the direct URL-command
attempt established the result. This is unverified, not a passing test or a proven
app defect. The blank test tab was closed.

Permission denial/reset, multiple windows, fullscreen, English system UI, older
macOS versions, and Intel hardware runtime still need separate testing. Universal
compilation does not prove runtime compatibility on those systems.

If an OS upgrade resets permission, enable the app under System Settings > Privacy
& Security. On this Korean macOS 27 host the panel is named “기기 제어 및 데이터 접근”
(Device Control & Data Access); earlier versions use Accessibility. The app does
not repeatedly request the system prompt, but explains recovery when explicitly
invoked without the required permission.

## References

- [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Safari 27 release notes](https://developer.apple.com/documentation/safari-release-notes/safari-27-release-notes)
- [Xcode 27 release notes: Intel deprecation](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [Cooperative activation](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(from:options:))
