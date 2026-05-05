//
//  CraftPresenceTests.swift
//  CraftPresenceTests
//
//  Created by Nohyunsoo on 4/30/26.
//

import XCTest
@testable import CraftPresence

final class CraftPresenceTests: XCTestCase {
    func testElapsedStartDateResetsToPublishTimeWhenToggleIsEnabled() {
        let previousStart = Date(timeIntervalSince1970: 1_000)
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let preset = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: previousStart,
            resetsElapsedTimeOnPublish: true
        )

        XCTAssertEqual(preset.elapsedStartDateForPublish(now: publishTime), publishTime)
    }

    func testElapsedStartDatePreservesExistingTimeWhenToggleIsDisabled() {
        let previousStart = Date(timeIntervalSince1970: 1_000)
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let preset = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: previousStart,
            resetsElapsedTimeOnPublish: false
        )

        XCTAssertEqual(preset.elapsedStartDateForPublish(now: publishTime), previousStart)
    }

    func testElapsedStartDateIsNilWhenElapsedTimeIsDisabled() {
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let preset = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: false,
            elapsedStartDate: Date(timeIntervalSince1970: 1_000),
            resetsElapsedTimeOnPublish: true
        )

        XCTAssertNil(preset.elapsedStartDateForPublish(now: publishTime))
    }

    func testElapsedStartDateCanPreserveMatchingAppliedPresenceWhenToggleIsDisabled() {
        let previousStart = Date(timeIntervalSince1970: 1_000)
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let appliedPresence = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: previousStart,
            resetsElapsedTimeOnPublish: false
        )
        let draft = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: nil,
            resetsElapsedTimeOnPublish: false
        )

        XCTAssertEqual(
            draft.elapsedStartDateForPublish(now: publishTime, preserving: appliedPresence),
            previousStart
        )
    }
}
