# Security Policy

## Overview

DDM macOS Update Reminder is a system-level macOS utility that displays notifications for Declarative Device Management (DDM) enforced updates. Given its privileged execution context, security has been carefully considered throughout the design and implementation.

## Security Model

### Privilege Requirements

- **Root execution required**: The binary must run as root (`uid 0`) to:
  - Read protected system logs (`/var/log/install.log`)
  - Write state files to `/Library/Application Support/`
  - Manage LaunchDaemons in `/Library/LaunchDaemons/`
  - Run on behalf of logged-in users via LaunchDaemon

- **Debug mode exception**: The `--debug` flag bypasses the root check for development/testing purposes only. This is logged and intended solely for Xcode development.

### Code Signing & Notarization

All official releases are:
- Signed with **Developer ID Application: William Grzybowski (96KRXXRRDF)**
- Package signed with **Developer ID Installer**
- Apple notarized for Gatekeeper approval
- Built with hardened runtime (`--options runtime`)

To verify the binary signature:
```bash
codesign -dv --verbose=4 /usr/local/bin/DDMmacOSUpdateReminder
```

### Input Validation

#### Preference Domain Validation
The preference domain argument is validated against a strict regex pattern to ensure reverse domain notation format:
```regex
^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$
```

This prevents injection of special characters that could be used in path traversal or command injection.

#### URL Validation
All external URLs (icons, banners) are validated to:
1. Use only `http://` or `https://` schemes
2. Contain no shell metacharacters: `; | & \` $ ( ) { } [ ] < > \ ' " \n \r`

This prevents command injection through maliciously crafted URLs in configuration profiles.

#### Configuration Bounds Checking
All integer configuration values are clamped to documented min/max ranges. Out-of-range values are logged and adjusted to prevent unexpected behavior.

### External Process Execution

All external commands use the `Process` API with:
- Explicit absolute paths (e.g., `/usr/bin/curl`)
- Arguments passed as arrays, not shell-interpreted strings
- No use of `/bin/sh -c` or similar shell evaluation

Commands executed:
| Command | Purpose |
|---------|---------|
| `/usr/bin/stat` | Get logged-in user |
| `/usr/bin/sw_vers` | Get macOS version |
| `/usr/bin/pmset` | Check display assertions |
| `/usr/sbin/scutil` | Get computer name |
| `/usr/sbin/ioreg` | Get serial number |
| `/usr/bin/curl` | Download icons |
| `/usr/sbin/installer` | Install swiftDialog |
| `/bin/launchctl` | Manage LaunchDaemons |

### swiftDialog Verification

When auto-installing swiftDialog:
1. Package is downloaded from official GitHub releases
2. **Team ID verification** via `spctl` ensures authenticity
3. Expected Team ID: `PWA5E9TQ59` (Bart Reardon)

```swift
let expectedTeamID = "PWA5E9TQ59"
guard verifyTeamID(tempPkg, expected: expectedTeamID) else {
    Logger.shared.error("swiftDialog Team ID verification failed")
    return false
}
```

### File System Security

#### State File Permissions
All state files are created with:
- Owner: `root:wheel`
- Permissions: `0644` (files) / `0755` (directories)
- Atomic writes to prevent corruption

#### Temporary Files
- Written to `/var/tmp/` (system temp directory)
- Cleaned up after dialog exits via `defer` block
- Named predictably but not exploitable in root context

### Network Security

- **HTTPS URLs recommended** but HTTP allowed for compatibility
- 30-second timeout on all downloads
- No sensitive data transmitted (only icon/image downloads)

### Logging Security

- Uses macOS Unified Logging (`os_log`)
- All logged values are public (`%{public}@`)
- No passwords, secrets, or credentials are ever logged
- Log access restricted by standard macOS security model

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.2.x   | :white_check_mark: |
| 1.1.x   | :white_check_mark: |
| < 1.1   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** create a public GitHub issue
2. Email security concerns to the repository maintainer
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact assessment
   - Any suggested mitigations

We aim to respond within 48 hours and will work with you on coordinated disclosure.

## Security Best Practices for Deployment

### Configuration Profile Security
- Deploy configuration profiles via MDM (Jamf Pro) to ensure integrity
- Use HTTPS URLs for all icon and banner images
- Review message templates for sensitive information

### Access Control
- The binary location (`/usr/local/bin/`) is protected by SIP
- LaunchDaemon files require root to modify
- State files in `/Library/Application Support/` require root

### Monitoring
- Use provided Extension Attributes to monitor health status
- Review logs periodically for unexpected errors
- Monitor for unauthorized configuration changes

## Dependencies

This project has **no external runtime dependencies** beyond:
- Swift standard library
- Foundation framework
- os.log framework
- swiftDialog (optional, auto-installed)

This minimal dependency footprint reduces supply chain risk.
