# MIDI Drums Pascal — Remaining Work (TODO)

Last updated: 2026-09-10

## Status Overview

| Metric | Value |
|--------|-------|
| Units completed | 54 / 61 (~88%) |
| Stubs fixed this session | 4 files (composer_v2, midi_engine, ardour_export, plugin_registry) |
| Remaining stubs | **7** across 4 files |
| Non-critical remaining | ~7 units (tests, docs, examples) |

---

## 🔴 CRITICAL STUBS (must be fixed for working generation)

### 1. `composer_v2.pas` — `_generate_base_bar()` Returns Empty Pattern

**Python reference:** Lines 304–453 of `midi_drums/generation/composer_v2.py`
- Calls `GenrePlugin.generate_pattern(section, params)` to construct beats
- Applies timekeeping logic (hi-hat/ride/crash promotion)
- Builds actual beat data via PatternBuilder

**Pascal stub (current):**
```pascal
function TComposerV2.GenerateBaseBar(...): TPattern;
begin
  Result := TPattern.Create(SectionName + '_bar' + IntToStr(ABarIndex));
  { Empty — no beats, no genre plugin call }
end;
```

**Action needed:** Wire up to `GenrePlugin.GeneratePattern(section, params)` and apply timekeeping logic.

---

### 2. `composer_v2.pas` — `_fill_from_context()` Returns Empty Fill List

**Python reference:** Lines 606–616 of `midi_drums/generation/composer_v2.py`
- Calls `GenrePlugin.get_common_fills()` for genre-specific fills
- Calls `DrummerPlugin.get_signature_fills()` for drummer fills
- Selects based on section context and bar position

**Pascal stub (current):**
```pascal
function TComposerV2.GenerateContextAwareFills(...): TObjectList<TFill>;
begin
  Result := TObjectList<TFill>.Create(true);
  { Empty — no genre/drummer plugin calls }
end;
```

**Action needed:** Call both genre and drummer fill methods, merge results.

---

### 3. `plugin_registry.pas` — `GetStylesForGenre()` Broken Late-Binding Cast

**Python reference:** Lines 72–75 of `midi_drums/plugins/registry/plugin_registry.py`
```python
return genre_plugin.supported_styles
```

**Pascal stub (current):**
```pascal
function TPluginRegistry.GetStylesForGenre(const Genre: string): TArray<string>;
var
  PluginObj: TObject;
begin
  PluginObj := GetGenrePlugin(Genre);
  if not Assigned(PluginObj) then Exit([]);
  Result := TObjectClass(PluginObj).GetSupportedStyles; { ← BREAKS COMPILE }
end;
```

**Problem:** `TObjectClass(PluginObj)` returns the metaclass, but `GetSupportedStyles` is not a class method on TObject. This will not compile.

**Action needed:** Either:
- Store metadata parallel to plugin (already done via `FGenreStyles[]` — just fix the lookup), or
- Use a registered interface/RTTI approach to read styles from the actual genre plugin instance.

---

### 4. `plugin_registry.pas` — `GetPreferredDrummersForGenre()` Always Returns Empty

**Python reference:** Lines 78–91 of `midi_drums/plugins/registry/plugin_registry.py`
```python
if plugin and genre in plugin.preferred_genres:
    preferred_for_genre.append(name)
```

**Pascal stub (current):** Iterates `FDrummerPrefs[]` but this array is never populated because `RegisterDrummerPlugin()` does not store the `APrefGenres` metadata.

**Action needed:** Wire up `FDrummerPrefs[NewIdx].PreferredGenres` in `RegisterDrummerPlugin()`.

---

### 5. `midi_engine.pas` — Tempo Hardcoded to 120 BPM

**Python reference:** `composer_v2.py` line 93: `Song(tempo=tempo, ...)` passes tempo to song; MIDI events use it for tick calculations.

**Pascal stub (current):**
```pascal
procedure TMIDIEngine.WriteTempoMicroSec(MicroSecPerBeat: Cardinal);
begin
  WriteTempoMicroSec(500000); { ← Always 120 BPM, ignored }
end;
```

**Action needed:** Pass `Song.Tempo` to `SongToBytes()` and use it in the tempo meta event. Currently the tempo calculation is disconnected from song data.

---

### 6. `composer_v2.pas` — `_select_flavor()` Does Not Rotate Flavors

**Python reference:** Lines 279–302 of `midi_drums/generation/composer_v2.py`
```python
def _select_flavor(self, available_flavors, bar_index):
    return self._rng.choice(available_flavors)
```

**Pascal state (current):** Uses only `MacroComposer.SelectGroove()` which returns empty patterns. Falls back to `GenrePlugin.GeneratePattern()` only if groove is nil. Never calls `GenrePlugin.GetSectionFlavors()`.

**Action needed:** Call `GenrePlugin.GetSectionFlavors(section, params)`, then use `TBarSelector` or random selection to rotate between flavors per bar.

