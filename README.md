<div align="center">

<img src="docs/icon.png" width="120" alt="Sysline icon">

# Sysline

**See which apps use your internet — and how much — over time.**

Free, open-source, on-device. A macOS menu bar app that records per-app network
usage so you can look *back*, not just watch live.

[sysline.kodeelite.com](https://sysline.kodeelite.com)

<img src="docs/main-window.png" width="800" alt="Sysline main window">

</div>

## Install

**One command — installs *and* updates.** Run it again any time to get the latest:

```bash
curl -fsSL https://sysline.kodeelite.com/install.sh | sh
```

Or with Homebrew:

```bash
brew install --cask azharbinanwar/tap/sysline
```

<sub>Not from Apple's App Store — it's a free open-source tool. The curl command handles the "unidentified developer" prompt for you. [Manual install ↓](#install--updating)</sub>

## Why

I lost **40 GB in 2 days** on a mobile hotspot and had no way to find out which
app did it. macOS doesn't keep history — Activity Monitor only shows bytes since
a process started, and forgets everything when the app quits or you reboot.

Sysline is the tool that should have existed: a lightweight logger + viewer that
remembers, so you can answer *"which app used my data, and how much, this week?"*

## Features

- **Per-app history** — download/upload per app for Today / Yesterday / 7 / 30 / 90 days / All, sorted, searchable.
- **Real app names + icons** — helper processes are folded into their parent app.
- **Counts only what left your Mac** — traffic between local apps (a simulator streaming its screen, a dev server, a local database) never touches your connection, and isn't counted. Most monitors count it anyway.
- **Wi-Fi breakdown** — tag usage by network and filter to one (e.g. isolate your hotspot to match your carrier's count).
- **Speed test** — a live download/upload test with a real-time gauge, ping + loaded latency, and per-activity ratings (Browsing / Gaming / Streaming / Video calls). Open it straight from the menu bar; history is kept with carrier and location. Free, uses Cloudflare's public endpoints — no account.
- **Floating monitor** — a small always-on-top HUD with live totals, top apps, and a trend chart. Small / Medium / Large.
- **Data-plan alerts** — set your plan limit + a "notify me at" value, get one alert when you cross it. Plus an optional daily usage reminder.
- **Light on resources** — ~0% CPU and near-zero energy at idle. Everything stays on your Mac.

## Install & updating

The command up top downloads the latest release, drops **Sysline.app** into
`/Applications`, launches it, and clears the quarantine flag so it opens without
warnings. **Re-run the same command any time to update.** Prefer to do it by
hand? Grab `Sysline.dmg` from
[Releases](https://github.com/azharbinanwar/Sysline/releases), drag it to
Applications, then **right-click → Open** the first time.

> Sysline isn't notarized by Apple (it's a free open-source tool), so macOS shows
> an "unidentified developer" prompt on a plain download. The install command
> handles that for you; the DMG and Homebrew routes need one right-click → Open,
> or `brew install --cask --no-quarantine` to skip it.

**Updating:** re-run the install command, `brew upgrade --cask sysline`, or use
**Settings → App → Updates → Check for Updates** inside the app. Sysline also
checks once a day on its own and can install the update in place.

## Screenshots

Small dialogs:

| Menu bar popover | Floating monitor | Speed test |
|---|---|---|
| <img src="docs/popover.png" width="240"> | <img src="docs/hud.png" width="240"> | <img src="docs/speed-test.png" width="240"> |

<div align="center">

<img src="docs/speed.png" width="800" alt="Speed history">

<img src="docs/dataplan.png" width="800" alt="Data-plan alerts">

<img src="docs/settings.png" width="800" alt="Settings">

</div>

## How it works

Sysline samples macOS's built-in `nettop` every few seconds, computes the
**delta** (what each process used since the last sample), tags it with the
current network, and stores it in a small SQLite database. Summing those deltas
over a date range gives per-app usage. No packet inspection, no kernel
extension — just polling a system tool and doing arithmetic.

Records only while running; launch-at-login keeps it almost always on.

## Privacy

100% on-device. Sysline makes **two kinds of network call, both yours to
trigger**: a speed test you start, and a check with GitHub for a newer version.
No accounts, no analytics, no telemetry. It's open source — read every line.

## Build from source

```bash
git clone https://github.com/azharbinanwar/Sysline.git
open Sysline/Sysline.xcodeproj   # Xcode 16+, macOS 14+
```

## License

[MIT](LICENSE) © 2026 Azhar Ali
