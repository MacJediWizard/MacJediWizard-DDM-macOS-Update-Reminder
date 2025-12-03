//
//  Configuration.swift
//  DDMmacOSUpdateReminder
//
//  Configuration management - reads from Jamf managed preferences
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import Foundation

// MARK: - Configuration Errors

enum ConfigurationError: Error {
    case profileNotFound
    case missingRequiredKey(String)
    case invalidValue(key: String, expected: String)
}

// MARK: - Configuration Validation Helpers

/// Clamps an integer value to a specified range, logging if adjustment was needed
private func clampedInt(_ value: Int?, default defaultValue: Int, min: Int, max: Int, key: String) -> Int {
    let val = value ?? defaultValue
    if val < min {
        Logger.shared.warning("Configuration '\(key)' value \(val) below minimum \(min), using \(min)")
        return min
    }
    if val > max {
        Logger.shared.warning("Configuration '\(key)' value \(val) above maximum \(max), using \(max)")
        return max
    }
    return val
}

// MARK: - Main Configuration

struct Configuration {
    let configVersion: String
    let organizationSettings: OrganizationSettings
    let behaviorSettings: BehaviorSettings
    let deferralSettings: DeferralSettings
    let scheduleSettings: ScheduleSettings
    let brandingSettings: BrandingSettings
    let supportSettings: SupportSettings
    let dialogContent: DialogContent
    let healthSettings: HealthSettings
    let advancedSettings: AdvancedSettings

    static func load(from preferenceDomain: String) throws -> Configuration {
        let defaults = UserDefaults(suiteName: preferenceDomain)

        // Check if profile exists
        guard let configVersion = defaults?.string(forKey: "ConfigVersion") else {
            throw ConfigurationError.profileNotFound
        }

        return Configuration(
            configVersion: configVersion,
            organizationSettings: OrganizationSettings.load(from: defaults),
            behaviorSettings: BehaviorSettings.load(from: defaults),
            deferralSettings: DeferralSettings.load(from: defaults),
            scheduleSettings: ScheduleSettings.load(from: defaults),
            brandingSettings: BrandingSettings.load(from: defaults),
            supportSettings: SupportSettings.load(from: defaults),
            dialogContent: DialogContent.load(from: defaults),
            healthSettings: HealthSettings.load(from: defaults),
            advancedSettings: AdvancedSettings.load(from: defaults)
        )
    }
}

// MARK: - Organization Settings

struct OrganizationSettings {
    let reverseDomainName: String
    let organizationName: String
    let managementDirectory: String

    static func load(from defaults: UserDefaults?) -> OrganizationSettings {
        let dict = defaults?.dictionary(forKey: "OrganizationSettings") ?? [:]

        return OrganizationSettings(
            reverseDomainName: dict["ReverseDomainName"] as? String ?? "com.yourorg",
            organizationName: dict["OrganizationName"] as? String ?? "Your Organization",
            managementDirectory: dict["ManagementDirectory"] as? String ?? "/Library/Application Support"
        )
    }
}

// MARK: - Behavior Settings

struct BehaviorSettings {
    let daysBeforeDeadlineDisplayReminder: Int
    let daysBeforeDeadlineBlurscreen: Int
    let meetingDelayMinutes: Int
    let meetingCheckIntervalSeconds: Int
    let ignoreAssertionsWithinHours: Int
    let randomDelayMaxSeconds: Int

