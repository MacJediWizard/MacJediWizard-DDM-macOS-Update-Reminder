#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Last Run Status
# Reports the last run status with timestamp
# Returns: Status with date, or "NotInstalled"

# Preference domain - adjust if using custom domain
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Managed preferences file path
MANAGED_PREFS="/Library/Managed Preferences/${PREF_DOMAIN}.plist"

# Get ManagementDirectory from config (default: /Library/Application Support)
MGMT_DIR=$(/usr/libexec/PlistBuddy -c "Print :ManagementDirectory" "${MANAGED_PREFS}" 2>/dev/null)
if [[ -z "${MGMT_DIR}" ]]; then
    MGMT_DIR="/Library/Application Support"
fi

# Health state file path
HEALTH_FILE="${MGMT_DIR}/${PREF_DOMAIN}/health.plist"

# Check if health file exists
if [[ ! -f "${HEALTH_FILE}" ]]; then
    echo "<result>NotInstalled</result>"
    exit 0
fi

# Read last run info
LAST_STATUS=$(/usr/libexec/PlistBuddy -c "Print :lastRunStatus" "${HEALTH_FILE}" 2>/dev/null)
LAST_RUN=$(/usr/libexec/PlistBuddy -c "Print :lastRunDate" "${HEALTH_FILE}" 2>/dev/null)
LAST_ACTION=$(/usr/libexec/PlistBuddy -c "Print :lastUserAction" "${HEALTH_FILE}" 2>/dev/null)

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
