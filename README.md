# Jarvis

Jarvis is a macOS browser with an optional local AI assistant. It combines a WebKit browser, tab and workspace management, and task automation in one app.

This repository contains the Swift source, app icon, and macOS package build script. The app targets macOS 14 or newer and supports universal Apple Silicon and Intel Macs.

## Features

- Built-in WebKit browser with tabs, workspaces, page search, and address navigation.
- Optional local language model through Ollama at `127.0.0.1:11434`.
- English, Czech, Slovak, German, and Polish interface choices; dark, light, and system appearance.
- Voice input and speech output when enabled by the user.
- Web task assistance for visible page content and common accessible controls.
- macOS `.pkg` installer build for universal arm64 and x86_64.

The default local build can produce a single offline package with the universal Ollama runtime and `qwen2.5:3b`. On first use, Jarvis copies the model into the current user's Ollama cache. Installing and preparing the model needs about 6 GB of free disk space. For practical local inference, use a Mac with at least 8 GB of unified/system memory; speed varies by model and hardware. The model may be changed in Settings, which can require an additional download.

Web task support depends on the page exposing readable text and accessible controls. The app cannot guarantee support for every interactive activity, including canvas-based tasks or sites that require specialized authentication or unsupported controls. Review answers before submitting them.

## Build from source

Requirements: macOS 14+, Xcode Command Line Tools, and the macOS SDK.

Build and run the executable during development:

```sh
swift build
swift run Jarvis
```

Create a universal app bundle and installer:

```sh
./packaging/build-release.sh
```

The installer is written to `dist/Jarvis-1.0.0.pkg`. The default build includes the universal Ollama app and `qwen2.5:3b` model. `BUNDLE_LOCAL_AI=0` creates a smaller package that downloads those components on first use. GitHub release automation first attempts to publish one complete offline installer; if it exceeds GitHub's 2 GiB per-file limit, it publishes the smaller installer plus separate Ollama and model packages. Without Apple Developer ID signing and notarization credentials, packages are unsigned and macOS may warn before installation. See [packaging/README.md](packaging/README.md) for details.

## Updates

Jarvis checks the latest GitHub release at startup and every six hours. When a newer version with a `Jarvis-<version>.pkg` release asset is available, it offers the update. Choosing **Later** leaves the update available under **Settings → Updates**. Jarvis downloads the package over HTTPS and opens macOS Installer; installation is never silent. In-app checks require a publicly readable GitHub repository and release. To publish a release, set `VERSION`, create a GitHub release with the matching `v<version>` tag, and publish it. The workflow builds the complete package and attaches it to the release, using separate components only if GitHub's asset limit requires them.

## Project website

The public-facing product website is in [`docs/`](docs/). The GitHub Pages workflow publishes it from the `main` branch. In repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**. The expected site URL is <https://williamklierq.github.io/Jarvis/>. The homepage puts the macOS download first, followed by product details, privacy information, and system requirements.

## Local AI setup

Open **Settings → Local AI → Install and configure AI** or start a task and choose the setup prompt. With the full offline installer, Jarvis starts Ollama and copies `qwen2.5:3b` from `/Library/Application Support/Jarvis` into the current user's local model cache. This initial setup does not need to download the model. The model is licensed separately from Jarvis; see [ASSET-LICENSES.md](ASSET-LICENSES.md). With a `BUNDLE_LOCAL_AI=0` package, setup downloads Ollama and the selected model from their official sources.

## Privacy

- The task agent connects to the local Ollama endpoint at `127.0.0.1:11434`.
- Model prompts include the user task and a snapshot of the active page. Review the page before sending sensitive information to any service.
- Voice capture starts only after voice mode is enabled and stops when it is disabled.
- Browser data is managed by WebKit on the local Mac.

## Project layout

```text
Sources/JarvisApp.swift             App source
packaging/build-release.sh          Universal macOS app and .pkg builder
packaging/build-offline-components.sh Runtime and model .pkg builder for offline releases
packaging/resources/Jarvis.icns     App icon
packaging/resources/Welcome.html    Installer welcome text
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for build and contribution guidance. Please report security issues privately as described in [SECURITY.md](SECURITY.md).

## License

Jarvis source code and project documentation are licensed under the MIT License. The app icon and third-party runtime/model components bundled into the full installer are excluded; see [ASSET-LICENSES.md](ASSET-LICENSES.md) for their notices.

