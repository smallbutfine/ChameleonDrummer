# ChameleonDrummer

**Dynamic MIDI drum generation** — a FreePascal/Lazarus project that turns a
genre, style, drummer and meter into a realistic, human-feeling drum track and
exports it as MIDI (plus REAPER / Ardour sessions).

## What it does

- **5 genres** — Metal, Rock, Jazz, Funk, Electronic — with **37 styles total**
- **17 drummers** — Bonham, Porcaro, Weckl, Chambers, Roeder, Dee, Hoglan, Peart,
  Rich, Copeland, Carey, Smith, Moon, Watts, Haake, Halpern, DoomBlues
- **Multi-keymap** — GM, AD2, EZDrummer 3, Yamaha XG, or user-defined JSON keymaps
- **Meters** — 2/4, 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 … up to 32/16, with optional
  triplet feel (`4/4T`, `7/8T`)
- **External data** — grooves, fills, defaults and song structures are plain
  text/JSON files you can edit without recompiling
- **DAW export** — MIDI with REAPER `.rpp` markers or Ardour `.ardour` sessions
- **Humanization** — timing/velocity jitter, ghost notes, swing, physical
  playability constraints
- **Four programs** — `ChameleonDrummer` (CLI), `chameleondrummer_gui` (GUI),
  `midi_to_tab` (MIDI → tab converter) and `step_editor` (tab editor GUI)
- **Cross-platform** — Windows (x86_64), macOS (Intel + Apple Silicon) and
  Linux (x86_64 + ARM)

## Downloads

