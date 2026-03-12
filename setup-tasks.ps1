# setup-tasks.ps1
# Run once as Administrator to register scheduled tasks.
# Right-click PowerShell -> "Run as Administrator"

$scriptDir = "C:\Scripts"
$psArgs = "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File"

# Check that scripts exist
foreach ($file in @("mute-evening.ps1", "unmute-morning.ps1")) {
    if (-not (Test-Path "$scriptDir\$file")) {
        Write-Host "Missing: $scriptDir\$file - copy the file before continuing."
        exit 1
    }
}

# Settings: only run on AC power (not battery)
$acOnly = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable `
    -DisallowStartIfOnBatteries `
    -StopIfGoingOnBatteries

# ---------------------------------------------------------------
# Task 1: MUTE - runs every 20 minutes from 18:00 on weekdays
# ---------------------------------------------------------------
$action1 = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument "$psArgs $scriptDir\mute-evening.ps1"

# Weekday trigger: 18:00, repeat every 20 min until midnight
$weekdayTrigger = New-ScheduledTaskTrigger -Weekly `
    -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "18:00"
$weekdayTrigger.RepetitionInterval = "PT20M"
$weekdayTrigger.RepetitionDuration = "PT6H"   # 18:00 -> 00:00

# Weekend trigger: 00:00, repeat every 20 min all day
$saturdayTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At "00:00"
$saturdayTrigger.RepetitionInterval = "PT20M"
$saturdayTrigger.RepetitionDuration = "P1D"   # all day

$sundayTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "00:00"
$sundayTrigger.RepetitionInterval = "PT20M"
$sundayTrigger.RepetitionDuration = "P1D"     # all day

Register-ScheduledTask -TaskName "AudioMuteEvening" `
    -Action $action1 `
    -Trigger @($weekdayTrigger, $saturdayTrigger, $sundayTrigger) `
    -Settings $acOnly `
    -RunLevel Highest -Force | Out-Null

Write-Host "OK: AudioMuteEvening registered (weekdays 18:00+, weekends all day, every 20 min, AC only)"

# ---------------------------------------------------------------
# Task 2: UNMUTE at 07:30 Monday-Friday
# ---------------------------------------------------------------
$action2 = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument "$psArgs $scriptDir\unmute-morning.ps1"

$trigger2 = New-ScheduledTaskTrigger -Weekly `
    -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "07:30"

Register-ScheduledTask -TaskName "AudioUnmuteMorning" `
    -Action $action2 -Trigger $trigger2 -Settings $acOnly `
    -RunLevel Highest -Force | Out-Null

Write-Host "OK: AudioUnmuteMorning registered (07:30 Mon-Fri, AC only)"
Write-Host ""
Write-Host "Done. Verify in Task Scheduler (taskschd.msc)."
