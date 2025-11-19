#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Enforcement Deadline
# Reports the current DDM enforcement deadline
# Returns: Deadline date/time, "None", or "NotInstalled"

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
    # Try to read directly from install.log as fallback
    ddmLogEntry=$(grep "EnforcedInstallDate" /var/log/install.log 2>/dev/null | tail -n 1)
    if [[ -n "${ddmLogEntry}" ]]; then
        DEADLINE="${${ddmLogEntry##*|EnforcedInstallDate:}%%|*}"
        DEADLINE_FORMATTED=$(date -jf "%Y-%m-%dT%H:%M:%S" "${DEADLINE%%Z}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "${DEADLINE}")
        echo "<result>${DEADLINE_FORMATTED}</result>"
    else
        echo "<result>None</result>"
    fi
    exit 0
fi

# Read deadline from health state
DEADLINE=$(/usr/libexec/PlistBuddy -c "Print :CurrentEnforcementDeadline" "${HEALTH_FILE}" 2>/dev/null)
TARGET_VERSION=$(/usr/libexec/PlistBuddy -c "Print :TargetVersion" "${HEALTH_FILE}" 2>/dev/null)

if [[ -n "${DEADLINE}" ]] && [[ "${DEADLINE}" != "None" ]]; then
    # Format date for readability
    FORMATTED_DATE=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${DEADLINE}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "${DEADLINE}")

    if [[ -n "${TARGET_VERSION}" ]]; then
        echo "<result>${TARGET_VERSION} - ${FORMATTED_DATE}</result>"
    else
        echo "<result>${FORMATTED_DATE}</result>"
    fi
else
    echo "<result>None</result>"
fi
