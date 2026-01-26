// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

/// Minimal shell syntax highlighter for script inspection.
enum ShellSyntaxHighlighter {

    // MARK: - Colors

    private static let commentColor = NSColor.secondaryLabelColor
    private static let stringColor = NSColor(red: 0.133, green: 0.525, blue: 0.227, alpha: 1.0)  // #22863a (green)
    private static let variableColor = NSColor(red: 0.012, green: 0.4, blue: 0.839, alpha: 1.0)  // #0366d6 (blue)
    private static let shebangColor = NSColor(red: 0.435, green: 0.259, blue: 0.757, alpha: 1.0)  // #6f42c1 (purple)

    private static let keywords: Set<String> = [
        "if", "then", "else", "elif", "fi",
        "for", "while", "until", "do", "done",
        "case", "esac", "in",
        "function", "return", "exit",
        "local", "export", "readonly",
        "break", "continue"
    ]

    // MARK: - Public API

    /// Highlights shell script content with syntax coloring.
    static func highlight(_ script: String) -> AttributedString {
        var result = AttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)

        // Process line by line to handle comments correctly
        let lines = script.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, line) in lines.enumerated() {
            let highlighted = highlightLine(String(line), font: font, boldFont: boldFont, isFirstLine: index == 0)
            result.append(highlighted)

            // Add newline between lines (not after the last one)
            if index < lines.count - 1 {
                var newline = AttributedString("\n")
                newline.font = font
                result.append(newline)
            }
        }

        return result
    }

    // MARK: - Line Processing

    private static func highlightLine(_ line: String, font: NSFont, boldFont: NSFont, isFirstLine: Bool) -> AttributedString {
        var result = AttributedString()

        // Check for shebang on first line
        if isFirstLine && line.hasPrefix("#!") {
            var attr = AttributedString(line)
            attr.font = font
            attr.foregroundColor = Color(nsColor: shebangColor)
            return attr
        }

        // Find comment start (outside of strings)
        let commentStart = findCommentStart(in: line)

        if let commentIdx = commentStart {
            // Highlight code before comment
            let codePart = String(line[line.startIndex..<commentIdx])
            result.append(highlightCode(codePart, font: font, boldFont: boldFont))

            // Highlight comment
            let commentPart = String(line[commentIdx...])
            var commentAttr = AttributedString(commentPart)
            commentAttr.font = font
            commentAttr.foregroundColor = Color(nsColor: commentColor)
            result.append(commentAttr)
        } else {
            result.append(highlightCode(line, font: font, boldFont: boldFont))
        }

        return result
    }

    /// Finds the start of a comment (# not inside a string or backticks).
    private static func findCommentStart(in line: String) -> String.Index? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var inBacktick = false
        var prevChar: Character?

        for (offset, char) in line.enumerated() {
            // Handle escape in double quotes
            let escaped = prevChar == "\\" && inDoubleQuote

            if char == "'" && !inDoubleQuote && !inBacktick && !escaped {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote && !inBacktick && !escaped {
                inDoubleQuote.toggle()
            } else if char == "`" && !inSingleQuote && !inDoubleQuote && !escaped {
                inBacktick.toggle()
            } else if char == "#" && !inSingleQuote && !inDoubleQuote && !inBacktick {
                // Check if it's a shebang at line start - still a comment
                // Check if it's part of ${#...} - not a comment
                if let prev = prevChar, prev == "{" {
                    // Part of ${#var} - not a comment
                } else {
                    return line.index(line.startIndex, offsetBy: offset)
                }
            }

            prevChar = char
        }

        return nil
    }

    /// Highlights code (not comments) with strings, variables, and keywords.
    private static func highlightCode(_ code: String, font: NSFont, boldFont: NSFont) -> AttributedString {
        var result = AttributedString()
        var index = code.startIndex

        while index < code.endIndex {
            let char = code[index]

            // Check for strings
            if char == "'" {
                // Single-quoted string - no escapes, no variable expansion
                if let endIdx = findSingleQuoteEnd(in: code, from: index) {
                    let str = String(code[index...endIdx])
                    var attr = AttributedString(str)
                    attr.font = font
                    attr.foregroundColor = Color(nsColor: stringColor)
                    result.append(attr)
                    index = code.index(after: endIdx)
                    continue
                }
            } else if char == "\"" {
                // Double-quoted string - highlight with variables inside
                if let endIdx = findDoubleQuoteEnd(in: code, from: index) {
                    result.append(highlightDoubleQuotedString(code[index...endIdx], font: font))
                    index = code.index(after: endIdx)
                    continue
                }
            } else if char == "`" {
                // Backtick command substitution - highlight with variables inside
                if let endIdx = findBacktickEnd(in: code, from: index) {
                    result.append(highlightBacktickString(code[index...endIdx], font: font))
                    index = code.index(after: endIdx)
                    continue
                }
            }

            // Check for variables
            if char == "$" {
                if let (varStr, endIdx) = parseVariable(in: code, from: index) {
                    var attr = AttributedString(varStr)
                    attr.font = font
                    attr.foregroundColor = Color(nsColor: variableColor)
                    result.append(attr)
                    index = endIdx
                    continue
                }
            }

            // Check for keywords (at word boundary)
            if char.isLetter || char == "_" {
                let wordStart = index
                var wordEnd = index
                while wordEnd < code.endIndex {
                    let c = code[wordEnd]
                    if c.isLetter || c.isNumber || c == "_" {
                        wordEnd = code.index(after: wordEnd)
                    } else {
                        break
                    }
                }

                let word = String(code[wordStart..<wordEnd])
                if keywords.contains(word) && isWordBoundary(code: code, before: wordStart, after: wordEnd) {
                    var attr = AttributedString(word)
                    attr.font = boldFont
                    result.append(attr)
                    index = wordEnd
                    continue
                }
            }

            // Default: just append the character
            var attr = AttributedString(String(char))
            attr.font = font
            result.append(attr)
            index = code.index(after: index)
        }

        return result
    }

    /// Checks if a word is at a word boundary (not part of a larger identifier).
    private static func isWordBoundary(code: String, before: String.Index, after: String.Index) -> Bool {
        // Check character before
        if before > code.startIndex {
            let prevIdx = code.index(before: before)
            let prevChar = code[prevIdx]
            if prevChar.isLetter || prevChar.isNumber || prevChar == "_" {
                return false
            }
        }

        // Check character after
        if after < code.endIndex {
            let nextChar = code[after]
            if nextChar.isLetter || nextChar.isNumber || nextChar == "_" {
                return false
            }
        }

        return true
    }

    /// Highlights a double-quoted string, showing variables in blue.
    private static func highlightDoubleQuotedString(_ str: Substring, font: NSFont) -> AttributedString {
        var result = AttributedString()
        let code = String(str)
        var index = code.startIndex

        while index < code.endIndex {
            let char = code[index]

            // Check for escaped characters
            if char == "\\" && code.index(after: index) < code.endIndex {
                // Include the backslash and the escaped character as string color
                let nextIdx = code.index(after: index)
                var attr = AttributedString(String(code[index...nextIdx]))
                attr.font = font
                attr.foregroundColor = Color(nsColor: stringColor)
                result.append(attr)
                index = code.index(after: nextIdx)
                continue
            }

            // Check for variables
            if char == "$" {
                if let (varStr, endIdx) = parseVariable(in: code, from: index) {
                    var attr = AttributedString(varStr)
                    attr.font = font
                    attr.foregroundColor = Color(nsColor: variableColor)
                    result.append(attr)
                    index = endIdx
                    continue
                }
            }

            // Default: string color
            var attr = AttributedString(String(char))
            attr.font = font
            attr.foregroundColor = Color(nsColor: stringColor)
            result.append(attr)
            index = code.index(after: index)
        }

        return result
    }

    /// Finds the end of a single-quoted string.
    private static func findSingleQuoteEnd(in code: String, from start: String.Index) -> String.Index? {
        var index = code.index(after: start)
        while index < code.endIndex {
            if code[index] == "'" {
                return index
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// Finds the end of a double-quoted string (handling escapes).
    private static func findDoubleQuoteEnd(in code: String, from start: String.Index) -> String.Index? {
        var index = code.index(after: start)
        while index < code.endIndex {
            let char = code[index]
            if char == "\\" {
                // Skip escaped character
                index = code.index(after: index)
                if index < code.endIndex {
                    index = code.index(after: index)
                }
                continue
            }
            if char == "\"" {
                return index
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// Finds the end of a backtick command substitution (handling escapes).
    private static func findBacktickEnd(in code: String, from start: String.Index) -> String.Index? {
        var index = code.index(after: start)
        while index < code.endIndex {
            let char = code[index]
            if char == "\\" {
                // Skip escaped character
                index = code.index(after: index)
                if index < code.endIndex {
                    index = code.index(after: index)
                }
                continue
            }
            if char == "`" {
                return index
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// Highlights a backtick command substitution, showing variables in blue.
    private static func highlightBacktickString(_ str: Substring, font: NSFont) -> AttributedString {
        var result = AttributedString()
        let code = String(str)
        var index = code.startIndex

        while index < code.endIndex {
            let char = code[index]

            // Check for escaped characters
            if char == "\\" && code.index(after: index) < code.endIndex {
                // Include the backslash and the escaped character as string color
                let nextIdx = code.index(after: index)
                var attr = AttributedString(String(code[index...nextIdx]))
                attr.font = font
                attr.foregroundColor = Color(nsColor: stringColor)
                result.append(attr)
                index = code.index(after: nextIdx)
                continue
            }

            // Check for variables
            if char == "$" {
                if let (varStr, endIdx) = parseVariable(in: code, from: index) {
                    var attr = AttributedString(varStr)
                    attr.font = font
                    attr.foregroundColor = Color(nsColor: variableColor)
                    result.append(attr)
                    index = endIdx
                    continue
                }
            }

            // Default: string color
            var attr = AttributedString(String(char))
            attr.font = font
            attr.foregroundColor = Color(nsColor: stringColor)
            result.append(attr)
            index = code.index(after: index)
        }

        return result
    }

    /// Parses a variable starting at $ and returns the variable string and end index.
    private static func parseVariable(in code: String, from start: String.Index) -> (String, String.Index)? {
        guard start < code.endIndex, code[start] == "$" else { return nil }

        var index = code.index(after: start)
        guard index < code.endIndex else {
            return nil
        }

        let nextChar = code[index]

        // ${...} or $(...) forms
        if nextChar == "{" || nextChar == "(" {
            let closeChar: Character = nextChar == "{" ? "}" : ")"
            var depth = 1
            index = code.index(after: index)

            while index < code.endIndex && depth > 0 {
                let c = code[index]
                if c == nextChar {
                    depth += 1
                } else if c == closeChar {
                    depth -= 1
                }
                index = code.index(after: index)
            }

            return (String(code[start..<index]), index)
        }

        // $VAR form - must start with letter or underscore
        if nextChar.isLetter || nextChar == "_" {
            while index < code.endIndex {
                let c = code[index]
                if c.isLetter || c.isNumber || c == "_" {
                    index = code.index(after: index)
                } else {
                    break
                }
            }
            return (String(code[start..<index]), index)
        }

        // Special variables: $?, $!, $$, $#, $@, $*, $0-$9
        // Note: $12 is $1 followed by literal "2", only single digit is captured
        if "?!$#@*0123456789".contains(nextChar) {
            index = code.index(after: index)
            return (String(code[start..<index]), index)
        }

        return nil
    }
}
