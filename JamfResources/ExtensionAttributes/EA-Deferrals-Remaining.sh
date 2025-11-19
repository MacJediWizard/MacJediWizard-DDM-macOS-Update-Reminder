#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Deferrals Remaining
# Reports the number of deferrals remaining for the user
# Returns: Number, "N/A" if no active enforcement, or "NotInstalled"

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

# Read deferrals remaining
DEFERRALS=$(/usr/libexec/PlistBuddy -c "Print :DeferralsRemaining" "${HEALTH_FILE}" 2>/dev/null)
MAX_DEFERRALS=$(/usr/libexec/PlistBuddy -c "Print :MaxDeferralsAtThreshold" "${HEALTH_FILE}" 2>/dev/null)

if [[ -n "${DEFERRALS}" ]] && [[ "${DEFERRALS}" != "-1" ]]; then
    if [[ -n "${MAX_DEFERRALS}" ]]; then
        echo "<result>${DEFERRALS} of ${MAX_DEFERRALS}</result>"
    else
        echo "<result>${DEFERRALS}</result>"
    fi
else
    echo "<result>N/A</result>"
fi
