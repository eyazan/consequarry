# Known Issues (P0)

| # | Severity | Issue | Plan |
|---|---|---|---|
| K-1 | Major (process) | No git remote: the repository exists only in this ephemeral cloud container. | **Owner action:** provide a GitHub repo to push to, or download the repo. |
| K-2 | Medium | Exports now built for Web/Windows/macOS/Linux/iOS-project; only Web (Chromium) and Linux were run. Windows/macOS/real iPhone Safari unverified. | Owner tests on iPhone Safari; Windows/Mac testers in playtest. |
| K-3 | Medium | Balance tuned only with bots. Heuristic "conservative/recovery" bots win ~80%; human difficulty unknown. | Human playtest (≥30 testers) before tuning further. |
| K-4 | Medium | Expert lookahead bot is myopic (abuses Delay); not a reliable skill ceiling. | Two-ply or MCTS bot in P0.5 if needed. |
| K-5 | Medium | UI strings are hard-coded English (content strings are in data). | Move to translation CSV in P1. |
| K-6 | Minor | Controller: no on-screen gamepad cursor for map orbs (touch and mouse work; Tab/Enter on keyboard). | P1 controller UX pass (Steam Deck). |
| K-7 | Minor | UI default font licence should be confirmed against Godot's COPYRIGHT.txt before release. | Pre-release checklist. |
| K-8 | Minor | Audio is placeholder synthesis; no music. | P1. |
| K-9 | Minor | Compact layout added (phones). Tablet portrait is blocked by the rotate guard; landscape only. | Revisit for tablets in P1. |
| K-10 | Info | Trademark/name is provisional; databases (USPTO/EUIPO/WIPO) not searched. | Owner action before Steam page. |
| K-11 | Medium | 25 of 300 sampled seeds were lost by every bot strategy — possible unavoidable defeats, or bot weakness. | Replay those seeds by hand / with a stronger bot; if truly unwinnable, cap early event magnitude. |
| K-12 | Medium | The claude.ai-hosted web build could not be verified from this container (its sandbox may block WebAssembly/audio worklets). The same files work on a normal web server. | Owner opens the link on iPhone; fallback: host `builds/web` on GitHub Pages or itch.io (publishing → needs approval). |
