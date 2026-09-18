# Safari Translate Toolbar

[KO](README.ko.md) | [EN](README.md)

A macOS app and Safari Web Extension that runs Safari's **built-in Apple translation** from a toolbar button beside the address bar. It does not use a separate translation server or inject scripts into webpages.

## Current status

- App: `com.team95788x96a7.safari-translate-toolbar`
- Extension: `com.team95788x96a7.safari-translate-toolbar.Extension`
- Source version: `1.2.0 (5)`; see GitHub Releases for published binaries
- Languages: English and Korean
- Minimum macOS: 13.0
- Architectures: Apple Silicon `arm64` and Intel `x86_64`
- Distribution: Developer ID signed, Hardened Runtime, Apple-notarized and stapled DMG

Keep the app and extension bundle identifiers and Team ID stable after publishing. macOS uses this identity to recognize updates as the same app and to preserve Accessibility permission where possible.

## Download

Download the latest `SafariTranslateToolbar-version.dmg` from [GitHub Releases](https://github.com/ekdma7913/SafariTranslateToolbar/releases/latest). The matching `.sha256` file can verify download integrity.

```sh
shasum -a 256 -c SafariTranslateToolbar-1.2.0.dmg.sha256
```

## Language support

The app follows its per-app language preference in macOS when one is set, otherwise it follows the system language.

- Korean environment: app and extension names, toolbar description, and error messages appear in Korean.
- Any other environment: English is used as the default language.

The language into which Safari translates a webpage is separate from this app's display language. Safari chooses the target language based on Safari/macOS language settings and Apple translation availability.

## How it works

Click once to translate; click again to restore the original. A confirmed translated
state shows an active icon and `ON` badge; restoring the original clears them.
`…` means a request is pending and `?` means the state could not be confirmed.
Safari may render toolbar icons/badges with its own colors, so the shape and text
also distinguish the states. Rapid clicks while a request is pending are ignored.

The indicator records the last state confirmed through this button, not a live
monitor of Safari's own menu. Navigation or a browser restart clears it; manual
translation-menu changes are reconciled on the next click. Each click reads Safari's
actual menu state to choose translation or restoration, regardless of the badge.
See [toggle validation and limitations](docs/TOGGLE.md) for tested behavior and remaining checks.

```text
Safari toolbar button
  → nativeMessaging calls the local extension handler
  → a private URL scheme launches the container app
  → Accessibility selects Safari's Translate or View Original command
  → the app confirms menu state and replies through native messaging
  → the originating tab's toolbar indicator updates
```

Safari does not expose a public extension API for directly starting its built-in translation. The container app therefore presses the translation command already present in Safari's UI. Major Safari or macOS menu changes may require an update to the Accessibility matching logic.

## Installation

Use only the **notarized DMG** for external distribution.

1. Open the DMG and drag `SafariTranslateToolbar.app` to `Applications`.
2. Open the app once from Applications.
3. In Safari Settings > Extensions, enable `Safari Translate Button`.
4. If the button is missing, add it using Customize Toolbar in Safari.
5. Open a translatable page and click the button.
6. Allow the one-time macOS Accessibility request.

The signed and notarized build does not require Safari's “Allow Unsigned Extensions” setting. If control permission was denied or reset, enable the app in System Settings > Privacy & Security > Device Control & Data Access on macOS 27, or Accessibility on earlier versions. The app does not repeat the system permission prompt; a requested translation shows recovery guidance if access is still missing.

## Development and release

The working tree includes macOS 27 / Safari 27 compatibility improvements.
See [compatibility checks and remaining installation tests](docs/MACOS27.md).
Existing installations are not updated automatically. Download and install the new DMG to update.

Requirements:

- Xcode and the macOS SDK
- Node.js 18+ for the toolbar-state regression tests
- A valid Developer ID Application certificate and private key for Team `95788X96A7`
- An app-specific Apple ID password or App Store Connect API key only when notarizing

```sh
./scripts/source-audit.sh
./scripts/test.sh
./scripts/release.sh
./scripts/configure-notary.sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.2.0.dmg
```

Use `./scripts/release.sh --notarize` to build and notarize in one command. Enter Apple credentials only in Apple's interactive `notarytool` prompt; never store them in the project.

See [distribution](docs/DISTRIBUTION.md), [privacy](docs/PRIVACY.md), and [GitHub maintenance](docs/GITHUB_WORKFLOW.md) for details.

## License

The source code is available under the [MIT License](LICENSE).

## Key files

- `SafariTranslateToolbar/.../AppDelegate.swift`: starts Safari translation and presents localized errors
- `SafariTranslateToolbar/.../*.lproj`: English and Korean strings for the macOS app and native extension
- `SafariTranslateToolbar/... Extension/Resources/_locales`: English and Korean WebExtension strings
- `scripts/source-audit.sh`: checks permissions, privacy boundaries, and localization resources
- `scripts/release.sh`: creates a signed universal app and DMG
- `scripts/verify-release.sh`: verifies signatures, entitlements, architectures, and localization resources

## Apple documentation

- [Localizing your app](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LocalizingYourApp/LocalizingYourApp.html)
- [Creating a Safari web extension](https://developer.apple.com/documentation/safariservices/creating-a-safari-web-extension)
- [Distributing your Safari web extension](https://developer.apple.com/documentation/safariservices/distributing-your-safari-web-extension)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
