# KSwitch

KSwitch is a native macOS menu bar app for managing Kubernetes contexts with [Flux](https://fluxcd.io) integration.

## Features

- **Quick Context Switching** - Switch between Kubernetes contexts from the menu bar
- **Real-time Sync** - Automatically detects kubeconfig changes made by other tools (kubectl, kubectx, etc.)
- **Cluster Status** - Shows reachability, Kubernetes version, and node count for each cluster
- **Flux Monitoring** - Displays [Flux](https://fluxcd.io) health status and failing resource counts (requires [flux-operator](https://github.com/controlplaneio-fluxcd/flux-operator) installed in-cluster)
- **Notifications** - Get notified when clusters become unreachable or Flux resources fail
- **Organization** - Mark clusters as favorites, hide unused ones, customize display names and colors
- **Native Experience** - Built with SwiftUI, runs as a lightweight menu bar app

## Requirements

- macOS 15.0 (Sequoia) or later
- `kubectl` installed and in PATH

## Installation

Download the latest release from the [Releases](https://github.com/controlplaneio-fluxcd/kswitch/releases) page.

## Development

```bash
# Build and run (dev loop)
make run

# Build release binary
make build-release

# Package .app bundle
make package

# Run tests
make test

# Stream logs
make logs-stream

# Clean build artifacts
make clean
```

## License

Apache-2.0
