// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite struct KubectlRunnerTests {

    // Settings that provide a kubectl path so tests don't hit real shell
    private func testSettings() -> AppSettings {
        AppSettings(
            kubeconfigPaths: ["/test/.kube/config"],
            kubectlPath: "/usr/local/bin/kubectl",
            refreshIntervalSeconds: 30,
            launchAtLogin: false,
            notificationsEnabled: false,
            autoupdate: false
        )
    }

    @Test func kubectlRunnerCanBeCreated() async {
        let runner = KubectlRunner(settings: { .default })
        let settings = await runner.currentSettings()
        #expect(settings == .default)
    }

    // MARK: - getContexts Tests

    @Test func getContextsParsesNewlineSeparatedOutput() async throws {
        let mock = MockCommandRunner()
        given(mock)
            .run(
                .any,
                args: .any,
                environment: .any,
                timeout: .any
            )
            .willReturn(CommandResult(output: "ctx1\nctx2\nctx3\n", exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let contexts = try await kubectl.getContexts()

        #expect(contexts == ["ctx1", "ctx2", "ctx3"])
    }

    @Test func getContextsHandlesEmptyOutput() async throws {
        let mock = MockCommandRunner()
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: "", exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let contexts = try await kubectl.getContexts()

        #expect(contexts.isEmpty)
    }

    @Test func getContextsFiltersEmptyLines() async throws {
        let mock = MockCommandRunner()
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: "ctx1\n\nctx2\n\n\n", exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let contexts = try await kubectl.getContexts()

        #expect(contexts == ["ctx1", "ctx2"])
    }

    // MARK: - getVersion Tests

    @Test func getVersionParsesJSON() async throws {
        let mock = MockCommandRunner()
        let versionJSON = """
        {
            "clientVersion": {"gitVersion": "v1.30.0"},
            "serverVersion": {"gitVersion": "v1.29.2"}
        }
        """
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: versionJSON, exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let version = try await kubectl.getVersion(context: "test-ctx")

        #expect(version == "v1.29.2")
    }

    @Test func getVersionThrowsOnInvalidJSON() async throws {
        let mock = MockCommandRunner()
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: "not json", exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)

        await #expect(throws: (any Error).self) {
            _ = try await kubectl.getVersion(context: "test-ctx")
        }
    }

    // MARK: - getNodes Tests

    @Test func getNodesParsesJSON() async throws {
        let mock = MockCommandRunner()
        let nodesJSON = """
        {
            "apiVersion": "v1",
            "kind": "NodeList",
            "items": [
                {
                    "metadata": {"uid": "uid-1", "name": "node-1"},
                    "status": {
                        "conditions": [{"type": "Ready", "status": "True"}],
                        "allocatable": {"cpu": "4", "memory": "8Gi", "pods": "110"}
                    }
                },
                {
                    "metadata": {"uid": "uid-2", "name": "node-2"},
                    "status": {
                        "conditions": [{"type": "Ready", "status": "False"}],
                        "allocatable": {"cpu": "2000m", "memory": "4096Mi", "pods": "50"}
                    }
                }
            ]
        }
        """
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: nodesJSON, exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let nodes = try await kubectl.getNodes(context: "test-ctx")

        #expect(nodes.count == 2)

        #expect(nodes[0].id == "uid-1")
        #expect(nodes[0].name == "node-1")
        #expect(nodes[0].isReady == true)
        #expect(nodes[0].cpu == 4000)
        #expect(nodes[0].memory == 8 * 1024 * 1024 * 1024)
        #expect(nodes[0].pods == 110)

        #expect(nodes[1].id == "uid-2")
        #expect(nodes[1].name == "node-2")
        #expect(nodes[1].isReady == false)
        #expect(nodes[1].cpu == 2000)
        #expect(nodes[1].memory == 4096 * 1024 * 1024)
        #expect(nodes[1].pods == 50)
    }

    @Test func getNodesReturnsEmptyArrayForEmptyList() async throws {
        let mock = MockCommandRunner()
        let nodesJSON = """
        {"items": []}
        """
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: nodesJSON, exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let nodes = try await kubectl.getNodes(context: "test-ctx")

        #expect(nodes.isEmpty)
    }

    @Test func getNodesHandlesMissingAllocatable() async throws {
        let mock = MockCommandRunner()
        let nodesJSON = """
        {
            "items": [
                {
                    "metadata": {"uid": "uid-1", "name": "node-1"},
                    "status": {
                        "conditions": [{"type": "Ready", "status": "True"}]
                    }
                }
            ]
        }
        """
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: nodesJSON, exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let nodes = try await kubectl.getNodes(context: "test-ctx")

        #expect(nodes.count == 1)
        #expect(nodes[0].cpu == 0)
        #expect(nodes[0].memory == 0)
        #expect(nodes[0].pods == 0)
    }

    @Test func getNodesHandlesMissingReadyCondition() async throws {
        let mock = MockCommandRunner()
        let nodesJSON = """
        {
            "items": [
                {
                    "metadata": {"uid": "uid-1", "name": "node-1"},
                    "status": {
                        "conditions": [{"type": "DiskPressure", "status": "False"}],
                        "allocatable": {"cpu": "4", "memory": "8Gi", "pods": "110"}
                    }
                }
            ]
        }
        """
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: nodesJSON, exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        let nodes = try await kubectl.getNodes(context: "test-ctx")

        #expect(nodes.count == 1)
        #expect(nodes[0].isReady == false)
    }

    // MARK: - getFluxReport Tests

    @Test func getFluxReportThrowsNotFoundForMissingCRD() async throws {
        let mock = MockCommandRunner()
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(
                output: "error: the server doesn't have a resource type \"fluxreport\"",
                exitCode: 1
            ))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)

        await #expect(throws: KSwitchError.self) {
            _ = try await kubectl.getFluxReport(context: "test-ctx")
        }
    }

    @Test func getFluxReportThrowsNotFoundForEmptyList() async throws {
        let mock = MockCommandRunner()
        let emptyListJSON = """
        {"apiVersion": "v1", "kind": "List", "items": []}
        """
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: emptyListJSON, exitCode: 0))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)

        await #expect(throws: KSwitchError.self) {
            _ = try await kubectl.getFluxReport(context: "test-ctx")
        }
    }

    // MARK: - Error Handling Tests

    @Test func kubectlFailedErrorThrownOnNonZeroExit() async throws {
        let mock = MockCommandRunner()
        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willReturn(CommandResult(output: "connection refused", exitCode: 1))

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)

        await #expect(throws: KSwitchError.self) {
            _ = try await kubectl.getContexts()
        }
    }

    // MARK: - Context Parameter Tests

    @Test func contextParameterPassedToCommand() async throws {
        let mock = MockCommandRunner()
        var capturedArgs: [String]?

        given(mock)
            .run(.any, args: .any, environment: .any, timeout: .any)
            .willProduce { _, args, _, _ in
                capturedArgs = args
                return CommandResult(output: "{\"serverVersion\":{\"gitVersion\":\"v1.29.0\"}}", exitCode: 0)
            }

        let kubectl = KubectlRunner(runner: mock, settings: testSettings)
        _ = try await kubectl.getVersion(context: "my-cluster")

        #expect(capturedArgs?.contains("--context") == true)
        #expect(capturedArgs?.contains("my-cluster") == true)
    }
}
