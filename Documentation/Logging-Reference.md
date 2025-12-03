# Logging Reference

DDM macOS Update Reminder uses macOS Unified Logging for all output. This guide covers how to view and filter logs.

## Log Subsystem and Categories

**Subsystem**: `com.macjediwizard.ddmmacosupdatereminder`

> **Note**: Both the log subsystem and preference domain use `com.macjediwizard.ddmmacosupdatereminder`. This was unified in v1.1.0 (issue #36 resolved).

**Categories**:
- `preflight` - Startup and validation checks
- `config` - Configuration loading and parsing
- `ddmParsing` - Parsing `/var/log/install.log` for DDM data
- `deferral` - Deferral tracking and calculations
- `dialog` - swiftDialog interaction
- `userAction` - User button clicks and choices
- `health` - Health state updates
- `launchDaemon` - LaunchDaemon management
- `error` - Error conditions

## Basic Log Commands

### View Recent Logs

```bash
# Last hour
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h

# Last 24 hours
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 24h

# Last 7 days
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 7d
```

### Real-Time Streaming

```bash
# Stream all logs
log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"'

# Stream with debug level
log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --level debug

# Stream info level and above
log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --level info
```

## Filtering by Category

### Configuration Issues

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "config"' --last 24h
```

### User Actions

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "userAction"' --last 7d
```

### Deferral Tracking

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "deferral"' --last 24h
```

### Errors Only

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND messageType == error' --last 7d
```

### Errors and Faults

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND (messageType == error OR messageType == fault)' --last 7d
```

## Advanced Predicates

### Multiple Categories

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND (category == "userAction" OR category == "deferral")' --last 7d
```

### Text Search

```bash
# Messages containing "deadline"
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND eventMessage CONTAINS "deadline"' --last 24h

# Case-insensitive search
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND eventMessage CONTAINS[c] "error"' --last 24h
```

### Time Range

```bash
# Specific date range
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --start "2025-11-01 00:00:00" --end "2025-11-15 23:59:59"
```

### Process-Specific

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND process == "DDMmacOSUpdateReminder"' --last 24h
```

## Output Formats

### Compact (Default)

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h --style compact
```

### JSON Export

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 7d --style json > ddm-logs.json
```

### Syslog Format

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 1h --style syslog
```

## Common Troubleshooting Queries

### Why Didn't Reminder Appear?

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND (category == "preflight" OR category == "config" OR category == "ddmParsing")' --last 24h
```

### Check Meeting Detection

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND eventMessage CONTAINS "assertion"' --last 24h
```

### Track Deferral Usage

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "deferral"' --last 7d | grep -E "used|remaining|exhausted"
```

### LaunchDaemon Issues

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "launchDaemon"' --last 24h
```

### swiftDialog Problems

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder" AND category == "dialog"' --last 24h
```

## Log Collection Script

Create a script to collect logs for support:

```bash
#!/bin/zsh
# Collect DDM Update Reminder logs for support

OUTPUT_DIR="/tmp/ddm-logs"
mkdir -p "${OUTPUT_DIR}"

SUBSYSTEM="com.macjediwizard.ddmmacosupdatereminder"

# Recent logs (JSON)
log show --predicate "subsystem == '${SUBSYSTEM}'" --last 7d --style json > "${OUTPUT_DIR}/all-logs.json"

# Errors only
log show --predicate "subsystem == '${SUBSYSTEM}' AND messageType == error" --last 7d > "${OUTPUT_DIR}/errors.log"

# User actions
log show --predicate "subsystem == '${SUBSYSTEM}' AND category == 'userAction'" --last 30d > "${OUTPUT_DIR}/user-actions.log"

# Health state
HEALTH_FILE="/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/health.plist"
if [[ -f "${HEALTH_FILE}" ]]; then
    cp "${HEALTH_FILE}" "${OUTPUT_DIR}/health-state.plist"
fi

# Deferral state
DEFERRAL_FILE="/Library/Application Support/com.macjediwizard.ddmmacosupdatereminder/deferral.plist"
if [[ -f "${DEFERRAL_FILE}" ]]; then
    cp "${DEFERRAL_FILE}" "${OUTPUT_DIR}/deferral-state.plist"
fi

# System info
sw_vers > "${OUTPUT_DIR}/system-info.txt"
echo "" >> "${OUTPUT_DIR}/system-info.txt"
system_profiler SPHardwareDataType >> "${OUTPUT_DIR}/system-info.txt"

# Package
ARCHIVE="/tmp/ddm-logs-$(date +%Y%m%d-%H%M%S).zip"
cd /tmp && zip -r "${ARCHIVE}" ddm-logs

echo "Logs collected: ${ARCHIVE}"
```

## Verbose Logging

Enable verbose logging for troubleshooting:

1. Set `VerboseLogging` to `true` in config profile
2. Logs will include debug-level messages
3. Remember to disable for production

## Log Retention

macOS Unified Logging retention varies:
- Default: ~7 days for most logs
- Longer for certain log types

For long-term retention, export logs regularly:

```bash
log show --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --last 7d --style json >> /path/to/archive/ddm-$(date +%Y%m%d).json
```
