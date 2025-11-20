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

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            Logger.shared.dialog("Dialog exit code: \(exitCode)")

            return interpretExitCode(Int(exitCode))
        } catch {
            Logger.shared.error("Failed to run dialog: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Build Arguments

    private func buildDialogArguments() -> [String] {
        var args: [String] = []

        let daysRemaining = enforcement.daysRemaining
        let deferralsRemaining = deferralManager.deferralsRemaining(forDaysRemaining: daysRemaining)
        let isExhausted = deferralsRemaining <= 0

        // Title
        let title = enforcement.isUpgrade
            ? configuration.dialogContent.titleUpgrade
            : configuration.dialogContent.titleUpdate
        args += ["--title", title]

        // Message
        let messageTemplate = isExhausted
            ? configuration.dialogContent.messageTemplateExhausted
            : configuration.dialogContent.messageTemplate
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

        // Button 2 (defer/remind later) - only if deferrals remaining
        if !isExhausted {
            args += ["--button2text", configuration.dialogContent.button2Text]
            if !branding.button2Color.isEmpty {
                args += ["--button2actioncolor", branding.button2Color]
            }
        }

        // Info button (for help)
        args += ["--infobuttontext", configuration.dialogContent.infoButtonText]

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

        let daysRemaining = enforcement.daysRemaining
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

        return result
    }

    // MARK: - Exit Code Interpretation

    private func interpretExitCode(_ code: Int) -> DialogResult {
        switch code {
        case 0:
            return .openSoftwareUpdate
        case 2:
            return .deferred
        case 3:
            return .info
        case 4:
            return .timeout
        case 20:
            Logger.shared.dialog("User has Do Not Disturb enabled")
            return .timeout
        default:
            return .error("Unknown exit code: \(code)")
        }
    }

    // MARK: - Icon Management

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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-L", "-s", "-o", tempPath, "--max-time", "30", iconURL]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? tempPath : nil
        } catch {
            return nil
        }
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-L", "-s", "-o", tempPath, "--max-time", "30", overlayURL]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? tempPath : "/System/Library/CoreServices/Finder.app"
        } catch {
            return "/System/Library/CoreServices/Finder.app"
        }
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-L", "-s", "-o", tempPath, "--max-time", "30", bannerURL]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? tempPath : nil
        } catch {
            return nil
        }
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

    private func installSwiftDialog() -> Bool {
        Logger.shared.dialog("Attempting to install swiftDialog")

        // Get latest release URL
        let apiURL = "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest"
        guard let pkgURL = getSwiftDialogPkgURL(from: apiURL) else {
            Logger.shared.error("Failed to get swiftDialog download URL")
            return false
        }

        // Validate the download URL
        guard isValidURL(pkgURL) else {
            Logger.shared.error("Invalid swiftDialog download URL: \(pkgURL)")
            return false
        }

        // Download
        let tempPkg = "/var/tmp/dialog.pkg"
        let downloadProcess = Process()
        downloadProcess.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        downloadProcess.arguments = ["-L", "-s", "-o", tempPkg, pkgURL]

        do {
            try downloadProcess.run()
            downloadProcess.waitUntilExit()

            guard downloadProcess.terminationStatus == 0 else {
                Logger.shared.error("Failed to download swiftDialog")
                return false
            }

            // Verify Team ID
            let expectedTeamID = "PWA5E9TQ59"
            guard verifyTeamID(tempPkg, expected: expectedTeamID) else {
                Logger.shared.error("swiftDialog Team ID verification failed")
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
            if success {
                Logger.shared.dialog("swiftDialog installed successfully")
            }
            return success
        } catch {
            Logger.shared.error("Error installing swiftDialog: \(error.localizedDescription)")
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
}
