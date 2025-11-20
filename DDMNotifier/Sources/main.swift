//
//  main.swift
//  DDMmacOSUpdateReminder
//
//  A Swift binary that provides configurable end-user notifications
//  for Apple's Declarative Device Management enforced macOS updates.
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - Version Info
let appVersion = "1.1.1"
let appName = "DDMmacOSUpdateReminder"

// MARK: - Main Entry Point

func main() {
    // Parse command-line arguments
    let arguments = CommandLine.arguments
    var preferenceDomain: String?
    var runSetup = false
    var testMode = false
    var debugMode = false
    var syncCheckMode = false

    var i = 1
    while i < arguments.count {
        let arg = arguments[i]

        switch arg {
        case "--version", "-v":
            print("\(appName) version \(appVersion)")
            exit(0)

        case "--help", "-h":
            printUsage()
            exit(0)

        case "--domain":
            if i + 1 < arguments.count {
                i += 1
                preferenceDomain = arguments[i]
            } else {
                Logger.shared.error("--domain requires a preference domain argument")
                exit(1)
            }

        case "--setup":
            runSetup = true

        case "--test":
            testMode = true

        case "--debug":
            debugMode = true

        case "--sync-check":
            syncCheckMode = true

        default:
            Logger.shared.error("Unknown argument: \(arg)")
            printUsage()
            exit(1)
        }

        i += 1
    }

    // Validate required arguments
    guard let domain = preferenceDomain else {
        Logger.shared.error("Missing required --domain argument")
        printUsage()
        exit(1)
    }

    // Security: Validate preference domain format (reverse domain notation)
    // Allows alphanumeric, hyphens, and dots (e.g., com.your-org.app)
    let domainPattern = "^[a-zA-Z0-9-]+(\\.[a-zA-Z0-9-]+)+$"
    guard domain.range(of: domainPattern, options: .regularExpression) != nil else {
        Logger.shared.error("Invalid preference domain format. Must be reverse domain notation (e.g., com.example.app)")
        exit(1)
    }

    // Initialize logger with the preference domain as subsystem
    Logger.shared.configure(subsystem: domain)

    Logger.shared.info("Starting \(appName) v\(appVersion)")
    Logger.shared.info("Preference domain: \(domain)")

    // Run the application
    let app = DDMUpdateReminderApp(
        preferenceDomain: domain,
        setupMode: runSetup,
        testMode: testMode,
        debugMode: debugMode,
        syncCheckMode: syncCheckMode
    )

    let exitCode = app.run()
    exit(exitCode)
}

// MARK: - Usage

func printUsage() {
    print("""
    Usage: \(appName) --domain <preference.domain> [options]

    Required:
      --domain <domain>    Preference domain for managed preferences
                          (e.g., com.yourorg.ddmmacosupdatereminder)

    Options:
      --setup              Create/update LaunchDaemons and exit
      --sync-check         Check if LaunchDaemon schedule needs updating
      --test               Run in test mode (show dialog regardless of DDM state)
      --debug              Skip root check (for Xcode testing only)
      --version, -v        Print version and exit
      --help, -h           Print this help message

    Examples:
      \(appName) --domain com.yourorg.ddmmacosupdatereminder
      \(appName) --domain com.yourorg.ddmmacosupdatereminder --setup
      \(appName) --domain com.yourorg.ddmmacosupdatereminder --sync-check
      \(appName) --domain com.yourorg.ddmmacosupdatereminder --test
    """)
}

// MARK: - Application Class

class DDMUpdateReminderApp {
    let preferenceDomain: String
    let setupMode: Bool
    let testMode: Bool
    let debugMode: Bool
    let syncCheckMode: Bool

    private var configuration: Configuration?
    private var healthReporter: HealthReporter?

    init(preferenceDomain: String, setupMode: Bool, testMode: Bool, debugMode: Bool, syncCheckMode: Bool) {
        self.preferenceDomain = preferenceDomain
        self.setupMode = setupMode
        self.testMode = testMode
        self.debugMode = debugMode
        self.syncCheckMode = syncCheckMode
    }

