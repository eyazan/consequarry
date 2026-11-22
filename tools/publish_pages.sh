#!/usr/bin/env bash
# Publishes builds/web to the PUBLIC play repository (GitHub Pages, branch main, root).
# The source repository stays private; only the compiled web build is public.
# Usage: tools/publish_pages.sh [play_repo_url]
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="${1:-https://github.com/eyazan/consequarry-play}"
WORK="${TMPDIR:-/tmp}/consequarry-play"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --export-release "Web" builds/web/index.html >/dev/null 2>&1
rm -rf "$WORK"
git clone --depth 1 "$REPO" "$WORK" 2>/dev/null || { mkdir -p "$WORK"; git -C "$WORK" init -q -b main; git -C "$WORK" remote add origin "$REPO"; }
find "$WORK" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r builds/web/. "$WORK/"
touch "$WORK/.nojekyll"
cat > "$WORK/README.md" <<'MD'
# CONSEQUARRY — playable prototype

Play in the browser: https://eyazan.github.io/consequarry-play/

On iPhone: open the link in Safari → Share → **Add to Home Screen**, then launch it from the icon (full screen, works offline after the first load). Play in landscape.

This repository only hosts the compiled web build. Prototype build, not a finished game.
MD
VERSION=$(grep -o 'config/version="[^"]*"' project.godot | cut -d'"' -f2)
git -C "$WORK" add -A
git -C "$WORK" -c user.name="CONSEQUARRY Dev" -c user.email="dev@consequarry.local" commit -q -m "Publish web build $VERSION" || echo "nothing to publish"
git -C "$WORK" -c push.negotiate=true push -u origin main
