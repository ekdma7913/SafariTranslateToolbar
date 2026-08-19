# Developer ID and DMG distribution

English | [한국어](DISTRIBUTION.ko.md)

## 1. Distribution model

This project is distributed as a direct web download rather than through the Mac App Store. Every executable is signed with Developer ID Application, the outer DMG is submitted to Apple's notarization service, and the notarization ticket is stapled. The Safari extension is embedded in the container app and signed by the same Team.

## 2. Signing configuration

- Container app: App Sandbox `NO`, Hardened Runtime `YES`
- Safari extension: App Sandbox `YES`, Hardened Runtime `YES`
- App and extension: Developer ID Application with secure timestamp in Release
- No `get-task-allow`, network, user-selected file, or App Group capability

The app uses only Apple's `SafariServices`, `AppKit/Cocoa`, and `ApplicationServices` frameworks. It has no third-party library or remote service.

## 3. Build a signed DMG

```sh
./scripts/release.sh
```

The script audits source, permissions, and localization resources; creates a universal Xcode Archive; then produces a signed UDZO DMG containing the app plus English and Korean installation guides. It also creates a matching `.sha256` file. The certificate name is not stored in source: the script finds a Keychain identity matching the Team ID.

## 4. Store notarization credentials

```sh
./scripts/configure-notary.sh
```

Provide the Apple ID and app-specific password only in Apple's interactive prompt. They are stored in macOS Keychain, not in the repository, environment files, README, or shell command line. Do not copy App Store Connect `.p8` private keys into the repository.

## 5. Notarize and staple

```sh
./scripts/notarize.sh dist/SafariTranslateToolbar-1.1.0.dmg
```

The script checks the DMG signature, runs `notarytool submit --wait`, saves the result and log, staples only an Accepted submission, and verifies the staple and Gatekeeper assessment.

## 6. Manual pre-release checks

1. Install from a quarantined DMG.
2. Copy the app to `/Applications`.
3. Confirm the first launch opens Safari extension settings without a Gatekeeper warning.
4. Check app and extension names and messages in both English and Korean environments.
5. Enable the extension and confirm the toolbar button appears.
6. Allow Accessibility on a translatable page and run translation.
7. Restart the apps and Mac and confirm permission and operation remain intact.
8. Deny permission and confirm the request does not loop.

## 7. GitHub Release

Attach only a notarized and manually verified DMG to a GitHub Release. `dist/` is intentionally not tracked by Git.

```sh
gh release create v1.1.0 \
  dist/SafariTranslateToolbar-1.1.0.dmg \
  dist/SafariTranslateToolbar-1.1.0.dmg.sha256 \
  --title "Safari Translate Toolbar 1.1.0" \
  --notes-file docs/RELEASE_NOTES_1.1.0.md
```

Do not silently replace an already published asset with the same filename. Create a new version so users can identify the binary they downloaded.

## 8. Values to keep stable

- App and extension bundle identifiers
- Developer Team ID
- URL scheme
- App executable name
- `/Applications` installation flow

When a certificate expires, sign the next release with a new Developer ID Application certificate from the same Team.
