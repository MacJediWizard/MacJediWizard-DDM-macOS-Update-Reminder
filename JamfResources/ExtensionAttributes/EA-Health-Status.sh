#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Health Status
# Reports the health status of DDM macOS Update Reminder
# Returns: Healthy, ConfigMissing, Error: <details>, or NotInstalled

# Preference domain - adjust if using custom domain
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Health state file path (in /Library/Application Support/{preferenceDomain}/)
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
LAST_RUN=$(/usr/libexec/PlistBuddy -c "Print :LastRunDate" "${HEALTH_FILE}" 2>/dev/null)

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
