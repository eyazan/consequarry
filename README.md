# CONSEQUARRY (working title)

*Every consequence must go somewhere.*

A turn-based systemic strategy roguelite. You don't build the city — you decide where its disasters, waste and windfalls go. Route, split, delay and transform consequences across a living causal network; trigger controlled crises; and live with a world that remembers.

**Status:** P0 playable prototype (not a commercial build). See `docs/STATUS.md`.

## Run it
1. Install Godot **4.7.2-stable** (standard, not .NET) from godotengine.org.
2. `godot --path .` → press Play (or open the folder in the editor and press F5).

## Test it
```
godot --headless --import
godot --headless --script res://tests/run_tests.gd
godot --headless --script res://tools/batch_sim.gd -- 1500 300 10000
```

## Layout
See `docs/architecture/ARCHITECTURE.md`. Design: `docs/design/GDD.md`, formulas: `docs/design/FORMULAS.md`. Research: `docs/research/`.

## Licence
All code and procedural art/audio are original to this project (see `docs/asset_licenses.md`). Godot Engine is MIT-licensed.
