# Asset and third-party notices

## Jarvis icon

`packaging/resources/Jarvis.icns` was supplied by the project owner as the Jarvis application icon. The website icon at `docs/assets/jarvis-icon.png` is a PNG export of that file. Its original author and redistribution terms have not been independently verified. The MIT license in this repository applies to the Jarvis source code and project documentation; it does not grant rights to this icon or to third-party marks.

## Runtime and models

Jarvis links against Apple system frameworks: AppKit, WebKit, Speech, and AVFoundation. Offline installer assets include the Ollama application and its runtime dependencies, plus the `qwen2.5:3b` model cache. Ollama's license and third-party notices are distributed within `Ollama.app`; the model publisher's license ships beside the model as `QWEN-MODEL-LICENSE.txt` (or in Jarvis resources in the single-package build). These third-party terms apply to those components and are separate from Jarvis's MIT license. See [Ollama](https://ollama.com) and [Qwen2.5](https://ollama.com/library/qwen2.5) for upstream project details.

