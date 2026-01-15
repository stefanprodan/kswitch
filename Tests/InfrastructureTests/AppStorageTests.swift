import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite struct AppStorageTests {

    // MARK: - Load Tests

    @Test func loadClustersReturnsEmptyArrayWhenFileDoesNotExist() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let storage = AppStorage(storageURL: tempDir)

        let clusters = storage.loadClusters()

        #expect(clusters.isEmpty)
    }

    @Test func loadSettingsReturnsDefaultWhenFileDoesNotExist() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let storage = AppStorage(storageURL: tempDir)

        let settings = storage.loadSettings()

        #expect(settings == .default)
    }

    // MARK: - Save and Load Round Trip

    @Test func saveAndLoadClusters() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let storage = AppStorage(storageURL: tempDir)

        var cluster = Cluster(contextName: "test-cluster")
        cluster.displayName = "Test Cluster"
        cluster.isFavorite = true
        cluster.colorHex = "#FF0000"

        storage.save(clusters: [cluster], settings: .default)
        let loaded = storage.loadClusters()

        #expect(loaded.count == 1)
        #expect(loaded[0].contextName == "test-cluster")
        #expect(loaded[0].displayName == "Test Cluster")
        #expect(loaded[0].isFavorite == true)
        #expect(loaded[0].colorHex == "#FF0000")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func saveAndLoadSettings() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let storage = AppStorage(storageURL: tempDir)

        let settings = AppSettings(
            kubeconfigPaths: ["/custom/path"],
            kubectlPath: "/usr/local/bin/kubectl",
            refreshIntervalSeconds: 60,
            launchAtLogin: true,
            notificationsEnabled: true,
            autoupdate: false
        )

        storage.save(clusters: [], settings: settings)
        let loaded = storage.loadSettings()

        #expect(loaded.kubeconfigPaths == ["/custom/path"])
        #expect(loaded.kubectlPath == "/usr/local/bin/kubectl")
        #expect(loaded.refreshIntervalSeconds == 60)
        #expect(loaded.launchAtLogin == true)
        #expect(loaded.notificationsEnabled == true)
        #expect(loaded.autoupdate == false)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func saveMultipleClusters() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let storage = AppStorage(storageURL: tempDir)

        let clusters = [
            Cluster(contextName: "cluster-1"),
            Cluster(contextName: "cluster-2"),
            Cluster(contextName: "cluster-3"),
        ]

        storage.save(clusters: clusters, settings: .default)
        let loaded = storage.loadClusters()

        #expect(loaded.count == 3)
        #expect(loaded.map { $0.contextName }.sorted() == ["cluster-1", "cluster-2", "cluster-3"])

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func saveOverwritesPreviousData() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let storage = AppStorage(storageURL: tempDir)

        // Save initial data
        storage.save(clusters: [Cluster(contextName: "old-cluster")], settings: .default)

        // Save new data
        storage.save(clusters: [Cluster(contextName: "new-cluster")], settings: .default)

        let loaded = storage.loadClusters()

        #expect(loaded.count == 1)
        #expect(loaded[0].contextName == "new-cluster")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func saveCreatesDirectoryIfNeeded() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nested")
            .appendingPathComponent("directory")
        let storage = AppStorage(storageURL: tempDir)

        storage.save(clusters: [Cluster(contextName: "test")], settings: .default)
        let loaded = storage.loadClusters()

        #expect(loaded.count == 1)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir.deletingLastPathComponent().deletingLastPathComponent())
    }
}
