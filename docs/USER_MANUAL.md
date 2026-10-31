# ChameleonDrummer — Full User Manual

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installance)
3. [Quick Start](#quick-start)
4. [Concepts of MIDI Drum Generation](#concepts-of-midi-drum-generation)
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

ChameleonDrummer is a dynamic MIDI drum generation system built in Free Pascal (FPC) with the Lazarus Component Library (LCL). It generates realistic drum patterns for 5 genres (Metal, Rock, Jazz, Funk, Electronic) with 8 styles per genre (38 total), and 17 drummer personalities. It supports multiple MIDI keymaps (GM, AD2, EZD3, XG), odd meters from 2/4 up to 32/16, external groove/fill/default files, REAPER `.rpp` and Ardour `.ardour` session export, and advanced humanization, intensity curves, and physical playability constraints.

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

Both executables are self-contained. Place `chameleondrummer.exe` and `chameleondrummer_gui.exe` in the same directory, or reference the CLI from the GUI's working directory.

---

## Quick Start

### CLI — Generate a Metal Song

```bash
ChameleonDrummer.exe generate --genre metal --style death --tempo 195 --drummer hoglan --mapping ad2 --output death_metal.mid
```

### CLI — Generate a Rock Pattern with Bonham Style

```bash
ChameleonDrummer.exe pattern --genre rock --style classic --drummer bonham --output bonham_verse.mid
```

### CLI — Generate in an Odd Meter

```bash
ChameleonDrummer.exe generate --genre rock --style classic --time-sig 7/8 --output rock_7_8.mid
```

### CLI — List Available Options

```bash
ChameleonDrummer.exe list genres
ChameleonDrummer.exe list styles --genre jazz
ChameleonDrummer.exe list drummers
```

### GUI — Interactive Generation

1. Launch `chameleondrummer_gui.exe`.
2. Select **Genre**: `metal`.
3. Select **Style**: `death`.
4. Select **Drummer**: `hoglan`.
5. Select **Mapping**: `ad2`.
6. Set **Tempo**: `195`.
7. Adjust **Complexity** and **Humanization** sliders.
8. Click **Generate**.
9. View output in the log panel.

---

## Concepts of MIDI Drum Generation

This section explains the underlying principles derived from the source code (`ComposerV2.pas`, `DrumGenerator.pas`, `Pattern.pas`, `Song.pas`, `MidiIO.pas`).

### 1. Pattern and Beat Model (`Pattern.pas`)

A `TPattern` is a container of `TBeat` objects. Each beat has:

- `Position` (`Double`): Time in beats (e.g., 0.0, 0.5, 1.0). Position 1.0 = the second beat, position 2.0 = the third beat, etc.
- `Instrument` (`TDrumInstrument`): The drum instrument (kick, snare, hi-hat, etc.). Instrument identity comes from a JSON keymap file — no notes are hardcoded in Pascal code.
- `Velocity` (`Integer`): MIDI velocity from 0 (silent) to 127 (maximum). This is what makes some hits sound louder or softer.
- `Duration` (`Double`): Note length in beats. Most drum hits are very short (~0.1 beats), but some can be longer for effect.
- `GhostNote` (`Boolean`): Subtle, low-velocity note for groove feel. Think of this as the drummer lightly tapping the rim of a drum between the main hits.
- `Accent` (`Boolean`): Emphasized hit. This is how the drummer puts emphasis on certain beats (like the snare on beats 2 and 4 in rock).
- `InstrumentPromoted` (`Boolean`): Provenance flag. True only when this beat's instrument was changed in place by a genre plugin promoting an existing hi-hat beat to a higher-energy cymbal for a high-energy section.

### 2. Song and Section Model (`Song.pas`)

A `TSong` contains sections (`TSection`), each with its own patterns, fills, tempo, and meter. Sections are arranged in a standard song order: intro, verse, pre_chorus, chorus, bridge, breakdown, solo, outro.

Each section has its own:

- **Tempo** — speed in beats per minute (BPM). 0 means inherit the song tempo.
- **Meter** — the time signature (4/4, 7/8, 5/4, etc.). The first number is how many beats per bar, the second note value gets one beat.
- **Complexity** — how varied the patterns are. Only used when `HasComplexity` is set; zero-filled records inherit the song's complexity.
- **Default patterns** — which grooves/fills the engine should choose from for this section.

Sections are stored in plain JSON files. You can add your own sections, change the order, or give each section its own tempo and meter.

### 3. Bar-by-Bar Pattern Evolution (`ComposerV2.pas`)

`TBarSelector.SelectPatternForPhrase` picks a groove for each bar using a weighted random draw:

- **Intensity matching**: Each groove's weight is based on how well its intensity band fits the bar's intensity. Grooves whose band contains the bar's intensity get a bonus.
- **Recency weighting**: The previous pattern's weight is reduced to 0.25× so it can return but rarely repeats consecutively. This prevents the same pattern from playing bar after bar.
- **Macro phases**: The song evolves in four phases:
  - `mpEstablish` (early bars): tries lighter grooves to set the feel
  - `mpMaintain` (middle bars): keeps whatever's working
  - `mpBuild` (toward climax): favors heavier, more intense grooves
  - `mpTurnaround` (ending): leads back to the beginning or chorus
- **Thread-safe randomness**: Selection uses `TThreadedRandom` for consistent results across threads.

### 4. Intensity Curves (`ComposerV2.pas`)

Intensity varies across the song: intro/verse are lighter, chorus is heavier, bridge/breakdown vary. The intensity curve drives both pattern selection and fill placement. Typical curves:

- `icAscending` — getting louder toward the climax
- `icDescending` — starting loud, fading out
- `icPlateau` — roughly constant intensity
- `icDipRise` — dips then rises (common for verse-chorus-verse)
- `icSteps` — distinct intensity changes at section boundaries

### 5. Macro Composer (`ComposerV2.pas`)

The macro phase biases pattern selection per section. The four phases (`mpEstablish`, `mpMaintain`, `mpBuild`, `mpTurnaround`) control how the groove evolves throughout the song, like a musical director saying "start simple, build energy, then bring it home."

### 6. Groove Engine (`ComposerV2.pas`)

Grooves are loaded from `config/grooves/<genre>.tab` files. Each block defines a style/kind/intensity band. The engine picks the best-fitting groove per bar.

**Groove block format:**

```
[style kind intensity=low-high]
K  x... .... x... .... | x... .... x... ..x.
S  .... x... .... x... | .... x... .... x...
H  x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.
```

- **Header**: `[style kind intensity=low-high]`
  - `style` — e.g., `metal`, `rock`, `jazz`, `funk`, `electronic`
  - `kind` — `verse`, `chorus` or `bridge`
  - `intensity=low-high` — the bar intensities (0–1) this groove suits, e.g., `intensity=0.20-0.60`
- **Add meter after kind**: `[classic verse 7/8 intensity=0.2-0.7]` for odd-meter grooves
- **Instrument lines**: One line per instrument. Format: `INSTRUMENT STEP STEP STEP | STEP STEP STEP`
  - `K` = kick, `S` = snare, `RS` = ride cymbal short, `SS` = splash, `H` = hi-hat, `HO` = hi-hat open, `HP` = hi-hat pedal, `R` = rack tom, `RB` = bass tom, `C` = crash cymbal, `C2` = second crash, `CH` = china, `SP` = splash, `T1` = tom 1, `T2` = tom 2, `T3` = tom 3, `T4` = tom 4
  - Step characters: `.` = rest (no hit), `x` = hit, `X` = accented hit, `o` = soft note, `g` = ghost note
  - Spaces inside a bar are ignored (they improve readability only)
  - Bars are separated by `|`. The engine uses the longest line's bar count; shorter lines repeat their pattern
- **Example** (from `rock.tab`):

```
[rock verse intensity=0.20-0.60]
K  x... .... x... .... | x... .... x... ..x.
S  .... x... .... x... | .... x... .... x...
H  x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.
```

### 7. Fill System (`ComposerV2.pas`)

Fills are loaded from `config/fills/<drummer>.tab`. Each block defines a name/energy band. The engine picks a fill whose energy matches the bar's intensity at section boundaries.

**Fill block format:**

```
[bonham_fill_short energy=0.3]
S ... ... ... xxx
```

- **Header**: `[name energy=0.3]`
  - `name` — e.g., `bonham_fill_short`, `peart_fill_odd_7_8`
  - `energy=0.3` — the bar intensity (0–1) the fill suits best
- **Same instrument/step format as grooves**: Same step characters (`.`, `x`, `X`, `o`, `g`), same bar/bars separator rules.

### 8. Humanization (`AdvancedHumanization.pas`)

Timing and velocity jitter are applied per note, scaled by the humanization setting. Ghost notes and accents are preserved.

- **Timing jitter**: Each note is shifted forward or backward by a few milliseconds. Small enough to feel natural, large enough to avoid the "machine gun" effect.
- **Velocity variation**: Some hits are slightly louder or softer than expected.
- **Swing**: A feel where straight eighth notes are played with a slight 2:1 or 3:1 ratio, like a classic rock or funk groove. Controlled by the `--swing` CLI flag or GUI slider (0 = straight, 0.67 = classic 2:1 swing, 1 = 3:1).

You control all of this with the **Humanization** slider in the GUI (0–1). At 0, it's perfectly on the grid. At 1, it has maximum feel.

### 9. Physical Constraints (`PhysicalConstraints.pas` / `PatternFixer.pas`)

The pattern fixer removes impossible hits:

- **At most 3 hits on one step**: A drummer can't hit the kick, snare, and two toms all at once in one motion.
- **Limb coordination patterns**: 
  - Right hand: typically plays crash or ride cymbal
  - Left hand: hi-hat or ride cymbal
  - Right foot: kick pedal
  - Left foot: hi-hat pedal
- This prevents the engine from generating patterns a real drummer couldn't physically play.

### 10. Plugin Architecture (`PluginRegistry.pas`, `DrumGenerator.pas`)

Genre plugins and drummer plugins are discovered dynamically at runtime from `.pas` files. Each drummer applies 2–4 modifications:

- **BehindBeat**: The drummer plays slightly behind the beat for a laid-back feel.
- **GhostNotes**: Adds subtle rim shots and quiet notes.
- **LinearCoordination**: Typical limb patterns for that drummer (e.g., Bonham's distinctive kick-snare patterns).
- **ShuffleFeel**: Swing feel specific to that style.
- **FillPatterns**: Typical fill vocabulary for that drummer.

Modifications are composable and applied in order. Genre plugins (Metal, Rock, Jazz, Funk, Electronic) define the typical intensity bands, which grooves make sense for that style, and default song structure.

### 11. Keymap System (`Kit.pas`)

MIDI notes are resolved through JSON keymap files in `mappings/`. **No hardcoded notes exist in Pascal code.**

- Keymap files map note names (kick, snare, hi-hat, tom1, crash, etc.) to MIDI notes.
- The same generation engine can use any keymap — GM (General MIDI), AD2 (Addictive Drums 2), EZD3 (EZDrummer 3), XG, or user-created.
- You can edit keymap JSON files to customize which note triggers which drum.
- This is why the system works with so many different drum libraries and why the GUI doesn't hardcode drum names.

### 12. MIDI Export (`MidiIO.pas`, `MidiParser.pas`)

Raw SMF Format 0 writer with VLQ encoding, tempo/meter meta events, compatible with all DAWs and drum VSTs.

- **Tracks**: One MIDI track containing all drum notes.
- **Tempo events**: BPM changes as the song progresses.
- **Meter events**: Time signature changes.
- **Note data**: Pitch (which drum), velocity, start time, duration.

This MIDI file works with any DAW (Reaper, Ardour, Ableton, Logic, etc.) and any drum VST plugin (EZDrummer, Superior Drummer, Addictive Drums, etc.).

---

## The GUI Program

The GUI (`chameleondrummer_gui.exe`) links the engine directly — it produces exactly what the command-line tool produces, without shelling out to it.

1. Launch `chameleondrummer_gui.exe`.
2. Pick genre, style, drummer, keymap, tempo, complexity and humanization from the interface.
3. Click **Generate** — a MIDI file is written.
4. Optionally export a REAPER project (`.rpp`) or Ardour session (`.ardour`) next to it.
5. Dark mode is available via `View > System/Light/Dark` and persists in `gui.ini`.

The GUI provides interactive access to all CLI generation options plus visual feedback:

- Real-time preview of selected genre/style/drummer combinations
- Dynamic section controls added at runtime based on genre defaults
- Dark mode support (compiled only for Windows)
- Configuration persistence via `gui.ini`

See `gui/README.md` for details on the Lazarus form layout, component setup, and dark mode implementation.

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
  --swing <0-1>        Swing feel: 0 = straight (default), 0.67 = classic 2:1, 1 = 3:1
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

### Lookup Order

1. The folder in the environment variable `CHAMELEON_CONFIG`, if set
2. `%APPDATA%\ChameleonDrummer\config` (Linux: `~/.config/ChameleonDrummer/config`)
3. `config` next to the program
4. `..\config` (development builds)

---

## MIDI → Tab Conversion

`tools/midi_to_tab.py` converts a MIDI file to the `.tab` groove/fill format. Pure Python, no external dependencies.

```bash
python tools/midi_to_tab.py input.mid [output.tab]
python tools/midi_to_tab.py input.mid --fill --name bonham_fill --energy 0.6
python tools/midi_to_tab.py input.mid --meter 7/8 --resolution 16
python tools/midi_to_tab.py input.mid --mapping mappings/gm.json --style rock --kind verse
```

Options:

| Option | Description |
|--------|-------------|
| `--fill` | Output a fill block instead of a groove block |
| `--name <name>` | Fill name (default: `fill`) |
| `--energy <0-1>` | Fill energy (default: 0.5) |
| `--meter <n/d>` | Meter override (default: from MIDI meta or 4/4) |
| `--resolution <n>` | Steps per quarter note: 4, 8, 16, 32 (default: 16) |
| `--mapping <file>` | Keymap JSON file (default: built-in GM map) |
| `--style <name>` | Groove style name (default: `midi`) |
| `--kind <name>` | Groove kind: verse/chorus/bridge (default: `verse`) |
| `--intensity <low-high>` | Groove intensity band (default: `0.2-0.6`) |

Output is written with CRLF line endings, ready to drop into `config/grooves/` or `config/fills/`.

---

## Troubleshooting

### Common Issues

| Problem | Cause / Fix |
|---------|-------------|
| `FPC fehlgeschlagen` | Run from the project root with `-Fusrc` include path |
| `method identifier expected` | Syntax error in a `.pas` file — check the named line |
| `Identifier not found "GetSectionFlavors"` | Missing unit or method — rebuild all units |
| `Syntax error, "." expected but ";" found` | Missing comma/semicolon in Pascal source |
| `Comment level 2 found` | Warning only — nested `(* *)` comments |
| `function result variable ... does not seem to be initialized` | Warning only — result variable not assigned on all paths |
| `[Warning] ... metal.tab (12): ...` | Tab file syntax error — that file is ignored, built-in plays instead |

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