# Safari Translate Toolbar 1.2.0

[KO](RELEASE_NOTES_1.2.0.ko.md) | [EN](RELEASE_NOTES_1.2.0.md)

- Click to translate; click again to restore the original. Each click uses Safari's actual menu state, not a click counter.
- Confirmed translation shows an active icon and `ON` badge; restoring the original clears them. `…` means pending, `?` means unconfirmed. Safari controls the final toolbar colors.
- Keep indicators separate per tab, reset on navigation, and discard stale replies. Ignore repeated clicks while a request is pending.
- Preserve minimal `nativeMessaging` permission: no webpage content, URL/title access, or persistent translation-state storage. Messages add only an opaque per-click UUID and a state result.
- Retain macOS 13+ and universal Apple Silicon/Intel binaries, with Developer ID signing and Apple notarization.

Eight Swift and eleven JavaScript tests passed. On macOS 27 / Safari 27 with Korean UI, the installed app was verified through translation → original → translation, tab switching, and reload.

The badge is the last confirmed result, not continuous monitoring of Safari's own menu. Keep the same tab/window in front during a request. Permission denial/reset, multiple profiles, English system UI, older macOS, Intel hardware, and slow/failing translations need further manual checks. See [validation details](TOGGLE.md).
