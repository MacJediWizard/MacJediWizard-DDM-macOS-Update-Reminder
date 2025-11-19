//
//  DeferralManager.swift
//  DDMmacOSUpdateReminder
//
//  Manages deferral and snooze tracking
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - Deferral State

struct DeferralState: Codable {
    var deferralCount: Int
    var lastDeadline: Date?
    var lastDeferralDate: Date?
    var snoozeUntil: Date?
}

// MARK: - Deferral Manager

class DeferralManager {
    private let preferenceDomain: String
    private let configuration: Configuration
    private var state: DeferralState

    private var stateFilePath: String {
        let appSupport = "/Library/Application Support/\(preferenceDomain)"
        return "\(appSupport)/deferral.plist"
    }

    init(preferenceDomain: String, configuration: Configuration) {
        self.preferenceDomain = preferenceDomain
        self.configuration = configuration
        self.state = DeferralState(deferralCount: 0)

        loadState()
    }

    // MARK: - State Management

    private func loadState() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: stateFilePath) else {
            Logger.shared.deferral("No existing deferral state found")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: stateFilePath))
            let decoder = PropertyListDecoder()
            state = try decoder.decode(DeferralState.self, from: data)
            Logger.shared.deferral("Loaded deferral state: \(state.deferralCount) deferrals")
        } catch {
            Logger.shared.error("Failed to load deferral state: \(error.localizedDescription)")
            state = DeferralState(deferralCount: 0)
        }
    }

    private func saveState() {
        let fileManager = FileManager.default
        let directory = (stateFilePath as NSString).deletingLastPathComponent

        // Create directory if needed
        if !fileManager.fileExists(atPath: directory) {
            do {
                try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
            } catch {
                Logger.shared.error("Failed to create directory: \(error.localizedDescription)")
                return
            }
        }

        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let data = try encoder.encode(state)
            try data.write(to: URL(fileURLWithPath: stateFilePath))
            Logger.shared.deferral("Saved deferral state")
        } catch {
            Logger.shared.error("Failed to save deferral state: \(error.localizedDescription)")
        }
    }

    // MARK: - Deferral Logic

    func checkDeadlineChanged(currentDeadline: Date) {
        if let lastDeadline = state.lastDeadline {
            if abs(currentDeadline.timeIntervalSince(lastDeadline)) > 60 {
                // Deadline changed
                if configuration.deferralSettings.resetOnNewDeadline {
                    Logger.shared.deferral("Deadline changed, resetting deferral count")
                    state.deferralCount = 0
                }
            }
        }
        state.lastDeadline = currentDeadline
        saveState()
    }

    func deferralsRemaining(forDaysRemaining days: Int) -> Int {
        let maxAllowed = configuration.deferralSettings.maxDeferralsForDaysRemaining(days)
        return max(0, maxAllowed - state.deferralCount)
    }

    func maxDeferralsAtThreshold(forDaysRemaining days: Int) -> Int {
        return configuration.deferralSettings.maxDeferralsForDaysRemaining(days)
    }

    var deferralsUsed: Int {
        return state.deferralCount
    }

    func canDefer(forDaysRemaining days: Int) -> Bool {
        return deferralsRemaining(forDaysRemaining: days) > 0
    }

    func recordDeferral() {
        state.deferralCount += 1
        state.lastDeferralDate = Date()
        saveState()
        Logger.shared.deferral("Recorded deferral. Total: \(state.deferralCount)")
    }

    // MARK: - Snooze Logic

    func isSnoozeActive() -> Bool {
        guard let snoozeUntil = state.snoozeUntil else {
            return false
        }
        return snoozeUntil > Date()
    }

    func snoozeTimeRemaining() -> Int {
        guard let snoozeUntil = state.snoozeUntil else {
            return 0
        }
        return max(0, Int(snoozeUntil.timeIntervalSinceNow / 60))
    }

    func recordSnooze() {
        let snoozeMinutes = configuration.deferralSettings.snoozeMinutes
        state.snoozeUntil = Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))
        saveState()
        Logger.shared.deferral("Snoozed for \(snoozeMinutes) minutes")
    }

    func clearSnooze() {
        state.snoozeUntil = nil
        saveState()
        Logger.shared.deferral("Cleared snooze")
    }

    // MARK: - Reset

    func reset() {
        state = DeferralState(deferralCount: 0)
        saveState()
        Logger.shared.deferral("Reset all deferral state")
    }
}
