#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Last Run Status
# Reports the last run status with timestamp
# Returns: Status with date, or "NotInstalled"

# Preference domain - adjust if using custom domain
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Health state file path (in /Library/Application Support/{preferenceDomain}/)
HEALTH_FILE="/Library/Application Support/${PREF_DOMAIN}/health.plist"

# Check if health file exists
if [[ ! -f "${HEALTH_FILE}" ]]; then
    echo "<result>NotInstalled</result>"
    exit 0
fi

# Read last run info
LAST_STATUS=$(/usr/libexec/PlistBuddy -c "Print :LastRunStatus" "${HEALTH_FILE}" 2>/dev/null)
LAST_RUN=$(/usr/libexec/PlistBuddy -c "Print :LastRunDate" "${HEALTH_FILE}" 2>/dev/null)
LAST_ACTION=$(/usr/libexec/PlistBuddy -c "Print :LastUserAction" "${HEALTH_FILE}" 2>/dev/null)

if [[ -n "${LAST_STATUS}" ]] && [[ -n "${LAST_RUN}" ]]; then
    # Format date for readability
    FORMATTED_DATE=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${LAST_RUN}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "${LAST_RUN}")

    if [[ -n "${LAST_ACTION}" ]] && [[ "${LAST_ACTION}" != "None" ]]; then
        echo "<result>${LAST_STATUS} - ${FORMATTED_DATE} (${LAST_ACTION})</result>"
    else
        echo "<result>${LAST_STATUS} - ${FORMATTED_DATE}</result>"
    fi
else
    echo "<result>No data</result>"
fi
