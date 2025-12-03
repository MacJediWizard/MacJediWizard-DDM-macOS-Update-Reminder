//
//  DialogController.swift
//  DDMmacOSUpdateReminder
//
//  Controls swiftDialog interaction
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - Dialog Result

enum DialogResult {
    case openSoftwareUpdate
    case deferred
    case snoozed
    case info
    case timeout
    case error(String)
}

// MARK: - Dialog Controller

class DialogController {
    private let configuration: Configuration
    private let enforcement: DDMEnforcement
    private let deferralManager: DeferralManager

    private let dialogBinary = "/usr/local/bin/dialog"

    init(configuration: Configuration, enforcement: DDMEnforcement, deferralManager: DeferralManager) {
        self.configuration = configuration
        self.enforcement = enforcement
        self.deferralManager = deferralManager
    }

    // MARK: - Show Reminder

    func showReminder() -> DialogResult {
        Logger.shared.dialog("Preparing to show reminder dialog")

        // Check swiftDialog exists
        if !FileManager.default.fileExists(atPath: dialogBinary) {
            if configuration.advancedSettings.swiftDialogAutoInstall {
                if !installSwiftDialog() {
                    return .error("swiftDialog not installed and auto-install failed")
                }
                // Verify installation succeeded
                guard FileManager.default.fileExists(atPath: dialogBinary) else {
                    return .error("swiftDialog installation completed but binary not found")
                }
            } else {
                return .error("swiftDialog not found at \(dialogBinary)")
            }
        }

        // Check swiftDialog version
        let installedVersion = getSwiftDialogVersion()
        let minVersion = configuration.advancedSettings.swiftDialogMinVersion

        if !installedVersion.isEmpty && !isVersionSufficient(installed: installedVersion, minimum: minVersion) {
            Logger.shared.dialog("swiftDialog version \(installedVersion) is below minimum \(minVersion)")

            if configuration.advancedSettings.swiftDialogAutoInstall {
                Logger.shared.dialog("Attempting to update swiftDialog...")
                if !installSwiftDialog() {
                    return .error("swiftDialog update failed - version \(installedVersion) below minimum \(minVersion)")
                }
                // Verify update succeeded
                let newVersion = getSwiftDialogVersion()
                if !isVersionSufficient(installed: newVersion, minimum: minVersion) {
                    return .error("swiftDialog still below minimum version after update: \(newVersion)")
                }
                Logger.shared.dialog("swiftDialog updated to version \(newVersion)")
            } else {
                return .error("swiftDialog version \(installedVersion) below minimum \(minVersion)")
            }
        } else if !installedVersion.isEmpty {
            Logger.shared.dialog("swiftDialog version \(installedVersion) meets minimum \(minVersion)")
        }

        // Build dialog arguments
        let arguments = buildDialogArguments()

        // Cleanup temp files after dialog exits
        defer {
            let tempFiles = [
                "/var/tmp/ddm-icon.png",
                "/var/tmp/ddm-overlay.png",
                "/var/tmp/ddm-banner.png"
            ]
            for file in tempFiles {
                try? FileManager.default.removeItem(atPath: file)
            }
        }

        // Run dialog
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dialogBinary)
        process.arguments = arguments

        // Capture stdout for JSON output
        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            Logger.shared.dialog("Dialog exit code: \(exitCode)")

