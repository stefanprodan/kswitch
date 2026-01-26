// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// A view that displays task output with ANSI colors parsed into styled text.
/// Used for both real-time streaming and viewing historical task runs.
struct TaskTerminalView: View {
    let output: Data
    var isStreaming: Bool = false

    // Track previous streaming state to detect completion
    @State private var wasStreaming: Bool = false
    // Cache parsed output to avoid re-parsing on every render
    @State private var attributedText: AttributedString = AttributedString()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(attributedText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)

                // Invisible anchor at the bottom
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onAppear {
                wasStreaming = isStreaming
                attributedText = ANSIParser.parse(output)
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: output) {
                // Re-parse only when output changes
                attributedText = ANSIParser.parse(output)
                // Auto-scroll to bottom when streaming new output
                if isStreaming {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isStreaming) { _, newValue in
                // Scroll one final time when streaming stops (task completed)
                if wasStreaming && !newValue {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                wasStreaming = newValue
            }
        }
    }
}