    static func load(from defaults: UserDefaults?) -> BehaviorSettings {
        let dict = defaults?.dictionary(forKey: "BehaviorSettings") ?? [:]

        return BehaviorSettings(
            daysBeforeDeadlineDisplayReminder: clampedInt(
                dict["DaysBeforeDeadlineDisplayReminder"] as? Int,
                default: 14, min: 1, max: 30,
                key: "DaysBeforeDeadlineDisplayReminder"
            ),
            daysBeforeDeadlineBlurscreen: clampedInt(
                dict["DaysBeforeDeadlineBlurscreen"] as? Int,
                default: 3, min: 0, max: 14,
                key: "DaysBeforeDeadlineBlurscreen"
            ),
            meetingDelayMinutes: clampedInt(
                dict["MeetingDelayMinutes"] as? Int,
                default: 75, min: 0, max: 240,
                key: "MeetingDelayMinutes"
            ),
            meetingCheckIntervalSeconds: clampedInt(
                dict["MeetingCheckIntervalSeconds"] as? Int,
                default: 300, min: 60, max: 600,
                key: "MeetingCheckIntervalSeconds"
            ),
            ignoreAssertionsWithinHours: clampedInt(
                dict["IgnoreAssertionsWithinHours"] as? Int,
                default: 24, min: 0, max: 72,
                key: "IgnoreAssertionsWithinHours"
            ),
            randomDelayMaxSeconds: clampedInt(
                dict["RandomDelayMaxSeconds"] as? Int,
                default: 1200, min: 0, max: 3600,
                key: "RandomDelayMaxSeconds"
            )
        )
    }
}

// MARK: - Deferral Settings

struct DeferralScheduleEntry {
    let daysRemaining: Int
    let maxDeferrals: Int
}

struct DeferralSettings {
    let maxDeferrals: Int
    let deferralSchedule: [DeferralScheduleEntry]
    let resetOnNewDeadline: Bool
    let snoozeEnabled: Bool
    let snoozeMinutes: Int
    let exhaustedBehavior: String
    let autoOpenDelaySeconds: Int

    static func load(from defaults: UserDefaults?) -> DeferralSettings {
        let dict = defaults?.dictionary(forKey: "DeferralSettings") ?? [:]

        // Parse deferral schedule
        var schedule: [DeferralScheduleEntry] = []
        if let scheduleArray = dict["DeferralSchedule"] as? [[String: Any]] {
            for entry in scheduleArray {
                if let days = entry["DaysRemaining"] as? Int,
                   let max = entry["MaxDeferrals"] as? Int {
                    schedule.append(DeferralScheduleEntry(daysRemaining: days, maxDeferrals: max))
                }
            }
        }

        // Default schedule if none provided
        if schedule.isEmpty {
            schedule = [
                DeferralScheduleEntry(daysRemaining: 14, maxDeferrals: 10),
                DeferralScheduleEntry(daysRemaining: 7, maxDeferrals: 5),
                DeferralScheduleEntry(daysRemaining: 3, maxDeferrals: 2),
                DeferralScheduleEntry(daysRemaining: 1, maxDeferrals: 0)
            ]
        }

        // Validate exhaustedBehavior
        let behavior = dict["ExhaustedBehavior"] as? String ?? "NoRemindButton"
        let validBehaviors = ["NoRemindButton", "AutoOpenUpdate"]
        let validatedBehavior = validBehaviors.contains(behavior) ? behavior : "NoRemindButton"
        if behavior != validatedBehavior {
            Logger.shared.warning("Configuration 'ExhaustedBehavior' invalid value '\(behavior)', using 'NoRemindButton'")
        }

        return DeferralSettings(
            maxDeferrals: clampedInt(
                dict["MaxDeferrals"] as? Int,
                default: 10, min: 0, max: 50,
                key: "MaxDeferrals"
            ),
            deferralSchedule: schedule,
            resetOnNewDeadline: dict["ResetOnNewDeadline"] as? Bool ?? true,
            snoozeEnabled: dict["SnoozeEnabled"] as? Bool ?? true,
            snoozeMinutes: clampedInt(
                dict["SnoozeMinutes"] as? Int,
                default: 120, min: 15, max: 480,
                key: "SnoozeMinutes"
            ),
            exhaustedBehavior: validatedBehavior,
            autoOpenDelaySeconds: clampedInt(
                dict["AutoOpenDelaySeconds"] as? Int,
                default: 60, min: 10, max: 300,
                key: "AutoOpenDelaySeconds"
            )
        )
    }

    func maxDeferralsForDaysRemaining(_ days: Int) -> Int {
        // Sort ascending and find first threshold that covers the remaining days
        // e.g., 5 days remaining should use the 7-day threshold, not the 14-day threshold
        for entry in deferralSchedule.sorted(by: { $0.daysRemaining < $1.daysRemaining }) {
            if entry.daysRemaining >= days {
                return entry.maxDeferrals
            }
        }
        return maxDeferrals
    }
}

