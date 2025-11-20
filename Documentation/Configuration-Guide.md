# Configuration Guide

Complete guide to configuring DDM macOS Update Reminder via Jamf Configuration Profiles.

## Overview

All configuration is managed through Jamf Configuration Profiles using managed preferences. The binary reads these settings at runtime, allowing you to update configuration without redeploying the binary.

## Setting Up the Configuration Profile

### 1. Create Configuration Profile in Jamf Pro

1. Go to **Computers > Configuration Profiles**
2. Click **New**
3. Add payload: **Application & Custom Settings**
4. Select **External Applications** > **Add**
5. Choose **Custom Schema**
6. Set **Preference Domain** to: `com.macjediwizard.ddmupdatereminder`
7. Paste the contents of `JamfResources/ConfigurationProfile/com.macjediwizard.ddmupdatereminder.json`
8. Click **Add**
9. Configure your organization's settings using the Jamf Pro UI
10. Scope to target computers

### 2. Preference Domain

The default preference domain is:
```
com.macjediwizard.ddmupdatereminder
```

If using a custom domain, pass it as an argument when running the binary:
```bash
/usr/local/bin/DDMmacOSUpdateReminder --domain com.yourorg.ddmupdatereminder
```

## Configuration Sections

### Organization Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `ReverseDomainName` | String | `com.yourorg` | Your organization's reverse domain |
| `OrganizationName` | String | `Your Organization` | Human-readable name for logs |
| `ManagementDirectory` | String | `/Library/Application Support` | Base directory for data files |

Files are stored at `{ManagementDirectory}/{PreferenceDomain}/`:
- `health.plist` - Health state for Extension Attributes
- `deferral.plist` - Deferral tracking state

The Extension Attributes automatically read this setting from the Configuration Profile.

### Behavior Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `DaysBeforeDeadlineDisplayReminder` | Integer | `14` | Days before deadline to start reminders |
| `DaysBeforeDeadlineBlurscreen` | Integer | `3` | Days before deadline to enable blurscreen |
| `MeetingDelayMinutes` | Integer | `75` | Max minutes to wait for meetings |
| `MeetingCheckIntervalSeconds` | Integer | `300` | Seconds between meeting checks |
| `IgnoreAssertionsWithinHours` | Integer | `24` | Hours before deadline to ignore assertions |
| `RandomDelayMaxSeconds` | Integer | `1200` | Max random delay to stagger notifications |

### Deferral Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `MaxDeferrals` | Integer | `10` | Baseline maximum deferrals |
| `DeferralSchedule` | Array | See below | Deferrals by days remaining |
| `ResetOnNewDeadline` | Boolean | `true` | Reset count on new deadline |
| `SnoozeEnabled` | Boolean | `true` | Allow snooze option |
| `SnoozeMinutes` | Integer | `120` | Snooze duration |
| `ExhaustedBehavior` | String | `NoRemindButton` | Behavior when exhausted |
| `AutoOpenDelaySeconds` | Integer | `60` | Delay before auto-open |

#### Deferral Schedule

The deferral schedule reduces available deferrals as the deadline approaches:

```json
[
  { "DaysRemaining": 14, "MaxDeferrals": 10 },
  { "DaysRemaining": 7, "MaxDeferrals": 5 },
  { "DaysRemaining": 3, "MaxDeferrals": 2 },
  { "DaysRemaining": 1, "MaxDeferrals": 0 }
]
```

The system uses the first matching entry where `DaysRemaining >= actual days remaining`.

### Schedule Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `LaunchDaemonTimes` | Array | `[{9,0}, {14,0}]` | Run times (24-hour) |
| `RunAtLoad` | Boolean | `true` | Run at login/boot |
| `LoginDelaySeconds` | Integer | `60` | Delay after login |

### Branding Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `OverlayIconURL` | String | `""` | URL to overlay icon |
| `OverlayIconPath` | String | `""` | Local path to overlay icon |
| `MacOSIcons` | Object | See manifest | Icons per macOS version |

### Support Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `TeamName` | String | `IT Support` | Support team name |
| `Phone` | String | `""` | Support phone |
| `Email` | String | `""` | Support email |
| `Website` | String | `""` | Support website |
| `KBArticleID` | String | `""` | KB article ID |
| `KBArticleURL` | String | `""` | KB article URL |
| `TicketSystemURL` | String | `""` | Ticket system URL |

### Dialog Content

Customize all dialog text using message templates with variables.

