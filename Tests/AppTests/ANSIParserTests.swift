// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import KSwitch

@Suite struct ANSIParserTests {

    // MARK: - Helper to extract plain text from AttributedString

    private func plainText(_ attributed: AttributedString) -> String {
        String(attributed.characters)
    }

    // MARK: - Basic text handling

    @Test func parseReturnsEmptyForEmptyString() {
        let result = ANSIParser.parse("")
        #expect(plainText(result) == "")
    }

    @Test func parseReturnsEmptyForEmptyData() {
        let result = ANSIParser.parse(Data())
        #expect(plainText(result) == "")
    }

    @Test func parsePreservesPlainText() {
        let result = ANSIParser.parse("Hello, World!")
        #expect(plainText(result) == "Hello, World!")
    }

    @Test func parsePreservesMultilineText() {
        let text = "Line 1\nLine 2\nLine 3"
        let result = ANSIParser.parse(text)
        #expect(plainText(result) == "Line 1\nLine 2\nLine 3")
    }

    @Test func parsePreservesTab() {
        let result = ANSIParser.parse("col1\tcol2\tcol3")
        #expect(plainText(result) == "col1\tcol2\tcol3")
    }

    // MARK: - Carriage return processing (spinner collapse)

    @Test func processCarriageReturnsKeepsLastSegment() {
        // "a\rb" should become "b" (carriage return returns to line start)
        let result = ANSIParser.parse("a\rb")
        #expect(plainText(result) == "b")
    }

    @Test func processCarriageReturnsPreservesNewlines() {
        // "a\nb\rc" should become "a\nc" (newline preserved, CR on second line)
        let result = ANSIParser.parse("a\nb\rc")
        #expect(plainText(result) == "a\nc")
    }

    @Test func processCarriageReturnsHandlesMultipleCRs() {
        // Multiple CRs on same line - keep only final text
        let result = ANSIParser.parse("first\rsecond\rthird")
        #expect(plainText(result) == "third")
    }

    @Test func processCarriageReturnsHandlesTrailingCR() {
        // "text\r" keeps the last non-empty segment ("text")
        let result = ANSIParser.parse("text\r")
        #expect(plainText(result) == "text")
    }

    // MARK: - Backspace processing

    @Test func processBackspacesDeletesCharacter() {
        // "abc\x08d" should become "abd" (backspace deletes 'c', then 'd' is added)
        let result = ANSIParser.parse("abc\u{08}d")
        #expect(plainText(result) == "abd")
    }

    @Test func processBackspacesAtStartDoesNothing() {
        // Backspace at start should not crash
        let result = ANSIParser.parse("\u{08}abc")
        #expect(plainText(result) == "abc")
    }

    @Test func processMultipleBackspaces() {
        // "abcd\x08\x08xy" should become "abxy"
        let result = ANSIParser.parse("abcd\u{08}\u{08}xy")
        #expect(plainText(result) == "abxy")
    }

    // MARK: - Control character stripping

    @Test func parseStripsBellCharacter() {
        // Bell (\x07) should be stripped
        let result = ANSIParser.parse("Hello\u{07}World")
        #expect(plainText(result) == "HelloWorld")
    }

    @Test func parseStripsControlD() {
        // ^D (literal caret-D) at start should be stripped
        let result = ANSIParser.parse("^Dhello")
        #expect(plainText(result) == "hello")
    }

    @Test func parseStripsControlDAfterNewline() {
        let result = ANSIParser.parse("line1\n^Dline2")
        #expect(plainText(result) == "line1\nline2")
    }

    @Test func parseStripsOtherControlCharacters() {
        // Control characters like ^C (0x03) should be stripped
        let result = ANSIParser.parse("hello\u{03}world")
        #expect(plainText(result) == "helloworld")
    }

    // MARK: - SGR color codes

    @Test func parseSGRResetClearsStyle() {
        // Reset code should be processed (text should appear without escape)
        let result = ANSIParser.parse("\u{1b}[0mtext")
        #expect(plainText(result) == "text")
    }

    @Test func parseSGRBoldCode() {
        // Bold code should be processed
        let result = ANSIParser.parse("\u{1b}[1mbold text\u{1b}[0m")
        #expect(plainText(result) == "bold text")
    }

    @Test func parseSGRStandardForegroundColors() {
        // Red foreground (31) should be processed
        let result = ANSIParser.parse("\u{1b}[31mred text\u{1b}[0m")
        #expect(plainText(result) == "red text")
    }

    @Test func parseSGRBrightForegroundColors() {
        // Bright red (91) should be processed
        let result = ANSIParser.parse("\u{1b}[91mbright red\u{1b}[0m")
        #expect(plainText(result) == "bright red")
    }

    @Test func parseSGR256ColorForeground() {
        // 256-color mode: 38;5;196 (bright red in 256-color palette)
        let result = ANSIParser.parse("\u{1b}[38;5;196m256 color\u{1b}[0m")
        #expect(plainText(result) == "256 color")
    }

    @Test func parseSGRBackgroundColor() {
        // Blue background (44)
        let result = ANSIParser.parse("\u{1b}[44mblue bg\u{1b}[0m")
        #expect(plainText(result) == "blue bg")
    }

    @Test func parseSGRCombinedCodes() {
        // Bold + red: 1;31
        let result = ANSIParser.parse("\u{1b}[1;31mbold red\u{1b}[0m")
        #expect(plainText(result) == "bold red")
    }

