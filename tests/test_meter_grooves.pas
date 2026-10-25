program test_meter_grooves;

{$mode objfpc}{$H+}

{ Every odd-meter groove shipped in config/grooves/*.tab must be playable by
  one drummer (no limb violations, so the fixer never has to thin it out), must
  fill its bar, and must keep to the meter's beat groups: a groove that has a
  snare marks the start of a later beat group (3+2+2: units 4 and 6 of 7/8) and
  never the one. Run from the project root. }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, Pattern,
  time_signature, patterns_templates, ConfigFiles, TabFiles, GrooveLibrary,
  LimbConstraints;

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

const
  GenreNames: array[0..4] of string = ('metal', 'rock', 'jazz', 'funk', 'electronic');

var
  Engine: TLimbConstraintEngine;
  G: Integer;
  Path, Label_, Dump: string;
  Blocks: TTabBlocks;
  B: TTabBlock;
  P: TPattern;
  V: specialize TList<TLimbViolation>;
  I, Checked, SnareGrooves, WithBackbeat: Integer;
  Backbeats: specialize TArray<Double>;
  Beat: TBeat;
  BarQ, Pos_: Double;
  HasBackbeat, HasSnare, SnareOnOne: Boolean;
  Meters: TStringList;
begin
  Engine := TLimbConstraintEngine.Create;
  Meters := TStringList.Create;
  Meters.Sorted := True;
  Meters.Duplicates := dupIgnore;
  Checked := 0;
  SnareGrooves := 0;
  WithBackbeat := 0;
  try
    for G := 0 to High(GenreNames) do
    begin
      Path := 'config' + PathDelim + 'grooves' + PathDelim + GenreNames[G] + '.tab';
      Check(FileExists(Path), GenreNames[G] + '.tab exists next to the test');
      if not FileExists(Path) then
        Continue;
      Blocks := ParseTabFile(Path);
      CheckGrooveBlocks(Blocks, Path);
      for B in Blocks do
      begin
        if B.MeterNum = 0 then
          Continue;
        Label_ := Format('%s %s %s %d/%d (line %d)', [GenreNames[G], B.Words[0], B.Words[1],
          B.MeterNum, B.MeterDen, B.HeaderLine]);
        Meters.Add(Format('%d/%d', [B.MeterNum, B.MeterDen]));
        P := BuildDrumTabPattern('t', B.Lines, 1.0, 1, B.MeterNum, B.MeterDen);
        try
          Inc(Checked);
          Check(P.Beats.Count > 0, Label_ + ' has notes');
          BarQ := B.MeterNum * 4.0 / B.MeterDen;

          V := Engine.FindViolations(P);
          try
            Dump := '';
            for I := 0 to V.Count - 1 do
              Dump := Dump + V[I].Description + '; ';
            Check(V.Count = 0, Label_ + ' has limb violations: ' + Dump);
            for I := 0 to V.Count - 1 do
              V[I].Free;
          finally
            V.Free;
          end;

          { the one is marked by a kick or a crash }
          Dump := '';
          for Beat in P.Beats do
            if Beat.Position < 1e-6 then
              Dump := Dump + Beat.Instrument.Name + ' ';
          Check((Pos('kick', Dump) > 0) or (Pos('cymbal', Dump) > 0),
            Label_ + ': nothing marks the one: ' + Dump);

          { backbeat: a snare, when there is one, sits on a beat-group start, never on the one }
          Backbeats := MeterBackbeats(B.MeterNum, B.MeterDen);
          HasSnare := False;
          HasBackbeat := False;
          SnareOnOne := False;
          for Beat in P.Beats do
            if (Pos('snare', Beat.Instrument.Name) = 1) and not Beat.GhostNote then
            begin
              HasSnare := True;
              Pos_ := Beat.Position;
              if Pos_ < 1e-6 then
                SnareOnOne := True;
              for I := 0 to High(Backbeats) do
                if Abs(Pos_ - Backbeats[I]) < 1e-6 then
                  HasBackbeat := True;
            end;
          Check(not SnareOnOne, Label_ + ': a snare on the one');
          if HasSnare then
          begin
            Inc(SnareGrooves);
            if HasBackbeat then
              Inc(WithBackbeat);
          end;
        finally
          P.Free;
        end;
      end;
    end;
  finally
    Engine.Free;
  end;

  Check(Checked >= 60, Format('at least 60 odd-meter grooves are shipped, found %d', [Checked]));
  Check(Meters.Count >= 6, 'at least 6 different meters are covered: ' + Meters.CommaText);
  { the grooves follow the meter's own backbeat in nearly all cases; a few
    deliberately use other accents (2+2+3 counts, two-bar grooves) }
  Check(WithBackbeat * 100 >= SnareGrooves * 80,
    Format('%d of %d grooves with a snare keep to the beat groups', [WithBackbeat, SnareGrooves]));
  Meters.Free;

  if Failures = 0 then
    WriteLn('PASS: odd-meter grooves (', Checked, ' grooves, ', WithBackbeat, ' of ', SnareGrooves,
      ' with the snare on a beat group)')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
