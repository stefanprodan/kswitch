// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Domain

/// Monitors a directory for `*.kswitch.sh` task scripts.
///
/// Uses polling to reliably detect file changes including new files added to
/// the directory. The polling interval is configurable and defaults to 2 seconds.
@MainActor
public final class TasksWatcher {
    private var pollingTask: Task<Void, Never>?
    private var lastKnownState: [String: TimeInterval] = [:]  // path -> modification timestamp
    private let onChange: @MainActor ([ScriptTask]) -> Void
    private let directoryPath: String
    private let pollInterval: Duration

    public init(
        directoryPath: String,
        pollInterval: Duration = .seconds(2),
        onChange: @escaping @MainActor ([ScriptTask]) -> Void
    ) {
        self.directoryPath = directoryPath
        self.pollInterval = pollInterval
        self.onChange = onChange

        // Initial scan (returns empty array if directory doesn't exist)
        let tasks = discoverTasks()
        lastKnownState = getFileState(for: tasks)
        if !tasks.isEmpty {
            let expandedPath = expandPath(directoryPath)
            AppLog.info("Discovered \(tasks.count) tasks at \(expandedPath)", category: .tasks)
        }
        onChange(tasks)
    }

    public func start() {
        stop()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: self.pollInterval)
                guard !Task.isCancelled else { return }

                let tasks = self.discoverTasks()
                let currentState = self.getFileState(for: tasks)

                // Notify if files changed (added, removed, or modified)
                if currentState != self.lastKnownState {
                    AppLog.info("Tasks directory changed, found \(tasks.count) tasks", category: .tasks)
                    self.lastKnownState = currentState
                    self.onChange(tasks)
                }
            }
        }

        AppLog.debug("Started polling tasks directory", category: .tasks)
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        AppLog.debug("Stopped polling tasks directory", category: .tasks)
    }

    /// Scans the directory for executable `*.kswitch.sh` scripts.
    public func discoverTasks() -> [ScriptTask] {
        let expandedPath = expandPath(directoryPath)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: expandedPath) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)
            var tasks: [ScriptTask] = []

            for filename in contents {
                guard filename.hasSuffix(".kswitch.sh") else { continue }

                let fullPath = (expandedPath as NSString).appendingPathComponent(filename)

                // Check if executable
                guard fileManager.isExecutableFile(atPath: fullPath) else {
                    AppLog.debug("Skipping non-executable: \(filename)", category: .tasks)
                    continue
                }

                let (customName, customDesc) = ScriptTask.parseMetadata(from: fullPath)
                let inputs = ScriptTask.parseInputs(from: fullPath)
                let task = ScriptTask(scriptPath: fullPath, name: customName, description: customDesc, inputs: inputs)
                tasks.append(task)
            }

            tasks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return tasks
        } catch {
            AppLog.error("Failed to scan tasks directory: \(error)", category: .tasks)
            return []
        }
    }

    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return NSHomeDirectory() + path.dropFirst()
        }
        return path
    }

    private func getFileState(for tasks: [ScriptTask]) -> [String: TimeInterval] {
        var state: [String: TimeInterval] = [:]
        let fileManager = FileManager.default
        for task in tasks {
            if let attrs = try? fileManager.attributesOfItem(atPath: task.scriptPath),
               let modDate = attrs[.modificationDate] as? Date {
                // Round to seconds to avoid precision issues
                state[task.scriptPath] = modDate.timeIntervalSince1970.rounded()
            }
        }
        return state
    }

    deinit {
        pollingTask?.cancel()
    }
}
