# Modularity Suggestions — Patterns, Fills, and Structures

**Status:** Design proposal for externalizing pattern/fill/structure data  
**Target:** Free Pascal / Lazarus (LCL) environment  
**Formats discussed:** INI, JSON, plain text / CSV  
**Scope:** Pattern templates, fill library, drummer modifications, genre configurations, section structures, intensity curves, groove profiles

---

## 1. Executive Summary — What Should Be Modular?

From a drummer's perspective, the engine currently hardcodes too much inside Pascal source files (`patterns/templates.py` equivalent in `src/patterns_templates.pas`, `modifications/drummer_mods.pas`, `ComposerV2.pas` fill picker, `DrumGenerator.pas` plugin registry). The following elements should be loadable from external files so users can extend the system without recompiling:

| Element | Current State | Should Be External? | Best Format | Reason |
|---------|--------------|---------------------|-------------|--------|
| Pattern templates (BasicGroove, BlastBeat, etc.) | Hardcoded in `patterns/templates.py` (Python) / `src/patterns_templates.pas` (Pascal) | **Yes** | JSON | Structured beat lists with instruments, velocities, positions |
| Fill patterns (tom_downfill, blast_beat, etc.) | Hardcoded in `ComposerV2.pas` lines 226–288 | **Yes** | JSON | Same structure as patterns; needs instrument names and velocities |
| Drummer modifications (BehindBeatTiming, etc.) | Hardcoded in `modifications/drummer_mods.py` / `src/DrummerMods.pas` | **Yes** | INI + JSON | INI for parameters (delay_ms, probability); JSON for beat-level rules |
| Genre style configurations (metal/death, rock/classic) | Hardcoded in `DrumGenerator.pas` LoadPlugins() | **Partial** | INI | Style names, default BPM, preferred drummers |
| Section structures (intro/verse/chorus) | Hardcoded in `MainFrm.pas` ResetToDefaultStructure() | **Yes** | JSON | Named sections with bar counts; supports song maps |
| Intensity curves (ascending, descending, plateau) | Hardcoded in `ComposerV2.pas` GetIntensityPt() | **Yes** | JSON | Curve type + interpolation points |
| Groove profiles (Bonham +25ms, Porcaro -10ms) | Hardcoded in `ComposerV2.pas` GetDrummerGrooveBias() | **Yes** | INI | Simple key-value: drummer = offset_ms |
| Keymap mappings (gm, ad2, ezd3, xg) | Already JSON in `midi_drums/mappings/` | **Already done** | JSON | Confirmed working |
| Signature fills per drummer | Hardcoded in drummer plugin `.pas` files | **Yes** | JSON | Pattern objects with metadata |

---

## 2. INI vs. JSON vs. Text — Pascal-Specific Analysis

### 2.1 INI (`TIniFile` / `TIniFile` from `IniFiles` unit)

**Pros for Pascal:**
- Native FPC/LCL class — no external dependencies
- Simple syntax: `[Section]` + `Key=Value`
- Supports comments with `;`
- Easy to edit by hand
- Good for flat parameter lists (drummer profiles, genre defaults)

**Cons:**
- No nested structures (no arrays of objects)
- No typed arrays — everything is string
- No standard for lists (must use `Key=Value1,Value2` or numbered keys `Key1=...`)
- No native JSON-like nesting for patterns with beat lists

**Best for:** Drummer profiles, genre defaults, groove offsets, simple configuration

### 2.2 JSON (`fpjson` — already used in `Kit.pas`, `MidiIO.pas`)

**Pros:**
- Already integrated (`fpjson` unit used for keymap loading)
- Supports nested objects, arrays, typed values (numbers, booleans, strings)
- Standard format — can be edited with any JSON editor
- Perfect for patterns (array of beats with position/instrument/velocity)
- Perfect for section structures (array of section objects)

**Cons:**
- Requires `fpjson` unit (already available)
- Slightly more verbose syntax
- No native comments (must use `//` in some parsers, but `fpjson` ignores unknown fields)

**Best for:** Pattern templates, fill patterns, section structures, intensity curves, signature fills

### 2.3 Plain Text / CSV

**Pros:**
- Simplest possible format
- Easy to generate from spreadsheets
- Good for simple lists (style names, drummer names)

**Cons:**
- No structure — must define parsing rules
- Fragile (whitespace-sensitive)
- No standard for nested data

**Best for:** Simple lists, quick edits, import from external tools

### 2.4 Recommendation — Hybrid Approach

Use **INI for flat parameters**, **JSON for structured data**:

