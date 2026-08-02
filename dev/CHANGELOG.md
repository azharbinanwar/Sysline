# Changelog

All notable changes to Sysline. Unreleased items ship with the next version.

## [Unreleased]

### Added
- "90 Days" and "All" view ranges in the main window (popover and floating
  HUD keep the light Today→30 Days set).

### Fixed
- A damaged database no longer crash-loops the app — the bad file is set
  aside (never deleted) and a fresh one is created.
- History older than 48h no longer loses data to the hourly rollup.
- 7/30-day totals no longer double-count the hour at the 24h boundary.
- Chart day-bars now split at local midnight, not UTC.
- A bad nettop read no longer wipes the recorder's baselines, and a frozen
  nettop is killed after 10s instead of stopping recording until relaunch.
- "Always on top" off now behaves like a normal window — including never
  appearing over full-screen apps.
- The floating HUD remembers its position across size changes and relaunches.

### Changed
- Redesigned the speed test: a speedometer with a real tick scale up to
  1000 Mbps (log-style, so slow speeds stay readable), a peak marker, and a
  Download/Upload/Ping stat row. The old 0–100 dial pegged on fast lines.
- Unknown processes are recorded by their real name (e.g. `adb`) instead of
  all lumping into "Other processes".
- The daily notification now reports the previous day with date and
  download/upload split.

### Removed
- Dead code: unused gauge view, unused preference keys, duplicate poll
  constant, redundant defaults observer.
