#!/bin/bash
# Fetches and builds ungive/mediaremote-adapter (BSD-3) into vendor/.
# It is the workaround that lets us read now-playing info on macOS 15.4+.
# Requires: git, cmake (brew install cmake), Xcode command line tools.
set -euo pipefail
cd "$(dirname "$0")/.."

# Pinned to the commit that was read and tested. Review the diff before bumping it.
PIN=0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd
DIR=vendor/mediaremote-adapter

if [ ! -d "$DIR/.git" ]; then
  mkdir -p vendor
  git clone https://github.com/ungive/mediaremote-adapter.git "$DIR"
fi
git -C "$DIR" fetch --quiet origin
git -C "$DIR" checkout --quiet "$PIN"

mkdir -p "$DIR/build"
(cd "$DIR/build" && cmake .. && cmake --build .)
echo "Built $DIR/build/MediaRemoteAdapter.framework"
