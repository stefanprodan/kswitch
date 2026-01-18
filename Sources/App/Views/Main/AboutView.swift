// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure
#if ENABLE_SPARKLE
import Sparkle
#endif

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    #if ENABLE_SPARKLE
    @Environment(\.sparkleUpdater) private var sparkleUpdater
    #endif

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildDate: String? {
        guard let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let timestamp = TimeInterval(buildNumber) else {
            return nil
        }
        let date = Date(timeIntervalSince1970: timestamp)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                Divider()

                infoSection

                Divider()

                feedbackSection

                #if ENABLE_SPARKLE
                Divider()

                updatesSection
                #endif

                Spacer()
            }
            .padding()
        }
        .navigationTitle("About")
        .toolbarBackground(.visible, for: .windowToolbar)
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 12) {
            AboutIcon()

            VStack(alignment: .leading, spacing: 4) {
                Text("KSwitch")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Kubernetes context manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func AboutIcon() -> some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 64, height: 64)
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Text(appVersion)
                        .textSelection(.enabled)
                }

                if let buildDate {
                    GridRow {
                        Text("Build Date")
                            .foregroundStyle(.secondary)
                        Text(buildDate)
                            .textSelection(.enabled)
                    }
                }

                GridRow {
                    Text("License")
                        .foregroundStyle(.secondary)
                    Text("Apache-2.0")
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("Copyright")
                        .foregroundStyle(.secondary)
                    Text("© 2026 Stefan Prodan")
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("Source Code")
                        .foregroundStyle(.secondary)
                    Link("github.com/stefanprodan/kswitch", destination: URL(string: "https://github.com/stefanprodan/kswitch")!)
                }
            }
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feedback")
                .font(.headline)

            Text("Have a question, found a bug, or want to request a feature?")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                openURL(URL(string: "https://github.com/stefanprodan/kswitch/issues/new")!)
            } label: {
                Label("Open issue", systemImage: "bubble.left.and.exclamationmark.bubble.right")
            }
        }
    }

    #if ENABLE_SPARKLE
    @ViewBuilder
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Updates")
                .font(.headline)

            if sparkleUpdater?.isAvailable == true {
                Button {
                    sparkleUpdater?.checkForUpdates()
                } label: {
                    Label("Check now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(sparkleUpdater?.canCheckForUpdates != true)

                if let lastCheck = sparkleUpdater?.lastUpdateCheckDate {
                    Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Updates unavailable in debug builds")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif
}
