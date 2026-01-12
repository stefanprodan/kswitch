import Foundation

@MainActor
final class KubeconfigWatcher {
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var debounceTask: Task<Void, Never>?
    private let onChange: @MainActor () -> Void

    private var kubeconfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kube/config")
    }

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func start() {
        stop()

        guard FileManager.default.fileExists(atPath: kubeconfigURL.path) else {
            Log.warning("Kubeconfig not found at \(kubeconfigURL.path)", category: .kubectl)
            return
        }

        do {
            let handle = try FileHandle(forReadingFrom: kubeconfigURL)
            self.fileHandle = handle

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: handle.fileDescriptor,
                eventMask: [.write, .rename, .delete, .attrib],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                guard let self else { return }
                // Debounce: cancel previous task and wait before triggering
                self.debounceTask?.cancel()
                self.debounceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }
                    Log.info("Kubeconfig file changed", category: .kubectl)
                    self.onChange()
                }
            }

            source.setCancelHandler { [weak self] in
                try? self?.fileHandle?.close()
            }

            source.resume()
            self.source = source
            Log.info("Started watching kubeconfig at \(kubeconfigURL.path)", category: .kubectl)
        } catch {
            Log.error("Failed to watch kubeconfig: \(error)", category: .kubectl)
        }
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        source?.cancel()
        source = nil
        fileHandle = nil
    }

    deinit {
        source?.cancel()
    }
}
