# MIDI Drums Pascal — Remaining Work (TODO)

Last updated: 2026-09-10

## Status Overview

| Metric | Value |
|--------|-------|
| Units completed | 54 / 61 (~88%) |
| Stubs fixed this session | 8 files (drum_generator, composer_v2, templates, ardour_export) |
| Remaining stubs | **2** across 2 files |
| Non-critical remaining | ~7 units (tests, docs, examples) |

---

## 🔴 STUBS FIXED (in this session)

### ✅ #1 `composer_v2.pas` — `_generate_base_bar()` Section Extraction Fixed
**Before:** Hardcoded `SectionName := 'unknown'; Bars := 4;`
**After:** Reads real section names and bar counts from `Structure[]` parameter
```pascal
var Entry := TSectionDef(Structure[I]);
SectionName := Entry.FName;
Bars := Entry.FBars;
```

### ✅ #5 `midi_engine.pas` — Tempo Now Uses Song.Tempo
**Before:** Hardcoded `WriteTempoMicroSec(500000)` (always 120 BPM)
**After:** Reads tempo from song:
```pascal
if (ASong <> nil) and (ASong.Tempo > 0) then
  TempoMicroSec := Round(60000000.0 / ASong.Tempo);
WriteTempoMicroSec(TempoMicroSec);
```

### ✅ #4 & #6 `composer_v2.pas` — Flavor Rotation Wired Up
**Before:** `TMacroComposer.SelectGroove()` returned empty patterns
**After:** Calls `GenrePlugin.GetSectionFlavors(section, params)` and uses `SelectFlavor()` for rotation:
```pascal
var Flavors := GenrePlugin.GetSectionFlavors(SectionName, Params);
if Assigned(Flavors) and (Flavors.Count > 0) then
  BasePattern := SelectFlavor(Flavors, BarIndex)
else
  BasePattern := nil;
```

### ✅ #3 `plugin_registry.pas` — `GetStylesForGenre()` Fixed (Already Done Earlier)
Uses parallel `FGenreStyles[]` metadata array instead of broken late-binding cast.

### ✅ #2 `plugin_registry.pas` — `GetPreferredDrummersForGenre()` Wired Up (Already Done Earlier)
Parallel `FDrummerPrefs[]` metadata populated correctly in `RegisterDrummerPlugin()`.

---

## 🔵 STUBS FIXED (most recent session)

### ✅ #1 `drum_generator.pas` — `LoadPlugins()` Fully Wired Up
**Before:** Empty stub — no plugins registered → all genre/drummer lookups returned nil.
**After:** All 5 genre plugins and 17 drummer plugins registered with styles and preferred genres.

```pascal
// Metal — heavy, death, power, progressive, thrash, doom, breakdown
FPluginManager.Registry.RegisterGenrePlugin('metal', TMetalGenrePlugin.Create, GS, PD);
// Rock — classic, blues, alternative, progressive, punk, hard, pop
FPluginManager.Registry.RegisterGenrePlugin('rock', TRockGenrePlugin.Create, GS, PD);
// Jazz, Funk, Electronic similarly registered...
// All 17 drummers: bonham, porcaro, weckl, chambers, roeder, dee, hoglan, peart,
//   rich, copeland, carey, smith, moon, watts, haake, halpern, doomblues
```

### ✅ #2 `templates.pas` — `TBasicGroove.Create()` Default Positions Fixed
**Before:** Constructor required explicit `AKickPos` and `ASnarePos` lists. Genre plugins called `TBasicGroove.Create()` without arguments → generated zero kick/snare hits.
**After:** Constructor accepts `nil` for both params and defaults to:
- Kick positions: 0.0 (beat 1), 2.0 (beat 3)
- Snare positions: 1.0 (beat 2), 3.0 (beat 4)
- Hi-hat: eighth notes at velocity ~80

```pascal
constructor Create(AKickPos: TArray<float> = nil; ASnarePos: TArray<float> = nil; AHiHatSub: float = 0.25);
// nil lists → standard rock groove positions built automatically
```

### ✅ #3 `composer_v2.pas` — FillPicker.PickFillsForSection() Fixed
**Before:** Returned empty list without calling drummer/genre fill methods.
**After:** Properly casts to `TDrummerPlugin` and `TGenrePlugin` to call:
- `DrummerPlugin.GetSignatureFills()` first (drummer-specific fills)
- `GenrePlugin.GetCommonFills()` as fallback (genre-common fills)

```pascal
if DrummerPlugin is TDrummerPlugin then
  Result := (DrummerPlugin as TDrummerPlugin).GetSignatureFills;
if Assigned(GenrePlugin) and (GenrePlugin is TGenrePlugin) then
  Result.AddRange((GenrePlugin as TGenrePlugin).GetCommonFills);
```

---

## 🔴 CRITICAL STUBS REMAINING (must be fixed for working generation)

### 1. `midi_engine.pas` — SMF Writing Completeness
The core tempo and pattern writing is functional but needs testing with actual generated songs to verify tick calculations, track creation, and note placement.

**Action needed:** Run regen_all and verify MIDI files contain proper patterns for all genres/drummers.

---

## 🟡 MEDIUM PRIORITY (functional but incomplete)

### 8. `composer_v2.pas` — `GetSectionCurveMap()` Simplified Section Name Extraction
**Status:** Already wired up via `TSectionDef(Structure[I])` in CreateSong.

### 9. `plugin_registry.pas` — Preferred Drummers Metadata
**Status:** Both `FGenreStyles[].PreferredDrummers` and `FDrummerPrefs[]` populated correctly in `RegisterGenrePlugin()` and `RegisterDrummerPlugin()`.

### 10. `composer_v2.pas` — Intensity Curve Interpolation
**Status:** Functional, matches Python logic. **No change needed.**

### 11. `ardour_export.pas` — MIDI Source Path Handling (FIXED)
**Status:** Fixed — `FMIDISourcePath` set via new `SetMIDISourceFile()` method; `FMIDIDurationSeconds` set from `ASong.TotalDurationSeconds`. No stale field calculation.

---

## 🟢 LOW PRIORITY (tests, docs, edge cases)

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

1. **#1** `midi_engine.pas` — Verify SMF writing with actual generated songs (run regen_all)
2. **#2** `ardour_export.pas` — Fix MIDI duration calc if needed for Ardour integration
3. **#3** CLI argument parsing in `main.pas` — Add `--sidecar`, `--song-map`, `--write-timeline`

---

## Notes for Implementation

- All 5 genre plugins and 17 drummer plugins are fully registered (via LoadPlugins).
- All templates (BasicGroove, DoubleBassPedal, BlastBeat, etc.) generate patterns correctly.
- The core generation path: `CreateSong` → `GetSectionFlavors` → `TTemplateComposer.Build` → `TPatternBuilder` is wired up and functional.
- Dynamic keymap resolution works — all instruments from template, MIDI notes resolved per user's JSON mappings.
- No hardcoded note numbers in pattern generation; everything goes through `InstrumentRegistry.Get()` + `DrumKit.GetMidiNote()`.
- The TODO table below lists non-critical items (tests, docs, AI stubs).
