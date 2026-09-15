# Privacy and permissions

English | [한국어](PRIVACY.ko.md)

## Data collection

None.

This app has no account system, server, network requests, analytics SDK, advertising SDK, crash collector, update tracker, or remote logging. The source does not store the developer's personal name, email address, home-directory path, Apple ID, or notarization password.

The signed app contains the legal signer name and Team ID from Apple's Developer ID certificate. This is public signing information required by Gatekeeper to verify the distributor. The source configuration contains only the Team ID needed for public identity.

## Safari extension permissions

The manifest declares exactly one permission: `nativeMessaging`.

- No permission to read webpage content
- No access to all websites
- No content scripts
- No collection of tab URLs or titles
- No clipboard permission
- No network permission

When the toolbar button is clicked, `nativeMessaging` sends only the fixed local command `{ "command": "translate" }` to the container app. It does not send page content, URLs, cookies, or form input.

## macOS Accessibility permission

Safari does not provide a public extension API for starting its built-in Apple translation. The container app therefore uses macOS Accessibility to find and press the translation command in the current Safari window.

- The target process is fixed to bundle ID `com.apple.Safari`.
- The search is constrained by role to Safari's toolbar, menus, and popovers.
- Traversal stops at `AXWebArea` before enumerating its children; webpage toolbars and menus cannot become translation candidates. Elements with unreadable roles are skipped.
- It checks only the titles, descriptions, help text, and identifiers of translation-related controls.
- It does not read `AXValue`, which could expose page input values.
- It does not write search results to disk or send them over a network.
- It does not read or store webpage content.
- It exits immediately after starting translation.

Menu dismissal first uses the menu's Accessibility cancel action. Its Escape fallback targets only the Safari process while Safari is frontmost.

macOS TCC manages the permission itself. The app stores one boolean in `UserDefaults` indicating that it already attempted the system permission prompt. This contains no user information and prevents a repeated prompt loop.

If that permission is later missing, an explicit translation attempt shows localized recovery guidance instead of repeatedly requesting the system prompt. macOS 27 installation guidance accounts for the renamed Device Control & Data Access panel (observed in Korean as “기기 제어 및 데이터 접근”).

The optional command-line `--diagnose` mode prints only the app version, macOS major version, and current Accessibility trust status. It does not inspect Safari, request permission, save a report, or transmit data.

## App Sandbox and entitlements

- Container app: App Sandbox disabled because Safari UI automation requires it
- Embedded Safari extension: App Sandbox enabled
- No network, file, App Group, or `get-task-allow` entitlement
- Hardened Runtime enabled for both executable targets

Release checks fail if `AXValue`, network/file/clipboard APIs, extension permissions, or required localization resources change unexpectedly.

## v1.1.1 pre-publication review

On September 15, 2026, the source, reachable local Git history, notarized DMG,
embedded app/extension, image metadata, and extended attributes were checked.
No unnecessary personal email, home-directory path, credential, or private key
was found within that scope. Git authors and committers use the public GitHub
username and GitHub noreply address. App-icon EXIF contains only pixel dimensions;
no author or location metadata was found. Local build logs and backups are excluded
from Git and release attachments.

The Developer ID signer name and Team ID remain in the signatures. The DMG's
local extended attributes include disk-image checksum metadata; GitHub asset
uploads transfer the file bytes, not those filesystem attributes. This review is
not a guarantee that every possible secret format or runtime issue has been ruled
out. See [validation scope](MACOS27.md) for the remaining manual tests.
