#!/bin/bash
# Publie ARCHiVES sur GitHub Releases : compilation, signature Developer ID, notarisation, agrafage, zip, release.
# Usage : ./release.sh [--replace]    (DRY=1 : montre les étapes sans notariser ni publier)
# Prérequis : dépôt propre et poussé sur main, gh connecté, _tools/notarize_app.sh opérationnel (profil « Applications »).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="/Volumes/SKYRIM/TOOLS/MAC/_tools"
OWNER="starbudweiser"; PROJ="ARCHiVES"
INSTALL_DIR="${ARCHIVES_INSTALL_DIR:-$HOME/Applications/Applications Personnelles}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPLACE=0; [ "${1:-}" = "--replace" ] && REPLACE=1
run() { if [ "${DRY:-0}" = 1 ]; then echo "[DRY] $*"; else "$@"; fi; }

[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || { echo "release : modifications non commitées" >&2; exit 1; }
git -C "$ROOT" fetch -q origin main
[ "$(git -C "$ROOT" rev-parse HEAD)" = "$(git -C "$ROOT" rev-parse origin/main)" ] || { echo "release : pas synchronisé avec origin/main" >&2; exit 1; }

echo "→ Compilation"
NO_TEST= "$ROOT/build_app.sh" >/dev/null
app="$INSTALL_DIR/$PROJ.app"
version="$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")"
tag="v$version"
echo "→ $PROJ $version ($tag)"
if gh release view "$tag" -R "$OWNER/$PROJ" >/dev/null 2>&1 && [ "$REPLACE" != 1 ]; then
    echo "release : $tag existe déjà (--replace)" >&2; exit 1
fi

echo "→ Notarisation"
run "$TOOLS/notarize_app.sh" "$app"
zip="$TOOLS/notarized/$PROJ.zip"
asset="$PROJ-$version-macOS-arm64.zip"
stage="$(mktemp -d)"
if [ "${DRY:-0}" != 1 ]; then
    [ -f "$zip" ] || { echo "release : $zip absent après la notarisation" >&2; exit 1; }
    cp "$zip" "$stage/$asset"; (cd "$stage" && shasum -a 256 "$asset" > "$asset.sha256")
fi

NOTES_FILE="$ROOT/release_notes.md"
echo "→ Publication"
if gh release view "$tag" -R "$OWNER/$PROJ" >/dev/null 2>&1; then
    run gh release upload "$tag" -R "$OWNER/$PROJ" --clobber "$stage/$asset" "$stage/$asset.sha256"
else
    run gh release create "$tag" -R "$OWNER/$PROJ" --target main --title "$PROJ $version" --notes-file "$NOTES_FILE" "$stage/$asset" "$stage/$asset.sha256"
fi
echo "✓ https://github.com/$OWNER/$PROJ/releases/tag/$tag"
