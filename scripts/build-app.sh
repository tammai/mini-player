#!/bin/bash
# Assembles build/MiniPlayer.app (ad-hoc signed) with the adapter bundled inside.
# Run scripts/build-adapter.sh first, or point ADAPTER_DIR at a built adapter checkout.
#
# SIGN_IDENTITY picks the signing certificate (see `security find-identity -v -p codesigning`). The default,
# "-", signs ad hoc, which gives every build a new identity, so macOS asks for the Screen Recording permission
# again after each rebuild. A real certificate keeps one identity, and the permission survives rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

ADAPTER_DIR="${ADAPTER_DIR:-vendor/mediaremote-adapter}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ ! -d "$ADAPTER_DIR/build/MediaRemoteAdapter.framework" ]; then
  echo "Adapter not built at $ADAPTER_DIR. Run scripts/build-adapter.sh first." >&2
  exit 1
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/MiniPlayer"

APP=build/MiniPlayer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/MiniPlayer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp "$ADAPTER_DIR/bin/mediaremote-adapter.pl" "$APP/Contents/Resources/"
cp "$ADAPTER_DIR/build/MediaRemoteAdapterTestClient" "$APP/Contents/Resources/"
cp -R "$ADAPTER_DIR/build/MediaRemoteAdapter.framework" "$APP/Contents/Frameworks/"
cp "$ADAPTER_DIR/LICENSE" "$APP/Contents/Resources/mediaremote-adapter-LICENSE"

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP"
