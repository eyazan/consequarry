# Architecture

Engine: **Godot 4.7.2-stable** (official build, verified with `godot --version` → `4.7.2.stable.official.ed1daf0bf`), GDScript with static typing, GL Compatibility renderer (broadest hardware incl. Apple Silicon, Steam Deck, tablets).

## Layers
```
data/content.json            data-driven content (systems, types, edges, events, rules, scenarios)
src/core                     ContentDB (loader), DetRng (xorshift32, integer), SeedCode, GameSettings
src/consequences             Consequence, ConsequenceLedger (conservation invariants)
src/causality                CausalGraph
src/world_memory             WorldMemory
src/economy                  Intervention (value object)
src/events                   EventDirector
src/simulation               WorldState (serializable), CivilizationSystem, SimulationEngine (rules)
src/progression              BotStrategies (simulated players for balancing)
src/persistence              SaveSystem (versioned JSON, atomic write)
src/presentation             GameView (controller), IsoMap, DistrictView, OrbView, FxLayer, Sfx, Palette
src/ui                       main.gd (app root), Hud, TutorialOverlay, GameOverPanel, SettingsPanel, MainMenu, UIKit
tests/run_tests.gd           headless unit/integration tests
tools/batch_sim.gd           headless seeded batch balancer → reports/
tools/run_all_checks.sh      import + tests + batch (+ optional UI smoke)
```
Simulation classes extend `RefCounted`, never touch nodes, and are fully headless. Presentation only *reads* `WorldState` and calls `SimulationEngine.validate/apply/end_turn`. `end_turn` returns a report the view animates; the world is already final when animation starts.

## Determinism
- No floats in state; all randomness from `WorldState.rng` (serialized state).
- Deterministic iteration: systems in data order, consequences sorted by id, edges in data order.
- `WorldState.state_hash()` = MD5 of key-sorted JSON; tests assert identical hashes across runs and across save/load continuation.

## Persistence
`user://run_save.json` (autosaved at the start of every season), `save_version` field (currently 1); loading normalises JSON floats to ints. Settings in `user://settings.cfg`.

## Input
InputMap actions `end_turn` (Space / pad Y), `undo_action` (Z / pad X), `cancel_selection` (Esc / RMB / pad B) plus keyboard Tab/1-4/Enter; all UI reachable via focusable Buttons.

## Localization readiness
All player-facing content strings live in `data/content.json` or UI code in English; P1 task: move UI strings to a CSV translation table (`tr()`).

## Dependency rules
core ← consequences ← simulation ← presentation/ui. No upward references. No autoloads; no external services; no runtime AI.
