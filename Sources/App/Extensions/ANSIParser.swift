// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

/// Parses ANSI escape codes into AttributedString for terminal history display.
enum ANSIParser {

    /// Standard ANSI colors (0-7) in both normal and bright variants.
    private static let standardColors: [NSColor] = [
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),       // 0: Black
        NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0),       // 1: Red
        NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0),       // 2: Green
        NSColor(red: 0.8, green: 0.8, blue: 0.2, alpha: 1.0),       // 3: Yellow
        NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),       // 4: Blue
        NSColor(red: 0.8, green: 0.2, blue: 0.8, alpha: 1.0),       // 5: Magenta
        NSColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0),       // 6: Cyan
        NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),       // 7: White
    ]

    private static let brightColors: [NSColor] = [
        NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),       // 0: Bright Black (Gray)
        NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),       // 1: Bright Red
        NSColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0),       // 2: Bright Green
        NSColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 1.0),       // 3: Bright Yellow
        NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),       // 4: Bright Blue
        NSColor(red: 1.0, green: 0.3, blue: 1.0, alpha: 1.0),       // 5: Bright Magenta
        NSColor(red: 0.3, green: 1.0, blue: 1.0, alpha: 1.0),       // 6: Bright Cyan
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),       // 7: Bright White
    ]

    /// Current text styling state.
    private struct Style {
        var foreground: NSColor?
        var background: NSColor?
        var bold: Bool = false
        var dim: Bool = false

        mutating func reset() {
            foreground = nil
            background = nil
            bold = false
            dim = false
        }
    }

    /// Parses ANSI-escaped data into an AttributedString suitable for display.
    static func parse(_ data: Data) -> AttributedString {
        guard let text = String(data: data, encoding: .utf8) else {
            return AttributedString()
        }
        return parse(text)
    }

    /// Parses ANSI-escaped text into an AttributedString suitable for display.
    static func parse(_ text: String) -> AttributedString {
        // Strip control characters (^D, ^C, etc.) except newline, tab, carriage return
        var cleaned = text.filter { char in
            guard let ascii = char.asciiValue else { return true }
            // Keep printable chars (0x20+), newline (0x0A), tab (0x09), CR (0x0D), ESC (0x1B)
            return ascii >= 0x20 || ascii == 0x0A || ascii == 0x09 || ascii == 0x0D || ascii == 0x1B
        }

        // Strip literal ^D (caret notation for EOF) that PTY may output
        if cleaned.hasPrefix("^D") {
            cleaned = String(cleaned.dropFirst(2))
        }
        // Also strip if preceded by newline
        cleaned = cleaned.replacingOccurrences(of: "\n^D", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r\n^D", with: "\r\n")

        // Handle carriage return: for each line, only keep text after the last \r
        // This collapses spinner animations into their final state
        cleaned = processCarriageReturns(cleaned)

        // Strip non-CSI escape sequences (OSC, single-char escapes, etc.)
        cleaned = stripNonCSIEscapes(cleaned)

        var result = AttributedString()
        var style = Style()
        var index = cleaned.startIndex

        // Regex to match CSI sequences: ESC [ (optional prefix) params (letter)
        // Handles standard sequences, DEC private modes (?), and secondary DA (>)
        // We specifically look for SGR (ending in 'm') and strip others
        let escapePattern = /\x1b\[[?>]?([0-9;]*)([A-Za-z])/

        while index < cleaned.endIndex {
            // Find the next escape sequence
            let remaining = cleaned[index...]
            if let match = remaining.firstMatch(of: escapePattern) {
                // Add text before the escape sequence
                let beforeEscape = cleaned[index..<match.range.lowerBound]
                if !beforeEscape.isEmpty {
                    var segment = AttributedString(beforeEscape)
                    applyStyle(&segment, style: style)
                    result.append(segment)
                }

                // Process the escape sequence
                let params = String(match.1)
                let command = match.2

                if command == "m" {
                    // SGR (Select Graphic Rendition) - apply styling
                    processSGR(params, style: &style)
                }
                // All other sequences (cursor movement, clear, etc.) are stripped

                index = match.range.upperBound
            } else {
                // No more escape sequences, add remaining text
                let remaining = cleaned[index...]
                if !remaining.isEmpty {
                    var segment = AttributedString(remaining)
                    applyStyle(&segment, style: style)
                    result.append(segment)
                }
                break
            }
        }

        return result
    }

    /// Processes SGR (Select Graphic Rendition) parameters.
    private static func processSGR(_ params: String, style: inout Style) {
        let codes = params.split(separator: ";").compactMap { Int($0) }

        // Empty or "0" means reset
        if codes.isEmpty {
            style.reset()
            return
        }

        var i = 0
        while i < codes.count {
            let code = codes[i]

            switch code {
            case 0:
                style.reset()

            case 1:
                style.bold = true

            case 2:
                style.dim = true

            case 22:
                style.bold = false
                style.dim = false

            // Standard foreground colors (30-37)
            case 30...37:
                style.foreground = standardColors[code - 30]

            // Standard background colors (40-47)
            case 40...47:
                style.background = standardColors[code - 40]

            // Default foreground
            case 39:
                style.foreground = nil

            // Default background
            case 49:
                style.background = nil

            // Bright foreground colors (90-97)
            case 90...97:
                style.foreground = brightColors[code - 90]

            // Bright background colors (100-107)
            case 100...107:
                style.background = brightColors[code - 100]

            // 256-color mode (38;5;n or 48;5;n)
            case 38:
                if i + 2 < codes.count, codes[i + 1] == 5 {
                    style.foreground = color256(codes[i + 2])
                    i += 2
                }

            case 48:
                if i + 2 < codes.count, codes[i + 1] == 5 {
                    style.background = color256(codes[i + 2])
                    i += 2
                }

            default:
                break
            }

            i += 1
        }
    }

    /// Converts a 256-color palette index to NSColor.
    private static func color256(_ index: Int) -> NSColor {
        switch index {
        case 0...7:
            return standardColors[index]
        case 8...15:
            return brightColors[index - 8]
        case 16...231:
            // 6x6x6 color cube
            let adjusted = index - 16
            let r = adjusted / 36
            let g = (adjusted % 36) / 6
            let b = adjusted % 6
            return NSColor(
                red: r == 0 ? 0 : CGFloat(r * 40 + 55) / 255,
                green: g == 0 ? 0 : CGFloat(g * 40 + 55) / 255,
                blue: b == 0 ? 0 : CGFloat(b * 40 + 55) / 255,
                alpha: 1.0
            )
        case 232...255:
            // Grayscale (24 shades)
            let gray = CGFloat((index - 232) * 10 + 8) / 255
            return NSColor(white: gray, alpha: 1.0)
        default:
            return NSColor.textColor
        }
    }

    /// Applies the current style to an AttributedString segment.
    private static func applyStyle(_ segment: inout AttributedString, style: Style) {
        // Font with bold/dim support (12pt matches SwiftTerm default)
        var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        if style.bold {
            font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        }
        segment.font = font

        // Foreground color
        if let fg = style.foreground {
            var color = fg
            if style.dim {
                color = fg.withAlphaComponent(0.6)
            }
            segment.foregroundColor = Color(nsColor: color)
        } else if style.dim {
            segment.foregroundColor = Color(nsColor: NSColor.textColor.withAlphaComponent(0.6))
        }

        // Background color
        if let bg = style.background {
            segment.backgroundColor = Color(nsColor: bg)
        }
    }

    /// Strips non-CSI escape sequences that we don't handle.
    /// - OSC sequences: ESC ] ... BEL or ESC ] ... ST (set window title, etc.)
    /// - Single-char escapes: ESC M, ESC 7, ESC 8, etc.
    private static func stripNonCSIEscapes(_ text: String) -> String {
        var result = ""
        var iterator = text.makeIterator()

        while let char = iterator.next() {
            if char == "\u{1b}" {
                // Found ESC, check next character
                guard let next = iterator.next() else {
                    // ESC at end of string, skip it
                    break
                }

                if next == "[" {
                    // CSI sequence - keep it (will be processed by main parser)
                    result.append(char)
                    result.append(next)
                } else if next == "]" {
                    // OSC sequence - skip until BEL (\x07) or ST (ESC \)
                    while let oscChar = iterator.next() {
                        if oscChar == "\u{07}" {
                            break  // BEL terminates OSC
                        }
                        if oscChar == "\u{1b}" {
                            // Check for ST (ESC \)
                            if let stChar = iterator.next(), stChar == "\\" {
                                break
                            }
                            // Not ST, continue scanning
                        }
                    }
                } else {
                    // Single-character escape (ESC M, ESC 7, etc.) - skip both chars
                    // The next character is consumed and discarded
                }
            } else {
                result.append(char)
            }
        }

        return result
    }

    /// Processes carriage returns to collapse spinner animations.
    /// For each line, keeps only the text after the last \r (unless followed by \n).
    private static func processCarriageReturns(_ text: String) -> String {
        var result: [String] = []

        // Split by newline, preserving the structure
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            // Handle \r\n (Windows line ending) - the \r is not a "return to start"
            // Handle standalone \r - keep only text after the last one
            if line.contains("\r") {
                // Split by \r and take the last non-empty segment
                let segments = line.components(separatedBy: "\r")
                // Find the last non-empty segment (or empty if all are empty)
                if let lastNonEmpty = segments.last(where: { !$0.isEmpty }) {
                    result.append(lastNonEmpty)
                } else {
                    result.append(segments.last ?? "")
                }
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}
