// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import SwiftTerm

/// A read-only terminal view for displaying task output with ANSI color support.
struct TerminalOutputView: NSViewRepresentable {
    let output: Data

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        terminal.configureNativeColors()

        // Configure for read-only display
        terminal.getTerminal().setCursorStyle(.steadyBlock)
        terminal.nativeBackgroundColor = NSColor.textBackgroundColor
        terminal.nativeForegroundColor = NSColor.textColor

        // Set a reasonable terminal size
        terminal.getTerminal().resize(cols: 120, rows: 40)

        // Feed initial output
        if !output.isEmpty {
            terminal.feed(byteArray: ArraySlice(output))
        }

        // Hide cursor (VT100 escape sequence)
        terminal.feed(text: "\u{1b}[?25l")

        return terminal
    }

    func updateNSView(_ terminal: LocalProcessTerminalView, context: Context) {
        // Clear and re-feed when output changes
        terminal.getTerminal().resetToInitialState()
        if !output.isEmpty {
            terminal.feed(byteArray: ArraySlice(output))
        }
        // Hide cursor (VT100 escape sequence)
        terminal.feed(text: "\u{1b}[?25l")
    }
}
