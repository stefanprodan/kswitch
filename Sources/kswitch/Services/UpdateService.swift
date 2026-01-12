import Foundation
import Sparkle

@MainActor
final class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()

    private var updaterController: SPUStandardUpdaterController?

    @Published var canCheckForUpdates = false

    override init() {
        super.init()

        // Only initialize Sparkle when running as a proper app bundle
        guard Bundle.main.bundleIdentifier != nil else {
            Log.warning("Updates disabled: not running as app bundle", category: .updates)
            return
        }

        // Initialize Sparkle updater
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller

        // Observe updater state
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? false }
        set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    var lastUpdateCheckDate: Date? {
        updaterController?.updater.lastUpdateCheckDate
    }
}