    func run() -> Int32 {
        // Preflight checks
        guard performPreflightChecks() else {
            return 1
        }

        // Load configuration
        let configLoaded = loadConfiguration()

        // Initialize health reporter (after config attempt, so we can report config errors)
        // Skip in debug mode - can't write to /Library without root
        if let config = configuration, !debugMode {
            healthReporter = HealthReporter(
                preferenceDomain: preferenceDomain,
                configuration: config
            )
        } else if debugMode {
            Logger.shared.preflight("Debug mode: skipping health reporter initialization")
        }

        guard configLoaded else {
            return 1
        }

        // Setup mode - create/update LaunchDaemons and exit
        if setupMode {
            return performSetup()
        }

        // Sync check mode - check if schedule needs updating and exit
        if syncCheckMode {
            return performSyncCheck()
        }

        // Normal operation
        return performReminder()
    }

    // MARK: - Preflight Checks

    private func performPreflightChecks() -> Bool {
        Logger.shared.preflight("Running preflight checks")

        // Check running as root (skip in debug mode)
        if debugMode {
            Logger.shared.preflight("Debug mode: skipping root check")
        } else {
            guard getuid() == 0 else {
                Logger.shared.error("Must be run as root")
                return false
            }
            Logger.shared.preflight("Running as root: OK")
        }

        // Check for logged-in user
        let loggedInUser = getLoggedInUser()
        guard !loggedInUser.isEmpty && loggedInUser != "loginwindow" else {
            Logger.shared.error("No logged-in user found")
            return false
        }
        Logger.shared.preflight("Logged-in user: \(loggedInUser)")

        Logger.shared.preflight("Preflight checks complete")
        return true
    }

    // MARK: - Configuration

    private func loadConfiguration() -> Bool {
        Logger.shared.config("Loading configuration from: \(preferenceDomain)")

        do {
            configuration = try Configuration.load(from: preferenceDomain)
            Logger.shared.config("Configuration loaded successfully")
            Logger.shared.config("Config version: \(configuration!.configVersion)")
            return true
        } catch ConfigurationError.profileNotFound {
            Logger.shared.error("Configuration profile not found for domain: \(preferenceDomain)")
            writeConfigErrorToHealth(status: "ConfigMissing", error: "Configuration profile not found")
            return false
        } catch ConfigurationError.missingRequiredKey(let key) {
            Logger.shared.error("Missing required configuration key: \(key)")
            writeConfigErrorToHealth(status: "ConfigError", error: "Missing required key: \(key)")
            return false
        } catch {
            Logger.shared.error("Failed to load configuration: \(error.localizedDescription)")
            writeConfigErrorToHealth(status: "ConfigError", error: error.localizedDescription)
            return false
        }
    }

    /// Writes configuration errors directly to health file (before healthReporter is available)
    private func writeConfigErrorToHealth(status: String, error: String) {
        // Skip in debug mode - can't write to /Library without root
        if debugMode {
            Logger.shared.preflight("Debug mode: skipping health file write")
            return
        }

        // Use default path since configuration is not available when this is called
        // Note: If ManagementDirectory is customized, this error state won't appear in the custom location
        let directory = "/Library/Application Support/\(preferenceDomain)"
        let healthPath = "\(directory)/health.plist"
        let fileManager = FileManager.default

        // Create directory if needed
        if !fileManager.fileExists(atPath: directory) {
            do {
                try fileManager.createDirectory(
                    atPath: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o755]
                )
                try fileManager.setAttributes([
                    .ownerAccountName: "root",
                    .groupOwnerAccountName: "wheel"
                ], ofItemAtPath: directory)
            } catch {
                Logger.shared.error("Failed to create directory for health file: \(error.localizedDescription)")
                return
            }
        }

        // Create minimal health state dictionary
        let dateFormatter = ISO8601DateFormatter()
        let healthDict: [String: Any] = [
            "LastRunDate": dateFormatter.string(from: Date()),
            "LastRunStatus": status,
            "ConfigProfileDetected": false,
            "LastUserAction": "None",
            "ErrorLog": ["\(dateFormatter.string(from: Date())) - \(error)"]
        ]

