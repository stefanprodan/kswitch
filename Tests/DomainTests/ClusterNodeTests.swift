// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
@testable import Domain

@Suite struct ClusterNodeTests {

    // MARK: - CPU Parsing

    @Test func parseCPUWholeCores() {
        #expect(ClusterNode.parseCPU("4") == 4000)
        #expect(ClusterNode.parseCPU("1") == 1000)
        #expect(ClusterNode.parseCPU("16") == 16000)
    }

    @Test func parseCPUMillicores() {
        #expect(ClusterNode.parseCPU("250m") == 250)
        #expect(ClusterNode.parseCPU("1500m") == 1500)
        #expect(ClusterNode.parseCPU("100m") == 100)
    }

    @Test func parseCPUDecimalCores() {
        #expect(ClusterNode.parseCPU("0.5") == 500)
        #expect(ClusterNode.parseCPU("1.5") == 1500)
        #expect(ClusterNode.parseCPU("0.25") == 250)
    }

    @Test func parseCPUInvalidReturnsZero() {
        #expect(ClusterNode.parseCPU("") == 0)
        #expect(ClusterNode.parseCPU("invalid") == 0)
    }

    @Test func parseCPUTrimsWhitespace() {
        #expect(ClusterNode.parseCPU("  4  ") == 4000)
        #expect(ClusterNode.parseCPU(" 250m ") == 250)
    }

    // MARK: - Memory Parsing

    @Test func parseMemoryKibibytes() {
        #expect(ClusterNode.parseMemory("1024Ki") == 1024 * 1024)
        #expect(ClusterNode.parseMemory("7950264Ki") == 7950264 * 1024)
    }

    @Test func parseMemoryMebibytes() {
        #expect(ClusterNode.parseMemory("8192Mi") == 8192 * 1024 * 1024)
        #expect(ClusterNode.parseMemory("512Mi") == 512 * 1024 * 1024)
    }

    @Test func parseMemoryGibibytes() {
        #expect(ClusterNode.parseMemory("2Gi") == 2 * 1024 * 1024 * 1024)
        #expect(ClusterNode.parseMemory("64Gi") == 64 * 1024 * 1024 * 1024)
    }

    @Test func parseMemoryTebibytes() {
        #expect(ClusterNode.parseMemory("1Ti") == 1024 * 1024 * 1024 * 1024)
    }

    @Test func parseMemorySIUnits() {
        #expect(ClusterNode.parseMemory("1000K") == 1000 * 1000)
        #expect(ClusterNode.parseMemory("1000M") == 1000 * 1000 * 1000)
        #expect(ClusterNode.parseMemory("2G") == 2 * 1000 * 1000 * 1000)
        #expect(ClusterNode.parseMemory("1T") == 1000 * 1000 * 1000 * 1000)
    }

    @Test func parseMemoryPlainBytes() {
        #expect(ClusterNode.parseMemory("1048576") == 1048576)
    }

    @Test func parseMemoryInvalidReturnsZero() {
        #expect(ClusterNode.parseMemory("") == 0)
        #expect(ClusterNode.parseMemory("invalid") == 0)
    }

    @Test func parseMemoryTrimsWhitespace() {
        #expect(ClusterNode.parseMemory("  2Gi  ") == 2 * 1024 * 1024 * 1024)
    }

    // MARK: - CPU Formatting

    @Test func formatCPUCores() {
        #expect(ClusterNode.formatCPU(4000) == "4 cores")
        #expect(ClusterNode.formatCPU(1000) == "1 core")
        #expect(ClusterNode.formatCPU(16000) == "16 cores")
    }

    @Test func formatCPUMillicores() {
        #expect(ClusterNode.formatCPU(250) == "250m")
        #expect(ClusterNode.formatCPU(1500) == "1500m")
        #expect(ClusterNode.formatCPU(500) == "500m")
    }

    @Test func formatCPUMixedMillicores() {
        // 4500m should show as millicores since not evenly divisible
        #expect(ClusterNode.formatCPU(4500) == "4500m")
    }

    // MARK: - Memory Formatting

    @Test func formatMemoryGibibytes() {
        let gi = Int64(1024 * 1024 * 1024)
        #expect(ClusterNode.formatMemory(2 * gi) == "2Gi")
        #expect(ClusterNode.formatMemory(64 * gi) == "64Gi")
    }

    @Test func formatMemoryMebibytes() {
        let mi = Int64(1024 * 1024)
        #expect(ClusterNode.formatMemory(512 * mi) == "512Mi")
        #expect(ClusterNode.formatMemory(256 * mi) == "256Mi")
    }

    @Test func formatMemoryBytes() {
        #expect(ClusterNode.formatMemory(1024) == "1024B")
    }

    // MARK: - ClusterNode Initialization

    @Test func clusterNodeInitialization() {
        let node = ClusterNode(
            id: "abc123",
            name: "node-1",
            isReady: true,
            cpu: 4000,
            memory: 8 * 1024 * 1024 * 1024,
            pods: 110
        )

        #expect(node.id == "abc123")
        #expect(node.name == "node-1")
        #expect(node.isReady == true)
        #expect(node.cpu == 4000)
        #expect(node.memory == 8 * 1024 * 1024 * 1024)
        #expect(node.pods == 110)
    }

    @Test func clusterNodeEquality() {
        let node1 = ClusterNode(id: "a", name: "node", isReady: true, cpu: 1000, memory: 1024, pods: 10)
        let node2 = ClusterNode(id: "a", name: "node", isReady: true, cpu: 1000, memory: 1024, pods: 10)
        let node3 = ClusterNode(id: "b", name: "node", isReady: true, cpu: 1000, memory: 1024, pods: 10)

        #expect(node1 == node2)
        #expect(node1 != node3)
    }
}
