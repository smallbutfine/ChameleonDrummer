# Implementation Plan — Engine Improvements & CLI Extensions

**Status:** Design document for addressing `ENGINE_ANALYSIS.md` findings  
**Scope:** ComposerV2 pipeline, CLI interface, GUI, plugin architecture, MIDI export  
**Approach:** Incremental — fix critical realism issues first, then usability, then advanced features

---

## 1. Implementation Roadmap (Prioritized)

### Phase 1 — Critical Realism Fixes (Week 1–2)

| Issue | Source File | Lines | Implementation | Effort |
|-------|-------------|-------|----------------|--------|
| Fill placement logic | `ComposerV2.pas` | 185–196 | Replace `ShouldPlaceFill()` with phrase-boundary logic | Low |
| Drummer fill vocabulary | `ComposerV2.pas` | 226–288 | Load fills from `DrummerPlugin.GetSignatureFills()` first | Low |
| Pattern variation per bar | `ComposerV2.pas` | 118–127 | Use `Section.Variations` in `GenerateForBar()` | Medium |
| Per-instrument groove offsets | `ComposerV2.pas` | 292–312 | Modify `GetBarOffsetMs()` to return per-instrument map | Medium |
| Ghost note preservation | `PatternFixer.pas` | 178–186 | Add `MusicalImportance` score to `WeakerThan()` | Low |

### Phase 2 — Humanization & Intensity (Week 3)

| Issue | Source File | Lines | Implementation | Effort |
|-------|-------------|-------|----------------|--------|
| Drummer timing profiles | `AdvancedHumanization.pas` | 70–113 | Replace random with profile-based deviation | Medium |
| Intensity for pattern selection | `ComposerV2.pas` | 885–910 | Use `IntensityPt` to select denser flavors | Medium |
| Swing implementation | `Pattern.pas` | 51 | Add `ApplySwing()` to `TPattern` | Low |

### Phase 3 — Structural & Validation (Week 4)

| Issue | Source File | Lines | Implementation | Effort |
|-------|-------------|-------|----------------|--------|
| Pattern duration validation | `Pattern.pas` | 97 | Add duration check to `Validate()` | Low |
| Note-off events | `MidiIO.pas` | 15 | Add note-off writing to `SaveMidi()` | Low |
| PPQ configurability | `MidiIO.pas` | 97 | Make PPQ parameter configurable | Low |

### Phase 4 — Plugin & CLI (Week 5–6)

| Issue | Source File | Lines | Implementation | Effort |
|-------|-------------|-------|----------------|--------|
| Dynamic plugin loading | `DrumGenerator.pas` | 229 | Load from `plugins/` directory | Medium |
| GUI dropdown loading | `MainFrm.pas` | 103 | Read from registry at form create | Low |
| CLI extension — section control | `CLIInterface.pas` | 63 | Add `--section`, `--bars`, `--structure` flags | Medium |
| CLI extension — odd meters | `CLIInterface.pas` | 63 | Add `--time-sig` with numerator/denominator | Low |

---

## 2. Bar-Per-Bar vs. Multi-Bar Patterns — Collision Analysis

### 2.1 The Core Tension

`ComposerV2.CreateSong()` operates on a **per-bar basis** (line 641: `for BarIndex := 0 to Bars - 1 do`). Each bar is generated independently from the base phrase pattern (`BasePattern`) via `ExtractPatternBar()` (line 912). The phrase pattern (`CurrentPattern`) is selected once per phrase (`NextPhraseBar`) and then extracted bar-by-bar.

**This is correct architecture** — a drummer plays phrases (2–4 bars) with internal variation, not identical bars. The engine selects a phrase, then extracts each bar from it.

### 2.2 Where Collision Occurs

**Collision 1: Pattern Variation vs. Phrase Consistency**

If `GenerateForBar()` selects a different variation for each bar of a 4-bar phrase, the phrase loses coherence. The `PreviousBars` parameter (line 39) exists but is never used to enforce consistency.

**Solution:** Use `PreviousBars` to prefer variations that are similar to the previous bar. Only switch variation at phrase boundaries (`NextPhraseBar`).

**Collision 2: Fill Placement vs. Bar Extraction**

Fills are inserted after bar combination (line 737–796), but the fill pattern is a separate `TPattern` that may have different time signatures or bar lengths. If a fill is 1 bar and the section is 4 bars, the fill replaces bar 3 — but the fill's beats must align with the section's time signature.

**Solution:** Ensure `GenerateFillPattern()` creates patterns with the same `TimeSignature` as the section. Add validation in `TFillPicker.PickFillsForSection()`.

**Collision 3: Groove Offsets vs. Multi-Bar Phrases**

`GrooveOffsetsMs` is calculated per bar (line 786–792) but applied to the combined section pattern. If the phrase spans 4 bars, each bar gets its own offset — which is correct for microtiming variation. However, if the offset changes abruptly between bars, it sounds like the drummer is rushing/dragging within the phrase.

