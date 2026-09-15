# Safari Translate Toolbar 1.1.1

[KO](RELEASE_NOTES_1.1.1.ko.md) | [EN](RELEASE_NOTES_1.1.1.md)

- Improved Safari 27 translation-menu discovery using observed control identifiers, with localized-label fallback.
- Open the translation submenu before selecting a language and recognize already-translated pages through View Original.
- Wait for Safari activation and limit menu actions to Safari while it is frontmost.
- Exclude web-content subtrees from Accessibility searches and bound traversal work.
- Updated English/Korean error guidance and added six regression tests to release packaging.
- Added macOS 27 permission-recovery guidance without repeated system prompts, plus privacy-preserving `--diagnose` status output.
- Retained macOS 13 minimum support, Apple Silicon/Intel binaries, stable app identity, and the existing one-time permission prompt.

See [macOS 27 validation](MACOS27.md) for verification scope and remaining checks.
