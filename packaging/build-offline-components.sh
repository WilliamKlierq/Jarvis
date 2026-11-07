#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
OLLAMA_APP="${OLLAMA_APP_PATH:-/Applications/Ollama.app}"
OLLAMA_MODELS="${OLLAMA_MODELS_PATH:-$HOME/.ollama/models}"
STAGE="${TMPDIR:-/tmp}/jarvis-offline-components"
RUNTIME_ROOT="$STAGE/runtime"
MODEL_ROOT="$STAGE/model"
OUT="$ROOT/dist"
IDENTITY="${APPLE_INSTALLER_SIGNING_IDENTITY:-}"
MANIFEST="$OLLAMA_MODELS/manifests/registry.ollama.ai/library/qwen2.5/3b"

[[ -d "$OLLAMA_APP" && -x "$OLLAMA_APP/Contents/Resources/ollama" ]] || { echo "Universal Ollama app not found: $OLLAMA_APP" >&2; exit 1; }
[[ -s "$MANIFEST" ]] || { echo "qwen2.5:3b model not found: $OLLAMA_MODELS" >&2; exit 1; }
codesign --verify --deep --strict "$OLLAMA_APP"
mkdir -p "$OUT"
python3 - "$STAGE" <<'PY'
import pathlib, shutil, sys
shutil.rmtree(pathlib.Path(sys.argv[1]), ignore_errors=True)
PY
mkdir -p "$RUNTIME_ROOT/Applications" "$MODEL_ROOT/Library/Application Support/Jarvis/OllamaModels"
COPYFILE_DISABLE=1 cp -cR "$OLLAMA_APP" "$RUNTIME_ROOT/Applications/Ollama.app"

/usr/bin/python3 - "$OLLAMA_MODELS" "$MODEL_ROOT/Library/Application Support/Jarvis/OllamaModels" <<'PY'
import json, os, pathlib, shutil, sys
source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
relative = pathlib.Path("manifests/registry.ollama.ai/library/qwen2.5/3b")
manifest = json.loads((source / relative).read_text())
digests = [manifest["config"]["digest"], *(layer["digest"] for layer in manifest["layers"])]
(target / "manifests/registry.ollama.ai/library/qwen2.5").mkdir(parents=True, exist_ok=True)
for digest in digests:
    name = "sha256-" + digest.split(":", 1)[1]
    src, dst = source / "blobs" / name, target / "blobs" / name
    if not src.is_file(): raise SystemExit(f"Missing model data: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    try: os.link(src, dst)
    except OSError: shutil.copy2(src, dst)
shutil.copy2(source / relative, target / relative)
license_digest = next(layer["digest"].split(":", 1)[1] for layer in manifest["layers"] if layer["mediaType"] == "application/vnd.ollama.image.license")
shutil.copy2(source / "blobs" / ("sha256-" + license_digest), target / "QWEN-MODEL-LICENSE.txt")
PY

for component in runtime model; do
  if [[ "$component" == runtime ]]; then
    ROOT_PATH="$RUNTIME_ROOT"
    PACKAGE="$OUT/Jarvis-$VERSION-Ollama.pkg"
    IDENTIFIER="ai.jarvis.ollama-runtime"
  else
    ROOT_PATH="$MODEL_ROOT"
    PACKAGE="$OUT/Jarvis-$VERSION-Qwen-3b-Model.pkg"
    IDENTIFIER="ai.jarvis.qwen25-3b-model"
  fi
  if [[ -n "$IDENTITY" ]]; then
    pkgbuild --root "$ROOT_PATH" --identifier "$IDENTIFIER" --version "$VERSION" --install-location / --sign "$IDENTITY" "$PACKAGE"
  else
    pkgbuild --root "$ROOT_PATH" --identifier "$IDENTIFIER" --version "$VERSION" --install-location / "$PACKAGE"
  fi
done

echo "Created $OUT/Jarvis-$VERSION-Ollama.pkg"
echo "Created $OUT/Jarvis-$VERSION-Qwen-3b-Model.pkg"
