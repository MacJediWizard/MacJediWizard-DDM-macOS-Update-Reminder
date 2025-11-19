#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Last Run Status
# Reports the last run status with timestamp
# Returns: Status with date, or "NotInstalled"

# Preference domain - adjust if using custom domain
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Get management directory from config, default if not set
MGMT_DIR=$(defaults read "${PREF_DOMAIN}" OrganizationSettings 2>/dev/null | grep ManagementDirectory | awk -F'"' '{print $2}')
MGMT_DIR="${MGMT_DIR:-/Library/Management}"

# Get reverse domain from config
REV_DOMAIN=$(defaults read "${PREF_DOMAIN}" OrganizationSettings 2>/dev/null | grep ReverseDomainName | awk -F'"' '{print $2}')
REV_DOMAIN="${REV_DOMAIN:-com.yourorg}"

# Health state file path
HEALTH_FILE="${MGMT_DIR}/${REV_DOMAIN}/ddm-health.plist"

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
