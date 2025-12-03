//
//  LaunchDaemonManager.swift
//  DDMmacOSUpdateReminder
//
//  Self-manages the LaunchDaemon for scheduled execution
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - LaunchDaemon Errors

enum LaunchDaemonError: Error {
    case binaryNotFound
    case plistWriteFailure
    case loadFailure
}

// MARK: - LaunchDaemon Manager

class LaunchDaemonManager {
    private let preferenceDomain: String
    private let configuration: Configuration

    private var daemonPath: String {
        return "/Library/LaunchDaemons/\(preferenceDomain).plist"
    }

    private var watcherDaemonPath: String {
        return "/Library/LaunchDaemons/\(preferenceDomain).watcher.plist"
    }

    private var binaryPath: String {
        return "/usr/local/bin/DDMmacOSUpdateReminder"
    }

    init(preferenceDomain: String, configuration: Configuration) {
        self.preferenceDomain = preferenceDomain
        self.configuration = configuration
    }

    // MARK: - Create/Update LaunchDaemon

    func createOrUpdateLaunchDaemon() throws {
        Logger.shared.launchDaemon("Creating/updating LaunchDaemon")

        // Verify binary exists
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            Logger.shared.error("Binary not found at \(binaryPath)")
            throw LaunchDaemonError.binaryNotFound
        }

        // Unload existing daemon if present
        if FileManager.default.fileExists(atPath: daemonPath) {
            unloadDaemon()
        }

        // Build plist content
        let plistContent = buildPlistContent()

        // Write plist
        try plistContent.write(toFile: daemonPath, atomically: true, encoding: .utf8)
        Logger.shared.launchDaemon("Wrote LaunchDaemon plist to \(daemonPath)")

        // Set permissions
        let fileManager = FileManager.default
        try fileManager.setAttributes([
            .posixPermissions: 0o644,
            .ownerAccountName: "root",
            .groupOwnerAccountName: "wheel"
        ], ofItemAtPath: daemonPath)

        // Load daemon
        loadDaemon()

