# Test Plan

Comprehensive testing guide for DDM macOS Update Reminder.

## Test Matrix

### Hardware Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Apple Silicon (M1/M2/M3) | Required | Primary target |
| Intel | Required | Legacy support |

### macOS Versions

| Version | Status | Notes |
|---------|--------|-------|
| macOS 12 (Monterey) | Required | Minimum supported |
| macOS 13 (Ventura) | Required | |
| macOS 14 (Sonoma) | Required | |
| macOS 15 (Sequoia) | Required | Current release |

## Scenario Tests

### 1. No DDM Enforcement

**Setup**: Machine with no DDM OS update policy

**Test Steps**:
```bash
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder
```

**Expected Result**:
- No dialog displayed
- Log shows "No DDM enforcement found"
- Health state shows `lastRunStatus: "NoEnforcementFound"`

---

### 2. DDM Enforcement - Future Deadline

**Setup**: DDM enforcement with deadline 7+ days away

**Test Steps**:
```bash
# Verify enforcement exists
grep -i "software update" /var/log/install.log | tail -5

# Run tool
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder
```

**Expected Result**:
- Dialog appears with correct deadline date
- Days remaining matches actual deadline
- "Remind Me Later" button available (if deferrals remain)
- Snooze option available

---

### 3. DDM Enforcement - Past Deadline

**Setup**: DDM enforcement with deadline already passed

**Test Steps**:
```bash
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder
```

**Expected Result**:
- Dialog shows 0 days remaining
- Blurscreen enabled (if configured)
- No deferral options available
- Forced update behavior

---

### 4. Minor Update Required

**Setup**: Current: 15.0, Required: 15.1

**Test Steps**:
```bash
# Use test mode to simulate
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder --test
```

**Expected Result**:
- Dialog shows "Update Required"
- Message uses update templates (not upgrade)
- Update button opens Software Update preference pane

---

### 5. Major Upgrade Required

**Setup**: Current: 14.x, Required: 15.x

**Expected Result**:
- Dialog shows "Upgrade Required"
- Message uses upgrade templates
- Different messaging for major version change

---

### 6. All Deferrals Used

**Setup**: Exhaust all available deferrals

**Test Steps**:
```bash
# Check current deferrals
cat "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/deferral.plist"

# Manually set high deferral count to test exhaustion
sudo /usr/libexec/PlistBuddy -c "Set :deferralCount 10" "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/deferral.plist"
```

**Expected Result (NoRemindButton behavior)**:
- "Remind Me Later" button hidden
- Only Update/Snooze options available

**Expected Result (AutoOpenUpdate behavior)**:
- Countdown timer displayed
- Auto-opens Software Update when timer expires

---

### 7. Snooze Active

**Setup**: User previously snoozed

**Test Steps**:
```bash
# Set snooze in deferral file
sudo /usr/libexec/PlistBuddy -c "Set :snoozeUntil $(date -v+1H +%Y-%m-%dT%H:%M:%SZ)" "/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/deferral.plist"

# Run tool
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder
```

**Expected Result**:
- No dialog displayed
- Log shows "Snooze active until..."
- Health state shows `lastRunStatus: "SnoozeActive"`

---

### 8. Meeting/Presentation in Progress

**Setup**: Screen sharing or video call active

**Test Steps**:
```bash
# Start a screen sharing session or video call
# Then run:
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder

# Check assertions
pmset -g assertions
```

**Expected Result**:
- No dialog displayed during meeting
- Log shows "Meeting detected, delaying..."
- Tool reschedules for later

---

### 9. Test Mode

**Setup**: Enable test mode

**Test Steps**:
```bash
# Via command line
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder --test

# Or set TestMode: true in configuration profile
```

**Expected Result**:
- Skips meeting/assertion detection
- Uses TestDaysRemaining value
- Skips actual DDM parsing
- Dialog appears immediately

---

### 10. Missing Configuration Profile

**Setup**: Remove or don't deploy configuration profile

**Test Steps**:
```bash
# Verify no profile
defaults read com.macjediwizard.ddmmacosupdatereminder 2>&1

# Run tool
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder
```

**Expected Result**:
- Tool exits with error
- Log shows "Configuration profile not found"
- Health state shows `lastRunStatus: "ConfigMissing"`
- Structured error code: 100 (ConfigMissing)

---

### 11. Invalid Configuration Values

**Setup**: Deploy profile with out-of-range values

**Configuration**:
```xml
<key>BehaviorSettings</key>
<dict>
    <key>DaysBeforeDeadlineDisplayReminder</key>
    <integer>100</integer>  <!-- Max is 30 -->
    <key>MeetingDelayMinutes</key>
    <integer>-5</integer>   <!-- Min is 0 -->
</dict>
```

**Expected Result**:
- Values clamped to valid ranges
- Log shows warning about clamped values
- Tool continues with safe defaults
- DaysBeforeDeadlineDisplayReminder = 30 (max)
- MeetingDelayMinutes = 0 (min)

---

### 12. swiftDialog Missing

**Setup**: swiftDialog not installed

