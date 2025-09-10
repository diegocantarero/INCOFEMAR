#!/usr/bin/env bash
set -euo pipefail

DIST="dist"

if [ ! -f "$DIST/index.html" ]; then
  echo "ERROR: $DIST/index.html not found"; exit 1;
fi

# index.html must reference the config script
if ! grep -q "firebase-config.js" "$DIST/index.html"; then
  echo "ERROR: firebase-config.js not referenced in dist/index.html"; exit 1;
fi

# config file must exist and define window.FB_CONFIG
if [ ! -f "$DIST/firebase-config.js" ]; then
  echo "ERROR: $DIST/firebase-config.js not found"; exit 1;
fi
if ! grep -q "window.FB_CONFIG" "$DIST/firebase-config.js"; then
  echo "ERROR: window.FB_CONFIG not found in dist/firebase-config.js"; exit 1;
fi

# find a main bundle (supports both main.js and cache-busted main.*.js)
JS=""
if [ -f "$DIST/main.js" ]; then JS="$DIST/main.js"; fi
if [ -z "$JS" ]; then
  for f in "$DIST"/main*.js; do
    if [ -f "$f" ]; then JS="$f"; break; fi
  done
fi
if [ -z "$JS" ]; then
  echo "ERROR: No main*.js bundle found in dist/"; exit 1;
fi

# ensure initializeApp is present in the bundle
if ! grep -q "initializeApp" "$JS"; then
  echo "ERROR: initializeApp not found in bundle $JS"; exit 1;
fi

echo "[verify] Firebase inclusion OK"

