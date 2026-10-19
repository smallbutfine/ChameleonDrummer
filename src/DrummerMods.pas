unit DrummerMods;

{$mode objfpc}{$H+}

{ Composable drummer style modifications. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Kit;

function HasAnyPrefix(const Str: String; const Prefixes: specialize TArray<String>): Boolean;

type
  TPatternModifier = class
  public
    function Apply(APattern: TPattern; Intensity: Double): TPattern; virtual; abstract;
  end;

function ApplyAndFreeModifier(AModifier: TPatternModifier; APattern: TPattern;
  Intensity: Double; OwnsPattern: Boolean = False): TPattern;

{ ── BehindBeatTiming ───────────────────────────────────── }
type
  TBehindBeatTiming = class(TPatternModifier)
  private
    FMaxDelayMs: Single;
  public
    constructor Create(A_MAX_DELAY_MS: Single);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── TripletVocabulary ──────────────────────────────────── }
type
  TTripletVocabulary = class(TPatternModifier)
  private
    FTripProbability: Double;
  public
    constructor Create(A_TRIP_PROBABILITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── GhostNoteLayer ─────────────────────────────────────── }
type
  TGhostNoteLayer = class(TPatternModifier)
  private
    FGhostDensity: Double;
  public
    constructor Create(A_GHOST_DENSITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── LinearCoordination ─────────────────────────────────── }
type
  TLinearCoordination = class(TPatternModifier)
  private
    FLinearProbability: Double;
  public
    constructor Create(A_LINEAR_PROBABILITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── HeavyAccents ───────────────────────────────────────── }
type
  THeavyAccents = class(TPatternModifier)
  private
    FAccentBoost: Integer;
  public
    constructor Create(A_ACCENT_BOOST: Integer);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── ShuffleFeelApplication ─────────────────────────────── }
type
  TShuffleFeelApplication = class(TPatternModifier)
  private
    FShuffleAmount: Double;
  public
    constructor Create(A_SHUFFLE_AMOUNT: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── FastChopsTriplets ──────────────────────────────────── }
type
  TFastChopsTriplets = class(TPatternModifier)
  private
    FChopProbability: Double;
  public
    constructor Create(A_CHOP_PROBABILITY: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── PocketStretching ───────────────────────────────────── }
type
  TPocketStretching = class(TPatternModifier)
  public
    constructor Create;
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── MinimalCreativity ──────────────────────────────────── }
type
  TMinimalCreativity = class(TPatternModifier)
  public
    constructor Create;
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── SpeedPrecision ─────────────────────────────────────── }
type
  TSpeedPrecision = class(TPatternModifier)
  public
    constructor Create;
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── TwistedAccents ─────────────────────────────────────── }
type
  TTwistedAccents = class(TPatternModifier)
  private
    FTwistAmount: Double;
  public
    constructor Create(A_TWIST_AMOUNT: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

{ ── MechanicalPrecision ────────────────────────────────── }
type
  TMechanicalPrecision = class(TPatternModifier)
  public
    constructor Create;
    function Apply(APattern: TPattern; Intensity: Double): TPattern; override;
  end;

implementation

function HasAnyPrefix(const Str: String; const Prefixes: specialize TArray<String>): Boolean;
var P: string;
begin
  for P in Prefixes do
    if Pos(LowerCase(P), Str) = 1 then Exit(True);
  Result := False;
end;

function ApplyAndFreeModifier(AModifier: TPatternModifier; APattern: TPattern;
  Intensity: Double; OwnsPattern: Boolean): TPattern;
begin
  Result := nil;
  if not Assigned(AModifier) then
    raise Exception.Create('Cannot apply an unassigned drummer modifier');
  try
    Result := AModifier.Apply(APattern, Intensity);
  finally
    AModifier.Free;
    if OwnsPattern and Assigned(APattern) and (APattern <> Result) then
      APattern.Free;
  end;
end;

{ TBehindBeatTiming }
constructor TBehindBeatTiming.Create(A_MAX_DELAY_MS: Single);
begin FMaxDelayMs := A_MAX_DELAY_MS; end;

function TBehindBeatTiming.Apply(APattern: TPattern; Intensity: Double): TPattern;
var Beat: TBeat; InstName: String; OffsetMs: Single;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FMaxDelayMs <= 0) then Exit;
  for Beat in Result.Beats do
  begin
    if not Assigned(Beat.Instrument) then Continue;
    InstName := LowerCase(Beat.Instrument.Name);
    if ((Pos('kick', InstName) = 1) or (Pos('snare', InstName) = 1)) then
    begin
      OffsetMs := FMaxDelayMs * Intensity * (0.5 + Random * 0.5);
      Beat.Position := Beat.Position + (OffsetMs / 1000.0);
    end;
  end;
