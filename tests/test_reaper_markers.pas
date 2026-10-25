program test_reaper_markers;

{$mode objfpc}{$H+}

{ The REAPER project must only contain tokens REAPER knows. A first version
  wrote RPR_MARKER, a top-level FILE and a top-level NAME, and REAPER 7.79
  answered with "Project tokens not recognized". Markers are MARKER lines
  (flags bit 1 = region, a region being a pair of lines with the same index),
  and the project must read back through our own reader too. }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, ReaperAPI, ReaperRPP;

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
  Reader: TReaperRPPReader;
  Sects: specialize TArray<TReaperSection>;
  L: TStringList;
  I, Plain, Pairs, Bad: Integer;
  T: string;
begin
  Bridge := TReaperBridge.Create;
  Reader := TReaperRPPReader.Create;
  L := TStringList.Create;
  try
    SetLength(Sects, 2);
    Sects[0] := Section('intro', 2, 120);
    Sects[1] := Section('say "hi"', 4, 100);
    Check(Bridge.CreateFromSections('t', '_test_markers.mid', Sects), 'project is written');
    L.LoadFromFile('_test_markers.rpp');

    Bad := 0;
    Plain := 0;
    Pairs := 0;
    for I := 0 to L.Count - 1 do
    begin
      T := L[I];
      { project level tokens have exactly two blanks of indent }
      if (Pos('  RPR_MARKER', T) = 1) or (Pos('  FILE ', T) = 1) or (Pos('  NAME ', T) = 1) then
        Inc(Bad);
      if Pos('  MARKER ', T) = 1 then
      begin
        if Pos('"" 1', T) > 0 then Inc(Pairs)
        else if Pos(' 0 0 1 B {', T) > 0 then Inc(Plain);
      end;
    end;
    Check(Bad = 0, 'no RPR_MARKER, project-level FILE or NAME token (' + IntToStr(Bad) + ' found)');
    Check(Plain = 2, 'one plain marker per section, got ' + IntToStr(Plain));
    Check(Pairs = 2, 'one region end line per section, got ' + IntToStr(Pairs));


    { read it back }
    Check(Reader.LoadFromFile('_test_markers.rpp'), 'the project reads back');
    Check(Reader.GetMarkers.Count = 4, 'two markers and two regions, got ' +
      IntToStr(Reader.GetMarkers.Count));
    if Reader.GetMarkers.Count = 4 then
    begin
      Check((Reader.GetMarkers[1].IsRegion) and (Reader.GetMarkers[1].Name = 'intro') and
        (Abs(Reader.GetMarkers[1].Position) < 0.0001) and
        (Abs(Reader.GetMarkers[1].EndPosition - 4.0) < 0.0001),
        'region intro spans 0 to 4 s');
      Check((Reader.GetMarkers[3].IsRegion) and
        (Abs(Reader.GetMarkers[3].Position - 4.0) < 0.0001) and
        (Abs(Reader.GetMarkers[3].EndPosition - 13.6) < 0.0001),
        'second region spans 4 to 13.6 s, got ' +
        FloatToStr(Reader.GetMarkers[3].EndPosition));
      Check(Reader.GetMarkers[2].Name = 'say ''hi''',
        'a double quote in a name becomes an apostrophe: ' + Reader.GetMarkers[2].Name);
    end;
  finally
    L.Free;
    Reader.Free;
    Bridge.Free;
    if FileExists('_test_markers.rpp') then DeleteFile('_test_markers.rpp');
    if FileExists('_test_markers.mid') then DeleteFile('_test_markers.mid');
  end;

  if Failures = 0 then
    WriteLn('PASS: REAPER markers use only known tokens and read back')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
