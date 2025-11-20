//
//  HealthReporter.swift
//  DDMmacOSUpdateReminder
//
//  Health state reporting for Extension Attributes
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - Health Status

enum HealthStatus: String, Codable {
    case success = "Success"
    case configMissing = "ConfigMissing"
    case configError = "ConfigError"
    case dialogError = "DialogError"
    case logParseError = "LogParseError"
    case unknown = "Unknown"
}

// MARK: - Health State

struct HealthState: Codable {
    var lastRunDate: Date
    var lastRunStatus: String
    var configProfileDetected: Bool
    var configProfileVersion: String
    var currentEnforcementDeadline: Date?
    var targetVersion: String?
    var deferralsRemaining: Int
    var maxDeferralsAtThreshold: Int
    var lastUserAction: String
    var errorLog: [String]
}

// MARK: - Health Reporter

class HealthReporter {
    private let preferenceDomain: String
    private let configuration: Configuration

    private var healthFilePath: String {
        let appSupport = "/Library/Application Support/\(preferenceDomain)"
        return "\(appSupport)/health.plist"
    }

    init(preferenceDomain: String, configuration: Configuration) {
        self.preferenceDomain = preferenceDomain
        self.configuration = configuration
    }

    // MARK: - Update Health State

    func updateHealthState(
        status: HealthStatus,
        enforcement: DDMEnforcement? = nil,
        deferralManager: DeferralManager? = nil,
        userAction: String = "None",
        error: String? = nil
    ) {
        guard configuration.healthSettings.enableHealthReporting else {
            return
        }

        // Load existing state or create new
        var state = loadHealthState() ?? createEmptyState()

        // Update fields
        state.lastRunDate = Date()
        state.lastRunStatus = status.rawValue
        state.configProfileDetected = true
        state.configProfileVersion = configuration.configVersion
        state.lastUserAction = userAction

        if let enforcement = enforcement {
            state.currentEnforcementDeadline = enforcement.deadline
            state.targetVersion = enforcement.targetVersion
        }

        if let deferralManager = deferralManager, let enforcement = enforcement {
            let days = enforcement.daysRemaining
            state.deferralsRemaining = deferralManager.deferralsRemaining(forDaysRemaining: days)
            state.maxDeferralsAtThreshold = deferralManager.maxDeferralsAtThreshold(forDaysRemaining: days)
        }

        // Add error to log if present
        if let errorMessage = error {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            state.errorLog.append("\(timestamp) - \(errorMessage)")

            // Trim to max entries
            let maxEntries = configuration.healthSettings.maxErrorLogEntries
            if state.errorLog.count > maxEntries {
                state.errorLog = Array(state.errorLog.suffix(maxEntries))
            }
        }

        // Save state
        saveHealthState(state)
        Logger.shared.health("Updated health state: \(status.rawValue)")
    }

    // MARK: - State Management

    private func loadHealthState() -> HealthState? {
        guard FileManager.default.fileExists(atPath: healthFilePath) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: healthFilePath))
            let decoder = PropertyListDecoder()
            return try decoder.decode(HealthState.self, from: data)
        } catch {
            Logger.shared.error("Failed to load health state: \(error.localizedDescription)")
            return nil
        }
    }

    private func saveHealthState(_ state: HealthState) {
        let fileManager = FileManager.default
        let directory = (healthFilePath as NSString).deletingLastPathComponent

        // Create directory if needed
        if !fileManager.fileExists(atPath: directory) {
            do {
                try fileManager.createDirectory(
                    atPath: directory,
                    withIntermediateDirectories: true,
                    attributes: [
                        .posixPermissions: 0o755
                    ]
                )
                // Set ownership separately (createDirectory doesn't support owner attributes)
                try fileManager.setAttributes([
                    .ownerAccountName: "root",
                    .groupOwnerAccountName: "wheel"
                ], ofItemAtPath: directory)
            } catch {
                Logger.shared.error("Failed to create directory: \(error.localizedDescription)")
                return
            }
        }

        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let data = try encoder.encode(state)
            try data.write(to: URL(fileURLWithPath: healthFilePath), options: .atomic)
            // Set file permissions
            try fileManager.setAttributes([
                .posixPermissions: 0o644,
                .ownerAccountName: "root",
                .groupOwnerAccountName: "wheel"
            ], ofItemAtPath: healthFilePath)
        } catch {
            Logger.shared.error("Failed to save health state: \(error.localizedDescription)")
        }
    }

    private func createEmptyState() -> HealthState {
        return HealthState(
            lastRunDate: Date(),
            lastRunStatus: HealthStatus.unknown.rawValue,
            configProfileDetected: false,
            configProfileVersion: "",
            currentEnforcementDeadline: nil,
            targetVersion: nil,
            deferralsRemaining: -1,
            maxDeferralsAtThreshold: 0,
            lastUserAction: "None",
            errorLog: []
        )
    }
}