```
config/
  drummer_profiles.ini      ← INI: Bonham=+25ms, Porcaro=-10ms
  genre_defaults.ini        ← INI: metal/death=195bpm, rock/classic=110bpm
  patterns/
    basic_groove.json       ← JSON: beat array
    blast_beat.json         ← JSON: beat array
    tom_downfill.json       ← JSON: beat array
  fills/
    blast_beat.json         ← JSON: fill pattern
    snare_roll.json         ← JSON: fill pattern
  sections/
    metal_default.json      ← JSON: section array
    rock_default.json       ← JSON: section array
  curves/
    ascending.json          ← JSON: curve points
    descending.json         ← JSON: curve points
  modifications/
    behind_beat.ini         ← INI: max_delay_ms=25.0, intensity_scale=0.7
    triplet_vocab.ini       ← INI: triplet_probability=0.4
```

---

## 3. Detailed Format Proposals

### 3.1 Pattern Template — JSON Format

```json
{
  "name": "BasicGroove",
  "description": "Standard 4/4 rock groove with kick, snare, hi-hat",
  "time_signature": {"numerator": 4, "denominator": 4},
  "bars": 2,
  "beats": [
    {"position": 0.0, "instrument": "kick", "velocity": 105, "duration": 0.25, "accent": false, "ghost": false},
    {"position": 0.5, "instrument": "hihat_closed", "velocity": 80, "duration": 0.25, "accent": false, "ghost": false},
    {"position": 1.0, "instrument": "snare_rimshot_open_hit", "velocity": 110, "duration": 0.25, "accent": true, "ghost": false},
    {"position": 1.5, "instrument": "hihat_closed", "velocity": 80, "duration": 0.25, "accent": false, "ghost": false},
    {"position": 2.0, "instrument": "kick", "velocity": 105, "duration": 0.25, "accent": false, "ghost": false},
    {"position": 2.5, "instrument": "hihat_closed", "velocity": 80, "duration": 0.25, "accent": false, "ghost": false},
    {"position": 3.0, "instrument": "snare_rimshot_open_hit", "velocity": 110, "duration": 0.25, "accent": true, "ghost": false},
    {"position": 3.5, "instrument": "hihat_closed", "velocity": 80, "duration": 0.25, "accent": false, "ghost": false}
  ],
  "metadata": {
    "genre": "rock",
    "style": "classic",
    "complexity": 0.5
  }
}
```

**Notes:**
- `instrument` uses the same names as `TInstrumentRegistry` (loaded from keymap JSON)
- `position` is in beats (0.0 = bar start)
- `duration` is in beats (0.25 = 16th note)
- `accent` and `ghost` are booleans
- `metadata` allows filtering by genre/style

### 3.2 Fill Pattern — JSON Format

```json
{
  "name": "TomDownfill",
  "description": "Descending tom fill: tom_4 → tom_3 → tom_2 → tom_1",
  "bars": 1,
  "beats": [
    {"position": 0.0, "instrument": "tom_4_open_hit", "velocity": 95, "duration": 0.25},
    {"position": 1.0, "instrument": "tom_3_open_hit", "velocity": 90, "duration": 0.25},
    {"position": 2.0, "instrument": "tom_2_open_hit", "velocity": 85, "duration": 0.25},
    {"position": 3.0, "instrument": "tom_1_open_hit", "velocity": 105, "duration": 0.25, "accent": true}
  ],
  "metadata": {
    "fill_type": "tom_downfill",
    "genre_compatible": ["metal", "rock", "funk"]
  }
}
```

### 3.3 Section Structure — JSON Format

```json
{
  "name": "Metal_Death_Default",
  "genre": "metal",
  "style": "death",
  "tempo": 195,
  "time_signature": [4, 4],
  "sections": [
    {"name": "intro", "bars": 4, "pattern_template": "BasicGroove", "complexity": 0.3},
    {"name": "verse", "bars": 8, "pattern_template": "DoubleBassPedal", "complexity": 0.7},
    {"name": "chorus", "bars": 8, "pattern_template": "BlastBeat", "complexity": 0.9},
    {"name": "bridge", "bars": 4, "pattern_template": "BasicGroove", "complexity": 0.5},
    {"name": "chorus", "bars": 8, "pattern_template": "BlastBeat", "complexity": 0.9},
    {"name": "outro", "bars": 4, "pattern_template": "BasicGroove", "complexity": 0.4}
  ],
  "fill_policy": {
    "frequency": "phrase_end",
    "preferred_fills": ["TomDownfill", "BlastBeat"],
    "drummer_specific": true
  }
}
```

### 3.4 Drummer Profile — INI Format

