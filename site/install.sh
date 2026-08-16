#!/bin/sh
# Sysline installer — downloads the latest release, verifies it, installs to /Applications.
# Usage: curl -fsSL sysline.kodeelite.com/install.sh | sh
set -eu

URL="https://github.com/azharbinanwar/Sysline/releases/latest/download/Sysline.dmg"
TMP="$(mktemp -d)"
MNT=""
cleanup() {
  [ -n "$MNT" ] && hdiutil detach "$MNT" -quiet 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Sysline…"
curl -fL --progress-bar "$URL" -o "$TMP/Sysline.dmg"

if curl -fsL "$URL.sha256" -o "$TMP/Sysline.dmg.sha256" 2>/dev/null; then
  want="$(awk '{print $1}' "$TMP/Sysline.dmg.sha256")"
  got="$(shasum -a 256 "$TMP/Sysline.dmg" | awk '{print $1}')"
  if [ "$want" != "$got" ]; then
    echo "Checksum mismatch — download may be corrupted. Aborting." >&2
    exit 1
  fi
  echo "Checksum verified."
fi

MNT="$(hdiutil attach "$TMP/Sysline.dmg" -nobrowse -readonly | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
echo "Installing to /Applications…"
osascript -e 'quit app "Sysline"' >/dev/null 2>&1 || true
rm -rf /Applications/Sysline.app
ditto "$MNT/Sysline.app" /Applications/Sysline.app
hdiutil detach "$MNT" -quiet
MNT=""

# Clear Gatekeeper quarantine so first launch doesn't need right-click → Open.
xattr -dr com.apple.quarantine /Applications/Sysline.app 2>/dev/null || true

echo "✓ Sysline installed."
open /Applications/Sysline.app
