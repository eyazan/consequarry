#!/usr/bin/env bash
# Packages builds/web into builds/web_artifact: wasm split into <15 MB parts
# (per-file hosting limit) and a page that reassembles them in the browser.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=builds/web
OUT=builds/web_artifact
rm -rf "$OUT" && mkdir -p "$OUT"
cp "$SRC/index.js" "$SRC/index.audio.worklet.js" "$SRC/index.audio.position.worklet.js" "$OUT/"
# Only standard web extensions are served, so binaries travel with a .wasm name.
cp "$SRC/index.pck" "$OUT/index.pck.wasm"
split -b 13500000 -d -a 1 "$SRC/index.wasm" "$OUT/index.part"
for f in "$OUT"/index.part?; do mv "$f" "$f.wasm"; done
PARTS=$(ls "$OUT" | grep -c 'index.part')
WASM_SIZE=$(stat -c %s "$SRC/index.wasm")
PCK_SIZE=$(stat -c %s "$SRC/index.pck")
sed -e "s/__PARTS__/$PARTS/" -e "s/__WASM_SIZE__/$WASM_SIZE/" -e "s/__PCK_SIZE__/$PCK_SIZE/" tools/web_artifact_shell.html > "$OUT/consequarry.html"
ls -la "$OUT"