// MARK: - Schedule Settings

struct LaunchDaemonTime {
    let hour: Int
    let minute: Int
}

struct ScheduleSettings {
    let launchDaemonTimes: [LaunchDaemonTime]
    let runAtLoad: Bool
    let loginDelaySeconds: Int

    static func load(from defaults: UserDefaults?) -> ScheduleSettings {
        let dict = defaults?.dictionary(forKey: "ScheduleSettings") ?? [:]

        // Parse launch daemon times with validation
        var times: [LaunchDaemonTime] = []
        if let timesArray = dict["LaunchDaemonTimes"] as? [[String: Any]] {
            for entry in timesArray {
                if let hour = entry["Hour"] as? Int,
                   let minute = entry["Minute"] as? Int {
                    // Clamp hours and minutes to valid ranges
                    let validHour = min(max(hour, 0), 23)
                    let validMinute = min(max(minute, 0), 59)
                    if hour != validHour || minute != validMinute {
                        Logger.shared.warning("Configuration 'LaunchDaemonTimes' adjusted invalid time \(hour):\(minute) to \(validHour):\(validMinute)")
                    }
                    times.append(LaunchDaemonTime(hour: validHour, minute: validMinute))
                }
            }
        }

        // Default times if none provided
        if times.isEmpty {
            times = [
                LaunchDaemonTime(hour: 9, minute: 0),
                LaunchDaemonTime(hour: 14, minute: 0)
            ]
        }

        return ScheduleSettings(
            launchDaemonTimes: times,
            runAtLoad: dict["RunAtLoad"] as? Bool ?? true,
            loginDelaySeconds: clampedInt(
                dict["LoginDelaySeconds"] as? Int,
                default: 60, min: 0, max: 300,
                key: "LoginDelaySeconds"
            )
        )
    }
}

// MARK: - Branding Settings

struct BrandingSettings {
    // Icons
    let overlayIconURL: String
    let overlayIconPath: String
    let macOSIcons: [String: String]
    let iconSize: Int

    // Window
    let windowWidth: Int
    let windowHeight: Int
    let windowPosition: String  // center, topleft, topright, bottomleft, bottomright
    let bannerImageURL: String
    let bannerImagePath: String
    let bannerTitle: String

    // Colors
    let titleFontColor: String
    let messageFontColor: String
    let button1Color: String  // Primary button color
    let button2Color: String  // Secondary button color

    // Fonts
    let titleFontName: String
    let titleFontSize: Int
    let messageFontName: String
    let messageFontSize: Int

    // Other
    let progressBarColor: String
    let infoboxFontSize: Int

