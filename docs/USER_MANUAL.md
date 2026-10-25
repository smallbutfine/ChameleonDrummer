# ChameleonDrummer — Full User Manual

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Concepts of MIDI Drum Generation](#concepts-of-midi-drum-generation)
5. [The CLI Program](#the-cli-program)
6. [The GUI Program](#the-gui-program)
7. [Advanced Features](#advanced-features)
8. [Troubleshooting](#troubleshooting)
9. [Appendix: Source Code Principles](#appendix-source-code-principles)

---

## Introduction

ChameleonDrummer is a dynamic MIDI drum generation system built in Free Pascal (FPC) with the Lazarus Component Library (LCL). It translates the Python-based `midi_drums` architecture into native Pascal executables: a command-line interface (`ChameleonDrummer`) and a graphical interface (`ChameleonDrummerGUI`).

The system generates realistic drum patterns for 5 genres (Metal, Rock, Jazz, Funk, Electronic), 38 distinct styles, and 17 drummer personalities. It supports multiple MIDI keymaps (GM, AD2, EZD3, XG), produces REAPER `.rpp` and Ardour `.ardour` session files, and applies advanced humanization, intensity curves, and physical playability constraints.

---

## Installation

### Requirements

- Windows (primary target; Linux/macOS possible with FPC/LCL)
- Free Pascal Compiler (FPC) 3.2+
- Lazarus IDE (optional, for GUI development)
- Python 3.10+ (optional, for AI generation features)

### Building from Source

```bash
# CLI executable
lazbuild ChameleonDrummer.lpr

# GUI executable
lazbuild gui/chameleondrummer_gui.lpi
```

### Running the Executable

Both executables are self-contained. Place `chameleondrummer.exe` and `chameleondrummer_gui.exe` in the same directory, or reference the CLI from the GUI's working directory.

---

## Quick Start

### CLI — Generate a Metal Song

```bash
chameleondrummer generate --genre metal --style doom --tempo 75 --output doom_song.mid
```

### CLI — Generate a Rock Pattern with Bonham Style

```bash
chameleondrummer pattern --genre rock --style classic --drummer bonham --output bonham_verse.mid
```

### CLI — List Available Options

```bash
chameleondrummer list genres
chameleondrummer list styles --genre jazz
chameleondrummer list drummers
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

The `TPattern` also holds:
- `TimeSignature` (`TTimeSignature`): Numerator/denominator (default 4/4)
- `Subdivision` (`Integer`): Grid resolution (default 16 = 16th notes)
- `SwingRatio` (`Double`): Swing amount (0.0 = straight, the default; about 0.67 = classic 2:1 swing; 1.0 = 3:1). Applied by `TPattern.ApplySwing` after a bar is composed and before humanization. Patterns already on a triplet grid (jazz swing, funk shuffle, blues) and recorded GMD patterns are left alone.
- `Metadata` (`TDictionary<string, string>`): Key-value tags (e.g., `bars_to_fill`, `phrase_bars`)

### 2. Song and Section Model (`Song.pas`)

A `TSong` is a collection of `TSection` objects. Each section represents a musical part (verse, chorus, bridge, intro, outro, breakdown).

A `TSection` contains:
- `Name`: Section identifier
- `Pattern`: The base drum pattern
- `Bars`: Duration in bars
- `Variations`: List of `TPatternVariation` objects for variation selection
- `Fills`: List of `TFill` objects for fill placement
- `Segments`: `TSongSegment` objects for tempo/time-signature changes within the section
- `GrooveOffsetsMs`: Per-bar timing offsets (microtiming adjustments)

A `TSongSegment` allows a section to contain a mid-section tempo or meter change. This mirrors the `song_creator` REAPER tool's region-segment shape.

### 3. Bar-by-Bar Pattern Evolution (`ComposerV2.pas`)

The `TComposerV2` class implements Engine V2: full per-bar pattern generation with intensity curves, groove selection, drummer style application, and context-aware fills.

The pipeline for each bar:

1. **Intensity Point**: Calculate intensity based on the section's intensity curve (`icAscending`, `icDescending`, `icPlateau`, `icDipRise`, `icSteps`).
2. **Macro Phase**: Determine the macro-composer phase (`mpEstablish`, `mpMaintain`, `mpBuild`, `mpTurnaround`).
3. **Groove Selection**: Select a groove from the genre plugin's flavor library based on phase.
4. **Drummer Style**: Apply drummer modifications (`BehindBeatTiming`, `TripletVocabulary`, `HeavyAccents`, etc.).
5. **Bar Extraction**: Extract the current bar from the multi-bar phrase pattern.
6. **Parameter Modulation**: Apply velocity bias and dynamics scaling based on intensity and complexity.
7. **Physical Constraints**: Remove hits that are physically impossible (`TPatternFixer`).
8. **Humanization**: Apply timing and velocity variations (`TAdvancedHumanizer`).
9. **Fill Placement**: Insert fills at musical boundaries.
10. **Combine Bars**: Combine all bars into the final section pattern.

### 4. Intensity Curves (`ComposerV2.pas`)

Each section is assigned an intensity curve based on its musical context:

- `icAscending`: Intro sections (build up)
- `icDescending`: Outro sections (wind down)
- `icPlateau`: Chorus sections (maintain energy)
- `icDipRise`: Bridge sections (dip then rise)
- `icSteps`: Step-wise intensity changes

The intensity point (`IntensityPt`) is a value between 0.0 and 1.0 that drives velocity bias, dynamics scaling, and groove selection.

### 5. Macro Composer (`ComposerV2.pas`)

The `TMacroComposer` manages groove library phase cycling:

- `mpEstablish` (first 25%): Always the first groove flavor
- `mpMaintain` (middle 50%): Rotates through the library without repeating the previous groove
- `mpBuild` (75–95%): Pushes toward the densest groove
- `mpTurnaround` (last 5%): Random selection for transition

This ensures the song has a purposeful shape rather than random picks per phrase.

### 6. Groove Engine (`ComposerV2.pas`)

The `TGrooveEngine` calculates microtiming offsets per bar:

- `GetDrummerGrooveBias`: Per-drummer timing bias (e.g., Bonham = +25ms behind beat, Porcaro = -10ms ahead)
- `GetSectionGrooveContext`: Per-section context adjustments (e.g., chorus = +10ms, intro = -15ms)
- `GetBarOffsetMs`: Combines drummer bias, section context, and intensity-based modulation, bounded to ±25ms

### 7. Fill System (`ComposerV2.pas`)

The `TFillPicker` determines fill placement:

- Fills are placed at natural musical boundaries: before section end (`ABars - 2`), every 4 bars, midpoint, or with 30% random probability
- Fill types include: `tom_downfill`, `tom_upfill`, `blast_beat`, `ride_bell_sweep`, `snare_roll`, `cymbal_crash`
- Signature fills from drummer plugins are added when a drummer is specified

### 8. Humanization (`AdvancedHumanization.pas`)

The `TAdvancedHumanizer` applies context-aware timing and velocity variations:

- Timing variance: Small random offsets to beat positions (simulates human imperfection)
- Velocity variance: Small adjustments to velocities (simulates dynamic playing)
- Context parameters: Genre, style, section, complexity, intensity, tempo, and source random seed

### 9. Physical Constraints (`PhysicalConstraints.pas` / `PatternFixer.pas`)

The `TPatternFixer` ensures patterns are physically playable:

- No two hits on the same hand at the same instant
- Maximum 3 simultaneous hits
- No impossibly fast repeats on one limb
- Removes or adjusts hits that violate these rules

### 10. Plugin Architecture (`PluginRegistry.pas`, `DrumGenerator.pas`)

The system uses a plugin registry:

- `TPluginRegistry`: Stores genre and drummer plugins in dictionaries
- `TPluginManager`: Manages plugin discovery and loading
- `TGenrePlugin`: Interface for genre plugins (metal, rock, jazz, funk, electronic)
- `TDrummerPlugin`: Interface for drummer plugins (bonham, porcaro, weckl, etc.)

Each genre plugin provides:
- Supported styles
- Pattern generation methods per section (`_verse`, `_chorus`, etc.)
- Common fills
- Preferred drummers

Each drummer plugin provides:
- Compatible genres
- Style application (modifies patterns with drummer-specific techniques)
- Signature fills

### 11. Keymap System (`Kit.pas`)

The `TDrumKit` class loads MIDI note mappings from JSON files:

- `gm`: General MIDI mapping
- `ad2`: Addictive Drums 2 mapping
- `ezd3`: EZDrummer 3 mapping
- `xg`: XG Standard mapping

All instrument names and MIDI notes are data-driven. The `TInstrumentRegistry` manages instrument definitions.

### 12. MIDI Export (`MidiIO.pas`, `MidiParser.pas`)

The MIDI engine writes standard MIDI files with:
- Variable Length Quantity (VLQ) encoding for delta ticks
- Proper byte ordering (little-endian for MIDI headers)
- Note events with absolute time basis
- BPM and PPQ (pulses per quarter note) metadata

---

## The CLI Program

### Command Reference

```
Usage: chameleondrummer <command> [options]

Commands:
  generate  Generate a complete song (multi-bar pattern)
  pattern   Generate a single 1-4 bar pattern
  list      List available genres, styles, or drummers
  info      Show system information
  reaper    Create a REAPER project (sub-command: export)
  ardour    Create an Ardour session (sub-command: export)

Options:
  --genre <name>       Genre (e.g., metal, rock, jazz, funk)
  --style <name>       Style within genre (e.g., heavy, classic, swing)
  --tempo <bpm>        Tempo in BPM (default: genre/style value)
  --complexity <0-1>   Pattern complexity (default: 0.5)
  --humanization <0-1> Humanization intensity (default: 0.3)
  --swing <0-1>        Swing feel: 0 straight (default), 0.67 classic 2:1, 1 = 3:1
  --drummer <name>     Drummer style (e.g., bonham, peart, carey)
  --output <file>      Output MIDI file path
  --mapping <name>     Keymap to use: gm (default), ad2, ezd3, xg
  --sidecar <file>     Read section structure from sidecar JSON
  --song-map <file>    Read song map JSON for per-bar tempo/meter
  --write-timeline     Write timeline JSON after generation
  --list <type>        List: genres, styles, drummers
```

### Examples

**Generate a complete song:**

```bash
chameleondrummer generate --genre metal --style death --tempo 195 --drummer hoglan --mapping ad2 --output death_metal.mid
```

**Generate a single pattern:**

```bash
chameleondrummer pattern --genre jazz --style swing --output swing_verse.mid
```

**Create REAPER project:**

```bash
chameleondrummer reaper export --genre rock --style classic --drummer bonham --mapping gm --output rock_classic.rpp
```

**Create Ardour session:**

```bash
chameleondrummer ardour export --genre funk --style classic --mapping ezd3 --output funk_classic.ardour
```

---

## The GUI Program

### Interface Overview

The GUI (`chameleondrummer_gui.exe`) provides an interactive front end to the CLI engine.

**Main Controls:**

- **Mode Toggle**: Pattern mode (single pattern) vs. Song mode (multi-section song)
- **Genre Dropdown**: Metal, Rock, Jazz, Funk, Electronic
- **Style Dropdown**: Dynamically populated based on selected genre
- **Drummer Dropdown**: 17 drummer personalities
- **Mapping Dropdown**: GM, AD2, EZD3, XG
- **Tempo Spin Edit**: 0–300 BPM (0 = use genre default)
- **Complexity Slider**: 0–100 (mapped to 0.0–1.0)
- **Humanization Slider**: 0–100 (mapped to 0.0–1.0)
- **Export Dropdown**: MIDI only, MIDI + REAPER, MIDI + Ardour
- **Output File**: Filename for output
- **Generate Button**: Starts generation
- **Log Panel**: Displays CLI output
- **Status Label**: Shows current state

**Song Mode Section Management:**

In song mode, the form displays dynamic section controls:
- Section name dropdown (intro, verse, chorus, bridge, outro)
- Bar count spin edit (1–64)
- Delete button for each section
- Add section button
- Reset to default structure button

Default structures per genre:

| Genre | Sections | Bars |
|-------|----------|------|
| Metal | intro, verse, chorus, verse, chorus, bridge, chorus, outro | 4, 8, 8, 8, 8, 4, 8, 4 |
| Rock | intro, verse, chorus, bridge, chorus, outro | 4, 8, 8, 4, 8, 4 |
| Jazz | intro, verse, chorus, bridge, outro | 4, 8, 8, 4, 4 |
| Funk | intro, verse, chorus, bridge, chorus, outro | 4, 8, 8, 4, 8, 4 |
| Electronic | intro, verse, chorus, verse, bridge, outro | 4, 8, 8, 8, 4, 4 |

---

## Advanced Features

### Song Maps and Sidecars

The CLI supports reading external song structures:

**Sidecar (`--sidecar`)**: A JSON file defining sections and bar counts.

**Song Map (`--song-map`)**: A JSON file defining per-region segments with tempo and meter changes. This allows complex song structures with mid-section tempo changes.

**Timeline (`--write-timeline`)**: Writes a flat timeline JSON after generation, resolving tempo points and region boundaries.

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

## Troubleshooting

### Common Issues

**No output file generated:**
- Check that `--genre` is specified for `generate` and `pattern` commands.
- Verify the output directory exists and is writable.

**Unknown drummer error:**
- Check available drummers with `chameleondrummer list drummers`.
- Ensure the drummer name is lowercase.

**GUI does not generate:**
- Verify `chameleondrummer.exe` is in the same directory as the GUI executable.
- Check the log panel for CLI error messages.

**MIDI file plays incorrectly:**
- Verify the keymap (`--mapping`) matches your drum software.
- Check that tempo and time signature are appropriate for the genre/style.

---

## Appendix: Source Code Principles

### Design Patterns

- **Strategy Pattern**: Genre and drummer plugins implement strategy interfaces (`GenrePlugin`, `DrummerPlugin`)
- **Builder Pattern**: `PatternBuilder` provides fluent API for pattern creation
- **Factory Pattern**: `PluginManager` acts as factory for plugin instances
- **Composition over Inheritance**: Drummer modifications (`BehindBeatTiming`, `TripletVocabulary`, etc.) are composable

### Key Constants (`config/constants.py` equivalent in Pascal)

The Pascal code uses descriptive constants rather than magic numbers:
- `VELOCITY`: 40+ velocity constants (`KICK_SOFT`, `SNARE_ACCENT`, etc.)
- `TIMING`: 25+ timing constants (`QUARTER`, `EIGHTH`, `SIXTEENTH`, `TRIPLET`)
- `DEFAULTS`: 50+ default parameters (`TEMPO`, `COMPLEXITY`, `HUMANIZATION`)

### Pattern Template System (`patterns/templates.py` equivalent)

The `TemplateComposer` provides 8 reusable pattern templates:
- `BasicGroove`: Standard kick + snare + hi-hat patterns
- `DoubleBassPedal`: Continuous, gallop, and burst patterns
- `BlastBeat`: Traditional, hammer, and gravity blast beats
- `JazzRidePattern`: Swing ride patterns with accents
- `FunkGhostNotes`: Ghost note layers for funk grooves
- `CrashAccents`: Crash cymbal placement
- `TomFill`: Descending, ascending, and accent fills
- `TemplateComposer`: Combines multiple templates

### Drummer Modification Registry (`modifications/drummer_mods.py` equivalent)

12 composable modifications for authentic drummer techniques:
- `BehindBeatTiming`: Delays hits behind beat (Bonham, Chambers)
- `TripletVocabulary`: Triplet-based fills (Bonham)
- `GhostNoteLayer`: Subtle ghost notes (Porcaro, Weckl, Chambers)
- `LinearCoordination`: Removes simultaneous hits (Weckl)
- `HeavyAccents`: Increases accent contrast (metal drummers)
- `ShuffleFeelApplication`: Shuffle/swing feel (Porcaro)
- `FastChopsTriplets`: Fast technical fills (Chambers)
- `PocketStretching`: Subtle groove variations (Chambers)
- `MinimalCreativity`: Sparse, atmospheric approach (Roeder)
- `SpeedPrecision`: Consistent timing/velocity (Dee)
- `TwistedAccents`: Displaced accents (Dee)
- `MechanicalPrecision`: Extreme quantization (Hoglan)

---
