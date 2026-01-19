// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
@testable import Domain

@Suite struct KSwitchErrorTests {

    // MARK: - Error Descriptions

    @Test func kubectlNotFoundHasDescription() {
        let error = KSwitchError.kubectlNotFound
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("kubectl"))
    }

    @Test func kubectlFailedIncludesMessage() {
        let error = KSwitchError.kubectlFailed("connection refused")
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("connection refused"))
    }

    @Test func fluxReportNotFoundHasDescription() {
        let error = KSwitchError.fluxReportNotFound
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("FluxReport"))
    }

    @Test func timeoutHasDescription() {
        let error = KSwitchError.timeout(10)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("timed out"))
        #expect(error.errorDescription!.contains("10s"))
    }

    @Test func decodingFailedIncludesMessage() {
        let error = KSwitchError.decodingFailed("keyNotFound")
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("keyNotFound"))
        #expect(error.errorDescription!.contains("parse"))
    }

    // MARK: - LocalizedError Conformance

    @Test func errorsConformToLocalizedError() {
        let errors: [KSwitchError] = [
            .kubectlNotFound,
            .kubectlFailed("test"),
            .fluxReportNotFound,
            .timeout(30),
            .decodingFailed("test"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Error Equality

    @Test func kubectlNotFoundEqualsKubectlNotFound() {
        let a = KSwitchError.kubectlNotFound
        let b = KSwitchError.kubectlNotFound
        #expect(a.errorDescription == b.errorDescription)
    }

    @Test func kubectlFailedWithSameMessageHasSameDescription() {
        let a = KSwitchError.kubectlFailed("error")
        let b = KSwitchError.kubectlFailed("error")
        #expect(a.errorDescription == b.errorDescription)
    }

    @Test func kubectlFailedWithDifferentMessageHasDifferentDescription() {
        let a = KSwitchError.kubectlFailed("error 1")
        let b = KSwitchError.kubectlFailed("error 2")
        #expect(a.errorDescription != b.errorDescription)
    }
}
