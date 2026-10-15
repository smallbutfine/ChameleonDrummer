unit DrummerMods;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math, Kit, Pattern;

// ============================================================================
// BehindBeatTiming â€” delays hits slightly behind the beat (Bonham signature)
// ============================================================================
type
  TBehindBeatTiming = class
  private
    FMaxDelayMs: Double;
  public
    constructor Create(A_MAX_DELAY_MS: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// TriplettVocabulary â€” adds triplet-based fills and phrasing
// ============================================================================
type
  TTripeltVocabulary = class
  private
    FTripProbability: Double;
  public
    constructor Create(A_TRIP_PROBABILITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// HeavyAccents â€” increases accent contrast for power playing
// ============================================================================
type
  THeavyAccents = class
  private
    FAccentBoost: Integer;
  public
    constructor Create(A_ACCENT_BOOST: Integer);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// GhostNoteLayer â€” adds subtle ghost notes for groove
// ============================================================================
type
  TGhostNoteLayer = class
  private
    FGhostDensity: Double;
  public
    constructor Create(A_GHOST_DENSITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// LinearCoordination â€” removes simultaneous hits for linear playing
// ============================================================================
type
  TLinearCoordination = class
  private
    FLinearProbability: Double;
  public
    constructor Create(A_LINEAR_PROBABILITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// ShuffleFeelApplication â€” adds shuffle/swing feel (Porcaro signature)
// ============================================================================
type
  TShuffleFeelApplication = class
  private
    FShuffleAmount: Double;
  public
    constructor Create(A_SHUFFLE_AMOUNT: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// FastChopsTriplets â€” fast technical fills (Chambers signature)
// ============================================================================
type
  TFastChopsTriplets = class
  private
    FChopProbability: Double;
  public
    constructor Create(A_CHOP_PROBABILITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// PocketStretching â€” subtle groove variations (Chambers signature)
// ============================================================================
type
  TPocketStretching = class
  public
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// MinimalCreativity â€” sparse, atmospheric approach (Roeder signature)
// ============================================================================
type
  TMinimalCreativity = class
  public
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// SpeedPrecision â€” consistent timing/velocity (Dee signature)
// ============================================================================
type
  TSpeedPrecision = class
  private
    FVelocityTolerance: Double;
  public
    constructor Create(A_VELOCITY_TOLERANCE: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// TwistedAccents â€” displaced accents (Dee signature)
// ============================================================================
type
  TTwistedAccents = class
  private
    FAccentDisplacement: Integer;
  public
    constructor Create(A_ACCENT_DISPLACEMENT: Integer);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// MechanicalPrecision â€” extreme quantization (Hoglan signature)
// ============================================================================
type
  TMechanicalPrecision = class
  private
    FQuantizationStrength: Double;
  public
    constructor Create(A_QUANT_STRENGTH: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// BlastBeatApplication â€” applies blast beats for metal (Hoglan signature)
// ============================================================================
type
  TBlastBeatApplication = class
  private
    FBlastDensity: Double;
  public
    constructor Create(A_BLAST_DENSITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

implementation

{ Helper: check if a string starts with any of the given prefixes }
function HasPrefix(const S, Prefix: String): Boolean;
begin
  Result := Pos(LowerCase(Prefix), LowerCase(S)) = 1;
end;

function HasAnyPrefix(const S: String; const Prefixes: specialize TArray<String>): Boolean;
var
  I: Integer;
begin
  for I := Low(Prefixes) to High(Prefixes) do
    if Pos(LowerCase(Prefixes[I]), LowerCase(S)) > 0 then
      Exit(True);
  Exit(False);
end;

{ TBehindBeatTiming }
constructor TBehindBeatTiming.Create(A_MAX_DELAY_MS: Double);
begin
  FMaxDelayMs := A_MAX_DELAY_MS;
end;

function TBehindBeatTiming.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
  Beat: TBeat;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    Beat := Result.Beats[BIdx];
    if Random < Intensity * 0.3 then
    begin
      // Add delayed copy of this beat (behind-the-beat feel)
      Beat.Position := Beat.Position + FMaxDelayMs / 1000.0 * Intensity;
      Beat.GhostNote := True;
      Beat.Velocity := Trunc(Beat.Velocity * 0.95);
    end;
  end;
end;

{ TTripeltVocabulary }
constructor TTripeltVocabulary.Create(A_TRIP_PROBABILITY: Double);
begin
  FTripProbability := A_TRIP_PROBABILITY;
end;

function TTripeltVocabulary.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  I: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FTripProbability <= 0) then Exit;

  // Add triplet accent every bar
  for I := 0 to Trunc(Result.DurationBars) - 1 do
    if Random < FTripProbability * Intensity * 0.2 then
      Result.AddBeat(0.5, TInstrumentRegistry.Get('snare_1_hit'), Round(90 * Intensity));
end;

{ THeavyAccents }
constructor THeavyAccents.Create(A_ACCENT_BOOST: Integer);
begin
  FAccentBoost := A_ACCENT_BOOST;
end;

function THeavyAccents.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
  BoostedVel: Integer;
  InstName: String;
begin
  Result := APattern.Copy;

  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    InstName := LowerCase(Result.Beats[BIdx].Instrument.Name);
    // Boost snare and kick accents
    if ((HasAnyPrefix(InstName, ['snare', 'kick'])) and (Intensity > 0.5)) then
    begin
      BoostedVel := Min(127, Result.Beats[BIdx].Velocity + FAccentBoost);
      Result.Beats[BIdx].Velocity := Trunc(BoostedVel * Intensity);
    end;
  end;
end;

{ TGhostNoteLayer }
constructor TGhostNoteLayer.Create(A_GHOST_DENSITY: Double);
begin
  FGhostDensity := A_GHOST_DENSITY;
end;

function TGhostNoteLayer.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx, GhostCount, MaxGhostsPerBar: Integer;
  EffectiveDensity, ScaleFactor: Double;
  BarStart: Double;
  InstName: String;
  SnarePrefixes: specialize TArray<String>;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FGhostDensity <= 0) then Exit;

  SetLength(SnarePrefixes, 4);
  SnarePrefixes[0] := 'snare';
  SnarePrefixes[1] := 'snare_sticks';
  SnarePrefixes[2] := 'snare_1_hit';
  SnarePrefixes[3] := 'rimshot';

  // Scale density inversely to input beat count (matches Python)
  EffectiveDensity := FGhostDensity * Intensity;
  if EffectiveDensity >= 0.99 then
    ScaleFactor := 1.0
  else if Result.Beats.Count <= 6 then
    ScaleFactor := 1.0
  else if Result.Beats.Count <= 14 then
    ScaleFactor := 0.6
  else
    ScaleFactor := 0.3;

  EffectiveDensity := EffectiveDensity * ScaleFactor;
  MaxGhostsPerBar := Max(2, Trunc((16 - Result.Beats.Count) * EffectiveDensity));

  // Iterate beats in order by bar
  GhostCount := 0;
  BarStart := -1.0;
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    // Detect new bar boundary and reset ghost count
    if Trunc(Result.Beats[BIdx].Position) > Trunc(BarStart) then
    begin
      GhostCount := 0;
      BarStart := Result.Beats[BIdx].Position;
    end;

    // Stop adding ghosts for this bar if budget exceeded
    if GhostCount >= MaxGhostsPerBar then Continue;

    // Check if this is a snare beat (by instrument name)
    InstName := Result.Beats[BIdx].Instrument.Name;
    if not HasAnyPrefix(InstName, SnarePrefixes) then Continue;

    // Add ghost note slightly offset from original
    GhostCount := GhostCount + 1;
    Result.Beats.Add(TBeat.Create(Result.Beats[BIdx].Position + 0.25,
      TInstrumentRegistry.Get('snare_1_hit'), Max(40, Trunc(40 * Intensity))));
  end;
end;

{ TLinearCoordination }
constructor TLinearCoordination.Create(A_LINEAR_PROBABILITY: Double);
begin
  FLinearProbability := A_LINEAR_PROBABILITY;
end;

function TLinearCoordination.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  I, J: Integer;
  TimeDiff: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FLinearProbability <= 0) then Exit;

  // Check all pairs for simultaneous hits on different instruments
  for I := 0 to Result.Beats.Count - 2 do
    for J := I + 1 to Result.Beats.Count - 1 do
    begin
      TimeDiff := Abs(Result.Beats[I].Position - Result.Beats[J].Position);
      if (TimeDiff < 0.01) and
         (Result.Beats[I].Instrument <> Result.Beats[J].Instrument) then
      begin
        if Random < FLinearProbability * Intensity then
          Result.Beats[J].Position := Result.Beats[J].Position + 0.0625;
      end;
    end;
end;

{ TShuffleFeelApplication }
constructor TShuffleFeelApplication.Create(A_SHUFFLE_AMOUNT: Double);
begin
  FShuffleAmount := A_SHUFFLE_AMOUNT;
end;

function TShuffleFeelApplication.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
  BeatWithinQuarter, ShuffleOffset: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FShuffleAmount <= 0) then Exit;

  ShuffleOffset := FShuffleAmount * Intensity * 0.25; // triplet-based swing amount

  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    BeatWithinQuarter := Result.Beats[BIdx].Position mod 1.0;

    // Apply shuffle to offbeat 16ths (positions .25, .75 within quarter note)
    if (Abs(BeatWithinQuarter - 0.25) < 0.01) or (Abs(BeatWithinQuarter - 0.75) < 0.01) then
      Result.Beats[BIdx].Position := Result.Beats[BIdx].Position + ShuffleOffset;
  end;
end;

{ TFastChopsTriplets }
constructor TFastChopsTriplets.Create(A_CHOP_PROBABILITY: Double);
begin
  FChopProbability := A_CHOP_PROBABILITY;
end;

function TFastChopsTriplets.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FChopProbability <= 0) then Exit;

  // Add tom chop every bar at the bar start position
  for BIdx := 0 to Result.Beats.Count - 1 do
    if Random < FChopProbability * Intensity * 0.2 then
      Result.AddBeat(Trunc(Result.Beats[BIdx].Position), TInstrumentRegistry.Get('tom_2_open_hit'), Round(100 * Intensity));
end;

{ TPocketStretching }
function TPocketStretching.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
  MicroDelay: Double;
  InstName: String;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  // Subtle micro-timing variations for pocket feel on kick/snare beats
  MicroDelay := (Random(100) / 100.0 - 0.5) * 0.02 * Intensity;
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    InstName := LowerCase(Result.Beats[BIdx].Instrument.Name);
    if (HasAnyPrefix(InstName, ['kick', 'snare'])) then
      Result.Beats[BIdx].Position := Result.Beats[BIdx].Position + MicroDelay;
  end;
end;

{ TMinimalCreativity }
function TMinimalCreativity.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  // Remove some beats for sparse atmosphere
  for BIdx := 0 to Result.Beats.Count - 1 do
    if (Random < Intensity * 0.4) and (Result.Beats.Count > 2) then
      Result.Beats.Delete(Random(Result.Beats.Count - 1));
end;

{ TSpeedPrecision }
constructor TSpeedPrecision.Create(A_VELOCITY_TOLERANCE: Double);
begin
  FVelocityTolerance := A_VELOCITY_TOLERANCE;
end;

function TSpeedPrecision.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
  AvgVel: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  // Normalize velocities toward precision
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    AvgVel := Round(Result.Beats[BIdx].Velocity * FVelocityTolerance +
                    100 * (1.0 - FVelocityTolerance));
    Result.Beats[BIdx].Velocity := Max(40, Min(127, AvgVel));
  end;
end;

{ TTwistedAccents }
constructor TTwistedAccents.Create(A_ACCENT_DISPLACEMENT: Integer);
begin
  FAccentDisplacement := A_ACCENT_DISPLACEMENT;
end;

function TTwistedAccents.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  for BIdx := 0 to Result.Beats.Count - 1 do
    if (Random < Intensity * 0.3) and
       HasAnyPrefix(LowerCase(Result.Beats[BIdx].Instrument.Name), ['snare']) then
      Result.Beats[BIdx].Position := Result.Beats[BIdx].Position + (FAccentDisplacement / 480.0);
end;

{ TMechanicalPrecision }
constructor TMechanicalPrecision.Create(A_QUANT_STRENGTH: Double);
begin
  FQuantizationStrength := A_QUANT_STRENGTH;
end;

function TMechanicalPrecision.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx: Integer;
  QuantTime: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  // Quantize all notes to strict grid with strength factor
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    QuantTime := Round(Result.Beats[BIdx].Position * 16) / 16.0;
    Result.Beats[BIdx].Position :=
      Result.Beats[BIdx].Position * (1.0 - FQuantizationStrength) +
      QuantTime * FQuantizationStrength;
  end;
end;

{ TBlastBeatApplication }
constructor TBlastBeatApplication.Create(A_BLAST_DENSITY: Double);
begin
  FBlastDensity := A_BLAST_DENSITY;
end;

function TBlastBeatApplication.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  I: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FBlastDensity <= 0) then Exit;

  // Add blast beat hits at the start of each bar
  for I := 0 to Trunc(Result.DurationBars) - 1 do
    if Random < FBlastDensity * Intensity * 0.25 then
    begin
      Result.AddBeat(I, TInstrumentRegistry.Get('snare_1_hit'), Round(110 * Intensity));
      Result.AddBeat(I + 0.25, TInstrumentRegistry.Get('kick_hit'), Round(115 * Intensity));
      Result.AddBeat(I + 0.5, TInstrumentRegistry.Get('snare_1_hit'), Round(105 * Intensity));
      Result.AddBeat(I + 0.75, TInstrumentRegistry.Get('kick_hit'), Round(110 * Intensity));
    end;
end;

end.
