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

## CLI Reference

```
chameleondrummer <command> [options]

Commands:
  generate   Generate a complete song (multi-bar pattern)
  pattern    Generate a single 1-4 bar pattern
  list       List available genres, styles, or drummers
  info       Show system information
  reaper     Create a REAPER project (sub-command: export)
  ardour     Create an Ardour session (sub-command: export)

Options:
  --genre <name>       Genre (metal, rock, jazz, funk, electronic)
  --style <name>       Style within genre (heavy, classic, swing, ...)
  --tempo <bpm>        Tempo in BPM (default: genre/style value)
  --complexity <0-1>   Pattern complexity (default: 0.5)
  --humanization <0-1> Humanization intensity (default: 0.3)
  --swing <0-1>        Swing feel (0 = straight, 0.67 = classic 2:1, 1 = 3:1)
  --time-sig <n/d>     Meter of the song, e.g. 3/4, 5/4, 7/8, 9/8, 11/8, 13/8
  --segment <n:bars:bpm:n/d>  Section with its own tempo and meter
  --section <n:bars[@bpm]>    Song structure (repeat per section)
  --drummer <name>     Drummer style (e.g., bonham, peart, carey)
  --output <file>      Output MIDI file path
  --mapping <name>     Keymap: gm (default), ad2, ezd3, xg
  --structure <file>   Song structure JSON file
  --sidecar <file>     Same as --structure (REAPER sidecar format works)
  --song-map <file>    Read song map JSON for per-bar tempo/meter
  --write-timeline     Write timeline JSON after generation
  --list <type>        List: genres, styles, drummers
```

## External Data Files

Grooves, fills, defaults and structures are plain files in `config/`:

| File | Describes |
|------|-----------|
| `config/grooves/<genre>.tab` | Grooves of a genre: every style, verse/chorus/bridge |
| `config/fills/<drummer>.tab` | Fills of one drummer |
| `config/defaults/<genre>.ini` | Tempo per style, preferred drummers |
| `config/sections/<genre>.json` | Default song structure of a genre |
| `config/drummer_profiles.ini` | Timing feel of each drummer |

Lookup order: `CHAMELEON_CONFIG` env var → `%APPDATA%\ChameleonDrummer\config` →
`config` next to the program → `..\config` (dev builds).

## MIDI → Tab Conversion

`tools/midi_to_tab.py` converts a MIDI file to the `.tab` groove/fill format:

```bash
python tools/midi_to_tab.py song.mid --meter 7/8 --resolution 16 --output groove.tab
python tools/midi_to_tab.py song.mid --fill --name my_fill --energy 0.6 --output fill.tab
```

## Status

- ✅ Core generation engine (ComposerV2, Pattern, Song, DrumGenerator)
- ✅ All 5 genres × 26 styles, 17 drummers
- ✅ Odd meters (2/4 … 32/16) with meter-aware grooves/fills
- ✅ External data files (grooves/fills/defaults/sections)
- ✅ REAPER + Ardour export
- ✅ Humanization, swing, physical constraints
- ✅ Weighted random pattern selection (intensity bands, thread-safe RNG)
- ✅ MIDI → tab conversion tool

## REAPER / Ardour Integration

ChameleonDrummer includes Lua panels for both REAPER and Ardour that provide a graphical interface for drum generation:

### REAPER

- Copy `reaper_chameleon/` to your REAPER scripts folder
- Load `chameleon_panel.lua` via Actions > Show action list > New > ReaScript
- Access via Window > ReaScript > ChameleonDrummer

### Ardour

- Copy `ardour/` to your Ardour scripts folder (`~/.config/ardour/scripts/` on Linux, `~/Library/Application Support/Ardour/scripts/` on macOS, or `%APPDATA%\Ardour\scripts\` on Windows)
- Load `chameleon_panel.lua` via Window > Scripting > Script Manager > New Script
- Access via Window > Scripting > ChameleonDrummer

Both panels provide the same functionality: Song Sections generation, Additive Rhythm patterns, Step Editor for editing existing MIDI, Settings configuration, and real-time logging.

For detailed documentation, see the `docs/` directory or visit the project website.

## Documentation

- `docs/USER_MANUAL.md` — full user manual
- `docs/concepts.html` — concepts / how it works
- `docs/download.html` — download page
- `docs/docs.html` — manual page
- `config/README.md` — groove/fill tab format
