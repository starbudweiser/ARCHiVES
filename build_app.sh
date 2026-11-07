#!/bin/bash
# Compile ARCHiVES, assemble ARCHiVES.app (7zz embarqué, icône, Services), signe (_tools/sign_app.sh) et installe
# dans ~/Applications/Applications Personnelles. Usage : ./build_app.sh   (NO_TEST=1 : sans les tests)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ARCHiVES"
VERSION="1.0.0"
INSTALL_DIR="${ARCHIVES_INSTALL_DIR:-$HOME/Applications/Applications Personnelles}"
APP="$ROOT/$APP_NAME.app"
SEVENZ="$(readlink -f /opt/homebrew/bin/7zz 2>/dev/null || true)"

[ -f "$ROOT/assets/icon.icns" ] || { echo "❌ assets/icon.icns manquant" >&2; exit 1; }
[ -x "$SEVENZ" ] || { echo "❌ 7zz introuvable (brew install sevenzip)" >&2; exit 1; }

[ -n "${NO_TEST:-}" ] || { echo "→ Tests"; swift test --package-path "$ROOT" -q 2>&1 | tail -3; }
echo "→ Compilation"
swift build --package-path "$ROOT" -c release -q
BIN="$(swift build --package-path "$ROOT" -c release --show-bin-path)/$APP_NAME"

echo "→ Assemblage"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/assets/icon.icns" "$APP/Contents/Resources/icon.icns"
cp "$SEVENZ" "$APP/Contents/Resources/7zz"
python3 "$ROOT/make_info_plist.py" "$APP/Contents/Info.plist" "$VERSION"
# Titres des Services du Finder (clic droit › Services), par langue
write_strings() { mkdir -p "$APP/Contents/Resources/$1.lproj"; printf '"Extraire ARCHiVE" = "%s";\n"Créer une ARCHiVE" = "%s";\n"Créer une ARCHiVE protégée…" = "%s";\n' "$2" "$3" "$4" | iconv -f UTF-8 -t UTF-16 > "$APP/Contents/Resources/$1.lproj/InfoPlist.strings"; }
write_strings fr "Extraire ARCHiVE" "Créer une ARCHiVE" "Créer une ARCHiVE protégée…"
write_strings en "Extract ARCHiVE" "Create an ARCHiVE" "Create a protected ARCHiVE…"
write_strings it "Estrai ARCHiVE" "Crea un ARCHiVE" "Crea un ARCHiVE protetto…"
write_strings es "Extraer ARCHiVE" "Crear un ARCHiVE" "Crear un ARCHiVE protegido…"

SIGN_APP="$ROOT/../../../../SKYRIM/TOOLS/MAC/_tools/sign_app.sh"
[ -x "$SIGN_APP" ] || SIGN_APP="/Volumes/SKYRIM/TOOLS/MAC/_tools/sign_app.sh"
if [ -x "$SIGN_APP" ]; then "$SIGN_APP" "$APP"; else echo "sign_app.sh absent : signature ad hoc"; codesign --force --deep --sign - "$APP"; fi

echo "→ Installation : $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$APP" "$INSTALL_DIR/$APP_NAME.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
echo "✓ $INSTALL_DIR/$APP_NAME.app"