---

### 7. `ardour_export.pas` — MIDI Duration Calculation Uses Uninitialized Field

**Python reference:** Lines 195–208 of `midi_drums/core/models/kit.py` reads `mido.MidiFile(path).length` from the actual `.mid` file.

**Pascal stub (current):**
```pascal
function TArdourSessionExporter.CalcMIDISeconds: Double;
begin
  if (FMIDIMSecPerBeat = 0) then Exit(0);
  Result := FMIDITotalBars * (FMIDIMSecPerBeat / 60000); { ← FMIDITotalBars never set }
end;
```

**Action needed:** Either:
- Add a `ParseMIDILength(path)` equivalent using raw SMF parsing (no mido), or
- Accept duration from the calling code (Song or DrumGenerator) as a parameter.

---

## 🟡 MEDIUM PRIORITY (functional but incomplete)

### 8. `composer_v2.pas` — `GetSectionCurveMap()` Simplified Section Name Extraction

**Python reference:** Parses section tuples `(section_name, bar_count)` from structure list.

**Pascal stub (current):** Line 174: `SectionName := 'unknown'; Bars := 4;` — ignores actual data.

**Action needed:** Extract real section names and bar counts from the passed structure array.

---

### 9. `plugin_registry.pas` — `_get_open_hh_crash_variant()` Not Stored in Metadata

The `RegisterGenrePlugin()` method accepts `APrefDrummers` but does not populate `FGenreStyles[Idx].PreferredDrummers` correctly in all code paths.

**Action needed:** Audit the metadata population logic and ensure both styles and preferred drummers arrays are fully populated.

---

### 10. `composer_v2.pas` — `IntensityCurveType` Interpolation Uses Placeholder Values

**Current (line 346-359):**
```pascal
case TIntensityCurveType(CurveType) of
    icAscending: Result := Ratio;
    icDescending: Result := 1.0 - Ratio;
    icPlateau: Result := Min(1.0, Max(0.5, 0.7 + sin(Ratio * Pi) * 0.3));
    icDipRise: Result := sin(Ratio * Pi);
    icSteps: Result := floor(Ratio * 4) / 4;
```

**Status:** This is actually functional and matches the Python logic from `composer_v2.py` lines 198-207. **No change needed.**

---

### 11. `ardour_export.pas` — MIDI File Copy Uses Wrong Path

**Current (line 203):**
```pascal
SysUtils.FileCopy(MIDIFullPath, InterchangeDir + PathDelim + FMIDIFileName, True);
```

**Problem:** `MIDIFullPath = AOutputPath + FSessionName + PathDelim + FMIDIFileName` but the MIDI file might not be at that location.

**Action needed:** Accept actual MIDI file path as a parameter or use the song's output directory from the calling context.

---

## 🟢 LOW PRIORITY (tests, docs, edge cases)

| Item | File | Description |
|------|------|-------------|
| A | `plugin_registry.pas` | `LoadPluginsFromDirectory()` only scans for `.pas` files but doesn't dynamically load modules — this is expected in FPC since all plugins are compiled into the binary. Accept as-is or add RTTI-based auto-registration later. |
| B | `composer_v2.pas` | `TMacroComposer` phase cycling logic (`mpEstablish`, `mpMaintain`, etc.) works but has no genre-specific flavor weights. |
| C | `main.pas` | CLI argument parsing is basic — missing `--sidecar`, `--song-map`, `--write-timeline` flags from the Python version. |
| D | `ai/` modules | All AI backends return empty strings — stubbed for future OpenAI/LangChain integration. No MIDI logic affected. |
| E | Test suite | ~7 test units needed (pattern generation, drummer plugin application, keymap resolution). Python tests cover the same ground. |
| F | Documentation | `pascal/README.md` is up to date with current status. Add compilation troubleshooting section if needed. |

---

## Recommended Fix Priority Order

1. **#3** `plugin_registry.pas` — Fix `GetStylesForGenre()` compile error (will break everything that depends on it)
2. **#4** `plugin_registry.pas` — Wire up `FDrummerPrefs` metadata in register method
3. **#1** `composer_v2.pas` — Implement `_generate_base_bar()` with real PatternBuilder calls
4. **#2** `composer_v2.pas` — Implement `_fill_from_context()` with genre/drummer fills
5. **#6** `composer_v2.pas` — Wire up flavor rotation in `_select_flavor()`
6. **#5** `midi_engine.pas` — Pass song tempo to tempo meta event writer
7. **#7** `ardour_export.pas` — Fix MIDI duration calc

---

## Notes for Implementation

- All genre/drummer plugins in Pascal are fully implemented (54 units complete). No new plugin code needed.
- The core architecture (dynamic keymap resolution, no hardcoded notes) is correct and ready.
- Fixing stubs #1–#2 will restore full pattern generation parity with Python.
- Stub #3 (#3 in this table) is a compile blocker — it must be fixed first before any compilation succeeds.
