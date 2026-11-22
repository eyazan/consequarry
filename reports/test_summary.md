# Test Summary — P0 (2026-11-22)

All results below were produced by commands actually executed in this environment (Linux x86_64, Godot 4.7.2-stable official, headless + Xvfb). **Bot simulation results are not evidence of human engagement or fun.**

## Unit / integration tests
`godot --headless --script res://tests/run_tests.gd` → **23 passed, 0 failed** (also re-run from a clean `git clone` → 23/23).

## Batch simulation (`tools/batch_sim.gd -- 1500 300 10000`)
**12,300 seeded runs**, 1,418.8 s, peak static memory 26.2 MB. Full data: `simulation_results.json`, `balance_metrics.csv`, `balance_summary.md`.

| Strategy | Runs | Win % |
|---|---|---|
| passive (no actions) | 1500 | 0.1 |
| random | 1500 | 0.9 |
| greedy (transform-first) | 1500 | 17.1 |
| aggressive | 1500 | 28.1 |
| expert (1-ply lookahead) | 300 | 42.3 |
| balanced | 1500 | 49.9 |
| crisis_focused | 1500 | 58.0 |
| recovery_focused | 1500 | 78.7 |
| conservative (route-to-least-vulnerable) | 1500 | 81.1 |

| Check | Result |
|---|---|
| Ledger conservation invariants (I1–I3) on every run | **0 failing runs** |
| Health bounds / negative values / non-termination | **0** |
| Determinism re-check (50 seeds run twice, hash compare) | **0 mismatches** |
| Dominant strategy (>85% win, non-expert) | **none flagged** |
| Seeds lost by *every* strategy (300-seed expert sample) | **25 (8.3%)** — candidate unavoidable defeats; bots are imperfect, needs investigation (K-11) |
| Infinite resource generation | Not observed: reserve converts to at most +1 action/season; max surplus bounded by events/crises (no unbounded growth found in 12,300 runs) |
| Performance | 13–43 ms per simulated run (bots); expert 3.3 s/run due to cloning |

## UI smoke (Xvfb, OpenGL3 / llvmpipe)
- `--autoplay` full run, instant animations: finished, outcome reached, ledger errors 0.
- `--autoplay --animated` full run: finished in 25 s, ledger errors 0.
- Screenshots captured at 1280×720, 1280×800 (Steam Deck), 1920×1080: layout verified visually. See `docs/screenshots/`.

## Not tested
Real GPUs, Windows/macOS/Apple Silicon builds, gamepads, touch input, audio output (dummy audio driver in container), human players.
