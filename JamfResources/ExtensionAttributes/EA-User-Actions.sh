#!/bin/zsh
# Extension Attribute: DDM Update Reminder - User Actions
# Reports recent user actions (button clicks) from unified logging
# Returns: Last 5 actions or "None"

# Subsystem for unified logging - adjust if using custom domain
SUBSYSTEM="com.macjediwizard.ddmupdatereminder"

# Query unified log for user actions from last 7 days
ACTIONS=$(log show --predicate "subsystem == '${SUBSYSTEM}' AND category == 'userAction'" --last 7d --style compact 2>/dev/null | grep -E "clicked|deferred|snoozed" | tail -n 5)

if [[ -n "${ACTIONS}" ]]; then
    # Format output: extract timestamp and action
    FORMATTED=""
    while IFS= read -r line; do
        # Extract date and message
        TIMESTAMP=$(echo "${line}" | awk '{print $1, $2}' | cut -d'.' -f1)
        MESSAGE=$(echo "${line}" | sed 's/.*\] //')
        if [[ -n "${FORMATTED}" ]]; then
            FORMATTED="${FORMATTED}
${TIMESTAMP}: ${MESSAGE}"
        else
            FORMATTED="${TIMESTAMP}: ${MESSAGE}"
        fi
    done <<< "${ACTIONS}"

    echo "<result>${FORMATTED}</result>"
else
    echo "<result>None</result>"
fi
