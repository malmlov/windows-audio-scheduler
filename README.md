# Windows Audio Scheduler

Automatically mutes and unmutes system audio on a schedule using PowerShell and Windows Task Scheduler. No third-party tools required — uses the native Windows Core Audio API directly.

## Behavior

| Situation | Action |
|---|---|
| Weekday after 18:00, idle >= 10 min | Mute |
| Weekday after 18:00, PC locked | Mute |
| Weekday after 18:00, actively working | Skip (check again in 20 min) |
| You unmute manually, then go idle | Mute again after 10 min |
| Weekend (all day), idle >= 10 min | Mute |
| Weekday 07:30 | Unmute |
| Running on battery | Tasks do not run |

Manual adjustments via the Windows tray volume control are always respected — the schedule only kicks in at the next 20-minute check.

## Files

| File | Description |
|---|---|
| `mute-evening.ps1` | Mutes audio if PC is locked or idle >= 10 min |
| `unmute-morning.ps1` | Unmutes audio at 07:30 on weekdays |
| `setup-tasks.ps1` | Registers both tasks in Windows Task Scheduler |

## Requirements

- Windows 10 or 11
- PowerShell 5.1 or later (included in Windows)
- Admin rights required only for `setup-tasks.ps1`

## Installation

1. Copy all three `.ps1` files to `C:\Scripts\`
2. Right-click PowerShell -> **Run as Administrator**
3. Run:
```powershell
powershell -ExecutionPolicy Bypass -File C:\Scripts\setup-tasks.ps1
```
4. Verify in Task Scheduler (`taskschd.msc`) that both tasks appear

## Configuration

### Change idle threshold (default: 10 minutes)
Edit `mute-evening.ps1`:
```powershell
if ($locked -or $idleMinutes -ge 10) {
```

### Change mute start time (default: 18:00)
Edit `setup-tasks.ps1`:
```powershell
$weekdayTrigger = New-ScheduledTaskTrigger -Weekly `
    -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "18:00"
```

### Change unmute time (default: 07:30)
Edit `setup-tasks.ps1`:
```powershell
$trigger2 = New-ScheduledTaskTrigger -Weekly `
    -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "07:30"
```

### Change check interval (default: every 20 minutes)
Edit both repetition lines in `setup-tasks.ps1`:
```powershell
$weekdayTrigger.RepetitionInterval = "PT20M"   # PT20M = 20 min, PT10M = 10 min
```

### Re-apply after changes
Re-run `setup-tasks.ps1` as Administrator. The `-Force` flag overwrites existing tasks cleanly.

## How It Works

**Audio control** uses the Windows Core Audio API (`IAudioEndpointVolume`) via COM interop embedded as inline C# in PowerShell. Calls `SetMute(true/false)` explicitly — not a toggle.

**Idle detection** calls `GetLastInputInfo` from `user32.dll`, returning the timestamp of the last mouse or keyboard input.

**Lock detection** checks whether `LogonUI.exe` is running, which Windows starts when the screen is locked.

**AC power only** — tasks are configured with `DisallowStartIfOnBatteries` and `StopIfGoingOnBatteries`, so they never run on battery.

## License

MIT
