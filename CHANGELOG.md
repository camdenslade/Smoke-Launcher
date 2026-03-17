# Changelog

All notable changes to Smoke Launcher are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.2] - 2026-03-16

### Added
- Playtime tracking: total time played is accumulated per session and shown in the sidebar and detail pane
- Sort library by last played, name, or play time - persisted across launches
- Launch arguments field in game settings
- Save backup: zips `drive_c/users` from the Wine bottle to `~/Library/Application Support/SmokeLauncher/backups/`
- Game rename, bottle picker, and delete button in game settings
- Trial mode: 3 free launches, then a paywall (Stripe)
- Exit notification: system notification when a game process closes
- Wine error parsing: actionable errors surfaced in the output log instead of raw debug noise
- "Check for Updates" menu item linking to GitHub releases

### Fixed
- Hero banner art now scales proportionally to any window width with no cropping
- Sidebar icons now load from Steam's local librarycache (`appcache/librarycache/{appID}/*.jpg`) - no network request, shows the actual game icon
- `WINEDEBUG` changed from `-all` to targeted channels so the Wine error parser receives output
- Steam App ID field restricted to digits only
- Backup filename sanitized to prevent path traversal

---

## [1.0.1] - 2026-03-16

### Fixed
- Steam artwork now resolves correctly for newer games by falling back to the Store API when the legacy CDN path returns 404
- Sidebar game icons now use Steam's dedicated square community icons instead of a cropped header image
- Hero banner art displays at the correct 460x215 aspect ratio instead of being aggressively cropped

### Added
- App icon (dock and title bar) now shows the Smoke Launcher logo

---

## [1.0.0] - 2026-03-16

### Added
- First public release
- Native macOS launcher with SwiftUI liquid glass interface
- Wine bottle management with per-bottle DXVK (DirectX → Metal) and ESync toggles
- Automatic Steam game detection via ACF manifest parsing
- Steam CDN artwork: game icons and hero banners via `AsyncImage`
- Ambient background art in the detail pane derived from the selected game's header image
- One-click Steam UI launch into a managed Wine bottle
- First-run setup wizard: Wine runtime download → bottle creation → Steam install
- Steam bootstrap recovery: detects missing `steamui.dll` and clears version pin automatically
- `-cefdisable` flag suppresses `steamwebhelper.exe` / CEF crashes on launch
- Wine AeDebug registry fix suppresses Wine Debugger popup on game crashes
- Live stdout log streamed from running game process
- Auto-scan banner: games detected from ACF manifests are silently added when Steam closes
- Backfill pass populates `steamAppID` for games added before artwork support
- Glass card modifier (`ultraThinMaterial` + gradient overlay + gradient stroke border)
- `AmbientBackground` view: blurred game art over charcoal with `plusLighter` blend
- Deep charcoal color scheme forced dark mode app-wide

[1.0.2]: https://github.com/camdenslade/Smoke-Launcher/releases/tag/v1.0.2
[1.0.1]: https://github.com/camdenslade/Smoke-Launcher/releases/tag/v1.0.1
[1.0.0]: https://github.com/camdenslade/Smoke-Launcher/releases/tag/v1.0.0