        // Write plist
        do {
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: healthDict,
                format: .xml,
                options: 0
            )
            try plistData.write(to: URL(fileURLWithPath: healthPath), options: .atomic)
            try fileManager.setAttributes([
                .posixPermissions: 0o644,
                .ownerAccountName: "root",
                .groupOwnerAccountName: "wheel"
            ], ofItemAtPath: healthPath)
        } catch {
            Logger.shared.error("Failed to write config error to health file: \(error.localizedDescription)")
        }
    }

    // MARK: - Setup Mode

    private func performSetup() -> Int32 {
        Logger.shared.info("Running in setup mode")

        guard let config = configuration else {
            Logger.shared.error("Configuration not loaded")
            return 1
        }

        let launchDaemonManager = LaunchDaemonManager(
            preferenceDomain: preferenceDomain,
            configuration: config
        )

        do {
            try launchDaemonManager.createOrUpdateLaunchDaemon()
            try launchDaemonManager.createOrUpdateWatcherDaemon()
            Logger.shared.info("LaunchDaemons created/updated successfully")
            return 0
        } catch {
            Logger.shared.error("Failed to create LaunchDaemon: \(error.localizedDescription)")
            return 1
        }
    }

    // MARK: - Sync Check Mode

    private func performSyncCheck() -> Int32 {
        Logger.shared.info("Running sync check mode")

        guard let config = configuration else {
            Logger.shared.error("Configuration not loaded")
            return 1
        }

        let launchDaemonManager = LaunchDaemonManager(
            preferenceDomain: preferenceDomain,
            configuration: config
        )

        // Check if schedule needs updating
        if launchDaemonManager.needsScheduleSync() {
            Logger.shared.info("Schedule mismatch detected - updating LaunchDaemon")
            do {
                try launchDaemonManager.createOrUpdateLaunchDaemon()
                Logger.shared.info("LaunchDaemon schedule synced successfully")
            } catch {
                Logger.shared.error("Failed to sync LaunchDaemon: \(error.localizedDescription)")
                return 1
            }
        } else {
            Logger.shared.info("Schedule is current - no update needed")
        }

        return 0
    }

    // MARK: - Reminder Flow

    private func performReminder() -> Int32 {
        Logger.shared.info("Running reminder flow")

        guard let config = configuration else {
            Logger.shared.error("Configuration not loaded")
            return 1
        }

        // Check if test mode is enabled (command-line or config)
        let isTestMode = testMode || config.advancedSettings.testMode

        // Parse DDM enforcement from install.log
        let ddmParser = DDMParser()
        var enforcement = ddmParser.parseEnforcement()

        // In test mode, create fake enforcement if none exists
        if enforcement == nil && isTestMode {
            Logger.shared.info("Test mode: creating fake DDM enforcement")
            let testDays = config.advancedSettings.testDaysRemaining
            let fakeDeadline = Date().addingTimeInterval(TimeInterval(testDays * 86400))
            enforcement = DDMEnforcement(
                targetVersion: "15.2",
                targetBuild: "24C101",
                deadline: fakeDeadline,
                deadlineFormatted: formatTestDeadline(fakeDeadline),
                daysRemaining: testDays,
                hoursRemaining: testDays * 24,
                isUpgrade: false
            )
        }

        guard let enforcement = enforcement else {
            Logger.shared.info("No DDM enforcement found - system may be up to date or not in scope")
            if !debugMode {
                healthReporter?.updateHealthState(status: .success, userAction: "No enforcement")
            }
            return 0
        }

        Logger.shared.ddmParsing("DDM enforcement found: \(enforcement.targetVersion) by \(enforcement.deadline)")

        // Check if update is required
        let installedVersion = getInstalledMacOSVersion()
        guard enforcement.isUpdateRequired(currentVersion: installedVersion) || isTestMode else {
            Logger.shared.info("System is up to date (\(installedVersion) >= \(enforcement.targetVersion))")
            if !debugMode {
                healthReporter?.updateHealthState(status: .success, userAction: "Up to date")
            }
            return 0
        }

        // Use testDaysRemaining if in config test mode, otherwise actual days
        let daysRemaining = config.advancedSettings.testMode
            ? config.advancedSettings.testDaysRemaining
            : enforcement.daysRemaining

        // Check if within reminder window (or test mode)
        if !isTestMode && daysRemaining > config.behaviorSettings.daysBeforeDeadlineDisplayReminder {
            Logger.shared.info("Outside reminder window (\(daysRemaining) days > \(config.behaviorSettings.daysBeforeDeadlineDisplayReminder))")
            healthReporter?.updateHealthState(status: .success, userAction: "Outside window")
            return 0
        }

        if config.advancedSettings.testMode {
            Logger.shared.info("Config test mode enabled - using testDaysRemaining: \(daysRemaining)")
        }

        // Check deferral state
        let deferralManager = DeferralManager(
            preferenceDomain: preferenceDomain,
            configuration: config
        )

        // Check if deadline changed and reset deferrals if configured
        deferralManager.checkDeadlineChanged(currentDeadline: enforcement.deadline)

        // Check for active snooze
        if deferralManager.isSnoozeActive() {
            Logger.shared.info("Snooze is active - skipping reminder")
            healthReporter?.updateHealthState(status: .success, userAction: "Snoozed")
            return 0
        }

        // Check display assertions (meetings/presentations) - skip in debug/test mode
        if debugMode || testMode {
            if debugMode {
                Logger.shared.info("Debug mode: skipping meeting/assertion checks")
            } else {
                Logger.shared.info("Test mode: skipping meeting/assertion checks")
            }
        } else {
            let hoursUntilDeadline = enforcement.hoursRemaining
            if hoursUntilDeadline > config.behaviorSettings.ignoreAssertionsWithinHours {
                let meetingWaitResult = waitForMeetingToEnd(config: config)
                if !meetingWaitResult {
                    // Meeting still active after max wait time
                    Logger.shared.info("Meeting still active after maximum wait - exiting")
                    healthReporter?.updateHealthState(status: .success, userAction: "Meeting timeout - will retry later")
                    return 0
                }
            } else {
                Logger.shared.info("Within \(config.behaviorSettings.ignoreAssertionsWithinHours) hours of deadline - ignoring display assertions")
            }

            // Apply random delay (if at scheduled time)
            applyRandomDelay(config: config)
        }

        // Show dialog
        let dialogController = DialogController(
            configuration: config,
            enforcement: enforcement,
            deferralManager: deferralManager
        )

        let result = dialogController.showReminder()

        // Handle result
        switch result {
        case .openSoftwareUpdate:
            Logger.shared.userAction("User clicked: Open Software Update")
            openSoftwareUpdate()
            healthReporter?.updateHealthState(
                status: .success,
                enforcement: enforcement,
                deferralManager: deferralManager,
                userAction: "Opened Software Update"
            )

        case .deferred:
            Logger.shared.userAction("User clicked: Remind Me Later")
            deferralManager.recordDeferral()
            healthReporter?.updateHealthState(
                status: .success,
                enforcement: enforcement,
                deferralManager: deferralManager,
                userAction: "Deferred"
            )

        case .snoozed:
            Logger.shared.userAction("User selected: Snooze")
            deferralManager.recordSnooze()
            healthReporter?.updateHealthState(
                status: .success,
                enforcement: enforcement,
                deferralManager: deferralManager,
                userAction: "Snoozed"
            )

        case .info:
            Logger.shared.userAction("User clicked: Info/Help")
            healthReporter?.updateHealthState(
                status: .success,
                enforcement: enforcement,
                deferralManager: deferralManager,
                userAction: "Viewed help"
            )

        case .timeout:
            // Timeout acts as snooze when snooze is enabled
            if config.deferralSettings.snoozeEnabled {
                Logger.shared.userAction("Dialog timed out - treating as snooze")
                deferralManager.recordSnooze()
                healthReporter?.updateHealthState(
                    status: .success,
                    enforcement: enforcement,
                    deferralManager: deferralManager,
                    userAction: "Snoozed (timeout)"
                )
            } else {
                Logger.shared.userAction("Dialog timed out")
                healthReporter?.updateHealthState(
                    status: .success,
                    enforcement: enforcement,
                    deferralManager: deferralManager,
                    userAction: "Timeout"
                )
            }

        case .error(let message):
            Logger.shared.error("Dialog error: \(message)")
            healthReporter?.updateHealthState(
                status: .dialogError,
                enforcement: enforcement,
                deferralManager: deferralManager,
                error: message
            )
            return 1
        }

        return 0
    }

    // MARK: - Helper Functions

    private func formatTestDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd-MMM-yyyy, h:mm a"
        var formatted = formatter.string(from: date)
        formatted = formatted.replacingOccurrences(of: " AM", with: " a.m.")
        formatted = formatted.replacingOccurrences(of: " PM", with: " p.m.")
        return formatted
    }

    private func getLoggedInUser() -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/stat")
        process.arguments = ["-f%Su", "/dev/console"]
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

    private func hasActiveDisplayAssertions() -> Bool {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // Check for display assertions (excluding coreaudiod)
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if (line.contains("NoDisplaySleepAssertion") || line.contains("PreventUserIdleDisplaySleep"))
                    && !line.contains("coreaudiod") {
                    return true
                }
            }
            return false
        } catch {
            return false
        }
    }

    private func waitForMeetingToEnd(config: Configuration) -> Bool {
        // Check if there's an active display assertion
        if !hasActiveDisplayAssertions() {
            return true  // No meeting, proceed
        }

        Logger.shared.info("Display assertion detected - user may be in meeting/presentation")

        let maxWaitMinutes = config.behaviorSettings.meetingDelayMinutes
        let checkIntervalSeconds = config.behaviorSettings.meetingCheckIntervalSeconds
        let maxWaitSeconds = maxWaitMinutes * 60
        var totalWaitedSeconds = 0

        Logger.shared.info("Waiting up to \(maxWaitMinutes) minutes for meeting to end (checking every \(checkIntervalSeconds) seconds)")

        while totalWaitedSeconds < maxWaitSeconds {
            // Wait for the check interval
            Thread.sleep(forTimeInterval: Double(checkIntervalSeconds))
            totalWaitedSeconds += checkIntervalSeconds

            // Check again
            if !hasActiveDisplayAssertions() {
                Logger.shared.info("Display assertion cleared after \(totalWaitedSeconds / 60) minutes - proceeding")
                return true  // Meeting ended, proceed
            }

            let remainingMinutes = (maxWaitSeconds - totalWaitedSeconds) / 60
            Logger.shared.info("Display assertion still active - \(remainingMinutes) minutes remaining before timeout")
        }

        // Max wait time exceeded
        Logger.shared.info("Maximum wait time (\(maxWaitMinutes) minutes) exceeded - meeting still active")
        return false  // Meeting still active after max wait
    }

    private func applyRandomDelay(config: Configuration) {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute

        // Check if we're within 5 minutes of a scheduled time
        for time in config.scheduleSettings.launchDaemonTimes {
            let scheduledMinutes = time.hour * 60 + time.minute
            if abs(currentMinutes - scheduledMinutes) <= 5 {
                let maxDelay = config.behaviorSettings.randomDelayMaxSeconds
                let delay = Int.random(in: 0...maxDelay)
                Logger.shared.info("Applying random delay: \(delay) seconds (near scheduled time \(time.hour):\(String(format: "%02d", time.minute)))")
                sleep(UInt32(delay))
                return
            }
        }

        // Login delay (when not at a scheduled time)
        let loginDelay = config.scheduleSettings.loginDelaySeconds
        if loginDelay > 0 {
            Logger.shared.info("Applying login delay: \(loginDelay) seconds")
            sleep(UInt32(loginDelay))
        }
    }

    private func openSoftwareUpdate() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["x-apple.systempreferences:com.apple.preferences.softwareupdate"]

        do {
            try process.run()
        } catch {
            Logger.shared.error("Failed to open Software Update: \(error.localizedDescription)")
        }
    }
}

// Run main
main()
