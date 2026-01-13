import Foundation

actor KubectlService {
    private let settingsProvider: @Sendable () -> AppSettings
    private var resolvedPath: String?

    private static let commandTimeout: TimeInterval = 10

    init(settings: @escaping @Sendable () -> AppSettings) {
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = fullArgs
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(Self.commandTimeout))
                if process.isRunning {
                    process.terminate()
                }
            }

            Task {
                do {
                    try process.run()
                    process.waitUntilExit()
                    timeoutTask.cancel()

                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()

                    guard process.terminationStatus == 0 else {
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        let trimmed = errMsg.trimmingCharacters(in: .whitespacesAndNewlines)
                        if logErrors {
                            Log.error("kubectl failed: \(trimmed)", category: .kubectl)
                        }
                        continuation.resume(throwing: KSwitchError.kubectlFailed(trimmed))
                        return
                    }

                    let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    timeoutTask.cancel()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Public API

    func getContexts() async throws -> [String] {
        let output = try await run(["config", "get-contexts", "-o", "name"])
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    func getCurrentContext() async throws -> String {
        try await run(["config", "current-context"])
    }

    func setCurrentContext(_ name: String) async throws {
        Log.info("Switching to context: \(name)", category: .kubectl)
        _ = try await run(["config", "use-context", name])
    }

    func getVersion(context: String) async throws -> String {
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

    func getNodeCount(context: String) async throws -> Int {
        struct NodeList: Decodable {
            let items: [NodeItem]
            struct NodeItem: Decodable {}
        }

        let output = try await run(["get", "nodes", "-o", "json"], context: context)
        let nodes = try JSONDecoder().decode(NodeList.self, from: Data(output.utf8))
        return nodes.items.count
    }

    func getFluxReport(context: String) async throws -> FluxReportSpec {
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
