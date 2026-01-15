# KSwitch

KSwitch is a native macOS app for managing Kubernetes contexts and monitoring
[Flux Operator](https://fluxoperator.dev) GitOps clusters directly from the menu bar.

## Features

- **Quick Context Switching** - Switch between Kubernetes contexts from the menu bar
- **Cluster Status** - Shows reachability, Kubernetes version, nodes health, and cluster capacity
- **GitOps Monitoring** - Displays Flux Operator cluster sync status and reconciler stats
- **Organization** - Mark clusters as favorites, hide unused ones, customize display names and colors
- **Notifications** - Get notified when clusters become unreachable or Flux resources fail

## Requirements

- macOS 15.0 (Sequoia) or later
- `kubectl` installed and in PATH

## Installation

Download the latest version from the [GitHub releases](https://github.com/controlplaneio-fluxcd/kswitch/releases) page.

## License

KSwitch is an open-source project licensed under the
[Apache-2.0 license](https://github.com/stefanprodan/kswitch/blob/main/LICENSE).
