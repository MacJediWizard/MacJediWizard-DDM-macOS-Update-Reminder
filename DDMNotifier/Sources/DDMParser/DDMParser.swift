//
//  DDMParser.swift
//  DDMmacOSUpdateReminder
//
//  Parses /var/log/install.log for DDM enforcement information
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - DDM Enforcement

struct DDMEnforcement {
    let targetVersion: String
    let targetBuild: String
    let deadline: Date
    let deadlineFormatted: String
    let daysRemaining: Int
    let hoursRemaining: Int
    let isUpgrade: Bool  // Major version change

    func isUpdateRequired(currentVersion: String) -> Bool {
        return compareVersions(currentVersion, targetVersion) == .orderedAscending
    }

    private func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(parts1.count, parts2.count)

        for i in 0..<maxLength {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0

            if p1 < p2 {
                return .orderedAscending
            } else if p1 > p2 {
                return .orderedDescending
            }
        }

        return .orderedSame
    }
}

// MARK: - DDM Parser

class DDMParser {
    private let installLogPath = "/var/log/install.log"

    func parseEnforcement() -> DDMEnforcement? {
        Logger.shared.ddmParsing("Parsing install.log for DDM enforcement")

        guard let logContent = try? String(contentsOfFile: installLogPath, encoding: .utf8) else {
            Logger.shared.ddmParsing("Could not read install.log")
            return nil
        }

        // Find the most recent EnforcedInstallDate entry
        let lines = logContent.components(separatedBy: .newlines)
        var latestEntry: String?

        for line in lines.reversed() {
            if line.contains("EnforcedInstallDate") {
                latestEntry = line
                break
            }
        }

        guard let entry = latestEntry else {
            Logger.shared.ddmParsing("No EnforcedInstallDate entry found")
            return nil
        }

        // Parse the entry
        // Format: ...|EnforcedInstallDate:2025-11-25T12:00:00Z|VersionString:15.1|BuildVersionString:24B83|...
        guard let enforcement = parseLogEntry(entry) else {
            Logger.shared.ddmParsing("Failed to parse DDM enforcement entry")
            return nil
        }

        // Check if deadline has passed - look for setPastDuePaddedEnforcementDate
        let now = Date()
        if enforcement.deadline <= now {
            Logger.shared.ddmParsing("Deadline has passed, checking for padded enforcement date")

            if let paddedDate = findPaddedEnforcementDate(in: logContent) {
                // Create new enforcement with padded date
                return DDMEnforcement(
                    targetVersion: enforcement.targetVersion,
                    targetBuild: enforcement.targetBuild,
                    deadline: paddedDate,
                    deadlineFormatted: formatDeadline(paddedDate),
                    daysRemaining: calculateDaysRemaining(until: paddedDate),
                    hoursRemaining: calculateHoursRemaining(until: paddedDate),
                    isUpgrade: enforcement.isUpgrade
                )
            }
        }

        return enforcement
    }

    private func parseLogEntry(_ entry: String) -> DDMEnforcement? {
        // Extract EnforcedInstallDate
        guard let dateString = extractValue(from: entry, key: "EnforcedInstallDate") else {
            return nil
        }

        // Extract VersionString
        guard let versionString = extractValue(from: entry, key: "VersionString") else {
            return nil
        }

        // Extract BuildVersionString
        let buildString = extractValue(from: entry, key: "BuildVersionString") ?? ""

        // Parse the date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        // Try with Z suffix
        var deadline: Date?
        if dateString.hasSuffix("Z") {
            deadline = dateFormatter.date(from: dateString)
        } else {
            // Try without timezone
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            deadline = formatter.date(from: dateString)
        }

        guard let parsedDeadline = deadline else {
            Logger.shared.ddmParsing("Failed to parse deadline date: \(dateString)")
            return nil
        }

        // Determine if this is an upgrade (major version change)
        let installedVersion = getInstalledMacOSVersion()
        let installedMajor = installedVersion.split(separator: ".").first.map(String.init) ?? "0"
        let targetMajor = versionString.split(separator: ".").first.map(String.init) ?? "0"
        let isUpgrade = installedMajor != targetMajor

        return DDMEnforcement(
            targetVersion: versionString,
            targetBuild: buildString,
            deadline: parsedDeadline,
            deadlineFormatted: formatDeadline(parsedDeadline),
            daysRemaining: calculateDaysRemaining(until: parsedDeadline),
            hoursRemaining: calculateHoursRemaining(until: parsedDeadline),
            isUpgrade: isUpgrade
        )
    }

    private func extractValue(from entry: String, key: String) -> String? {
        // Pattern: |Key:Value|
        let pattern = "\\|\(key):([^|]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: entry, options: [], range: NSRange(entry.startIndex..., in: entry)),
              let range = Range(match.range(at: 1), in: entry) else {
            return nil
        }
        return String(entry[range])
    }

    private func findPaddedEnforcementDate(in logContent: String) -> Date? {
        // Look for: setPastDuePaddedEnforcementDate is set: Thu Nov 13 08:59:56 2025
        let lines = logContent.components(separatedBy: .newlines)

        for line in lines.reversed() {
            if line.contains("setPastDuePaddedEnforcementDate is set:") {
                // Extract the date portion
                if let range = line.range(of: "setPastDuePaddedEnforcementDate is set: ") {
                    let dateString = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                    // Parse: Thu Nov 13 08:59:56 2025
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
                    formatter.locale = Locale(identifier: "en_US_POSIX")

                    if let date = formatter.date(from: dateString) {
                        Logger.shared.ddmParsing("Found padded enforcement date: \(dateString)")
                        return date
                    }
                }
            }
        }

        return nil
    }

    private func formatDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd-MMM-yyyy, h:mm a"
        var formatted = formatter.string(from: date)
        formatted = formatted.replacingOccurrences(of: " AM", with: " a.m.")
        formatted = formatted.replacingOccurrences(of: " PM", with: " p.m.")
        return formatted
    }

    private func calculateDaysRemaining(until date: Date) -> Int {
        let now = Date()
        let seconds = date.timeIntervalSince(now)
        return Int(seconds / 86400)
    }

    private func calculateHoursRemaining(until date: Date) -> Int {
        let now = Date()
        let seconds = date.timeIntervalSince(now)
        return Int(seconds / 3600)
    }

    private func getInstalledMacOSVersion() -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sw_vers")
        process.arguments = ["-productVersion"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