```ini
[Bonham]
name = John Bonham
genres = rock, metal, blues
groove_bias_ms = 25.0
groove_direction = behind
triplet_probability = 0.4
accent_boost = 15
behind_beat_max_delay = 25.0
signature_fills = MobyDick, TripletFill, BehindBeatAccent
compatible_styles = classic, heavy, death, blues

[Porcaro]
name = Jeff Porcaro
genres = rock, funk, pop
groove_bias_ms = -10.0
groove_direction = ahead
shuffle_feel = 0.6
ghost_note_probability = 0.3
signature_fills = ShuffleFill, GhostNoteLayer, StudioPrecision
compatible_styles = classic, shuffle, fusion, pop

[Hoglan]
name = Gene Hoglan
genres = metal, doom
groove_bias_ms = -2.0
groove_direction = locked
mechanical_precision = 0.95
blast_beat_intensity = 0.9
signature_fills = BlastBeat, MechanicalFill, ProgressiveFill
compatible_styles = death, thrash, doom, progressive
```

### 3.5 Intensity Curve — JSON Format

```json
{
  "name": "Ascending",
  "type": "icAscending",
  "description": "Build intensity from start to end",
  "interpolation": "linear",
  "points": [
    {"bar_index": 0, "intensity": 0.0},
    {"bar_index": 1, "intensity": 0.25},
    {"bar_index": 2, "intensity": 0.5},
    {"bar_index": 3, "intensity": 0.75},
    {"bar_index": 4, "intensity": 1.0}
  ]
}
```

### 3.6 Modification Rule — INI + JSON Hybrid

For complex rules that need both parameters and beat-level logic:

**INI (parameters):**
```ini
[BehindBeatTiming]
description = Delays hits behind beat (Bonham, Chambers)
max_delay_ms = 25.0
intensity_scale = 0.7
instrument_filter = snare, kick, tom
```

**JSON (beat-level rules — optional):**
```json
{
  "name": "BehindBeatTiming",
  "parameters": {"max_delay_ms": 25.0, "intensity_scale": 0.7},
  "rules": [
    {"condition": "instrument == snare", "action": "delay", "amount_ms": 15},
    {"condition": "instrument == kick", "action": "delay", "amount_ms": 5},
    {"condition": "section == chorus", "action": "delay", "amount_ms": 25}
  ]
}
```

---

## 4. Full Free Pascal Loading Functions

### 4.1 INI Loader (`IniFiles` unit)