| Key | Type | Description |
|-----|------|-------------|
| `TitleUpdate` | String | Title for minor updates |
| `TitleUpgrade` | String | Title for major upgrades |
| `Button1Text` | String | Primary button |
| `Button2Text` | String | Defer button |
| `MessageTemplate` | String | Main message |
| `MessageTemplateExhausted` | String | Message when exhausted |
| `InfoboxTemplate` | String | Sidebar info |
| `HelpMessageTemplate` | String | Help popup |

#### Line Breaks in Templates

**Important**: Jamf Pro's Custom Schema text fields strip newline characters. Use `\n` for line breaks in your templates:

```
**Title**\n\nFirst paragraph text.\n\nSecond paragraph text.
```

The binary automatically converts `\n` to actual line breaks. This applies to:
- `MessageTemplate`
- `MessageTemplateExhausted`
- `InfoboxTemplate`
- `HelpMessageTemplate`

#### Markdown Support

Templates support markdown formatting:
- `**bold**` for bold text
- `---` for horizontal rules
- `- item` for bullet lists

### Health Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `EnableHealthReporting` | Boolean | `true` | Write health state |
| `HealthStatePath` | String | `ddm-health.plist` | Health file name |
| `MaxErrorLogEntries` | Integer | `50` | Max errors to keep |

### Advanced Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `SwiftDialogMinVersion` | String | `2.4.0` | Min swiftDialog version |
| `SwiftDialogAutoInstall` | Boolean | `true` | Auto-install swiftDialog |
| `VerboseLogging` | Boolean | `false` | Debug logging |
| `TestMode` | Boolean | `false` | Test mode |
| `TestDaysRemaining` | Integer | `5` | Simulated days for testing |

## Message Template Variables

Use these variables in message templates:

### User Information
- `{userFirstName}` - First name
- `{userFullName}` - Full name
- `{userName}` - Username

### Computer Information
- `{computerName}` - Computer name
- `{serialNumber}` - Serial number
- `{installedVersion}` - Current macOS
- `{installedBuild}` - Current build

### Update Information
- `{targetVersion}` - Required version
- `{targetBuild}` - Required build
- `{action}` - "Update" or "Upgrade"
- `{actionLower}` - "update" or "upgrade"
- `{softwareUpdateButtonText}` - "Restart Now" or "Upgrade Now"

### Deadline Information
- `{deadlineFormatted}` - Human-readable deadline
- `{deadlineDate}` - Date only
- `{deadlineTime}` - Time only
- `{daysRemaining}` - Days until deadline
- `{hoursRemaining}` - Hours until deadline

### Deferral Information
- `{deferralsRemaining}` - Remaining deferrals
- `{deferralsUsed}` - Used deferrals
- `{maxDeferrals}` - Max at current threshold

### Date/Time
- `{dayOfWeek}` - Day name
- `{currentDate}` - Current date
- `{currentTime}` - Current time

### Button Text
- `{button1Text}` - Primary button text
- `{button2Text}` - Secondary button text

### Support Information
- `{supportTeamName}` - Team name
- `{supportPhone}` - Phone
- `{supportEmail}` - Email
- `{supportWebsite}` - Website
- `{supportKBArticleID}` - KB ID
- `{supportKBArticleURL}` - KB URL

### Other
- `{snoozeMinutes}` - Snooze duration

## Example Configurations

### Conservative (Minimal Disruption)

```json
{
  "DaysBeforeDeadlineDisplayReminder": 7,
  "DaysBeforeDeadlineBlurscreen": 1,
  "MaxDeferrals": 15,
  "MeetingDelayMinutes": 120,
  "LaunchDaemonTimes": [{"Hour": 10, "Minute": 0}]
}
```

### Aggressive (Maximum Compliance)

```json
{
  "DaysBeforeDeadlineDisplayReminder": 14,
  "DaysBeforeDeadlineBlurscreen": 5,
  "MaxDeferrals": 5,
  "MeetingDelayMinutes": 30,
  "LaunchDaemonTimes": [
    {"Hour": 9, "Minute": 0},
    {"Hour": 13, "Minute": 0},
    {"Hour": 16, "Minute": 0}
  ]
}
```

## Testing Configuration

1. Enable test mode in config:
   ```json
   {
     "TestMode": true,
     "TestDaysRemaining": 5,
     "VerboseLogging": true
   }
   ```

2. Run binary manually to verify dialog appears

3. Check unified logs:
   ```bash
   log stream --predicate 'subsystem == "com.macjediwizard.ddmmacosupdatereminder"' --level debug
   ```

4. Disable test mode for production
