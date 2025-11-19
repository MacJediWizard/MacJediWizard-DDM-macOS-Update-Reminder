//
//  LaunchDaemonManager.swift
//  DDMmacOSUpdateReminder
//
//  Self-manages the LaunchDaemon for scheduled execution
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - LaunchDaemon Manager

class LaunchDaemonManager {
    private let preferenceDomain: String
    private let configuration: Configuration

    private var daemonPath: String {
        return "/Library/LaunchDaemons/\(preferenceDomain).plist"
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
            // May fail if not loaded, that's OK
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
}