    @Test func parseSGRDefaultForeground() {
        // Default foreground (39)
        let result = ANSIParser.parse("\u{1b}[31mred\u{1b}[39mdefault")
        #expect(plainText(result) == "reddefault")
    }

    // MARK: - Non-CSI escape stripping

    @Test func stripNonCSIRemovesOSCSequence() {
        // OSC sequence terminated with ST (ESC \) is properly stripped
        // Note: BEL-terminated OSC sequences (\x07) won't work because BEL is
        // stripped by the control character filter before OSC parsing
        let result = ANSIParser.parse("\u{1b}]0;Window Title\u{1b}\\actual text")
        #expect(plainText(result) == "actual text")
    }

    @Test func stripNonCSIRemovesOSCWithST() {
        // OSC sequence terminated with ST (ESC \)
        let result = ANSIParser.parse("\u{1b}]0;Title\u{1b}\\text")
        #expect(plainText(result) == "text")
    }

    @Test func stripNonCSIPreservesCSI() {
        // CSI sequences should be preserved for SGR processing
        let result = ANSIParser.parse("\u{1b}[32mgreen")
        #expect(plainText(result) == "green")
    }

    @Test func stripSingleCharEscapes() {
        // Single-char escapes like ESC M (reverse index) should be stripped
        let result = ANSIParser.parse("\u{1b}Mtext")
        #expect(plainText(result) == "text")
    }

    // MARK: - Cursor movement codes (should be stripped)

    @Test func stripsCursorUpCode() {
        // ESC [ n A - cursor up
        let result = ANSIParser.parse("line1\u{1b}[1Aline2")
        #expect(plainText(result) == "line1line2")
    }

    @Test func stripsCursorPositionCode() {
        // ESC [ n ; m H - cursor position
        let result = ANSIParser.parse("\u{1b}[10;20Htext")
        #expect(plainText(result) == "text")
    }

    @Test func stripsEraseLineCode() {
        // ESC [ K - erase to end of line
        let result = ANSIParser.parse("text\u{1b}[Kmore")
        #expect(plainText(result) == "textmore")
    }

    @Test func stripsClearScreenCode() {
        // ESC [ 2 J - clear screen
        let result = ANSIParser.parse("\u{1b}[2Jtext")
        #expect(plainText(result) == "text")
    }

    // MARK: - DEC private mode sequences

    @Test func stripsDECPrivateModeSequence() {
        // ESC [ ? 25 h - show cursor (DEC private mode)
        let result = ANSIParser.parse("\u{1b}[?25htext")
        #expect(plainText(result) == "text")
    }

    // MARK: - Real-world scenarios

    @Test func parseCollapsesSpinnerAnimation() {
        // Simulates a spinner animation that collapses to final state
        let spinner = "⠋ Loading\r⠙ Loading\r⠹ Loading\r✓ Done"
        let result = ANSIParser.parse(spinner)
        #expect(plainText(result) == "✓ Done")
    }

    @Test func parseHandlesColoredSpinner() {
        // Spinner with colors
        let spinner = "\u{1b}[33m⠋\u{1b}[0m Loading\r\u{1b}[33m⠙\u{1b}[0m Loading\r\u{1b}[32m✓\u{1b}[0m Done"
        let result = ANSIParser.parse(spinner)
        #expect(plainText(result) == "✓ Done")
    }

    @Test func parseHandlesProgressBar() {
        // Progress bar that overwrites itself
        let progress = "[====      ] 40%\r[========  ] 80%\r[==========] 100%"
        let result = ANSIParser.parse(progress)
        #expect(plainText(result) == "[==========] 100%")
    }

    @Test func parseHandlesMultiLineOutput() {
        // Multiple lines with colors
        let output = """
        \u{1b}[32m✓\u{1b}[0m Step 1 completed
        \u{1b}[32m✓\u{1b}[0m Step 2 completed
        \u{1b}[31m✗\u{1b}[0m Step 3 failed
        """
        let result = ANSIParser.parse(output)
        let expected = """
        ✓ Step 1 completed
        ✓ Step 2 completed
        ✗ Step 3 failed
        """
        #expect(plainText(result) == expected)
    }

    @Test func parseHandlesKubectlOutput() {
        // Typical kubectl output with colors
        let output = "\u{1b}[0;32mNAME\u{1b}[0m    \u{1b}[0;32mREADY\u{1b}[0m   STATUS"
        let result = ANSIParser.parse(output)
        #expect(plainText(result) == "NAME    READY   STATUS")
    }

    // MARK: - Data input

    @Test func parseFromDataPreservesContent() {
        let text = "Hello from data"
        let data = text.data(using: .utf8)!
        let result = ANSIParser.parse(data)
        #expect(plainText(result) == "Hello from data")
    }

    @Test func parseFromDataHandlesInvalidUTF8() {
        // Invalid UTF-8 sequence should result in empty string
        let invalidData = Data([0xFF, 0xFE])
        let result = ANSIParser.parse(invalidData)
        #expect(plainText(result) == "")
    }

    @Test func parseFromDataWithANSICodes() {
        let text = "\u{1b}[31mred\u{1b}[0m"
        let data = text.data(using: .utf8)!
        let result = ANSIParser.parse(data)
        #expect(plainText(result) == "red")
    }
}
