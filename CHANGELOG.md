# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Additional customization options
- Extended localization support

## [1.0.5] - 2025-11-20

### Added
- **Snooze/Defer dropdown**: Users can now explicitly choose between Snooze (no deferral used) and Remind Me Later (uses a deferral)
- Dropdown shows snooze duration and remaining deferrals for clarity

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.0.4] - 2025-11-20

### Fixed
- **ManagementDirectory**: Now properly uses the configured ManagementDirectory for health.plist and deferral.plist file paths

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.0.3] - 2025-11-20

### Fixed
- **EA-Health-Status.sh**: Fixed ERROR_COUNT calculation that caused blank results in Jamf Pro inventory

### Removed
- **EA-User-Actions.sh**: Removed redundant Extension Attribute - user action is already shown in EA-Last-Run-Status.sh

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.0.2] - 2025-11-20

### Fixed
- **Template formatting**: Added automatic conversion of `\n` to actual newlines in message templates (Jamf Pro strips newlines from Custom Schema text fields)
- **Info button**: Fixed issue where both "Help" text and "?" icon appeared; now only shows icon when InfoButtonText is empty
- **Extension Attributes**: Fixed all EAs to use correct plist key names (lowercase camelCase) and proper managed preferences detection

### Changed
- Updated Configuration-Guide.md with documentation about using `\n` for line breaks in templates

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.0.1] - 2025-11-19

### Added
- **Self-healing watcher daemon** - Automatically syncs LaunchDaemon schedule when Configuration Profile changes
- New `--sync-check` command-line flag for schedule synchronization
- Watcher daemon runs every 15 minutes to detect configuration changes

### Changed
- `--setup` now creates two LaunchDaemons:
  - Main daemon for scheduled reminders
  - Watcher daemon for automatic schedule sync
- Updated documentation throughout for watcher daemon feature

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.0.0] - 2025-11-19

### Added
- Complete Swift binary implementation
- DDM enforcement detection and parsing
- SwiftDialog-based notification dialogs with customizable branding
- Configurable deferral system with threshold-based behavior
- Snooze functionality separate from deferrals
- Meeting/presentation detection (respects user assertions)
- Self-managing LaunchDaemon creation and updates
- Comprehensive health reporting for Jamf Extension Attributes
- macOS Unified Logging integration
- Test mode for development and validation
- Debug mode for Xcode testing without root privileges
- Configuration Profile JSON schema for Jamf Pro
- Extension Attributes for monitoring:
  - Health Status
  - Deferrals Remaining
  - Last Run Status
  - Enforcement Deadline
- Message template variables for dynamic content
- Support for custom icons, overlay images, and branding
- Automatic swiftDialog installation option
- Multi-entity support via preference domain argument

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

### Requirements
- macOS 12.0 (Monterey) or later
- swiftDialog 2.4.0 or later
- Jamf Pro (or compatible MDM)

