#!/bin/bash
# Cut a Sysline release: build → ad-hoc sign → DMG → sha256 → GitHub release.
# Usage:  ./release.sh 1.1.0
# Needs: Xcode, create-dmg (brew install create-dmg), gh (authenticated).
set -euo pipefail

VERSION="${1:?usage: ./release.sh <version>  e.g. ./release.sh 1.1.0}"
REPO="azharbinanwar/Sysline"
BUILD=".release-build"
DMG="Sysline.dmg"

echo "→ Building Sysline $VERSION (Release)…"
rm -rf "$BUILD"; mkdir -p "$BUILD"
xcodebuild -scheme Sysline -configuration Release \
  -derivedDataPath "$BUILD/dd" \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  build >/dev/null
APP=$(find "$BUILD/dd/Build/Products/Release" -maxdepth 1 -name 'Sysline.app' | head -1)
[ -n "$APP" ] || { echo "✗ build produced no app"; exit 1; }

# Ad-hoc sign so it runs on any Mac once quarantine is stripped.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "→ Building DMG…"
rm -f "$DMG"
create-dmg --volname "Sysline" --window-size 480 300 \
  --icon "Sysline.app" 120 150 --app-drop-link 360 150 \
  "$DMG" "$APP" >/dev/null 2>&1 || \
  hdiutil create -volname Sysline -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

shasum -a 256 "$DMG" | awk '{print $1}' > "$DMG.sha256"
echo "→ sha256: $(cat "$DMG.sha256")"

echo "→ Publishing GitHub release v$VERSION…"
gh release create "v$VERSION" "$DMG" "$DMG.sha256" \
  --repo "$REPO" --title "Sysline $VERSION" --generate-notes

rm -rf "$BUILD"
echo "✓ Released v$VERSION"
