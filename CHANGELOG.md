# Changelog

## 0.3.0 — 2026-11-25 (store readiness)
- Business model (D-018): free to try (River Valley, 10 levels) + one-time full-game unlock; no ads, no subscriptions.
- Entitlements by build flavour (`store`, `demo`, full); paywall screen with price, restore and "not now"; locked tiles on the map; Steam demo end screen.
- Store purchase layer ready for Godot's iOS `InAppStore` plugin (not yet in the build: needs the Apple Developer account and product).
- Export presets: "Windows Demo" (feature `demo`) and "iOS Store" (feature `store`).
- Premium feel: haptics on phones, confetti on saved valleys.
- Store kit: official-size screenshots (Steam 1920×1080, iPhone 6.7" 2796×1290) via `tools/store_shots.sh`, EN/TR store listing draft, privacy policy, monetization guide.

## 0.2.0 — 2026-11-23 (campaign + drag & drop)
- New main mode **Valleys**: 30 short levels (4–6 seasons, 2–5 minutes) in three regions (River Valley, Dry Hills, Boomtown), 1–3 stars, unlock-as-you-go map, local progress, new seed per attempt.
- Levels start with 3 districts and grow to 6; moves unlock gradually (move → transform → split → delay → controlled crisis); early levels have no rerouting leak.
- **Drag & drop**: hold a trouble and drop it on a glowing district (live damage preview on every valid target). Tap still opens details.
- Guided first level with an animated drag gesture; level-4 transform lesson; level goal card and star result screen; Hint shows the drag gesture in levels.
- Engine: scenarios can use a subset of districts, an event pool, unlocked moves, rule overrides (`rules`), and a magnitude multiplier.
- Difficulty calibrated with bots by binary search per level: novice (random) win rate falls from ~78% (level 1) to ~5% (level 30); good-bot win rate from 100% to ~80–96% (`reports/campaign_calibration.md`).
- Classic 12-season mode, daily valley and scenarios remain under "Classic mode".
- Map zooms to the districts in play (3-district levels fill the phone screen); on phones the map shifts right while the tutorial panel is open.
- Fixes found with real touch events on a phone-sized web build: the side panel no longer opens mid-drag (the map moved under the finger); a drop no longer selects the moved piece (which hid END on phones); END always stays visible; overlays no longer react to resizes after closing.

## 0.1.3 — 2026-11-23 (onboarding)
- Owner playtest: game was not understood without the tutorial. Response:
  - First launch starts the tutorial directly; rewritten 7-step tutorial in plain words ("troubles", "tap the orange shape").
  - On-screen guidance: bouncing arrow on the map and a pulsing, arrow-marked button for every step; falls back to the step the player still has to do.
  - Hint button: suggests and points at a sensible move (strongest simple heuristic); reminder toast in the first three runs.
  - Tutorial run made easier (win avg ≥50 / min ≥20, fewer and smaller events).
  - EN | TR toggle on the main menu (English stays the default outside Turkish devices).
- Fix: map taps now use the event position instead of the last cursor position (stale positions could select the wrong orb on touch screens).
- QA: `--guided` mode plays like a newcomer with real clicks: follows the arrow through the tutorial (5 taps), then follows Hint for the rest of the run.

## 0.1.2 — 2026-11-23
- Procedural ambient soundtrack (no assets): pad, bass and arpeggio loop synthesised in small chunks across frames; Music bus low-pass follows stability (tension); separate Music and Sound effects volume sliders.
- Localization pipeline: engine messages are language-neutral (`Msg` key + args), UI goes through `Loc`; `tools/i18n_extract.py` builds `localization/strings.csv` from code and content, merges `localization/tr.json`, and checks placeholder order. Full Turkish translation (259 strings); Settings → Language (Auto/English/Türkçe); Turkish-aware upper case. CI fails on missing or mismatched translations.
- Two new scenarios: **Dry Season** (heat/fire-heavy, weakened fields and forests) and **Boomtown** (booming industry, frequent accidents, strikes and spills). Scenario picker in the main menu.
- Daily valley: same seed and scenario for everyone per UTC date (offline), run score, local best score per day.
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
