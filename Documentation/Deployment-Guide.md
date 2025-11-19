# Deployment Guide

Step-by-step guide to deploying DDM macOS Update Reminder in your environment.

## Prerequisites

- Jamf Pro (or compatible MDM)
- Apple Developer ID for code signing (for custom builds)
- macOS 13.0+ target machines
- DDM OS update enforcement configured in your MDM

## Deployment Overview

1. Deploy Configuration Profile
2. Deploy swiftDialog (if not already deployed)
3. Deploy binary package
4. Verify installation
5. Monitor with Extension Attributes

## Step 1: Deploy Configuration Profile

### Create External Application

1. In Jamf Pro, go to **Settings > Computer Management > Custom Schema**
2. Click **External Applications > Add**
3. Configure:
   - **Source**: Custom Schema
   - **Preference Domain**: `com.macjediwizard.ddmupdatereminder`
4. Upload the JSON manifest from `JamfResources/ConfigurationProfile/`

### Configure Settings

At minimum, configure:
- Organization Settings (domain name, directory)
- Support Settings (contact information)
- Dialog Content (customize messages)

### Create Configuration Profile

1. Go to **Computers > Configuration Profiles > New**
2. Add **Application & Custom Settings > External Applications**
3. Select your External Application
4. Configure values using the Jamf Pro UI
5. Scope to target computers

## Step 2: Deploy swiftDialog

If swiftDialog is not already deployed, you have two options:

### Option A: Let Binary Auto-Install

Set in your configuration profile:
```json
{
  "SwiftDialogAutoInstall": true
}
```

The binary will download and install swiftDialog from the official GitHub release.

### Option B: Deploy via Jamf

1. Download latest swiftDialog from [GitHub releases](https://github.com/swiftDialog/swiftDialog/releases)
2. Create a Jamf package
3. Deploy before the DDM Update Reminder binary

## Step 3: Deploy Binary

### Download Release

Download the signed/notarized binary from [Releases](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/releases).

### Create Package

Create a Jamf package that:

1. Creates the management directory:
   ```bash
   mkdir -p /Library/Management/com.yourorg
   ```

2. Copies the binary:
   ```bash
   cp ddm-update-reminder /Library/Management/com.yourorg/
   chmod 755 /Library/Management/com.yourorg/ddm-update-reminder
   chown root:wheel /Library/Management/com.yourorg/ddm-update-reminder
   ```

3. Runs initial setup:
   ```bash
   /Library/Management/com.yourorg/ddm-update-reminder --domain com.macjediwizard.ddmupdatereminder --setup
   ```

### Alternative: Deployment Script

Use the provided installation script in `JamfResources/Scripts/`:

```bash
#!/bin/zsh
# Install DDM macOS Update Reminder

BINARY_URL="https://your-distribution-point/ddm-update-reminder"
INSTALL_DIR="/Library/Management/com.yourorg"
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Create directory
mkdir -p "${INSTALL_DIR}"

# Download binary
curl -L -o "${INSTALL_DIR}/ddm-update-reminder" "${BINARY_URL}"

# Set permissions
chmod 755 "${INSTALL_DIR}/ddm-update-reminder"
chown root:wheel "${INSTALL_DIR}/ddm-update-reminder"

# Run setup (creates LaunchDaemon)
"${INSTALL_DIR}/ddm-update-reminder" --domain "${PREF_DOMAIN}" --setup

exit 0
```

### Policy Configuration

1. Create new policy in Jamf Pro
2. Add package or script
3. Set trigger: Enrollment Complete, Recurring Check-in
4. Scope to target computers
5. Execution frequency: Once per computer

## Step 4: Verify Installation

### Check Binary

```bash
ls -la /Library/Management/com.yourorg/ddm-update-reminder
```

### Check LaunchDaemon

```bash
launchctl list | grep ddmupdatereminder
ls -la /Library/LaunchDaemons/ | grep ddmupdatereminder
```

### Check Configuration Profile

```bash
defaults read com.macjediwizard.ddmupdatereminder
```

### Test Run

```bash
# Run with test mode
sudo /Library/Management/com.yourorg/ddm-update-reminder --domain com.macjediwizard.ddmupdatereminder --test
```

### Check Logs

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder"' --last 1h
```

## Step 5: Set Up Extension Attributes

### Create Extension Attributes

In Jamf Pro, create Extension Attributes using the scripts from `JamfResources/ExtensionAttributes/`:

1. **DDM Update Reminder - Health Status**
   - Data Type: String
   - Script: `EA-Health-Status.sh`

2. **DDM Update Reminder - Deferrals Remaining**
   - Data Type: String
   - Script: `EA-Deferrals-Remaining.sh`

3. **DDM Update Reminder - Last Run Status**
   - Data Type: String
   - Script: `EA-Last-Run-Status.sh`

4. **DDM Update Reminder - Enforcement Deadline**
   - Data Type: String
   - Script: `EA-Enforcement-Deadline.sh`

### Create Smart Groups

Create Smart Groups based on Extension Attributes:

**Healthy Installations**:
- DDM Update Reminder - Health Status is "Healthy"

**Config Issues**:
- DDM Update Reminder - Health Status contains "Error"
- DDM Update Reminder - Health Status is "ConfigMissing"

**No Deferrals Remaining**:
- DDM Update Reminder - Deferrals Remaining is "0"

## Updating

### Update Configuration

Simply update the Configuration Profile in Jamf Pro. The binary reads settings at each run.

### Update Binary

1. Update the package/script with new binary
2. Deploy via policy
3. The binary will update its LaunchDaemon if needed

### Uninstall

Create an uninstall policy with script:

```bash
#!/bin/zsh
# Uninstall DDM macOS Update Reminder

INSTALL_DIR="/Library/Management/com.yourorg"
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"
DAEMON_LABEL="${PREF_DOMAIN}"

# Unload LaunchDaemon
launchctl bootout system "/Library/LaunchDaemons/${DAEMON_LABEL}.plist" 2>/dev/null

# Remove files
rm -f "/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
rm -f "${INSTALL_DIR}/ddm-update-reminder"
rm -f "${INSTALL_DIR}/ddm-health.plist"
rm -f "${INSTALL_DIR}/ddm-deferral.plist"

# Remove directory if empty
rmdir "${INSTALL_DIR}" 2>/dev/null

exit 0
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

1. Check for display assertions:
   ```bash
   pmset -g assertions
   ```

2. Check DDM enforcement exists:
   ```bash
   grep EnforcedInstallDate /var/log/install.log
   ```

3. Verify swiftDialog:
   ```bash
   /usr/local/bin/dialog --version
   ```

## Security Considerations

- Binary must be signed with Developer ID
- Binary must be notarized
- Use HTTPS for icon URLs
- Sanitize sensitive data in logs
- Restrict management directory permissions
