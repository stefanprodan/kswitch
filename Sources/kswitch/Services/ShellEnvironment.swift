import Foundation

/// Provides access to shell environment and executable discovery.
/// Used for finding CLI tools like kubectl without spawning a login shell.
actor ShellEnvironment {
    static let shared = ShellEnvironment()

    private var cachedPath: [String]?
    private var cachedProtectedPaths: [String]?

    /// Returns minimal environment variables for kubectl subprocesses.
    func getEnvironment(kubeconfigPaths: [String] = []) -> [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]

        if !kubeconfigPaths.isEmpty {
            env["KUBECONFIG"] = kubeconfigPaths.joined(separator: ":")
        }
        if let home = processEnv["HOME"] {
            env["HOME"] = home
        }
        if let path = processEnv["PATH"] {
            env["PATH"] = path
        }

        return env
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
        if let cached = cachedPath {
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

        cachedPath = paths
        return paths
    }

    /// Searches for an executable by name in the search paths.
    /// Returns the full path if found, nil otherwise.
    func findExecutable(named name: String) async throws -> String? {
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
