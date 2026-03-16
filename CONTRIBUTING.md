# Contributing to Smoke Launcher

## Prerequisites

- **Xcode 15+** (Swift 5.9)
- **macOS 13 Ventura or later**
- A Wine runtime bundle installed via the app's setup wizard (or placed manually at `~/Library/Application Support/SmokeLauncher/runtime/`)

## Getting Started

```bash
git clone https://github.com/camdenslade/Smoke-Launcher.git
cd Smoke-Launcher
open "Smoke Launcher.xcodeproj"
```

Build and run with **⌘R**. The app targets macOS 13+ with Hardened Runtime enabled.

## Project Structure

```
Smoke Launcher/
├── Managers/          # @MainActor ObservableObject managers (one per domain)
├── Models/            # Codable value types (Game, Bottle, SteamBuild)
├── ViewModels/        # LaunchViewModel, SetupViewModel, LibraryViewModel
├── Views/
│   ├── Library/       # Sidebar: LibraryView, GameRowView, AddGameView
│   ├── Detail/        # Detail pane: GameDetailView, GameSettingsView
│   ├── Setup/         # First-run: SetupView, RuntimeDownloadView, etc.
│   └── Shared/        # Reusable: GlassModifier, SteamArtworkView, LogView
└── Resources/
    └── Assets.xcassets
```

## Architecture Notes

- All managers are `@MainActor final class` conforming to `ObservableObject`. Each has an `init()` that calls its own load/check method — do **not** call `wrappedValue` on `@StateObject` from `App.init()`.
- Game launching uses `AsyncThrowingStream<String, Error>` streamed from `ShellRunner`. Avoid `waitUntilExit()` on the MainActor — use `Task.sleep` instead.
- `Game` and `Bottle` are `Codable` structs persisted as JSON in Application Support. Add new optional fields with `?` to maintain backwards compatibility.
- `SteamManager` pins a Steam build version via `steam.cfg`. If `steamui.dll` is missing on launch, the recovery path deletes `steam.cfg` and clears the pin.

## Adding a New View

1. Create the `.swift` file under the appropriate `Views/` subfolder.
2. Add it to the Xcode project target (Sources build phase in `project.pbxproj`).
3. Use `.glassCard()` for content cards and `AmbientBackground` for full-pane backgrounds.
4. Pass `@EnvironmentObject` down from `ContentView` — do not instantiate managers directly in views.

## Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR** — breaking changes to the Wine runtime format or bottle schema
- **MINOR** — new features (new manager, new game source, new UI section)
- **PATCH** — bug fixes, UI tweaks, crash fixes

Releases are tagged `vMAJOR.MINOR.PATCH` and published with a DMG attached.

## Pull Requests

1. Branch from `main`: `git checkout -b feat/my-feature`
2. Keep changes focused — one feature or fix per PR
3. Test the full setup flow (runtime install → bottle → Steam) if touching managers
4. Update `CHANGELOG.md` under `[Unreleased]`

## Reporting Issues

Open a [GitHub Issue](https://github.com/camdenslade/Smoke-Launcher/issues) with:
- macOS version and chip (Apple Silicon / Intel)
- Steps to reproduce
- Relevant log output from the Output panel in the detail view
