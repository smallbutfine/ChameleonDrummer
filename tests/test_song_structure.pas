program test_song_structure;

{$mode objfpc}{$H+}

{ Checks the --section parser and that a custom structure and per-section
  tempo reach the generated song. Run from the project root (needs the
  mappings folder). }

uses
  SysUtils, jsonparser, Kit, Song, ComposerV2, DrumGenerator, SongStructure;

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

function Rejects(const ASpec: string): Boolean;
begin
  Result := False;
  try
    ParseSectionSpec(ASpec);
  except
    on E: Exception do
      Result := Pos(ASpec, E.Message) > 0;   { the message names the bad input }
  end;
end;

var
  D: TSectionDef;
  Gen: TDrumGenerator;
  Structure: array of TSectionDef;
  S: TSong;
  Text: string;
begin
  D := ParseSectionSpec('verse:8');
  Check((D.Name = 'verse') and (D.Bars = 8) and (D.Tempo = 0), 'verse:8');
  D := ParseSectionSpec('Chorus:16@140');
  Check((D.Name = 'chorus') and (D.Bars = 16) and (D.Tempo = 140), 'Chorus:16@140 is lower-cased');
  D := ParseSectionSpec('  pre_chorus:2 ');
  Check((D.Name = 'pre_chorus') and (D.Bars = 2), 'surrounding blanks and underscore');
  D := ParseSectionSpec('solo-2:4@60');
  Check((D.Name = 'solo-2') and (D.Tempo = 60), 'hyphen and digit in a name, lowest tempo');
  D := ParseSectionSpec('x:256@300');
  Check((D.Bars = 256) and (D.Tempo = 300), 'upper limits are accepted');

  Check(Rejects('verse'), 'missing :bars');
  Check(Rejects('verse:'), 'empty bars');
  Check(Rejects(':8'), 'empty name');
  Check(Rejects('verse:abc'), 'bars not a number');
  Check(Rejects('verse:0'), 'zero bars');
  Check(Rejects('verse:257'), 'too many bars');
  Check(Rejects('verse:-4'), 'negative bars');
  Check(Rejects('verse:8@59'), 'tempo below 60');
  Check(Rejects('verse:8@301'), 'tempo above 300');
  Check(Rejects('verse:8@'), 'empty tempo');
  Check(Rejects('verse:8@fast'), 'tempo not a number');
  Check(Rejects('1verse:8'), 'name starting with a digit');
  Check(Rejects('ve rse:8'), 'blank inside the name');

  SetLength(Structure, 3);
  Structure[0] := ParseSectionSpec('intro:2');
  Structure[1] := ParseSectionSpec('verse:4@100');
  Structure[2] := ParseSectionSpec('chorus:4@150');
  Check(DescribeStructure(Structure) = 'intro:2 verse:4@100 chorus:4@150',
    'DescribeStructure round-trips the syntax, got: ' + DescribeStructure(Structure));

  Gen := TDrumGenerator.Create;
  try
    S := Gen.CreateSong('rock', 'classic', 120, Structure, TDrumKit.FromKeymapName('gm'),
      '', 0.5, 0.6, 0.0);
    try
      Check(S.Sections.Count = 3, 'one section per --section');
      Check((S.Sections[0].Name = 'intro') and (S.Sections[0].Bars = 2), 'section 0');
      Check((S.Sections[1].Name = 'verse') and (S.Sections[1].Bars = 4), 'section 1');
      Check((S.Sections[2].Name = 'chorus') and (S.Sections[2].Bars = 4), 'section 2');
      Check(S.Sections[0].EffectiveTempo(0, S.Tempo) = 120, 'intro inherits the song tempo');
      Check(S.Sections[1].EffectiveTempo(0, S.Tempo) = 100, 'verse runs at 100');
      Check(S.Sections[1].EffectiveTempo(3, S.Tempo) = 100, 'verse runs at 100 in its last bar');
      Check(S.Sections[2].EffectiveTempo(0, S.Tempo) = 150, 'chorus runs at 150');
      Check(S.TotalBars = 10, Format('10 bars in total, got %d', [S.TotalBars]));
    finally
      S.Free;
    end;

    { No structure: the genre default is still used. }
    S := Gen.CreateSong('rock', 'classic', 120, nil, TDrumKit.FromKeymapName('gm'),
      '', 0.5, 0.6, 0.0);
    try
      Check(S.Sections.Count >= 4, 'the genre default structure is still used');
    finally
      S.Free;
    end;
  finally
    Gen.Free;
  end;

  Text := '';
  if Failures = 0 then
    WriteLn('PASS: --section parsing, custom structure and per-section tempo')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
