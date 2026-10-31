# ChameleonDrummer — Full User Manual

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [How ChameleonDrummer Creates Your Drum Tracks](#how-chameleondrummer-creates-your-drum-tracks)
5. [The GUI Program](#the-gui-program)
6. [REAPER Integration](#reaper-integration)
7. [Ardour Integration](#ardour-integration)
8. [The CLI Program](#the-cli-program)
9. [Advanced Features](#advanced-features)
10. [External Data Files](#external-data-files)
11. [MIDI → Tab Conversion](#midi--tab-conversion)
12. [Troubleshooting](#troubleshooting)
13. [Appendix: Source Code Principles](#appendix-source-code-principles)

---

## Introduction

ChameleonDrummer is a dynamic MIDI drum generation system built in Free Pascal (FPC) with the Lazarus Component Library (LCL). It generates realistic drum patterns for 5 genres (Metal, Rock, Jazz, Funk, Electronic), 8 styles per genre (38 total), and 17 drummer personalities. It supports multiple MIDI keymaps (GM, AD2, EZD3, XG), odd meters from 2/4 up to 32/16, external groove/fill/default files, REAPER `.rpp` and Ardour `.ardour` session export, and advanced humanization, intensity curves, and physical playability constraints.

Two executables are produced:

- `ChameleonDrummer.exe` — command-line interface
- `chameleondrummer_gui.exe` — graphical interface (Lazarus/LCL)

---

## Installation

### Requirements

- Windows (primary target; Linux/macOS possible with FPC/LCL)
- Free Pascal Compiler (FPC) 3.2.2+
- Lazarus IDE (optional, for GUI development)
- Python 3.10+ (optional, for the `tools/midi_to_tab.py` converter)

### Building from Source

```bash
# CLI executable
cd B:\dev\github\ChameleonDrummer
"%SystemDrive%\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe" -O2 -Fusrc -Sg -Sc ChameleonDrummer.lpr

# GUI executable
cd gui
cmd /c "build_gui.bat < NUL"
```

### Running the Executable

```bash
ChameleonDrummer.exe generate --genre metal --style death --tempo 195 --drummer hoglan --mapping ad2 --output death_metal.mid
```

---

## Quick Start

### CLI — Generate a Metal Song

```bash
ChameleonDrummer.exe generate --genre metal --style death --tempo 195 --drummer hoglan --mapping ad2 --output death_metal.mid
```

### CLI — Generate a Rock Pattern with Bonham Style

```bash
ChameleonDrummer.exe generate --genre rock --style classic --drummer bonham --mapping gm --output rock_classic.mid
```

### CLI — Generate in an Odd Meter

```bash
ChameleonDrummer.exe generate --genre jazz --style swing --time-sig 7/8 --output jazz_7_8.mid
```

### CLI — List Available Options

```bash
ChameleonDrummer.exe list genres
ChameleonDrummer.exe list styles --genre metal
ChameleonDrummer.exe list drummers
ChameleonDrummer.exe list mappings
```

### GUI — Interactive Generation

Launch `chameleondrummer_gui.exe`. Select genre, style, drummer, and mapping from dropdowns. Adjust tempo, bars, and complexity with sliders. Press **Generate** to create the MIDI file.

---

## How ChameleonDrummer Creates Your Drum Tracks

*For the musician who wants to understand what's happening under the hood.*

ChameleonDrummer is built as a chain of simple, independent steps. Each step does one musical job, and together they create a complete drum track. Nothing is hardcoded — everything comes from files you can read and edit yourself.

### 1. The Building Blocks: Patterns & Beats

A **pattern** is just a list of individual drum hits (beats). Each hit has:

- **When it occurs** — measured in beats from the start (1.0 = the second beat, 2.0 = the third, etc.)
- **Which drum** — kick, snare, hi-hat, tom, cymbal, etc. (defined in a JSON keymap file, not hardcoded)
- **How hard** — MIDI velocity from 0 (silent) to 127 (maximum). This is what makes some hits sound louder or softer.
- **How long** — how many beats the note lasts (most drum hits are very short, ~0.1 beats)
- **Ghost note** — a subtle, quiet hit added for groove feel. Think of this as the drummer lightly tapping the rim of a drum between the main hits.
- **Accent** — a marked, emphasized hit. This is how the drummer puts emphasis on certain beats (like the snare on beats 2 and 4 in rock).
- **Promoted instrument** — when a genre plugin decides a hi-hat should become a ride cymbal for a loud section. This lets the drumming adapt to the energy of the song.

Patterns are stored in plain `.tab` files you can open in any text editor. Each line says which instrument plays, on what beat, and with what velocity.

### 2. The Song Structure

A full song is divided into **sections** (intro, verse, chorus, bridge, etc.). Each section has its own:

- **Tempo** — speed in beats per minute (BPM). Can be different for each section.
- **Meter** — the time signature (4/4, 7/8, 5/4, etc.). The first number is how many beats per bar, the second note value gets one beat.
- **Complexity** — how varied the patterns are.
- **Default patterns** — which grooves/fills the engine should choose from.

Sections are stored in plain JSON files. You can add your own sections, change the order, or give each section its own tempo and meter.

### 3. The Bar-by-Bar Engine (ComposerV2)

This is the heart of the generation. For **each bar** of the song, the engine chooses a groove pattern. It does this using three simple ideas:

**A. Intensity matching** — Every groove (pattern) has an intensity band (e.g., 0.0–0.3 = light, 0.4–0.6 = medium, 0.7–1.0 = heavy). The engine looks at how "loud" the current bar should be (based on the song's intensity curve) and picks a groove whose band matches.

**B. Weighted randomness** — If multiple grooves fit the intensity, the engine picks one randomly, but grooves that have been used recently are less likely to be chosen again. This prevents the same pattern from repeating too often.

**C. Macro phases** — The song evolves in phases:
- **mpEstablish** (early bars): tries lighter grooves to set the feel
- **mpMaintain** (middle bars): keeps whatever's working
- **mpBuild** (toward climax): favors heavier, more intense grooves
- **mpTurnaround** (ending): leads back to the beginning or chorus

These phases are like a musical director saying "start simple, build energy, then bring it home."

### 4. The Fill System

At section boundaries (like the end of a verse before the chorus), the engine may insert a **fill** — a short, exciting pattern that signals "something's changing." The fill system:

- Loads fills from `.tab` files, each labeled with an energy level
- Checks the song's intensity at that moment
- Picks a fill whose energy matches
- Inserts it at the right bar
- After the fill, goes back to the regular groove

Fills often feature the drummer using toms, cymbal swells, or rhythmic pauses — the musical equivalent of a drummer filling the space before the next section.

### 5. Humanization (Making It Feel Human)

Real drummers don't play perfectly on the grid. ChameleonDrummer adds subtle variations:

- **Timing jitter** — each note is shifted forward or backward by a few milliseconds. Small enough to feel natural, large enough to avoid the "machine gun" effect.
- **Velocity variation** — some hits are slightly louder or softer than expected.
- **Ghost notes** — already mentioned above, these are preserved and sometimes added.
- **Swing** — a feel where straight eighth notes are played with a slight 2:1 or 3:1 ratio, like a classic rock or funk groove.

You control all of this with the **Humanization** slider in the GUI (0–1). At 0, it's perfectly on the grid. At 1, it has maximum feel.

### 5b. Physical Constraints (What a Real Drummer Can Do)

The engine knows some basic drumming physics:

- No more than 3 different drums on the same beat (a drummer can't hit the kick, snare, and two toms all at once in one motion)
- Limb coordination patterns — e.g., the right hand typically plays crash or ride cymbal, the left hand hi-hat or ride, the right foot kick, the left foot hi-hat pedal
- This prevents the engine from generating patterns a real drummer couldn't physically play

### 6. Genre & Drummer Plugins

The engine doesn't know how to play any particular style natively. Instead, it loads **plugins** at runtime:

- **Genre plugins** (Metal, Rock, Jazz, Funk, Electronic) — each defines the typical intensity bands, which grooves make sense for that style, and default song structure
- **Drummer plugins** (Bonham, Peart, Weckl, etc.) — each applies 2–4 style-specific modifications:
  - **BehindBeat** — the drummer plays slightly behind the beat for a laid-back feel
  - **GhostNotes** — adds subtle rim shots and quiet notes
  - **LinearCoordination** — typical limb patterns for that drummer
  - **ShuffleFeel** — swing feel specific to that style
  - **FillPatterns** — typical fill vocabulary

Plugins are loaded from `.pas` units but their parameters and behaviors are documented so you understand what each drummer brings.

### 7. MIDI Export

When the song is complete, it's written as a Standard MIDI File (Format 0):

- **Tracks** — one MIDI track containing all drum notes
- **Tempo events** — BPM changes as the song progresses
- **Meter events** — time signature changes
- **Note data** — pitch (which drum), velocity, start time, duration

This MIDI file works with any DAW (Reaper, Ardour, Ableton, Logic, etc.) and any drum VST plugin (EZDrummer, Superior Drummer, Addictive Drums, etc.).

### 8. The Keymap System (No Hardcoded Notes)

One of the most important design choices: **no MIDI note numbers are hardcoded** in the Pascal code. Instead:

- Keymap files (JSON) map note names (kick, snare, hi-hat, tom1, crash, etc.) to MIDI notes
- The same generation engine can use any keymap — GM (General MIDI), AD2 (Addictive Drums 2), EZD3 (EZDrummer 3), XG, or user-created
- You can edit keymap JSON files to customize which note triggers which drum
- This is why the system works with so many different drum libraries and why the GUI doesn't hardcode drum names

### 9. From GUI to CLI — Same Engine, Same Output

The graphical interface (`chameleondrummer_gui.exe`) and the command-line tool (`ChameleonDrummer.exe`) use exactly the same engine code. The GUI just provides sliders, dropdowns, and a visual interface for the same parameters you type on the command line. Whatever the GUI produces, the CLI produces identically — and vice versa.

---

## REAPER Integration

ChameleonDrummer integrates with REAPER via a Lua panel (`reaper_chameleon/chameleon_panel.lua`) that drives the CLI for drum generation and imports results directly into your REAPER project.

### Installation

1. Copy the `reaper_chameleon/` directory into your REAPER scripts folder.
2. Open REAPER and load `chameleon_panel.lua` via Actions > Show action list > New > ReaScript.
3. The panel appears as a dockable window with four tabs.

### Tabs

**Song Sections**

- Select genre, style, drummer, mapping, tempo, and number of bars
- Generate MIDI via CLI and import into the current REAPER project
- Export REAPER project (`.rpp`) alongside the MIDI

**Additive Rhythm**

- Enter additive grouping notation (e.g., `3-3-3-3-2-2`)
- Set grid resolution (4, 8, 16, 32), tempo, drummer, intensity
- Generate additive rhythm patterns with per-bar time signatures
- Optional timeline JSON export for REAPER tempo markers

**Step Editor**

- Load a MIDI item from the current project
- Edit on a grid with drummer application (timing/velocity variance)
- Apply drummer style to existing patterns

**Settings**

- Configure CLI executable path
- Set default genre/style/drummer/mapping
- Refresh options from CLI list commands

**Log**

- Real-time log output from CLI commands
- Status messages during generation

### CLI Commands Used by REAPER Panel

```
ChameleonDrummer list genres --json
ChameleonDrummer list styles --genre metal --json
ChameleonDrummer list drummers --json
ChameleonDrummer list mappings --json
ChameleonDrummer generate --genre X --style Y --mapping Z --tempo N --drummer D --drummer-intensity I --bars B --output file.mid
ChameleonDrummer additive-rhythm --grouping "3-3-3-3-2-2" --grid 16 --tempo 120 --mapping gm --drummer bonham --drummer-intensity 0.8 --output file.mid [--write-timeline timeline.json]
```

See `REAPER_INTEGRATION_PLAN.md` for the full integration architecture and implementation details.

---

## Ardour Integration

ChameleonDrummer integrates with Ardour via a Lua panel (`ardour/chameleon_panel.lua`) that drives the CLI for drum generation and imports results directly into your Ardour session.

### Installation

1. Copy the `ardour/` directory into your Ardour scripts folder (typically `~/.config/ardour/scripts/` on Linux, `~/Library/Application Support/Ardour/scripts/` on macOS, or `%APPDATA%\Ardour\scripts\` on Windows).
2. Open Ardour and load `chameleon_panel.lua` via Window > Scripting > Script Manager > New Script.
3. The panel appears as a dockable window with four tabs.

### Tabs

**Song Sections**

- Select genre, style, drummer, mapping, tempo, and number of bars
- Generate MIDI via CLI and import into the current Ardour session
- Export Ardour session (`.ardour`) alongside the MIDI

**Additive Rhythm**

- Enter additive grouping notation (e.g., `3-3-3-3-2-2`)
- Set grid resolution (4, 8, 16, 32), tempo, drummer, intensity
- Generate additive rhythm patterns with per-bar time signatures
- Optional timeline JSON export for Ardour tempo markers

**Step Editor**

- Load a MIDI item from the current session
- Edit on a grid with drummer application (timing/velocity variance)
- Apply drummer style to existing patterns

**Settings**

- Configure CLI executable path
- Set default genre/style/drummer/mapping
- Refresh options from CLI list commands

**Log**

- Real-time log output from CLI commands
- Status messages during generation

### CLI Commands Used by Ardour Panel

```
ChameleonDrummer list genres --json
ChameleonDrummer list styles --genre metal --json
ChameleonDrummer list drummers --json
ChameleonDrummer list mappings --json
ChameleonDrummer generate --genre X --style Y --mapping Z --tempo N --drummer D --drummer-intensity I --bars B --output file.mid
ChameleonDrummer additive-rhythm --grouping "3-3-3-3-2-2" --grid 16 --tempo 120 --mapping gm --drummer bonham --drummer-intensity 0.8 --output file.mid [--write-timeline timeline.json]
```

### Accessing the Panel in Ardour

Once installed, the ChameleonDrummer panel can be accessed in Ardour via:

- **Window > Scripting > ChameleonDrummer** (if registered as a menu action)
- **Window > Scripting > Script Manager > ChameleonDrummer > Run**
- Assign a keyboard shortcut in **Window > Scripting > Script Manager > ChameleonDrummer > Bind Shortcut**

The panel uses Ardour's Lua API (`Session`, `Temporal`, `ARDOUR` namespaces) for session manipulation, tempo map creation, and MIDI region import.

See `ardour/import_chameleon_song.lua` for the headless session builder used by the CLI `--ardour` export.

---

## The CLI Program

### Command Reference

```
Usage: chameleondrummer <command> [options]

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
  --swing <0-1>        Swing feel: 0 = straight (default), 0.67 classic 2:1, 1 = 3:1
  --time-sig <n/d>     Meter of the song, e.g. 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 (default 4/4)
  --segment <n:bars:bpm:n/d>  A section with its own tempo and meter, e.g. bridge:4:96:7/8
                       (bpm - keeps the song tempo); mix freely with --section
  --section <n:bars[@bpm]>  Song structure; repeat once per section, in order
                       e.g. --section intro:4 --section verse:8 --section chorus:8@140
                       (without --section the genre default structure is used)
  --drummer <name>     Drummer style (e.g., bonham, peart, carey)
  --output <file>      Output MIDI file path
  --reaper, --ardour   With generate: also write <output>.rpp / the <output>.ardour session
  --mapping <name>     Keymap to use: gm (default), ad2, ezd3, xg
  --structure <file>   Song structure from a JSON file (sections with bars, tempo,
                       complexity; optional genre, style, tempo). Command-line
                       genre/style/tempo win over the file. Not with --section.
  --sidecar <file>     Same as --structure (the REAPER sidecar format works)
  --song-map <file>    Read song map JSON for per-bar tempo/meter
  --write-timeline     Write timeline JSON after generation
  --list <type>        List: genres, styles, drummers
```

### Examples

**Generate a complete song:**

```bash
ChameleonDrummer.exe generate --genre metal --style death --tempo 195 --drummer hoglan --mapping ad2 --output death_metal.mid
```

**Generate a single pattern:**

```bash
ChameleonDrummer.exe pattern --genre jazz --style swing --output swing_verse.mid
```

**Create REAPER project:**

```bash
ChameleonDrummer.exe reaper export --genre rock --style classic --drummer bonham --mapping gm --output rock_classic.rpp
```

**Create Ardour session:**

```bash
ChameleonDrummer.exe ardour export --genre rock --style classic --drummer bonham --mapping gm --output rock_classic.ardour
```

---

## Advanced Features

### Song Maps and Sidecars

**Sections (`--section`)**: Describes the song structure directly on the command line, one `--section` per section, in playing order:

```bash
ChameleonDrummer.exe generate --genre metal --style death --section intro:4 --section verse:8 --section chorus:8 --section bridge:4 --output song.mid
```

**Sidecar (`--sidecar`)**: A JSON file describing sections with bars, tempo, complexity, and optional genre/style/tempo overrides. The command-line genre/style/tempo win over the file.

**Song Map (`--song-map`)**: A JSON file describing per-bar tempo and meter changes for complex progressive songs.

### Odd Meters

The engine supports meters from 2/4 to 32/16. Use `--time-sig n/d` or `--segment` to specify. Grooves and fills are loaded from `.tab` files that declare their meter in the block header (e.g., `[metal verse 7/8 intensity=0.40-0.90]`).

### Your Own Grooves, Fills and Defaults

Edit files in `config/`:

- `config/grooves/<genre>.tab` — add new grooves, change intensity bands
- `config/fills/<drummer>.tab` — add new fills, change energy levels
- `config/defaults/<genre>.ini` — change default tempo/style/drummer
- `config/sections/<genre>.json` — change default song structure

No recompilation needed — the engine reads these at runtime.

---

## External Data Files

### Grooves (`config/grooves/<genre>.tab`)

Each file contains blocks like:

```
[metal verse 7/8 intensity=0.40-0.90]
K     x.. .x .x
RS    ... x. x.
HO    xxx xx xx
```

The header defines the style, meter, and intensity band. Lines below define each instrument's pattern.

### Fills (`config/fills/<drummer>.tab`)

Each file contains blocks like:

```
[peart_fill_odd_7_8 energy=0.7]
S .... x... x... x..
T2 .... .x.. .x.. .x.
HP x... .... ..
```

The header defines the drummer, meter (from the name), and energy level.

### Defaults (`config/defaults/<genre>.ini`)

INI format with tempo, preferred drummers, and intensity profiles per style.

### Sections (`config/sections/<genre>.json`)

JSON array of section definitions with name, bars, tempo, complexity.

### Lookup Order

`CHAMELEON_CONFIG` env var → `%APPDATA%\ChameleonDrummer\config` → `config` next to program → `..\config` (dev builds).

---

## MIDI → Tab Conversion

`tools/midi_to_tab.py` converts a MIDI file to the `.tab` groove/fill format:

```bash
python tools/midi_to_tab.py song.mid --meter 7/8 --resolution 16 --output groove.tab
python tools/midi_to_tab.py song.mid --fill --name my_fill --energy 0.6 --output fill.tab
```

---

## Troubleshooting

**No MIDI output** — Check that `--output` points to a writable path. Check that the genre/style exists.

**Wrong meter** — Use `--time-sig 7/8` or `--segment` to specify. The engine reads meter from `.tab` block headers.

**Patterns sound too repetitive** — Increase `--complexity` (0.5 default) or use `--humanization 0.5` for more variation.

**REAPER/Ardour panel not loading** — Ensure the `reaper_chameleon/` or `ardour/` directory is copied to the correct scripts folder and loaded via the DAW's script manager.

---

## Appendix: Source Code Principles

### Design Patterns

- **Plugin architecture** — Genre and drummer plugins loaded at runtime from `.pas` files
- **No hardcoded MIDI notes** — All notes come from JSON keymap files
- **File-driven configuration** — Grooves, fills, defaults, sections are plain text/JSON
- **Same engine for GUI and CLI** — No separate code paths

### Key Constants

- `TDrumInstrument` — dynamic drum identity (name, description, metadata)
- `TPattern` / `TBeat` — pattern and beat data models
- `TComposerV2` — bar-by-bar composition engine
- `TBarSelector` — groove selection per bar
- `TFillPicker` — fill placement and selection
- `TMacroComposer` — macro phase management
- `TAdvancedHumanizer` — timing/velocity jitter
- `TPhysicalConstraints` / `TPatternFixer` — playability limits

### Pattern Template System

Grooves and fills are defined in `.tab` files with block headers that declare style, meter, and intensity. The engine selects patterns based on these declarations, not hardcoded rules.
