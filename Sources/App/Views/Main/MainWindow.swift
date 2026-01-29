// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var selectedItem: SidebarItem? = .clusters
    @State private var navigationPath = NavigationPath()
    @State private var isSearching: Bool = false
    @State private var isProgrammaticNavigation: Bool = false

    private var showsListView: Bool {
        selectedItem == .clusters || selectedItem == .tasks
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selectedItem)
        } detail: {
            NavigationStack(path: $navigationPath) {
                detailView
                    .navigationDestination(for: Cluster.self) { cluster in
                        ClusterDetailView(cluster: cluster)
                    }
                    .navigationDestination(for: ScriptTask.self) { task in
                        TaskRunView(task: task)
                    }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    if !navigationPath.isEmpty {
                        Button(action: { goBack() }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if showsListView && isSearching {
                        FocusableTextField(
                            placeholder: selectedItem == .clusters ? "Search clusters" : "Search tasks",
                            text: $searchText,
                            shouldFocus: true,
                            onEscape: {
                                isSearching = false
                                searchText = ""
                            }
                        )
                        .frame(width: 180)
                    }

                    if showsListView {
                        Button {
                            isSearching.toggle()
                            if !isSearching {
                                searchText = ""
                            }
                        } label: {
                            Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                        }
                    }

                    if selectedItem == .clusters {
                        Button {
                            Task { await appState.refreshAllStatuses() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .opacity(appState.isRefreshing ? 0 : 1)
                                .overlay {
                                    if appState.isRefreshing {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    }
                                }
                                .frame(width: 16, height: 16)
                        }
                        .disabled(appState.isRefreshing)
                        .help("Refresh all clusters")
                    }
                }
            }
            .toolbarBackground(.visible, for: .windowToolbar)
        }
        .task {
            await appState.refreshAllStatuses()
        }
        .onAppear {
            // Handle pending navigation when window opens fresh
            // (onChange doesn't fire for values already set before view appeared)
            handlePendingNavigation()
        }
        .onChange(of: selectedItem) {
            // Skip reset if this is a programmatic navigation
            if isProgrammaticNavigation {
                isProgrammaticNavigation = false
                return
            }
            // Clear search and navigation when user manually switches sections
            isSearching = false
            searchText = ""
            navigationPath = NavigationPath()
        }
        .onChange(of: appState.pendingClusterNavigation) {
            handlePendingNavigation()
        }
        .onChange(of: appState.pendingSettingsNavigation) {
            handlePendingNavigation()
        }
        .onChange(of: appState.pendingTaskNavigation) {
            handlePendingNavigation()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if selectedItem == .settings {
            SettingsView()
        } else if selectedItem == .about {
            AboutView()
        } else if selectedItem == .tasks {
            TasksListView(searchText: $searchText, navigationPath: $navigationPath)
                .navigationTitle("Tasks")
        } else if let error = appState.error {
            errorStateView(message: error)
        } else if appState.clusters.isEmpty {
            emptyStateView
        } else {
            ClustersListView(
                searchText: $searchText,
                navigationPath: $navigationPath
            )
            .navigationTitle("Clusters")
        }
    }

    @ViewBuilder
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Configuration Error")
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 12) {
                Button("Dismiss") {
                    appState.error = nil
                }
                .buttonStyle(.bordered)

                Button("Open Settings") {
                    selectedItem = .settings
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Clusters Found")
                .font(.title2.weight(.semibold))

            Text("No Kubernetes contexts found in your kubeconfig file. Check your settings to configure the correct path.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Open Settings") {
                selectedItem = .settings
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    private func handlePendingNavigation() {
        if let cluster = appState.pendingClusterNavigation {
            appState.pendingClusterNavigation = nil
            if selectedItem != .clusters {
                isProgrammaticNavigation = true
                selectedItem = .clusters
                // Delay path update until after view transition
                DispatchQueue.main.async {
                    navigationPath = NavigationPath()
                    navigationPath.append(cluster)
                }
            } else {
                navigationPath = NavigationPath()
                navigationPath.append(cluster)
            }
        } else if appState.pendingSettingsNavigation {
            appState.pendingSettingsNavigation = false
            if selectedItem != .settings {
                isProgrammaticNavigation = true
                selectedItem = .settings
            }
            navigationPath = NavigationPath()
        } else if let task = appState.pendingTaskNavigation {
            appState.pendingTaskNavigation = nil
            if selectedItem != .tasks {
                isProgrammaticNavigation = true
                selectedItem = .tasks
                // Delay path update until after view transition
                DispatchQueue.main.async {
                    navigationPath = NavigationPath()
                    navigationPath.append(task)
                }
            } else {
                navigationPath = NavigationPath()
                navigationPath.append(task)
            }
        }
    }
}

// MARK: - Focusable TextField (NSViewRepresentable for reliable focus in toolbar)

struct FocusableTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var shouldFocus: Bool
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .exterior
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder

        // Focus when first appearing
        if shouldFocus && !context.coordinator.hasFocused {
            context.coordinator.hasFocused = true
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField
        var hasFocused = false

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

