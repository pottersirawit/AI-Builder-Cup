#!/usr/bin/env bash
# Renders index.html and every screens/*.html to PNG with headless Chrome.
set -euo pipefail
cd "$(dirname "$0")"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
python3 build.py
mkdir -p png
shot() { "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
  --window-size="$3" --screenshot="$2" "file://$PWD/$1" >/dev/null 2>&1; }
shot index.html png/wireframe-v0-all.png 1840,2500
for f in screens/*.html; do shot "$f" "png/$(basename "${f%.html}").png" 470,1170; done
ls png
