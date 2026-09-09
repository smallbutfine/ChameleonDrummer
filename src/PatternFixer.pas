unit PatternFixer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math,
  Pattern;

// ============================================================================
// TPatternFixer — Post-generation pattern repair utilities
// ============================================================================
type
  TPatternFixer = class
  private
    function FixEmptyBars(APattern: TPattern): TPattern;
    function FixOvercrowdedBars(APattern: TPattern): TPattern;
    function FixVelocityClipping(APattern: TPattern): TPattern;
    function FixTimingBounds(APattern: TPattern): TPattern;
  public
    constructor Create;

    function Fix(APattern: TPattern): TPattern;
    function GetFixSummary(APattern: TPattern): TArray<String>;
  end;

implementation

constructor TPatternFixer.Create;
begin
  // No initialization needed
end;

function TPatternFixer.FixEmptyBars(APattern: TPattern): TPattern;
var
  BarIdx, BeatIdx: Integer;
  MinNotesPerBar: Integer;
begin
  Result := APattern.Copy;
  MinNotesPerBar := 3; // Minimum notes per bar for a playable pattern

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;

    // Check each beat group within the bar
    if (Result.Beats[BarIdx].Count < MinNotesPerBar) then
    begin
      // Add basic kick/snare/hihat framework to empty bars
      for BeatIdx := 0 to 3 do
      begin
        case BeatIdx of
          0: Result.Beats[BarIdx].Add(BeatIdx * 1.0, 'kick_hit', 100); // Kick on beat 1
          1: Result.Beats[BarIdx].Add(BeatIdx * 1.0, 'snare_1_hit', 95); // Snare on beat 2
          2: Result.Beats[BarIdx].Add((BeatIdx + 0.5) * 1.0, 'hh_closed_1_tip_hit', 80); // HH on off-beat
          3: Result.Beats[BarIdx].Add(BeatIdx * 1.0, 'hh_closed_1_tip_hit', 80); // HH on beat 4
        end;
      end;
    end;
  end;
end;

function TPatternFixer.FixOvercrowdedBars(APattern: TPattern): TPattern;
var
  BarIdx, BeatIdx: Integer;
  MaxNotesPerBeat: Integer;
begin
  Result := APattern.Copy;
  MaxNotesPerBeat := 5; // Reasonable max notes per beat position

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;

    // Check beats within this bar section
    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 2 do
    begin
      // If too many notes at similar time positions, remove extras
      if (Result.Beats[BarIdx].Count > MaxNotesPerBeat * 4) then
      begin
        // Remove lowest velocity notes first (preserving accents)
        Result.Beats[BarIdx].Delete(Result.Beats[BarIdx].Count - 1);
      end;
    end;
  end;
end;

function TPatternFixer.FixVelocityClipping(APattern: TPattern): TPattern;
var
  BarIdx, BeatIdx: Integer;
begin
  Result := APattern.Copy;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;

    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      // Clamp velocities to valid MIDI range
      if (Result.Beats[BarIdx][BeatIdx].Velocity < 1) then
        Result.Beats[BarIdx][BeatIdx].Velocity := 1;

      if (Result.Beats[BarIdx][BeatIdx].Velocity > 127) then
        Result.Beats[BarIdx][BeatIdx].Velocity := 127;
    end;
  end;
end;

function TPatternFixer.FixTimingBounds(APattern: TPattern): TPattern;
var
  BarIdx, BeatIdx: Integer;
begin
  Result := APattern.Copy;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;

    for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      // Ensure timing is within bar bounds [0, 4.0)
      if (Result.Beats[BarIdx][BeatIdx].Time < 0) then
        Result.Beats[BarIdx][BeatIdx].Time := 0;

      if (Result.Beats[BarIdx][BeatIdx].Time >= 4.0) then
        Result.Beats[BarIdx][BeatIdx].Time := Result.Beats[BarIdx][BeatIdx].Time - 4.0;
    end;
  end;
end;

function TPatternFixer.Fix(APattern: TPattern): TPattern;
begin
  // Apply all fixes in order
  Result := FixEmptyBars(APattern);
  Result := FixOvercrowdedBars(Result);
  Result := FixVelocityClipping(Result);
  Result := FixTimingBounds(Result);
end;

function TPatternFixer.GetFixSummary(APattern: TPattern): TArray<String>;
var
  Issues: TStringList;
  BarIdx, BeatIdx: Integer;
begin
  Issues := TStringList.Create;
  try
    for BarIdx := 0 to APattern.BarsCount - 1 do
    begin
      if (BarIdx >= APattern.Beats.Count) then Break;

      // Check for empty bars
      if (APattern.Beats[BarIdx].Count = 0) then
        Issues.Add(Format('Bar %d: Empty — would add basic framework', [BarIdx]));

      // Check for velocity issues
      for BeatIdx := 0 to APattern.Beats[BarIdx].Count - 1 do
      begin
        if (APattern.Beats[BarIdx][BeatIdx].Velocity <= 1) then
          Issues.Add(Format('Bar %d, Beat: Velocity %d is too low',
            [BarIdx, APattern.Beats[BarIdx][BeatIdx].Velocity]));

        if (APattern.Beats[BarIdx][BeatIdx].Velocity > 127) then
          Issues.Add(Format('Bar %d, Beat: Velocity %d is clipped (max 127)',
            [BarIdx, APattern.Beats[BarIdx][BeatIdx].Velocity]));
      end;
    end;

    SetLength(Result, Issues.Count);
    for BarIdx := 0 to Issues.Count - 1 do
      Result[BarIdx] := Issues[BarIdx];
  finally
    Issues.Free;
  end;
end;

end.
