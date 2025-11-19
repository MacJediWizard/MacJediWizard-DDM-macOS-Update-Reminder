#!/bin/zsh
# Extension Attribute: DDM Update Reminder - Deferrals Remaining
# Reports the number of deferrals remaining for the user
# Returns: Number, "N/A" if no active enforcement, or "NotInstalled"

# Preference domain - adjust if using custom domain
PREF_DOMAIN="com.macjediwizard.ddmupdatereminder"

# Health state file path (in /Library/Application Support/{preferenceDomain}/)
HEALTH_FILE="/Library/Application Support/${PREF_DOMAIN}/health.plist"

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
