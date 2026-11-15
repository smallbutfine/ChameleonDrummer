# Quintole-Face-Support-Plan.md

## Ziel

Quintolen (4:5 polyrhythm) als optionale "Feel"-Art neben TripletSupport in ChameleonDrummer implementieren.

## Ansatz

Schnellste Lösung: Boolean bleibt, zwei Flags statt eins.
- `TripletFeel: Boolean` bleibt bestehen
- Neues Flag `QuintoleFeel: Boolean` (oder `GrooveFeel: Integer` mit Werten 0/1/2)

---

## Dateiliste der Änderungen

### 1. time_signature.pas — Kern

| # | Änderung | Art |
|---|----------|-----|
| 1 | TTimeSignature.TripletFeel → GrooveFeel: Integer (0=nichts, 1=triplet, 2=quintole) | Field-Change |
| 2 | GetStepsPerBar(): if GF=1 then *3div2; if GF=2 then Round(Power(5,-0.25)*4)) | Logic |
| 3 | MeterName(): case GF of 1:+'T'; 2:+'Q' end | Logic |
| 4 | TryParseMeterWithTriplet(): erkennt jetzt 'Q'-Suffix | Logic |

### 2. CLIInterface.pas — CLI-Eingabe

| # | Änderung | Art |
|---|----------|-----|
| 1 | TCLIArgs.TripletFeel → GrooveFeel: Integer | Field-Change |
| 2 | Parsing für '7/8Q' etc. analog zu 'T' | Logic |
| 3 | Alle Args.TripletFeel → Args.GrooveFeel (~6 Stellen) | Propagation |

### 3. ComposerV2.pas — Großes Refactoring

| # | Änderung | Art |
|---|----------|-----|
| 1 | TSectionDef.TripletFeel → GrooveFeel: Integer | Field-Change |
| 2 | Alle ATripletFeel: Boolean Parameter → AGrooveFeel: Integer (~6 Funcs) | Signature |
| 3 | GetBarOffsetMs: if GF=1 then *1.5; if GF=2 then *Power(5,-0.25)*4 | Logic |
| 4 | GetDrummerGrooveBias: GrooveBiasQuintole statt GrooveBiasTriple für GF=2 | Logic |
| 5 | GetSectionGrooveContext: Case auf GF, eigene Offsets für Quintole (1+2) | Logic |
| 6 | Alle .TripletFeel Properties → .GrooveFeel (~5 Stellen) | Propagation |

### 4. DrumGenerator.pas — Signaturen

| # | Änderung | Art |
|---|----------|-----|
| 1 | ATripletFeel: Boolean → AGrooveFeel: Integer in CreateSong (4× declaration + implementation) | Signature |

### 5. DrummerPlugin.pas — Fill-Lookup

| # | Änderung | Art |
|---|----------|-----|
| 1 | ATripletFeel: Boolean → AGrooveFeel: Integer in GetFillVocabulary (~2 Stellen) | Signature |
| 2 | GrooveBiasQuintole für GF=2 statt GrooveBiasTriple | Logic |
| 3. APattern.TimeSignature.GrooveFeel in [1,2] im Accent-Logik | Propagation |

### 6. FillLibrary.pas — Fill-Matching

| # | Änderung | Art |
|---|----------|-----|
| 1 | TripletOK: B.Meters[0].GrooveFeel = AGrooveFeel (statt Boolean-Vergleich) | Logic |
| 2 | `if AGrooveFeel in [1,2]` statt `if ATripletFeel` im Fallback-Logik | Logic |
| 3 | TripletOK: B.Meters[0].GrooveFeel <> AGrooveFeel beim "try straight" Fall | Logic |

### 7. GrooveLibrary.pas — Groove-Lookup

| # | Änderung | Art |
|---|----------|-----|
| 1 | ATripletFeel: Boolean → AGrooveFeel: Integer in MeterKey, FileGrooveVariants, GrooveVariantCount, BuildGroove (~6 Stellen) | Signature |
| 2 | MeterKey: case GF of 1:'T'; 2:'Q' end; sonst kein Anhang | Logic |
| 3 | Fallback `if AGrooveFeel > 0` statt `if ATripletFeel` beim try-straight-Versuch | Logic |

### 8. Genre-Plugins — Signaturen nur (~10 Signaturen)

Keine neue Logik nötig! Nur Parameter-Namen ändern:
- JazzGrooves.pas (2× FunkGrooveLines)
- FunkGrooves.pas (2×)
- RockGrooves.pas (2×)
- ElectronicGrooves.pas (2×)
- MetalGrooves.pas (2×)

Dispatch auf 7/8T-Varianten arbeitet nur auf Meter, nicht auf GrooveFeel. Parameter wird einfach durchgereicht.

### 9. PatternFixer.pas — Limb-Gap

| # | Änderung | Art |
|---|----------|-----|
| 1 | APattern.TimeSignature.GrooveFeel in [1,2] statt .TripletFeel | Propagation |
| 2 | Gap-Faktor: bei GF=2 etwas weniger als *2/3 (z.B. ~0.75) | Logic |

### 10. patterns_templates.pas — Metadata

| # | Änderung | Art |
|---|----------|-----|
| 1 | case AGrooveFeel of 1: 'triplet'; 2: 'quintole' end; statt 'triplet_feel':'true' | Logic |

### 11. gui/MainFrm.pas — GUI

| # | Änderung | Art |
|---|----------|-----|
| 1 | cbMeter.Items: neue Optionen hinzufügen (4/4Q,6/8Q,7/8Q,9/8Q,11/8Q,13/8Q) | UI-Data |
| 2 | Parsing in GetMeterText(): Q-Support analog zu T | Logic |

---

## Gesamt: ~12 Dateien, ~120 Zeilen geändert
