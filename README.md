# Windows Audio Scheduler

Automatically mutes and unmutes system audio on a schedule using PowerShell and Windows Task Scheduler. No third-party tools required — uses the native Windows Core Audio API directly.

## Behavior

| Time | Condition | Action |
|---|---|---|
| 18:00 (daily) | PC is locked | → Mute |
| 18:00 (daily) | Idle ≥ 10 minutes | → Mute |
| 18:00 (daily) | User is active | → Do nothing |
| 07:30 (Mon–Fri) | — | → Unmute |
| Weekend | — | Audio stays muted |

Manual adjustments via the Windows tray volume control are always respected — the schedule only kicks in at the next scheduled run.

## Files

| File | Description |
|---|---|
| `mute-evening.ps1` | Mutes audio at 18:00 if PC is locked or idle |
| `unmute-morning.ps1` | Unmutes audio at 07:30 on weekdays |
| `setup-tasks.ps1` | Registers both tasks in Windows Task Scheduler |

## Requirements

- Windows 10 or 11
- PowerShell 5.1 or later (included in Windows)
- No admin rights needed to run the audio scripts themselves — only `setup-tasks.ps1` requires admin

## Installation

1. Copy all three `.ps1` files to `C:\Scripts\`
2. Right-click `setup-tasks.ps1` → **Run with PowerShell as Administrator**
3. Verify in Task Scheduler (`taskschd.msc`) that both tasks appear

## Configuration

All timing and behavior is configured in `setup-tasks.ps1` and `mute-evening.ps1`.

### Change the mute/unmute times
Edit the trigger lines in `setup-tasks.ps1`:

```powershell
# Evening mute time
$trigger1 = New-ScheduledTaskTrigger -Daily -At "18:00"

# Morning unmute time (weekdays only)
$trigger2 = New-ScheduledTaskTrigger -Weekly `
    -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "07:30"
```

### Change the idle threshold
Edit this line in `mute-evening.ps1` (default: 10 minutes):

```powershell
if ($locked -or $idleMinutes -ge 10) {
```

### Enable unmute on weekends
Add `Saturday,Sunday` to the `-DaysOfWeek` parameter in `setup-tasks.ps1`:

```powershell
-DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday
```

### Re-apply after changes
After editing any settings, re-run `setup-tasks.ps1` as Administrator. The `-Force` flag ensures existing tasks are overwritten cleanly.

## How It Works

**Audio control** uses the Windows Core Audio API (`IAudioEndpointVolume`) via COM interop embedded as inline C# in PowerShell. This calls `SetMute(true/false)` explicitly — not a toggle — making it safe and predictable regardless of the current mute state.

**Idle detection** calls `GetLastInputInfo` from `user32.dll`, which returns the timestamp of the last mouse or keyboard input.

**Lock detection** checks whether the `LogonUI.exe` process is running, which Windows starts whenever the screen is locked.

## License

MIT
