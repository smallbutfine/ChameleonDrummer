unit PhysicalConstraints;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math,
  core_models_pattern;

// ============================================================================
// TPhysicalConstraintResult — Result of physical playability validation
// ============================================================================
type
  TPhysicalConstraintResult = record
    IsValid: Boolean;
    Violations: TArray<String>;
    MaxSimultaneousHits: Integer;
    MinLimbGap: Double;
  end;

// ============================================================================
// TPhysicalConstraintChecker — Validates patterns against physical playability
// ============================================================================
type
  TPhysicalConstraintChecker = class
  private
    FMaxSimultaneousHits: Integer;
    FMinLimbGap: Double;

    function GetLimbForInstrument(Instrument: String): String;
    function CheckSimultaneousHits(APattern: TPattern): TArray<String>;
    function CheckLimbConflicts(APattern: TPattern): TArray<String>;
  public
    constructor Create(A_MAX_SIM_HITS: Integer = 4; A_MIN_LIMB_GAP: Double = 0.01);

    function Validate(APattern: TPattern): TPhysicalConstraintResult;
    function FixViolations(APattern: TPattern): TPattern;
  end;

implementation

constructor TPhysicalConstraintChecker.Create(A_MAX_SIM_HITS: Integer; A_MIN_LIMB_GAP: Double);
begin
  FMaxSimultaneousHits := A_MAX_SIM_HITS;
  FMinLimbGap := A_MIN_LIMB_GAP;
end;

function TPhysicalConstraintChecker.GetLimbForInstrument(Instrument: String): String;
begin
  if (Instrument = 'kick_hit') or (Instrument = 'kick_2_hit') then
    Result := 'foot'
  else if ((Instrument = 'snare_1_hit') or (Instrument = 'snare_rimshot_open_hit') or
           (Instrument = 'snare_sticks') or (Instrument = 'snare_sidestick')) then
    Result := 'hand_l'
  else if ((Instrument = 'hh_closed_1_tip_hit') or (Instrument = 'hh_open_d_hit') or
           (Instrument = 'hh_pedal_closed') or (Instrument = 'hh_pedal_open')) then
    Result := 'foot_r'
  else if ((Instrument = 'tom_1_open_hit') or (Instrument = 'tom_2_open_hit') or
           (Instrument = 'tom_3_open_hit') or (Instrument = 'tom_4_open_hit')) then
    Result := 'hand_r'
  else if ((Instrument = 'ride_1_tip_hit') or (Instrument = 'ride_2_tip_hit')) then
    Result := 'hand_r'
  else if ((Instrument = 'crash_1_hit') or (Instrument = 'cymbal_1_hit') or
           (Instrument = 'cymbal_2_hit')) then
    Result := 'hand_l'
  else
    Result := 'unknown';
end;

function TPhysicalConstraintChecker.CheckSimultaneousHits(APattern: TPattern): TArray<String>;
var
  Violations: TStringList;
  BarIdx, BeatIdx, InnerIdx: Integer;
  HitCount: Integer;
begin
  Violations := TStringList.Create;
  try
    for BarIdx := 0 to APattern.BarsCount - 1 do
    begin
      if (BarIdx >= APattern.Beats.Count) then Break;

      // Group beats by time proximity
      HitCount := 0;
      for BeatIdx := 0 to APattern.Beats[BarIdx].Count - 1 do
      begin
        for InnerIdx := BeatIdx + 1 to APattern.Beats[BarIdx].Count - 1 do
        begin
          if (Abs(APattern.Beats[BarIdx][BeatIdx].Time - APattern.Beats[BarIdx][InnerIdx].Time) < FMinLimbGap) then
            Inc(HitCount);
        end;
      end;

      if (HitCount >= FMaxSimultaneousHits) then
        Violations.Add(Format('Bar %d: Too many simultaneous hits (%d)', [BarIdx, HitCount]));
    end;

    SetLength(Result, Violations.Count);
    for BarIdx := 0 to Violations.Count - 1 do
      Result[BarIdx] := Violations[BarIdx];
  finally
    Violations.Free;
  end;
end;

function TPhysicalConstraintChecker.CheckLimbConflicts(APattern: TPattern): TArray<String>;
var
  Violations: TStringList;
  BarIdx, BeatIdx, InnerIdx: Integer;
  Limb1, Limb2: String;
begin
  Violations := TStringList.Create;
  try
    for BarIdx := 0 to APattern.BarsCount - 1 do
    begin
      if (BarIdx >= APattern.Beats.Count) then Break;

      for BeatIdx := 0 to APattern.Beats[BarIdx].Count - 2 do
      begin
        for InnerIdx := BeatIdx + 1 to APattern.Beats[BarIdx].Count - 1 do
        begin
          if (Abs(APattern.Beats[BarIdx][BeatIdx].Time - APattern.Beats[BarIdx][InnerIdx].Time) < FMinLimbGap) then
          begin
            Limb1 := GetLimbForInstrument(APattern.Beats[BarIdx][BeatIdx].Instrument);
            Limb2 := GetLimbForInstrument(APattern.Beats[BarIdx][InnerIdx].Instrument);

            if ((Limb1 = Limb2) and (Limb1 <> 'unknown')) then
              Violations.Add(Format('Bar %d: Same limb (%s) required for %s and %s',
                [BarIdx, Limb1, APattern.Beats[BarIdx][BeatIdx].Instrument,
                 APattern.Beats[BarIdx][InnerIdx].Instrument]));
          end;
        end;
      end;
    end;

    SetLength(Result, Violations.Count);
    for BarIdx := 0 to Violations.Count - 1 do
      Result[BarIdx] := Violations[BarIdx];
  finally
    Violations.Free;
  end;
end;

function TPhysicalConstraintChecker.Validate(APattern: TPattern): TPhysicalConstraintResult;
var
  SimViolations, LimbViolations: TArray<String>;
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  SimViolations := CheckSimultaneousHits(APattern);
  LimbViolations := CheckLimbConflicts(APattern);

  // Merge violations
  SetLength(Result.Violations, Length(SimViolations) + Length(LimbViolations));
  for I := 0 to Length(SimViolations) - 1 do
    Result.Violations[I] := SimViolations[I];
  for I := 0 to Length(LimbViolations) - 1 do
    Result.Violations[Length(SimViolations) + I] := LimbViolations[I];

  Result.IsValid := Length(Result.Violations) = 0;
end;

function TPhysicalConstraintChecker.FixViolations(APattern: TPattern): TPattern;
var
  BarIdx, BeatIdx, InnerIdx: Integer;
begin
  Result := APattern.Copy;

  // Shift overlapping hits to resolve limb conflicts
  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;

    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 2 do
    begin
      for InnerIdx := BeatIdx + 1 to Result.Beats[BarIdx].Count - 1 do
      begin
        if (Abs(Result.Beats[BarIdx][BeatIdx].Time - Result.Beats[BarIdx][InnerIdx].Time) < FMinLimbGap) then
        begin
          if (GetLimbForInstrument(Result.Beats[BarIdx][BeatIdx].Instrument) =
              GetLimbForInstrument(Result.Beats[BarIdx][InnerIdx].Instrument)) then
          begin
            Result.Beats[BarIdx][InnerIdx].Time := Result.Beats[BarIdx][InnerIdx].Time + FMinLimbGap;
          end;
        end;
      end;
    end;
  end;
end;

end.
