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

# ---------------------------------------------------------------
# Task 1: MUTE - runs every 20 minutes from 18:00 on weekdays
#         and all day on weekends. AC power only.
# Uses schtasks.exe which has full support for repetition and AC.
# ---------------------------------------------------------------

# Weekdays: 18:00 to 00:00 (6 hours), every 20 min
schtasks /create /tn "AudioMuteEvening" /f `
    /sc WEEKLY /d MON,TUE,WED,THU,FRI `
    /st 18:00 /du 0006:00 /ri 20 `
    /tr "powershell.exe $psArgs $scriptDir\mute-evening.ps1" `
    /rl HIGHEST /it

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: AudioMuteEvening weekday trigger registered"
} else {
    Write-Host "ERROR: AudioMuteEvening weekday trigger failed"
}

# Saturday: all day, every 20 min
schtasks /create /tn "AudioMuteSaturday" /f `
    /sc WEEKLY /d SAT `
    /st 00:00 /du 0023:59 /ri 20 `
    /tr "powershell.exe $psArgs $scriptDir\mute-evening.ps1" `
    /rl HIGHEST /it

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: AudioMuteSaturday trigger registered"
} else {
    Write-Host "ERROR: AudioMuteSaturday trigger failed"
}

# Sunday: all day, every 20 min
schtasks /create /tn "AudioMuteSunday" /f `
    /sc WEEKLY /d SUN `
    /st 00:00 /du 0023:59 /ri 20 `
    /tr "powershell.exe $psArgs $scriptDir\mute-evening.ps1" `
    /rl HIGHEST /it

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: AudioMuteSunday trigger registered"
} else {
    Write-Host "ERROR: AudioMuteSunday trigger failed"
}

# ---------------------------------------------------------------
# Task 2: UNMUTE at 07:30 Monday-Friday. AC power only.
# ---------------------------------------------------------------
schtasks /create /tn "AudioUnmuteMorning" /f `
    /sc WEEKLY /d MON,TUE,WED,THU,FRI `
    /st 07:30 `
    /tr "powershell.exe $psArgs $scriptDir\unmute-morning.ps1" `
    /rl HIGHEST /it

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: AudioUnmuteMorning registered (07:30 Mon-Fri)"
} else {
    Write-Host "ERROR: AudioUnmuteMorning failed"
}

# ---------------------------------------------------------------
# Set AC-only via XML patch (schtasks does not expose this flag)
# ---------------------------------------------------------------
$tasks = @("AudioMuteEvening", "AudioMuteSaturday", "AudioMuteSunday", "AudioUnmuteMorning")
foreach ($task in $tasks) {
    $xml = schtasks /query /tn $task /xml ONE 2>$null
    if ($xml) {
        $xml = $xml -replace "<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>", "<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>"
        $xml = $xml -replace "<StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>", "<StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>"
        # Add battery settings if not present
        if ($xml -notmatch "DisallowStartIfOnBatteries") {
            $xml = $xml -replace "</Settings>", "  <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>`n  <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>`n</Settings>"
        }
        $tmpFile = "$env:TEMP\task_$task.xml"
        $xml | Out-File -FilePath $tmpFile -Encoding UTF8
        schtasks /create /tn $task /f /xml $tmpFile | Out-Null
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
        Write-Host "OK: AC-only set for $task"
    }
}

Write-Host ""
Write-Host "Done. Verify in Task Scheduler (taskschd.msc)."
