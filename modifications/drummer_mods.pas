unit DrummerMods;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math,
  core_models_pattern;

// ============================================================================
// BehindBeatTiming — delays hits slightly behind the beat (Bonham signature)
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
// TriplettVocabulary — adds triplet-based fills and phrasing
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
// HeavyAccents — increases accent contrast for power playing
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
// GhostNoteLayer — adds subtle ghost notes for groove
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
// LinearCoordination — removes simultaneous hits for linear playing
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
// ShuffleFeelApplication — adds shuffle/swing feel (Porcaro signature)
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
// FastChopsTriplets — fast technical fills (Chambers signature)
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
// PocketStretching — subtle groove variations (Chambers signature)
// ============================================================================
type
  TPocketStretching = class
  public
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// MinimalCreativity — sparse, atmospheric approach (Roeder signature)
// ============================================================================
type
  TMinimalCreativity = class
  public
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

// ============================================================================
// SpeedPrecision — consistent timing/velocity (Dee signature)
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
// TwistedAccents — displaced accents (Dee signature)
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
// MechanicalPrecision — extreme quantization (Hoglan signature)
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
// BlastBeatApplication — applies blast beats for metal (Hoglan signature)
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

{ TBehindBeatTiming }
constructor TBehindBeatTiming.Create(A_MAX_DELAY_MS: Double);
begin
  FMaxDelayMs := A_MAX_DELAY_MS;
end;

function TBehindBeatTiming.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx: Integer;
  DelayedBeat: TBeat;
  MaxBar: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  MaxBar := Result.BarsCount - 1;
  for BarIdx := 0 to MaxBar do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      if (Random < Intensity * 0.3) then
      begin
        DelayedBeat := TBeat.Create(
          Result.Beats[BarIdx][BeatIdx].Instrument,
          Result.Beats[BarIdx][BeatIdx].Time + FMaxDelayMs / 1000.0 * Intensity,
          Round(Result.Beats[BarIdx][BeatIdx].Velocity * 0.95)
        );
        DelayedBeat.IsGhost := True;
        Result.Beats[BarIdx].Insert(BeatIdx, DelayedBeat);
      end;
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
  BarIdx: Integer;
  BeatIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FTripProbability <= 0) then Exit;

  for BarIdx := 1 to Result.BarsCount - 1 do
  begin
    if (Random < FTripProbability * Intensity * 0.2) then
    begin
      // Add triplet accent at bar start
      BeatIdx := Result.Beats[BarIdx].Add(0.5, 'snare_1_hit', 90);
      if (BeatIdx >= 0) then
        Result.Beats[BarIdx][BeatIdx].Velocity := Round(90 * Intensity);
    end;
  end;
end;

{ THeavyAccents }
constructor THeavyAccents.Create(A_ACCENT_BOOST: Integer);
begin
  FAccentBoost := A_ACCENT_BOOST;
end;

function THeavyAccents.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx: Integer;
  BoostedVel: Integer;
begin
  Result := APattern.Copy;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      // Boost snare and kick accents
      if ((Result.Beats[BarIdx][BeatIdx].Instrument = 'snare_1_hit') or
          (Result.Beats[BarIdx][BeatIdx].Instrument = 'kick_hit')) and
         (Intensity > 0.5) then
      begin
        BoostedVel := Min(127, Result.Beats[BarIdx][BeatIdx].Velocity + FAccentBoost);
        Result.Beats[BarIdx][BeatIdx].Velocity := Round(BoostedVel * Intensity);
      end;
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
  BarIdx, BeatIdx: Integer;
  GhostBeat: TBeat;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FGhostDensity <= 0) then Exit;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      if (Random < FGhostDensity * Intensity * 0.4) and
         (Result.Beats[BarIdx][BeatIdx].Instrument = 'snare_1_hit') then
      begin
        GhostBeat := TBeat.Create('snare_1_hit',
          Result.Beats[BarIdx][BeatIdx].Time + 0.25,
          Round(40 * Intensity));
        GhostBeat.IsGhost := True;
        Result.Beats[BarIdx].Add(GhostBeat);
      end;
    end;
  end;
end;

{ TLinearCoordination }
constructor TLinearCoordination.Create(A_LINEAR_PROBABILITY: Double);
begin
  FLinearProbability := A_LINEAR_PROBABILITY;
end;

function TLinearCoordination.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx, I: Integer;
  TimeDiff: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FLinearProbability <= 0) then Exit;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    // Find and shift simultaneous hits on different instruments
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 2 do
    begin
      for I := BeatIdx + 1 to Result.Beats[BarIdx].Count - 1 do
      begin
        TimeDiff := Abs(Result.Beats[BarIdx][BeatIdx].Time - Result.Beats[BarIdx][I].Time);
        if (TimeDiff < 0.01) and
           (Result.Beats[BarIdx][BeatIdx].Instrument <> Result.Beats[BarIdx][I].Instrument) then
        begin
          if (Random < FLinearProbability * Intensity) then
          begin
            // Shift the second hit slightly to avoid simultaneity
            Result.Beats[BarIdx][I].Time := Result.Beats[BarIdx][I].Time + 0.0625;
          end;
        end;
      end;
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
  BarIdx, BeatIdx: Integer;
  ShuffleOffset: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FShuffleAmount <= 0) then Exit;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    ShuffleOffset := FShuffleAmount * Intensity * 0.125; // 1/16th note shuffle
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      // Apply triplet-based offset to hi-hat and ride hits
      if (Result.Beats[BarIdx][BeatIdx].Instrument = 'hh_closed_1_tip_hit') or
         (Result.Beats[BarIdx][BeatIdx].Instrument = 'ride_1_tip_hit') then
      begin
        // Odd beats get delayed, even beats get early
        if (BeatIdx mod 2 = 1) then
          Result.Beats[BarIdx][BeatIdx].Time := Result.Beats[BarIdx][BeatIdx].Time + ShuffleOffset
        else
          Result.Beats[BarIdx][BeatIdx].Time := Result.Beats[BarIdx][BeatIdx].Time - (ShuffleOffset * 0.5);
      end;
    end;
  end;