**Test Steps**:
```bash
# Temporarily rename dialog
sudo mv /usr/local/bin/dialog /usr/local/bin/dialog.bak

# Run tool
sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder

# Restore
sudo mv /usr/local/bin/dialog.bak /usr/local/bin/dialog
```

**Expected Result (AutoInstall disabled)**:
- Tool exits with error
- Log shows "swiftDialog not installed"
- Health state shows error code 200

**Expected Result (AutoInstall enabled)**:
- Tool attempts download from GitHub
- Rate limiting prevents repeated failures
- Checksum verification on download

---

### 13. Multiple Scheduled Runs

**Setup**: LaunchDaemon with multiple StartCalendarInterval entries

**Test Steps**:
```bash
# Check daemon schedule
cat /Library/LaunchDaemons/com.macjediwizard.ddmmacosupdatereminder.plist

# Monitor runs
log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"'
```

**Expected Result**:
- Tool runs at each scheduled time
- Random delay applied if configured
- State persists between runs

---

### 14. Icon/Banner Download Failures

**Setup**: Network issues or invalid URLs

**Test Steps**:
```bash
# Set invalid icon URL in configuration
# Run tool and observe retry behavior
```

**Expected Result**:
- Retry up to 3 times with exponential backoff
- Falls back to default icon on failure
- Logs download errors
- Tool continues without icon

---

### 15. Version Mismatch Detection

**Setup**: Binary 1.2.0 with config version 2.0.0

**Expected Result**:
- Warning logged about version mismatch
- Tool continues with available configuration
- Health state records version info

---

## Extension Attribute Verification

### EA-Health-Status.sh

**Test Steps**:
```bash
# Run EA script manually
sudo /path/to/EA-Health-Status.sh
```

**Expected Output Format**:
```xml
<result>OK|ERROR_COUNT:0|LAST_ERROR:None</result>
```

---

### EA-Deferrals-Remaining.sh

**Test Steps**:
```bash
sudo /path/to/EA-Deferrals-Remaining.sh
```

**Expected Output**:
```xml
<result>5</result>
```

---

### EA-Last-Run-Status.sh

**Test Steps**:
```bash
sudo /path/to/EA-Last-Run-Status.sh
```

**Expected Output**:
```xml
<result>DialogShown|UserDeferred|2025-01-15T10:30:00Z</result>
```

---

### EA-Enforcement-Deadline.sh

**Test Steps**:
```bash
sudo /path/to/EA-Enforcement-Deadline.sh
```

**Expected Output**:
```xml
<result>2025-01-20T09:00:00Z|5 days remaining</result>
```

---

## Logging Verification

### Categories to Verify

```bash
# All categories
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h

# Specific categories
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "preflight"' --last 1h
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "config"' --last 1h
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "ddmParser"' --last 1h
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "dialog"' --last 1h
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "userAction"' --last 1h
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "health"' --last 1h
```

### Verbose Logging

```bash
# Enable VerboseLogging in config, then:
log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --level debug
```

---

## Unit Tests

### Running Tests

```bash
cd /path/to/project
swift test
```

### Test Coverage

| Module | Tests | Status |
|--------|-------|--------|
| Configuration bounds checking | ConfigurationTests.swift | Implemented |
| DDM Parser version comparison | DDMParserTests.swift | Implemented |
| URL validation security | URLValidationTests.swift | Implemented |

---

## Performance Testing

### Memory Usage

```bash
# Monitor during dialog display
top -pid $(pgrep -f DDMmacOSUpdateReminder)
```

**Expected**: < 50MB memory usage

### Startup Time

```bash
time sudo /usr/local/bin/DDMmacOSUpdateReminder --domain com.macjediwizard.ddmmacosupdatereminder --test
```

**Expected**: < 2 seconds to dialog display

---

## Edge Case Testing

### 1. Leap Year Handling
- Test deadline calculations around Feb 29

### 2. Timezone Changes
- Test during DST transitions

### 3. Date Rollover
- Test at midnight

### 4. Very Long Strings
- Test with maximum length message templates

### 5. Special Characters
- Test template variables with special characters

### 6. Concurrent Runs
- Test multiple simultaneous executions

---

## Acceptance Criteria

- [ ] All scenario tests pass on Apple Silicon
- [ ] All scenario tests pass on Intel
- [ ] All scenario tests pass on macOS 12+
- [ ] No crashes or hangs in any scenario
- [ ] All error conditions handled gracefully
- [ ] Logs are informative and structured
- [ ] Extension Attributes return expected values
- [ ] Unit tests pass
- [ ] Memory usage within limits
- [ ] Startup time within limits

---

## Test Reporting

### Template

```
Test Date: YYYY-MM-DD
Tester: [Name]
Hardware: [Apple Silicon/Intel]
macOS Version: [Version]
Binary Version: [Version]

| Scenario | Result | Notes |
|----------|--------|-------|
| 1. No DDM Enforcement | PASS/FAIL | |
| 2. Future Deadline | PASS/FAIL | |
| ... | | |

Issues Found:
- [Description]

Overall Status: PASS/FAIL
```
