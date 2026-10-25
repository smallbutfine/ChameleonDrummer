program test_swing;

{$mode objfpc}{$H+}

{ Checks TPattern.ApplySwing: the offbeat moves, the downbeat does not, the
  sixteenths follow, and patterns that must not be swung are left alone.
  Run from the project root (needs the mappings folder). }

uses
  SysUtils, Math, jsonparser, Kit, Pattern, time_signature;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AText: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AText);
    Inc(Failures);
  end;
end;

function Near(A, B: Double): Boolean;
begin
  Result := Abs(A - B) < 0.0001;
end;

function SixteenthPattern: TPattern;
var
  I: Integer;
begin
  Result := TPattern.Create('sixteenths');
  for I := 0 to 15 do
    Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('hihat_closed_1_tip_closed_1_hit'), 90);
end;

var
  P: TPattern;
  Applied: Boolean;
  I: Integer;
  Monotonic: Boolean;
begin
  { Classic 2:1 swing: amount 2/3 puts the offbeat on the third triplet. }
  P := SixteenthPattern;
  Applied := P.ApplySwing(2.0 / 3.0);
  Check(Applied, 'swing applies to a straight sixteenth pattern');
  Check(Near(P.Beats[0].Position, 0.0), 'downbeat stays at 0');
  Check(Near(P.Beats[2].Position, 2.0 / 3.0),
    Format('offbeat eighth moves to 2/3 of the beat, got %.4f', [P.Beats[2].Position]));
  Check(Near(P.Beats[4].Position, 1.0), 'next downbeat stays at 1');
  Check(Near(P.Beats[1].Position, 1.0 / 3.0),
    Format('first sixteenth sits between, got %.4f', [P.Beats[1].Position]));
  Check(Near(P.Beats[3].Position, 5.0 / 6.0),
    Format('last sixteenth of the beat follows the offbeat, got %.4f', [P.Beats[3].Position]));
  Monotonic := True;
  for I := 1 to P.Beats.Count - 1 do
    if P.Beats[I].Position <= P.Beats[I - 1].Position then
      Monotonic := False;
  Check(Monotonic, 'swing keeps the order of the notes');
  Check(Near(P.SwingRatio, 2.0 / 3.0), 'SwingRatio records the applied amount');
  Check(not P.ApplySwing(0.5), 'a pattern is never swung twice');
  P.Free;

  { Amount 0 is straight. }
  P := SixteenthPattern;
  Check(not P.ApplySwing(0.0), 'amount 0 changes nothing');
  Check(Near(P.Beats[2].Position, 0.5), 'amount 0 leaves the offbeat at 0.5');
  P.Free;

  { Heavy swing (3:1): the offbeat sits at 3/4 of the beat. }
  P := SixteenthPattern;
  P.ApplySwing(1.0);
  Check(Near(P.Beats[2].Position, 0.75), 'amount 1 puts the offbeat at 0.75');
  P.Free;

  { A pattern already on the triplet grid (shuffle, jazz ride) is left alone. }
  P := TPattern.Create('shuffle');
  P.AddBeat(0.0, TInstrumentRegistry.Get('ride_1_tip_hit_softer'), 90);
  P.AddBeat(2.0 / 3.0, TInstrumentRegistry.Get('ride_1_tip_hit_softer'), 90);
  P.AddBeat(1.0, TInstrumentRegistry.Get('ride_1_tip_hit_softer'), 90);
  Check(not P.ApplySwing(0.7), 'a triplet-grid pattern is not swung again');
  Check(Near(P.Beats[1].Position, 2.0 / 3.0), 'triplet-grid positions are untouched');
  P.Free;

  { Not x/4: no swing. }
  P := SixteenthPattern;
  P.TimeSignature := TTimeSignature.Create(6, 8);
  Check(not P.ApplySwing(0.7), 'compound meter is not swung');
  P.Free;

  { Later bars swing the same way. }
  P := TPattern.Create('two beats of the second bar');
  P.AddBeat(4.0, TInstrumentRegistry.Get('kick'), 100);
  P.AddBeat(4.5, TInstrumentRegistry.Get('kick'), 100);
  P.ApplySwing(2.0 / 3.0);
  Check(Near(P.Beats[0].Position, 4.0) and Near(P.Beats[1].Position, 4.0 + 2.0 / 3.0),
    'swing works relative to each beat, in any bar');
  P.Free;

  if Failures = 0 then
    WriteLn('PASS: swing')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
