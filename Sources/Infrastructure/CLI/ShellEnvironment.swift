import Foundation
import Domain

/// Shell-specific command and parsing rules for getting environment from user's shell.
private enum Shell: Sendable {
    case posix  // bash, zsh, sh
    case fish
    case nushell

    static func detect(from shellPath: String) -> Shell {
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()
        switch shellName {
        case "nu", "nushell":
            return .nushell
        case "fish":
            return .fish
        default:
            return .posix
        }
    }

    /// Arguments to pass to the shell to print PATH.
    func pathArguments() -> [String] {
        switch self {
        case .posix, .fish:
            return ["-l", "-c", "echo $PATH"]
        case .nushell:
            return ["-l", "-c", "$env.PATH | str join ':'"]
        }
    }

    /// Parse the output of the PATH command.
    func parsePathOutput(_ output: String) -> String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Provides access to shell environment and executable discovery.
/// Gets PATH from the user's login shell to find tools like aws, gcloud, etc.
public actor ShellEnvironment {
    public static let shared = ShellEnvironment()

    private var cachedSearchPaths: [String]?
    private var cachedShellPath: String?
    private var cachedProtectedPaths: [String]?

    public init() {}

    /// Returns minimal environment variables for kubectl subprocesses.
    /// Uses the user's login shell PATH to ensure exec credential plugins (aws, gcloud, etc.) are found.
    public func getEnvironment(kubeconfigPaths: [String] = []) -> [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]

        if !kubeconfigPaths.isEmpty {
            env["KUBECONFIG"] = kubeconfigPaths.joined(separator: ":")
        }
        if let home = processEnv["HOME"] {
            env["HOME"] = home
        }
        env["PATH"] = getShellPath()

        return env
    }

    /// Gets the user's PATH from their login shell.
    /// This ensures we have access to tools installed via Homebrew, nix-darwin, asdf, etc.
    private func getShellPath() -> String {
        if let cached = cachedShellPath {
            return cached
        }

        let processEnv = ProcessInfo.processInfo.environment
        let fallback = processEnv["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let shellBinary = processEnv["SHELL"] ?? "/bin/zsh"
        let shell = Shell.detect(from: shellBinary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellBinary)
        process.arguments = shell.pathArguments()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                Log.debug("Shell exited with status \(process.terminationStatus), using fallback PATH", category: .shell)
                cachedShellPath = fallback
                return fallback
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                Log.debug("Could not decode shell output, using fallback PATH", category: .shell)
                cachedShellPath = fallback
                return fallback
            }

            let path = shell.parsePathOutput(output)
            if path.isEmpty {
                Log.debug("Shell returned empty PATH, using fallback", category: .shell)
                cachedShellPath = fallback
                return fallback
            }

            Log.debug("Got PATH from login shell: \(path.prefix(100))...", category: .shell)
            cachedShellPath = path
            return path
        } catch {
            Log.debug("Failed to run shell: \(error), using fallback PATH", category: .shell)
            cachedShellPath = fallback
            return fallback
        }
    }

    /// Returns the paths of directories protected by TCC (Transparency, Consent, and Control).
    private func getProtectedPaths() -> [String] {
        if let cached = cachedProtectedPaths {
            return cached
        }

        // We manually construct these paths to avoid triggering permission prompts
        // by asking FileManager for them (which can interpret the request as an access attempt).
        let home = NSHomeDirectory()
        let paths = [
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Downloads"
        ]

        cachedProtectedPaths = paths
        return paths
    }

    /// Returns search paths for executables, prioritizing package managers over system paths.
    /// Order: Homebrew, MacPorts, asdf, mise, Nix, ~/.local/bin, then /etc/paths.
    private func getSearchPaths() -> [String] {
        if let cached = cachedSearchPaths {
            return cached
        }

        let home = NSHomeDirectory()
        var paths: [String] = []

        let packageManagerPaths = [
            "/opt/homebrew/bin",                    // Homebrew (Apple Silicon)
            "/usr/local/bin",                       // Homebrew (Intel)
            "/opt/local/bin",                       // MacPorts
            "\(home)/.asdf/shims",                  // asdf
            "\(home)/.local/share/mise/shims",     // mise
            "\(home)/.nix-profile/bin",             // Nix
            "\(home)/.local/bin",
        ]
        paths.append(contentsOf: packageManagerPaths)

        // Then system paths from /etc/paths
        if let systemPaths = try? String(contentsOfFile: "/etc/paths", encoding: .utf8) {
            for path in systemPaths.split(separator: "\n").map(String.init) {
                if !paths.contains(path) {
                    paths.append(path)
                }
            }
        }

        // Then /etc/paths.d/
        let pathsD = "/etc/paths.d"
        if let files = try? FileManager.default.contentsOfDirectory(atPath: pathsD) {
            for file in files {
                if let content = try? String(contentsOfFile: "\(pathsD)/\(file)", encoding: .utf8) {
                    for path in content.split(separator: "\n").map(String.init) {
                        if !paths.contains(path) {
                            paths.append(path)
                        }
                    }
                }
            }
        }

        cachedSearchPaths = paths
        return paths
    }

    /// Searches for an executable by name in the search paths.
    /// Returns the full path if found, nil otherwise.
    public func findExecutable(named name: String) async throws -> String? {
        let pathDirs = getSearchPaths()
        let protectedPaths = getProtectedPaths()

        for dir in pathDirs {
            // Check raw path first to avoid touching file system if it's clearly protected
            if protectedPaths.contains(where: { protected in
                dir == protected || dir.hasPrefix(protected + "/")
            }) {
                continue
            }

            // Now safely resolve symlinks
            let resolvedDir = URL(fileURLWithPath: dir).resolvingSymlinksInPath().path

            // Check resolved path
            if protectedPaths.contains(where: { protected in
                resolvedDir == protected || resolvedDir.hasPrefix(protected + "/")
            }) {
                continue
            }

            let fullPath = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                Log.debug("Found \(name) at: \(fullPath)", category: .shell)
                return fullPath
            }
        }

        Log.debug("Could not find \(name) in PATH", category: .shell)
        return nil
    }
}
