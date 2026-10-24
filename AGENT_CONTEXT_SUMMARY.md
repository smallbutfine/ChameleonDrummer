# ChameleonDrummer GUI — State Summary for Context Compaction

## Architecture

Two independent Pascal programs in `B:\dev\github\ChameleonDrummer`:

1. **`gui/chameleondrummer_gui.exe`** — Lazarus GUI, CLI wrapper calling the standalone Pascal CLI
2. **`chameleondrummer.exe`** — standalone Pascal CLI that performs actual drum generation from embedded plugin code

The Python source in `midi-drums/` is **reference only**. All values come from the Pascal CLI source (`B:\dev\github\midi-drums`). The GUI never calls Python and never discovers plugins. All dropdown values are hardcoded constants mirroring the Pascal CLI.

## Form Layout (ClientHeight=655, ClientWidth=960)

### Menu Bar
- File → Exit
- Help → About (shows version string)

### Left Column — gbSong (Left=12, Top=21, Width=396)
- **Pattern** radio button: Top=9 inside gbSong (shifted up 15px from original 24)
- **Song** radio button: Top=9 inside gbSong (unchanged — overlaps Pattern; needs vertical offset fix)
- Genre dropdown: hardcoded 5 genres (metal, rock, jazz, funk, electronic)
- Style dropdown: filled dynamically by genre via `FillStyles()`, or pattern types in Pattern mode
- Drummer dropdown: 17 drummers hardcoded (bonham, porcaro, weckl, chambers, roeder, dee, hoglan, peart, rich, copeland, carey, smith, moon, watts, haake, halpern, doomblues)
- Keymap dropdown: gm, ad2, ezd3, xg
- Section List (Song mode only): dynamic rows below keymap — each row = section name combobox + bars spinedit + delete button. Created at runtime by `BuildSectionControls()`, hidden in Pattern mode

### Right Column
- **gbOutput** (Left=420, Top=21): Export mode, filename, browse button
- **gbPerformance** (Left=420, Top=245): Tempo SpinEdit (0-300), Complexity TrackBar (0-100), Humanization TrackBar (0-100)
- **btnGenerate** / **btnOpenFolder** buttons (Top=413)

### Bottom
- **gbLog**: scrollable memo with timestamped CLI log lines
- **lblStatus**: "Ready" status text — fixed with explicit Font.Color=clWindowText for visibility
- **pbProgress**: hidden progress bar

## Mode Switching

| Aspect | Pattern Mode | Song Mode |
|--------|-------------|-----------|
| cbStyle contents | 7 pattern types (BasicGroove, DoubleBassPedal, BlastBeat, JazzRidePattern, FunkGhostNotes, CrashAccents, TomFill) | Genre-specific styles from Pascal CLI constants |
| Section list | Hidden | Shown/hidden dynamically |
| CLI command | `chameleondrummer.exe pattern --genre X --style Y --output Z [--tempo N]` | `chameleondrummer.exe generate --genre X --style Y --drummer D --mapping M --output Z [--tempo N] --complexity C --humanization H [--reaper|--ardour]` |
| Extra params sent | Only tempo | Drummer, keymap, complexity, humanization, export flag |

## Dynamic Section Controls

Created by `BuildSectionControls()` at Y=200 inside gbSong. Each row:
- TLabel caption "Section N" (Left=12)
- TComboBox for section type — intro/verse/chorus/bridge/outro (Left=80, Width=180)
- TSpinEdit for bar count 1-64 (Left=270, Width=60)
- TButton "-" delete (Left=340, Width=28)

Cleanup in `BuildSectionControls()` frees by prefix matching: secCmb*, secSpn*, secDel* buttons, Section labels, btnAddSection, btnResetStructure.

## Technical Notes

- gbLog height: 140px, memo height: 110px
- All Sender parameters have "not used" hints (kept for LCL compatibility)
- ExportMIDI constant is unused in code
- `AnsiStartsStr` requires StrUtils unit (used throughout cleanup logic)
- DoubleBuffered and Application.ProcessMessages used in Song mode switch to prevent control flash
- Section controls placed at Y=200 relative to gbSong (below keymap dropdown)
- btnAddSection (+ Add Section) and btnResetStructure (Reset to Default) appended after section rows

## Known Issues
- rbPattern and rbSong overlap at the same Top position inside gbSong — both at Top=9. They need vertical offset (Song should be below Pattern).
- No scrolling for section list if many sections exceed groupbox bounds

## Recent Changes
- Added menu bar with File/Help menus
- Moved gbPerformance below gbOutput in right column
- Shifted all controls up 15px, ClientHeight reduced from 670→655
- Only rbPattern radio button moved up (Top: 24→9); rbSong unchanged at Top=9 — they now overlap
- Fixed lblStatus visibility with explicit Font.Color and Alignment properties
- Removed "Section List" label; section rows start directly below keymap dropdown
- Added chameleondrummer_gui.exe to installer.iss file list

## Build Status
- Clean build: `./build_gui.bat` in `gui/` directory
- 0 compiler errors, ~13-15 harmless hints
- Version: 1.0.643
- Compiled exe at: `B:\dev\github\ChameleonDrummer\chameleondrummer_gui.exe`

## Files Modified Recently
- `gui/TMainForm.lfm` — form layout, menu, all Top positions
- `gui/MainFrm.pas` — event handlers, FillStyles, BuildSectionControls, rgModeChange, btnGenerateClick, mnuQuitClick, mnuAboutClick
- `installer/installer.iss` — added chameleondrummer_gui.exe to file list
