# MacTranslate AI — AI Translator for Mac

**Bring your own AI API key. Translate selected text. Stay in your flow.**

MacTranslate AI is a native, open-source macOS translator, installed as **iTrans**. Translate selected text with shortcuts, work from the menu bar, configure your own DeepSeek API key and compatible endpoint, and keep preferred terminology for future translations. Supports Google and DeepSeek engines, a local CLI, and an optional Agent Gateway.

**Requires macOS 14+** · [Download](https://github.com/cduyzh/iTrans/releases) · [简体中文](README.zh-CN.md)

> Previously known as TransBar.

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://github.com/cduyzh/iTrans/releases)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://github.com/cduyzh/iTrans)
[![Architecture: Universal 2](https://img.shields.io/badge/Arch-Apple%20Silicon%20%7C%20Intel-blue?style=flat-square)](https://github.com/cduyzh/iTrans/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Author](https://img.shields.io/badge/Author-cduyzh-blue?style=flat-square)](https://github.com/cduyzh)

**English** · [简体中文](README.zh-CN.md)

---

## Key Features

- **Blazing Fast Native Performance**
  - Pure native SwiftUI/AppKit architecture with launch times under 200ms and minimal memory footprint.
  - Zero third-party closed-source dependencies; native macOS 14+ Sonoma, Sequoia, and beyond.
- **Dual Engine Architecture**
  - **Google Web RPC**: 60~120ms ultra-low latency, zero configuration, free and ready out-of-the-box.
  - **DeepSeek AI Reasoning**: Deep context understanding, full Markdown preservation, independent foldable thinking process (Reasoning Content).
- **Universal 2 Architecture (Apple Silicon & Intel Mac)**
  - Native performance on both Apple Silicon (M1/M2/M3/M4) and Intel (x86_64) Macs without Rosetta 2 translation overhead.
- **Quiet Signal Status Panel**
  - **Left Click**: Instant primary translation HUD.
  - **Right Click**: 5-Zone high-density frosted glass Status Control Panel (NSPopover) with engine toggle (`⌥E`), glossary access (`⌥M`), real-time usage stats (`⌥S`), and permission health checks.
- **Local Self-Learning Memory & Knowledge Base**
  - Instant 1ms lookup for previously translated terms and sentences.
  - Domain glossary injection (Computer & AI, Legal, Finance, Slang) with custom token budget guards.
- **API Health & Connectivity Inspector**
  - Persistent, clear status badge for API Key availability (`API call successful · latency 180ms · models verified`) so you never have to test repeatedly.
- **Local Loopback Agent Gateway (`127.0.0.1:11899`)**
  - Provides standard HTTP REST endpoints for external scripts, Claude Desktop, Cursor, or autonomous local agents.
- **100% Local-First Privacy**
  - API keys stored in restricted private files (`0600` permissions) under `~/Library/Application Support/cduyzhTranslator/`.
  - Zero Keychain authorization prompts; no telemetry, tracking, or unexpected background network egress.

---

## Download & Installation

### Option 1: Download Pre-built DMG (Recommended)

Download the latest release from [GitHub Releases](https://github.com/cduyzh/iTrans/releases):

- **Universal 2 Build**: `iTrans-1.0.0-universal.dmg` (Runs natively on both Apple Silicon & Intel Mac)
- **Apple Silicon Build**: `iTrans-1.0.0-arm64.dmg` (M1/M2/M3/M4 optimized)
- **Intel Mac Build**: `iTrans-1.0.0-x86_64.dmg` (Intel Core i5/i7/i9)

#### Installation Steps:
1. Double-click the downloaded `.dmg` file.
2. Drag `iTrans.app` into your **Applications** folder.
3. Eject the DMG and launch iTrans from **Applications** or Spotlight.

> **Note on Permissions**:
> TransBar uses macOS Accessibility APIs for double `⌘C` selection translation. On first launch, open **System Settings → Privacy & Security → Accessibility** and enable `iTrans`. If you prefer not granting permissions, `Option+Z` or manual input works without any extra permissions.

---

### Option 2: Clone & Build from Source

Requirements:
- macOS 14.0 or higher
- Xcode 15+ or Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

```bash
# 1. Clone the repository
git clone https://github.com/cduyzh/iTrans.git
cd TransBar

# 2. Run automated tests to verify environment
./scripts/run_tests.sh

# 3. Build and package the application
# Default builds a Universal 2 application (Apple Silicon + Intel)
./build_app.sh

# Or build for specific architecture:
# ./build_app.sh --arm64    # Apple Silicon only
# ./build_app.sh --x86_64   # Intel Mac only
# ./build_app.sh --native   # Current host architecture only
```

The compiled application bundle will be created at `.build.noindex/iTrans.app`. Double-click to run or launch via:

```bash
open .build.noindex/iTrans.app
```

---

## Shortcuts & Usage

| Action | Shortcut / Trigger | Description |
| --- | --- | --- |
| **Translate Selection** | `⌘C ⌘C` (Double Command+C) | Select any text across apps and double-tap `⌘C` for instant popup translation |
| **Summon Panel** | `⌥Z` / `⌃Z` | Open/hide the floating translation panel anywhere |
| **Switch Engine** | `⌥E` | Switch between Google and DeepSeek |
| **Personal Memory** | `⌥M` | Open terminology and memory management |
| **Usage Stats** | `⌥S` | View translation counts, latency, and token metrics |
| **Menu Bar Left Click** | Left click icon | Open translation main window |
| **Menu Bar Right Click**| Right click icon | Open frosted glass Status Control Panel |

---

## Local Agent Gateway API

When enabled in Settings, TransBar hosts a lightweight local HTTP server at `http://127.0.0.1:11899`:

| Method | Endpoint | Description |
| --- | --- | --- |
| `POST` | `/v1/translate` | Translate text via selected engine |
| `GET` | `/v1/memory` | Retrieve local personal memory items |
| `GET` | `/v1/knowledge-base` | Overview of domain terminology categories |
| `POST` | `/v1/knowledge-base/import`| Batch import terminology in JSON/CSV |
| `GET` | `/v1/stats` | Export usage statistics and cost estimations |
| `GET` | `/v1/version` | Read current app version |
| `GET` | `/v1/changelog` | Read structured release notes |

### Example cURL:

```bash
curl -X POST http://127.0.0.1:11899/v1/translate \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "Evaluating zero-shot transfer capabilities.",
    "source_lang": "en",
    "target_lang": "zh-CN",
    "engine": "deepseek"
  }'
```

---

## Privacy & Security Commitment

- **Zero Cloud Data Retention**: Your text is never stored on external third-party servers operated by TransBar. Text is transmitted solely to the translation provider you select (Google or DeepSeek).
- **Private Key Isolation**: DeepSeek API Keys are stored strictly on-disk with owner-only `0600` permissions (`~/Library/Application Support/cduyzhTranslator/deepseek-api-key`). We do not use the system Keychain to prevent intrusive system password prompts during binary updates.
- **No Analytics / Telemetry**: No tracking SDKs, no behavioral analysis, no telemetry pings.

---

## License

TransBar is open source software licensed under the [MIT License](LICENSE).

## Author

**cduyzh**
- GitHub: [https://github.com/cduyzh](https://github.com/cduyzh)
- Website: [https://www.cduyzh.top](https://www.cduyzh.top)
- Goal: [https://www.cduyzh.top/goal](https://www.cduyzh.top/goal)