**Solution:** Smooth offsets across phrase boundaries using a moving average or only apply offsets at phrase starts.

**Collision 4: Intensity Curve vs. Phrase Length**

The intensity curve (`GetIntensityPt()`) is calculated per bar based on `ABarIndex / (ABars - 1)`. For a 4-bar phrase, intensity goes 0 → 0.33 → 0.67 → 1.0. This is fine for a single phrase. But if the section has 8 bars with 2 phrases, the intensity resets at phrase 2 — which is wrong. The intensity should be continuous across the section.

**Solution:** Calculate intensity based on section-level progress (`BarIndex / (SectionBars - 1)`), not phrase-level.

---

## 3. CLI Extensions for Creation Parameter Control

### 3.1 Current CLI Flags (`CLIInterface.pas` Lines 63–208)

The CLI supports: `--genre`, `--style`, `--tempo`, `--complexity`, `--humanization`, `--drummer`, `--output`, `--mapping`, `--sidecar`, `--song-map`, `--write-timeline`, `--preset-only`, `--song`, `--list`, `--help`.

### 3.2 Proposed New Flags

**Section Structure Control:**

```bash
# Define custom section structure
chameleondrummer generate --genre metal --style death \
  --section intro:4 --section verse:8 --section chorus:8 \
  --section bridge:4 --section chorus:8 --section outro:4

# Or from JSON
chameleondrummer generate --genre metal --style death --structure song_structure.json
```

Implementation in `ParseArgs()`:
- Add `--section <name>:<bars>` parsing (split on `:`)
- Build `TStructureEntry` array from parsed sections
- Pass to `HandleGenerate()` instead of `nil`

**Time Signature Control:**

```bash
# Odd time signatures
chameleondrummer generate --genre jazz --style fusion --time-sig 7/8 --tempo 200
chameleondrummer generate --genre metal --style progressive --time-sig 5/4 --tempo 140
chameleondrummer generate --genre funk --style shuffle --time-sig 6/8 --tempo 130
```

Implementation:
- Add `--time-sig <num>/<denom>` parsing
- Create `TTimeSignature` object from parsed values
- Pass to `TDrumGenerator.CreateSong()` (currently not passed — needs interface change)

**Per-Section Tempo / Meter (Song Map Style):**

```bash
chameleondrummer generate --genre rock --style classic \
  --song-map song_map.json --write-timeline timeline.json
```

The `--song-map` already exists but only reads from file. The CLI should also allow inline specification:

```bash
chameleondrummer generate --genre rock --style classic \
  --segment verse:8:144:4/4 --segment chorus:8:160:4/4 \
  --segment bridge:4:120:7/8
```

**Drummer Intensity / Style Modifiers:**

```bash
# Force specific drummer modifications
chameleondrummer generate --genre metal --style death --drummer hoglan \
  --drummer-mod behind_beat:0.7 --drummer-mod triplets:0.8
```

**Pattern Template Selection:**

```bash
# Use specific pattern templates
chameleondrummer generate --genre metal --style death \
  --template BlastBeat --template DoubleBassPedal
```

**Output Format Control:**

```bash
# Multiple outputs
chameleondrummer generate --genre metal --style death \
  --output song.mid --output-reaper song.rpp --output-ardour song.ardour
```

---

## 4. Odd Time Signatures — Implementation

### 4.1 Current State

`time_signature.pas` defines `TTimeSignature`. The default is 4/4. `ComposerV2.CreateSong()` creates `Song := TSong.Create(...)` with default time signature. The `TDrumGenerator.GetDefaultBpm()` uses genre/style defaults but ignores time signature.

### 4.2 Changes Required

**In `CLIInterface.pas`:**

```pascal
else if (Args[I] = '--time-sig') then
begin
  Inc(I);
  if (I < Length(Args)) then
  begin
    // Parse "7/8" or "5/4"
    Result.TimeSigNum := StrToInt(Copy(Args[I], 1, Pos('/', Args[I]) - 1));
    Result.TimeSigDenom := StrToInt(Copy(Args[I], Pos('/', Args[I]) + 1, MaxInt));
  end;
end
```

**In `DrumGenerator.pas`:**

Modify `CreateSong()` to accept `ATimeSignature` parameter and pass to `TSong.Create()`.

**In `ComposerV2.pas`:**

The `TSectionDef` and intensity curves assume 4/4. For odd meters:
- `ABars` should represent the number of bars, not beats
- `GetIntensityPt()` uses `ABarIndex / (ABars - 1)` — this is correct regardless of meter
- `ExtractPatternBar()` uses `BarLength := APattern.TimeSignature.BeatsPerBar` — correct
- Fill placement uses `ABars` — correct
- **Problem:** The `GMDPatternLibrary.GetPatterns()` may only have 4/4 patterns. Need to generate patterns for odd meters or adapt 4/4 patterns.

**In `Pattern.pas`:**

