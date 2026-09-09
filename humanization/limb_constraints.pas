unit LimbConstraints;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math,
  core_models_pattern;

// ============================================================================
// TLimbConstraintEngine — checks if a pattern is physically playable
// ============================================================================
type
  TLimbConstraintEngine = class
  private
    FMaxSimultaneousHits: Integer;
    FMinLimbGap: Double;
    function GetLimbForInstrument(Instrument: String): String;
  public
    constructor Create(A_MAX_SIM_HITS: Integer = 4; A_MIN_LIMB_GAP: Double = 0.01);
    function IsValid(APattern: TPattern): Boolean;
    function GetViolations(APattern: TPattern): TArray<String>;
    function FixPatterns(APattern: TPattern): TPattern;
  end;

implementation

constructor TLimbConstraintEngine.Create(A_MAX_SIM_HITS: Integer; A_MIN_LIMB_GAP: Double);
begin
  FMaxSimultaneousHits := A_MAX_SIM_HITS;
  FMinLimbGap := A_MIN_LIMB_GAP;
end;

function TLimbConstraintEngine.GetLimbForInstrument(Instrument: String): String;
begin
  // Map instrument to limb category
  if (Instrument = 'kick_hit') or (Instrument = 'kick_2_hit') or
     (Instrument = 'kick_3_hit') or (Instrument = 'kick_4_hit') then
    Result := 'foot'
  else if ((Instrument = 'snare_1_hit') or (Instrument = 'snare_rimshot_open_hit') or
           (Instrument = 'snare_sticks') or (Instrument = 'snare_sidestick')) then
    Result := 'hand_l' // snare typically left hand
  else if ((Instrument = 'hh_closed_1_tip_hit') or (Instrument = 'hh_open_d_hit') or
           (Instrument = 'hh_pedal_closed') or (Instrument = 'hh_pedal_open')) then
    Result := 'foot_r' // hi-hat foot
  else if ((Instrument = 'tom_1_open_hit') or (Instrument = 'tom_2_open_hit') or
           (Instrument = 'tom_3_open_hit') or (Instrument = 'tom_4_open_hit')) then
    Result := 'hand_r' // toms typically right hand
  else if ((Instrument = 'ride_1_tip_hit') or (Instrument = 'ride_2_tip_hit')) then
    Result := 'hand_r' // ride typically right hand
  else if ((Instrument = 'crash_1_hit') or (Instrument = 'cymbal_1_hit') or
           (Instrument = 'cymbal_2_hit') or (Instrument = 'cymbal_3_hit')) then
    Result := 'hand_l' // crash typically left hand
  else
    Result := 'unknown';
end;

function TLimbConstraintEngine.IsValid(APattern: TPattern): Boolean;
var
  BarIdx, BeatIdx, InnerIdx: Integer;
  SimHits: TArray<TBeat>;
  HitCount: Integer;
begin
  Result := True;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    
    // Group beats by time proximity
    SetLength(SimHits, 0);
    HitCount := 0;
    
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      // Find all beats within limb gap of this beat
      for InnerIdx := 0 to Result.Beats[BarIdx].Count - 1 do
      begin
        if (InnerIdx <> BeatIdx) and
           (Abs(Result.Beats[BarIdx][BeatIdx].Time - Result.Beats[BarIdx][InnerIdx].Time) < FMinLimbGap) then
        begin
          SetLength(SimHits, HitCount + 1);
          SimHits[HitCount] := Result.Beats[BarIdx][InnerIdx];
          Inc(HitCount);
        end;
      end;

      // Check if any limb has too many simultaneous hits
      if (HitCount >= FMaxSimultaneousHits) then
      begin
        Result := False;
        Exit;
      end;
    end;
  end;
end;

function TLimbConstraintEngine.GetViolations(APattern: TPattern): TArray<String>;
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
            
            // Check if same limb is assigned to two instruments
            if (Limb1 = Limb2) and (Limb1 <> 'unknown') then
            begin
              Violations.Add(Format('Bar %d: Same limb (%s) required for %s and %s',
                [BarIdx, Limb1, APattern.Beats[BarIdx][BeatIdx].Instrument,
                 APattern.Beats[BarIdx][InnerIdx].Instrument]));
            end;
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

function TLimbConstraintEngine.FixPatterns(APattern: TPattern): TPattern;
var
  BarIdx, BeatIdx, InnerIdx: Integer;
begin
  Result := APattern.Copy;

  // Remove or shift overlapping hits on same limb
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
            // Shift the later hit to avoid conflict
            Result.Beats[BarIdx][InnerIdx].Time := Result.Beats[BarIdx][InnerIdx].Time + FMinLimbGap;
          end;
        end;
      end;
    end;
  end;
end;

end.
