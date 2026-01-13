import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                Divider()

                infoSection

                Divider()

                feedbackSection

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
            Image(systemName: "helm")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("KSwitch")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Kubernetes context manager")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
                Label("Open GitHub Issue", systemImage: "bubble.left.and.exclamationmark.bubble.right")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
