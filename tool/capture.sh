#!/usr/bin/env bash
# Renders doc/*.gif for the README from tool/capture/capture_test.dart. Needs gifski.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/frames
fvm flutter test tool/capture/capture_test.dart
mkdir -p doc
for dir in build/frames/*/; do
  name=$(basename "$dir")
  gifski --quiet --fps 25 --width 393 -o "doc/$name.gif" "$dir"*.png
  echo "doc/$name.gif"
done
