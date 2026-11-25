# Monetization & Store Builds

Owner decision (D-018): free to try + one-time full-game purchase; no ads, no subscriptions, no consumables.

| Build | Export preset | Feature tag | What's playable | Purchase |
|---|---|---|---|---|
| Steam full game | Windows / macOS / Linux | — | everything | bought on Steam |
| Steam demo | Windows Demo (add macOS/Linux demo the same way) | `demo` | levels 1–10 | end-of-demo screen points to Steam |
| iOS App Store | iOS Store | `store` | levels 1–10, rest after IAP | in-app purchase `consequarry.full_game` |
| Playtest / web / dev | Web, iOS | — | everything | none |

Code: `src/progression/entitlements.gd` (rules), `src/progression/store.gd` (purchase layer), `src/ui/paywall.gd` (screen). Preview without a store: `-- --store-build --map --paywall`; simulate a purchase: add `--fake-store`.

## Owner steps (paid accounts — need your approval and payment)
1. **Apple Developer Program** (USD 99/yr): create the app (bundle `com.eyazan.consequarry`), add a non-consumable IAP with id `consequarry.full_game`, price tier ≈ USD 4.99. Then Claude adds Godot's iOS `InAppStore` plugin to the build and tests with a sandbox account via TestFlight.
2. **Steamworks** (USD 100 per app): create the app + demo app, upload capsules and screenshots, then Claude prepares SteamPipe upload scripts for the full and demo builds.
3. Host the privacy policy at a public URL (GitHub Pages on the public `consequarry-play` repo works) and add a support email.
