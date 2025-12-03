//
//  Logger.swift
//  DDMmacOSUpdateReminder
//
//  Unified logging infrastructure using os_log
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation
import os.log

// MARK: - Log Categories

enum LogCategory: String {
    case preflight = "preflight"
    case config = "config"
    case ddmParsing = "ddmParsing"
    case deferral = "deferral"
    case dialog = "dialog"
    case userAction = "userAction"
    case health = "health"
    case launchDaemon = "launchDaemon"
    case general = "general"
}

// MARK: - Logger

class Logger {
    static let shared = Logger()

    private var subsystem: String = "com.macjediwizard.ddmmacosupdatereminder"
    private var logs: [LogCategory: OSLog] = [:]

    /// When verbose mode is enabled, debug messages are logged
    var verboseMode: Bool = false

    private init() {
        // Initialize with default subsystem
        createLogs()
    }

    func configure(subsystem: String, verboseLogging: Bool = false) {
        self.subsystem = subsystem
        self.verboseMode = verboseLogging
        createLogs()
        if verboseLogging {
            info("Verbose logging enabled", category: .config)
        }
    }

    private func createLogs() {
        for category in [LogCategory.preflight, .config, .ddmParsing, .deferral,
                         .dialog, .userAction, .health, .launchDaemon, .general] {
            logs[category] = OSLog(subsystem: subsystem, category: category.rawValue)
        }
    }

    // MARK: - Category-Specific Logging

    func preflight(_ message: String) {
        log(message, category: .preflight, type: .info)
    }

    func config(_ message: String) {
        log(message, category: .config, type: .info)
    }

    func ddmParsing(_ message: String) {
        log(message, category: .ddmParsing, type: .info)
    }

    func deferral(_ message: String) {
        log(message, category: .deferral, type: .info)
    }

    func dialog(_ message: String) {
        log(message, category: .dialog, type: .info)
    }

    func userAction(_ message: String) {
        log(message, category: .userAction, type: .info)
    }

    func health(_ message: String) {
        log(message, category: .health, type: .info)
    }

    func launchDaemon(_ message: String) {
        log(message, category: .launchDaemon, type: .info)
    }

    // MARK: - General Logging

    /// Debug messages are only logged when verboseMode is enabled
    func debug(_ message: String, category: LogCategory = .general) {
        guard verboseMode else { return }
        log(message, category: category, type: .debug)
    }

    /// Verbose logging - only logs when verboseMode is enabled (alias for debug)
    func verbose(_ message: String, category: LogCategory = .general) {
        guard verboseMode else { return }
        log(message, category: category, type: .debug)
    }

    func info(_ message: String, category: LogCategory = .general) {
        log(message, category: category, type: .info)
    }

    func warning(_ message: String, category: LogCategory = .general) {
        log(message, category: category, type: .default)
    }

    func error(_ message: String, category: LogCategory = .general) {
        log(message, category: category, type: .error)
    }

    func fault(_ message: String, category: LogCategory = .general) {
        log(message, category: category, type: .fault)
    }

    // MARK: - Core Logging

    private func log(_ message: String, category: LogCategory, type: OSLogType) {
        guard let osLog = logs[category] else {
            // Fallback to default log
            os_log("%{public}@", type: type, message)
            return
        }

        os_log("%{public}@", log: osLog, type: type, message)
    }
}
