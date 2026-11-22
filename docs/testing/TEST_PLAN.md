# Test Plan

## Automated (headless)
- `tests/run_tests.gd` — 23 tests: RNG determinism, run determinism, conservation after every action/turn (random play, 30 seeds), bounds/NaN/negative checks (60 seeds), save/load roundtrip + continuation, each intervention, transform capacity, crisis escalation/cooldown, world-memory effects (adaptation, dependency, familiarity), termination, spill depth, tutorial script, end-of-run crisis lockout, collapsed-target rejection, save file IO, seed codes, preview == resolution (40 seeds).
- `tools/batch_sim.gd` — ≥10,000 seeded runs across 9 strategies; ledger verification + bounds per run; determinism re-check; dominant-strategy flag (>85% win for any non-expert bot); seeds lost by all strategies; perf and peak static memory.
- UI smoke (Xvfb): `--autoplay` plays an entire run through GameView (instant and animated modes) and verifies the ledger.

## Manual (owner / testers)
- First-session: does the player perform Redirect → Transform within 60 s via tutorial?
- Readability: can testers explain why a system lost health after a season?
- Win/loss clarity, post-mortem usefulness, replay desire.
