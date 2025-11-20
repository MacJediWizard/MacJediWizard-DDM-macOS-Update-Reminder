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
/usr/local/bin/DDMmacOSUpdateReminder                    # Binary

/Library/Application Support/{PreferenceDomain}/
├── deferral.plist                                       # Deferral state
└── health.plist                                         # Health state for EAs

/Library/LaunchDaemons/{PreferenceDomain}.plist          # Main LaunchDaemon
/Library/LaunchDaemons/{PreferenceDomain}.watcher.plist  # Watcher LaunchDaemon
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

- **DDMmacOSUpdateReminder-1.0.1.pkg**

This installs the binary to `/usr/local/bin/DDMmacOSUpdateReminder`.

### Create Jamf Policy

1. Upload `DDMmacOSUpdateReminder-1.0.1.pkg` to Jamf Pro
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

The `--setup` command creates two LaunchDaemons:

1. **Main daemon** (`com.macjediwizard.ddmupdatereminder.plist`)
   - Runs at times configured in your Configuration Profile
   - Displays the reminder dialog when DDM enforcement is active

2. **Watcher daemon** (`com.macjediwizard.ddmupdatereminder.watcher.plist`)
   - Runs every 15 minutes
   - Monitors for Configuration Profile schedule changes
   - Automatically updates the main daemon when schedule changes

This self-healing design means you only need to run `--setup` once during initial deployment. Future schedule changes in your Configuration Profile are automatically applied.

## Step 4: Verify Installation

### Check Binary

```bash
/usr/local/bin/DDMmacOSUpdateReminder --version
# Should output: DDMmacOSUpdateReminder version 1.0.1
```

### Check LaunchDaemons

```bash
# Verify plists exist
ls -la /Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist
ls -la /Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.watcher.plist

# Verify daemons are loaded
launchctl list | grep ddmupdatereminder
# Should show both main daemon and watcher daemon
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
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h
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

Create Extension Attributes in Jamf Pro for monitoring. Scripts are in `JamfResources/ExtensionAttributes/`.

### Available Extension Attributes

| Extension Attribute | Script | Data Type | Description |
|---------------------|--------|-----------|-------------|
| Health Status | `EA-Health-Status.sh` | String | Overall health status |
| Deferrals Remaining | `EA-Deferrals-Remaining.sh` | String | User's remaining deferrals |
| Last Run Status | `EA-Last-Run-Status.sh` | String | Result of last execution (includes last user action) |
| Enforcement Deadline | `EA-Enforcement-Deadline.sh` | String | DDM deadline date |

### Creating Extension Attributes in Jamf Pro

For each Extension Attribute:

1. In Jamf Pro, go to **Settings > Computer Management > Extension Attributes**
2. Click **New**
3. Configure:
   - **Display Name**: Use the name from the table above (e.g., "DDM Reminder - Health Status")
   - **Description**: (Optional) Add description from table
   - **Data Type**: String
   - **Inventory Display**: General or your preferred section
   - **Input Type**: Script
4. Paste the contents of the corresponding `.sh` file from `JamfResources/ExtensionAttributes/`
5. Click **Save**

### Example: Health Status EA

```bash
#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Health Status
# Reports the health status of DDM macOS Update Reminder
# Returns: Healthy, ConfigMissing, Error: <details>, or NotInstalled

# Preference domain - adjust if using custom domain
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Health state file path
HEALTH_FILE="/Library/Application Support/${PREF_DOMAIN}/health.plist"

# Check if configuration profile exists
CONFIG_EXISTS=$(defaults read "${PREF_DOMAIN}" ConfigVersion 2>/dev/null)

if [[ -z "${CONFIG_EXISTS}" ]]; then
    echo "<result>ConfigMissing</result>"
    exit 0
fi

# Check if health file exists
if [[ ! -f "${HEALTH_FILE}" ]]; then
    echo "<result>NotInstalled</result>"
    exit 0
fi

# Read health status
LAST_STATUS=$(/usr/libexec/PlistBuddy -c "Print :LastRunStatus" "${HEALTH_FILE}" 2>/dev/null)
CONFIG_DETECTED=$(/usr/libexec/PlistBuddy -c "Print :ConfigProfileDetected" "${HEALTH_FILE}" 2>/dev/null)

# Check for errors
ERROR_COUNT=$(/usr/libexec/PlistBuddy -c "Print :ErrorLog" "${HEALTH_FILE}" 2>/dev/null | grep -c "^    " || echo "0")

if [[ "${LAST_STATUS}" == "Success" ]] && [[ "${CONFIG_DETECTED}" == "true" ]]; then
    if [[ "${ERROR_COUNT}" -gt 0 ]]; then
        echo "<result>Healthy (${ERROR_COUNT} warnings)</result>"
    else
        echo "<result>Healthy</result>"
    fi
elif [[ "${CONFIG_DETECTED}" != "true" ]]; then
    echo "<result>Error: Config profile not detected</result>"
elif [[ -n "${LAST_STATUS}" ]]; then
    echo "<result>Error: ${LAST_STATUS}</result>"
else
    echo "<result>Unknown</result>"
fi
```

### Custom Preference Domain

If using a custom preference domain, update the `PREF_DOMAIN` variable in each EA script:

```bash
PREF_DOMAIN="com.yourcompany.ddmupdatereminder"
```

### Creating Smart Groups

Use Extension Attributes to create Smart Groups for targeting:

**Example: Computers with depleted deferrals**
- Extension Attribute: "DDM Reminder - Deferrals Remaining"
- Operator: like
- Value: "0 of"

**Example: Computers with errors**
- Extension Attribute: "DDM Reminder - Health Status"
- Operator: like
- Value: "Error"

**Example: Computers not installed**
- Extension Attribute: "DDM Reminder - Health Status"
- Operator: is
- Value: "NotInstalled"

## Updating

### Update Configuration

Simply update the Configuration Profile in Jamf Pro. The binary reads settings at each run.

### Update Binary

1. Upload new package version to Jamf Pro
2. Deploy via policy using the same policy (set execution frequency appropriately)
3. The post-install script runs `--setup` again, which is safe to run multiple times

**Note**: The watcher daemon automatically syncs schedule changes from your Configuration Profile. You don't need to manually re-run setup when changing reminder times - just update the Configuration Profile and the watcher will apply the changes within 15 minutes.

### Uninstall

Create an uninstall policy with this script:

```bash
#!/bin/zsh

# Uninstall DDMmacOSUpdateReminder

BINARY="/usr/local/bin/DDMmacOSUpdateReminder"
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"
SUPPORT_DIR="/Library/Application Support/${PREF_DOMAIN}"
DAEMON_PLIST="/Library/LaunchDaemons/${PREF_DOMAIN}.plist"
WATCHER_PLIST="/Library/LaunchDaemons/${PREF_DOMAIN}.watcher.plist"

# Unload LaunchDaemons
if [[ -f "$DAEMON_PLIST" ]]; then
    launchctl bootout system "$DAEMON_PLIST" 2>/dev/null
fi
if [[ -f "$WATCHER_PLIST" ]]; then
    launchctl bootout system "$WATCHER_PLIST" 2>/dev/null
fi

# Remove files
rm -f "$DAEMON_PLIST"
rm -f "$WATCHER_PLIST"
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
  --setup              Create/update LaunchDaemons (main + watcher) and exit
  --sync-check         Check if schedule needs sync and update if needed
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
   log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h
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
