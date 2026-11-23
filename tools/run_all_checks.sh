#!/usr/bin/env bash
# Runs import, unit tests and a batch simulation. Usage: tools/run_all_checks.sh [--ui] [runs] [expert_runs]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
UI=0
if [[ "${1:-}" == "--ui" ]]; then UI=1; shift; fi
RUNS="${1:-1500}"
EXPERT="${2:-300}"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --script res://tests/run_tests.gd
"$GODOT" --headless --script res://tools/batch_sim.gd -- "$RUNS" "$EXPERT" 10000
if [[ $UI == 1 ]]; then
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --resolution 1280x720 -- \
    --autostart p0_valley 4242 --shot reports/ui_smoke_end.png 10 --autoplay | grep -E "autoplay|ledger|saved"
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --resolution 1280x720 -- \
    --autostart tutorial 20261122 --shot reports/ui_guided_end.png 5 --guided | grep -E "guided"
fi
