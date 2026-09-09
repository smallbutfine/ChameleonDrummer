unit SnareAccentReaction;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math,
  Pattern;

// ============================================================================
// TSnaeAccentReaction — reacts snare velocity to kick accents
// ============================================================================
type
  TSnaeAccentReaction = class
  private
    FReactionAmount: Double;
  public
    constructor Create(A_REACTION_AMOUNT: Double);
    function Apply(APattern: TPattern; Intensity: Double): TPattern;
  end;

implementation

constructor TSnaeAccentReaction.Create(A_REACTION_AMOUNT: Double);
begin
  FReactionAmount := A_REACTION_AMOUNT;
end;

function TSnaeAccentReaction.Apply(APattern: TPattern; Intensity: Double): TPattern;
var
  BarIdx, BeatIdx, InnerIdx: Integer;
  HasKickAccent: Boolean;
  SnareVel: Integer;
begin
  Result := APattern.Copy;
  if (Intensity <= 0) then Exit;

  for BarIdx := 0 to Result.BarsCount - 1 do
  begin
    if (BarIdx >= Result.Beats.Count) then Break;
    
    // Check if this bar has a kick accent
    HasKickAccent := False;
    for InnerIdx := 0 to Result.Beats[BarIdx].Count - 1 do
    begin
      if (Result.Beats[BarIdx][InnerIdx].Instrument = 'kick_hit') and
         (Result.Beats[BarIdx][InnerIdx].Velocity > 100) then
      begin
        HasKickAccent := True;
        Break;
      end;
    end;

    // React snare velocity to kick accent
    if HasKickAccent then
    begin
      for BeatIdx := 0 to Result.Beats[BarIdx].Count - 1 do
      begin
        if (Result.Beats[BarIdx][BeatIdx].Instrument = 'snare_1_hit') then
        begin
          SnareVel := Round(Result.Beats[BarIdx][BeatIdx].Velocity * (1.0 + FReactionAmount * Intensity));
          Result.Beats[BarIdx][BeatIdx].Velocity := Min(127, SnareVel);
        end;
      end;
    end;
  end;
end;

end.