    static func load(from defaults: UserDefaults?) -> BrandingSettings {
        let dict = defaults?.dictionary(forKey: "BrandingSettings") ?? [:]

        // Default macOS icons
        let defaultIcons: [String: String] = [
            "14": "https://ics.services.jamfcloud.com/icon/hash_eecee9688d1bc0426083d427d80c9ad48fa118b71d8d4962061d4de8d45747e7",
            "15": "https://ics.services.jamfcloud.com/icon/hash_0968afcd54ff99edd98ec6d9a418a5ab0c851576b687756dc3004ec52bac704e",
            "26": "https://ics.services.jamfcloud.com/icon/hash_7320c100c9ca155dc388e143dbc05620907e2d17d6bf74a8fb6d6278ece2c2b4",
            "default": "https://ics.services.jamfcloud.com/icon/hash_4555d9dc8fecb4e2678faffa8bdcf43cba110e81950e07a4ce3695ec2d5579ee"
        ]

        // Validate windowPosition
        let position = dict["WindowPosition"] as? String ?? "center"
        let validPositions = ["center", "topleft", "topright", "bottomleft", "bottomright"]
        let validatedPosition = validPositions.contains(position) ? position : "center"
        if position != validatedPosition {
            Logger.shared.warning("Configuration 'WindowPosition' invalid value '\(position)', using 'center'")
        }

        return BrandingSettings(
            // Icons
            overlayIconURL: dict["OverlayIconURL"] as? String ?? "",
            overlayIconPath: dict["OverlayIconPath"] as? String ?? "",
            macOSIcons: dict["MacOSIcons"] as? [String: String] ?? defaultIcons,
            iconSize: clampedInt(
                dict["IconSize"] as? Int,
                default: 250, min: 64, max: 500,
                key: "IconSize"
            ),

            // Window
            windowWidth: clampedInt(
                dict["WindowWidth"] as? Int,
                default: 800, min: 400, max: 1200,
                key: "WindowWidth"
            ),
            windowHeight: clampedInt(
                dict["WindowHeight"] as? Int,
                default: 600, min: 300, max: 900,
                key: "WindowHeight"
            ),
            windowPosition: validatedPosition,
            bannerImageURL: dict["BannerImageURL"] as? String ?? "",
            bannerImagePath: dict["BannerImagePath"] as? String ?? "",
            bannerTitle: dict["BannerTitle"] as? String ?? "",

            // Colors
            titleFontColor: dict["TitleFontColor"] as? String ?? "",
            messageFontColor: dict["MessageFontColor"] as? String ?? "",
            button1Color: dict["Button1Color"] as? String ?? "",
            button2Color: dict["Button2Color"] as? String ?? "",

            // Fonts
            titleFontName: dict["TitleFontName"] as? String ?? "",
            titleFontSize: clampedInt(
                dict["TitleFontSize"] as? Int,
                default: 0, min: 0, max: 72,
                key: "TitleFontSize"
            ),
            messageFontName: dict["MessageFontName"] as? String ?? "",
            messageFontSize: clampedInt(
                dict["MessageFontSize"] as? Int,
                default: 14, min: 8, max: 36,
                key: "MessageFontSize"
            ),

            // Other
            progressBarColor: dict["ProgressBarColor"] as? String ?? "",
            infoboxFontSize: clampedInt(
                dict["InfoboxFontSize"] as? Int,
                default: 12, min: 8, max: 24,
                key: "InfoboxFontSize"
            )
        )
    }

    func iconURL(forMajorVersion version: String) -> String {
        return macOSIcons[version] ?? macOSIcons["default"] ?? ""
    }
}

// MARK: - Support Settings

struct SupportSettings {
    let teamName: String
    let phone: String
    let email: String
    let website: String
    let kbArticleID: String
    let kbArticleURL: String
    let ticketSystemURL: String

    static func load(from defaults: UserDefaults?) -> SupportSettings {
        let dict = defaults?.dictionary(forKey: "SupportSettings") ?? [:]

        return SupportSettings(
            teamName: dict["TeamName"] as? String ?? "IT Support",
            phone: dict["Phone"] as? String ?? "",
            email: dict["Email"] as? String ?? "",
            website: dict["Website"] as? String ?? "",
            kbArticleID: dict["KBArticleID"] as? String ?? "",
            kbArticleURL: dict["KBArticleURL"] as? String ?? "",
            ticketSystemURL: dict["TicketSystemURL"] as? String ?? ""
        )
    }
}

// MARK: - Dialog Content

struct DialogContent {
    let titleUpdate: String
    let titleUpgrade: String
    let button1Text: String
    let button2Text: String
    let button2TextExhausted: String
    let snoozeButtonText: String  // Reserved for future use - snooze currently via timeout
    let infoButtonText: String
    let messageTemplate: String
    let messageTemplateExhausted: String
    let perVersionMessages: [String: [String: String]]
    let infoboxTemplate: String
    let helpMessageTemplate: String

