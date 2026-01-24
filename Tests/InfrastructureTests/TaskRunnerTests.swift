// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import Domain
@testable import Infrastructure

/// Thread-safe accumulator for test output chunks.
private final class TestOutputAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var chunks: [Data] = []

    func append(_ data: Data) {
        lock.lock()
        chunks.append(data)
        lock.unlock()
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return chunks.isEmpty
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return chunks.count
    }
}

@Suite struct TaskRunnerTests {

    // MARK: - Exit Code Tests

    @Test func capturesSuccessExitCode() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("success.kswitch.sh")
        try "#!/bin/bash\nexit 0".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()
        let result = await runner.run(task: task)

        #expect(result.exitCode == 0)
        #expect(!result.timedOut)
    }

    @Test func capturesFailureExitCode() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("failure.kswitch.sh")
        try "#!/bin/bash\nexit 42".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()
        let result = await runner.run(task: task)

        #expect(result.exitCode == 42)
    }

    @Test func capturesScriptOutput() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("output.kswitch.sh")
        try "#!/bin/bash\necho 'hello world'".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()
        let result = await runner.run(task: task)

        let output = String(data: result.output, encoding: .utf8) ?? ""
        #expect(output.contains("hello world"))
    }

    // MARK: - UUID Tracking Tests

    @Test func returnsUniqueRunID() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("quick.kswitch.sh")
        try "#!/bin/bash\nexit 0".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()

        let result1 = await runner.run(task: task)
        let result2 = await runner.run(task: task)

        #expect(result1.runID != result2.runID)
    }

    // MARK: - Environment Variable Tests

    @Test func passesInputValuesAsEnvironment() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("env.kswitch.sh")
        try "#!/bin/bash\necho $MY_VAR".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()
        let result = await runner.run(task: task, inputValues: ["MY_VAR": "test_value"])

        let output = String(data: result.output, encoding: .utf8) ?? ""
        #expect(output.contains("test_value"))
    }

    // MARK: - Streaming Output Tests

    @Test func streamsOutputViaCallback() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("stream.kswitch.sh")
        try "#!/bin/bash\necho line1\necho line2".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()

        let accumulator = TestOutputAccumulator()

        _ = await runner.run(task: task, onOutput: { data in
            accumulator.append(data)
        })

        #expect(!accumulator.isEmpty)
    }

    // MARK: - Memory Limit Tests

    @Test func truncatesLargeOutput() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Script that outputs ~15MB (over the 10MB limit)
        let scriptPath = tempDir.appendingPathComponent("large.kswitch.sh")
        try """
        #!/bin/bash
        for i in {1..15000}; do
            printf '%1000s\\n' | tr ' ' 'x'
        done
        """.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()
        let result = await runner.run(task: task, timeoutMinutes: 2)

        // Output should be capped at ~10MB
        let tenMB = 10 * 1024 * 1024
        #expect(result.output.count <= tenMB)
    }

    // MARK: - Stderr Capture Tests

    @Test func capturesStderrOutput() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("stderr.kswitch.sh")
        try "#!/bin/bash\necho 'error message' >&2".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()
        let result = await runner.run(task: task)

        let output = String(data: result.output, encoding: .utf8) ?? ""
        #expect(output.contains("error message"))
    }

    // MARK: - Working Directory Tests

    @Test func runsInScriptDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scriptPath = tempDir.appendingPathComponent("pwd.kswitch.sh")
        try "#!/bin/bash\npwd".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let task = ScriptTask(scriptPath: scriptPath.path)
        let runner = TaskRunner()
        let result = await runner.run(task: task)

        let output = String(data: result.output, encoding: .utf8) ?? ""
        #expect(output.contains(tempDir.path))
    }
}
