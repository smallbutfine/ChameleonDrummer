# ChameleonDrummer REAPER Integration Plan

## Core Constraints
- **No AI integration**
- **No engine changes to sidecar/JSON** - use existing CLI args like GUI
- **Only CLI additions**: `list-genres`, `list-styles`, `list-drummers`, `list-mappings` + `additive-rhythm` command
- **No Song Map, no Riff-Lock**

---

## 1. CLI Additions

```bash
# Existing list commands (for panel combos)
ChameleonDrummer list-genres --json
ChameleonDrummer list-styles --genre metal --json
ChameleonDrummer list-drummers --json
ChameleonDrummer list-mappings --json

# NEW: Additive Rhythm generation
ChameleonDrummer additive-rhythm --grouping "3-3-3-3-2-2" --grid 16 --tempo 120 \
  --drummer bonham --drummer-intensity 0.8 --output out.mid \
  [--write-timeline timeline.json]
```

**Output**: Standard MIDI file + optional `timeline.json` for REAPER tempo markers.

---

## 2. Engine Changes: Additive Rhythm Module

**New unit**: `src/AdditiveRhythm.pas`

```pascal
unit AdditiveRhythm;

interface

uses Classes, SysUtils, Pattern, time_signature;

type
  TAdditiveGroup = record
    Size: Integer;           // 2,3,4,5,6,7...
    IsExplicitBar: Boolean;  // terminated by '|'
  end;

  TAdditiveRhythm = record
    Groups: array of TAdditiveGroup;
    GridResolution: Integer;  // 4,8,16,32
    Tempo: Double;
  end;

  TAdditiveOptions = record
    Rhythm: TAdditiveRhythm;
    Drummer: String;
    DrummerIntensity: Double;
    Mapping: String;
  end;

function ParseGrouping(const S: String; out ARhythm: TAdditiveRhythm; 
  AGridResolution: Integer): Boolean;
function ResolveTimeSignatures(const ARhythm: TAdditiveRhythm): TTimeSignatureDynArray;
function GeneratePattern(const AOptions: TAdditiveOptions): TPattern;
function BuildTimelineJSON(const ARhythm: TAdditiveRhythm; ATempo: Double): String;

implementation
```

#### Parsing Rules
| Input | Groups | Bars | Time Signatures |
|-------|--------|------|-----------------|
| `3-3-3-3-2-2` | [3,3,3,3,2,2] | 6 | 6/8, 6/8, 6/8, 6/8, 4/8, 4/8 |
| `3-3-3|3-3-2` | [3,3,3|,3,3,2] | 2 | 9/8, 8/8 |
| `2+2+3|` | [2,2,3|] | 1 | 7/8 |
| `4|4|4` | [4|,4|,4|] | 3 | 4/4, 4/4, 4/4 |

- Runs of identical sizes without `|` → one bar per group
- `|` forces explicit bar boundary (heterogeneous bar)
- `+` is alias for `-` (visual grouping)

#### Pattern Generation
- **Kick**: On first step of each group (downbeat of each additive cell)
- **Snare**: On "backbeat" positions (middle of bar for even, offset for odd)
- **Hi-hat**: Continuous on grid resolution
- **Drummer styling**: Applied via existing `PluginManager.apply_drummer_style()`

---

## 3. Reaper Panel Architecture

| Module | Action |
|--------|--------|
| `job_runner.lua` | Reuse as-is |
| `settings.lua` | Reuse (ExtState: `chameleon_drummer`) |
| `options.lua` | New: calls CLI list commands |
| `sections.lua` | Adapt: `build_template_cmd` for our CLI |
| `step_editor.lua` | Reuse as-is |
| `additive_rhythm.lua` | **New**: adapted from midi-drums |
| `chameleon_panel.lua` | **4 tabs**: Song Sections, Additive Rhythm, Step Editor, Settings (+ Log) |

---

## 4. Additive Rhythm Tab (Lua)

**State variables**:
```lua
local ar_grouping = "3-3-3-3-2-2"
local ar_grid = "16"
local ar_tempo = "120"
local ar_drummer = ""
local ar_drummer_intensity = 1.0
local ar_mapping = "gm"
local ar_status = ""
```

**UI**:
- Grouping text input (with help popover explaining syntax)
- Grid combo: 4, 8, 16, 32
- Tempo input
- Drummer combo (optional) + intensity slider
- Mapping combo
- Generate button

