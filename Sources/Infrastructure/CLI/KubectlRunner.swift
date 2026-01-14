import Foundation
import Domain

public actor KubectlRunner {
    private let settingsProvider: @Sendable () -> AppSettings
    private let runner: CommandRunner
    private var resolvedPath: String?

    private static let commandTimeout: TimeInterval = 10

    public init(
        runner: CommandRunner = DefaultCommandRunner(),
        settings: @escaping @Sendable () -> AppSettings
    ) {
        self.runner = runner
        self.settingsProvider = settings
    }

    private func kubectlPath() async throws -> String {
        let settings = settingsProvider()
        if let configured = settings.kubectlPath, !configured.isEmpty {
            return configured
        }

        if let cached = resolvedPath {
            return cached
        }

        if let found = try await ShellEnvironment.shared.findExecutable(named: "kubectl") {
            Log.info("Found kubectl at: \(found)", category: .kubectl)
            resolvedPath = found
            return found
        }

        Log.error("kubectl not found in PATH", category: .kubectl)
        throw KSwitchError.kubectlNotFound
    }

    private func run(
        _ args: [String],
        context: String? = nil,
        logErrors: Bool = true
    ) async throws -> String {
        let settings = settingsProvider()
        let path = try await kubectlPath()
        let env = await ShellEnvironment.shared.getEnvironment(
            kubeconfigPaths: settings.effectiveKubeconfigPaths
        )

        var fullArgs = args
        if let ctx = context {
            fullArgs = ["--context", ctx] + fullArgs
        }

        let result = try await runner.run(
            path,
            args: fullArgs,
            environment: env,
            timeout: Self.commandTimeout
        )

        guard result.exitCode == 0 else {
            if logErrors {
                Log.error("kubectl failed: \(result.output)", category: .kubectl)
            }
            throw KSwitchError.kubectlFailed(result.output)
        }

        return result.output
    }

    // MARK: - Public API

    public func currentSettings() -> AppSettings {
        settingsProvider()
    }

    public func getContexts() async throws -> [String] {
        let output = try await run(["config", "get-contexts", "-o", "name"])
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    public func getCurrentContext() async throws -> String {
        try await run(["config", "current-context"])
    }

    public func setCurrentContext(_ name: String) async throws {
        Log.info("Switching to context: \(name)", category: .kubectl)
        _ = try await run(["config", "use-context", name])
    }

    public func getVersion(context: String) async throws -> String {
        struct VersionResponse: Decodable {
            struct Version: Decodable {
                let gitVersion: String
            }
            let serverVersion: Version
        }

        let output = try await run(["version", "-o", "json"], context: context)
        let response = try JSONDecoder().decode(VersionResponse.self, from: Data(output.utf8))
        Log.debug("Fetched cluster info for \(context): \(response.serverVersion.gitVersion)", category: .kubectl)
        return response.serverVersion.gitVersion
    }

    public func getNodeCount(context: String) async throws -> Int {
        struct NodeList: Decodable {
            let items: [NodeItem]
            struct NodeItem: Decodable {}
        }

        let output = try await run(["get", "nodes", "-o", "json"], context: context)
        let nodes = try JSONDecoder().decode(NodeList.self, from: Data(output.utf8))
        return nodes.items.count
    }

    public func getFluxReport(context: String) async throws -> FluxReportSpec {
        let output: String
        do {
            // Don't log errors - we handle expected failures (CRD not found)
            output = try await run(["get", "fluxreport", "-A", "-o", "json"], context: context, logErrors: false)
        } catch KSwitchError.kubectlFailed(let message) {
            // CRD not installed - treat as Flux not installed
            if message.contains("doesn't have a resource type") {
                throw KSwitchError.fluxReportNotFound
            }
            // Log unexpected errors
            Log.error("FluxReport fetch failed: \(message)", category: .flux)
            throw KSwitchError.kubectlFailed(message)
        }
        let list = try JSONDecoder().decode(FluxReportList.self, from: Data(output.utf8))
        guard let first = list.items.first else {
            throw KSwitchError.fluxReportNotFound
        }
        Log.debug("Fetched FluxReport for \(context): \(first.spec.operator?.version ?? "unknown")", category: .flux)
        return first.spec
    }
}
