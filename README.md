# ChameleonDrummer

**Dynamic MIDI drum generation** — a FreePascal/Lazarus project that turns a
genre, style, drummer and meter into a realistic, human-feeling drum track and
exports it as MIDI (plus REAPER / Ardour sessions).

## What it does

- **5 genres** — Metal, Rock, Jazz, Funk, Electronic — with **26 styles** each
- **17 drummers** — Bonham, Porcaro, Weckl, Chambers, Roeder, Dee, Hoglan, Peart,
  Rich, Copeland, Carey, Smith, Moon, Watts, Haake, Halpern, DoomBlues
- **Multi-keymap** — GM, AD2, EZDrummer 3, Yamaha XG, or user-defined JSON keymaps
- **Odd meters** — 2/4, 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 … up to 32/16
- **External data** — grooves, fills, defaults and song structures are plain
  text/JSON files you can edit without recompiling
- **DAW export** — MIDI with REAPER `.rpp` markers or Ardour `.ardour` sessions
- **Humanization** — timing/velocity jitter, ghost notes, swing, physical
  playability constraints

## Installation / Build

### Prerequisites

- FreePascal Compiler (FPC) 3.2.2+ or Lazarus IDE 3.0+
- Lazarus/LCL for the GUI

### CLI build

```bash
cd B:\dev\github\ChameleonDrummer
"%SystemDrive%\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe" -O2 -Fusrc -Sg -Sc ChameleonDrummer.lpr
```

### GUI build

```bash
cd gui
cmd /c "build_gui.bat < NUL"
```

### Run

```bash
ChameleonDrummer.exe generate --genre metal --style death --tempo 195 --drummer hoglan --mapping ad2 --output death_metal.mid
ChameleonDrummer.exe generate --genre rock --style classic --time-sig 7/8 --output rock.mid
ChameleonDrummer.exe list genres
ChameleonDrummer.exe list styles --genre jazz
ChameleonDrummer.exe list drummers
```

## REAPER / Ardour Integration

ChameleonDrummer includes Lua panels for both REAPER and Ardour that provide a graphical interface for drum generation:

### REAPER

- Copy `reaper_chameleon/` to your REAPER scripts folder
- Load `chameleon_panel.lua` via Actions > Show action list > New > ReaScript
- Access via Window > ReaScript > ChameleonDrummer

### Ardour

- Copy `ardour/` to your Ardour scripts folder (`~/.config/ardour/scripts/` on Linux, `~/Library/Application Support/Ardour/scripts/` on macOS, or `%APPDATA%\\Ardour\\scripts\\` on Windows)
- Load `chameleon_panel.lua` via Window > Scripting > Script Manager > New Script
- Access via Window > Scripting > ChameleonDrummer

Both panels provide the same functionality: Song Sections generation, Additive Rhythm patterns, Step Editor for editing existing MIDI, Settings configuration, and real-time logging.

For detailed documentation, see the `docs/` directory or visit the project website.