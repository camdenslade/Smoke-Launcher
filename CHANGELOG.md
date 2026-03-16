# Changelog

All notable changes to Smoke Launcher are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

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

[1.0.0]: https://github.com/camdenslade/Smoke-Launcher/releases/tag/v1.0.0
