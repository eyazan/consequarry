# Decision Log

| ID | Date | Decision | Reason |
|---|---|---|---|
| D-001 | 2026-11-22 | Godot 4.7.2-stable, GDScript, GL Compatibility renderer | Latest stable available (probed GitHub releases; 4.8 not released). Compatibility renderer maximises Steam Deck / tablet / Apple Silicon reach. No Godot was pre-installed; official Linux binary downloaded. |
| D-002 | 2026-11-22 | Integer-only simulation with own xorshift32 RNG | Cross-platform determinism, exact conservation arithmetic, no NaN class of bugs. |
| D-003 | 2026-11-22 | Single `data/content.json` for all content | Data-driven tuning by bots without code changes; one file is easier to diff in P0. Split per domain in P1 if it grows. |
| D-004 | 2026-11-22 | Delay redesigned as "deferred harm + separate strain consequence", max 2, not past final season | Avoid Anachrony-style loan mechanic (originality audit) and infinite deferral exploit. |
| D-005 | 2026-11-22 | Softened Industry→Environment pressure (−(h−60)·w/200, cap −3) | First batch: Environment collapsed in ~50–95% of runs for every strategy, making all play converge on one failure (passive won more than active play). |
| D-006 | 2026-11-22 | Redirect leaks 20% (parent closes into moved + leak children) | Batch showed the "send harm to least-vulnerable neighbour" heuristic won ~91–97% → dominant strategy. After leak + dependency 1 per 2 redirects: ~81%, other heuristics 20–60%, passive/random ≈0%. Also reinforces the slogan: you can never fully dodge a consequence. |
| D-007 | 2026-11-22 | Difficulty: regen 1/0, absorb effect 80%, +8%/season magnitude, extra event chance from season 3, win avg ≥55 & min ≥25 | Initial values let passive play win 98%. Tuned until passive ≈0%, random ≈1%. |
| D-008 | 2026-11-22 | Bots are not human evidence; "expert" one-ply lookahead bot is myopic | It over-uses Delay (pushes harm past its horizon). Kept as a reachability probe, not a skill ceiling. |
| D-009 | 2026-11-22 | Post-mortem attributes damage to the root origin through routing chains | "Split share (−26)" taught nothing; "Flood (routed)" does. |
