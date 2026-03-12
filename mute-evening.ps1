# mute-evening.ps1
# Sätter systemljudet till MUTE om datorn är låst eller idle >= 10 minuter
# Placera i C:\Scripts\

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

// Hämtar idle-tid från Windows
public class IdleDetector {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static double GetIdleMinutes() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(lii);
        GetLastInputInfo(ref lii);
        return (Environment.TickCount - (int)lii.dwTime) / 60000.0;
    }
}

// Sätter mute explicit via Windows Core Audio API (IAudioEndpointVolume)
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int RegisterControlChangeNotify(IntPtr pNotify);
    int UnregisterControlChangeNotify(IntPtr pNotify);
    int GetChannelCount(out uint pnChannelCount);
    int SetMasterVolumeLevel(float fLevelDB, ref Guid pguidEventContext);
    int SetMasterVolumeLevelScalar(float fLevel, ref Guid pguidEventContext);
    int GetMasterVolumeLevel(out float pfLevelDB);
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int SetChannelVolumeLevel(uint nChannel, float fLevelDB, ref Guid pguidEventContext);
    int SetChannelVolumeLevelScalar(uint nChannel, float fLevel, ref Guid pguidEventContext);
    int GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
    int GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, ref Guid pguidEventContext);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(ref Guid iid, uint dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    int OpenPropertyStore(uint stgmAccess, out IntPtr ppProperties);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
    int GetState(out uint pdwState);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(uint dataFlow, uint dwStateMask, out IntPtr ppDevices);
    int GetDefaultAudioEndpoint(uint dataFlow, uint role, out IMMDevice ppDevice);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorClass {}

public class AudioController {
    public static void SetMute(bool mute) {
        var enumeratorType = Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E"));
        var enumerator = (IMMDeviceEnumerator)Activator.CreateInstance(enumeratorType);
        IMMDevice device;
        enumerator.GetDefaultAudioEndpoint(0, 1, out device); // eRender, eMultimedia

        Guid iid = typeof(IAudioEndpointVolume).GUID;
        object volObj;
        device.Activate(ref iid, 23, IntPtr.Zero, out volObj);
        var vol = (IAudioEndpointVolume)volObj;

        Guid empty = Guid.Empty;
        vol.SetMute(mute, ref empty);
    }
}
"@ -Language CSharp

# ── Kontrollera om datorn är låst ──────────────────────────────────────────
$locked = (Get-Process -Name "LogonUI" -ErrorAction SilentlyContinue) -ne $null

# ── Kontrollera idle-tid ────────────────────────────────────────────────────
$idleMinutes = [IdleDetector]::GetIdleMinutes()

# ── Sätt MUTE om låst eller idle >= 10 min ─────────────────────────────────
if ($locked -or $idleMinutes -ge 10) {
    [AudioController]::SetMute($true)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm') - Muted (locked=$locked, idle=$([math]::Round($idleMinutes,1)) min)"
} else {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm') - Skipped (active user, idle=$([math]::Round($idleMinutes,1)) min)"
}
