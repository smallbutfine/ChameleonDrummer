program test_reaper_tempo;

{$mode objfpc}{$H+}

{ The REAPER project must carry the tempo changes of a song as a tempo
  envelope whose points sit exactly at the section boundaries (in seconds),
  and must keep the plain TEMPO line for a song at one tempo. }

uses
  SysUtils, Classes, jsonparser, Kit, ReaperAPI;

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

function Lines(const APath: string): TStringList;
begin
  Result := TStringList.Create;
  Result.LoadFromFile(APath);
end;

function CountStarting(AList: TStringList; const APrefix: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to AList.Count - 1 do
    if Pos(APrefix, Trim(AList[I])) = 1 then
      Inc(Result);
end;

function Section(const AName: string; ABars, ABPM: Integer): TReaperSection;
begin
  Result.Name := AName;
  Result.Bars := ABars;
  Result.BPM := ABPM;
  Result.Num := 4;
  Result.Denom := 4;
end;

var
  Bridge: TReaperBridge;
  Sects: specialize TArray<TReaperSection>;
  L: TStringList;
  Path: string;
begin
  Path := '_test_reaper_tempo.mid';
  Bridge := TReaperBridge.Create;
  try
    { 2 bars at 120 = 4 s, 4 bars at 110 = 8.727273 s, 4 bars at 150 }
    SetLength(Sects, 3);
    Sects[0] := Section('intro', 2, 120);
    Sects[1] := Section('verse', 4, 110);
    Sects[2] := Section('chorus', 4, 150);
    Check(Bridge.CreateFromSections('t', Path, Sects), 'project is written');
    L := Lines('_test_reaper_tempo.rpp');
    try
      Check(CountStarting(L, 'TEMPO 120 4 4') = 1, 'the base tempo line is the first tempo');
      Check(CountStarting(L, '<TEMPOENVEX') = 1, 'one tempo envelope');
      Check(CountStarting(L, 'PT ') = 3, 'one envelope point per tempo change, got ' +
        IntToStr(CountStarting(L, 'PT ')));
      Check(L.IndexOf('    PT 0.000000 120 1 0 0 0') >= 0, 'point at 0 s, 120 BPM');
      Check(L.IndexOf('    PT 4.000000 110 1 0 0 0') >= 0, 'point at the verse start, 110 BPM');
      Check(L.IndexOf('    PT 12.727273 150 1 0 0 0') >= 0, 'point at the chorus start, 150 BPM');
      Check(L.IndexOf('  <TEMPOENVEX') >= 0, 'the envelope is a child of the project');
    finally
      L.Free;
    end;

    { One tempo: no envelope, the plain TEMPO line stays. }
    SetLength(Sects, 2);
    Sects[0] := Section('intro', 2, 120);
    Sects[1] := Section('verse', 4, 120);
    Check(Bridge.CreateFromSections('t', Path, Sects), 'constant-tempo project is written');
    L := Lines('_test_reaper_tempo.rpp');
    try
      Check(CountStarting(L, '<TEMPOENVEX') = 0, 'no envelope for a constant tempo');
      Check(CountStarting(L, 'TEMPO 120 4 4') = 1, 'plain TEMPO line');
    finally
      L.Free;
    end;

    { A meter change is a point that sets the time signature:
      65536 * denominator + numerator, flag bit 1. }
    SetLength(Sects, 2);
    Sects[0] := Section('a', 2, 120);
    Sects[1] := Section('b', 2, 120);
    Sects[1].Num := 7;
    Sects[1].Denom := 8;
    Check(Bridge.CreateFromSections('t', Path, Sects), 'meter-change project is written');
    L := Lines('_test_reaper_tempo.rpp');
    try
      Check(CountStarting(L, '<TEMPOENVEX') = 1, 'a meter change also needs the envelope');
      Check(L.IndexOf('    PT 4.000000 120 1 ' + IntToStr(65536 * 8 + 7) + ' 0 1') >= 0,
        'meter point packs 65536 * denominator + numerator with the set-meter flag');
    finally
      L.Free;
    end;
  finally
    Bridge.Free;
    if FileExists('_test_reaper_tempo.rpp') then DeleteFile('_test_reaper_tempo.rpp');
    if FileExists(Path) then DeleteFile(Path);
  end;

  if Failures = 0 then
    WriteLn('PASS: REAPER tempo envelope')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
