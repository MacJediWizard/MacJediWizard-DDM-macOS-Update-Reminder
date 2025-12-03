//
//  ConfigurationTests.swift
//  DDMmacOSUpdateReminderTests
//
//  Unit tests for Configuration loading and validation
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import XCTest
@testable import DDMNotifier

final class ConfigurationTests: XCTestCase {

    // MARK: - Bounds Checking Tests

    func testBehaviorSettingsBoundsClampingLow() {
        // Test that values below minimum are clamped
        let dict: [String: Any] = [
            "DaysBeforeDeadlineDisplayReminder": 0,  // min is 1
            "MeetingDelayMinutes": -10,  // min is 0
            "RandomDelayMaxSeconds": -100  // min is 0
        ]

        let defaults = createMockDefaults(with: ["BehaviorSettings": dict])
        let settings = BehaviorSettings.load(from: defaults)

        XCTAssertEqual(settings.daysBeforeDeadlineDisplayReminder, 1, "Should clamp to minimum 1")
        XCTAssertEqual(settings.meetingDelayMinutes, 0, "Should clamp to minimum 0")
        XCTAssertEqual(settings.randomDelayMaxSeconds, 0, "Should clamp to minimum 0")
    }

    func testBehaviorSettingsBoundsClampingHigh() {
        // Test that values above maximum are clamped
        let dict: [String: Any] = [
            "DaysBeforeDeadlineDisplayReminder": 100,  // max is 30
            "MeetingDelayMinutes": 500,  // max is 240
            "RandomDelayMaxSeconds": 10000  // max is 3600
        ]

        let defaults = createMockDefaults(with: ["BehaviorSettings": dict])
        let settings = BehaviorSettings.load(from: defaults)

        XCTAssertEqual(settings.daysBeforeDeadlineDisplayReminder, 30, "Should clamp to maximum 30")
        XCTAssertEqual(settings.meetingDelayMinutes, 240, "Should clamp to maximum 240")
        XCTAssertEqual(settings.randomDelayMaxSeconds, 3600, "Should clamp to maximum 3600")
    }

    func testBehaviorSettingsDefaultValues() {
        let defaults = createMockDefaults(with: [:])
        let settings = BehaviorSettings.load(from: defaults)

        XCTAssertEqual(settings.daysBeforeDeadlineDisplayReminder, 14)
        XCTAssertEqual(settings.daysBeforeDeadlineBlurscreen, 3)
        XCTAssertEqual(settings.meetingDelayMinutes, 75)
        XCTAssertEqual(settings.meetingCheckIntervalSeconds, 300)
        XCTAssertEqual(settings.ignoreAssertionsWithinHours, 24)
        XCTAssertEqual(settings.randomDelayMaxSeconds, 1200)
    }

    func testDeferralSettingsExhaustedBehaviorValidation() {
        // Test invalid exhaustedBehavior falls back to default
        let dict: [String: Any] = [
            "ExhaustedBehavior": "InvalidBehavior"
        ]

        let defaults = createMockDefaults(with: ["DeferralSettings": dict])
        let settings = DeferralSettings.load(from: defaults)

        XCTAssertEqual(settings.exhaustedBehavior, "NoRemindButton", "Invalid behavior should fall back to default")
    }

    func testDeferralSettingsValidBehaviors() {
        for behavior in ["NoRemindButton", "AutoOpenUpdate"] {
            let dict: [String: Any] = ["ExhaustedBehavior": behavior]
            let defaults = createMockDefaults(with: ["DeferralSettings": dict])
            let settings = DeferralSettings.load(from: defaults)

            XCTAssertEqual(settings.exhaustedBehavior, behavior, "Valid behavior '\(behavior)' should be accepted")
        }
    }

    func testBrandingSettingsWindowPositionValidation() {
        // Test invalid position falls back to center
        let dict: [String: Any] = [
            "WindowPosition": "invalid_position"
        ]

        let defaults = createMockDefaults(with: ["BrandingSettings": dict])
        let settings = BrandingSettings.load(from: defaults)

        XCTAssertEqual(settings.windowPosition, "center", "Invalid position should fall back to center")
    }

    func testBrandingSettingsValidPositions() {
        let validPositions = ["center", "topleft", "topright", "bottomleft", "bottomright"]

        for position in validPositions {
            let dict: [String: Any] = ["WindowPosition": position]
            let defaults = createMockDefaults(with: ["BrandingSettings": dict])
            let settings = BrandingSettings.load(from: defaults)

            XCTAssertEqual(settings.windowPosition, position, "Valid position '\(position)' should be accepted")
        }
    }

    func testScheduleSettingsTimeValidation() {
        // Test invalid hour/minute values are clamped
        let dict: [String: Any] = [
            "LaunchDaemonTimes": [
                ["Hour": 25, "Minute": 70],  // Invalid
                ["Hour": -1, "Minute": -5]   // Invalid
            ]
        ]

        let defaults = createMockDefaults(with: ["ScheduleSettings": dict])
        let settings = ScheduleSettings.load(from: defaults)

        XCTAssertEqual(settings.launchDaemonTimes.count, 2)
        XCTAssertEqual(settings.launchDaemonTimes[0].hour, 23, "Hour should clamp to 23")
        XCTAssertEqual(settings.launchDaemonTimes[0].minute, 59, "Minute should clamp to 59")
        XCTAssertEqual(settings.launchDaemonTimes[1].hour, 0, "Hour should clamp to 0")
        XCTAssertEqual(settings.launchDaemonTimes[1].minute, 0, "Minute should clamp to 0")
    }

    // MARK: - Deferral Schedule Tests

    func testDeferralScheduleDefaults() {
        let defaults = createMockDefaults(with: [:])
        let settings = DeferralSettings.load(from: defaults)

        XCTAssertEqual(settings.deferralSchedule.count, 4, "Default schedule should have 4 entries")
        XCTAssertEqual(settings.deferralSchedule[0].daysRemaining, 14)
        XCTAssertEqual(settings.deferralSchedule[0].maxDeferrals, 10)
    }

    func testMaxDeferralsForDaysRemaining() {
        let defaults = createMockDefaults(with: [:])
        let settings = DeferralSettings.load(from: defaults)

        // Default schedule: [14:10, 7:5, 3:2, 1:0]
        // Logic: finds first threshold where daysRemaining >= days (sorted ascending)
        // So for 10 days, schedule sorted is [1:0, 3:2, 7:5, 14:10], first >= 10 is 14:10
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(20), 10, "Days > 14 should use max (fallback)")
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(14), 10, "Day 14 exactly matches threshold")
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(10), 10, "10 days: first threshold >= 10 is 14")
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(7), 5, "Day 7 exactly matches threshold")
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(5), 5, "5 days: first threshold >= 5 is 7")
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(3), 2, "Day 3 exactly matches threshold")
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(1), 0, "Day 1 exactly matches threshold")
        XCTAssertEqual(settings.maxDeferralsForDaysRemaining(0), 0, "Day 0: first threshold >= 0 is 1")
    }

    // MARK: - Helper Functions

    private func createMockDefaults(with values: [String: Any]) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "test.ddmnotifier.\(UUID().uuidString)")!
        for (key, value) in values {
            defaults.set(value, forKey: key)
        }
        // Must set ConfigVersion for profile detection
        if defaults.string(forKey: "ConfigVersion") == nil {
            defaults.set("1.0.0", forKey: "ConfigVersion")
        }
        return defaults
    }
}
