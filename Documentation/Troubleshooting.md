# Troubleshooting Guide

Common issues and solutions for DDM macOS Update Reminder.

## Diagnostic Commands

### Quick Health Check

```bash
# Check if binary exists
ls -la /usr/local/bin/DDMmacOSUpdateReminder

# Check version
/usr/local/bin/DDMmacOSUpdateReminder --version

# Check LaunchDaemon
launchctl list | grep ddmupdatereminder

# Check config profile
defaults read com.macjediwizard.ddmmacosupdatereminder ConfigVersion

# Check recent logs
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h
```

## Common Issues

### Issue: Reminder Not Appearing

**Symptoms**: LaunchDaemon runs but no dialog appears.

**Causes and Solutions**:

1. **No DDM enforcement detected**
   ```bash
   grep -i "software update" /var/log/install.log | tail -20
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
   defaults read com.macjediwizard.ddmmacosupdatereminder
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
   ls -la /Library/LaunchDaemons/com.macjediwizard.ddmmacosupdatereminder.plist
   ```

3. Check plist syntax:
   ```bash
   plutil -lint /Library/LaunchDaemons/com.macjediwizard.ddmmacosupdatereminder.plist
   ```

4. Run setup to create LaunchDaemon:
   ```bash
   sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder --setup
   ```

5. Manually load:
   ```bash
   sudo launchctl bootstrap system /Library/LaunchDaemons/com.macjediwizard.ddmmacosupdatereminder.plist
   ```

6. Check for errors:
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

2. Verify minimum version (should be 2.4.0+)

3. Test swiftDialog directly:
   ```bash
   /usr/local/bin/dialog --title "Test" --message "Hello" --button1text "OK"
   ```

4. If auto-install is enabled, check logs for download errors

5. Reinstall swiftDialog:
   ```bash
   # Download from https://github.com/swiftDialog/swiftDialog/releases
   ```

### Issue: Deferrals Not Tracking

**Symptoms**: Deferral count doesn't change or resets unexpectedly.

**Solutions**:

1. Check deferral file:
   ```bash
   /usr/libexec/PlistBuddy -c "Print" "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/deferral.plist"
   ```

2. Check permissions:
   ```bash
   ls -la "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/"
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
   log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND eventMessage CONTAINS "icon"' --last 1h
   ```

### Issue: Wrong Deadline Displayed

**Symptoms**: Deadline doesn't match MDM configuration.

**Solutions**:

1. Check install.log parsing:
   ```bash
   grep -i "software update" /var/log/install.log | tail -20
   ```

2. Verify machine received updated DDM policy

3. Check for multiple enforcement entries

### Issue: Health State Not Updating

**Symptoms**: Extension Attributes show stale data.

**Solutions**:

1. Verify `EnableHealthReporting` is true

2. Check health file permissions:
   ```bash
   ls -la "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/health.plist"
   ```

3. Read health file:
   ```bash
   /usr/libexec/PlistBuddy -c "Print" "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/health.plist"
   ```

4. Trigger inventory update in Jamf

## Log Analysis

### Find Startup Issues

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "preflight"' --last 24h
```

### Find Configuration Errors

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND (category == "config" OR messageType == error)' --last 24h
```

### Track User Behavior

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "userAction"' --last 7d
```

## Reset and Clean State

### Reset Deferrals

```bash
sudo rm "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/deferral.plist"
```

### Reset Health State

```bash
sudo rm "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/health.plist"
```

### Complete Reset

```bash
# Unload daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.macjediwizard.ddmmacosupdatereminder.plist

# Remove all state files
sudo rm -rf "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder"

# Reload daemon
sudo launchctl bootstrap system /Library/LaunchDaemons/com.macjediwizard.ddmmacosupdatereminder.plist
```

## Test Mode

Enable test mode for debugging:

1. Set in configuration profile:
   ```
   AdvancedSettings > TestMode: true
   AdvancedSettings > TestDaysRemaining: 5
   AdvancedSettings > VerboseLogging: true
   ```

2. Run manually:
   ```bash
   sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder --test
   ```

3. Stream logs in another terminal:
   ```bash
   log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --level debug
   ```

## Getting Help

If issues persist:

1. Collect logs using the predicates above
2. Note macOS version and hardware
3. Include configuration profile settings (sanitized)
4. Open issue on [GitHub](https://github.com/MacJediWizard/MacJediWizard-DDM-macOS-Update-Reminder/issues)
