# ChameleonDrummer REAPER Integration

REAPER-side scripts for the ChameleonDrummer drum generation engine.
Provides a dockable ReaImGui panel that generates drum MIDI via the
ChameleonDrummer CLI and imports it into the current REAPER project.

## Prerequisites

- **REAPER** 6.x/7.x (64-bit)
- **ReaPack** — https://reapack.com/
- **ReaImGui** — https://github.com/cfillion/reaimgui
  - In REAPER: Extensions → ReaPack → Browse packages → search "ReaImGui" → Install → Synchronize packages → restart REAPER
- **ChameleonDrummer CLI** — `ChameleonDrummer.exe` built from this repository

## Install

REAPER only loads ReaScripts from paths it knows about (typically
`REAPER_RESOURCE_PATH/Scripts/`). Copy or symlink the files:

```bat
:: Windows (from an elevated shell, one-time):
mklink "C:\REAPER\Scripts\chameleon_panel.lua" "C:\path\to\ChameleonDrummer\reaper_chameleon\chameleon_panel.lua"
mklink /D "C:\REAPER\Scripts\chameleon_drummer" "C:\path\to\ChameleonDrummer\reaper_chameleon"

:: Or copy after every edit:
copy reaper_chameleon\chameleon_panel.lua "C:\REAPER\Scripts\"
xcopy /E /I /Y reaper_chameleon "C:\REAPER\Scripts\chameleon_drummer\"
```

Then in REAPER: **Actions → Load ReaScript** → select `chameleon_panel.lua`
→ assign a shortcut (e.g. "ChameleonDrummer: Open Panel").

## First Run

1. Open the panel in REAPER
2. Go to the **Settings** tab
3. Click **Browse...** and select your `ChameleonDrummer.exe`
4. Click **Refresh Options** to load genres, drummers, and mappings
5. Go to **Song Sections** or **Additive Rhythm** tab and click **Generate**

## Tabs

### Song Sections
Generates a drum pattern using genre, style, drummer, mapping, tempo, and
bar count. Creates REAPER regions matching the section structure and
imports the MIDI file.

### Additive Rhythm
Converts box notation grouping strings (e.g., `3-3-3-3-2-2`) into per-bar
time signatures and a matching drum pattern. Optionally writes a timeline
JSON for REAPER tempo markers.

### Settings
Configure the ChameleonDrummer CLI path and default values. Settings are
saved in REAPER's ExtState (reaper.ini).

### Log
Live streaming log of the currently (or most recently) run job.

## CLI Commands Used

The panel calls the ChameleonDrummer CLI with these commands:

```bash
# List options (for combo boxes)
ChameleonDrummer list genres --json
ChameleonDrummer list drummers --json
ChameleonDrummer list mappings --json
ChameleonDrummer list styles --genre metal --json

# Generate song sections
ChameleonDrummer generate --genre metal --style heavy --mapping gm \
  --drummer bonham --drummer-intensity 0.8 --tempo 120 --bars 8 \
  --output chameleon_song.mid

# Generate additive rhythm
ChameleonDrummer additive-rhythm --grouping "3-3-3-3-2-2" --grid 16 \
  --tempo 120 --mapping gm --drummer bonham --drummer-intensity 0.8 \
  --output chameleon_additive.mid --write-timeline timeline.json
```

## File Structure

```
reaper_chameleon/
├── chameleon_panel.lua    # Main entry point (4 tabs + Log)
├── job_runner.lua         # Async subprocess executor
├── settings.lua           # ExtState persistence
├── options.lua            # CLI list commands wrapper
├── sections.lua           # Song Sections business logic
├── additive_rhythm.lua    # Additive Rhythm tab logic
└── README.md              # This file
```

## License

Same as ChameleonDrummer project.