    static func load(from defaults: UserDefaults?) -> DialogContent {
        let dict = defaults?.dictionary(forKey: "DialogContent") ?? [:]

        let defaultMessage = """
        **A required macOS {actionLower} is now available**
        ---
        Happy {dayOfWeek}, {userFirstName}!

        Please {actionLower} to macOS **{targetVersion}** to ensure your Mac remains secure and compliant with organizational policies.

        To perform the {actionLower} now, click **{button1Text}**, review the on-screen instructions, then click **{softwareUpdateButtonText}**.

        If you are unable to perform this {actionLower} now, click **{button2Text}** to be reminded again later.

        However, your device **will automatically restart and {actionLower}** on **{deadlineFormatted}** if you have not completed the {actionLower} before the deadline.

        **Deferrals Remaining:** {deferralsRemaining} of {maxDeferrals}

        For assistance, please contact **{supportTeamName}**.
        """

        let defaultExhaustedMessage = """
        **Immediate Action Required**
        ---
        {userFirstName}, you have used all available deferrals.

        Your Mac **must** be updated to macOS **{targetVersion}** immediately.

        Click **{button1Text}** to begin the update process now.

        If you do not update, your device will automatically restart and update on **{deadlineFormatted}**.

        For assistance, contact **{supportTeamName}**.
        """

        let defaultInfobox = """
        **Current:** {installedVersion}

        **Required:** {targetVersion}

        **Deadline:** {deadlineFormatted}

        **Days Remaining:** {daysRemaining}
        """

        let defaultHelpMessage = """
        For assistance, please contact: **{supportTeamName}**
        - **Phone:** {supportPhone}
        - **Email:** {supportEmail}
        - **Website:** {supportWebsite}
        - **KB Article:** {supportKBArticleID}

        **User Information:**
        - **Name:** {userFullName}
        - **Username:** {userName}

        **Computer Information:**
        - **Name:** {computerName}
        - **Serial:** {serialNumber}
        - **macOS:** {installedVersion}
        """

        return DialogContent(
            titleUpdate: dict["TitleUpdate"] as? String ?? "macOS Update Required",
            titleUpgrade: dict["TitleUpgrade"] as? String ?? "macOS Upgrade Required",
            button1Text: dict["Button1Text"] as? String ?? "Open Software Update",
            button2Text: dict["Button2Text"] as? String ?? "Remind Me Later",
            button2TextExhausted: dict["Button2TextExhausted"] as? String ?? "No Deferrals Remaining",
            snoozeButtonText: dict["SnoozeButtonText"] as? String ?? "Snooze {snoozeMinutes} Minutes",
            infoButtonText: dict["InfoButtonText"] as? String ?? "Help",
            messageTemplate: dict["MessageTemplate"] as? String ?? defaultMessage,
            messageTemplateExhausted: dict["MessageTemplateExhausted"] as? String ?? defaultExhaustedMessage,
            perVersionMessages: dict["PerVersionMessages"] as? [String: [String: String]] ?? [:],
            infoboxTemplate: dict["InfoboxTemplate"] as? String ?? defaultInfobox,
            helpMessageTemplate: dict["HelpMessageTemplate"] as? String ?? defaultHelpMessage
        )
    }
}

// MARK: - Health Settings

struct HealthSettings {
    let enableHealthReporting: Bool
    let healthStatePath: String
    let maxErrorLogEntries: Int

    static func load(from defaults: UserDefaults?) -> HealthSettings {
        let dict = defaults?.dictionary(forKey: "HealthSettings") ?? [:]

        return HealthSettings(
            enableHealthReporting: dict["EnableHealthReporting"] as? Bool ?? true,
            healthStatePath: dict["HealthStatePath"] as? String ?? "health.plist",
            maxErrorLogEntries: clampedInt(
                dict["MaxErrorLogEntries"] as? Int,
                default: 50, min: 10, max: 200,
                key: "MaxErrorLogEntries"
            )
        )
    }
}

// MARK: - Advanced Settings

struct AdvancedSettings {
    let swiftDialogMinVersion: String
    let swiftDialogAutoInstall: Bool
    let verboseLogging: Bool
    let testMode: Bool
    let testDaysRemaining: Int

    static func load(from defaults: UserDefaults?) -> AdvancedSettings {
        let dict = defaults?.dictionary(forKey: "AdvancedSettings") ?? [:]

        return AdvancedSettings(
            swiftDialogMinVersion: dict["SwiftDialogMinVersion"] as? String ?? "2.4.0",
            swiftDialogAutoInstall: dict["SwiftDialogAutoInstall"] as? Bool ?? true,
            verboseLogging: dict["VerboseLogging"] as? Bool ?? false,
            testMode: dict["TestMode"] as? Bool ?? false,
            testDaysRemaining: clampedInt(
                dict["TestDaysRemaining"] as? Int,
                default: 5, min: 0, max: 30,
                key: "TestDaysRemaining"
            )
        )
    }
}
