#!/bin/bash
# Sysline installer / updater — run the same command any time to install or update:
#   curl -fsSL https://raw.githubusercontent.com/azharbinanwar/Sysline/main/install.sh | bash
set -euo pipefail

REPO="azharbinanwar/Sysline"
APP="/Applications/Sysline.app"

echo "→ Finding the latest Sysline release…"
DMG_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*Sysline\.dmg"' | head -1 | cut -d'"' -f4)
[ -n "$DMG_URL" ] || { echo "✗ No Sysline.dmg in the latest release yet."; exit 1; }

TMP=$(mktemp -d); MOUNT=$(mktemp -d)
trap 'hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; rm -rf "$TMP" "$MOUNT"' EXIT

echo "→ Downloading…"
curl -fsSL "$DMG_URL" -o "$TMP/Sysline.dmg"

echo "→ Installing to /Applications…"
osascript -e 'quit app "Sysline"' >/dev/null 2>&1 || true
sleep 1
hdiutil attach "$TMP/Sysline.dmg" -nobrowse -noautoopen -mountpoint "$MOUNT" >/dev/null
rm -rf "$APP"
cp -R "$MOUNT/Sysline.app" /Applications/

# Let Gatekeeper open it without the "unidentified developer" prompt.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "✓ Sysline installed. Launching…"
open "$APP"