        Logger.shared.launchDaemon("LaunchDaemon created and loaded successfully")
    }

    // MARK: - Build Plist

    private func buildPlistContent() -> String {
        var calendarIntervals = ""

        for time in configuration.scheduleSettings.launchDaemonTimes {
            calendarIntervals += """
                    <dict>
                        <key>Hour</key>
                        <integer>\(time.hour)</integer>
                        <key>Minute</key>
                        <integer>\(time.minute)</integer>
                    </dict>

            """
        }

        let runAtLoad = configuration.scheduleSettings.runAtLoad ? "<true/>" : "<false/>"

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(preferenceDomain)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>--domain</string>
                <string>\(preferenceDomain)</string>
            </array>
            <key>RunAtLoad</key>
            \(runAtLoad)
            <key>StartCalendarInterval</key>
            <array>
        \(calendarIntervals)    </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin</string>
            </dict>
            <key>AbandonProcessGroup</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/var/log/DDMmacOSUpdateReminder.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/DDMmacOSUpdateReminder.log</string>
        </dict>
        </plist>
        """
    }

    // MARK: - Load/Unload

    private func loadDaemon() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootstrap", "system", daemonPath]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                Logger.shared.launchDaemon("LaunchDaemon loaded successfully")
            } else {
                Logger.shared.error("Failed to load LaunchDaemon (exit: \(process.terminationStatus))")
            }
        } catch {
            Logger.shared.error("Error loading LaunchDaemon: \(error.localizedDescription)")
        }
    }

    private func unloadDaemon() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "system", daemonPath]

        do {
            try process.run()
            process.waitUntilExit()
            Logger.shared.launchDaemon("Unloaded existing LaunchDaemon")
        } catch {
            Logger.shared.verbose("LaunchDaemon unload failed (may not be loaded): \(error.localizedDescription)")
        }
    }

    // MARK: - Status

    func isDaemonLoaded() -> Bool {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains(preferenceDomain)
        } catch {
            Logger.shared.verbose("Failed to check daemon status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Remove

    func removeDaemon() {
        // Unload
        unloadDaemon()

        // Remove file
        try? FileManager.default.removeItem(atPath: daemonPath)

        Logger.shared.launchDaemon("Removed LaunchDaemon")
    }

    // MARK: - Watcher Daemon

    func createOrUpdateWatcherDaemon() throws {
        Logger.shared.launchDaemon("Creating/updating watcher LaunchDaemon")

        // Verify binary exists
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            Logger.shared.error("Binary not found at \(binaryPath)")
            throw LaunchDaemonError.binaryNotFound
        }

        // Unload existing watcher if present
        if FileManager.default.fileExists(atPath: watcherDaemonPath) {
            unloadWatcherDaemon()
        }

        // Build watcher plist content
        let plistContent = buildWatcherPlistContent()

        // Write plist
        try plistContent.write(toFile: watcherDaemonPath, atomically: true, encoding: .utf8)
        Logger.shared.launchDaemon("Wrote watcher LaunchDaemon plist to \(watcherDaemonPath)")

        // Set permissions
        let fileManager = FileManager.default
        try fileManager.setAttributes([
            .posixPermissions: 0o644,
            .ownerAccountName: "root",
            .groupOwnerAccountName: "wheel"
        ], ofItemAtPath: watcherDaemonPath)

        // Load watcher daemon
        loadWatcherDaemon()

        Logger.shared.launchDaemon("Watcher LaunchDaemon created and loaded successfully")
    }

    private func buildWatcherPlistContent() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(preferenceDomain).watcher</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>--domain</string>
                <string>\(preferenceDomain)</string>
                <string>--sync-check</string>
            </array>
            <key>StartInterval</key>
            <integer>900</integer>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin</string>
            </dict>
            <key>StandardOutPath</key>
            <string>/var/log/DDMmacOSUpdateReminder.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/DDMmacOSUpdateReminder.log</string>
        </dict>
        </plist>
        """
    }

    private func loadWatcherDaemon() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootstrap", "system", watcherDaemonPath]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                Logger.shared.launchDaemon("Watcher LaunchDaemon loaded successfully")
            } else {
                Logger.shared.error("Failed to load watcher LaunchDaemon (exit: \(process.terminationStatus))")
            }
        } catch {
            Logger.shared.error("Error loading watcher LaunchDaemon: \(error.localizedDescription)")
        }
    }

    private func unloadWatcherDaemon() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "system", watcherDaemonPath]

        do {
            try process.run()
            process.waitUntilExit()
            Logger.shared.launchDaemon("Unloaded existing watcher LaunchDaemon")
        } catch {
            Logger.shared.verbose("Watcher LaunchDaemon unload failed (may not be loaded): \(error.localizedDescription)")
        }
    }

    // MARK: - Schedule Sync Check

    func needsScheduleSync() -> Bool {
        // Check if main daemon plist exists
        guard FileManager.default.fileExists(atPath: daemonPath) else {
            Logger.shared.launchDaemon("Main daemon plist not found - sync not needed")
            return false
        }

        // Read current schedule from daemon plist
        guard let currentSchedule = getCurrentScheduleFromDaemon() else {
            Logger.shared.launchDaemon("Could not read current schedule - sync needed")
            return true
        }

        // Get configured schedule
        let configuredSchedule = configuration.scheduleSettings.launchDaemonTimes.map {
            (hour: $0.hour, minute: $0.minute)
        }

        // Compare schedules
        if currentSchedule.count != configuredSchedule.count {
            return true
        }

        for (current, configured) in zip(currentSchedule.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) },
                                          configuredSchedule.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) {
            if current.hour != configured.hour || current.minute != configured.minute {
                return true
            }
        }

        return false
    }

    private func getCurrentScheduleFromDaemon() -> [(hour: Int, minute: Int)]? {
        guard let plistData = FileManager.default.contents(atPath: daemonPath) else {
            return nil
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        guard let calendarIntervals = plist["StartCalendarInterval"] as? [[String: Any]] else {
            return nil
        }

        var schedule: [(hour: Int, minute: Int)] = []
        for interval in calendarIntervals {
            if let hour = interval["Hour"] as? Int, let minute = interval["Minute"] as? Int {
                schedule.append((hour: hour, minute: minute))
            }
        }

        return schedule
    }
}
