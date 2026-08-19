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
- It checks only the titles, descriptions, help text, and identifiers of translation-related controls.
- It does not read `AXValue`, which could expose page input values.
- It does not write search results to disk or send them over a network.
- It does not read or store webpage content.
- It exits immediately after starting translation.

macOS TCC manages the permission itself. The app stores one boolean in `UserDefaults` indicating that it already attempted the system permission prompt. This contains no user information and prevents a repeated prompt loop.

## App Sandbox and entitlements

- Container app: App Sandbox disabled because Safari UI automation requires it
- Embedded Safari extension: App Sandbox enabled
- No network, file, App Group, or `get-task-allow` entitlement
- Hardened Runtime enabled for both executable targets

Release checks fail if `AXValue`, network/file/clipboard APIs, extension permissions, or required localization resources change unexpectedly.
