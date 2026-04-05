# Godot Download Manager

A threaded, node-based download manager plugin for **Godot 4.2+** with intelligent caching, sequential group downloads, and a runtime singleton API.

## Features

- **Node-based setup** — configure entirely in the Inspector, no boilerplate
- **Multi-threaded** — concurrent downloads via configurable thread pool (1–16 threads)
- **Sequential groups** — groups download one at a time with per-group progress
- **Smart caching** — files matching expected size + SHA-256 hash are skipped instantly
- **Automatic retries** — failed downloads retry up to 3 times with exponential backoff
- **Redirect following** — follows HTTP 301, 302, 307, 308 redirects (up to 5 hops)
- **Hash verification** — post-download SHA-256 integrity check with automatic cleanup on mismatch
- **Update check** — pre-flight cache check before downloading
- **HTTP / HTTPS** — full TLS support via Godot's built-in HTTPClient
- **Signal-driven** — plugin emits signals only, you build the UI
- **Runtime API** — `DLClient` autoload singleton for on-demand downloads during gameplay

## Installation

1. Copy the `addons/download_manager/` folder into your Godot project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Godot Download Manager**.

The plugin registers a `DLClient` autoload singleton automatically.

## Quick Start

```
YourLoadingScene
├── DownloadProgress              ← Orchestrator
│   ├── DownloadGroup             ← Group: "Sound Effects"
│   └── DownloadGroup             ← Group: "Music"
└── CanvasLayer
    └── (your UI)
```

```gdscript
@onready var dl: DownloadProgress = $DownloadProgress

func _ready() -> void:
    dl.check_completed.connect(_on_check)
    dl.all_completed.connect(_on_done)

func _on_check(needs_download: bool, bytes: int) -> void:
    if needs_download:
        dl.start()

func _on_done(success: bool) -> void:
    if success:
        get_tree().change_scene_to_file("res://main_menu.tscn")
```

## Documentation

- **Usage guide:** [https://mapdu.dev/blog/godot/download-manager/](https://mapdu.dev/blog/godot/download-manager/)

## Contributing

Contributions are welcome! Here's how to get started:

### Setup

1. Fork this repository.
2. Clone your fork and open the project in Godot 4.2+.
3. Enable the plugin in **Project > Project Settings > Plugins**.
4. The `addons/download_manager/demo/demo_scene.tscn` is a working demo — use it to test changes.

### Code Style

- **Strict typing everywhere** — all variables, constants, `for` loops, and return types must have explicit type annotations.
- `const X: Type = value` — never use `:=` inference.
- `var x: Type = value` — never use untyped `var`.
- `for item: Type in collection:` — always type loop variables.
- `func name() -> ReturnType:` — always include return type, including `-> void`.

### Pull Requests

1. Create a feature branch from `main`.
2. Keep changes focused — one feature or fix per PR.
3. Test your changes with the included `addons/download_manager/demo/demo_scene.tscn`.
4. Ensure all code follows the style guide above.
5. Write a clear PR description explaining what and why.

### Reporting Issues

- Open an issue with steps to reproduce.
- Include your Godot version and OS.
- Attach any error logs from the Godot console.

## License

This project is licensed under the [MIT License](LICENSE).
