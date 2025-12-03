# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Additional customization options
- Extended localization support

## [1.2.0] - 2025-12-03

### Added
- **Input validation bounds checking** - All integer configuration values are now validated against documented min/max ranges (issue #39)
- **VerboseLogging implementation** - The `VerboseLogging` configuration option now enables detailed debug logging (issue #46)
- **AutoOpenUpdate behavior** - New `ExhaustedBehavior: AutoOpenUpdate` option shows countdown timer and auto-opens Software Update when deferrals exhausted (issue #50)
- **Missing template variables** - Added `{installedBuild}`, `{deadlineDate}`, and `{deadlineTime}` variables (issue #52)
- **Version mismatch detection** - Binary now logs warning when configuration version differs significantly from expected schema version (issue #43)
- **SECURITY.md** - New comprehensive security documentation covering privilege model, input validation, and code signing (issue #45)
- **Checksum verification helper** - Added SHA-256 checksum verification function for defense-in-depth (issue #41)
- **Rate limiting for swiftDialog install** - Exponential backoff (15min, 1hr, 4hr, 24hr) prevents repeated installation failures (issue #40)
- **Curl retry logic** - All icon/banner downloads now retry up to 3 times with exponential backoff (issue #44)
- **Structured error codes** - New `ErrorCode` enum with numeric codes for programmatic monitoring and alerting (issue #42)
- **Unit tests** - Added test suite for Configuration, DDMParser, and URL validation (issue #47)

### Fixed
- **create-pkg.sh version sync** - Package version now extracted from main.swift instead of hardcoded (issue #49)
- **HealthStatePath configuration** - The `HealthStatePath` setting is now properly used (was hardcoded before) (issue #51)
- **README version reference** - Documentation now references latest release generically (issue #48)
- **JSON schema HealthStatePath default** - Changed from `ddm-health.plist` to `health.plist` to match code

### Changed
- Version bumped to 1.2.0
- JSON schema version updated to 1.2.0
- Health state now includes `lastErrorCode`, `lastErrorCategory`, `binaryVersion`, and `structuredErrorLog` fields
- Logger now has `verboseMode` property and `verbose()` method

### Security
- URL validation blocks shell metacharacters to prevent command injection
- Configuration values clamped to safe ranges
- Team ID verification for swiftDialog downloads
- All security measures documented in SECURITY.md

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.1.1] - 2025-11-20

### Fixed
- **Test mode now skips meeting detection** - Test mode (via `--test` flag or `TestMode: true` in config) now bypasses meeting/assertion detection entirely
- Users can now test dialogs immediately without needing to kill background apps (Zoho, Teams, screen sharing, etc.)
- Added clear log message: "Test mode: skipping meeting/assertion checks"

### Changed
- Test mode behavior now matches debug mode for meeting detection

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.1.0] - 2025-11-20

### ⚠️ BREAKING CHANGES
- **Preference domain updated** from `com.macjediwizard.ddmupdatereminder` to `com.macjediwizard.ddmmacosupdatereminder`
- Resolves inconsistency between preference domain and logger subsystem (issue #36)
- **Migration required**: Update all Configuration Profiles to use new preference domain
- State files (deferrals, health) will not migrate automatically and will reset

### Changed
- Updated preference domain in all Extension Attributes (4 files)
- Renamed JSON schema file to `com.macjediwizard.ddmmacosupdatereminder.json`
- Updated all documentation (README, Configuration Guide, Deployment Guide, Troubleshooting, Logging Reference, Bug Report template)
- Updated main.swift default preference domain

### Migration Guide
1. Update Configuration Profile preference domain in Jamf Pro
2. Update Custom Schema JSON file reference
3. Update deployment policy post-install script to use new domain
4. Redeploy to all managed machines
5. See release notes for complete migration instructions

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

## [1.0.6] - 2025-11-20

### Added
- **Dynamic ManagementDirectory**: Extension Attributes now automatically read ManagementDirectory from Configuration Profile

### Changed
- Documentation updated with correct ManagementDirectory default and file location details

### Package
- Signed with Developer ID Application: William Grzybowski (96KRXXRRDF)
- Notarized by Apple
- Installs to `/usr/local/bin/DDMmacOSUpdateReminder`

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

