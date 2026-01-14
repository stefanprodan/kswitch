import Testing
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite struct KubectlRunnerTests {
    @Test func kubectlRunnerCanBeCreated() async {
        let runner = KubectlRunner(settings: { .default })
        // Verify it uses default settings
        let settings = await runner.currentSettings()
        #expect(settings == .default)
    }
}
