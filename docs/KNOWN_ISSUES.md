# Known Issues (P0)

| # | Severity | Issue | Plan |
|---|---|---|---|
| K-1 | Major (process) | No git remote: the repository exists only in this ephemeral cloud container. | **Owner action:** provide a GitHub repo to push to, or download the repo. |
| K-2 | Major | No platform exports built yet (export templates not installed in this environment; ~1 GB download). Windows/macOS builds unverified. | P0.5: install templates, add `export_presets.cfg`, verify on real hardware incl. Apple Silicon. |
| K-3 | Medium | Balance tuned only with bots. Heuristic "conservative/recovery" bots win ~80%; human difficulty unknown. | Human playtest (≥30 testers) before tuning further. |
| K-4 | Medium | Expert lookahead bot is myopic (abuses Delay); not a reliable skill ceiling. | Two-ply or MCTS bot in P0.5 if needed. |
| K-5 | Medium | UI strings are hard-coded English (content strings are in data). | Move to translation CSV in P1. |
| K-6 | Minor | Controller: actions reachable via focus/keys, but no on-screen gamepad cursor for selecting map orbs (Tab/Enter cycle works on keyboard only). | P1 controller UX pass (Steam Deck). |
| K-7 | Minor | UI default font licence should be confirmed against Godot's COPYRIGHT.txt before release. | Pre-release checklist. |
| K-8 | Minor | Audio is placeholder synthesis; no music. | P1. |
| K-9 | Minor | On narrow aspect ratios (< 1100 px wide logical) side panels can overlap the map. | Responsive layout pass in P1. |
| K-10 | Info | Trademark/name is provisional; databases (USPTO/EUIPO/WIPO) not searched. | Owner action before Steam page. |
| K-11 | Medium | 25 of 300 sampled seeds were lost by every bot strategy — possible unavoidable defeats, or bot weakness. | Replay those seeds by hand / with a stronger bot; if truly unwinnable, cap early event magnitude. |
