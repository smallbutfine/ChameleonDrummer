# Platform Independence Investigation

## Executive Summary

The ChameleonDrummer codebase is **mostly platform-independent** at its core, but has **significant Windows-specific components** that would require substantial work to make fully cross-platform.

**Effort Estimate: Medium-High (3-4 weeks for basic support, 6-8 weeks for full parity)**

---

## Platform-Independent Components (Easy to Port)

### Core Engine (`src/`)
- **Pattern, Song, Kit, ComposerV2, DrumGenerator** - Pure Pascal, no OS dependencies
- Uses `SysUtils`, `Classes`, `Generics.Collections` - all cross-platform
- **MIDI I/O** (`MidiIO.pas`) - Uses `FileExists`, `DeleteFile`, standard file ops
- **JSON parsing** (`fpjson`, `jsonparser`) - FPC built-in, cross-platform

### Build System
- **FPC compiler** - Works on Windows, Linux, macOS
- **Lazarus IDE** - Cross-platform GUI framework

---

## Windows-Specific Components (Require Changes)

### 1. GUI Application (`gui/`)

| File | Dependencies | Effort |
|------|-------------|--------|
| `DarkTheme.pas` | `Windows`, `Registry`, `IniFiles`, `DWM API` | **High** |
| `MainFrm.pas` | `ShellApi`, `process`, Windows paths | **Medium** |
| `CliLookup.pas` | Hardcoded `.exe` extension | **Low** |

**DarkTheme.pas issues:**
- Uses `TRegistry` for reading Windows theme settings
- Calls Windows DWM API (`DwmSetWindowAttribute`) for dark title bar
- Uses `SetProcessCurrentAppMode` / `FlushMenuThemes` from `uxtheme.dll`
- Hardcoded `%APPDATA%` path via `GetEnvironmentVariable`

**Mitigation:** Wrap in conditional compilation:
```pascal
{$IFDEF MSWINDOWS}
  // Windows-specific dark mode code
{$ELSE}
  // Fallback to LCL-native dark mode or ignore
{$ENDIF}
```

### 2. DAW Integration (`src/`)

| File | Dependencies | Effort |
|------|-------------|--------|
| `ArdourAPI.pas` | Windows paths, `.exe` names, `cmd.exe` | **High** |
| `ReaperAPI.pas` | Windows paths, `.rpp` format (REAPER-specific) | **Medium** |
| `ReaperRPP.pas` | Windows line endings, path handling | **Medium** |

**ArdourAPI issues:**
- Searches `ProgramFiles\Ardour` directories
- Uses `cmd.exe` for running Lua scripts
- Windows-style path separators in batch files

**ReaperAPI issues:**
- REAPER is Windows/macOS only (no Linux)
- `.rpp` format is REAPER-specific

### 3. Build Scripts

| File | Issues | Effort |
|------|--------|--------|
| `build_and_deploy.bat` | Windows batch, Inno Setup, windres | **High** |
| `gui/build_gui.bat` | Windows batch | **Low** |
| `_run_build.ps1` | PowerShell | **Medium** |

**Solution:** Create shell scripts for Linux/macOS:
```bash
#!/bin/bash
# build.sh
fpc -O2 -Fusrc ChameleonDrummer.lpr
lazbuild gui/chameleondrummer_gui.lpi
```

### 4. Path Handling

**Issues found:**
- `ArdourAPI.pas` line 146-147: `ProgramFiles + 'Ardour' + IntToStr(Major) + '\bin\'`
- `ArdourAPI.pas` line 227: `StringReplace(AMIDIFile, '\', '/', [rfReplaceAll])`
- `PluginDiscovery.LoadPluginsFromDirectory`: Uses `/` hardcoded

**Solution:** Use `IncludeTrailingPathDelimiter`, `PathSeparator`, or `System.IOUtils` (FPC 3.2+).

---

## Recommended Porting Strategy

### Phase 1: Core Engine (1-2 days)
- Verify all core units compile on Linux/macOS
- Fix any path separator issues
- Test MIDI generation

### Phase 2: Build System (2-3 days)
- Create `build.sh` and `build_gui.sh`
- Create `Makefile` or CMake config
- Handle resource compilation differently (no windres)

### Phase 3: GUI Dark Mode (3-5 days)
- Create `DarkThemeLinux.pas` / `DarkThemeMac.pas`
- Use GTK theme integration on Linux
- Use NSAppearance on macOS

### Phase 4: DAW Integration (5-7 days)
- **Ardour**: Already cross-platform (Linux native), just fix path handling
- **REAPER**: Windows/macOS only - document limitation or use Wine on Linux

---

## Conditional Compilation Guide

Add to project options:
```
-dRELEASE
-dCPU64
-dLCLWin32  (or LCLGtk3, LCLQt5, etc.)
```

Example pattern:
```pascal
{$IFDEF MSWINDOWS}
  uses Windows, Registry;
  // Windows-specific code
{$ENDIF}

{$IFDEF LINUX}
  uses Unix, BaseUnix;
  // Linux-specific code
{$ENDIF}

{$IFDEF DARWIN}
  // macOS-specific code
{$ENDIF}
```

---

## Dependencies Summary

| Dependency | Windows | Linux | macOS |
|------------|---------|-------|-------|
| FPC 3.2.2 | ✓ | ✓ | ✓ |
| Lazarus 2.2+ | ✓ | ✓ | ✓ |
| Inno Setup | ✓ | ✗ | ✗ |
| windres | ✓ | ✗ | ✗ |
| Windows API | ✓ | ✗ | ✗ |
| REAPER | ✓ | ✗ | ✓ |
| Ardour | ✓ | ✓ | ✓ |
| PowerShell | ✓ | ✗ | ✗ |

---

## Conclusion

**The core MIDI drum generation engine is already cross-platform.** The main barriers are:

1. **GUI dark mode** - Windows-specific API calls
2. **Build/deploy scripts** - Windows batch/PowerShell
3. **DAW integration** - Ardour needs path fixes, REAPER is Windows/macOS only

**Minimum viable port:** Can be achieved by:
- Using LCL's default theme (no custom dark mode)
- Using simple shell scripts instead of batch
- Focusing on Ardour (Linux native) and skipping REAPER on Linux

**Full parity:** Requires implementing platform-specific dark mode and build scripts for each OS.