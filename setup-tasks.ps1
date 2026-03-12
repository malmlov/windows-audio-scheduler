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

# Task 1: MUTE at 18:00 every day
$action1  = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "$psArgs $scriptDir\mute-evening.ps1"
$trigger1 = New-ScheduledTaskTrigger -Daily -At "18:00"
$settings1 = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
                -StartWhenAvailable

Register-ScheduledTask -TaskName "AudioMuteEvening" `
    -Action $action1 -Trigger $trigger1 -Settings $settings1 `
    -RunLevel Highest -Force | Out-Null

Write-Host "OK: AudioMuteEvening registered (18:00 daily)"

# Task 2: UNMUTE at 07:30 Monday-Friday
$action2  = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "$psArgs $scriptDir\unmute-morning.ps1"
$trigger2 = New-ScheduledTaskTrigger -Weekly `
                -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "07:30"
$settings2 = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
                -StartWhenAvailable

Register-ScheduledTask -TaskName "AudioUnmuteMorning" `
    -Action $action2 -Trigger $trigger2 -Settings $settings2 `
    -RunLevel Highest -Force | Out-Null

Write-Host "OK: AudioUnmuteMorning registered (07:30 Mon-Fri)"
Write-Host ""
Write-Host "Done. Verify in Task Scheduler (taskschd.msc)."
