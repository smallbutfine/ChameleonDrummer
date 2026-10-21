unit AdvancedHumanization;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math,
  Pattern;

// ============================================================================
// THumanizationContext â€” holds context for context-aware humanization
// ============================================================================
type
  THumanizationContext = record
    Genre: String;
    Style: String;
    Section: String;
    Complexity: Double;
    Intensity: Double;
    Humanization: Double;
    Tempo: Integer;
    SourceRandom: TThreadedRandom;
  end;


// ============================================================================
// TAdvancedHumanizer â€” context-aware timing and velocity humanization
// ============================================================================
type
  TAdvancedHumanizer = class
  private
    FTimingJitter: Double;
    FVelocityCurve: Double;
    FGrooveMap: TStringList;
    function GetTimingDeviation(Instrument: String; Context: THumanizationContext): Double;
    function GetVelocityBias(Instrument: String; BaseVel: Integer; Context: THumanizationContext): Integer;
  public
    constructor Create(A_TIMING_JITTER: Double = 0.015; A_VELOCITY_CURVE: Double = 0.3);
    destructor Destroy; override;

    function Apply(APattern: TPattern; Context: THumanizationContext): TPattern;
    function GetHumanizedVelocity(BaseVel: Integer; Context: THumanizationContext): Integer;
  end;

implementation

function IsInstrumentFamily(const AInstrument, AFamily: string): Boolean;
var
  InstrumentName: string;
begin
  InstrumentName := LowerCase(Trim(AInstrument));
  Result := (InstrumentName = AFamily) or
    (Pos(AFamily + '_', InstrumentName) = 1);
end;

constructor TAdvancedHumanizer.Create(A_TIMING_JITTER: Double; A_VELOCITY_CURVE: Double);
begin
  FTimingJitter := A_TIMING_JITTER;
  FVelocityCurve := A_VELOCITY_CURVE;
  FGrooveMap := TStringList.Create;
end;

destructor TAdvancedHumanizer.Destroy;
begin
  FGrooveMap.Free;
  inherited Destroy;
end;

function TAdvancedHumanizer.GetTimingDeviation(Instrument: String; Context: THumanizationContext): Double;
var
  BaseJitter: Double;
  InstrumentName: string;
begin
  InstrumentName := LowerCase(Trim(Instrument));

  // Genre-specific timing jitter profiles
  case LowerCase(Context.Genre) of
    'metal':
      begin
        if SameText(Context.Style, 'death') or SameText(Context.Style, 'thrash') then
          BaseJitter := FTimingJitter * 0.5 // tighter for fast metal
        else
          BaseJitter := FTimingJitter;
      end;
    'jazz':
      BaseJitter := FTimingJitter * 1.5; // more swing
    'funk':
      BaseJitter := FTimingJitter * 1.2;
  else
    BaseJitter := FTimingJitter;
  end;

  // Instrument-specific deviations
  if (Pos('hh_', InstrumentName) = 1) or
     (Pos('ride_', InstrumentName) = 1) then
    Result := BaseJitter * 0.8 // cymbals tighter
  else if IsInstrumentFamily(InstrumentName, 'kick') then
    Result := BaseJitter * 1.2 // kick looser
  else
    Result := BaseJitter;

  // Apply random jitter within range
  Result := Result * (Context.SourceRandom.Random(200) / 100.0 - 1.0);
end;


function TAdvancedHumanizer.GetVelocityBias(Instrument: String; BaseVel: Integer; Context: THumanizationContext): Integer;
var
  CurveFactor: Double;
begin
  // Velocity curve based on instrument and intensity
  CurveFactor := FVelocityCurve * EnsureRange(Context.Intensity, 0.0, 1.0) *
    EnsureRange(Context.Humanization, 0.0, 1.0);

  if IsInstrumentFamily(Instrument, 'snare') then
    Result := Round(BaseVel * (1.0 + CurveFactor * 0.1)) // snare gets slight boost
  else if IsInstrumentFamily(Instrument, 'kick') or
          IsInstrumentFamily(Instrument, 'crash') or
          IsInstrumentFamily(Instrument, 'cymbal') then
    Result := Round(BaseVel * (1.0 - CurveFactor * 0.05)) // kick/crash slight reduction
  else
    Result := BaseVel;

  Result := Max(0, Min(127, Result));
end;

function TAdvancedHumanizer.Apply(APattern: TPattern; Context: THumanizationContext): TPattern;
var
  Deviation, HumanizationAmount: Double;
  NewVel: Integer;
  Beat: TBeat;
begin
  if not Assigned(APattern) then
    Exit(nil);

  Result := APattern.Copy;
  HumanizationAmount := EnsureRange(Context.Humanization, 0.0, 1.0);
  if HumanizationAmount <= 0 then
    Exit;

  for Beat in Result.Beats do
  begin
    if not Assigned(Beat.Instrument) then
      Continue;

    Deviation := GetTimingDeviation(Beat.Instrument.Name, Context) *
      HumanizationAmount;
    Beat.Position := Max(0.0, Beat.Position + Deviation);

    NewVel := GetVelocityBias(Beat.Instrument.Name, Beat.Velocity, Context);
    Beat.Velocity := GetHumanizedVelocity(NewVel, Context);
  end;
end;

function TAdvancedHumanizer.GetHumanizedVelocity(BaseVel: Integer; Context: THumanizationContext): Integer;
begin
  if BaseVel <= 0 then
    Exit(BaseVel);

  Result := Round(BaseVel * (1.0 + (Random(100) / 100.0 - 0.5) *
    FVelocityCurve * EnsureRange(Context.Intensity, 0.0, 1.0) *
    EnsureRange(Context.Humanization, 0.0, 1.0)));
  Result := Max(1, Min(127, Result));
end;

end.
