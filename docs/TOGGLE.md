# Translation toggle (1.2.0)

[KO](TOGGLE.ko.md) | [EN](TOGGLE.md)

## Behavior

- An enabled native View Original command selects restoration; otherwise the
  app selects a translation language. The badge never decides the action.
- The app briefly rechecks the native menu after invoking the command. Only the
  expected state lights `ON` or clears it. Missing, failed, or timed-out confirmation
  shows `?`; `…` means pending. Color is best effort because Safari controls toolbar
  rendering; the active SVG also changes shape and has an `ON` badge.
- An opaque UUID associates each app response with its click. Tab loading, closing,
  or switching during a request invalidates the response. Rapid clicks are ignored.
- The badge is the last confirmed result, not continuous monitoring. Safari-menu
  changes made outside this extension are checked on the next click. Browser
  startup/update and navigation clear old indicators; background suspension alone
  does not. A slow translation can finish after the confirmation timeout.
- Keep the same Safari tab/window in front until completion. Native Accessibility
  actions target Safari's focused page; the extension does not read page URLs to
  identify a tab, and discarding feedback cannot undo an already issued command.

## Validation

Run `./scripts/source-audit.sh`, `./scripts/test.sh` (Xcode plus Node.js 18+),
an unsigned universal Xcode build, and `git diff --check`.
Swift tests cover original-command matching, toggle decisions, confirmation, and
web-content pruning. Mocked JavaScript tests cover reply correlation, timeouts,
failed delivery, rapid clicks, navigation, tab/window changes, background lifecycle,
unsupported badge coloring, and absence of URL/title access.

On September 19, 2026, version 1.2.0 (5) was signed, notarized, and installed on
macOS 27.0 (26A428), Safari 27, Apple Silicon. The existing 1.1.1 installation was
backed up; Accessibility trust and extension enablement remained intact.
Eight Swift and eleven JavaScript tests, source audit, unsigned universal build,
signed app/DMG checks, and Gatekeeper passed.

On `https://example.com`, the real extension button completed English → Korean →
English → Korean. The `ON` badge and original-page tooltip appeared only after
confirmation and cleared on restoration. A new tab stayed neutral; returning to
the translated tab retained its indicator. Reload returned the page and indicator
to the original/neutral state. Native-port delivery was exercised end to end.
Safari rendered the badge in its own color rather than the requested blue.

Permission denial/reset, multiple profiles, English system UI, older macOS, Intel
hardware runtime, and slow/failing network translations still need manual tests.
This report records validation for v1.2.0; older release assets remain unchanged.

DMG SHA-256: `512a35481dc4e5c7740959b5990de51eeed9872e76126a81d5e93e34d9dc1f15`.

## References

- [Apple native messaging](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension)
- [Toolbar icon API](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/action/setIcon)
