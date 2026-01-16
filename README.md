# KSwitch

[![release](https://img.shields.io/github/release/stefanprodan/kswitch/all.svg)](https://github.com/stefanprodan/kswitch/releases)
[![test](https://github.com/stefanprodan/kswitch/actions/workflows/test.yaml/badge.svg)](https://github.com/stefanprodan/kswitch/actions/workflows/test.yaml)
[![platform](https://img.shields.io/badge/Platform-macOS%2015-blue.svg)](https://developer.apple.com)
[![license](https://img.shields.io/github/license/stefanprodan/kswitch.svg)](https://github.com/stefanprodan/kswitch/blob/main/LICENSE)

KSwitch is a native macOS app for managing Kubernetes contexts and monitoring
[Flux Operator](https://fluxoperator.dev) GitOps clusters directly from the menu bar.

<p align="center">
  <img src="docs/screenshots/kswitch-banner.png" alt="KSwitch Dark Mode" width="100%"/>
</p>

## Features

- **Quick Context Switching** - Switch between Kubernetes contexts from the menu bar
- **Cluster Status** - Shows Kubernetes version, nodes health, and cluster capacity
- **GitOps Monitoring** - Displays Flux Operator version, cluster sync status, and reconciler stats
- **Organization** - Mark clusters as favorites, hide unused ones, customize display names and colors
- **Notifications** - Get notified when clusters become degraded or Flux reconcilers fail

## Installation

### Requirements

- macOS 15.0 (Sequoia) or later
- kubectl installed and in `PATH`

### Download (Recommended)

Download the KSwitch zip file from [GitHub releases](https://github.com/stefanprodan/kswitch/releases),
unzip it, and move `KSwitch.app` to your Applications folder.
The app is code-signed and notarized for Gatekeeper.

While the app is running, it will check for new versions automatically and update itself if allowed.

### Build from Source

Clone, build, and launch:

```bash
git clone https://github.com/stefanprodan/kswitch.git
cd kswitch
make dev
```

Building the app requires the macOS SDK and Swift 6.2+ toolchain
which comes with Xcode 26.2 or later.

## Usage

Launch KSwitch from Applications and allow it to access your kubeconfig file when prompted.
The app will appear in the menu bar from where you can switch Kubernetes contexts and
open the main dashboard.

### Configuration

By default, KSwitch uses `~/.kube/config` and auto-detects `kubectl` from your shell `PATH`.

In the Settings view, you can customize:
- Kubeconfig file path, including support for multiple files delimited by `:`
- Kubectl binary path
- Auto-refresh interval for clusters and Flux status
- Notification preferences
- Auto-start on login and auto-update options

The settings are persisted at
`~/Library/Application Support/KSwitch/config.json`.

### Cluster Management

KSwitch lists all available Kubernetes contexts from your kubeconfig file. It watches for
changes to the kubeconfig file and updates the context list automatically.

In the Cluster list view, you can:
- Mark clusters as favorites for quick access
- Hide unused clusters from the menu bar selector
- Search clusters by name
- Navigate to the cluster details view

In the Cluster details view, you can:
- View Kubernetes version, health, and cluster capacity (CPU, memory, pods)
- View the list of nodes and their status
- View Flux Operator version and sync status
- View the list of Flux components and reconcilers including their status

In the Cluster edit view, you can:
- Change the display name
- Set a custom color for the cluster icon
- Mark the cluster as favorite or hidden

The clusters which have been deleted from the kubeconfig file are kept in the list
but marked as removed. You can delete them permanently from the details view.

The cluster customizations are persisted at
`~/Library/Application Support/KSwitch/clusters.json`.

### Notifications

KSwitch can send macOS notifications to alert you of cluster state changes.
Enable notifications in Settings and allow KSwitch to send alerts when prompted.

You will be notified when:
- A cluster goes offline or comes back online
- Flux reconciliation failures increase

Notifications appear in the macOS Notification Center and can be managed in
System Settings > Notifications > KSwitch.

## License

KSwitch is an open-source project licensed under the
[Apache-2.0 license](https://github.com/stefanprodan/kswitch/blob/main/LICENSE).