            // Read output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            return interpretResult(exitCode: Int(exitCode), output: output)
        } catch {
            Logger.shared.error("Failed to run dialog: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Build Arguments

    private func buildDialogArguments() -> [String] {
        var args: [String] = []

        // Use testDaysRemaining if config test mode is enabled
        let daysRemaining = configuration.advancedSettings.testMode
            ? configuration.advancedSettings.testDaysRemaining
            : enforcement.daysRemaining
        let deferralsRemaining = deferralManager.deferralsRemaining(forDaysRemaining: daysRemaining)
        let isExhausted = deferralsRemaining <= 0

        // Title
        let title = enforcement.isUpgrade
            ? configuration.dialogContent.titleUpgrade
            : configuration.dialogContent.titleUpdate
        args += ["--title", title]

        // Message - check for version-specific message first
        var messageTemplate: String
        if isExhausted {
            messageTemplate = configuration.dialogContent.messageTemplateExhausted
        } else if let versionMessages = configuration.dialogContent.perVersionMessages[enforcement.targetVersion],
                  let customMessage = versionMessages["message"] {
            // Use version-specific message
            messageTemplate = customMessage
            Logger.shared.dialog("Using version-specific message for \(enforcement.targetVersion)")
        } else {
            messageTemplate = configuration.dialogContent.messageTemplate
        }
        let message = substituteVariables(in: messageTemplate)
        args += ["--message", message]

        let branding = configuration.brandingSettings

        // Icon
        if let iconPath = downloadIcon() {
            args += ["--icon", iconPath]
            args += ["--iconsize", String(branding.iconSize)]
        }

        // Overlay icon
        if let overlayPath = getOverlayIcon() {
            args += ["--overlayicon", overlayPath]
        }

        // Banner image
        if let bannerPath = getBannerImage() {
            args += ["--bannerimage", bannerPath]
            if !branding.bannerTitle.isEmpty {
                args += ["--bannertitle", branding.bannerTitle]
            }
        }

        // Infobox
        let infobox = substituteVariables(in: configuration.dialogContent.infoboxTemplate)
        args += ["--infobox", infobox]

        // Button 1 (primary action)
        args += ["--button1text", configuration.dialogContent.button1Text]
        if !branding.button1Color.isEmpty {
            args += ["--button1actioncolor", branding.button1Color]
        }

        // Button 2 (defer/remind later/snooze)
        if !isExhausted {
            // Add dropdown for snooze vs defer when snooze is enabled
            if configuration.deferralSettings.snoozeEnabled {
                let snoozeMinutes = configuration.deferralSettings.snoozeMinutes
                let snoozeOption = "Snooze (\(snoozeMinutes) min) - doesn't use a deferral"
                let deferOption = "Remind Me Later - uses 1 of \(deferralsRemaining) deferrals"

                args += ["--selecttitle", "Choose Action:"]
                args += ["--selectvalues", "\(snoozeOption),\(deferOption)"]
                args += ["--selectdefault", deferOption]

                // Button 2 confirms the selection
                args += ["--button2text", "Confirm"]
            } else {
                args += ["--button2text", configuration.dialogContent.button2Text]
            }

            if !branding.button2Color.isEmpty {
                args += ["--button2actioncolor", branding.button2Color]
            }
        } else {
            // Deferrals exhausted
            if configuration.deferralSettings.exhaustedBehavior == "AutoOpenUpdate" {
                // AutoOpenUpdate: Show countdown timer, then auto-click button1
                let delaySeconds = configuration.deferralSettings.autoOpenDelaySeconds
                Logger.shared.dialog("AutoOpenUpdate: Dialog will auto-proceed in \(delaySeconds) seconds")
                args += ["--timer", String(delaySeconds)]
                args += ["--button1text", "\(configuration.dialogContent.button1Text) (auto in {timer}s)"]
                // No button2 at all in AutoOpenUpdate mode
            } else {
                // NoRemindButton: Show disabled button with exhausted text
                args += ["--button2text", configuration.dialogContent.button2TextExhausted]
                args += ["--button2disabled"]
            }
        }

        // Enable JSON output to capture dropdown selection
        args += ["--jsonoutput"]

        // Info button (for help) - only set text if not empty, otherwise swiftDialog shows "?" icon
        if !configuration.dialogContent.infoButtonText.isEmpty {
            args += ["--infobuttontext", configuration.dialogContent.infoButtonText]
        }

        // Help message
        let helpMessage = substituteVariables(in: configuration.dialogContent.helpMessageTemplate)
        args += ["--helpmessage", helpMessage]

        // Timer for auto-dismiss (acts as implicit snooze when snooze is enabled)
        if configuration.deferralSettings.snoozeEnabled && !isExhausted {
            // Dialog timeout acts as snooze - user gets reminded again after snooze period
            args += ["--timer", "300"]  // 5 minute display timeout
            args += ["--hidetimerbar"]
        }

        // Window size
        args += ["--width", String(branding.windowWidth)]
        args += ["--height", String(branding.windowHeight)]

        // Window position
        if !branding.windowPosition.isEmpty && branding.windowPosition != "center" {
            args += ["--position", branding.windowPosition]
        }

        // Title font
        var titleFontArg = ""
        if !branding.titleFontName.isEmpty {
            titleFontArg += "name=\(branding.titleFontName)"
        }
        if branding.titleFontSize > 0 {
            if !titleFontArg.isEmpty { titleFontArg += "," }
            titleFontArg += "size=\(branding.titleFontSize)"
        }
        if !branding.titleFontColor.isEmpty {
            if !titleFontArg.isEmpty { titleFontArg += "," }
            titleFontArg += "color=\(branding.titleFontColor)"
        }
        if !titleFontArg.isEmpty {
            args += ["--titlefont", titleFontArg]
        }

        // Message font
        var messageFontArg = ""
        if !branding.messageFontName.isEmpty {
            messageFontArg += "name=\(branding.messageFontName)"
        }
        if branding.messageFontSize > 0 {
            if !messageFontArg.isEmpty { messageFontArg += "," }
            messageFontArg += "size=\(branding.messageFontSize)"
        }
        if !branding.messageFontColor.isEmpty {
            if !messageFontArg.isEmpty { messageFontArg += "," }
            messageFontArg += "color=\(branding.messageFontColor)"
        }
        if !messageFontArg.isEmpty {
            args += ["--messagefont", messageFontArg]
        } else {
            args += ["--messagefont", "size=14"]
        }

        // Infobox font
        if branding.infoboxFontSize > 0 {
            args += ["--infoboxfont", "size=\(branding.infoboxFontSize)"]
        }

        // Blurscreen if within threshold
        if daysRemaining <= configuration.behaviorSettings.daysBeforeDeadlineBlurscreen {
            args += ["--blurscreen"]
        }

        args += ["--ontop"]

        return args
    }

    // MARK: - Variable Substitution

    private func substituteVariables(in template: String) -> String {
        var result = template

        // Use testDaysRemaining if config test mode is enabled
        let daysRemaining = configuration.advancedSettings.testMode
            ? configuration.advancedSettings.testDaysRemaining
            : enforcement.daysRemaining
        let deferralsRemaining = deferralManager.deferralsRemaining(forDaysRemaining: daysRemaining)
        let maxDeferrals = deferralManager.maxDeferralsAtThreshold(forDaysRemaining: daysRemaining)

        // User info
        let (firstName, fullName, userName) = getUserInfo()
        result = result.replacingOccurrences(of: "{userFirstName}", with: firstName)
        result = result.replacingOccurrences(of: "{userFullName}", with: fullName)
        result = result.replacingOccurrences(of: "{userName}", with: userName)

        // Computer info
        result = result.replacingOccurrences(of: "{computerName}", with: getComputerName())
        result = result.replacingOccurrences(of: "{serialNumber}", with: getSerialNumber())

        // Version info
        result = result.replacingOccurrences(of: "{installedVersion}", with: getInstalledVersion())
        result = result.replacingOccurrences(of: "{installedBuild}", with: getInstalledBuild())
        result = result.replacingOccurrences(of: "{targetVersion}", with: enforcement.targetVersion)
        result = result.replacingOccurrences(of: "{targetBuild}", with: enforcement.targetBuild)

        // Action
        let action = enforcement.isUpgrade ? "Upgrade" : "Update"
        result = result.replacingOccurrences(of: "{action}", with: action)
        result = result.replacingOccurrences(of: "{actionLower}", with: action.lowercased())

        // Software Update button
        let suButton = enforcement.isUpgrade ? "Upgrade Now" : "Restart Now"
        result = result.replacingOccurrences(of: "{softwareUpdateButtonText}", with: suButton)

        // Deadline
        result = result.replacingOccurrences(of: "{deadlineFormatted}", with: enforcement.deadlineFormatted)
        result = result.replacingOccurrences(of: "{daysRemaining}", with: String(daysRemaining))
        result = result.replacingOccurrences(of: "{hoursRemaining}", with: String(enforcement.hoursRemaining))

        // Separate deadline date and time
        let deadlineDateFormatter = DateFormatter()
        deadlineDateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{deadlineDate}", with: deadlineDateFormatter.string(from: enforcement.deadline))
        deadlineDateFormatter.dateFormat = "HH:mm"
        result = result.replacingOccurrences(of: "{deadlineTime}", with: deadlineDateFormatter.string(from: enforcement.deadline))

        // Deferrals
        result = result.replacingOccurrences(of: "{deferralsRemaining}", with: String(deferralsRemaining))
        result = result.replacingOccurrences(of: "{deferralsUsed}", with: String(deferralManager.deferralsUsed))
        result = result.replacingOccurrences(of: "{maxDeferrals}", with: String(maxDeferrals))

        // Date/time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        result = result.replacingOccurrences(of: "{dayOfWeek}", with: dateFormatter.string(from: Date()))

        dateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{currentDate}", with: dateFormatter.string(from: Date()))

        dateFormatter.dateFormat = "HH:mm"
        result = result.replacingOccurrences(of: "{currentTime}", with: dateFormatter.string(from: Date()))

        // Button text
        result = result.replacingOccurrences(of: "{button1Text}", with: configuration.dialogContent.button1Text)
        result = result.replacingOccurrences(of: "{button2Text}", with: configuration.dialogContent.button2Text)

        // Support info
        result = result.replacingOccurrences(of: "{supportTeamName}", with: configuration.supportSettings.teamName)
        result = result.replacingOccurrences(of: "{supportPhone}", with: configuration.supportSettings.phone)
        result = result.replacingOccurrences(of: "{supportEmail}", with: configuration.supportSettings.email)
        result = result.replacingOccurrences(of: "{supportWebsite}", with: configuration.supportSettings.website)
        result = result.replacingOccurrences(of: "{supportKBArticleID}", with: configuration.supportSettings.kbArticleID)
        result = result.replacingOccurrences(of: "{supportKBArticleURL}", with: configuration.supportSettings.kbArticleURL)

        // Snooze
        result = result.replacingOccurrences(of: "{snoozeMinutes}", with: String(configuration.deferralSettings.snoozeMinutes))

        // Convert literal \n to actual newlines (Jamf Pro strips newlines from text fields)
        result = result.replacingOccurrences(of: "\\n", with: "\n")

        return result
    }

    // MARK: - Result Interpretation

    private func interpretResult(exitCode: Int, output: String) -> DialogResult {
        // Check if deferrals are exhausted for AutoOpenUpdate behavior
        let daysRemaining = configuration.advancedSettings.testMode
            ? configuration.advancedSettings.testDaysRemaining
            : enforcement.daysRemaining
        let deferralsRemaining = deferralManager.deferralsRemaining(forDaysRemaining: daysRemaining)
        let isExhausted = deferralsRemaining <= 0
        let isAutoOpen = isExhausted && configuration.deferralSettings.exhaustedBehavior == "AutoOpenUpdate"

        switch exitCode {
        case 0:
            return .openSoftwareUpdate
        case 2:
            // Button 2 clicked - check if snooze or defer was selected
            if configuration.deferralSettings.snoozeEnabled {
                // Parse JSON output to find selected option
                if let data = output.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let selectedOption = json["SelectedOption"] as? String {
                    Logger.shared.dialog("Selected option: \(selectedOption)")

                    // Check if snooze was selected (contains "Snooze")
                    if selectedOption.lowercased().contains("snooze") {
                        return .snoozed
                    }
                }
            }
            return .deferred
        case 3:
            return .info
        case 4:
            // Timer expired
            if isAutoOpen {
                // AutoOpenUpdate: timer expiry means auto-open Software Update
                Logger.shared.dialog("AutoOpenUpdate: Timer expired, opening Software Update")
                return .openSoftwareUpdate
            }
            return .timeout
        case 20:
            Logger.shared.dialog("User has Do Not Disturb enabled")
            return .timeout
        default:
            return .error("Unknown exit code: \(exitCode)")
        }
    }

    // MARK: - Icon Management

    /// Downloads a file with retry logic and exponential backoff
    private func downloadWithRetry(url: String, destination: String, maxAttempts: Int = 3) -> Bool {
        for attempt in 1...maxAttempts {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = [
                "-L", "-s",
                "-o", destination,
                "--connect-timeout", "10",
                "--max-time", "30",
                url
            ]

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    Logger.shared.verbose("Download succeeded on attempt \(attempt): \(url)", category: .dialog)
                    return true
                }

                Logger.shared.verbose("Download attempt \(attempt)/\(maxAttempts) failed for: \(url)", category: .dialog)
            } catch {
                Logger.shared.verbose("Download attempt \(attempt)/\(maxAttempts) error: \(error.localizedDescription)", category: .dialog)
            }

            // Exponential backoff: 1s, 2s, 4s
            if attempt < maxAttempts {
                let delay = pow(2.0, Double(attempt - 1))
                Thread.sleep(forTimeInterval: delay)
            }
        }

        Logger.shared.warning("Download failed after \(maxAttempts) attempts: \(url)")
        return false
    }

    private func downloadIcon() -> String? {
        let majorVersion = String(enforcement.targetVersion.split(separator: ".").first ?? "")
        let iconURL = configuration.brandingSettings.iconURL(forMajorVersion: majorVersion)

        guard !iconURL.isEmpty else { return nil }

        // Security: Validate URL
        guard isValidURL(iconURL) else {
            Logger.shared.error("Invalid icon URL: \(iconURL)")
            return nil
        }

        let tempPath = "/var/tmp/ddm-icon.png"
        return downloadWithRetry(url: iconURL, destination: tempPath) ? tempPath : nil
    }

    private func getOverlayIcon() -> String? {
        // Check local path first
        if !configuration.brandingSettings.overlayIconPath.isEmpty {
            if FileManager.default.fileExists(atPath: configuration.brandingSettings.overlayIconPath) {
                return configuration.brandingSettings.overlayIconPath
            }
        }

        // Try URL
        let overlayURL = configuration.brandingSettings.overlayIconURL
        guard !overlayURL.isEmpty else {
            return "/System/Library/CoreServices/Finder.app"
        }

        // Security: Validate URL
        guard isValidURL(overlayURL) else {
            Logger.shared.error("Invalid overlay icon URL: \(overlayURL)")
            return "/System/Library/CoreServices/Finder.app"
        }

        let tempPath = "/var/tmp/ddm-overlay.png"
        return downloadWithRetry(url: overlayURL, destination: tempPath) ? tempPath : "/System/Library/CoreServices/Finder.app"
    }

    private func getBannerImage() -> String? {
        // Check local path first
        if !configuration.brandingSettings.bannerImagePath.isEmpty {
            if FileManager.default.fileExists(atPath: configuration.brandingSettings.bannerImagePath) {
                return configuration.brandingSettings.bannerImagePath
            }
        }

        // Try URL
        let bannerURL = configuration.brandingSettings.bannerImageURL
        guard !bannerURL.isEmpty else {
            return nil
        }

        // Security: Validate URL
        guard isValidURL(bannerURL) else {
            Logger.shared.error("Invalid banner image URL: \(bannerURL)")
            return nil
        }

        let tempPath = "/var/tmp/ddm-banner.png"
        return downloadWithRetry(url: bannerURL, destination: tempPath) ? tempPath : nil
    }

    // MARK: - System Info Helpers

    private func getUserInfo() -> (firstName: String, fullName: String, userName: String) {
        // Get current user
        let userName = runCommand("/usr/bin/stat", arguments: ["-f%Su", "/dev/console"])

        // Get full name
        let fullName = runCommand("/usr/bin/id", arguments: ["-F", userName])

        // Extract first name
        var firstName = fullName
        if fullName.contains(",") {
            firstName = String(fullName.split(separator: ",").last ?? "").trimmingCharacters(in: .whitespaces)
        } else if fullName.contains(" ") {
            firstName = String(fullName.split(separator: " ").first ?? "")
        }

        // Capitalize first letter
        firstName = firstName.prefix(1).uppercased() + firstName.dropFirst().lowercased()

        return (firstName, fullName, userName)
    }

    private func getComputerName() -> String {
        return runCommand("/usr/sbin/scutil", arguments: ["--get", "ComputerName"])
    }

    private func getSerialNumber() -> String {
        return runCommand("/usr/sbin/ioreg", arguments: ["-c", "IOPlatformExpertDevice", "-d", "2"])
            .components(separatedBy: "\"IOPlatformSerialNumber\" = \"")
            .last?
            .components(separatedBy: "\"")
            .first ?? ""
    }

    private func getInstalledVersion() -> String {
        return runCommand("/usr/bin/sw_vers", arguments: ["-productVersion"])
    }

    private func getInstalledBuild() -> String {
        return runCommand("/usr/bin/sw_vers", arguments: ["-buildVersion"])
    }

    private func getSwiftDialogVersion() -> String {
        let output = runCommand(dialogBinary, arguments: ["--version"])
        // swiftDialog returns version like "2.4.0"
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isVersionSufficient(installed: String, minimum: String) -> Bool {
        let installedParts = installed.split(separator: ".").compactMap { Int($0) }
        let minimumParts = minimum.split(separator: ".").compactMap { Int($0) }

        // Pad arrays to same length
        let maxLength = max(installedParts.count, minimumParts.count)
        var installed = installedParts
        var minimum = minimumParts

        while installed.count < maxLength { installed.append(0) }
        while minimum.count < maxLength { minimum.append(0) }

        // Compare each component
        for i in 0..<maxLength {
            if installed[i] > minimum[i] {
                return true
            } else if installed[i] < minimum[i] {
                return false
            }
        }

        return true  // Versions are equal
    }

    private func runCommand(_ path: String, arguments: [String]) -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
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

    // MARK: - Security Helpers

    private func isValidURL(_ urlString: String) -> Bool {
        // Validate URL format and ensure it uses http/https
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            return false
        }
        // Check for shell metacharacters that could be dangerous
        let dangerousChars = CharacterSet(charactersIn: ";|&`$(){}[]<>\\'\"\n\r")
        return urlString.rangeOfCharacter(from: dangerousChars) == nil
    }

    // MARK: - swiftDialog Installation

    /// State file for rate-limiting installation attempts
    private var installStateFile: String {
        let baseDir = "\(configuration.organizationSettings.managementDirectory)/\(configuration.organizationSettings.reverseDomainName)"
        return "\(baseDir)/dialog-install-state.plist"
    }

    /// Check if we should attempt installation (rate limiting)
    private func shouldAttemptInstall() -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: installStateFile) else {
            return true  // No state file, allow attempt
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: installStateFile))
            if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let lastAttempt = plist["lastAttemptDate"] as? Date,
               let failures = plist["consecutiveFailures"] as? Int {
                // Exponential backoff: 15min, 1hr, 4hr, 24hr
                let backoffMinutes: [Int] = [15, 60, 240, 1440]
                let backoffIndex = min(failures, backoffMinutes.count - 1)
                let waitMinutes = backoffMinutes[max(0, backoffIndex)]
                let nextAllowed = lastAttempt.addingTimeInterval(Double(waitMinutes * 60))

                if Date() < nextAllowed {
                    Logger.shared.dialog("Installation rate-limited: \(failures) failures, retry after \(nextAllowed)")
                    return false
                }
            }
        } catch {
            Logger.shared.verbose("Could not read install state: \(error.localizedDescription)", category: .dialog)
        }
        return true
    }

    /// Record installation attempt result
    private func recordInstallAttempt(success: Bool) {
        let fileManager = FileManager.default
        let directory = (installStateFile as NSString).deletingLastPathComponent

        // Read existing state
        var failures = 0
        if fileManager.fileExists(atPath: installStateFile),
           let data = try? Data(contentsOf: URL(fileURLWithPath: installStateFile)),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            failures = plist["consecutiveFailures"] as? Int ?? 0
        }

        // Update state
        let state: [String: Any] = [
            "lastAttemptDate": Date(),
            "consecutiveFailures": success ? 0 : failures + 1,
            "lastResult": success ? "success" : "failure"
        ]

        // Create directory if needed
        if !fileManager.fileExists(atPath: directory) {
            try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }

        // Write state
        if let data = try? PropertyListSerialization.data(fromPropertyList: state, format: .xml, options: 0) {
            try? data.write(to: URL(fileURLWithPath: installStateFile))
        }
    }

    private func installSwiftDialog() -> Bool {
        Logger.shared.dialog("Attempting to install swiftDialog")

        // Check rate limiting
        guard shouldAttemptInstall() else {
            Logger.shared.dialog("Skipping installation due to rate limiting")
            return false
        }

        // Get latest release URL
        let apiURL = "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest"
        guard let pkgURL = getSwiftDialogPkgURL(from: apiURL) else {
            Logger.shared.error("Failed to get swiftDialog download URL")
            recordInstallAttempt(success: false)
            return false
        }

        // Validate the download URL
        guard isValidURL(pkgURL) else {
            Logger.shared.error("Invalid swiftDialog download URL: \(pkgURL)")
            recordInstallAttempt(success: false)
            return false
        }

        // Download
        let tempPkg = "/var/tmp/dialog.pkg"
        let downloadProcess = Process()
        downloadProcess.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        downloadProcess.arguments = ["-L", "-s", "-o", tempPkg, "--max-time", "120", pkgURL]

        do {
            try downloadProcess.run()
            downloadProcess.waitUntilExit()

            guard downloadProcess.terminationStatus == 0 else {
                Logger.shared.error("Failed to download swiftDialog")
                recordInstallAttempt(success: false)
                return false
            }

            // Verify Team ID
            let expectedTeamID = "PWA5E9TQ59"
            guard verifyTeamID(tempPkg, expected: expectedTeamID) else {
                Logger.shared.error("swiftDialog Team ID verification failed")
                recordInstallAttempt(success: false)
                return false
            }

            // Install
            let installProcess = Process()
            installProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/installer")
            installProcess.arguments = ["-pkg", tempPkg, "-target", "/"]

            try installProcess.run()
            installProcess.waitUntilExit()

            // Cleanup
            try? FileManager.default.removeItem(atPath: tempPkg)

            let success = installProcess.terminationStatus == 0
            recordInstallAttempt(success: success)
            if success {
                Logger.shared.dialog("swiftDialog installed successfully")
            }
            return success
        } catch {
            Logger.shared.error("Error installing swiftDialog: \(error.localizedDescription)")
            recordInstallAttempt(success: false)
            return false
        }
    }

    private func getSwiftDialogPkgURL(from apiURL: String) -> String? {
        let result = runCommand("/usr/bin/curl", arguments: ["-s", "--max-time", "30", apiURL])

        // Simple parsing for browser_download_url ending in .pkg
        let lines = result.components(separatedBy: "\"browser_download_url\"")
        for line in lines {
            if line.contains(".pkg") {
                if let start = line.range(of: "\"http"),
                   let end = line.range(of: ".pkg\"") {
                    let url = String(line[start.lowerBound..<end.upperBound])
                        .replacingOccurrences(of: "\"", with: "")
                    return url
                }
            }
        }
        return nil
    }

    private func verifyTeamID(_ pkgPath: String, expected: String) -> Bool {
        // Note: spctl outputs to stderr, not stdout
        let pipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        process.arguments = ["-a", "-vv", "-t", "install", pkgPath]
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            // spctl outputs signature info to stderr
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: errorData, encoding: .utf8) ?? ""
            return output.contains(expected)
        } catch {
            Logger.shared.error("Failed to verify Team ID: \(error.localizedDescription)")
            return false
        }
    }

    /// Verifies SHA-256 checksum of a file (defense in depth alongside Team ID verification)
    private func verifyChecksum(_ filePath: String, expected: String) -> Bool {
        guard !expected.isEmpty else {
            Logger.shared.verbose("No checksum provided, skipping verification", category: .dialog)
            return true
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
        process.arguments = ["-a", "256", filePath]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            // shasum output format: "checksum  filename"
            let computed = output.split(separator: " ").first ?? ""

            let matches = computed.lowercased() == expected.lowercased()
            if !matches {
                Logger.shared.error("Checksum mismatch: expected \(expected), got \(computed)")
            } else {
                Logger.shared.verbose("Checksum verified: \(expected)", category: .dialog)
            }
            return matches
        } catch {
            Logger.shared.error("Failed to compute checksum: \(error.localizedDescription)")
            return false
        }
    }
}
