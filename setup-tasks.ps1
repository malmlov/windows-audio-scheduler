# setup-tasks.ps1
# Kör detta EN GÅNG som administratör för att registrera de schemalagda uppgifterna
# Högerklicka på PowerShell -> "Kör som administratör"

$scriptDir = "C:\Scripts"

# ── Kontrollera att skriptmappen finns ─────────────────────────────────────
if (-not (Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir | Out-Null
    Write-Host "Skapade mapp: $scriptDir"
}

# ── Kontrollera att skripten finns på plats ────────────────────────────────
foreach ($file in @("mute-evening.ps1", "unmute-morning.ps1")) {
    if (-not (Test-Path "$scriptDir\$file")) {
        Write-Warning "Saknas: $scriptDir\$file — kopiera dit skriptet innan du fortsätter."
        exit 1
    }
}

$psArgs = "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File"

# ── Uppgift 1: MUTE kl 18:00 varje dag ────────────────────────────────────
$action1  = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "$psArgs $scriptDir\mute-evening.ps1"
$trigger1 = New-ScheduledTaskTrigger -Daily -At "18:00"
$settings1 = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
                -StartWhenAvailable

Register-ScheduledTask -TaskName "AudioMuteEvening" `
    -Action $action1 -Trigger $trigger1 -Settings $settings1 `
    -RunLevel Highest -Force | Out-Null

Write-Host "✓ Registrerad: AudioMuteEvening (kl 18:00 varje dag)"

# ── Uppgift 2: UNMUTE kl 07:30 måndag–fredag ──────────────────────────────
$action2  = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "$psArgs $scriptDir\unmute-morning.ps1"
$trigger2 = New-ScheduledTaskTrigger -Weekly `
                -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "07:30"
$settings2 = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
                -StartWhenAvailable

Register-ScheduledTask -TaskName "AudioUnmuteMorning" `
    -Action $action2 -Trigger $trigger2 -Settings $settings2 `
    -RunLevel Highest -Force | Out-Null

Write-Host "✓ Registrerad: AudioUnmuteMorning (kl 07:30 mån–fre)"
Write-Host ""
Write-Host "Klart! Verifiera i Task Scheduler (taskschd.msc)."