Prebuilt binaries are attached to every
[GitHub Release](https://github.com/smallbutfine/ChameleonDrummer/releases):

| Platform | Artifact |
|---|---|
| Windows 64-bit | `ChameleonDrummer_<version>_Setup.exe` (installer) |
| macOS Intel | `chameleondrummer_gui<version>-macos-intel.zip` |
| macOS Apple Silicon | `chameleondrummer_gui<version>-macos-aarch64.zip` |
| Linux x86_64 | `ChameleonDrummer<version>-linux-x64.tar.gz` |
| Linux ARM | `ChameleonDrummer<version>-linux-arm.tar.gz` |

Unzip the macOS archive and drag `chameleondrummer_gui.app` to
`/Applications`. The app is not code-signed, so on first launch use
**right-click → Open** (or `xattr -dr com.apple.quarantine` on the
terminal).

## Installation / Build

### Prerequisites

- FreePascal Compiler (FPC) 3.2.2+ or Lazarus IDE 3.0+
- Lazarus/LCL for the GUI
- For a full multi-platform build: the FPC cross-compilers
  (`ppcrossx64`, `ppcrossa64`, `ppcrossarm`) and Inno Setup 6

### Build everything (all platforms)

From the repository root, in Git Bash or `cmd.exe`:

```bash
./build_all.bat            # all 5 targets + packages into Deploy/
./build_all.bat --check    # verify the toolchain only, build nothing
```

The script builds every target, then writes the release artifacts to
`Deploy/`. It exits non-zero if any target fails and prints a summary.

Useful environment variables:

| Variable | Effect |
|---|---|
| `FPC_DIR`, `LAZBUILD`, `CROSS_BIN_DIR`, `ISCC`, `TAR` | override the toolchain paths |
| `NO_VERSION_BUMP=1` | build the version already in `Assets/version.txt` without incrementing it |
| `CI=true` or `NO_PAUSE=1` | never pause at the end |

### Build a single program

```bash
# CLI
"%SystemDrive%\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe" -O2 -Fusrc -Sg -Sc ChameleonDrummer.lpr

# GUI
lazbuild --build-all gui/chameleondrummer_gui.lpi

# Tools
lazbuild --build-all tools/step_editor/step_editor.lpi
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
  generate         Generate a complete song (multi-bar pattern)
  pattern          Generate a single 1-4 bar pattern
  list             List available genres, styles, drummers, or mappings
  info             Show system information
  reaper           Create a REAPER project (sub-command: export)
  ardour           Create an Ardour session (sub-command: export)
  additive-rhythm  Generate additive rhythm patterns

Options:
  --genre <name>              Genre (metal, rock, jazz, funk, electronic)
  --style <name>              Style within genre (heavy, classic, swing, ...)
  --tempo <bpm>               Tempo in BPM (default: genre/style value)
  --complexity <0-1>          Pattern complexity (default: 0.5)
  --humanization <0-1>        Humanization intensity (default: 0.3)
  --swing <0-1>               Swing feel: 0 = straight (default), 0.67 = classic 2:1, 1 = 3:1
  --time-sig <n/d>            Meter of the song, e.g. 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 (default 4/4)
  --time-sig <n/d>T           Meter with triplet feel (4/4T, 7/8T, 5/4T)
  --strict-meter              Only use patterns matching --time-sig
  --segment <n:bars:bpm:n/d>  A section with its own tempo and meter, e.g. bridge:4:96:7/8
                              (bpm - keeps the song tempo); mix freely with --section
  --section <n:bars[@bpm]>    Song structure; repeat once per section, in order
                              e.g. --section intro:4 --section verse:8 --section chorus:8@140
                              (without --section the genre default structure is used)
  --drummer <name>            Drummer style (e.g., bonham, peart, carey)
  --output <file>             Output MIDI file path
  --reaper, --ardour          With generate: also write <output>.rpp / the <output>.ardour session
  --mapping <name>            Keymap to use: gm (default), ad2, ezd3, xg
  --structure <file>          Song structure from a JSON file (sections with bars, tempo,
                              complexity; optional genre, style, tempo). Command-line
                              genre/style/tempo win over the file. Not with --section.
  --sidecar <file>            Same as --structure (the REAPER sidecar format works)
  --song-map <file>           Read song map JSON for per-bar tempo/meter
  --write-timeline            Write timeline JSON after generation
  --list <type>               List: genres, styles, drummers, mappings
  --json                      Output JSON for list commands
  --grouping <str>            Additive grouping notation (e.g., 3-3-3-3-2-2)
  --grid <n>                  Grid resolution for additive-rhythm (4, 8, 16, 32)
  --drummer-intensity <0-1>   Drummer intensity for additive-rhythm
  --help, -h                  Show this help
```

### Examples

```bash
# A doom-metal song at 75 BPM with Hoglan's style
chameleondrummer generate --genre metal --style doom --tempo 75 --drummer hoglan

# Rock in 7/8 with a keymap for Addictive Drums 2
chameleondrummer generate --genre rock --style classic --time-sig 7/8 --mapping ad2

# A song with per-section tempo and meter changes
chameleondrummer generate --genre jazz --style fusion \
  --section intro:4 --section verse:8@120 --segment bridge:4:-:7/8

# A single 2-bar pattern instead of a full song
chameleondrummer pattern --genre funk --style classic --drummer porcaro

# Also write a REAPER project and an Ardour session next to the MIDI
chameleondrummer generate --genre metal --style thrash --reaper --ardour --output song.mid

# Additive rhythm pattern (3-3-3-3-2-2 over 16 steps)
chameleondrummer additive-rhythm --grouping "3-3-3-3-2-2" --grid 16 --tempo 120 --output additive.mid

# Machine-readable output for scripting
chameleondrummer list genres --json

# Discover what is available
chameleondrummer list genres
chameleondrummer list styles --genre jazz
chameleondrummer list drummers
chameleondrummer list mappings
chameleondrummer info
```

### Available styles

| Genre | Styles |
|---|---|
| metal | heavy, death, power, progressive, thrash, doom, breakdown, metal |
| rock | classic, blues, alternative, progressive, punk, hard, pop, rock |
| jazz | swing, bebop, fusion, latin, ballad, hard_bop, contemporary, jazz |
| funk | classic, pfunk, shuffle, new_orleans, fusion, minimal, heavy, funk |
| electronic | house, techno, drum_and_bass, dubstep, electronic |

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

`tools/midi_to_tab.exe` converts a MIDI file to the `.tab` groove/fill format:

```bash
midi_to_tab.exe song.mid --meter 7/8 --resolution 16 --output groove.tab
midi_to_tab.exe song.mid --fill --name my_fill --energy 0.6 --output fill.tab
```

## Step Editor

The **Step Editor** (`tools/step_editor/step_editor.exe`) is a standalone graphical application for visually editing drum patterns on a step grid, converting MIDI files to the `.tab` groove/fill format, and managing pattern blocks in the config files.

### Features

- **Step Grid Editing:** Visual grid with 17 drum instruments (K, S, RS, SS, H, HO, HP, R, RB, C, C2, CH, SP, T1, T2, T3, T4) and configurable steps per bar (4, 8, 16, 32, 64).
- **Velocity/Articulation Characters:** Each step uses a character: `.` (rest), `x` (normal), `X` (accent), `o` (soft/ghost), `g` (ghost). Click cells to cycle through states.
- **MIDI → Tab Conversion:** Load a MIDI file (`.mid`, `.midi`) and convert it to tab format using the built-in `midi_to_tab.exe` with configurable mapping, style, kind, intensity, energy, resolution, and meter.
- **Tab File Loading:** Load existing `.tab` files (both ChameleonDrummer config format and foreign tab formats) for editing.
- **Block Navigation (Config Files):** When loading a config file from `config/grooves/` or `config/fills/`, the editor parses all pattern blocks and provides a dropdown selector with Prev/Next buttons to navigate between blocks.
- **Block Editing:** Edit block header fields (Style, Kind, Intensity Low/High) directly in the UI. Changes are tracked with a `*` indicator.
- **Surgical Save:** Save individual blocks back to their source file without affecting other blocks in the same file.
- **New/Delete Blocks:** Add new empty pattern blocks or delete existing ones (with confirmation).
- **Zoom/Resolution:** Change grid resolution (8, 16, 32, 64 steps per bar) and page size.
- **Dark Mode:** Automatic system theme detection (Windows) with manual override. All controls including grid, combo boxes, and status bar are themed.
- **Auto-Scaling:** Proportional vectorial scaling of all UI elements for high-DPI displays.
- **Export:** Save edited patterns as new groove or fill `.tab` files in the config directories.

### Launching

- **From the GUI:** Click the **Step Editor** button in the main window toolbar.
- **Directly:** Run `tools/step_editor/step_editor.exe` from the project root or installation directory.
- **From REAPER/Ardour panels:** The **Step Editor** tab in the DAW integration panels launches the editor with the current MIDI item loaded.

### Building the Step Editor

```bash
cd tools/step_editor
cmd /c "build_gui.bat < NUL"
```

## Status

- ✅ Core generation engine (ComposerV2, Pattern, Song, DrumGenerator)
- ✅ All 5 genres × 37 styles total, 17 drummers
- ✅ Meters 2/4 … 32/16 with meter-aware grooves/fills, optional triplet feel
- ✅ External data files (grooves/fills/defaults/sections)
- ✅ REAPER + Ardour export
- ✅ Humanization, swing, physical constraints
- ✅ Weighted random pattern selection (intensity bands, thread-safe RNG)
- ✅ MIDI → tab conversion tool (Pascal)
- ✅ Step Editor (visual grid editing, MIDI→Tab, block management, dark mode, auto-scaling)
- ✅ Multi-platform builds: Windows x86_64, macOS Intel/Apple Silicon, Linux x86_64/ARM

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

- `docs/index.html` — project website (GitHub Pages)
- `docs/manual.html` — full user manual
- `docs/concepts.html` — concepts / how it works
- `docs/download.html` — download page
- `docs/docs.html` — documentation index
- `docs/README.md` — the `config/` file format in detail
- `AGENTS.md` — working principles for agents and contributors
- `BATCH_FIX_PLAN.md` — history of the build-script repairs
- `config/README.md` — groove/fill tab format