end;

{ TTripletVocabulary }
constructor TTripletVocabulary.Create(A_TRIP_PROBABILITY: Double);
begin FTripProbability := A_TRIP_PROBABILITY; end;

function TTripletVocabulary.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FTripProbability <= 0) then Exit;
  for BIdx := 0 to Result.Beats.Count - 1 do
    if (Result.Beats[BIdx].Position mod 4.0 = 3.0) and (Random < FTripProbability * Intensity * 0.2) then
      Result.AddBeat(0.5, TInstrumentRegistry.Get('snare_1_hit'), Round(90 * Intensity));
end;

{ THeavyAccents }
constructor THeavyAccents.Create(A_ACCENT_BOOST: Integer);
begin FAccentBoost := A_ACCENT_BOOST; end;

function THeavyAccents.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer; BoostedVel: Integer; InstName: String;
begin
  Result := APattern.Copy;
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    if not Assigned(Result.Beats[BIdx].Instrument) then Continue;
    InstName := LowerCase(Result.Beats[BIdx].Instrument.Name);
    if ((HasAnyPrefix(InstName, ['snare', 'kick'])) and
        not Result.Beats[BIdx].GhostNote and (Intensity > 0.5)) then
      Result.Beats[BIdx].Velocity := Trunc(Min(127, Result.Beats[BIdx].Velocity + FAccentBoost) * Intensity);
  end;
end;

{ TGhostNoteLayer }
constructor TGhostNoteLayer.Create(A_GHOST_DENSITY: Double);
begin FGhostDensity := A_GHOST_DENSITY; end;

function TGhostNoteLayer.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BIdx, SourceBeatCount, GhostCount, MaxGhostsPerBar: Integer;
  EffDensity, ScaleF: Double;
  BarStart: Double;
  InstName: String;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FGhostDensity <= 0) then Exit;

  EffDensity := FGhostDensity * Intensity;
  if EffDensity >= 0.99 then ScaleF := 1.0
  else if Result.Beats.Count <= 6 then ScaleF := 1.0
  else if Result.Beats.Count <= 14 then ScaleF := 0.6
  else ScaleF := 0.3;
  EffDensity := EffDensity * ScaleF;
  MaxGhostsPerBar := Max(2, Trunc((16 - Result.Beats.Count) * EffDensity));

  SourceBeatCount := Result.Beats.Count;
  GhostCount := 0; BarStart := -1.0;
  for BIdx := 0 to SourceBeatCount - 1 do
  begin
    if Trunc(Result.Beats[BIdx].Position) > Trunc(BarStart) then begin GhostCount := 0; BarStart := Result.Beats[BIdx].Position; end;
    if GhostCount >= MaxGhostsPerBar then Continue;
    if not Assigned(Result.Beats[BIdx].Instrument) then Continue;
    InstName := LowerCase(Result.Beats[BIdx].Instrument.Name);
    if ((InstName = 'snare') or
        (InstName = 'snare_open_hit_open_lateral_hit') or
        (InstName = 'snare_rimshot_open_hit')) and
       (GhostCount < MaxGhostsPerBar) then
    begin
      Inc(GhostCount);
      Result.Beats.Add(TBeat.Create(Result.Beats[BIdx].Position + 0.25,
        TInstrumentRegistry.Get('snare_rimshot_open_hit'), Max(30, Trunc(35 * Intensity))));
      Result.Beats[Result.Beats.Count - 1].GhostNote := True;
    end;
  end;
end;

{ TLinearCoordination }
constructor TLinearCoordination.Create(A_LINEAR_PROBABILITY: Double);
begin FLinearProbability := A_LINEAR_PROBABILITY; end;

function TLinearCoordination.Apply(APattern: TPattern; Intensity: Double): TPattern;
var I, J: Integer; TimeDiff: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FLinearProbability <= 0) then Exit;
  for I := 0 to Result.Beats.Count - 2 do
    for J := I + 1 to Result.Beats.Count - 1 do
      if Abs(Result.Beats[I].Position - Result.Beats[J].Position) < 0.01 then
        if (Result.Beats[I].Instrument <> Result.Beats[J].Instrument) and (Random < FLinearProbability * Intensity) then
          Result.Beats[J].Position := Max(0.0, Result.Beats[J].Position + 0.0625);
