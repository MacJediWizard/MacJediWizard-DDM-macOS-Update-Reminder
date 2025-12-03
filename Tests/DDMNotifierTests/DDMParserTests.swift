//
//  DDMParserTests.swift
//  DDMmacOSUpdateReminderTests
//
//  Unit tests for DDM log parsing
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import XCTest
@testable import DDMNotifier

final class DDMParserTests: XCTestCase {

    // MARK: - Version Comparison Tests

    func testVersionComparisonEqual() {
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15.0.0", than: "15.0.0"))
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15.0", than: "15.0"))
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15", than: "15"))
    }

    func testVersionComparisonGreater() {
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15.1.0", than: "15.0.0"))
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("16.0.0", than: "15.0.0"))
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15.0.1", than: "15.0.0"))
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15.1", than: "15.0"))
    }

    func testVersionComparisonLess() {
        XCTAssertFalse(DDMParser.isVersionGreaterOrEqual("14.0.0", than: "15.0.0"))
        XCTAssertFalse(DDMParser.isVersionGreaterOrEqual("15.0.0", than: "15.0.1"))
        XCTAssertFalse(DDMParser.isVersionGreaterOrEqual("15.0", than: "15.1"))
    }

    func testVersionComparisonMixedLengths() {
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15.0.0", than: "15"))
        XCTAssertTrue(DDMParser.isVersionGreaterOrEqual("15.1", than: "15.0.0"))
        XCTAssertFalse(DDMParser.isVersionGreaterOrEqual("15", than: "15.0.1"))
    }

    // MARK: - Date Parsing Tests

    func testISO8601DateParsing() {
        let parser = DDMParser()

        // Standard ISO8601 format
        let date1 = parser.parseDate("2025-01-15T09:00:00Z")
        XCTAssertNotNil(date1)

        // With timezone offset
        let date2 = parser.parseDate("2025-01-15T09:00:00-08:00")
        XCTAssertNotNil(date2)

        // Invalid date
        let date3 = parser.parseDate("invalid-date")
        XCTAssertNil(date3)
    }

    // MARK: - Days Remaining Calculation

    func testDaysRemainingCalculation() {
        let parser = DDMParser()

        // Future date
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let daysRemaining = parser.calculateDaysRemaining(from: futureDate)
        XCTAssertEqual(daysRemaining, 5)

        // Past date
        let pastDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let pastDays = parser.calculateDaysRemaining(from: pastDate)
        XCTAssertEqual(pastDays, 0, "Past dates should return 0")

        // Today
        let today = Date()
        let todayDays = parser.calculateDaysRemaining(from: today)
        XCTAssertEqual(todayDays, 0)
    }

    // MARK: - Upgrade vs Update Detection

    func testUpgradeDetection() {
        // Major version change = upgrade
        XCTAssertTrue(DDMParser.isUpgrade(from: "14.0", to: "15.0"))
        XCTAssertTrue(DDMParser.isUpgrade(from: "15.7.2", to: "26.0"))

        // Minor version change = update (not upgrade)
        XCTAssertFalse(DDMParser.isUpgrade(from: "15.0", to: "15.1"))
        XCTAssertFalse(DDMParser.isUpgrade(from: "15.0.0", to: "15.0.1"))

        // Same version = not upgrade
        XCTAssertFalse(DDMParser.isUpgrade(from: "15.0", to: "15.0"))
    }
}

// MARK: - DDMParser Extension for Testing

extension DDMParser {
    /// Test helper to parse dates
    func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    /// Test helper to calculate days remaining
    func calculateDaysRemaining(from deadline: Date) -> Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let deadlineDay = calendar.startOfDay(for: deadline)
        let components = calendar.dateComponents([.day], from: now, to: deadlineDay)
        return max(0, components.day ?? 0)
    }

    /// Test helper for version comparison
    static func isVersionGreaterOrEqual(_ version1: String, than version2: String) -> Bool {
        let v1Parts = version1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Parts.count, v2Parts.count)
        var v1 = v1Parts
        var v2 = v2Parts

        while v1.count < maxLength { v1.append(0) }
        while v2.count < maxLength { v2.append(0) }

        for i in 0..<maxLength {
            if v1[i] > v2[i] { return true }
            if v1[i] < v2[i] { return false }
        }
        return true  // Equal
    }

    /// Test helper for upgrade detection
    static func isUpgrade(from installed: String, to target: String) -> Bool {
        let installedMajor = Int(installed.split(separator: ".").first ?? "0") ?? 0
        let targetMajor = Int(target.split(separator: ".").first ?? "0") ?? 0
        return targetMajor > installedMajor
    }
}
