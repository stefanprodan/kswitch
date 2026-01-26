// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import Domain

@Suite struct TaskInputTests {

    // MARK: - Initialization

    @Test func initSetsAllProperties() {
        let input = TaskInput(name: "VAR_NAME", description: "A description", isRequired: true)

        #expect(input.name == "VAR_NAME")
        #expect(input.description == "A description")
        #expect(input.isRequired == true)
    }

    @Test func initUsesDefaultDescription() {
        let input = TaskInput(name: "VAR")

        #expect(input.name == "VAR")
        #expect(input.description == "")
    }

    @Test func initUsesDefaultIsRequired() {
        let input = TaskInput(name: "VAR")

        #expect(input.isRequired == true)
    }

    @Test func initCanSetOptional() {
        let input = TaskInput(name: "OPT_VAR", description: "Optional var", isRequired: false)

        #expect(input.name == "OPT_VAR")
        #expect(input.description == "Optional var")
        #expect(input.isRequired == false)
    }

    // MARK: - Hashable

    @Test func taskInputIsHashable() {
        let input1 = TaskInput(name: "VAR", description: "desc", isRequired: true)
        let input2 = TaskInput(name: "VAR", description: "desc", isRequired: true)

        #expect(input1 == input2)
        #expect(input1.hashValue == input2.hashValue)
    }

    @Test func taskInputsWithDifferentNamesAreNotEqual() {
        let input1 = TaskInput(name: "VAR1", description: "desc", isRequired: true)
        let input2 = TaskInput(name: "VAR2", description: "desc", isRequired: true)

        #expect(input1 != input2)
    }

    @Test func taskInputsWithDifferentDescriptionsAreNotEqual() {
        let input1 = TaskInput(name: "VAR", description: "desc1", isRequired: true)
        let input2 = TaskInput(name: "VAR", description: "desc2", isRequired: true)

        #expect(input1 != input2)
    }

    @Test func taskInputsWithDifferentRequiredAreNotEqual() {
        let input1 = TaskInput(name: "VAR", description: "desc", isRequired: true)
        let input2 = TaskInput(name: "VAR", description: "desc", isRequired: false)

        #expect(input1 != input2)
    }

    @Test func taskInputCanBeUsedInSet() {
        let input1 = TaskInput(name: "VAR1", description: "desc", isRequired: true)
        let input2 = TaskInput(name: "VAR2", description: "desc", isRequired: true)
        let input3 = TaskInput(name: "VAR1", description: "desc", isRequired: true)  // Same as input1

        var set = Set<TaskInput>()
        set.insert(input1)
        set.insert(input2)
        set.insert(input3)

        #expect(set.count == 2)
    }
}
