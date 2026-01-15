// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
@testable import Infrastructure

@Suite struct ShellTests {

    // MARK: - Shell Detection

    @Test func detectsPosixFromZsh() {
        let shell = Shell.detect(from: "/bin/zsh")
        #expect(shell == .posix)
    }

    @Test func detectsPosixFromBash() {
        let shell = Shell.detect(from: "/bin/bash")
        #expect(shell == .posix)
    }

    @Test func detectsPosixFromSh() {
        let shell = Shell.detect(from: "/bin/sh")
        #expect(shell == .posix)
    }

    @Test func detectsFish() {
        let shell = Shell.detect(from: "/usr/local/bin/fish")
        #expect(shell == .fish)
    }

    @Test func detectsNushellFromNu() {
        let shell = Shell.detect(from: "/opt/homebrew/bin/nu")
        #expect(shell == .nushell)
    }

    @Test func detectsNushellFromNushell() {
        let shell = Shell.detect(from: "/usr/bin/nushell")
        #expect(shell == .nushell)
    }

    @Test func detectsPosixFromUnknownShell() {
        let shell = Shell.detect(from: "/bin/unknown-shell")
        #expect(shell == .posix)
    }

    // MARK: - PATH Arguments

    @Test func posixPathArguments() {
        let shell = Shell.posix
        #expect(shell.pathArguments() == ["-l", "-c", "echo $PATH"])
    }

    @Test func fishPathArguments() {
        let shell = Shell.fish
        #expect(shell.pathArguments() == ["-l", "-c", "echo $PATH"])
    }

    @Test func nushellPathArguments() {
        let shell = Shell.nushell
        #expect(shell.pathArguments() == ["-l", "-c", "$env.PATH | str join ':'"])
    }

    // MARK: - Which Arguments

    @Test func posixWhichArguments() {
        let shell = Shell.posix
        #expect(shell.whichArguments(for: "kubectl") == ["-l", "-c", "which kubectl"])
    }

    @Test func fishWhichArguments() {
        let shell = Shell.fish
        #expect(shell.whichArguments(for: "kubectl") == ["-l", "-c", "which kubectl"])
    }

    @Test func nushellWhichArguments() {
        let shell = Shell.nushell
        #expect(shell.whichArguments(for: "kubectl") == ["-l", "-c", "^which kubectl"])
    }

    // MARK: - Tool Name Sanitization

    @Test func sanitizesValidToolName() {
        #expect(Shell.sanitizedToolName("kubectl") == "kubectl")
    }

    @Test func sanitizesToolNameWithDots() {
        #expect(Shell.sanitizedToolName("kubectl.exe") == "kubectl.exe")
    }

    @Test func sanitizesToolNameWithDashes() {
        #expect(Shell.sanitizedToolName("kubectl-oidc") == "kubectl-oidc")
    }

    @Test func sanitizesToolNameWithUnderscores() {
        #expect(Shell.sanitizedToolName("my_tool") == "my_tool")
    }

    @Test func rejectsInjectionWithSemicolon() {
        #expect(Shell.sanitizedToolName("kubectl; rm -rf /") == nil)
    }

    @Test func rejectsInjectionWithPipe() {
        #expect(Shell.sanitizedToolName("kubectl | cat /etc/passwd") == nil)
    }

    @Test func rejectsInjectionWithBackticks() {
        #expect(Shell.sanitizedToolName("`whoami`") == nil)
    }

    @Test func rejectsInjectionWithDollar() {
        #expect(Shell.sanitizedToolName("$(whoami)") == nil)
    }

    @Test func rejectsSpaces() {
        #expect(Shell.sanitizedToolName("kubectl version") == nil)
    }

    @Test func whichArgumentsWithInvalidToolReturnsEmptyWhich() {
        let shell = Shell.posix
        let args = shell.whichArguments(for: "kubectl; rm -rf /")
        #expect(args == ["-l", "-c", "which ''"])
    }

    // MARK: - Parse PATH Output

    @Test func parsePathOutputTrimsWhitespace() {
        let shell = Shell.posix
        let result = shell.parsePathOutput("  /usr/bin:/bin  \n")
        #expect(result == "/usr/bin:/bin")
    }

    // MARK: - Parse Which Output

    @Test func posixParseWhichOutput() {
        let shell = Shell.posix
        let result = shell.parseWhichOutput("/usr/local/bin/kubectl\n")
        #expect(result == "/usr/local/bin/kubectl")
    }

    @Test func posixParseWhichOutputEmpty() {
        let shell = Shell.posix
        let result = shell.parseWhichOutput("")
        #expect(result == nil)
    }

    @Test func posixParseWhichOutputWhitespaceOnly() {
        let shell = Shell.posix
        let result = shell.parseWhichOutput("   \n")
        #expect(result == nil)
    }

    @Test func nushellParseWhichOutputValid() {
        let shell = Shell.nushell
        let result = shell.parseWhichOutput("/opt/homebrew/bin/kubectl\n")
        #expect(result == "/opt/homebrew/bin/kubectl")
    }

    @Test func nushellRejectsTableOutput() {
        let shell = Shell.nushell
        // Nushell table output with box-drawing characters
        let tableOutput = """
        ╭───┬─────────┬──────────────────────────╮
        │ # │ command │          path            │
        ├───┼─────────┼──────────────────────────┤
        │ 0 │ kubectl │ /opt/homebrew/bin/kubectl│
        ╰───┴─────────┴──────────────────────────╯
        """
        let result = shell.parseWhichOutput(tableOutput)
        #expect(result == nil)
    }

    @Test func nushellRejectsPartialTableOutput() {
        let shell = Shell.nushell
        // Even partial table characters should be rejected
        let output = "│ kubectl │ /usr/bin/kubectl │"
        let result = shell.parseWhichOutput(output)
        #expect(result == nil)
    }
}
