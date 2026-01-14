# KSwitch

KSwitch is a native macOS app for managing Kubernetes contexts and monitoring
[Flux Operator](https://fluxoperator.dev) GitOps clusters directly from the menu bar.

## Features

- **Quick Context Switching** - Switch between Kubernetes contexts from the menu bar
- **Cluster Status** - Shows reachability, Kubernetes version, and node count for each cluster
- **GitOps Monitoring** - Displays Flux CD health status and reconciler stats (requires [flux-operator](https://github.com/controlplaneio-fluxcd/flux-operator) installed in-cluster)
- **Notifications** - Get notified when clusters become unreachable or Flux resources fail
- **Organization** - Mark clusters as favorites, hide unused ones, customize display names and colors
- **Real-time Sync** - Automatically detects kubeconfig changes made by other tools (kubectl, kubectx, etc.)
- **Native Experience** - Built with SwiftUI, runs as a lightweight menu bar app

## Requirements

- macOS 15.0 (Sequoia) or later
- `kubectl` installed and in PATH

## Installation

Download the latest version from the [GitHub releases](https://github.com/controlplaneio-fluxcd/kswitch/releases) page.

## Development

The project is built with SwiftPM, it requires
Swift 6.2+ and xcode command line tools.

```bash
# Build and run
make run

# Run tests
make test

# Stream logs
make logs-stream
```

## License

KSwitch is an open-source project licensed under the
[Apache-2.0 license](https://github.com/stefanprodan/kswitch/blob/main/LICENSE).
