# Smoke Launcher

A native macOS launcher for Windows games via Wine, with a liquid glass SwiftUI interface and deep Steam integration.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

---

## Features

- **Automatic Steam game detection** — Parses Steam ACF manifests to find installed games and artwork when Steam closes
- **Wine bottle management** — Create isolated Wine environments with per-bottle DXVK (DirectX → Metal) and ESync toggles
- **Steam CDN artwork** — Game icons and hero banners pulled from Valve's CDN automatically
- **Liquid glass UI** — Deep charcoal color scheme with `ultraThinMaterial` glass cards, ambient background art, and smooth animations
- **One-click Steam** — Launch the Steam UI into a managed Wine bottle straight from the toolbar
- **Live output log** — See Wine/game stdout in real time from the detail pane

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac
- Wine runtime (downloaded automatically during setup)

## Installation

1. Download the latest `SmokeLauncher.dmg` from [Releases](https://github.com/camdenslade/Smoke-Launcher/releases)
2. Open the DMG and drag **Smoke Launcher** to your Applications folder
3. Launch the app — the setup wizard will guide you through installing the Wine runtime and Steam

## Building from Source

See [CONTRIBUTING.md](CONTRIBUTING.md) for full setup instructions.

```bash
git clone https://github.com/camdenslade/Smoke-Launcher.git
cd Smoke-Launcher
open "Smoke Launcher.xcodeproj"
```

Then build and run with **⌘R** in Xcode.

## How It Works

```
Smoke Launcher
├── Managers/
│   ├── RuntimeManager   — Downloads & verifies the Wine runtime bundle
│   ├── BottleManager    — Creates and manages Wine prefix environments
│   ├── SteamManager     — Installs Steam, pins versions, launches Steam UI
│   └── GameManager      — Scans ACF manifests, registers & launches games
├── Views/
│   ├── Library/         — Sidebar game list with glass row cards
│   ├── Detail/          — Hero banner, play button, output log
│   ├── Setup/           — First-run wizard (runtime → bottle → Steam)
│   └── Shared/          — GlassModifier, SteamArtworkView, LogView
└── Models/
    ├── Game             — Codable game record with steamAppID
    ├── Bottle           — Wine prefix with DXVK/ESync flags
    └── SteamBuild       — Pinned Steam version metadata
```

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (macOS 13+) |
| Concurrency | Swift async/await, AsyncThrowingStream |
| Wine | Wine via managed runtime bundle |
| GPU translation | DXVK (DirectX → Metal via MoltenVK) |
| Artwork | Steam CDN via AsyncImage |
| Persistence | JSON-encoded models in Application Support |

## License

MIT — see [LICENSE](LICENSE)
