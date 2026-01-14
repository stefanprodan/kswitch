import Testing
@testable import Infrastructure
@testable import Domain

@Suite struct DefaultCommandRunnerTests {

    private let runner = DefaultCommandRunner()

    @Test func executesCommandSuccessfully() async throws {
        let result = try await runner.run(
            "/bin/echo",
            args: ["hello", "world"],
            environment: [:],
            timeout: 5
        )

        #expect(result.exitCode == 0)
        #expect(result.output == "hello world")
    }

    @Test func capturesNonZeroExitCode() async throws {
        let result = try await runner.run(
            "/bin/sh",
            args: ["-c", "exit 42"],
            environment: [:],
            timeout: 5
        )

        #expect(result.exitCode == 42)
    }

    @Test func capturesStdoutOutput() async throws {
        let result = try await runner.run(
            "/bin/sh",
            args: ["-c", "echo 'line1'; echo 'line2'"],
            environment: [:],
            timeout: 5
        )

        #expect(result.exitCode == 0)
        #expect(result.output.contains("line1"))
        #expect(result.output.contains("line2"))
    }

    @Test func capturesStderrOnFailure() async throws {
        let result = try await runner.run(
            "/bin/sh",
            args: ["-c", "echo 'error message' >&2; exit 1"],
            environment: [:],
            timeout: 5
        )

        #expect(result.exitCode == 1)
        #expect(result.output.contains("error message"))
    }

    @Test func passesEnvironmentVariables() async throws {
        let result = try await runner.run(
            "/bin/sh",
            args: ["-c", "echo $TEST_VAR"],
            environment: ["TEST_VAR": "test_value"],
            timeout: 5
        )

        #expect(result.exitCode == 0)
        #expect(result.output == "test_value")
    }

    @Test func throwsOnInvalidExecutable() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await runner.run(
                "/nonexistent/path/to/binary",
                args: [],
                environment: [:],
                timeout: 5
            )
        }
    }

    @Test func handlesEmptyOutput() async throws {
        let result = try await runner.run(
            "/bin/sh",
            args: ["-c", "true"],
            environment: [:],
            timeout: 5
        )

        #expect(result.exitCode == 0)
        #expect(result.output.isEmpty)
    }

    @Test func passesArguments() async throws {
        let result = try await runner.run(
            "/bin/sh",
            args: ["-c", "echo $0 $1 $2", "arg0", "arg1", "arg2"],
            environment: [:],
            timeout: 5
        )

        #expect(result.exitCode == 0)
        #expect(result.output.contains("arg0"))
        #expect(result.output.contains("arg1"))
        #expect(result.output.contains("arg2"))
    }
}