end;

{ TShuffleFeelApplication }
constructor TShuffleFeelApplication.Create(A_SHUFFLE_AMOUNT: Double);
begin FShuffleAmount := A_SHUFFLE_AMOUNT; end;

function TShuffleFeelApplication.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer; BeatWithinQuarter, ShuffleOffset: Double;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FShuffleAmount <= 0) then Exit;
  ShuffleOffset := FShuffleAmount * Intensity * 0.25;
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    BeatWithinQuarter := Result.Beats[BIdx].Position mod 1.0;
    if (Abs(BeatWithinQuarter - 0.25) < 0.01) or (Abs(BeatWithinQuarter - 0.75) < 0.01) then
      Result.Beats[BIdx].Position := Max(0.0, Result.Beats[BIdx].Position + ShuffleOffset);
  end;
end;

{ TFastChopsTriplets }
constructor TFastChopsTriplets.Create(A_CHOP_PROBABILITY: Double);
begin FChopProbability := A_CHOP_PROBABILITY; end;

function TFastChopsTriplets.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FChopProbability <= 0) then Exit;
  for BIdx := 0 to Result.Beats.Count - 1 do
    if Random < FChopProbability * Intensity * 0.2 then
      Result.AddBeat(Trunc(Result.Beats[BIdx].Position), TInstrumentRegistry.Get('tom_2_open_hit'), Round(100 * Intensity));
end;

{ TPocketStretching }
constructor TPocketStretching.Create;
begin inherited Create; end;

function TPocketStretching.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer; MicroDelay: Double; InstName: String;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;
  // Clamp micro-delay to positive range only — negative delays cause sub-zero positions
  MicroDelay := ((Random(100) / 100.0) * 0.5) * 0.02 * Intensity; // 0 .. +0.01 * Intensity
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    if not Assigned(Result.Beats[BIdx].Instrument) then Continue;
    InstName := LowerCase(Result.Beats[BIdx].Instrument.Name);
    if HasAnyPrefix(InstName, ['kick', 'snare']) then
      Result.Beats[BIdx].Position := Result.Beats[BIdx].Position + MicroDelay;
  end;
end;

{ TMinimalCreativity }
constructor TMinimalCreativity.Create;
begin inherited Create; end;

function TMinimalCreativity.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx, DelIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (Result.Beats.Count <= 2) then Exit;
  // Delete backwards so indices don't shift during iteration
  for BIdx := Result.Beats.Count - 1 downto 0 do
    if Random < Intensity * 0.4 then
    begin
      DelIdx := BIdx;
      Result.Beats[DelIdx].Free;
      Result.Beats.Delete(DelIdx);
    end;
end;

{ TSpeedPrecision }
constructor TSpeedPrecision.Create;
begin inherited Create; end;

function TSpeedPrecision.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;
  for BIdx := 0 to Result.Beats.Count - 1 do
    if Assigned(Result.Beats[BIdx].Instrument) then
      Result.Beats[BIdx].Velocity := Min(127, Max(80, Round(105 * Intensity)));
end;

{ TTwistedAccents }
constructor TTwistedAccents.Create(A_TWIST_AMOUNT: Double);
begin FTwistAmount := A_TWIST_AMOUNT; end;

function TTwistedAccents.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer; InstName: String;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) or (FTwistAmount <= 0) then Exit;
  for BIdx := 0 to Result.Beats.Count - 1 do
  begin
    if not Assigned(Result.Beats[BIdx].Instrument) then Continue;
    InstName := LowerCase(Result.Beats[BIdx].Instrument.Name);
    if HasAnyPrefix(InstName, ['snare', 'kick']) then
      Result.Beats[BIdx].Position := Max(0.0, Result.Beats[BIdx].Position + (FTwistAmount * 0.05 * (Random - 0.5)));
  end;
end;

{ TMechanicalPrecision }
constructor TMechanicalPrecision.Create;
begin inherited Create; end;

function TMechanicalPrecision.Apply(APattern: TPattern; Intensity: Double): TPattern;
var BIdx: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;
  for BIdx := 0 to Result.Beats.Count - 1 do
    Result.Beats[BIdx].Position := Max(0.0, Round(Result.Beats[BIdx].Position * 32) / 32.0);
end;

end.
