# Changelog

## 0.1.2 — 2026-11-23
- Season report panel: every landing traced from origin to impact, causal-link drag, cascades, collapses and new world memory; reopenable from the idle panel.
- iPhone install verified on device via `tools/ios/install_on_iphone.sh`.

## 0.1.1-p0.5 — 2026-11-22
- Export presets for Web, Windows, macOS (universal, ad-hoc signed), Linux and iOS (Xcode project).
- Compact touch layout for phones: larger canvas scale, collapsible Season panel, scrollable detail panel, bigger tap targets, rotate-to-landscape guard; Settings → Layout override.
- Embedded DejaVu Sans symbol fallback (web/mobile have no system fonts).
- "Copy run report" on the end screen and a playtest guide.
- Web packaging script for size-limited hosting (split engine binary).

## 0.1.0-p0 — 2026-11-22
- Deterministic integer simulation: 6 systems, 5 consequence types, 10 events, 5 interventions, 3 transformations, 6 controlled crises, causal graph, world memory, cascades, scars.
- Consequence ledger with conservation invariants (I1–I3), verified in tests and every batch run.
- Isometric procedural presentation, consequence orbs, landing/overflow/cascade animations, procedural SFX.
- HUD with exact landing previews, forecast, world-memory chronicle; undo within season.
- Interactive 7-step tutorial; settings (volume, animation speed, shake, links, fullscreen); autosave/continue; shareable seed codes; post-mortem screen.
- Headless test suite and batch balancer with 9 simulated strategies; reports in `reports/`.
