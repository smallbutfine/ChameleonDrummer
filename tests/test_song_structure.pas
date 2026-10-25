program test_song_structure;

{$mode objfpc}{$H+}

{ Checks the --section parser, the structure file loader, and that a custom
  structure, per-section tempo and per-section complexity reach the generated
  song. Run from the project root (needs the mappings folder). }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, Pattern, Song, ComposerV2, DrumGenerator,
  SongStructure;

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
  TempDir: string;

function WriteFile(const AName, AText: string; ABom: Boolean = False): string;
var
  F: TFileStream;
  Bom: string;
begin
  Result := TempDir + AName;
  F := TFileStream.Create(Result, fmCreate);
  try
    if ABom then
    begin
      Bom := #$EF#$BB#$BF;
      F.WriteBuffer(Bom[1], 3);
    end;
    if AText <> '' then
      F.WriteBuffer(AText[1], Length(AText));
  finally
    F.Free;
  end;
end;

{ The loader's error message when it rejects the file, or '' if it accepts. }
function LoadError(const AText: string): string;
var
  Path: string;
begin
  Result := '';
  Path := WriteFile('bad.json', AText);
  try
    LoadStructureFile(Path);
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

function HasWarning(const AInfo: TStructureInfo; const AFragment: string): Boolean;
var
  W: string;
begin
  Result := False;
  for W in AInfo.Warnings do
    if Pos(AFragment, W) > 0 then
      Result := True;
end;

{ Every note of every section: position, instrument, velocity. Two songs
  with the same fingerprint have the same notes. }
function Fingerprint(ASong: TSong): string;
var
  Sec: TSection;
  B: TBeat;
begin
  Result := '';
  for Sec in ASong.Sections do
  begin
    Result := Result + '|' + Sec.Name + ':';
    for B in Sec.Pattern.Beats do
      Result := Result + Format('%.3f/%s/%d;', [B.Position, B.Instrument.Name, B.Velocity]);
  end;
end;

function MakeSong(Gen: TDrumGenerator;
  const AStructure: specialize TArray<TSectionDef>): TSong;
begin
  RandSeed := 12345;
  Result := Gen.CreateSong('rock', 'classic', 120, AStructure,
    TDrumKit.FromKeymapName('gm'), '', 0.5, 0.6, 0.0);
end;

var
  D: TSectionDef;
  Gen: TDrumGenerator;
  Structure: array of TSectionDef;
  S: TSong;
  Text, Msg, Path: string;
  Info: TStructureInfo;
  FpLow, FpHigh, FpPlain, FpSame: string;
  Low, High, Plain, Same: array of TSectionDef;
begin
  TempDir := GetTempDir + 'cd_structure_test' + PathDelim;
  ForceDirectories(TempDir);
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

  { ---- structure file ---- }

  Path := WriteFile('ok.json',
    '{"genre": "Rock", "style": "classic", "tempo": 118,' +
    ' "time_signature": [4, 4], "sections": [' +
    '{"name": "Intro", "bars": 4},' +
    '{"name": "verse", "bars": 8, "tempo": 110, "complexity": 0.4},' +
    '{"name": "chorus", "bars": 8, "complexity": 0}]}');
  Info := LoadStructureFile(Path);
  Check((Info.Genre = 'rock') and (Info.Style = 'classic') and (Info.Tempo = 118),
    'genre, style and tempo of the file');
  Check(Length(Info.Sections) = 3, 'three sections in the file');
  Check((Info.Sections[0].Name = 'intro') and (Info.Sections[0].Bars = 4) and
    (Info.Sections[0].Tempo = 0) and not Info.Sections[0].HasComplexity,
    'section 0: lower-cased name, no tempo, no complexity');
  Check((Info.Sections[1].Tempo = 110) and Info.Sections[1].HasComplexity and
    (Abs(Info.Sections[1].Complexity - 0.4) < 1e-9), 'section 1: tempo and complexity');
  Check(Info.Sections[2].HasComplexity and (Info.Sections[2].Complexity = 0.0),
    'complexity 0 is given, not missing');
  Check(Length(Info.Warnings) = 0, 'a clean file has no warnings');

  { The REAPER sidecar format is a subset of the structure format. }
  Path := WriteFile('sidecar.json',
    '{"source": "song.rpp", "tempo": 96, "time_signature": [4, 4],' +
    ' "sections": [{"name": "verse", "bars": 16}, {"name": "chorus", "bars": 8}]}');
  Info := LoadStructureFile(Path);
  Check((Length(Info.Sections) = 2) and (Info.Tempo = 96) and (Info.Genre = '') and
    (Length(Info.Warnings) = 0), 'sidecar format loads without warnings');

  Path := WriteFile('bom.json', '{"sections": [{"name": "verse", "bars": 2}]}', True);
  Info := LoadStructureFile(Path);
  Check(Length(Info.Sections) = 1, 'a UTF-8 byte order mark is accepted');

  Path := WriteFile('warn.json',
    '{"colour": 1, "pattern_template": "x", "sections": [' +
    '{"name": "verse", "bars": 2, "fill_policy": "none", "mood": "sad"}]}');
  Info := LoadStructureFile(Path);
  Check(Length(Info.Sections) = 1, 'a file with unknown keys still loads');
  Check(HasWarning(Info, 'unknown key "colour"'), 'warning for an unknown top-level key');
  Check(HasWarning(Info, '"pattern_template" is not supported'), 'warning for pattern_template');
  Check(HasWarning(Info, 'section 1 ("verse"): "fill_policy" is not supported'),
    'warning for fill_policy names the section');
  Check(HasWarning(Info, 'section 1 ("verse"): unknown key "mood"'),
    'warning for an unknown section key names the section');

  { Errors name the file, the section and the key. }
  Msg := '';
  try
    LoadStructureFile(TempDir + 'does_not_exist.json');
  except
    on E: Exception do Msg := E.Message;
  end;
  Check(Pos('does_not_exist.json', Msg) > 0, 'missing file is named: ' + Msg);

  Msg := LoadError('{"sections": [');
  Check((Pos('bad.json', Msg) > 0) and (Pos('not valid JSON', Msg) > 0),
    'broken JSON: ' + Msg);
  Msg := LoadError('');
  Check(Msg <> '', 'an empty file is rejected');
  Msg := LoadError('[1, 2]');
  Check((Pos('bad.json', Msg) > 0) and (Pos('top level', Msg) > 0), 'top level list: ' + Msg);
  Msg := LoadError('{"genre": "rock"}');
  Check(Pos('"sections"', Msg) > 0, 'no sections list: ' + Msg);
  Msg := LoadError('{"sections": []}');
  Check(Pos('empty', Msg) > 0, 'empty sections list: ' + Msg);
  Msg := LoadError('{"sections": ["verse"]}');
  Check(Pos('section 1', Msg) > 0, 'section is not an object: ' + Msg);
  Msg := LoadError('{"sections": [{"bars": 4}]}');
  Check((Pos('section 1', Msg) > 0) and (Pos('"name"', Msg) > 0), 'no name: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "intro", "bars": 2}, {"name": "verse"}]}');
  Check((Pos('section 2 ("verse")', Msg) > 0) and (Pos('"bars"', Msg) > 0),
    'no bars: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 0}]}');
  Check((Pos('section 1 ("verse")', Msg) > 0) and (Pos('"bars"', Msg) > 0),
    'zero bars: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 257}]}');
  Check(Pos('"bars"', Msg) > 0, 'too many bars: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 2.5}]}');
  Check(Pos('whole number', Msg) > 0, 'fractional bars: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": "eight"}]}');
  Check(Pos('must be a number', Msg) > 0, 'bars as text: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 4, "tempo": 30}]}');
  Check((Pos('"tempo"', Msg) > 0) and (Pos('section 1', Msg) > 0), 'tempo too low: ' + Msg);
  Msg := LoadError('{"tempo": 400, "sections": [{"name": "verse", "bars": 4}]}');
  Check(Pos('"tempo"', Msg) > 0, 'file tempo too high: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 4, "complexity": 1.5}]}');
  Check(Pos('"complexity"', Msg) > 0, 'complexity above 1: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 4, "complexity": -0.1}]}');
  Check(Pos('"complexity"', Msg) > 0, 'complexity below 0: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 4, "complexity": "high"}]}');
  Check(Pos('"complexity"', Msg) > 0, 'complexity as text: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "   ", "bars": 4}]}');
  Check(Pos('"name"', Msg) > 0, 'blank name: ' + Msg);
  Msg := LoadError('{"time_signature": [7, 8], "sections": [{"name": "verse", "bars": 4}]}');
  Check((Pos('7/8', Msg) > 0) and (Pos('4/4', Msg) > 0), 'file meter 7/8: ' + Msg);
  Msg := LoadError('{"sections": [{"name": "verse", "bars": 4, "time_signature": [3, 4]}]}');
  Check((Pos('3/4', Msg) > 0) and (Pos('section 1', Msg) > 0), 'section meter 3/4: ' + Msg);
  Msg := LoadError('{"time_signature": 4, "sections": [{"name": "verse", "bars": 4}]}');
  Check(Pos('time_signature', Msg) > 0, 'meter not a list: ' + Msg);

  { ---- per-section complexity reaches the notes ---- }

  SetLength(Low, 2);
  SetLength(High, 2);
  SetLength(Plain, 2);
  SetLength(Same, 2);
  Low[0] := ParseSectionSpec('verse:4');
  Low[0].HasComplexity := True;
  Low[0].Complexity := 0.0;
  Low[1] := ParseSectionSpec('chorus:4');
  High[0] := Low[0];
  High[0].Complexity := 1.0;
  High[1] := Low[1];
  { Chorus without an override, and with the song's own 0.5 spelled out: both
    must come out identical, which only holds when the verse's override was
    put back after the verse. }
  Plain[0] := High[0];
  Plain[1] := Low[1];
  Same[0] := High[0];
  Same[1] := Low[1];
  Same[1].HasComplexity := True;
  Same[1].Complexity := 0.5;

  Gen := TDrumGenerator.Create;
  try
    S := MakeSong(Gen, Low);   try FpLow := Fingerprint(S);   finally S.Free; end;
    S := MakeSong(Gen, High);  try FpHigh := Fingerprint(S);  finally S.Free; end;
    S := MakeSong(Gen, Plain); try FpPlain := Fingerprint(S); finally S.Free; end;
    S := MakeSong(Gen, Same);  try FpSame := Fingerprint(S);  finally S.Free; end;
    S := MakeSong(Gen, High);
    try
      Check(Fingerprint(S) = FpHigh, 'the same seed gives the same song');
    finally
      S.Free;
    end;
  finally
    Gen.Free;
  end;
  Check(FpLow <> FpHigh, 'verse complexity 0 and 1 give different notes');
  Check(FpPlain = FpSame,
    'the verse override is restored: chorus without override equals chorus at the song complexity');

  Text := '';
  if Failures = 0 then
    WriteLn('PASS: --section parsing, structure file, custom structure, per-section tempo and complexity')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
