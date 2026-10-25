# ChameleonDrummer — Full User Manual

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Concepts of MIDI Drum Generation](#concepts-of-midi-drum-generation)
5. [The CLI Program](#the-cli-program)
6. [The GUI Program](#the-gui-program)
7. [Advanced Features](#advanced-features)
8. [External Data Files](#external-data-files)
9. [MIDI → Tab Conversion](#midi--tab-conversion)
10. [Troubleshooting](#troubleshooting)
11. [Appendix: Source Code Principles](#appendix-source-code-principles)

---

## Introduction

ChameleonDrummer is a dynamic MIDI drum generation system built in Free Pascal (FPC) with the Lazarus Component Library (LCL). It generates realistic drum patterns for 5 genres (Metal, Rock, Jazz, Funk, Electronic), 26 styles per genre, and 17 drummer personalities. It supports multiple MIDI keymaps (GM, AD2, EZD3, XG), odd meters from 2/4 up to 32/16, external groove/fill/default files, REAPER `.rpp` and Ardour `.ardour` session export, and advanced humanization, intensity curves, and physical playability constraints.

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

- `Position` (`Double`): Time in beats (e.g., 0.0, 0.5, 1.0)
- `Instrument` (`TDrumInstrument`): The drum instrument (kick, snare, hi-hat, etc.)
- `Velocity` (`Integer`): MIDI velocity (0–127)
- `Duration` (`Double`): Note length in beats
- `GhostNote` (`Boolean`): Subtle, low-velocity note for groove
- `Accent` (`Boolean`): Emphasized hit
- `InstrumentPromoted` (`Boolean`): Provenance flag when a genre plugin promotes a hi-hat to a cymbal for high-energy sections

### 2. Song and Section Model (`Song.pas`)

A `TSong` contains sections (`TSection`), each with its own patterns, fills, tempo, and meter. Sections are arranged in order: intro, verse, pre_chorus, chorus, bridge, breakdown, solo, outro.

### 3. Bar-by-Bar Pattern Evolution (`ComposerV2.pas`)

`TBarSelector.SelectPatternForPhrase` picks a groove for each bar using a weighted random draw:

- Each groove's weight is based on how well its intensity band fits the bar's intensity
- Grooves whose band contains the bar's intensity get a bonus
- The previous pattern's weight is reduced (0.25×) so it can return but rarely repeats consecutively
- `mpEstablish` phase leans toward the lightest groove; `mpBuild` leans toward the heaviest
- Selection uses `TThreadedRandom` for thread-safe randomness

### 4. Intensity Curves (`ComposerV2.pas`)

Intensity varies across the song: intro/verse are lighter, chorus is heavier, bridge/breakdown vary. The curve drives pattern selection and fill placement.

### 5. Macro Composer (`ComposerV2.pas`)

The macro phase (`mpEstablish`, `mpMaintain`, `mpBuild`, `mpTurnaround`) biases pattern selection per section.

### 6. Groove Engine (`ComposerV2.pas`)

Grooves are loaded from `config/grooves/<genre>.tab` files. Each block defines a style/kind/intensity band. The engine picks the best-fitting groove per bar.

### 7. Fill System (`ComposerV2.pas`)

Fills are loaded from `config/fills/<drummer>.tab`. Each block defines a name/energy band. The engine picks a fill whose energy matches the bar's intensity at section boundaries.

### 8. Humanization (`AdvancedHumanization.pas`)

Timing and velocity jitter are applied per note, scaled by the humanization setting. Ghost notes and accents are preserved.

### 9. Physical Constraints (`PhysicalConstraints.pas` / `PatternFixer.pas`)

The pattern fixer removes impossible hits: at most 3 hits on one step, limb coordination (snare/crash/toms 1/3 right hand; hi-hat/ride/tom 2 left hand; kick/pedal feet).

### 10. Plugin Architecture (`PluginRegistry.pas`, `DrumGenerator.pas`)

Genre plugins and drummer plugins are discovered dynamically. Each drummer applies 2–4 modifications: BehindBeat, GhostNotes, LinearCoordination, ShuffleFeel, etc.

### 11. Keymap System (`Kit.pas`)

MIDI notes are resolved through JSON keymap files in `mappings/`. No hardcoded notes exist in Pascal code.

### 12. MIDI Export (`MidiIO.pas`, `MidiParser.pas`)

Raw SMF Format 0 writer with VLQ encoding, tempo/meter meta events, compatible with all DAWs and drum VSTs.

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
  --swing <0-1>        Swing feel: 0 straight (default), 0.67 classic 2:1, 1 = 3:1
  --time-sig <n/d>     Meter of the song, e.g. 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 (default 4/4)
  --segment <n:bars:bpm:n/d>  A section with its own tempo and meter, e.g. bridge:4:96:7/8
                       (bpm - keeps the song tempo); mix freely with --section
  --section <n:bars[@bpm]>  Song structure; repeat once per section, in order
                       e.g. --section intro:4 --section verse:8 --section chorus:8@140
                       (without --section the genre default structure is used)
  --drummer <name>     Drummer style (e.g., bonham, peart, carey)
  --output <file>      Output MIDI file path
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
ChameleonDrummer.exe ardour export --genre funk --style classic --mapping ezd3 --output funk_classic.ardour
```

---

## The GUI Program

The GUI (`chameleondrummer_gui.exe`) links the engine directly — it produces exactly what the command-line tool produces, without shelling out to it.

1. Launch `chameleondrummer_gui.exe`.
2. Pick genre, style, drummer, keymap, tempo, complexity and humanization.
3. Click **Generate** — a MIDI file is written.
4. Optionally export a REAPER project or Ardour session next to it.
5. Dark mode is available via `View > System/Light/Dark` and persists in `gui.ini`.

See `gui/README.md` for details.

---

## Advanced Features

### Song Maps and Sidecars

**Sections (`--section`)**: Describes the song structure directly on the command line, one `--section` per section, in playing order:

```bash
ChameleonDrummer.exe generate --genre rock --style classic --tempo 120 \
  --section intro:4 --section verse:8@100 --section chorus:8@140 --section outro:4
```

`name:bars` gives a section of that many bars (1–256); `@bpm` (60–300) gives it its own tempo, otherwise it plays at `--tempo`. A name is letters, digits, `_` and `-`, starting with a letter. The composer treats `intro`, `verse`, `pre_chorus`, `chorus`, `bridge`, `breakdown`, `solo` and `outro` specially; any other name plays like a verse. A wrong value stops with a message that names it. The tempo changes appear in the MIDI file, the Ardour session, the REAPER project (as a tempo envelope with a step at every section start, which also carries meter changes) and the exported bar lengths. The GUI sends the sections shown in its section list this way.

**Structure file (`--structure file.json`)**: The same information in a JSON file, for songs too long to type. `--sidecar` is the older name for the same option and reads the same files, so the sidecar that the REAPER script writes works as is. See `config/example_structure.json`:

```json
{
  "genre": "rock", "style": "classic", "tempo": 120,
  "time_signature": [4, 4],
  "sections": [
    { "name": "intro",  "bars": 4, "complexity": 0.2 },
    { "name": "verse",  "bars": 8, "tempo": 112, "complexity": 0.4 },
    { "name": "chorus", "bars": 8, "tempo": 124, "complexity": 0.9 }
  ]
}
```

- Each section needs `name` and `bars` (1–256); `tempo` (60–300) and `complexity` (0–1) are optional. `complexity` replaces `--complexity` for that section only, so a chorus can be busier than a verse.
- `genre`, `style` and `tempo` at the top are defaults: whatever you give on the command line wins.
- `time_signature` is `[7, 8]` style: numerator 2–32 over 2, 4, 8 or 16. At the top it is the song's meter, in a section it is that section's. Command-line `--time-sig` wins over the file.
- `pattern_template` and `fill_policy` are recognised but not implemented yet. They, and any unknown key, print a warning and are ignored.
- A mistake stops with a message naming the file, the section (number and name) and the key. `--structure` cannot be combined with `--section`.
- It works with `generate`, `reaper export` and `ardour export`.

**Song Map (`--song-map`)**: A JSON file defining per-region segments with tempo and meter changes. This allows complex song structures with mid-section tempo changes.

**Timeline (`--write-timeline`)**: Writes a flat timeline JSON after generation, resolving tempo points and region boundaries.

### Odd Meters

```bash
ChameleonDrummer.exe generate --genre rock --style classic --time-sig 7/8
ChameleonDrummer.exe generate --genre rock --style classic --tempo 120   --section intro:2 --segment verse:4:100:7/8 --segment chorus:4:-:5/4 --section outro:2
```

`--time-sig n/d` plays the whole song in that meter; `--segment name:bars:bpm:n/d` is a section with its own tempo and meter (`-` keeps the song tempo) and mixes freely with `--section`. Any numerator from 2 to 32 over 2, 4, 8 or 16 works: 2/4, 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 … The GUI has a Meter box. A `--structure` file takes `"time_signature": [7, 8]` for the song or for one section.

Grooves and fills are written per meter in the files (`[classic verse 7/8]`, see below). When a meter has none, the song still plays: the engine uses a groove of another style of the genre, or a plain one it builds, and prints a `[Warning]` naming the block to add and the file to add it to. MIDI, REAPER and Ardour all get the meter and its changes.

### Your Own Grooves, Fills and Defaults

Grooves, fills, default tempos and default song structures are plain text files in `config\`, each named after what it describes:

| File | Describes |
|------|-----------|
| `config\grooves\<genre>.tab` | The grooves of a genre: every style, verse / chorus / bridge |
| `config\fills\<drummer>.tab` | The fills of one drummer |
| `config\defaults\<genre>.ini` | Tempo per style, the drummers that suit the genre |
| `config\sections\<genre>.json` | The default song structure of the genre |
| `config\drummer_profiles.ini` | Timing feel of each drummer |

The tab format is a drum tab:

```
[heavy verse intensity=0.4-0.8]
K  x... ..x. x... ..x. | x... ....
S  .... x... .... x... | .... x...
H  x.x. x.x. x.x. x.x.
```

`x` hits, `X` accents, `o` is soft, `g` a ghost note, `.` a rest; one row per instrument, bars separated by `|`. To add a groove, add a block; to add a style, use a new style name; to give a drummer another fill, add a block to the file named after the drummer. Copy a file to `%APPDATA%\ChameleonDrummer\config\...` and edit the copy — it is used instead of the installed one, and survives a reinstall. A mistake in a file prints a `[Warning]` with the file and line and that file is ignored. `config\README.md` describes the format and the instrument names in full.

### REAPER Integration

The `reaper/create_song_sections.lua` script provides bi-directional integration:

- **REAPER Mode**: Reads `REAPER_SECTIONS` table and writes `midi_drums_sections.json`
- **Python Sidecar Mode**: Reads existing sidecar JSON
- **AI Agent Mode**: Uses AI to choose song structure
- **Song Map Mode**: Reads song map JSON for per-bar tempo/meter

The script calls Python via `io.popen()` and writes markers and regions in the REAPER project.

### Ardour Integration

Similar to REAPER, the Ardour bridge creates `.ardour` session directories with MIDI files and session metadata.

---

## External Data Files

All configuration is external — no recompilation needed to add grooves, fills, styles or drummers.

### Grooves (`config/grooves/<genre>.tab`)

One block per groove:

```
[classic verse intensity=0.20-0.60]
K  x... .... x... .... | x... .... x... ..x.
S  .... x... .... x... | .... x... .... x...
H  x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.
```

- Header: `[style kind intensity=low-high]` — kind is `verse`, `chorus` or `bridge`; intensity is the bar intensities (0–1) this groove suits
- Add `7/8`, `5/4` etc. after the kind for odd-meter grooves: `[classic verse 7/8 intensity=0.2-0.7]`
- One line per instrument: `K S RS SS H HO HP R RB C C2 CH SP T1 T2 T3 T4`
- Steps: `.` rest, `x` hit, `X` accent, `o` soft, `g` ghost
- Bars separated by `|`; spaces inside a bar are ignored
- A line with fewer bars than the longest line repeats its bars

### Fills (`config/fills/<drummer>.tab`)

One block per fill:

```
[bonham_fill_short energy=0.3]
S ... ... ... xxx
```

- Header: `[name energy=0.3]` — energy is the bar intensity (0–1) the fill suits best
- Same instrument/step format as grooves

### Defaults (`config/defaults/<genre>.ini`)

```
[bpm]
default=140
heavy=140
doom=70

[drummers]
preferred=bonham, roeder, dee
```

### Sections (`config/sections/<genre>.json`)

Same format as `--structure`. Default structure when neither `--section` nor `--structure` is given.

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
| `chameleondrummer.exe is not found` | GUI needs the CLI in the same directory or on PATH |
| `unknown runtime error 123` | Bad path in a logger — check `%APPDATA%\ChameleonDrummer\gui.ini` |

---

## Appendix: Source Code Principles

### Design Patterns

- **Plugin architecture**: Genre and drummer plugins registered in `TPluginRegistry`
- **Strategy pattern**: `TBarSelector` selects patterns per phrase; swappable per phase
- **Template method**: `TGenrePlugin` / `TDrummerPlugin` base classes define hooks
- **Value objects**: `TTimeSignature`, `TGenerationParameters` are immutable data carriers

### Key Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| `MIN_METER_NUMERATOR` | 2 | Smallest meter numerator |
| `MAX_METER_NUMERATOR` | 32 | Largest meter numerator |
| Valid denominators | 2, 4, 8, 16 | Meter denominators |
| `VEL_GHOST` | 32 | Below: ghost note `g` |
| `VEL_SOFT` | 64 | Below: soft `o` |
| `VEL_ACCENT` | 96 | Above: accent `X` |

### Pattern Template System

Templates define reusable groove building blocks: BasicGroove, DoubleBassPedal, BlastBeat, SteadyRide, JazzRide, FunkGhostNotes, CrashAccents, TomFill.

### Drummer Modification Registry

Each drummer applies 2–4 modifications: BehindBeat, GhostNotes, LinearCoordination, ShuffleFeel, etc. Modifications are composable and applied in order.
