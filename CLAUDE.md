# CLAUDE.md — CONSEQUARRY

Owner communication: **Turkish**. Code, docs, content, commits, identifiers: **English**.

## Project
Turn-based systemic roguelite: the player routes, splits, delays, transforms consequences produced by an autonomous civilization. Godot 4.7.2-stable, typed GDScript, GL Compatibility renderer. Offline, no backend, no runtime AI.

## Commands
- Import (builds class cache; required after adding a `class_name`): `godot --headless --import`
- Unit/integration tests: `godot --headless --script res://tests/run_tests.gd`
- Batch balance (writes reports/): `godot --headless --script res://tools/batch_sim.gd -- <runs_per_strategy> <expert_runs> <seed_base>`
- All checks: `tools/run_all_checks.sh` (add `--ui` for the Xvfb UI autoplay smoke test)
- Play: `godot` (editor) or `godot --path . ` ; direct run: `godot -- --autostart p0_valley <seed>`
- Screenshot (Xvfb): `xvfb-run -a godot --rendering-driver opengl3 -- --autostart tutorial 20261122 --shot out.png 30 --demo`

## Rules
- Simulation (`src/simulation`, `src/consequences`, ...) must stay integer-only, node-free, deterministic.
- Never break ledger invariants; run tests after any rule change.
- Balance changes go through `data/content.json` and must be followed by a batch run; record in docs/DECISIONS.md.
- Never claim results that were not produced by an actual run. Bot results are not human evidence.
- Ask the owner before: paid purchases, publishing, destructive git operations, major scope changes.

## Docs to keep current
docs/STATUS.md, docs/TASKS.md, docs/DECISIONS.md, docs/KNOWN_ISSUES.md, docs/ROADMAP.md, CHANGELOG.md, reports/test_summary.md.
