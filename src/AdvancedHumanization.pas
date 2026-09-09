unit AdvancedHumanization;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math,
  Pattern;

// ============================================================================
// THumanizationContext — holds context for context-aware humanization
// ============================================================================
type
  THumanizationContext = record
    Genre: String;
    Style: String;
    Section: String;
    Complexity: Double;
    Intensity: Double;
    Tempo: Integer;
  end;

// ============================================================================
// TAdvancedHumanizer — context-aware timing and velocity humanization
// ============================================================================
type
  TAdvancedHumanizer = class
  private
    FTimingJitter: Double;
    FVelocityCurve: Double;
    FGrooveMap: TStringList;
    function GetTimingDeviation(Instrument: String; Context: THumanizationContext): Double;
    function GetVelocityBias(Instrument: String, BaseVel: Integer; Context: THumanizationContext): Integer;
  public
    constructor Create(A_TIMING_JITTER: Double = 0.015; A_VELOCITY_CURVE: Double = 0.3);
    destructor Destroy; override;

    function Apply(APattern: TPattern; Context: THumanizationContext): TPattern;
    function GetHumanizedVelocity(BaseVel: Integer; Context: THumanizationContext): Integer;
  end;

implementation

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
begin
  // Genre-specific timing jitter profiles
  case Context.Genre of
    'metal':
      begin
        if (Context.Style = 'death') or (Context.Style = 'thrash') then
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
  if (Instrument = 'hh_closed_1_tip_hit') or (Instrument = 'ride_1_tip_hit') then
    Result := BaseJitter * 0.8 // cymbals tighter
  else if (Instrument = 'kick_hit') then
    Result := BaseJitter * 1.2 // kick looser
  else
    Result := BaseJitter;

  // Apply random jitter within range
  Result := Result * (Random(200) / 100.0 - 1.0);
end;

function TAdvancedHumanizer.GetVelocityBias(Instrument: String; BaseVel: Integer; Context: THumanizationContext): Integer;
var
  CurveFactor: Double;
begin
  // Velocity curve based on instrument and intensity
  CurveFactor := FVelocityCurve * Context.Intensity;

  if (Instrument = 'snare_1_hit') then
    Result := Round(BaseVel * (1.0 + CurveFactor * 0.1)) // snare gets slight boost
  else if ((Instrument = 'kick_hit') or (Instrument = 'crash_1_hit')) then
    Result := Round(BaseVel * (1.0 - CurveFactor * 0.05)) // kick/crash slight reduction
  else
    Result := BaseVel;

  // Clamp to valid range
  Result := Clamp(Result, 40, 127);
end;

function TAdvancedHumanizer.Apply(APattern: TPattern; Context: THumanizationContext): TPattern;
var
  BarIdx, BeatIdx: Integer;
  Deviation: Double;
  NewVel: Integer;
begin
  Result := APattern.Copy;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      // Apply timing jitter
      Deviation := GetTimingDeviation(Result.Beats[BarIdx][BeatIdx].Instrument, Context);
      Result.Beats[BarIdx][BeatIdx].Time := Result.Beats[BarIdx][BeatIdx].Time + Deviation;

      // Apply velocity bias
      NewVel := GetVelocityBias(Result.Beats[BarIdx][BeatIdx].Instrument,
                                Result.Beats[BarIdx][BeatIdx].Velocity, Context);
      Result.Beats[BarIdx][BeatIdx].Velocity := NewVel;
    end;
  end;
end;

function TAdvancedHumanizer.GetHumanizedVelocity(BaseVel: Integer; Context: THumanizationContext): Integer;
begin
  // Quick single-note humanization helper
  Result := Round(BaseVel * (1.0 + (Random(100) / 100.0 - 0.5) * FVelocityCurve * Context.Intensity));
  Result := Clamp(Result, 40, 127);
end;

end.
