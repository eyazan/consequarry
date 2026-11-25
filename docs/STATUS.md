# Status — 2026-11-25

**Version:** 0.3.0. Main mode: Valleys campaign (30 short levels, drag & drop). Classic mode kept.

## Directive checklist
| Area | State |
|---|---|
| Research (competitors, market, originality, trademark pre-check) | Done; trademark databases still to be searched by owner |
| P0 prototype quality gates | Met (see reports/test_summary.md) |
| Deterministic engine, ledger invariants, tests | 29 automated tests; CI on every push |
| Balance | Classic: 12,300 bot runs; campaign: per-level calibration (reports/campaign_calibration.md) |
| Platforms | Web, Windows, macOS, Linux, iOS (installed on owner's iPhone); Steam demo preset |
| Localization | English (default) + Turkish |
| Monetization | Free tier + one-time unlock implemented; real purchases need store accounts |
| Store kit | Screenshots, listing text, privacy policy drafted |
| **Human validation (directive §13: ≥30 testers)** | **Not done.** Only data point: owner did not understand the first format. The campaign format has not been tested by humans yet. |

## Blockers needing the owner
1. External playtest: share the web link/TestFlight with 10–30 people (see docs/playtest/PLAYTEST_GUIDE.md).
2. Paid accounts: Apple Developer (USD 99/yr), Steamworks (USD 100) — approval and payment.
3. Public play repo `consequarry-play` for the PWA link and privacy-policy hosting.
4. Trademark search for the name.
