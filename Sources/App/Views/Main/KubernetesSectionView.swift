// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain

struct KubernetesSectionView: View {
    let status: ClusterStatus
    @State private var selectedTab: Tab = .overview

    private enum Tab: String, CaseIterable {
        case overview = "Overview"
        case nodes = "Nodes"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Kubernetes", selection: $selectedTab)

            switch selectedTab {
            case .overview:
                overviewContent
            case .nodes:
                nodesTable
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
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    reachabilityText
                }

                if let version = status.kubernetesVersion {
                    GridRow {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Text(version)
                            .textSelection(.enabled)
                    }
                }

                if status.nodeCount > 0 {
                    GridRow {
                        Text("Nodes")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text("\(status.nodeCount)")
                                .textSelection(.enabled)
                            if status.notReadyCount > 0 {
                                Text("\(status.notReadyCount) Not Ready")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.yellow.opacity(0.2))
                                    .foregroundStyle(.yellow)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    GridRow {
                        Text("Capacity")
                            .foregroundStyle(.secondary)
                        Text("\(status.totalPods) pods · \(ClusterNode.formatCPU(status.totalCPU)) · \(ClusterNode.formatMemory(status.totalMemory))")
                            .textSelection(.enabled)
                    }
                }
            }

            // Error panels inside overview
            if case .unreachable(let error) = status.reachability {
                errorPanel(title: "Connection Error", message: error)
            } else if let nodeError = status.nodeError {
                errorPanel(title: "Nodes Fetch Error", message: nodeError)
            }
        }
    }

    // MARK: - Nodes Table

    @ViewBuilder
    private var nodesTable: some View {
        if status.nodes.isEmpty {
            Text("No nodes available")
                .foregroundStyle(.secondary)
        } else {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                // Header row
                GridRow {
                    Text("Name")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Pods")
                        .fontWeight(.medium)
                    Text("CPU")
                        .fontWeight(.medium)
                    Text("Memory")
                        .fontWeight(.medium)
                    Text("Status")
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                ForEach(status.nodes) { node in
                    GridRow {
                        Text(node.name)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(node.pods)")
                            .textSelection(.enabled)
                        Text(ClusterNode.formatCPU(node.cpu))
                            .textSelection(.enabled)
                        Text(ClusterNode.formatMemory(node.memory))
                            .textSelection(.enabled)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(node.isReady ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(node.isReady ? "Ready" : "NotReady")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var reachabilityText: some View {
        switch status.reachability {
        case .reachable:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(width: 14, height: 14)
                Text("Online")
            }
        case .unreachable:
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .frame(width: 14, height: 14)
                Text("Offline")
            }
        case .checking:
            // Show previous state if we have data, otherwise show checking
            if status.kubernetesVersion != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(width: 14, height: 14)
                    Text("Online")
                }
            } else {
                Text("Checking...")
                    .foregroundStyle(.secondary)
            }
        case .unknown:
            Text("Unknown")
                .foregroundStyle(.secondary)
        }
    }

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
