//
//  HealthReporter.swift
//  DDMmacOSUpdateReminder
//
//  Health state reporting for Extension Attributes
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - Error Codes

/// Structured error codes for programmatic parsing and monitoring
enum ErrorCode: Int, Codable {
    // Success (0xx)
    case success = 0

    // Configuration errors (1xx)
    case configMissing = 100
    case configInvalid = 101
    case configKeyMissing = 102
    case configVersionMismatch = 103

    // Dialog errors (2xx)
    case dialogNotInstalled = 200
    case dialogVersionTooLow = 201
    case dialogExecFailed = 202
    case dialogTimeout = 203
    case dialogDNDEnabled = 204

    // Network errors (3xx)
    case iconDownloadFailed = 300
    case dialogDownloadFailed = 301
    case networkTimeout = 302

    // System errors (4xx)
    case noLoggedInUser = 400
    case logParseError = 401
    case notRunningAsRoot = 402
    case launchDaemonError = 403

    // User action codes (5xx) - not errors, for tracking
    case userOpenedUpdate = 500
    case userDeferred = 501
    case userSnoozed = 502
    case userViewedHelp = 503
    case userTimeout = 504

    var category: String {
        switch self.rawValue {
        case 0..<100: return "Success"
        case 100..<200: return "Configuration"
        case 200..<300: return "Dialog"
        case 300..<400: return "Network"
        case 400..<500: return "System"
        case 500..<600: return "UserAction"
        default: return "Unknown"
        }
    }

    var severity: String {
        switch self.rawValue {
        case 0..<100: return "Info"
        case 500..<600: return "Info"
        default: return "Error"
        }
    }
}

// MARK: - Health Status

enum HealthStatus: String, Codable {
    case success = "Success"
    case configMissing = "ConfigMissing"
    case configError = "ConfigError"
    case dialogError = "DialogError"
    case logParseError = "LogParseError"
    case unknown = "Unknown"

    /// Convert to structured error code
    var errorCode: ErrorCode {
        switch self {
        case .success: return .success
        case .configMissing: return .configMissing
        case .configError: return .configInvalid
        case .dialogError: return .dialogExecFailed
        case .logParseError: return .logParseError
        case .unknown: return .success
        }
    }
}

// MARK: - Error Entry (structured log entry)

struct ErrorEntry: Codable {
    let timestamp: Date
    let code: Int
    let category: String
    let severity: String
    let message: String
    let details: String?
}

// MARK: - Health State

struct HealthState: Codable {
    var lastRunDate: Date
    var lastRunStatus: String
    var lastErrorCode: Int  // Structured error code
    var lastErrorCategory: String  // Error category for filtering
    var configProfileDetected: Bool
    var configProfileVersion: String
    var binaryVersion: String  // Track binary version for fleet visibility
    var currentEnforcementDeadline: Date?
    var targetVersion: String?
    var deferralsRemaining: Int
    var maxDeferralsAtThreshold: Int
    var lastUserAction: String
    var errorLog: [String]  // Legacy string log (backwards compatible)
    var structuredErrorLog: [ErrorEntry]  // New structured error log
}

// MARK: - Health Reporter

class HealthReporter {
    private let preferenceDomain: String
    private let configuration: Configuration

    private var healthFilePath: String {
        let baseDir = "\(configuration.organizationSettings.managementDirectory)/\(preferenceDomain)"
        // Use configured health state path (default: health.plist)
        let filename = configuration.healthSettings.healthStatePath.isEmpty
            ? "health.plist"
            : configuration.healthSettings.healthStatePath
        return "\(baseDir)/\(filename)"
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
        error: String? = nil,
        errorCode: ErrorCode? = nil
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
        state.binaryVersion = appVersion
        state.lastUserAction = userAction

        // Update structured error code
        let code = errorCode ?? status.errorCode
        state.lastErrorCode = code.rawValue
        state.lastErrorCategory = code.category

        if let enforcement = enforcement {
            state.currentEnforcementDeadline = enforcement.deadline
            state.targetVersion = enforcement.targetVersion
        }

        if let deferralManager = deferralManager, let enforcement = enforcement {
            let days = enforcement.daysRemaining
            state.deferralsRemaining = deferralManager.deferralsRemaining(forDaysRemaining: days)
            state.maxDeferralsAtThreshold = deferralManager.maxDeferralsAtThreshold(forDaysRemaining: days)
        }

        // Add error to logs if present
        if let errorMessage = error {
            let timestamp = ISO8601DateFormatter().string(from: Date())

            // Legacy string log (backwards compatible)
            state.errorLog.append("\(timestamp) - \(errorMessage)")

            // New structured error log
            let entry = ErrorEntry(
                timestamp: Date(),
                code: code.rawValue,
                category: code.category,
                severity: code.severity,
                message: errorMessage,
                details: nil
            )
            state.structuredErrorLog.append(entry)

            // Trim to max entries
            let maxEntries = configuration.healthSettings.maxErrorLogEntries
            if state.errorLog.count > maxEntries {
                state.errorLog = Array(state.errorLog.suffix(maxEntries))
            }
            if state.structuredErrorLog.count > maxEntries {
                state.structuredErrorLog = Array(state.structuredErrorLog.suffix(maxEntries))
            }
        }

        // Save state
        saveHealthState(state)
        Logger.shared.health("Updated health state: \(status.rawValue) (code: \(code.rawValue))")
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
            lastErrorCode: ErrorCode.success.rawValue,
            lastErrorCategory: ErrorCode.success.category,
            configProfileDetected: false,
            configProfileVersion: "",
            binaryVersion: appVersion,
            currentEnforcementDeadline: nil,
            targetVersion: nil,
            deferralsRemaining: -1,
            maxDeferralsAtThreshold: 0,
            lastUserAction: "None",
            errorLog: [],
            structuredErrorLog: []
        )
    }
}
