# DDM macOS Update Reminder

A Swift-based macOS binary that provides prominent, configurable end-user notifications for Apple's Declarative Device Management (DDM) enforced macOS updates.

## Overview

While Apple's Declarative Device Management (DDM) provides Mac Admins a powerful method to enforce macOS updates, its built-in notification tends to be too subtle. **DDM macOS Update Reminder** delivers highly customizable, prominent swiftDialog-based notifications that are entirely controlled through Jamf Configuration Profiles.

### Key Features

- **Configuration Profile Driven**: All settings managed via Jamf Configuration Profiles
- **Deploy Once**: Binary reads configuration from managed preferences - no script redeployment needed
- **Self-Healing Schedule**: Watcher daemon automatically syncs schedule changes from Configuration Profile
- **Flexible Deferrals**: Configurable deferral limits that decrease as deadline approaches
- **Snooze Support**: Optional short-term snooze separate from deferrals
- **Meeting Awareness**: Detects presentations/meetings and waits before displaying
- **Health Monitoring**: Extension Attributes report configuration status and errors
- **Self-Managing LaunchDaemon**: Binary creates and manages its own LaunchDaemon
- **Unified Logging**: Native macOS logging with customizable predicates

## Requirements

- macOS 12.0 (Monterey) or later
- Jamf Pro (or compatible MDM)
- Apple Silicon or Intel Mac

### swiftDialog Dependency

This tool uses [swiftDialog](https://github.com/swiftDialog/swiftDialog) to display notification windows. Enable `SwiftDialogAutoInstall` in your Configuration Profile and the binary will automatically download and install swiftDialog on first run.

## Quick Start

### 1. Create Configuration Profile in Jamf Pro

1. Go to **Computers > Configuration Profiles > New**
2. Add payload: **Application & Custom Settings**
3. Select **External Applications > Add**
4. Choose **Custom Schema**
5. Set **Preference Domain**: `com.macjediwizard.ddmupdatereminder`
6. Paste the JSON schema from `JamfResources/ConfigurationProfile/com.macjediwizard.ddmupdatereminder.json`
7. Configure your settings and scope to computers

### 2. Deploy Package

Download from [Releases](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/releases):

- **DDMmacOSUpdateReminder-1.0.1.pkg**

Upload to Jamf Pro and create a policy with a post-install script:

```bash
#!/bin/zsh
/usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmupdatereminder --setup
```

This creates two LaunchDaemons: the main reminder daemon and a watcher daemon that automatically syncs schedule changes from your Configuration Profile.

### 3. Verify Installation

```bash
# Check binary
/usr/local/bin/DDMmacOSUpdateReminder --version

# Check LaunchDaemon
launchctl list | grep ddmupdatereminder

# Test with simulated enforcement
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmupdatereminder --test
```

See the [Deployment Guide](Documentation/Deployment-Guide.md) for complete instructions.

## File Locations

```
/usr/local/bin/DDMmacOSUpdateReminder                              # Binary

/Library/Application Support/com.macjediwizard.ddmupdatereminder/
├── deferral.plist                                                 # Deferral state
└── health.plist                                                   # Health state for EAs

/Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist          # Main LaunchDaemon
/Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.watcher.plist  # Watcher LaunchDaemon
```

## Configuration

All configuration is managed through Jamf Configuration Profiles. See the [Configuration Guide](Documentation/Configuration-Guide.md) for complete details.

### Key Configuration Areas

- **Behavior Settings**: Reminder timing, meeting delays
- **Deferral Settings**: Max deferrals, schedule, snooze options
- **Schedule Settings**: LaunchDaemon run times
- **Branding Settings**: Icons, colors, window size
- **Support Settings**: Contact information
- **Dialog Content**: Message templates with variables

### Message Template Variables

Templates support variables like:
- `{userFirstName}`, `{userFullName}`, `{userName}`
- `{installedVersion}`, `{targetVersion}`
- `{deadlineFormatted}`, `{daysRemaining}`
- `{deferralsRemaining}`, `{maxDeferrals}`

See [Configuration Guide](Documentation/Configuration-Guide.md) for the complete list.

## Extension Attributes

Health monitoring Extension Attributes are provided in `JamfResources/ExtensionAttributes/`:

- **Health Status**: Overall configuration and run status
- **Deferrals Remaining**: User's remaining deferral count
- **Last Run Status**: Result of last execution (includes last user action)
- **Enforcement Deadline**: DDM deadline date

## Logging

Uses macOS Unified Logging:

```bash
# All logs
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h

# Errors only
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND messageType == error' --last 24h

# Real-time streaming
log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --level debug
```

See [Logging Reference](Documentation/Logging-Reference.md) for complete predicates.

## Documentation

- [Deployment Guide](Documentation/Deployment-Guide.md) - Complete deployment instructions
- [Configuration Guide](Documentation/Configuration-Guide.md) - All configuration options
- [Troubleshooting](Documentation/Troubleshooting.md) - Common issues and solutions
- [Logging Reference](Documentation/Logging-Reference.md) - Log analysis

## Support

- **Issues**: [GitHub Issues](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/discussions)
- **Mac Admins Slack**: #ddm-os-reminders

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

MIT License - See [LICENSE](LICENSE)