`TPattern.Create()` sets `FTimeSignature := TTimeSignature.Create(4, 4)`. Should accept parameter.

**In `MidiIO.pas`:**

The MIDI file header writes time signature meta events. Need to write the correct numerator/denominator.

---

## 5. Section Generation CLI — Detailed Design

### 5.1 Command Syntax

```bash
# Inline section definition
chameleondrummer generate --genre metal --style death \
  --section intro:4 --section verse:8 --section chorus:8 \
  --section bridge:4 --section chorus:8 --section outro:4

# From file
chameleondrummer generate --genre rock --style classic --structure my_song.json

# With tempo per section
chameleondrummer generate --genre jazz --style fusion \
  --section intro:4:120 --section verse:8:140 --section chorus:8:160
```

### 5.2 Implementation in `CLIInterface.pas`

Add to `TCLIArgs`:

```pascal
StructureFile: String;
SectionDefs: specialize TArray<TSectionDef>;
```

In `ParseArgs()`:

```pascal
else if (Args[I] = '--section') then
begin
  Inc(I);
  if (I < Length(Args)) then
  begin
    // Parse "name:bars" or "name:bars:tempo"
    // Add to SectionDefs array
  end;
end
else if (Args[I] = '--structure') then
begin
  Inc(I);
  if (I < Length(Args)) then Result.StructureFile := Args[I];
end
```

In `HandleGenerate()`:

```pascal
if (Args.StructureFile <> '') then
  // Load from JSON file
else if (Length(Args.SectionDefs) > 0) then
  // Use inline definitions
else
  // Use genre default (current behavior)
```

### 5.3 JSON Sidecar Format (Existing)

The existing `midi_drums_sections.json` format:

```json
{
  "source": "reaper",
  "tempo": 70,
  "time_signature": [4, 4],
  "sections": [
    {"name": "Intro", "bars": 8},
    {"name": "Verse", "bars": 16},
    {"name": "Chorus", "bars": 16},
    {"name": "Bridge", "bars": 8},
    {"name": "Outro", "bars": 4}
  ]
}
```

The CLI should read this format when `--sidecar` is specified.

---

## 6. Multi-Bar Pattern Integrity — Detailed Fix

### 6.1 The Problem

`TComposerV2.CreateSong()` selects a phrase (`CurrentPattern`) for a section, then extracts each bar from it. If `GenerateForBar()` applies a different variation per bar, the phrase is broken.

### 6.2 The Fix

Modify `GenerateForBar()` to check `PreviousBars`:

```pascal
function TBarSelector.GenerateForBar(BasePattern: TPattern; ABarIndex: Integer; ABars: Integer;
  IntensityPt, Complexity, Dynamics: Double; const ADrummer: string;
  PreviousBars: specialize TList<TPattern>): TPattern;
begin
  // If we're in the middle of a phrase (not at phrase start), prefer consistency
  if (PreviousBars <> nil) and (PreviousBars.Count > 0) then
  begin
    // Check if previous bar was from same phrase
    // If yes, use same base pattern with minor modulation only
    // If no (phrase boundary), allow new selection
  end;
end;
```

More specifically: only allow `Variation` selection when `ABarIndex = CurrentPhraseStartBar`. At other bars, only apply `ApplyParameterModifications()`.

---

## 7. Implementation Order & Dependencies

```
Phase 1 (Critical):
  Fill placement → Drummer fills → Pattern variation → Groove offsets → Ghost notes
  (No dependencies between these — can be done in parallel)

Phase 2 (Realism):
  Humanization profiles → Intensity usage → Swing → Duration validation
  (Depends on Phase 1 for consistent patterns)

Phase 3 (Structure):
  Note-off → PPQ → Pattern validation
  (Independent)

Phase 4 (CLI/Plugins):
  CLI flags → Dynamic plugins → GUI dropdowns → Section persistence
  (Depends on Phase 1 for stable patterns)

Phase 5 (Advanced):
  Odd meters → Song maps → Per-section tempo → Template selection
  (Depends on Phase 3 for time signature support)
```

---

## 8. Testing Plan

For each phase:

1. **Unit test:** Verify function behavior with known inputs
2. **Integration test:** Generate a song with new settings, inspect MIDI
3. **Drummer review:** Play generated MIDI in DAW, evaluate realism
4. **Regression test:** Ensure old behavior preserved when new flags not used

Specific tests:
- Fill at bar 3 of 4-bar verse (should occur)
- Fill at bar 0 of 4-bar verse (should NOT occur)
- Blast beat with Bonham drummer (should prefer Bonham fills)
- 7/8 time signature (should write correct MIDI meta event)
- Section structure from CLI (should match JSON input)

---

*This plan addresses all findings from `ENGINE_ANALYSIS.md` and extends the system with CLI controls for section generation, odd time signatures, and finer parameter control. The bar-per-bar architecture is preserved — the fixes improve how bars are selected and combined, not the fundamental pipeline.*