```pascal
unit ModularityLoader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpjson, jsonparser;

type
  TDrummerProfile = record
    Name: string;
    Genres: string;  // comma-separated
    GrooveBiasMs: Double;
    GrooveDirection: string;  // behind / ahead / locked
    TripletProb: Double;
    AccentBoost: Integer;
    SignatureFills: string;
  end;

  TPatternTemplate = class
  public
    Name: string;
    Description: string;
    TimeSignatureNum: Integer;
    TimeSignatureDenom: Integer;
    Bars: Integer;
    Beats: specialize TList<TBeat>;  // Requires Pattern unit
    Metadata: specialize TDictionary<string, string>;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;

function LoadDrummerProfiles(const AFilePath: string): specialize TDictionary<string, TDrummerProfile>;
function LoadPatternTemplate(const AFilePath: string): TPatternTemplate;
function LoadSectionStructure(const AFilePath: string): specialize TArray<TSectionDef>;

implementation

function LoadDrummerProfiles(const AFilePath: string): specialize TDictionary<string, TDrummerProfile>;
var
  Ini: TIniFile;
  Sections: TStringList;
  I: Integer;
  Profile: TDrummerProfile;
  Key: string;
begin
  Result := specialize TDictionary<string, TDrummerProfile>.Create;
  Ini := TIniFile.Create(AFilePath);
  try
    Sections := TStringList.Create;
    try
      Ini.ReadSectionNames(Sections);
      for I := 0 to Sections.Count - 1 do
      begin
        Key := Sections[I];
        // Skip non-section keys
        if Key = '' then Continue;
        
        Profile.Name := Ini.ReadString(Key, 'name', Key);
        Profile.Genres := Ini.ReadString(Key, 'genres', '');
        Profile.GrooveBiasMs := Ini.ReadFloat(Key, 'groove_bias_ms', 0.0);
        Profile.GrooveDirection := Ini.ReadString(Key, 'groove_direction', 'locked');
        Profile.TripletProb := Ini.ReadFloat(Key, 'triplet_probability', 0.0);
        Profile.AccentBoost := Ini.ReadInteger(Key, 'accent_boost', 0);
        Profile.SignatureFills := Ini.ReadString(Key, 'signature_fills', '');
        
        Result.Add(Key, Profile);
      end;
    finally
      Sections.Free;
    end;
  finally
    Ini.Free;
  end;
end;

function LoadPatternTemplate(const AFilePath: string): TPatternTemplate;
var
  JSONData: TJSONData;
  BeatsArray: TJSONArray;
  I: Integer;
  BeatObj: TJSONObject;
  InstrumentName: string;
  Instrument: TDrumInstrument;
begin
  Result := TPatternTemplate.Create('');
  
  // Read file content
  with TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite) do
  try
    JSONData := GetJSON(LoadFromStream(Self));
  finally
    Free;
  end;
  
  if not (JSONData is TJSONObject) then
    raise Exception.Create('Pattern file must contain a JSON object');
  
  with TJSONObject(JSONData) do
  begin
    Result.Name := GetJSONValue('name').Value;
    Result.Description := GetJSONValue('description').Value;
    
    // Time signature
    if Has('time_signature') then
    begin
      with TJSONObject(GetJSONValue('time_signature')) do
      begin
        Result.TimeSignatureNum := GetJSONValue('numerator').AsInteger;
        Result.TimeSignatureDenom := GetJSONValue('denominator').AsInteger;
      end;
    end
    else
    begin
      Result.TimeSignatureNum := 4;
      Result.TimeSignatureDenom := 4;
    end;
    
    Result.Bars := GetJSONValue('bars').AsInteger;
    
    // Beats array
    BeatsArray := TJSONArray(GetJSONValue('beats'));
    for I := 0 to BeatsArray.Count - 1 do
    begin
      BeatObj := TJSONObject(BeatsArray.Items[I]);
      
      InstrumentName := BeatObj.GetJSONValue('instrument').Value;
      Instrument := TInstrumentRegistry.Get(InstrumentName);
      
      // Create beat — requires Pattern unit
      // (Implementation depends on Pattern.pas interface)
      // Result.Beats.Add(TBeat.Create(
      //   BeatObj.GetJSONValue('position').AsFloat,
      //   Instrument,
      //   BeatObj.GetJSONValue('velocity').AsInteger
      // ));
    end;
  end;
end;

function LoadSectionStructure(const AFilePath: string): specialize TArray<TSectionDef>;
var
  JSONData: TJSONData;
  SectionsArray: TJSONArray;
  I: Integer;
  SectionObj: TJSONObject;
begin
  with TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite) do
  try
    JSONData := GetJSON(LoadFromStream(Self));
  finally
    Free;
  end;
  
  if not (JSONData is TJSONObject) then
    raise Exception.Create('Section file must contain a JSON object');
  
  with TJSONObject(JSONData) do
  begin
    SectionsArray := TJSONArray(GetJSONValue('sections'));
    SetLength(Result, SectionsArray.Count);
    
    for I := 0 to SectionsArray.Count - 1 do
    begin
      SectionObj := TJSONObject(SectionsArray.Items[I]);
      Result[I].Name := SectionObj.GetJSONValue('name').Value;
      Result[I].Bars := SectionObj.GetJSONValue('bars').AsInteger;
    end;
  end;
end;

end.
```

### 4.2 Usage in `DrumGenerator.pas`

```pascal
procedure TDrumGenerator.LoadPlugins;
// ... existing registration ...

// NEW: Load external pattern templates
var
  TemplateDir: string;
  PatternFiles: TStringList;
  I: Integer;
begin
  TemplateDir := 'patterns/';
  if DirectoryExists(TemplateDir) then
  begin
    PatternFiles := TStringList.Create;
    try
      FindAllFiles(PatternFiles, TemplateDir, '*.json');
      for I := 0 to PatternFiles.Count - 1 do
      begin
        // Load and register with PluginRegistry
        // (Requires registry extension for pattern templates)
      end;
    finally
      PatternFiles.Free;
    end;
  end;
end;
```

---

## 5. INI vs. JSON — When to Use Which (Drummer's View)

### 5.1 INI — For Drummer Profiles and Simple Config

A drummer wants to adjust their groove quickly. INI is perfect:

```ini
[MyCustomDrummer]
groove_bias_ms = 15.0
groove_direction = behind
triplet_probability = 0.5
accent_boost = 20
```

Edit with Notepad, reload — no JSON syntax errors, no brackets to match.

### 5.2 JSON — For Patterns, Fills, Sections

A pattern has beats with positions, instruments, velocities, durations, flags. This is inherently structured — JSON is the only practical format.

### 5.3 Hybrid — For Complex Modifications

A modification needs both parameters (INI-style) and beat-level rules (JSON-style). The hybrid approach lets users configure the easy parts in INI and the complex rules in JSON.

