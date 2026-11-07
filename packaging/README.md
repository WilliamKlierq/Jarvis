# macOS package build and signing

Run `./packaging/build-release.sh` from the repository root. The script reads the release number from `VERSION`, compiles arm64 and x86_64 binaries, combines them into a universal `.app`, and writes `dist/Jarvis-<version>.pkg`.

By default, the package includes Jarvis, the universal Ollama macOS runtime, and the `qwen2.5:3b` model cache. On first AI setup, Jarvis copies the model to the current user's Ollama cache. The target is macOS 14 or newer on Apple Silicon or Intel, with 8 GB RAM and about 6 GB free disk space recommended. Model speed varies by hardware. The package build requires a local Ollama app and model cache; set `OLLAMA_APP_PATH` and `OLLAMA_MODELS_PATH` to use alternate locations. Set `BUNDLE_LOCAL_AI=0` to make a smaller installer that downloads the runtime and model on first use.

The uncompressed runtime and model payload total about 2.5 GB. The complete package is compressed to just under GitHub's 2 GiB per-file limit on the current build. Release automation measures the package before uploading it. If a future runtime or model exceeds that limit, the workflow falls back to a smaller installer and separate `Jarvis-<version>-Ollama.pkg` and `Jarvis-<version>-Qwen-3b-Model.pkg` offline components. Run `./packaging/build-offline-components.sh` to create those components from a local Ollama app and model cache. A full single-package build needs substantial temporary free space; reserve about 8 GB on the build Mac. The network-assisted main package can be built with `BUNDLE_LOCAL_AI=0`.

For public distribution without Gatekeeper warnings, configure Developer ID Application and Developer ID Installer certificates in Keychain and create a notary profile with `xcrun notarytool store-credentials`. Then set:

```sh
export APPLE_APPLICATION_SIGNING_IDENTITY="Developer ID Application: Publisher Name (TEAMID)"
export APPLE_INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Publisher Name (TEAMID)"
export APPLE_NOTARY_PROFILE="jarvis-notary"
./packaging/build-release.sh
```

Without these credentials, the build script creates an unsigned development installer. Do not present that artifact as a notarized public release.

The GitHub release workflow targets one complete offline installer, including Ollama and `qwen2.5:3b`, while respecting GitHub's per-file size limit. The project version remains `1.0.0` until explicitly changed.

