# Deployment Guide

Step-by-step guide to deploying DDM macOS Update Reminder in your environment.

## Prerequisites

- Jamf Pro (or compatible MDM)
- macOS 12.0+ target machines
- DDM OS update enforcement configured in your MDM

## Deployment Overview

1. Deploy Configuration Profile
2. Deploy the installer package
3. Run setup command to create LaunchDaemon
4. Verify installation

## File Locations

After deployment, files are located at:

```
/usr/local/bin/DDMmacOSUpdateReminder              # Binary

/Library/Application Support/{PreferenceDomain}/
├── deferral.plist                                 # Deferral state
└── health.plist                                   # Health state for EAs

/Library/LaunchDaemons/{PreferenceDomain}.plist    # LaunchDaemon
```

Where `{PreferenceDomain}` is `com.macjediwizard.ddmupdatereminder` by default.

## Step 1: Deploy Configuration Profile

### Option A: Using Jamf Pro Custom Schema (Recommended)

1. In Jamf Pro, go to **Computers > Configuration Profiles**
2. Click **New**
3. Add payload: **Application & Custom Settings**
4. Select **External Applications** > **Add**
5. Choose **Custom Schema**
6. Set **Preference Domain** to: `com.macjediwizard.ddmupdatereminder`
7. Paste the contents of `JamfResources/ConfigurationProfile/com.macjediwizard.ddmupdatereminder.json`
8. Click **Add**
9. Configure your settings using the Jamf Pro UI
10. Scope to target computers

### Option B: Manual Property List

Create a Configuration Profile with Application & Custom Settings using preference domain `com.macjediwizard.ddmupdatereminder` and configure the settings manually.

### Minimum Required Settings

At minimum, configure:
- **AdvancedSettings > SwiftDialogAutoInstall**: `true` (recommended)
- **SupportSettings**: Your IT contact information
- **DialogContent**: Customize messages as needed

## Step 2: Deploy Package

### Download

Download the signed and notarized package from [Releases](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/releases):

- **DDMmacOSUpdateReminder-1.0.0.pkg**

This installs the binary to `/usr/local/bin/DDMmacOSUpdateReminder`.

### Create Jamf Policy

1. Upload `DDMmacOSUpdateReminder-1.0.0.pkg` to Jamf Pro
2. Create new policy
3. Add the package
4. **Important**: Add a post-install script (see Step 3)
5. Set triggers: Enrollment Complete, Recurring Check-in
6. Scope to target computers
7. Execution frequency: Once per computer

## Step 3: Run Setup Command

After the package installs, run the setup command to create the LaunchDaemon.

### Post-Install Script

Add this script to your Jamf policy:

```bash
#!/bin/zsh

# DDMmacOSUpdateReminder Post-Install Setup
# Creates LaunchDaemon for scheduled execution

BINARY="/usr/local/bin/DDMmacOSUpdateReminder"
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Verify binary exists
if [[ ! -x "$BINARY" ]]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

# Run setup to create LaunchDaemon
"$BINARY" --domain "$PREF_DOMAIN" --setup

if [[ $? -eq 0 ]]; then
    echo "LaunchDaemon created successfully"
else
    echo "Error: Failed to create LaunchDaemon"
    exit 1
fi

exit 0
```

### What Setup Does

The `--setup` command:
- Creates the LaunchDaemon at `/Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist`
- Configures run times from your Configuration Profile
- Loads the daemon into launchd
- The daemon will then run at scheduled times and at login

## Step 4: Verify Installation

### Check Binary

```bash
/usr/local/bin/DDMmacOSUpdateReminder --version
# Should output: DDMmacOSUpdateReminder version 1.0.0
```

### Check LaunchDaemon

```bash
# Verify plist exists
ls -la /Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist

# Verify daemon is loaded
launchctl list | grep ddmupdatereminder
```

### Check Configuration Profile

```bash
# Read all settings
defaults read com.macjediwizard.ddmupdatereminder

# Check specific setting
defaults read com.macjediwizard.ddmupdatereminder ConfigVersion
```

### Test Run

```bash
# Run with test mode (simulates DDM enforcement)
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmupdatereminder --test
```