---

## 6. Full File Structure Proposal

```
ChameleonDrummer/
  config/
    drummer_profiles.ini          ← INI: all drummer settings
    genre_defaults.ini            ← INI: genre/style/BPM mappings
    intensity_curves/             ← JSON: curve definitions
      ascending.json
      descending.json
      plateau.json
      dip_rise.json
      steps.json
    groove_profiles/              ← INI: per-drummer offsets
      bonham.ini
      porcaro.ini
      weckl.ini
  patterns/                      ← JSON: pattern templates
    basic_groove.json
    blast_beat.json
    double_bass_pedal.json
    jazz_ride_pattern.json
    funk_ghost_notes.json
    crash_accents.json
    tom_fill.json
    template_composer.json
  fills/                         ← JSON: fill patterns
    tom_downfill.json
    tom_upfill.json
    blast_beat.json
    ride_bell_sweep.json
    snare_roll.json
    cymbal_crash.json
  sections/                      ← JSON: default structures
    metal_default.json
    rock_default.json
    jazz_default.json
    funk_default.json
    electronic_default.json
  modifications/                  ← INI + JSON: drummer mods
    behind_beat.ini
    triplet_vocab.ini
    ghost_note_layer.ini
    linear_coordination.ini
    heavy_accents.ini
    shuffle_feel.ini
    fast_chops.ini
    pocket_stretching.ini
    minimal_creativity.ini
    speed_precision.ini
    twisted_accents.ini
    mechanical_precision.ini
  mappings/                      ← JSON: already exists
    gm.json
    ad2.json
    ezd3.json
    xg.json
```

---

## 7. Migration Path — From Hardcoded to Modular

### 7.1 Phase 1: Extract Patterns

1. Read `src/patterns_templates.pas` (or Python equivalent)
2. Convert each template to JSON in `patterns/`
3. Modify `PatternBuilder` to load from JSON instead of hardcoding
4. Keep hardcoded as fallback if file missing

### 7.2 Phase 2: Extract Fills

1. Read `ComposerV2.pas` lines 226–288
2. Convert each fill type to JSON in `fills/`
3. Modify `TFillPicker.GenerateFillPattern()` to load from file
4. Add `drummer_specific` flag — if true, load from drummer plugin first

### 7.3 Phase 3: Extract Modifications

1. Read `modifications/drummer_mods.py` / `src/DrummerMods.pas`
2. Create INI files for parameters
3. Create JSON files for beat-level rules (optional)
4. Modify `TDrummerPlugin.ApplyStyle()` to load modifications from files

### 7.4 Phase 4: Extract Sections

1. Read `MainFrm.pas` `ResetToDefaultStructure()`
2. Create JSON files in `sections/`
3. Modify `TCLIInterface.ParseArgs()` to support `--structure`
4. Modify `DrumGenerator.CreateSong()` to load from file when `AStructure = nil`

---

## 8. Benefits of Modularity

### For Drummers
- **Custom patterns:** Write your own groove in JSON, load it, use it
- **Custom fills:** Add your signature fill to the library
- **Custom drummer:** Define your own groove profile in INI
- **Custom sections:** Design song structures without editing code

### For Developers
- **No recompilation:** Change patterns without rebuilding
- **Version control:** Pattern files can be tracked separately
- **Testing:** Load test patterns from files
- **Extensibility:** New genres/styles added by adding files

### For Users
- **Sharing:** Share pattern libraries as ZIP files
- **Customization:** Adjust complexity/humanization via config
- **Consistency:** Same patterns across CLI and GUI

---

## 9. Potential Pitfalls

### 9.1 Performance

Loading JSON files for every bar could be slow. **Solution:** Cache loaded patterns in `TPatternCache` (dictionary by filename) at `DrumGenerator` level.

### 9.2 File Not Found

If a file is missing, the engine should fall back to hardcoded defaults. **Solution:** Always check `FileExists()` before loading; use hardcoded as fallback.

### 9.3 JSON Parsing Errors

Invalid JSON crashes the engine. **Solution:** Wrap `GetJSON()` in `try/except`; log error; use fallback.

### 9.4 INI Encoding

INI files with special characters (accents, symbols) may have encoding issues. **Solution:** Use UTF-8 encoding (`TIniFile` supports this on modern FPC).

---

*This document proposes a complete modular architecture for ChameleonDrummer, with specific file formats, loading functions, and migration steps. The hybrid INI/JSON approach leverages Pascal's native `TIniFile` for simple parameters and `fpjson` for structured data, avoiding external dependencies while enabling full external customization.*
