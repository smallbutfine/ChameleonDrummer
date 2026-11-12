program test_triplet_meter;

{$mode objfpc}{$H+}

{ Unit tests for triplet feel meter support:
  - TryParseMeterWithTriplet() parses '7/8T', '4/4T', '5/4T' etc.
  - GetStepsPerBar() returns x3/2 steps for triplet feel
  - MeterName() outputs '7/8T' when triplet feel is true
  - Backward compatibility: TryParseMeter() still works (triplet = False)
  Run from the project root. }

uses
  SysUtils, time_signature;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AText: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AText);
    Inc(Failures);
  end
  else
    WriteLn('PASS: ', AText);
end;

var
  Num, Den: Integer;
  Triplet: Boolean;
  TS: TTimeSignature;
  Steps: Integer;
begin
  WriteLn('=== TryParseMeterWithTriplet() ===');

  { Straight meters still parse (triplet = False) }
  Check(TryParseMeterWithTriplet('4/4', Num, Den, Triplet),
    'TryParseMeterWithTriplet("4/4") returns True');
  Check(Num = 4, 'TryParseMeterWithTriplet("4/4"): Num = 4');
  Check(Den = 4, 'TryParseMeterWithTriplet("4/4"): Den = 4');
  Check(not Triplet, 'TryParseMeterWithTriplet("4/4"): Triplet = False');

  Check(TryParseMeterWithTriplet('7/8', Num, Den, Triplet),
    'TryParseMeterWithTriplet("7/8") returns True');
  Check(Num = 7, 'TryParseMeterWithTriplet("7/8"): Num = 7');
  Check(Den = 8, 'TryParseMeterWithTriplet("7/8"): Den = 8');
  Check(not Triplet, 'TryParseMeterWithTriplet("7/8"): Triplet = False');

  { Triplet meters parse with T suffix }
  Check(TryParseMeterWithTriplet('4/4T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("4/4T") returns True');
  Check(Num = 4, 'TryParseMeterWithTriplet("4/4T"): Num = 4');
  Check(Den = 4, 'TryParseMeterWithTriplet("4/4T"): Den = 4');
  Check(Triplet, 'TryParseMeterWithTriplet("4/4T"): Triplet = True');

  Check(TryParseMeterWithTriplet('7/8T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("7/8T") returns True');
  Check(Num = 7, 'TryParseMeterWithTriplet("7/8T"): Num = 7');
  Check(Den = 8, 'TryParseMeterWithTriplet("7/8T"): Den = 8');
  Check(Triplet, 'TryParseMeterWithTriplet("7/8T"): Triplet = True');

  Check(TryParseMeterWithTriplet('5/4T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("5/4T") returns True');
  Check(Num = 5, 'TryParseMeterWithTriplet("5/4T"): Num = 5');
  Check(Den = 4, 'TryParseMeterWithTriplet("5/4T"): Den = 4');
  Check(Triplet, 'TryParseMeterWithTriplet("5/4T"): Triplet = True');

  Check(TryParseMeterWithTriplet('3/4T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("3/4T") returns True');
  Check(Num = 3, 'TryParseMeterWithTriplet("3/4T"): Num = 3');
  Check(Den = 4, 'TryParseMeterWithTriplet("3/4T"): Den = 4');
  Check(Triplet, 'TryParseMeterWithTriplet("3/4T"): Triplet = True');

  Check(TryParseMeterWithTriplet('6/8T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("6/8T") returns True');
  Check(Num = 6, 'TryParseMeterWithTriplet("6/8T"): Num = 6');
  Check(Den = 8, 'TryParseMeterWithTriplet("6/8T"): Den = 8');
  Check(Triplet, 'TryParseMeterWithTriplet("6/8T"): Triplet = True');

  Check(TryParseMeterWithTriplet('9/8T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("9/8T") returns True');
  Check(Num = 9, 'TryParseMeterWithTriplet("9/8T"): Num = 9');
  Check(Den = 8, 'TryParseMeterWithTriplet("9/8T"): Den = 8');
  Check(Triplet, 'TryParseMeterWithTriplet("9/8T"): Triplet = True');

  Check(TryParseMeterWithTriplet('11/8T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("11/8T") returns True');
  Check(Num = 11, 'TryParseMeterWithTriplet("11/8T"): Num = 11');
  Check(Den = 8, 'TryParseMeterWithTriplet("11/8T"): Den = 8');
  Check(Triplet, 'TryParseMeterWithTriplet("11/8T"): Triplet = True');

  Check(TryParseMeterWithTriplet('13/8T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("13/8T") returns True');
  Check(Num = 13, 'TryParseMeterWithTriplet("13/8T"): Num = 13');
  Check(Den = 8, 'TryParseMeterWithTriplet("13/8T"): Den = 8');
  Check(Triplet, 'TryParseMeterWithTriplet("13/8T"): Triplet = True');

  Check(TryParseMeterWithTriplet('15/16T', Num, Den, Triplet),
    'TryParseMeterWithTriplet("15/16T") returns True');
  Check(Num = 15, 'TryParseMeterWithTriplet("15/16T"): Num = 15');
  Check(Den = 16, 'TryParseMeterWithTriplet("15/16T"): Den = 16');
  Check(Triplet, 'TryParseMeterWithTriplet("15/16T"): Triplet = True');

  { Invalid input }
  Check(not TryParseMeterWithTriplet('abc', Num, Den, Triplet),
    'TryParseMeterWithTriplet("abc") returns False');
  Check(not TryParseMeterWithTriplet('', Num, Den, Triplet),
    'TryParseMeterWithTriplet("") returns False');
  Check(not TryParseMeterWithTriplet('4/', Num, Den, Triplet),
    'TryParseMeterWithTriplet("4/") returns False');
  Check(not TryParseMeterWithTriplet('/4', Num, Den, Triplet),
    'TryParseMeterWithTriplet("/4") returns False');

  { Backward compatibility: TryParseMeter() still works }
  Check(TryParseMeter('7/8T', Num, Den),
    'TryParseMeter("7/8T") returns True (backward compatible)');
  Check(Num = 7, 'TryParseMeter("7/8T"): Num = 7');
  Check(Den = 8, 'TryParseMeter("7/8T"): Den = 8');

  WriteLn('');
  WriteLn('=== GetStepsPerBar() ===');

  { Straight 4/4 at resolution 16 = 16 steps }
  TS := TTimeSignature.Create(4, 4);
  try
    Steps := TS.GetStepsPerBar(16);
    Check(Steps = 16, '4/4 straight at resolution 16 = 16 steps (got ' + IntToStr(Steps) + ')');
  finally
    TS.Free;
  end;

  { Triplet 4/4T at resolution 16 = 24 steps (16 * 3/2) }
  TS := TTimeSignature.Create(4, 4, True);
  try
    Steps := TS.GetStepsPerBar(16);
    Check(Steps = 24, '4/4T at resolution 16 = 24 steps (got ' + IntToStr(Steps) + ')');
  finally
    TS.Free;
  end;

  { Straight 7/8 at resolution 16 = 14 steps }
  TS := TTimeSignature.Create(7, 8);
  try
    Steps := TS.GetStepsPerBar(16);
    Check(Steps = 14, '7/8 straight at resolution 16 = 14 steps (got ' + IntToStr(Steps) + ')');
  finally
    TS.Free;
  end;

  { Triplet 7/8T at resolution 16 = 21 steps (14 * 3/2) }
  TS := TTimeSignature.Create(7, 8, True);
  try
    Steps := TS.GetStepsPerBar(16);
    Check(Steps = 21, '7/8T at resolution 16 = 21 steps (got ' + IntToStr(Steps) + ')');
  finally
    TS.Free;
  end;

  { Straight 5/4 at resolution 16 = 20 steps }
  TS := TTimeSignature.Create(5, 4);
  try
    Steps := TS.GetStepsPerBar(16);
    Check(Steps = 20, '5/4 straight at resolution 16 = 20 steps (got ' + IntToStr(Steps) + ')');
  finally
    TS.Free;
  end;

  { Triplet 5/4T at resolution 16 = 30 steps (20 * 3/2) }
  TS := TTimeSignature.Create(5, 4, True);
  try
    Steps := TS.GetStepsPerBar(16);
    Check(Steps = 30, '5/4T at resolution 16 = 30 steps (got ' + IntToStr(Steps) + ')');
  finally
    TS.Free;
  end;

  { StepsPerBar property accessor }
  TS := TTimeSignature.Create(4, 4, True);
  try
    Steps := TS.StepsPerBar[16];
    Check(Steps = 24, 'TS.StepsPerBar[16] for 4/4T = 24 (got ' + IntToStr(Steps) + ')');
  finally
    TS.Free;
  end;

  WriteLn('');
  WriteLn('=== MeterName() ===');

  Check(MeterName(4, 4) = '4/4', 'MeterName(4, 4) = "4/4" (got "' + MeterName(4, 4) + '")');
  Check(MeterName(7, 8) = '7/8', 'MeterName(7, 8) = "7/8" (got "' + MeterName(7, 8) + '")');
  Check(MeterName(4, 4, True) = '4/4T', 'MeterName(4, 4, True) = "4/4T" (got "' + MeterName(4, 4, True) + '")');
  Check(MeterName(7, 8, True) = '7/8T', 'MeterName(7, 8, True) = "7/8T" (got "' + MeterName(7, 8, True) + '")');
  Check(MeterName(5, 4, True) = '5/4T', 'MeterName(5, 4, True) = "5/4T" (got "' + MeterName(5, 4, True) + '")');

  WriteLn('');
  if Failures = 0 then
  begin
    WriteLn('ALL TESTS PASSED');
    Halt(0);
  end
  else
  begin
    WriteLn(Failures, ' test(s) failed');
    Halt(1);
  end;
end.
