// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import Domain

@Suite struct TaskRunTests {

    // MARK: - succeeded property

    @Test func succeededTrueForExitCodeZeroNotTimedOut() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            timedOut: false
        )
        #expect(run.succeeded == true)
    }

    @Test func succeededFalseForNonZeroExitCode() {
        let run = TaskRun(
            output: Data(),
            exitCode: 1,
            timedOut: false
        )
        #expect(run.succeeded == false)
    }

    @Test func succeededFalseForTimedOut() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            timedOut: true
        )
        #expect(run.succeeded == false)
    }

    @Test func succeededFalseForNonZeroExitCodeAndTimedOut() {
        let run = TaskRun(
            output: Data(),
            exitCode: 127,
            timedOut: true
        )
        #expect(run.succeeded == false)
    }

    // MARK: - formattedDuration property

    @Test func formattedDurationShowsMillisecondsUnderOneSecond() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            duration: 0.5
        )
        #expect(run.formattedDuration == "500ms")
    }

    @Test func formattedDurationShowsSecondsAtOneSecond() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            duration: 1.0
        )
        #expect(run.formattedDuration == "1.0s")
    }

    @Test func formattedDurationRoundsToOneTenth() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            duration: 1.234
        )
        #expect(run.formattedDuration == "1.2s")
    }

    @Test func formattedDurationHandlesZero() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            duration: 0
        )
        #expect(run.formattedDuration == "0ms")
    }

    @Test func formattedDurationHandlesLargeDuration() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            duration: 123.456
        )
        #expect(run.formattedDuration == "123.5s")
    }

    @Test func formattedDurationShowsMillisecondsAt999ms() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0,
            duration: 0.999
        )
        #expect(run.formattedDuration == "999ms")
    }

    // MARK: - Initialization

    @Test func initSetsAllProperties() {
        let output = "test output".data(using: .utf8)!
        let timestamp = Date()
        let inputValues = ["VAR": "value"]

        let run = TaskRun(
            output: output,
            exitCode: 42,
            timestamp: timestamp,
            inputValues: inputValues,
            timedOut: true,
            duration: 5.5
        )

        #expect(run.output == output)
        #expect(run.exitCode == 42)
        #expect(run.timestamp == timestamp)
        #expect(run.inputValues == inputValues)
        #expect(run.timedOut == true)
        #expect(run.duration == 5.5)
    }

    @Test func initUsesDefaultValues() {
        let run = TaskRun(
            output: Data(),
            exitCode: 0
        )

        #expect(run.inputValues.isEmpty)
        #expect(run.timedOut == false)
        #expect(run.duration == 0)
    }
}
