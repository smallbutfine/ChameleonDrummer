# Pascal Programs — Extensive Documentation

This document provides a comprehensive analysis of the two Pascal programs that make up the ChameleonDrummer system: the **CLI executable** and the **GUI application**. Both are Free Pascal / LCL-based implementations that wrap the same underlying engine (`ComposerV2`, `DrumGenerator`, `PluginRegistry`, `Kit`) to generate MIDI drum tracks across 5 genres, 38 styles, 15 drummer personalities, and multiple keymaps.

---

## Table of Contents

1. [Overview](#overview)
2. [Program 1: ChameleonDrummer (CLI)](#program-1-chameleondrummer-cli)
   - [File Structure](#file-structure)
   - [Entry Point](#entry-point)
   - [Command Parsing](#command-parsing)
   - [Command Dispatcher](#command-dispatcher)
   - [Command Implementations](#command-implementations)
   - [Key Data Structures](#key-data-structures)
3. [Program 2: ChameleonDrummerGUI (GUI)](#program-2-chameleondrummergui-gui)
   - [File Structure](#file-structure-2)
   - [Entry Point](#entry-point-2)
   - [Form Layout](#form-layout)
   - [Event Handlers](#event-handlers)
   - [Section Management](#section-management)
   - [Process Invocation Pattern](#process-invocation-pattern)
4. [Shared Architecture](#shared-architecture)
   - [Plugin System](#plugin-system)
   - [Engine Layer](#engine-layer)
   - [Kit & Keymap System](#kit--keymap-system)
   - [Export Bridges](#export-bridges)
5. [Build Configuration](#build-configuration)
6. [Usage Examples](#usage-examples)
7. [Error Handling & Exit Codes](#error-handling--exit-codes)
8. [Summary Comparison](#summary-comparison)

---

## Overview

Both programs share a common architecture but serve different purposes:

| Aspect | CLI (`ChameleonDrummer.lpr`) | GUI (`chameleondrummer_gui.lpr`) |
|--------|------------------------------|-----------------------------------|
| Entry point | `program ChameleonDrummer` | `program ChameleonDrummerGUI` |
| Purpose | Headless generation via command line | Interactive graphical interface |
| Output | Console text + MIDI files | Form controls + child process output |
| Complexity | ~46 lines | ~498 lines |
| Dependencies | `SysUtils, Classes, jsonparser, CLIInterface, Kit, PluginRegistry` | `Interfaces, Forms, MainFrm` |

The CLI is the primary engine driver; the GUI is a thin wrapper that collects user input and delegates to the CLI executable via `TProcess`.

---

## Program 1: ChameleonDrummer (CLI)

### File Structure

```
ChameleonDrummer.lpr          ← Project config (Free Pascal project file)
ChameleonDrummer.cfg         ← Compiler configuration
ChameleonDrummer.exe         ← Compiled executable

```

The `.lpr` file is an XML-based project descriptor (FPC version 12) that references:
- **Main unit**: `chameleondrummer_gui.lpr` (the actual program unit)
- **Secondary unit**: `MainFrm.pas` (the GUI form unit)
- **Search paths**: `../src` for source units, `lib/$(TargetCPU)-$(TargetOS)` for output
- **Optimization level**: 2 (standard optimization)
- **Debug info**: disabled (`-g- -gl-`)
- **Target**: `../chameleondrummer` (output binary name)

### Entry Point

```pascal
program ChameleonDrummer;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  jsonparser,
  CLIInterface, Kit, PluginRegistry;

var
  CLI: TCLIInterface;
  ExitCode: Integer;
  ArgCount: Integer;
  Args: specialize TArray<String>;
  I: Integer;

begin
  Randomize;

  // Parse command-line arguments from program parameters
  ArgCount := ParamCount;
  SetLength(Args, ArgCount + 1);
  Args[0] := ParamStr(0); // Program name

  for I := 1 to ArgCount do
    Args[I] := ParamStr(I);

  // Create and run CLI interface
  CLI := TCLIInterface.Create;
  try
    ExitCode := CLI.Run(ArgCount, Args);
  finally
    CLI.Free;
  end;

  Halt(ExitCode);
end.
```

**Key behaviors:**
1. Calls `Randomize` at startup for deterministic random number generation.
2. Builds an argument array from `ParamCount`/`ParamStr`.
3. Instantiates `TCLIInterface` (which internally creates `TDrumGenerator`).
4. Delegates all argument parsing and command dispatch to `CLI.Run()`.
5. Exits with the returned exit code via `Halt()`.

### Command Parsing

The `TCLIInterface.ParseArgs()` method handles a flat list of string arguments. It uses a sequential `while` loop with `if/else if` chains matching each known flag:

| Flag | Action |
|------|--------|
| `--genre <name>` | Sets `Result.Genre` (lowercased) |
| `--style <name>` | Sets `Result.Style` (lowercased) |
| `--tempo <bpm>` | Parses integer into `Result.Tempo` |
| `--complexity <0-1>` | Parses double into `Result.Complexity` |
| `--humanization <0-1>` | Parses double into `Result.Humanization` |
| `--swing <0-1>` | Parses double into `Result.Swing` (rejects non-numbers and values outside 0-1) |
| `--drummer <name>` | Sets `Result.Drummer` (lowercased) |
| `--output <file>` | Sets `Result.OutputFile` |
| `--mapping <name>` | Sets `Result.Mapping` (lowercased, default `'gm'`) |
| `--sidecar <file>` | Sets `Result.SidecarFile` |
| `--song-map <file>` | Sets `Result.SongMapFile` |
| `--write-timeline <path>` | Sets `Result.WriteTimelinePath` |
| `--preset-only` | Sets `Result.PresetOnly = True` |
| `--song` | Sets `Result.IsSongCommand = True` |
| `--list <type>` | Sets `Result.Command = 'list'` and `Result.ListType` |
| `--help` or `-h` | Prints usage and halts |
| `generate` or `pattern` | Sets `Result.Command` directly |
| `info` | Sets `Result.Command = 'info'` |
| `list` | Sets `Result.Command = 'list'`; checks next arg for type |
| `reaper` | Sets `Result.Command = 'reaper'`; checks next arg for subcommand |
| `ardour` | Sets `Result.Command = 'ardour'`; checks next arg for subcommand |

**Default values** are initialized before parsing:
- `Tempo`: 0 (meaning "use genre default")
- `Complexity`: 0.5
- `Humanization`: 0.3
- `Mapping`: `'gm'` (General MIDI)

If `--song` is used without a command, it defaults to `'generate'`.

### Command Dispatcher

```pascal
function TCLIInterface.Run(Argc: Integer; const Argv: specialize TArray<String>): Integer;
```

This method:
1. Fills the `TCLIArgs` record with parsed values.
2. If no command was specified, prints usage and returns exit code `-1`.
3. Dispatches based on `Args.Command`:
   - `'generate'` → `HandleGenerate()`
   - `'pattern'` → `HandlePattern()`
   - `'list'` → `HandleList()`
   - `'info'` → `HandleInfo()`
   - `'reaper'` → checks for `'export'` subcommand → `HandleReaperExport()`
   - `'ardour'` → checks for `'export'` subcommand → `HandleArdourExport()`
4. Returns `0` on success, `-2` on exception, `-1` on usage error.

All commands are wrapped in a `try/except` block that catches exceptions and prints `[Error] ClassName: Message`, returning exit code `2`.

### Command Implementations

#### `HandleGenerate`

Creates a complete multi-bar song using `FGenerator.CreateSong()`:

```pascal
Song := FGenerator.CreateSong(
  Args.Genre, Args.Style, Args.Tempo,
  nil,   // AStructure — use genre default
  DrumKit, // Pass pre-loaded keymap
  DrummerName, // ADrummer — pass directly to composer
  Args.Complexity,  // AComplexity
  0.6,              // ADynamics — default dynamics
  Args.Humanization // AHumanization
);
```

Then saves MIDI to `OutputFile` (auto-generated as `<genre>_<style>_<mapping>.mid` if not specified) and optionally writes a timeline JSON.

#### `HandlePattern`

Generates a single 1–4 bar pattern:

```pascal
Pattern := FGenerator.GeneratePattern(
  Args.Genre, 'verse', DrumKit, Args.Style);
```

Saves as `<genre>_<style>_pattern.mid` (or user-specified output). Tempo defaults to the genre/style default BPM if not provided.

#### `HandleList`

Displays available options based on `ListType`:
- `'genres'` — Lists all registered genres
- `'styles'` — Requires `--genre`; lists styles for that genre
- `'drummers'` — Lists all registered drummers

#### `HandleInfo`

Prints system information:
- Number of available genres
- Number of available drummers
- Keymap directory location

#### `HandleReaperExport`

Creates a complete song, saves MIDI, then creates a REAPER project file (`.rpp`) alongside the MIDI:

```pascal
Bridge := TReaperBridge.Create;
if Bridge.CreateFromSong(Song, MidiFile) then
  Writeln('REAPER project exported to:', RppFile);
```

#### `HandleArdourExport`

Creates a complete song, saves MIDI, then creates an Ardour session directory (`.ardour`) alongside the MIDI:

```pascal
Bridge := TArdourBridge.Create;
if Bridge.CreateFromSong(Song, MidiFile, SessionDir) then
  Writeln('Ardour session created:', SessionDir);
```

### Key Data Structures

```pascal
TCLIArgs = record
  Command: String;        // 'generate', 'pattern', 'list', 'info', 'reaper', 'ardour'
  SubCommand: String;      // e.g., 'export' for reaper/ardour
  Genre: String;
  Style: String;
  Tempo: Integer;
  Complexity: Double;     // 0.0–1.0
  Humanization: Double;    // 0.0–1.0
  Drummer: String;
  OutputFile: String;
  Mapping: String;        // 'gm', 'ad2', 'ezd3', 'xg'
  SidecarFile: String;
  SongMapFile: String;
  WriteTimelinePath: String;
  PresetOnly: Boolean;
  ListType: String;        // 'genres', 'styles', 'drummers'
  IsSongCommand: Boolean;  // --song flag
end;
```

---

## Program 2: ChameleonDrummerGUI (GUI)

### File Structure

```
gui/chameleondrummer_gui.lpr    ← Project config (FPC version 12)
gui/chameleondrummer_gui.lpi    ← Linker input (references MainFrm.pas)
gui/MainFrm.pas                 ← GUI form unit (~498 lines)
gui/TMainForm.lfm               ← Resource file (compiled form layout)
```

The `.lpr` file is a minimal project descriptor:
- **Required package**: LCL ( Lazarus Component Library)
- **Units**: `chameleondrummer_gui.lpr` (main) + `MainFrm.pas` (form)
- **Target**: `../chameleondrummer_gui`
- **Search paths**: `../src` for source units
- **Optimization**: level 2
- **Debug**: disabled

### Entry Point

```pascal
program ChameleonDrummerGUI;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, MainFrm;

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
```

**Key behaviors:**
1. Initializes the LCL application framework.
2. Creates the main form `TMainForm` as `MainForm`.
3. Runs the event loop (`Application.Run`), which blocks until the form closes.

### Form Layout

The form (`TMainForm`) contains these visual components organized into three group boxes:

#### GroupBox: `gbSong` (Song Mode)

| Component | Type | Description |
|-----------|------|-------------|
| `rbPattern` | TRadioButton | Toggle between pattern mode and song mode |
| `rbSong` | TRadioButton | Toggle to song mode |
| `lblGenre` | TLabel | "Genre" label |
| `cbGenre` | TComboBox | Genre dropdown (metal, rock, jazz, funk, electronic) |
| `lblStyle` | TLabel | "Style" label (changes to "Pattern" in pattern mode) |
| `cbStyle` | TComboBox | Style dropdown (populated dynamically per genre) |
| `lblDrummer` | TLabel | "Drummer" label |
| `cbDrummer` | TComboBox | Drummer dropdown (17 entries, hardcoded) |
| `lblMapping` | TLabel | "Mapping" label |
| `cbMapping` | TComboBox | Keymap dropdown (gm, ad2, ezd3, xg) |
| `gbPerformance` | TGroupBox | Performance parameters |
| `lblTempo` | TLabel | "Tempo" label |
| `seTempo` | TSpinEdit | Tempo spin edit (0–300) |
| `lblTempoHint` | TLabel | Tempo hint label |
| `lblComplexity` | TLabel | "Complexity" label |
| `tbComplexity` | TTrackBar | Complexity slider (0–100, mapped to 0.0–1.0) |
| `lblComplexityValue` | TLabel | Complexity value display (e.g., "0.50") |
| `lblHumanization` | TLabel | "Humanization" label |
| `tbHumanization` | TTrackBar | Humanization slider (0–100, mapped to 0.0–1.0) |
| `lblHumanizationValue` | TLabel | Humanization value display |
| `gbOutput` | TGroupBox | Output options |
| `lblExport` | TLabel | "Export" label |
| `cbExport` | TComboBox | Export format (MIDI only, MIDI+REAPER, MIDI+Ardour) |
| `lblFile` | TLabel | "File" label |
| `edOutput` | TEdit | Output filename text field (default: "song") |
| `btnBrowse` | TButton | Browse button for output file selection |
| `chkOpenFolder` | TCheckBox | "Open folder after generation" checkbox |
| `lblHint` | TLabel | Hint label |
| `btnGenerate` | TButton | Generate button |
| `btnOpenFolder` | TButton | Open folder button |
| `gbLog` | TGroupBox | Generation log panel |
| `memLog` | TMemo | Multi-line log display |
| `lblStatus` | TLabel | Status indicator ("Ready", etc.) |
| `pbProgress` | TProgressBar | Progress bar (unused in current code) |

#### Dynamic Section Controls (added at runtime)

When in song mode, the form dynamically creates section controls inside `gbSong`:
- `lblName` (TLabel): "Section N"
- `cmbSection` (TComboBox): Section name dropdown (intro, verse, chorus, bridge, outro)
- `seBars` (TSpinEdit): Bar count (1–64)
- `btnDelete` (TButton): Delete section button ("-")

Plus two static buttons:
- `btnAddSection`: Add section button
- `btnResetStructure`: Reset to default structure button

### Event Handlers

| Handler | Trigger | Action |
|---------|---------|--------|
| `FormCreate` | Form initialization | Populates dropdowns, sets defaults, calls `FillStyles`, `ResetToDefaultStructure`, logs startup message |
| `rgModeChange` | Radio button toggle | Switches between pattern/song mode; populates style dropdown accordingly; hides/shows section controls |
| `cbGenreChange` | Genre dropdown change | Refreshes styles for new genre; resets section structure if in song mode |
| `tbComplexityChange` | Complexity slider change | Updates value label |
| `tbHumanizationChange` | Humanization slider change | Updates value label |
| `btnGenerateClick` | Generate button click | Builds command-line args and spawns `chameleondrummer.exe` via `TProcess` |
| `btnBrowseClick` | Browse button click | Opens `TSaveDialog` for output file selection |
| `btnOpenFolderClick` | Open folder button click | Opens output directory in Explorer |
| `mnuQuitClick` | Quit menu item | Closes the form |
| `mnuAboutClick` | About menu item | Shows about dialog |

### Section Management

The form maintains two parallel dynamic arrays:

```pascal
FSectionNames: TStrDynArray;   // Array of section name strings
FSectionBars: TIntDynArray;     // Array of bar counts per section
```

**Default structures per genre** (set by `ResetToDefaultStructure`):

| Genre | Sections | Bars |
|-------|----------|------|
| Metal | intro, verse, chorus, verse, chorus, bridge, chorus, outro | 4, 8, 8, 8, 8, 4, 8, 4 |
| Rock | intro, verse, chorus, bridge, chorus, outro | 4, 8, 8, 4, 8, 4 |
| Jazz | intro, verse, chorus, bridge, outro | 4, 8, 8, 4, 4 |
| Funk | intro, verse, chorus, bridge, chorus, outro | 4, 8, 8, 4, 8, 4 |
| Electronic | intro, verse, chorus, verse, bridge, outro | 4, 8, 8, 8, 4, 4 |

Users can add/remove sections dynamically via the add/delete buttons.

### Process Invocation Pattern

When the user clicks "Generate", the form constructs a command-line invocation of the standalone CLI executable:

```pascal
with TProcess.Create(nil) do try
  Executable := ExtractFilePath(ParamStr(0)) + 'chameleondrummer.exe';
  Options := [poUsePipes, poStderrToOutput, poNoConsole];
  Parameters.Add('generate');
  Parameters.Add('--genre'); Parameters.Add(Genre);
  Parameters.Add('--style'); Parameters.Add(Style);
  Parameters.Add('--output'); Parameters.Add(OutputFile);
  // ... additional parameters ...
  Execute;
finally Free; end;
```

**Parameter mapping from UI to CLI:**

| UI Control | CLI Flag | Value Source |
|------------|----------|-------------|
| Genre dropdown | `--genre` | `SelectedGenre` |
| Style dropdown | `--style` | `SelectedStyle` |
| Drummer dropdown | `--drummer` | `cbDrummer.Text` |
| Mapping dropdown | `--mapping` | `cbMapping.Text` |
| Tempo spin edit | `--tempo` | `seTempo.Value` (only if > 0) |
| Complexity trackbar | `--complexity` | `tbComplexity.Position / 100` |
| Humanization trackbar | `--humanization` | `tbHumanization.Position / 100` |
| Swing trackbar | `--swing` (only if > 0) | `tbSwing.Position / 100` |
| Export combo | `--reaper` or `--ardour` | Based on `cbExport.ItemIndex` |
| Output edit | `--output` | `edOutput.Text` |

The process is configured with:
- `poUsePipes`: Capture stdout/stderr
- `poStderrToOutput`: Merge stderr into stdout for logging
- `poNoConsole`: Suppress console window on Windows

After execution, the form displays the child process output in the log memo.

---

## Shared Architecture

Both programs share the same core engine layer. Here is how the pieces fit together:

### Plugin System

The `TDrumGenerator.LoadPlugins()` method registers all plugins at construction time:

**Genre Plugins (5 genres × 7 styles = 35 styles):**

| Genre | Styles | Preferred Drummers |
|-------|--------|-------------------|
| Metal | heavy, death, power, progressive, thrash, doom, breakdown | bonham, roeder, dee, hoglan, peart, carey, watts, haake, doomblues |
| Rock | classic, blues, alternative, progressive, punk, hard, pop | bonham, porcaro, weckl, chambers, dee, rich, copeland, smith, moon, watts, doomblues |
| Jazz | swing, bebop, fusion, latin, ballad, hard_bop, contemporary | weckl, chambers, rich, halpern |
| Funk | classic, pfunk, shuffle, new_orleans, fusion, minimal, heavy | porcaro, chambers, copeland, smith, moon |
| Electronic | house, techno, drum_and_bass, dubstep | (none) |

**Drummer Plugins (17 total):**

bonham, porcaro, weckl, chambers, roeder, dee, hoglan, peart, rich, copeland, carey, smith, moon, watts, haake, halpern, doomblues

Each drummer declares compatible genres. When no drummer is specified, the engine auto-selects from the genre's preferred drummers.

### Engine Layer

The composition pipeline flows through these stages:

```
Genre Plugin → Section Flavors → GMD Pattern Library → Bar Selection →
Drummer Style → Groove Engine → Intensity Modulation → Physical Constraints →
Humanization → Fill Placement → Combine Bars → Section Assembly →
Groove Offsets → Song Assembly
```

Key classes involved:
- **`TComposerV2`**: Bar-by-bar composition engine with macro-phase groove rotation, intensity curves, fill picking, and timing offsets
- **`TBarSelector`**: Applies velocity bias and dynamics scaling per bar
- **`TFillPicker`**: Determines fill placement and type (tom downfill, blast beat, ride bell sweep, snare roll, cymbal crash)
- **`TGrooveEngine`**: Calculates microtiming offsets per bar based on drummer bias and section context
- **`TMacroComposer`**: Manages groove library phase cycling (establish → maintain → build → turnaround)
- **`TAdvancedHumanizer`**: Applies context-aware timing/velocity humanization
- **`TPatternFixer`**: Enforces physical playability constraints (no simultaneous hits, max 3 simultaneous, etc.)

### Kit & Keymap System

The `TDrumKit` class loads keymaps dynamically from JSON files in `midi_drums/mappings/`. Available keymaps include:
- `gm` — General MIDI (default)
- `ad2` — Addictive Drums 2
- `ezd3` — EZDrummer 3
- `xg` — XG Standard

All MIDI note mappings are data-driven; no instrument names are hardcoded.

### Export Bridges

Two bridge classes handle DAW export:
- **`TReaperBridge`**: Creates `.RPP` REAPER project files from song sections
- **`TArdourBridge`**: Creates `.ardour` session directories from song sections

Both bridges take a `TSong` object and its MIDI file path as input.

---

## Build Configuration

### CLI Build (`ChameleonDrummer.lpr`)

```xml
<ProjectOptions>
  <Version Value="12"/>
  <General>
    <SessionStorage Value="InProjectDir"/>
    <MainUnit Value="0"/>
    <IconPath Value="./"/>
    <TargetFileExt Value=""/>
  </General>
  <BuildModes Count="1">
    <Item1 Name="default" Default="True"/>
  </BuildModes>
  <PublishOptions>
    <Version Value="2"/>
    <DestinationDirectory Value="$(ProjPath)/published/"/>
  </PublishOptions>
  <RunParams>
    <FormatVersion Value="2"/>
    <Modes Count="1">
      <Mode0 Name="default"/>
    </Modes>
  </RunParams>
  <RequiredPackages Count="1">
    <Item1>
      <PackageName Value="LCL"/>
    </Item1>
  </RequiredPackages>
  <Units Count="2">
    <Unit0>
      <Filename Value="chameleondrummer_gui.lpr"/>
      <IsPartOfProject Value="True"/>
      <UnitName Value="ChameleonDrummerGUI"/>
    </Unit0>
    <Unit1>
      <Filename Value="MainFrm.pas"/>
      <ComponentName Value="MainForm"/>
      <IsPartOfProject Value="True"/>
      <ResourceFilename Value="TMainForm.lrs"/>
      <UnitName Value="MainFrm"/>
    </Unit1>
  </Units>
</ProjectOptions>
```

### GUI Build (`gui/chameleondrummer_gui.lpr`)

Minimal project descriptor with only the LCL package required. The form resource file `TMainForm.lfm` contains the compiled layout of all UI components.

### Build Commands

```bash
# Build CLI executable
lazbuild ChameleonDrummer.lpr

# Build GUI executable
lazbuild gui/chameleondrummer_gui.lpi
```

---

## Usage Examples

### CLI Examples

```bash
# Generate a complete metal song
chameleondrummer generate --genre metal --style doom --tempo 75

# Generate with Bonham drummer
chameleondrummer generate --genre rock --style classic --drummer bonham --output rock.mid

# List available genres
chameleondrummer list genres

# List drummers
chameleondrummer list drummers

# Generate a single pattern
chameleondrummer pattern --genre jazz --style swing --output swing.mid

# Create REAPER project
chameleondrummer reaper --genre metal --style death --mapping ad2 --output death_metal.rpp

# Create Ardour session
chameleondrummer ardour --genre funk --style classic --mapping gm --output funk_classic.ardour

# Show help
chameleondrummer --help
```

### GUI Examples

1. Launch the GUI executable.
2. Select a genre from the dropdown (metal, rock, jazz, funk, electronic).
3. Select a style from the dropdown (auto-populated per genre).
4. Optionally select a drummer and keymap.
5. Set tempo (0–300), complexity (0–100), and humanization (0–100) sliders.
6. Choose export format (MIDI only, MIDI + REAPER, MIDI + Ardour).
7. Click "Generate" — the GUI spawns `chameleondrummer.exe` with the appropriate arguments.
8. View generation progress in the log memo.

---

## Error Handling & Exit Codes

The CLI uses a consistent exit code scheme:

| Exit Code | Meaning |
|-----------|---------|
| `0` | Success |
| `-1` | Usage error (no command specified, unknown command) |
| `-2` | Runtime exception caught by `try/except` |
| `2` | Exception propagated to caller (e.g., `Halt(ExitCode)` in entry point) |

The GUI does not use exit codes directly — it captures the child process's exit code and displays log messages from the child's stdout/stderr.

---

## Summary Comparison

| Feature | CLI | GUI |
|---------|-----|-----|
| Lines of code | ~46 | ~498 |
| User interaction | Command-line arguments | Graphical form controls |
| Parameter entry | Flags and values | Dropdowns, sliders, spin edits |
| Section customization | Not available | Add/remove sections dynamically |
| Real-time feedback | Console output | Log memo panel |
| Export options | `--reaper`, `--ardour` flags | Dropdown selection |
| Process model | Single process | Parent-child (GUI spawns CLI) |
| Shared engine | Yes (same `TDrumGenerator`) | Yes (same `TCLIInterface`) |
| Plugin discovery | Via `PluginRegistry` | Hardcoded in `FormCreate` |
| Keymap selection | `--mapping` flag | Dropdown selection |
| Complexity control | `--complexity` flag | Trackbar slider |
| Humanization control | `--humanization` flag | Trackbar slider |

Both programs ultimately delegate to the same `TCLIInterface` for all generation logic, ensuring feature parity between the two front ends. The GUI adds interactive convenience (dropdowns, sliders, log display, section management) while the CLI provides scripting and automation capabilities.
