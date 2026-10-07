# [Witcher 3 Remastered][DX12] Game renders on WARP software adapter instead of hardware GPU

**Symptom:** after a few days of normal play, *The Witcher 3: Wild Hunt — Remastered* (Steam, DX12, Hotfix 5.00c) runs at under 10 fps and hangs on every loading screen. The graphics card sits idle while the CPU is maxed out.

**Cause:** the game picks a **Microsoft Basic Render Driver** adapter (Windows' built-in software renderer, vendor `0x1414`, device `0x008C`) instead of the real GPU. Every frame is drawn on the CPU, and NVIDIA DLSS fails to start.

**Status:** reported to CD Projekt Red. A community workaround (below) works until they ship a fix.

> Not affiliated with CD Projekt Red or NVIDIA. Use at your own risk.

## Do you have this problem?

With the game at the main menu, open **Task Manager**:

- `witcher3.exe` uses a lot of CPU (several cores), and
- your graphics card's usage and video memory barely move.
- you're getting <10 fps and are stuck in a loading screen

If these are true, you may have this bug.

## How it was diagnosed

Tested on Windows 11 with an RTX 3080, a Ryzen 7000 CPU with integrated graphics, and monitors on a DisplayLink USB-C dock.

1. **Windows' per-process GPU counters** showed all of `witcher3.exe`'s 3D work on a Microsoft Basic Render Driver adapter, with 0 MB of video memory, and nothing on the RTX 3080.
2. **A standalone Direct3D 12 test** showed that the RTX 3080 *and* both Basic Render Driver adapters pass `D3D12CreateDevice` capability checks. A probe returning `S_FALSE` counts as success ([Microsoft docs](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/nf-d3d12-d3d12createdevice)), so the game sees the software adapters as usable.
3. **Another DX12 game ran normally on the RTX 3080** on the same PC, so the problem is specific to Witcher 3.
4. **Ruled out**, with the game still failing after each:
   - System Restore to the last date it worked
   - Launching offline
   - Disabling the integrated GPU
   - Plugging the monitor directly into the GPU
   - Ray tracing off and default settings
   - All overlays off
   - Windows GPU preference
   - Disabling the Steam integration
   - DisplayLink driver changes and an NVIDIA driver reinstall
   - Full reinstall

Full details are in [`bug_report.txt`](bug_report.txt), the report sent to CD Projekt Red.

## Workaround

A Steam Community member traced the game's `D3D12CreateDevice` calls and wrote a small launcher. It uses [Frida](https://frida.re) to make only the Microsoft software-adapter capability checks report "unsupported". The game then picks the real GPU on its own. It changes nothing permanently on your PC and only affects that launch.

**Credit and the script:** the workaround and script were written by a Steam Community member. Get the script from [their post in the Steam discussion thread](https://steamcommunity.com/app/292030/discussions/1/589565500617502880/).

Confirmed working here: with the launcher, the game used the RTX 3080 (about 3.1 GB of video memory, normal CPU use), and gameplay and DLSS worked.

### Using it

1. Install Python, then Frida:
   ```
   python -m pip install --user frida==17.22.2
   ```
2. Save the script from the Steam post as `force_witcher_gpu.py`, and set `GAME` to your own `witcher3.exe` path (for example `.../steamapps/common/The Witcher 3/bin/x64_dx12/witcher3.exe`).
3. With **Steam running** and Witcher 3 closed, run:
   ```
   python force_witcher_gpu.py
   ```
   or double-click [`launcher.bat`](launcher.bat) if it's in the same folder.
4. You should see `Excluded Microsoft software-adapter probe` in the window. Use this launcher instead of Steam's Play button until an official patch.

**Read any script before you run it.** Windows Defender may flag Frida because it hooks into other programs.

### Known issue: crash a few minutes after launch

If the script calls `session.detach()` after a timer (the original detaches after 60 seconds), the game can crash later with an access violation (`0xc0000005`) in **`frida-agent.dll_unloaded`**. Detaching unloads Frida's agent, but Windows can still call into it afterwards (for example its DLL-load observer), and the next DLL the game loads triggers the crash. In testing, the game's own crash record showed it crashing right as the detach timer ran out.

**Fix:** stay attached until the game exits. Replace the `time.sleep(...)` and `session.detach()` lines at the end of the script with:

```python
ended = []
session.on('detached', lambda reason, crash: ended.append(reason))
while not ended:
    time.sleep(2)
```

Keep the launcher window open while you play. Closing it detaches the hook mid-game and can cause the same crash.

## Suggested fix for the developer

Skip adapters with `DXGI_ADAPTER_FLAG_SOFTWARE`, and Microsoft vendor ID `0x1414` (the Basic Render Driver also appears with flags `0`), whenever a hardware adapter passes the same check. Alternatively, use `IDXGIFactory6::EnumAdapterByGpuPreference(DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE)` and take the first hardware adapter that succeeds.
