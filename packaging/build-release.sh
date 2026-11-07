#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
IFS=. read -r VERSION_MAJOR VERSION_MINOR VERSION_PATCH VERSION_REVISION <<< "$VERSION"
VERSION_MAJOR="${VERSION_MAJOR:-0}"
VERSION_MINOR="${VERSION_MINOR:-0}"
VERSION_PATCH="${VERSION_PATCH:-0}"
VERSION_REVISION="${VERSION_REVISION:-0}"
APP_BUILD_VERSION=$((VERSION_MAJOR * 1000000 + VERSION_MINOR * 10000 + VERSION_PATCH * 100 + VERSION_REVISION))
SOURCE="$ROOT/Sources/JarvisApp.swift"
PACKAGING="$ROOT/packaging"
OUT="$ROOT/dist"
BUILD="$ROOT/build"
STAGE="${TMPDIR:-/tmp}/jarvis-release-stage"
APP="$STAGE/Applications/Jarvis.app"
PAYLOAD="${TMPDIR:-/tmp}/jarvis-pkg-payload"
PKG="${TMPDIR:-/tmp}/jarvis-$VERSION-component.pkg"
COMPONENT_PLIST="${TMPDIR:-/tmp}/jarvis-$VERSION-components.plist"
FINAL="$OUT/Jarvis-$VERSION.pkg"
APP_IDENTITY="${APPLE_APPLICATION_SIGNING_IDENTITY:-${APPLE_SIGNING_IDENTITY:-}}"
PKG_IDENTITY="${APPLE_INSTALLER_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${APPLE_NOTARY_PROFILE:-}"
ICON="$PACKAGING/resources/Jarvis.icns"
OLLAMA_APP="${OLLAMA_APP_PATH:-/Applications/Ollama.app}"
OLLAMA_MODELS="${OLLAMA_MODELS_PATH:-$HOME/.ollama/models}"
BUNDLE_LOCAL_AI="${BUNDLE_LOCAL_AI:-1}"

[[ -f "$SOURCE" ]] || { echo "Missing source: $SOURCE" >&2; exit 1; }
[[ -s "$ICON" ]] || { echo "Missing app icon: $ICON" >&2; exit 1; }
mkdir -p "$OUT" "$BUILD"
rm -rf "$STAGE" "$PAYLOAD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PAYLOAD/Applications"

swiftc -target arm64-apple-macos14.0 "$SOURCE" -o "$BUILD/Jarvis-arm64" -framework AppKit -framework WebKit -framework Speech -framework AVFoundation
swiftc -target x86_64-apple-macos14.0 "$SOURCE" -o "$BUILD/Jarvis-x86_64" -framework AppKit -framework WebKit -framework Speech -framework AVFoundation
lipo -create "$BUILD/Jarvis-arm64" "$BUILD/Jarvis-x86_64" -output "$APP/Contents/MacOS/Jarvis"
chmod 755 "$APP/Contents/MacOS/Jarvis"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Jarvis</string>
<key>CFBundleIdentifier</key><string>ai.jarvis.webassistant</string>
<key>CFBundleName</key><string>Jarvis</string>
<key>CFBundleDisplayName</key><string>Jarvis</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleSignature</key><string>JRVS</string>
<key>CFBundleIconFile</key><string>Jarvis</string>
<key>CFBundleURLTypes</key><array><dict>
<key>CFBundleURLName</key><string>Web URLs</string>
<key>CFBundleURLSchemes</key><array><string>http</string><string>https</string></array>
<key>LSHandlerRank</key><string>Owner</string>
</dict></array>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$APP_BUILD_VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Jarvis uses the microphone only while voice mode is enabled.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Jarvis converts voice commands to text only while voice mode is enabled.</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
install -m 644 "$ICON" "$APP/Contents/Resources/Jarvis.icns"
install -m 644 "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE.txt"
install -m 644 "$ROOT/ASSET-LICENSES.md" "$APP/Contents/Resources/THIRD-PARTY-NOTICES.txt"
if [[ "$BUNDLE_LOCAL_AI" == "1" ]]; then
  [[ -d "$OLLAMA_APP" && -x "$OLLAMA_APP/Contents/Resources/ollama" ]] || { echo "Missing universal Ollama app at $OLLAMA_APP. Set OLLAMA_APP_PATH or BUNDLE_LOCAL_AI=0." >&2; exit 1; }
  [[ -s "$OLLAMA_MODELS/manifests/registry.ollama.ai/library/qwen2.5/3b" ]] || { echo "Missing qwen2.5:3b model cache at $OLLAMA_MODELS. Set OLLAMA_MODELS_PATH or BUNDLE_LOCAL_AI=0." >&2; exit 1; }
  codesign --verify --deep --strict "$OLLAMA_APP"
  COPYFILE_DISABLE=1 cp -cR "$OLLAMA_APP" "$APP/Contents/Resources/Ollama.app"
  MODEL_CACHE_RESOURCE="$APP/Contents/Resources/OllamaModels"
  /usr/bin/python3 - "$OLLAMA_MODELS" "$MODEL_CACHE_RESOURCE" <<'PY'
