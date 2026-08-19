# Safari Translate Toolbar

[KO](README.ko.md) | [EN](README.md)

A macOS app and Safari Web Extension that runs Safari's **built-in Apple translation** from a toolbar button beside the address bar. It does not use a separate translation server or inject scripts into webpages.

## Current status

- App: `com.team95788x96a7.safari-translate-toolbar`
- Extension: `com.team95788x96a7.safari-translate-toolbar.Extension`
- Version: `1.1.0 (2)`
- Languages: English and Korean
- Minimum macOS: 13.0
- Architectures: Apple Silicon `arm64` and Intel `x86_64`
- Distribution: Developer ID signed, Hardened Runtime, Apple-notarized and stapled DMG

Keep the app and extension bundle identifiers and Team ID stable after publishing. macOS uses this identity to recognize updates as the same app and to preserve Accessibility permission where possible.

## Download

Download the latest `SafariTranslateToolbar-version.dmg` from [GitHub Releases](https://github.com/ekdma7913/SafariTranslateToolbar/releases/latest). The matching `.sha256` file can verify download integrity.

```sh
shasum -a 256 -c SafariTranslateToolbar-1.1.0.dmg.sha256
```

## Language support

The app follows its per-app language preference in macOS when one is set, otherwise it follows the system language.

- Korean environment: app and extension names, toolbar description, and error messages appear in Korean.
- Any other environment: English is used as the default language.

The language into which Safari translates a webpage is separate from this app's display language. Safari chooses the target language based on Safari/macOS language settings and Apple translation availability.

## How it works

```text
Safari toolbar button
  → nativeMessaging calls the local extension handler
  → a private URL scheme launches the container app
  → Accessibility selects Safari's View > Translate command
  → Safari runs Apple translation
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

The signed and notarized build does not require Safari's “Allow Unsigned Extensions” setting. If Accessibility permission was denied or manually reset, enable the app in System Settings > Privacy & Security > Accessibility. The app does not repeatedly show the system prompt after a denial.

## Development and release

Requirements:

- Xcode and the macOS SDK
- A valid Developer ID Application certificate and private key for Team `95788X96A7`
- An app-specific Apple ID password or App Store Connect API key only when notarizing

```sh
./scripts/source-audit.sh
./scripts/release.sh
./scripts/configure-notary.sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.1.0.dmg
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
