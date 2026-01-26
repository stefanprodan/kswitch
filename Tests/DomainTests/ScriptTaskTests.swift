// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import Domain

@Suite struct ScriptTaskTests {

    // MARK: - parseMetadata

    @Test func parseMetadataExtractsBothValues() throws {
        let content = """
        #!/usr/bin/env bash
        set -euo pipefail

        # KSWITCH_TASK: My Custom Task
        # KSWITCH_TASK_DESC: This is a description of my task.

        echo "hello"
        """

        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("test.kswitch.sh").path
        try content.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let (name, description) = ScriptTask.parseMetadata(from: scriptPath)

        #expect(name == "My Custom Task")
        #expect(description == "This is a description of my task.")

        try FileManager.default.removeItem(atPath: scriptPath)
    }

    @Test func parseMetadataExtractsNameOnly() throws {
        let content = """
        #!/usr/bin/env bash
        # KSWITCH_TASK: Task Name Only
        echo "hello"
        """

        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("test_name_only.kswitch.sh").path
        try content.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let (name, description) = ScriptTask.parseMetadata(from: scriptPath)

        #expect(name == "Task Name Only")
        #expect(description == nil)

        try FileManager.default.removeItem(atPath: scriptPath)
    }

    @Test func parseMetadataExtractsDescriptionOnly() throws {
        let content = """
        #!/usr/bin/env bash
        # KSWITCH_TASK_DESC: Description without name.
        echo "hello"
        """

        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("test_desc_only.kswitch.sh").path
        try content.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let (name, description) = ScriptTask.parseMetadata(from: scriptPath)

        #expect(name == nil)
        #expect(description == "Description without name.")

        try FileManager.default.removeItem(atPath: scriptPath)
    }

    @Test func parseMetadataReturnsNilForNoMetadata() throws {
        let content = """
        #!/usr/bin/env bash
        echo "hello"
        """

        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("test_no_meta.kswitch.sh").path
        try content.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let (name, description) = ScriptTask.parseMetadata(from: scriptPath)

        #expect(name == nil)
        #expect(description == nil)

        try FileManager.default.removeItem(atPath: scriptPath)
    }

    @Test func parseMetadataReturnsNilForNonexistentFile() {
        let (name, description) = ScriptTask.parseMetadata(from: "/nonexistent/path/script.sh")

        #expect(name == nil)
        #expect(description == nil)
    }

    @Test func parseMetadataTrimsWhitespace() throws {
        let content = """
        #!/usr/bin/env bash
        # KSWITCH_TASK:   Trimmed Name
        # KSWITCH_TASK_DESC:   Trimmed Description
        echo "hello"
        """

        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("test_trim.kswitch.sh").path
        try content.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let (name, description) = ScriptTask.parseMetadata(from: scriptPath)

        #expect(name == "Trimmed Name")
        #expect(description == "Trimmed Description")

        try FileManager.default.removeItem(atPath: scriptPath)
    }

    // MARK: - ScriptTask Initialization

    @Test func scriptTaskUsesCustomNameWhenProvided() {
        let task = ScriptTask(
            scriptPath: "/path/to/my_script.kswitch.sh",
            name: "Custom Name"
        )
        #expect(task.name == "Custom Name")
    }

    @Test func scriptTaskUsesCustomDescriptionWhenProvided() {
        let task = ScriptTask(
            scriptPath: "/path/to/my_script.kswitch.sh",
            description: "Custom Description"
        )
        #expect(task.description == "Custom Description")
    }

    @Test func scriptTaskFallsBackToFilenameForName() {
        let task = ScriptTask(scriptPath: "/path/to/my_script.kswitch.sh")
        #expect(task.name == "my script")
    }

    @Test func scriptTaskFallsBackToPathForDescription() {
        let task = ScriptTask(scriptPath: "/path/to/my_script.kswitch.sh")
        #expect(task.description == "/path/to/my_script.kswitch.sh")
    }

    @Test func scriptTaskAcceptsAllParameters() {
        let input = TaskInput(name: "VAR", description: "desc", isRequired: true)
        let task = ScriptTask(
            scriptPath: "/path/to/script.kswitch.sh",
            name: "Task Name",
            description: "Task Desc",
            inputs: [input]
        )

        #expect(task.id == "/path/to/script.kswitch.sh")
        #expect(task.scriptPath == "/path/to/script.kswitch.sh")
        #expect(task.name == "Task Name")
        #expect(task.description == "Task Desc")
        #expect(task.inputs.count == 1)
        #expect(task.inputs[0].name == "VAR")
    }

    // MARK: - displayName

    @Test func displayNameRemovesExtension() {
        let name = ScriptTask.displayName(from: "/path/to/my_task.kswitch.sh")
        #expect(name == "my task")
    }

    @Test func displayNameReplacesUnderscoresWithSpaces() {
        let name = ScriptTask.displayName(from: "/path/to/my_cool_task.kswitch.sh")
        #expect(name == "my cool task")
    }

    @Test func displayNameReplacesDashesWithSpaces() {
        let name = ScriptTask.displayName(from: "/path/to/my-cool-task.kswitch.sh")
        #expect(name == "my cool task")
    }
}
