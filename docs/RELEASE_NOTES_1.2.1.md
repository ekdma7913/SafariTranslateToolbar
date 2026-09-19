# Safari Translate Toolbar 1.2.1

[KO](RELEASE_NOTES_1.2.1.ko.md) | [EN](RELEASE_NOTES_1.2.1.md)

- Remove overlapping `ON`, `…`, and `?` text badges, including badges left by 1.2.0.
- Show a circled checkmark for confirmed translation, an hourglass while pending, and the default icon for original or unconfirmed states. Hover for the state description. Safari controls icon colors.
- Preserve click-to-translate/click-to-restore behavior and existing per-tab state safeguards.
- Add no permissions, page-content access, or data collection. The source and DMG privacy review found no unnecessary personal data or credentials within its scope; public Developer ID signing identity remains visible.
- Retain macOS 13+ and universal Apple Silicon/Intel binaries. Build 6 is Developer ID signed and Apple notarized.

Eight Swift and eleven JavaScript tests, source audit, signed app/DMG checks, and Gatekeeper passed. On Korean macOS 27 / Safari 27, the installed app restored the original and translated again; the default/check icons appeared without text badges. The brief pending hourglass is covered by mocked tests but was not visually captured.

Download the DMG from this release and replace the app in Applications. Existing installations do not auto-update.

The icon is the last confirmed result, not a continuous monitor. Keep the same tab/window in front until completion. Permission denial/reset, multiple profiles, English system UI, older macOS, Intel hardware, and slow/failing translations still need manual checks. See [validation details](TOGGLE.md).
