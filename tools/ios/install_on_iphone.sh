#!/usr/bin/env bash
# Builds CONSEQUARRY for iOS and installs it on a cable-connected iPhone.
# macOS only. Free Apple ID is enough (the app then expires after 7 days; re-run to renew).
#
# One-time prerequisites (the script checks and tells you what is missing):
#   1. Xcode from the App Store, opened once (accept the licence).
#   2. Xcode > Settings > Accounts: add your Apple ID.
#   3. iPhone connected by cable, unlocked, "Trust This Computer" accepted.
#   4. iPhone: Settings > Privacy & Security > Developer Mode = On (appears after step 3; phone restarts).
#
# Usage: tools/ios/install_on_iphone.sh            (auto-detects team id and device)
#        TEAM_ID=ABCDE12345 tools/ios/install_on_iphone.sh
set -euo pipefail

GODOT_VERSION="4.7.2"
BUNDLE_ID="${BUNDLE_ID:-com.eyazan.consequarry}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CACHE="$HOME/.consequarry-tools"
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable"
OUT="$ROOT/builds/ios"
DERIVED="$ROOT/builds/ios_derived"

say()  { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "This script runs on macOS only."

say "Checking Xcode"
xcodebuild -version >/dev/null 2>&1 || fail "Xcode not found. Install it from the App Store, open it once, then re-run."
xcrun devicectl --version >/dev/null 2>&1 || fail "Xcode 15 or newer is required (devicectl missing)."

say "Checking Godot ${GODOT_VERSION}"
mkdir -p "$CACHE"
GODOT="$CACHE/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$GODOT" ]]; then
  curl -L --fail -o "$CACHE/godot.zip" "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_macos.universal.zip"
  (cd "$CACHE" && unzip -q -o godot.zip && rm godot.zip)
  xattr -dr com.apple.quarantine "$CACHE/Godot.app" 2>/dev/null || true
fi
if [[ ! -f "$TEMPLATES/ios.zip" ]]; then
  say "Downloading Godot export templates (about 1.3 GB, one time only)"
  curl -L --fail -o "$CACHE/templates.tpz" "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  mkdir -p "$TEMPLATES"
  (cd "$CACHE" && unzip -q -o templates.tpz "templates/ios.zip" "templates/version.txt" && mv templates/* "$TEMPLATES/" && rm -rf templates templates.tpz)
fi

say "Finding your Apple development team"
if [[ -z "${TEAM_ID:-}" ]]; then
  TEAM_ID="$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)"
fi
if [[ -z "${TEAM_ID:-}" ]]; then
  TEAM_ID="$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | grep -o 'teamID = [A-Z0-9]\{10\}' | head -1 | awk '{print $3}')"
fi
[[ -n "${TEAM_ID:-}" ]] || fail "No Apple team found. Open Xcode > Settings > Accounts, add your Apple ID, click 'Manage Certificates' > + > Apple Development, then re-run. (Or set TEAM_ID=...)"
echo "Team: $TEAM_ID   Bundle id: $BUNDLE_ID"

say "Finding the connected iPhone"
DEVICES_JSON="$(mktemp)"
xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 || true
DEVICE_ID="$(/usr/bin/python3 - "$DEVICES_JSON" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for d in data.get("result", {}).get("devices", []):
    hw = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    if hw.get("platform") == "iOS" and conn.get("pairingState") == "paired":
        print(d.get("identifier", ""))
        break
PY
)"
rm -f "$DEVICES_JSON"
[[ -n "$DEVICE_ID" ]] || fail "No paired iPhone found. Connect it by cable, unlock it, tap 'Trust This Computer', enable Developer Mode, then re-run."
echo "Device: $DEVICE_ID"

say "Exporting the Xcode project from Godot"
cd "$ROOT"
cp export_presets.cfg export_presets.cfg.bak
trap 'mv -f "$ROOT/export_presets.cfg.bak" "$ROOT/export_presets.cfg"' EXIT
sed -i '' -e "s/application\/app_store_team_id=\"[^\"]*\"/application\/app_store_team_id=\"$TEAM_ID\"/" \
          -e "s/application\/bundle_identifier=\"com.consequarry.prototype\"/application\/bundle_identifier=\"$BUNDLE_ID\"/" export_presets.cfg
rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release "iOS" "$OUT/Consequarry.ipa" || fail "Godot iOS export failed."
[[ -d "$OUT/Consequarry.xcodeproj" ]] || fail "Xcode project was not produced."

say "Building and signing (Xcode)"
xcodebuild -project "$OUT/Consequarry.xcodeproj" -scheme Consequarry -configuration Release \
  -destination "id=$DEVICE_ID" -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  build | tail -20
APP="$(find "$DERIVED/Build/Products" -maxdepth 2 -name '*.app' -path '*iphoneos*' | head -1)"
[[ -n "$APP" ]] || fail "Build finished but no .app was found."

say "Installing on the iPhone"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

say "Done"
cat <<'TXT'
If the icon does not open: on the iPhone go to
  Settings > General > VPN & Device Management > (your Apple ID) > Trust.
Free Apple ID apps expire after 7 days. Re-run this script to renew.
TXT
