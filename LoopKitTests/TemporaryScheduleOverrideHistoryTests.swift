//
//  TemporaryScheduleOverrideHistoryTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 3/25/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit


final class TemporaryScheduleOverrideHistoryTests: XCTestCase {
    // Midnight of an arbitrary date
    let referenceDate = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: .hours(100_000)))

    let basalRateSchedule = BasalRateSchedule(dailyItems: [
        RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
        RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
        RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
    ])!

    let history = TemporaryScheduleOverrideHistory()

    private func recordOverride(
        at offset: TimeInterval,
        duration: TemporaryScheduleOverride.Duration,
        insulinNeedsScaleFactor scaleFactor: Double)
    {
        let settings = TemporaryScheduleOverrideSettings(targetRange: nil, insulinNeedsScaleFactor: scaleFactor)
        let override = TemporaryScheduleOverride(context: .custom, settings: settings, startDate: referenceDate + offset, duration: duration)
        history.recordOverride(override, at: override.startDate)
    }

    private func recordOverrideDisable(at offset: TimeInterval) {
        history.recordOverride(nil, at: referenceDate + offset)
    }

    private func historyResolves(to expected: BasalRateSchedule, referenceDateOffset: TimeInterval = 0) -> Bool {
        let referenceDate = self.referenceDate + referenceDateOffset
        let actual = history.resolvingRecentBasalSchedule(basalRateSchedule, relativeTo: referenceDate)
        return actual.equals(expected, accuracy: 1e-6)
    }

    override func setUp() {
        history.wipeHistory()
    }

    func testEmptyHistory() {
        XCTAssert(historyResolves(to: basalRateSchedule))
    }

    func testSingleOverrideNaturalEnd() {
        recordOverride(at: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(3)))
    }

    func testSingleOverrideEarlyEnd() {
        recordOverride(at: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(3))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(3), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(3)))
    }

    func testSingleIndefiniteOverrideEarlyEnd() {
        recordOverride(at: .hours(2), duration: .indefinite, insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(3))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(3), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(3)))
    }

    func testTwoOverrides() {
        recordOverride(at: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverride(at: .hours(6), duration: .finite(.hours(4)), insulinNeedsScaleFactor: 2.0)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.8),
            RepeatingScheduleValue(startTime: .hours(10), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(10)))
    }

    func testThreeOverrides() {
        recordOverride(at: .hours(5), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(6))
        recordOverride(at: .hours(10), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 2.0)
        recordOverride(at: .hours(12), duration: .finite(.hours(2)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(13))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(10), value: 2.8),
            RepeatingScheduleValue(startTime: .hours(11), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(12), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(13), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(13)))
    }

    func testOldOverrideRemoval() {
        recordOverride(at: .hours(-1000), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 2.0)
        recordOverride(at: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected))
    }

    func testActiveIndefiniteOverride() {
        recordOverride(at: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverride(at: .hours(6), duration: .indefinite, insulinNeedsScaleFactor: 2.0)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.8),
            RepeatingScheduleValue(startTime: .hours(8), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected))
    }
}
