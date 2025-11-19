# Troubleshooting Guide

Common issues and solutions for DDM macOS Update Reminder.

## Diagnostic Commands

### Quick Health Check

```bash
# Check if binary exists
ls -la /Library/Management/com.yourorg/ddm-update-reminder

# Check LaunchDaemon
launchctl list | grep ddmupdatereminder

# Check config profile
defaults read com.macjediwizard.ddmupdatereminder ConfigVersion

# Check recent logs
log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder"' --last 1h
```

## Common Issues

### Issue: Reminder Not Appearing

**Symptoms**: LaunchDaemon runs but no dialog appears.

**Causes and Solutions**:

1. **No DDM enforcement detected**
   ```bash
   grep EnforcedInstallDate /var/log/install.log
   ```
   - Ensure DDM OS update is configured in your MDM
   - Check that machine is in scope for DDM

2. **Outside reminder window**
   - Check `DaysBeforeDeadlineDisplayReminder` setting
   - Verify days remaining until deadline

3. **User in meeting**
   - Check for display assertions: `pmset -g assertions`
   - Wait for `MeetingDelayMinutes` to expire

4. **Already up to date**
   - Compare installed version with required version
   - No reminder needed if compliant

5. **No logged-in user**
   - Reminder requires GUI user session

### Issue: Configuration Profile Not Detected

**Symptoms**: EA shows "ConfigMissing"

**Solutions**:

1. Verify profile is installed:
   ```bash
   profiles list | grep -i ddm
   ```

2. Check preference domain:
   ```bash
   defaults read com.macjediwizard.ddmupdatereminder
   ```

3. Ensure profile is scoped to computer, not user

4. Force profile refresh:
   ```bash
   sudo jamf recon
   ```

### Issue: LaunchDaemon Not Loading

**Symptoms**: Binary never runs.

**Solutions**:

1. Check daemon status:
   ```bash
   launchctl list | grep ddmupdatereminder
   ```

2. Verify plist exists:
   ```bash
   ls -la /Library/LaunchDaemons/ | grep ddmupdatereminder
   ```

3. Check plist syntax:
   ```bash
   plutil -lint /Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist
   ```

4. Manually load:
   ```bash
   sudo launchctl bootstrap system /Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist
   ```

5. Check for errors:
   ```bash
   log show --predicate 'process == "launchd" AND eventMessage CONTAINS "ddmupdatereminder"' --last 1h
   ```

### Issue: swiftDialog Errors

**Symptoms**: Logs show dialog-related errors.

**Solutions**:

1. Check swiftDialog installed:
   ```bash
   /usr/local/bin/dialog --version
   ```

2. Verify minimum version:
   ```bash
   # Compare with SwiftDialogMinVersion in config
   ```

3. Test swiftDialog directly:
   ```bash
   /usr/local/bin/dialog --title "Test" --message "Hello" --button1text "OK"
   ```

4. Reinstall swiftDialog:
   ```bash
   # Download from https://github.com/swiftDialog/swiftDialog/releases
   ```

### Issue: Deferrals Not Tracking

**Symptoms**: Deferral count doesn't change or resets unexpectedly.

**Solutions**:

1. Check deferral file:
   ```bash
   /usr/libexec/PlistBuddy -c "Print" /Library/Management/com.yourorg/ddm-deferral.plist
   ```

2. Check permissions:
   ```bash
   ls -la /Library/Management/com.yourorg/
   ```

3. Verify deadline hasn't changed:
   - `ResetOnNewDeadline` may have reset count

4. Check deferral schedule:
   - Verify `DeferralSchedule` in config

### Issue: Icons Not Loading

**Symptoms**: Default/missing icons in dialog.

**Solutions**:

1. Check network connectivity
   ```bash
   curl -I "https://ics.services.jamfcloud.com/icon/hash_..."
   ```

2. Verify URLs in config are accessible

3. Check local icon paths exist

4. Review logs for download errors:
   ```bash
   log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder" AND eventMessage CONTAINS "icon"' --last 1h
   ```

### Issue: Wrong Deadline Displayed

**Symptoms**: Deadline doesn't match MDM configuration.

**Solutions**:

1. Check install.log parsing:
   ```bash
   grep EnforcedInstallDate /var/log/install.log | tail -n 1
   ```

2. Check for past-due deadline handling:
   ```bash
   grep setPastDuePaddedEnforcementDate /var/log/install.log | tail -n 1
   ```

3. Verify machine received updated DDM policy

### Issue: Health State Not Updating

**Symptoms**: Extension Attributes show stale data.

**Solutions**:

1. Verify `EnableHealthReporting` is true

2. Check health file permissions:
   ```bash
   ls -la /Library/Management/com.yourorg/ddm-health.plist
   ```

3. Read health file:
   ```bash
   /usr/libexec/PlistBuddy -c "Print" /Library/Management/com.yourorg/ddm-health.plist
   ```

4. Trigger inventory update in Jamf

## Log Analysis

### Find Startup Issues

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder" AND category == "preflight"' --last 24h
```

### Find Configuration Errors

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder" AND (category == "config" OR messageType == error)' --last 24h
```

### Track User Behavior

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder" AND category == "userAction"' --last 7d
```

## Reset and Clean State

### Reset Deferrals

```bash
sudo rm /Library/Management/com.yourorg/ddm-deferral.plist
```

### Reset Health State

```bash
sudo rm /Library/Management/com.yourorg/ddm-health.plist
```

### Complete Reset

```bash
# Unload daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist

# Remove all state files
sudo rm -f /Library/Management/com.yourorg/ddm-*.plist

# Reload daemon
sudo launchctl bootstrap system /Library/LaunchDaemons/com.macjediwizard.ddmupdatereminder.plist
```

## Test Mode

Enable test mode for debugging:

1. Set in configuration profile:
   ```json
   {
     "TestMode": true,
     "TestDaysRemaining": 5,
     "VerboseLogging": true
   }
   ```

2. Run manually:
   ```bash
   sudo /Library/Management/com.yourorg/ddm-update-reminder --domain com.macjediwizard.ddmupdatereminder
   ```

3. Stream logs in another terminal:
   ```bash
   log stream --predicate 'subsystem == "com.macjediwizard.ddmupdatereminder"' --level debug
   ```

## Getting Help

If issues persist:

1. Collect logs using the script in Logging-Reference.md
2. Note macOS version and hardware
3. Include configuration profile settings (sanitized)
4. Open issue on [GitHub](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/issues)
