# DDM macOS Update Reminder

A Swift-based macOS binary that provides prominent, configurable end-user notifications for Apple's Declarative Device Management (DDM) enforced macOS updates.

## Overview

While Apple's Declarative Device Management (DDM) provides Mac Admins a powerful method to enforce macOS updates, its built-in notification tends to be too subtle. **DDM macOS Update Reminder** delivers highly customizable, prominent swiftDialog-based notifications that are entirely controlled through Jamf Configuration Profiles.

### Key Features

- **Configuration Profile Driven**: All settings managed via Jamf Configuration Profiles (JSON)
- **Deploy Once**: Binary reads configuration from managed preferences - no script redeployment needed
- **Flexible Deferrals**: Configurable deferral limits that decrease as deadline approaches
- **Snooze Support**: Optional short-term snooze separate from deferrals
- **Meeting Awareness**: Detects presentations/meetings and waits before displaying
- **Health Monitoring**: Extension Attributes report configuration status and errors
- **Self-Managing LaunchDaemon**: Binary creates and manages its own LaunchDaemon
- **Unified Logging**: Native macOS logging with customizable predicates
- **Multi-Entity Support**: Single binary supports multiple organizations via domain argument

## Architecture

```
/Library/Management/com.yourorg/
├── ddm-update-reminder              # Signed binary
├── ddm-deferral.plist               # Deferral tracking
└── ddm-health.plist                 # Health state

/Library/LaunchDaemons/
└── com.yourorg.ddmupdatereminder.plist

Jamf Configuration Profile:
└── com.yourorg.ddmupdatereminder    # Managed preferences
```

## Requirements

- macOS 13.0 (Ventura) or later
- [swiftDialog](https://github.com/swiftDialog/swiftDialog) 2.4.0 or later
- Jamf Pro (or compatible MDM for managed preferences)
- Apple Silicon or Intel Mac

## Installation

### 1. Deploy Configuration Profile

Upload the JSON manifest to Jamf Pro as an External Application and configure your settings.

See [JamfResources/ConfigurationProfile/](JamfResources/ConfigurationProfile/) for the manifest.

### 2. Deploy Binary

Download the signed/notarized binary from [Releases](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/releases) and deploy via Jamf package or script.

### 3. Initial Run

The binary will:
- Read configuration from managed preferences
- Create its LaunchDaemon
- Begin monitoring for DDM enforcement deadlines

## Configuration

All configuration is managed through Jamf Configuration Profiles. See the [Configuration Guide](Documentation/Configuration-Guide.md) for complete details.

### Key Configuration Areas

- **Organization Settings**: Domain name, management directory, logging
- **Behavior Settings**: Reminder timing, meeting delays, assertion handling
- **Deferral Settings**: Max deferrals, schedule, snooze options
- **Schedule Settings**: LaunchDaemon run times
- **Branding Settings**: Icons, overlay images
- **Support Settings**: Contact information, KB articles
- **Dialog Content**: Message templates with variables

### Message Template Variables

Templates support variables like:
- `{userFirstName}`, `{userFullName}`, `{userName}`
- `{installedVersion}`, `{targetVersion}`
- `{deadlineFormatted}`, `{daysRemaining}`
- `{deferralsRemaining}`, `{maxDeferrals}`
- And many more...

See [Documentation/Configuration-Guide.md](Documentation/Configuration-Guide.md) for the complete list.

## Extension Attributes

Health monitoring Extension Attributes are provided:

- **Health Status**: Configuration profile detection and validity
- **Deferrals Remaining**: Current deferral count
- **Last Run Status**: Success/error with details

See [JamfResources/ExtensionAttributes/](JamfResources/ExtensionAttributes/)

## Logging

Uses macOS Unified Logging. View logs with:

```bash
# All logs
log show --predicate 'subsystem == "com.yourorg.ddmupdatereminder"' --last 1h

# Errors only
log show --predicate 'subsystem == "com.yourorg.ddmupdatereminder" AND messageType == error' --last 24h

# Real-time streaming
log stream --predicate 'subsystem == "com.yourorg.ddmupdatereminder"' --level debug
```

See [Documentation/Logging-Reference.md](Documentation/Logging-Reference.md) for complete predicates.

## Development

### Building

Requires Xcode 15+ and macOS 14+.

```bash
cd DDMNotifier
xcodebuild -scheme DDMNotifier -configuration Release
```

### Code Signing

The binary must be signed with a Developer ID and notarized for distribution.

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](LICENSE)

## Support

- **Issues**: [GitHub Issues](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/discussions)
- **Mac Admins Slack**: #ddm-os-reminders

## Roadmap

See [GitHub Issues](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/issues) for planned features and known issues.
