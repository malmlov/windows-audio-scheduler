# mute-evening.ps1
# Mutes system audio if idle >= 10 minutes or PC is locked.
# Runs every 20 minutes after 18:00 (and all day on weekends).
# Place in C:\Scripts\

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

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
        long idle = (uint)Environment.TickCount - lii.dwTime;
        return idle / 60000.0;
    }
}

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

public class AudioController {
    public static void SetMute(bool mute) {
        var enumeratorType = Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E"));
        var enumerator = (IMMDeviceEnumerator)Activator.CreateInstance(enumeratorType);
        IMMDevice device;
        enumerator.GetDefaultAudioEndpoint(0, 1, out device);
        Guid iid = typeof(IAudioEndpointVolume).GUID;
        object volObj;
        device.Activate(ref iid, 23, IntPtr.Zero, out volObj);
        var vol = (IAudioEndpointVolume)volObj;
        Guid empty = Guid.Empty;
        vol.SetMute(mute, ref empty);
    }
}
"@ -Language CSharp

$locked      = (Get-Process -Name "LogonUI" -ErrorAction SilentlyContinue) -ne $null
$idleMinutes = [IdleDetector]::GetIdleMinutes()

if ($locked -or $idleMinutes -ge 10) {
    [AudioController]::SetMute($true)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm') - Muted (locked=$locked, idle=$([math]::Round($idleMinutes,1)) min)"
} else {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm') - Skipped (active user, idle=$([math]::Round($idleMinutes,1)) min)"
}
