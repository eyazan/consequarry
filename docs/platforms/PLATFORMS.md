# Platform Builds

Built with `godot --headless --export-release "<preset>" <path>` (presets in `export_presets.cfg`). Output goes to `builds/` (git-ignored).

| Platform | Output | Verified here | Notes |
|---|---|---|---|
| Web | `builds/web/` (single-threaded, no COOP/COEP needed) | ✅ Loaded in Chromium (desktop + iPhone-landscape emulation with touch); full touch flow: tutorial → select → redirect → end season | iOS Safari itself not tested (no device here) |
| Web (hosted on claude.ai) | `tools/make_web_artifact.sh` → `builds/web_artifact/` | ✅ local test of the packaged page | Private artifact; engine binary split into <15 MB parts and reassembled in the browser |
| Linux x86_64 | `builds/linux/Consequarry.x86_64` | ✅ Full autoplay run under Xvfb; same outcome as editor run for the same seed | |
| Windows x86_64 | `builds/windows/Consequarry.exe` | ⚠️ Built (PE32+), not run | Unsigned → SmartScreen warning |
| macOS universal | `builds/macos/Consequarry.zip` | ⚠️ Built, ad-hoc signed, not run | Not notarised (needs paid Apple Developer account) |
| iOS | `builds/ios/` Xcode project | ⚠️ Project exported, not built | Needs a Mac with Xcode, see below |

## iOS native install by cable (owner has a Mac)
`tools/ios/install_on_iphone.sh` on the Mac: downloads Godot + iOS template (one time), detects the Apple team from Xcode, exports, builds/signs with `xcodebuild -allowProvisioningUpdates`, installs with `xcrun devicectl`. Free Apple ID: app expires after 7 days (re-run). Not yet executed on real hardware.

## Steam readiness
Windows/macOS/Linux builds are already produced in a Steam-compatible form (self-contained executables, offline, no accounts). Remaining for Steam: Steamworks partner account + app fee (USD 100, **paid — needs owner approval**), store page assets, optional Steamworks SDK (achievements/cloud) via GodotSteam, SteamPipe upload scripts. Planned for P1 after human playtest validation.

## iOS options (owner has an iPhone, no Android)
1. **Now, free:** play the web build in Safari (landscape). Optional: Share → *Add to Home Screen* for a full-screen icon.
2. **Native, free:** on a Mac with Xcode, open `builds/ios/Consequarry.xcodeproj`, sign with your personal Apple ID team, run on the iPhone. Free provisioning expires after 7 days. Replace `REPLACEME0` team id in `export_presets.cfg` with your team id and re-export.
3. **TestFlight for external testers:** requires the Apple Developer Program (USD 99/year) — **paid, needs owner approval**.

## Compact (touch) layout
Auto-enabled on iOS/Android browsers and mobile builds; can be forced in Settings → Layout, or with `-- --compact`. Logical canvas 900×460 (larger text and touch targets), collapsible Season panel, scrollable detail panel, rotate-to-landscape guard.