end;

{ TFastChopsTriplets }
constructor TFastChopsTriplets.Create(A_CHOP_PROBABILITY: Double);
begin
  FChopProbability := A_CHOP_PROBABILITY;
end;

function TFastChopsTriplets.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx: Integer;
  BeatIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FChopProbability <= 0) then Exit;

  for BarIdx := 1 to Result.BarsCount - 1 do
  begin
    if (Random < FChopProbability * Intensity * 0.3) then
    begin
      // Add tom chop at bar boundary
      BeatIdx := Result.Beats[BarIdx].Add(0.0, 'tom_2_open_hit', Round(100 * Intensity));
      if (BeatIdx >= 0) then
        Result.Beats[BarIdx][BeatIdx].IsGhost := False;
    end;
  end;
end;

{ TPocketStretching }
function TPocketStretching.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx: Integer;
  MicroDelay: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    // Subtle micro-timing variations for pocket feel
    MicroDelay := (Random(100) / 100.0 - 0.5) * 0.02 * Intensity;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      if ((Result.Beats[BarIdx][BeatIdx].Instrument = 'kick_hit') or
          (Result.Beats[BarIdx][BeatIdx].Instrument = 'snare_1_hit')) then
      begin
        Result.Beats[BarIdx][BeatIdx].Time := Result.Beats[BarIdx][BeatIdx].Time + MicroDelay;
      end;
    end;
  end;
end;

{ TMinimalCreativity }
function TMinimalCreativity.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  // Remove some beats for sparse atmosphere
  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    if (Random < Intensity * 0.4) and (Result.Beats[BarIdx].Count > 2) then
    begin
      // Randomly remove a non-essential beat
      BeatIdx := Random(Result.Beats[BarIdx].Count - 1);
      Result.Beats[BarIdx].Delete(BeatIdx);
    end;
  end;
end;

{ TSpeedPrecision }
constructor TSpeedPrecision.Create(A_VELOCITY_TOLERANCE: Double);
begin
  FVelocityTolerance := A_VELOCITY_TOLERANCE;
end;

function TSpeedPrecision.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx: Integer;
  AvgVel: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  // Normalize velocities toward precision
  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      AvgVel := Round(Result.Beats[BarIdx][BeatIdx].Velocity * FVelocityTolerance +
                      100 * (1.0 - FVelocityTolerance));
      Result.Beats[BarIdx][BeatIdx].Velocity := Clamp(AvgVel, 40, 127);
    end;
  end;
end;

{ TTwistedAccents }
constructor TTwistedAccents.Create(A_ACCENT_DISPLACEMENT: Integer);
begin
  FAccentDisplacement := A_ACCENT_DISPLACEMENT;
end;

function TTwistedAccents.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx: Integer;
  DisplacedTime: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      if (Random < Intensity * 0.3) and
         (Result.Beats[BarIdx][BeatIdx].Instrument = 'snare_1_hit') then
      begin
        // Displace accent by a fraction of a beat
        DisplacedTime := Result.Beats[BarIdx][BeatIdx].Time +
                         (FAccentDisplacement / 480.0); // ~32nd note at 4/4
        Result.Beats[BarIdx][BeatIdx].Time := DisplacedTime;
      end;
    end;
  end;
end;

{ TMechanicalPrecision }
constructor TMechanicalPrecision.Create(A_QUANT_STRENGTH: Double);
begin
  FQuantizationStrength := A_QUANT_STRENGTH;
end;

function TMechanicalPrecision.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx: Integer;
  QuantTime: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  // Quantize all notes to strict grid with strength factor
  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      // Quantize to nearest sixteenth note
      QuantTime := Round(Result.Beats[BarIdx][BeatIdx].Time * 16) / 16.0;
      Result.Beats[BarIdx][BeatIdx].Time :=
        Result.Beats[BarIdx][BeatIdx].Time * (1.0 - FQuantizationStrength) +
        QuantTime * FQuantizationStrength;
    end;
  end;
end;

{ TBlastBeatApplication }
constructor TBlastBeatApplication.Create(A_BLAST_DENSITY: Double);
begin
  FBlastDensity := A_BLAST_DENSITY;
end;

function TBlastBeatApplication.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FBlastDensity <= 0) then Exit;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    if (Random < FBlastDensity * Intensity * 0.25) then
    begin
      // Add rapid snare/kick pattern for blast beat feel
      Result.Beats[BarIdx].Add(0.0, 'snare_1_hit', Round(110 * Intensity));
      Result.Beats[BarIdx].Add(0.25, 'kick_hit', Round(115 * Intensity));
      Result.Beats[BarIdx].Add(0.5, 'snare_1_hit', Round(105 * Intensity));
      Result.Beats[BarIdx].Add(0.75, 'kick_hit', Round(110 * Intensity));
    end;
  end;
end;

end.
