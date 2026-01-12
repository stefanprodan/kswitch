import Foundation

actor ShellEnvironment {
    static let shared = ShellEnvironment()

    private var cachedEnv: [String: String]?

    func getEnvironment() async throws -> [String: String] {
        if let cached = cachedEnv {
            return cached
        }

        let shell = getUserShell()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", "env"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        var env: [String: String] = [:]
        for line in output.split(separator: "\n") {
            if let idx = line.firstIndex(of: "=") {
                let key = String(line[..<idx])
                let value = String(line[line.index(after: idx)...])
                env[key] = value
            }
        }

        cachedEnv = env
        return env
    }

    private func getUserShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
            return shell
        }
        if let pw = getpwuid(getuid()), let shellPtr = pw.pointee.pw_shell {
            return String(cString: shellPtr)
        }
        return "/bin/zsh"
    }

    func findExecutable(named name: String) async throws -> String? {
        let env = try await getEnvironment()
        let pathStr = env["PATH"] ?? ""
        Log.debug("Searching for \(name) in PATH", category: .shell)
        let pathDirs = pathStr.split(separator: ":").map(String.init)

        for dir in pathDirs {
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
