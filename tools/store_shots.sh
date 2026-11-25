#!/usr/bin/env bash
# Captures store screenshots at official sizes (Steam 1920x1080, iPhone 6.7" 2796x1290).
# Usage: tools/store_shots.sh [lang]   (en default; tr for Turkish store)
set -euo pipefail
cd "$(dirname "$0")/.."
LANG_CODE="${1:-en}"
OUT="marketing/store_shots/$LANG_CODE"
mkdir -p "$OUT"
shot() { # size_name WxH extra_args... ; last arg is file stem
  local name="$1" res="$2" stem="$3"; shift 3
  xvfb-run -a -s "-screen 0 ${res}x24" godot --rendering-driver opengl3 --resolution "$res" -- \
    --lang "$LANG_CODE" "$@" --shot "$OUT/${name}_${stem}.png" 40 >/dev/null 2>&1 || true
  [[ -f "$OUT/${name}_${stem}.png" ]] && echo "ok $OUT/${name}_${stem}.png"
}
for target in "steam 1920x1080" "iphone67 2796x1290"; do
  set -- $target; name="$1"; res="$2"
  extra=(); [[ "$name" == iphone* ]] && extra=(--compact)
  shot "$name" "$res" 1_drag   "${extra[@]}" --autostart lvl_09 4242 --no-intro --select-type heat
  shot "$name" "$res" 2_valley "${extra[@]}" --autostart boomtown 31337
  shot "$name" "$res" 3_map    "${extra[@]}" --map
  shot "$name" "$res" 4_report "${extra[@]}" --autostart tutorial 20261122 --demo --endturn
  shot "$name" "$res" 5_stars  "${extra[@]}" --autostart lvl_04 4242 --guided
done
