// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite struct TasksWatcherTests {

    @Test @MainActor func discoverTasksReturnsEmptyWhenDirectoryDoesNotExist() {
        let watcher = TasksWatcher(directoryPath: "/nonexistent/path") { _ in }
        let tasks = watcher.discoverTasks()
        #expect(tasks.isEmpty)
    }

    @Test @MainActor func discoverTasksFindsExecutableScripts() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create executable script
        let scriptPath = tempDir.appendingPathComponent("test.kswitch.sh")
        try "#!/bin/bash\necho hello".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let watcher = TasksWatcher(directoryPath: tempDir.path) { _ in }
        let tasks = watcher.discoverTasks()

        #expect(tasks.count == 1)
        #expect(tasks.first?.name == "test")
    }

    @Test @MainActor func discoverTasksIgnoresNonExecutableFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create non-executable script
        let scriptPath = tempDir.appendingPathComponent("test.kswitch.sh")
        try "#!/bin/bash\necho hello".write(to: scriptPath, atomically: true, encoding: .utf8)
        // Don't set executable permission

        let watcher = TasksWatcher(directoryPath: tempDir.path) { _ in }
        let tasks = watcher.discoverTasks()

        #expect(tasks.isEmpty)
    }

    @Test @MainActor func pollingDetectsNewFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var discoveredTasks: [ScriptTask] = []
        var callCount = 0

        let watcher = TasksWatcher(
            directoryPath: tempDir.path,
            pollInterval: .milliseconds(100)
        ) { tasks in
            discoveredTasks = tasks
            callCount += 1
        }
        watcher.start()

        // Initially empty (first callback happens synchronously in start())
        #expect(discoveredTasks.isEmpty)
        #expect(callCount == 1)

        // Add a script
        let scriptPath = tempDir.appendingPathComponent("new.kswitch.sh")
        try "#!/bin/bash\necho hello".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        // Wait for polling to detect (poll interval is 100ms, wait up to 500ms)
        for _ in 0..<5 {
            try await Task.sleep(for: .milliseconds(150))
            if !discoveredTasks.isEmpty {
                break
            }
        }

        #expect(discoveredTasks.count == 1)
        #expect(discoveredTasks.first?.name == "new")
        watcher.stop()
    }

    @Test @MainActor func pollingDetectsDeletedFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create executable script before starting watcher
        let scriptPath = tempDir.appendingPathComponent("test.kswitch.sh")
        try "#!/bin/bash\necho hello".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        var discoveredTasks: [ScriptTask] = []

        let watcher = TasksWatcher(
            directoryPath: tempDir.path,
            pollInterval: .milliseconds(100)
        ) { tasks in
            discoveredTasks = tasks
        }
        watcher.start()

        // Initially should have one task
        #expect(discoveredTasks.count == 1)

        // Delete the script
        try FileManager.default.removeItem(at: scriptPath)

        // Wait for polling to detect
        for _ in 0..<5 {
            try await Task.sleep(for: .milliseconds(150))
            if discoveredTasks.isEmpty {
                break
            }
        }

        #expect(discoveredTasks.isEmpty)
        watcher.stop()
    }

    @Test @MainActor func pollingDetectsDirectoryCreation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        // Don't create the directory yet
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var discoveredTasks: [ScriptTask] = []

        let watcher = TasksWatcher(
            directoryPath: tempDir.path,
            pollInterval: .milliseconds(100)
        ) { tasks in
            discoveredTasks = tasks
        }
        watcher.start()

        // Initially empty (directory doesn't exist)
        #expect(discoveredTasks.isEmpty)

        // Create directory and add a script
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let scriptPath = tempDir.appendingPathComponent("new.kswitch.sh")
        try "#!/bin/bash\necho hello".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        // Wait for polling to detect
        for _ in 0..<5 {
            try await Task.sleep(for: .milliseconds(150))
            if !discoveredTasks.isEmpty {
                break
            }
        }

        #expect(discoveredTasks.count == 1)
        watcher.stop()
    }
}