**Generate action**:
```lua
local cmd = string.format(
  '"%s" additive-rhythm --grouping "%s" --grid %s --tempo %s --mapping "%s" --output "%s"%s%s',
  exe, ar_grouping, ar_grid, ar_tempo, ar_mapping, midi_out,
  (ar_drummer ~= "" and string.format(' --drummer "%s" --drummer-intensity %g', ar_drummer, ar_drummer_intensity) or ""),
  (ar_write_timeline and ' --write-timeline "' .. timeline_path .. '"' or "")
)
job_runner.start(cmd, "Additive Rhythm", function()
  -- Import MIDI
  sections.import_midi(midi_out)
  -- Apply timeline if generated
  if ar_write_timeline then
    local f = io.open(timeline_path, "r")
    if f then
      local content = f:read("*a"); f:close()
      local tempo_points, regions, color_groups = sections.parse_timeline(content)
      if tempo_points then sections.apply_timeline_to_reaper(tempo_points, regions, color_groups) end
    end
  end
  ar_status = "Done."
end)
```

---

## 5. Implementation Steps

### Phase 1: CLI List Commands (1-2 days)
Add to `CLIInterface.pas`:
- `list-genres [--json]`
- `list-styles --genre <genre> [--json]`
- `list-drummers [--json]`
- `list-mappings [--json]`

### Phase 2: Additive Rhythm Engine (3-4 days)
1. Create `src/AdditiveRhythm.pas` with:
   - `ParseGrouping()` - parser for box notation
   - `ResolveTimeSignatures()` - groups → time signatures
   - `GeneratePattern()` - kick/snare/hihat from groups
   - `BuildTimelineJSON()` - for REAPER tempo markers
2. Add `additive-rhythm` command to `CLIInterface.pas`
3. Register in `PluginRegistry` if needed

### Phase 3: Core Lua Modules (2-3 days)
1. Copy `job_runner.lua`, `settings.lua` (rename ExtState section)
2. Create `options.lua` - calls CLI list commands
3. Create `sections.lua` - adapt `build_template_cmd` for our CLI
4. Copy `step_editor.lua` (unchanged)
5. Create `additive_rhythm.lua` - adapted from midi-drums

### Phase 4: Main Panel (2-3 days)
Create `chameleon_panel.lua` with 4 tabs:
- **Song Sections** - genre/style/drummer/mapping/tempo/bars, Generate
- **Additive Rhythm** - grouping/grid/tempo/drummer, Generate (+ timeline checkbox)
- **Step Editor** - Load MIDI item, grid editor, Apply Drummer
- **Settings** - CLI path, defaults, Refresh Options
- **Log** - reused

### Phase 5: Testing (1-2 days)
- CLI list commands return valid JSON
- Additive rhythm generates correct time signatures
- MIDI imports + REAPER tempo markers created
- All tabs functional

---

## 6. File Structure

```
reaper_chameleon/
├── chameleon_panel.lua          # Main entry (4 tabs + Log)
├── job_runner.lua               # Reused
├── settings.lua                 # Reused (ExtState: chameleon_drummer)
├── options.lua                  # Calls CLI list-* --json
├── sections.lua                 # build_template_cmd for our CLI
├── step_editor.lua              # Reused
├── additive_rhythm.lua          # New: additive rhythm tab logic
└── README.md                    # Install instructions
```

---

## 7. Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1. CLI List Commands | 1-2 days | `list-* --json` working |
| 2. Additive Rhythm Engine | 3-4 days | `additive-rhythm` CLI command |
| 3. Core Lua Modules | 2-3 days | All .lua modules ready |
| 4. Main Panel | 2-3 days | `chameleon_panel.lua` functional |
| 5. Testing & Polish | 1-2 days | Verified in REAPER |
| **Total** | **9-14 days** | **Complete integration** |

---

## 8. Key Command Mapping

| Panel Action | CLI Command |
|--------------|-------------|
| Refresh Options | `list-genres --json`, `list-styles --genre X --json`, `list-drummers --json`, `list-mappings --json` |
| Generate Song Sections | `generate --genre X --style Y --mapping Z --tempo N --drummer D --drummer-intensity I --bars B --output file.mid` |
| Generate Additive Rhythm | `additive-rhythm --grouping "3-3-2" --grid 16 --tempo 120 --mapping gm --drummer bonham --drummer-intensity 0.8 --output file.mid [--write-timeline timeline.json]` |
| Apply Drummer (Step Editor) | `apply-drummer --input in.json --output out.json --drummer D --intensity I --timing-variance T --velocity-variance V` |