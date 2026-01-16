// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain

struct FluxSectionView: View {
    let status: ClusterStatus
    @State private var selectedTab: Tab = .overview

    private enum Tab: String, CaseIterable {
        case overview = "Overview"
        case components = "Components"
        case reconcilers = "Reconcilers"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Flux", selection: $selectedTab)

            switch selectedTab {
            case .overview:
                overviewContent
            case .components:
                if let components = status.fluxReport?.components, !components.isEmpty {
                    componentsContent(components: components)
                } else {
                    Text("No components available")
                        .foregroundStyle(.secondary)
                }
            case .reconcilers:
                if let reconcilers = status.fluxReport?.reconcilers, !reconcilers.isEmpty {
                    reconcilersContent(reconcilers: reconcilers)
                } else {
                    Text("No reconcilers available")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader<T: RawRepresentable & CaseIterable & Hashable>(
        _ title: String,
        selection: Binding<T>
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Picker("", selection: selection) {
                ForEach(Array(T.allCases), id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewContent: some View {
        // If we have summary data, always show it (even during refresh)
        if let summary = status.fluxSummary {
            // Distribution not installed - show minimal info
            if !summary.isDistributionInstalled {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Operator")
                            .foregroundStyle(.secondary)
                        Text(summary.operatorVersion)
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text("Distribution")
                            .foregroundStyle(.secondary)
                        Text("N/A")
                            .textSelection(.enabled)
                    }
                }
            } else {
                distributionInstalledContent(summary: summary)
            }
        } else {
            // No previous data - show status based on operator state
            noSummaryContent
        }
    }

    @ViewBuilder
    private func distributionInstalledContent(summary: FluxReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    HStack {
                        if summary.totalFailing == 0 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Healthy")
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("\(summary.totalFailing) failing")
                        }
                    }
                }

                GridRow {
                    Text("Operator")
                        .foregroundStyle(.secondary)
                    Text(summary.operatorVersion)
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("Distribution")
                        .foregroundStyle(.secondary)
                    Text(summary.distributionVersion)
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("Components")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text("\(summary.componentsReady)")
                            .textSelection(.enabled)
                        if summary.componentsReady < summary.componentsTotal {
                            let notReady = summary.componentsTotal - summary.componentsReady
                            Text("\(notReady) failing")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                }

                GridRow {
                    Text("Reconcilers")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text("\(summary.totalRunning)")
                            .textSelection(.enabled)
                        if summary.totalFailing > 0 {
                            Text("\(summary.totalFailing) failing")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                }

                GridRow {
                    Text("Sync")
                        .foregroundStyle(.secondary)
                    if let sync = status.fluxReport?.sync {
                        if sync.ready {
                            Text("Cluster in sync with desired state")
                        } else if let message = sync.status, message.hasPrefix("Suspended") {
                            Text("Cluster sync is suspended")
                        } else {
                            Text("Cluster failing to sync desired state")
                        }
                    } else {
                        Text("Root sync not found")
                            .foregroundStyle(.secondary)
                    }
                }

                if let sync = status.fluxReport?.sync {
                    if let source = sync.source {
                        GridRow {
                            Text("Source")
                                .foregroundStyle(.secondary)
                            Text(source)
                                .textSelection(.enabled)
                        }
                    }

                    if let path = sync.path {
                        GridRow {
                            Text("Path")
                                .foregroundStyle(.secondary)
                            Text(path)
                                .textSelection(.enabled)
                        }
                    }

                    // Show revision in grid when sync is ready or suspended with applied revision
                    if let message = sync.status, !message.isEmpty {
                        let appliedRevisionPrefix = "Applied revision: "
                        let suspendedRevisionPrefix = "Suspended Applied revision: "
                        let revision: String? = if message.hasPrefix(suspendedRevisionPrefix) {
                            String(message.dropFirst(suspendedRevisionPrefix.count))
                        } else if sync.ready && message.hasPrefix(appliedRevisionPrefix) {
                            String(message.dropFirst(appliedRevisionPrefix.count))
                        } else {
                            nil
                        }
                        if let revision {
                            GridRow {
                                Text("Revision")
                                    .foregroundStyle(.secondary)
                                Text(revision)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }

            // Show sync error panel outside the grid when sync fails (not for suspended)
            if let sync = status.fluxReport?.sync,
               !sync.ready,
               let message = sync.status,
               !message.isEmpty,
               !message.hasPrefix("Suspended") {
                errorPanel(title: "Sync Error", message: message)
                    .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    private var noSummaryContent: some View {
        switch status.fluxOperator {
        case .notInstalled:
            Text("Flux Operator not installed")
                .foregroundStyle(.secondary)

        case .operatorOnly, .installed, .degraded:
            // Shouldn't happen - we always have summary when FluxReport exists
            Text("Loading...")
                .foregroundStyle(.secondary)

        case .checking:
            Text("Checking...")
                .foregroundStyle(.secondary)

        case .unknown:
            if let fluxError = status.fluxError {
                errorPanel(title: "Flux Report Error", message: fluxError)
            } else {
                Text("Status unknown")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func componentsContent(components: [FluxComponent]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            // Header row
            GridRow {
                Text("Name")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Version")
                    .fontWeight(.medium)
                Text("Status")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            ForEach(components, id: \.name) { component in
                GridRow {
                    Text(component.name)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(parseImageVersion(component.image))
                        .textSelection(.enabled)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(component.ready ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(component.ready ? "Ready" : "Not Ready")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Extracts version from container image string
    /// e.g., "ghcr.io/fluxcd/source-controller:v1.2.3@sha256:..." -> "v1.2.3"
    private func parseImageVersion(_ imageStr: String?) -> String {
        guard let imageStr, !imageStr.isEmpty else {
            return "unknown"
        }
        let parts = imageStr.split(separator: ":")
        guard parts.count > 1 else { return "latest" }
        // Remove @sha256:... digest if present
        return String(parts[1].split(separator: "@").first ?? "latest")
    }

    // MARK: - Reconcilers

    @ViewBuilder
    private func reconcilersContent(reconcilers: [FluxReconciler]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            // Header row
            GridRow {
                Text("Kind")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Running")
                    .fontWeight(.medium)
                Text("Failing")
                    .fontWeight(.medium)
                Text("Suspended")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            ForEach(reconcilers, id: \.kind) { reconciler in
                GridRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reconciler.kind)
                            .textSelection(.enabled)
                        Text(reconciler.apiVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(reconciler.stats.running)")
                        .foregroundStyle(reconciler.stats.running > 0 ? .blue : .primary)
                        .textSelection(.enabled)
                    Text("\(reconciler.stats.failing)")
                        .foregroundStyle(reconciler.stats.failing > 0 ? .red : .primary)
                        .textSelection(.enabled)
                    Text("\(reconciler.stats.suspended)")
                        .foregroundStyle(reconciler.stats.suspended > 0 ? .orange : .primary)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func errorPanel(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(title)
                    .font(.headline)
            }

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
