# Changelog

All notable changes to Sysline. Unreleased items ship with the next version.

## [Unreleased]

### Fixed
- **History no longer shrinks.** The hourly rollup pruned raw samples mid-hour,
  so every hour older than 48h permanently lost ~half its bytes on the next
  rollup. Pruning is now hour-aligned; verified by simulation (old: 50% of
  bytes kept on aged hours, new: 100%).
- **No more double-counting at the 24-hour boundary.** 7/30-day views and the
  data-plan total read hourly + raw tables split at "24h ago"; the split was
  mid-hour, so the boundary hour was counted by both sides (up to 1h of
  traffic twice). The split is now hour-aligned.
- **One bad nettop read no longer wipes the recorder's memory.** An empty
  parse cleared every per-process baseline, silently losing all traffic across
  two poll intervals. Empty reads are now ignored (covered by `--selftest`).
- **A frozen nettop can no longer stop recording forever.** The poll had no
  timeout and never drained stderr; a wedged nettop hung the loop until app
  relaunch. Now: stderr discarded, 10s watchdog kills a stuck run, partial
  output from a killed run is dropped.
- **"Always on top" off now truly behaves like a normal window.** The floating
  HUD was created with `.canJoinAllSpaces`, which on modern macOS leaks the
  window into full-screen spaces regardless of level. Off = plain managed
  window (one desktop, hidden by other apps, never over full-screen apps);
  on = floats over everything including full-screen, as before.
- **The floating HUD remembers its position.** Size changes, hide/show, and
  app relaunches no longer teleport it back to the top-right corner. Falls
  back to the default corner if the saved spot's screen is disconnected.

### Changed
- **Unresolved processes are recorded by their real name** (e.g. `adb`, `java`)
  instead of all lumping into "Other processes"; that label now only appears
  when nettop reports no name at all.
- **The daily notification reports the previous day**, not "today so far".
  At your chosen time it now reads e.g. "Daily usage report — Friday, Aug 1:
  ↓ 8.2 GB  ↑ 1.7 GB" (absolute date, download/upload split). Settings copy
  updated to match.

### Removed
- Dead code: `SpeedDial.swift` (unused duplicate of the gauge), three unused
  `Prefs` keys (`alertsEnabled`, `dailySummary`, `newNetworkAlert`),
  `Constants.Poll.interval` (unused duplicate of the poll default), and
  AppDelegate's global `UserDefaults` observer (the Settings toggle already
  applies the Dock-icon change directly).

### By design (decided, not bugs)
- Speed-test traffic stays in usage history: the user ran the test, so the
  data is genuinely consumed.
- Sysline counts all Wi-Fi bytes, including local-network traffic (e.g.
  Android Studio/adb device streaming) that doesn't consume an internet data
  package. nettop cannot tell LAN from internet.