### Check Logs

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder"' --last 1h
```

## swiftDialog Dependency

DDMmacOSUpdateReminder uses [swiftDialog](https://github.com/swiftDialog/swiftDialog) to display notifications.

### Auto-Install (Recommended)

Enable in your Configuration Profile:
```
AdvancedSettings > SwiftDialogAutoInstall: true
AdvancedSettings > SwiftDialogMinVersion: 2.4.0
```

The binary will automatically download and install swiftDialog on first run.

### Manual Install

If you prefer to manage swiftDialog separately:
1. Download from [swiftDialog releases](https://github.com/swiftDialog/swiftDialog/releases)
2. Deploy via Jamf before DDMmacOSUpdateReminder
3. Set `SwiftDialogAutoInstall: false`

## Extension Attributes

Create Extension Attributes in Jamf Pro for monitoring. Scripts are in `JamfResources/ExtensionAttributes/`:

| Extension Attribute | Script | Data Type | Description |
|---------------------|--------|-----------|-------------|
| Health Status | `EA-Health-Status.sh` | String | Overall health status |
| Deferrals Remaining | `EA-Deferrals-Remaining.sh` | String | User's remaining deferrals |
| Last Run Status | `EA-Last-Run-Status.sh` | String | Result of last execution |
| Enforcement Deadline | `EA-Enforcement-Deadline.sh` | String | DDM deadline date |
| User Actions | `EA-User-Actions.sh` | String | Last user action taken |

### Update Extension Attribute Paths

The Extension Attribute scripts need the correct path. Update them to use:

```bash
HEALTH_FILE="/Library/Application Support/com.macjediwizard.ddmupdatereminder/health.plist"
```

## Updating

### Update Configuration

Simply update the Configuration Profile in Jamf Pro. The binary reads settings at each run.

### Update Binary

1. Upload new package version to Jamf Pro
2. Deploy via policy
3. Run setup again if LaunchDaemon schedule changed:
   ```bash
   sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmupdatereminder --setup
   ```

### Uninstall

Create an uninstall policy with this script:

```bash
#!/bin/zsh

# Uninstall DDMmacOSUpdateReminder

BINARY="/usr/local/bin/DDMmacOSUpdateReminder"
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"
SUPPORT_DIR="/Library/Application Support/${PREF_DOMAIN}"
DAEMON_PLIST="/Library/LaunchDaemons/${PREF_DOMAIN}.plist"

# Unload LaunchDaemon
if [[ -f "$DAEMON_PLIST" ]]; then
    launchctl bootout system "$DAEMON_PLIST" 2>/dev/null
fi

# Remove files
rm -f "$DAEMON_PLIST"
rm -f "$BINARY"
rm -rf "$SUPPORT_DIR"

echo "DDMmacOSUpdateReminder uninstalled"
exit 0
```

## Command-Line Reference

```bash
DDMmacOSUpdateReminder --domain <preference.domain> [options]

Required:
  --domain <domain>    Preference domain for managed preferences
                       (e.g., com.macjediwizard.ddmupdatereminder)

Options:
  --setup              Create/update LaunchDaemon and exit
  --test               Run in test mode (show dialog regardless of DDM state)
  --debug              Skip root check (for Xcode testing only)
  --version, -v        Print version and exit
  --help, -h           Print this help message

Examples:
  DDMmacOSUpdateReminder --domain com.macjediwizard.ddmupdatereminder
  DDMmacOSUpdateReminder --domain com.macjediwizard.ddmupdatereminder --setup
  DDMmacOSUpdateReminder --domain com.macjediwizard.ddmupdatereminder --test
```

## Troubleshooting

### Binary Not Running

1. Check LaunchDaemon is loaded:
   ```bash
   launchctl list | grep ddmupdatereminder
   ```

2. Check for errors:
   ```bash
   log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder"' --last 1h
   ```

### Configuration Not Applied

1. Verify profile is installed:
   ```bash
   profiles list | grep ddmupdatereminder
   ```

2. Check defaults:
   ```bash
   defaults read com.macjediwizard.ddmupdatereminder
   ```

### Dialog Not Appearing

1. Check DDM enforcement exists:
   ```bash
   grep -i "software update" /var/log/install.log | tail -20
   ```

2. Verify swiftDialog:
   ```bash
   /usr/local/bin/dialog --version
   ```

3. Check for display assertions (meetings):
   ```bash
   pmset -g assertions
   ```

## Security Considerations

- Binary is signed with Developer ID Application
- Binary is notarized by Apple
- Requires root privileges for normal operation
- Use HTTPS for icon URLs
- State files are stored in protected directories