import json, os, pathlib, shutil, sys
source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
relative = pathlib.Path("manifests/registry.ollama.ai/library/qwen2.5/3b")
manifest = json.loads((source / relative).read_text())
digests = [manifest["config"]["digest"], *(layer["digest"] for layer in manifest["layers"])]
(target / "manifests/registry.ollama.ai/library/qwen2.5").mkdir(parents=True, exist_ok=True)
for digest in digests:
    name = "sha256-" + digest.split(":", 1)[1]
    src, dst = source / "blobs" / name, target / "blobs" / name
    if not src.is_file():
        raise SystemExit(f"Missing model data: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.link(src, dst)
    except OSError:
        shutil.copy2(src, dst)
shutil.copy2(source / relative, target / relative)
PY
  MODEL_LICENSE_DIGEST="$(/usr/bin/python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(next(x["digest"].split(":",1)[1] for x in m["layers"] if x["mediaType"] == "application/vnd.ollama.image.license"))' "$OLLAMA_MODELS/manifests/registry.ollama.ai/library/qwen2.5/3b")"
  MODEL_LICENSE="$OLLAMA_MODELS/blobs/sha256-$MODEL_LICENSE_DIGEST"
  [[ -s "$MODEL_LICENSE" ]] || { echo "Missing qwen2.5:3b model license blob." >&2; exit 1; }
  install -m 644 "$MODEL_LICENSE" "$APP/Contents/Resources/QWEN-MODEL-LICENSE.txt"
  install -m 644 "$OLLAMA_APP/Contents/Resources/LLAMA_CPP_LICENSE" "$APP/Contents/Resources/OLLAMA-LLAMA-CPP-LICENSE.txt"
  install -m 644 "$OLLAMA_APP/Contents/Resources/GO_LICENSE" "$APP/Contents/Resources/OLLAMA-GO-LICENSE.txt"
fi
COPYFILE_DISABLE=1 cp -cR "$APP" "$PAYLOAD/Applications/Jarvis.app"
find "$PAYLOAD/Applications/Jarvis.app" -name '._*' -delete
xattr -cr "$PAYLOAD/Applications/Jarvis.app" || true

if [[ -n "$APP_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$APP_IDENTITY" "$PAYLOAD/Applications/Jarvis.app/Contents/MacOS/Jarvis"
  codesign --force --options runtime --timestamp --sign "$APP_IDENTITY" "$PAYLOAD/Applications/Jarvis.app"
else
  codesign --force --sign - --timestamp=none "$PAYLOAD/Applications/Jarvis.app/Contents/MacOS/Jarvis"
  codesign --force --sign - --timestamp=none "$PAYLOAD/Applications/Jarvis.app"
fi
codesign --verify --deep --strict "$PAYLOAD/Applications/Jarvis.app"

pkgbuild --analyze --root "$PAYLOAD" "$COMPONENT_PLIST"
/usr/bin/python3 - "$COMPONENT_PLIST" <<'PY'
import plistlib, sys
path = sys.argv[1]
with open(path, "rb") as stream:
    components = plistlib.load(stream)
for component in components:
    if "BundleIsVersionChecked" in component:
        component["BundleIsVersionChecked"] = False
with open(path, "wb") as stream:
    plistlib.dump(components, stream)
PY
if [[ "$BUNDLE_LOCAL_AI" == "1" ]]; then
  if [[ -n "$PKG_IDENTITY" ]]; then
    pkgbuild --root "$PAYLOAD" --component-plist "$COMPONENT_PLIST" --identifier ai.jarvis.webassistant --version "$VERSION" --install-location / --sign "$PKG_IDENTITY" "$PKG"
  else
    pkgbuild --root "$PAYLOAD" --component-plist "$COMPONENT_PLIST" --identifier ai.jarvis.webassistant --version "$VERSION" --install-location / "$PKG"
  fi
  mv -f "$PKG" "$FINAL"
else
  pkgbuild --root "$PAYLOAD" --component-plist "$COMPONENT_PLIST" --identifier ai.jarvis.webassistant --version "$VERSION" --install-location / "$PKG"
  if [[ -n "$PKG_IDENTITY" ]]; then
    productbuild --package "$PKG" --resources "$PACKAGING/resources" --sign "$PKG_IDENTITY" "$FINAL"
  else
    productbuild --package "$PKG" --resources "$PACKAGING/resources" "$FINAL"
  fi
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  [[ -n "$APP_IDENTITY" && -n "$PKG_IDENTITY" ]] || { echo "Notarization requires both Developer ID Application and Developer ID Installer identities." >&2; exit 1; }
  xcrun notarytool submit "$FINAL" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$FINAL"
  xcrun stapler validate "$FINAL"
fi

if [[ -n "$PKG_IDENTITY" ]]; then
  pkgutil --check-signature "$FINAL"
else
  echo "Local package created unsigned. Developer ID Installer is required for public distribution." >&2
fi
rm -f "$PKG"
echo "Created $FINAL"
