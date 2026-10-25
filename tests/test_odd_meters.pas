program test_odd_meters;

{$mode objfpc}{$H+}

{ Odd meters (2/4, 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 ...): the meter helpers, the
  drum-tab grid, the groove and fill files with a meter in the header, the
  fallbacks when a meter has none, and the generated song - its bars, its MIDI
  time signature events and its tempo map. Run from the project root. }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, Pattern, Song,
  time_signature, patterns_templates, ComposerV2, DrumGenerator, DrummerPlugin,
  ConfigFiles, TabFiles, GrooveLibrary, FillLibrary, SongStructure;

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
  Result := Abs(A - B) < 1e-6;
end;

function GroupsText(ANum, ADen: Integer): string;
var
  G: Integer;
begin
  Result := '';
  for G in MeterGrouping(ANum, ADen) do
  begin
    if Result <> '' then Result := Result + '+';
    Result := Result + IntToStr(G);
  end;
end;

function Dot(X: Double): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.##', X, FS);
end;

function PositionsText(const A: specialize TArray<Double>): string;
var
  X: Double;
begin
  Result := '';
  for X in A do
    Result := Result + Dot(X) + ' ';
  Result := Trim(Result);
end;

procedure WriteText(const APath, AText: string);
var
  L: TStringList;
begin
  ForceDirectories(ExtractFilePath(APath));
  L := TStringList.Create;
  try
    L.Text := AText;
    L.SaveToFile(APath);
  finally
    L.Free;
  end;
end;

function Read16(const D: string; P: Integer): Integer;
begin
  Result := (Ord(D[P]) shl 8) or Ord(D[P + 1]);
end;

{ The time-signature meta events of a MIDI file: tick, numerator, denominator. }
type
  TSigEvent = record Tick, Num, Den: Int64; end;

function ReadFileText(const APath: string): string;
var
  F: TFileStream;
begin
  F := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then F.ReadBuffer(Result[1], F.Size);
  finally
    F.Free;
  end;
end;

function ReadSignatures(const APath: string): specialize TList<TSigEvent>;
var
  D: string;
  P, TrackEnd, Len: Integer;
  Tick: Int64;
  Status, B, Kind: Integer;
  Ev: TSigEvent;

  function VLQ: Int64;
  var
    C: Integer;
  begin
    Result := 0;
    repeat
      C := Ord(D[P]);
      Inc(P);
      Result := (Result shl 7) or (C and $7F);
    until (C and $80) = 0;
  end;

begin
  Result := specialize TList<TSigEvent>.Create;
  D := ReadFileText(APath);
  P := 15;
  TrackEnd := P + 8 + (Ord(D[P + 4]) shl 24) + (Ord(D[P + 5]) shl 16) + (Ord(D[P + 6]) shl 8) + Ord(D[P + 7]);
  Inc(P, 8);
  Tick := 0;
  Status := 0;
  while P < TrackEnd do
  begin
    Inc(Tick, VLQ);
    B := Ord(D[P]);
    if B = $FF then
    begin
      Kind := Ord(D[P + 1]);
      Len := Ord(D[P + 2]);
      if Kind = $58 then
      begin
        Ev.Tick := Tick;
        Ev.Num := Ord(D[P + 3]);
        Ev.Den := 1 shl Ord(D[P + 4]);
        Result.Add(Ev);
      end;
      Inc(P, 3 + Len);
      Continue;
    end;
    if (B and $80) <> 0 then
    begin
      Status := B;
      Inc(P);
    end;
    case Status and $F0 of
      $C0, $D0: Inc(P);
    else
      Inc(P, 2);
    end;
  end;
end;

{ Last note-on tick of the file. }
function LastNoteTick(const APath: string): Int64;
var
  D: string;
  P, TrackEnd, Len: Integer;
  Tick: Int64;
  Status, B: Integer;

  function VLQ: Int64;
  var
    C: Integer;
  begin
    Result := 0;
    repeat
      C := Ord(D[P]);
      Inc(P);
      Result := (Result shl 7) or (C and $7F);
    until (C and $80) = 0;
  end;

begin
  Result := 0;
  D := ReadFileText(APath);
  P := 15;
  TrackEnd := P + 8 + (Ord(D[P + 4]) shl 24) + (Ord(D[P + 5]) shl 16) + (Ord(D[P + 6]) shl 8) + Ord(D[P + 7]);
  Inc(P, 8);
  Tick := 0;
  Status := 0;
  while P < TrackEnd do
  begin
    Inc(Tick, VLQ);
    B := Ord(D[P]);
    if B = $FF then
    begin
      Len := Ord(D[P + 2]);
      Inc(P, 3 + Len);
      Continue;
    end;
    if (B and $80) <> 0 then
    begin
      Status := B;
      Inc(P);
    end;
    if ((Status and $F0) = $90) and (Ord(D[P + 1]) > 0) then
      Result := Tick;
    case Status and $F0 of
      $C0, $D0: Inc(P);
    else
      Inc(P, 2);
    end;
  end;
end;

procedure CheckGrid(APattern: TPattern; ANum, ADen: Integer; const AWhat: string);
var
  B: TBeat;
  BarQ: Double;
  Late: Integer;
begin
  BarQ := ANum * 4.0 / ADen;
  Late := 0;
  for B in APattern.Beats do
    if B.Position >= APattern.DurationBars * BarQ - 1e-9 then
      Inc(Late);
  Check(Late = 0, AWhat + ': no beat past the end of the pattern');
  Check((APattern.TimeSignature.Numerator = ANum) and (APattern.TimeSignature.Denominator = ADen),
    AWhat + ': the pattern carries the meter');
end;

const
  Meters: array[0..6, 0..1] of Integer =
    ((2, 4), (3, 4), (5, 4), (7, 8), (9, 8), (11, 8), (13, 8));

var
  Gen: TDrumGenerator;
  S: TSong;
  Sig: specialize TList<TSigEvent>;
  N, D, I, J, Bars: Integer;
  K: Int64;
  P: TPattern;
  Root, Path, Msg, Joined: string;
  Structure: specialize TArray<TSectionDef>;
  Used: specialize TList<TFill>;
  Plugin: TObject;
  Warn: string;
  Sec: TSection;
  Notes, Off: Integer;
  Beat: TBeat;
  Grid: Double;
  Spec: TSongBarSpec;
  Specs: specialize TList<TSongBarSpec>;
begin
  { ---- meter helpers ---- }
  Check(TryParseMeter('7/8', N, D) and (N = 7) and (D = 8), 'parse 7/8');
  Check(TryParseMeter(' 13 / 8 ', N, D) and (N = 13) and (D = 8), 'parse with blanks');
  Check(not TryParseMeter('7', N, D), 'no slash');
  Check(not TryParseMeter('/8', N, D), 'no numerator');
  Check(not TryParseMeter('a/8', N, D), 'letters');
  Check(not TryParseMeter('7/-8', N, D), 'negative');
  Check(not TryParseMeter('7/8/9', N, D), 'two slashes');
  Check(MeterProblem(7, 8) = '', '7/8 is playable');
  Check(MeterProblem(2, 4) = '', '2/4 is playable');
  Check(MeterProblem(32, 16) = '', '32/16 is playable');
  Check(MeterProblem(1, 4) <> '', '1/4 is not');
  Check(MeterProblem(33, 8) <> '', '33/8 is not');
  Check(MeterProblem(7, 3) <> '', 'a denominator of 3 is not');
  Check(MeterProblem(7, 32) <> '', 'a denominator of 32 is not');

  Check(GroupsText(2, 4) = '1+1', '2/4 counts 1+1: ' + GroupsText(2, 4));
  Check(GroupsText(3, 4) = '1+1+1', '3/4: ' + GroupsText(3, 4));
  Check(GroupsText(4, 4) = '1+1+1+1', '4/4: ' + GroupsText(4, 4));
  Check(GroupsText(5, 4) = '3+2', '5/4: ' + GroupsText(5, 4));
  Check(GroupsText(7, 8) = '3+2+2', '7/8: ' + GroupsText(7, 8));
  Check(GroupsText(9, 8) = '3+3+3', '9/8: ' + GroupsText(9, 8));
  Check(GroupsText(11, 8) = '3+3+3+2', '11/8: ' + GroupsText(11, 8));
  Check(GroupsText(13, 8) = '3+3+3+2+2', '13/8: ' + GroupsText(13, 8));
  Check(GroupsText(10, 8) = '3+3+2+2', '10/8: ' + GroupsText(10, 8));
  Check(GroupsText(6, 8) = '3+3', '6/8: ' + GroupsText(6, 8));
  for I := 0 to High(Meters) do
  begin
    K := 0;
    for J in MeterGrouping(Meters[I, 0], Meters[I, 1]) do
      Inc(K);
    Bars := 0;
    for J in MeterGrouping(Meters[I, 0], Meters[I, 1]) do
      Inc(Bars, J);
    Check((Bars = Meters[I, 0]) or (Meters[I, 1] = 4), Format('the groups of %d/%d add up', [Meters[I, 0], Meters[I, 1]]));
  end;

  Check(PositionsText(MeterBackbeats(4, 4)) = '1 3', '4/4 backbeats: ' + PositionsText(MeterBackbeats(4, 4)));
  Check(PositionsText(MeterBackbeats(3, 4)) = '1 2', '3/4 backbeats: ' + PositionsText(MeterBackbeats(3, 4)));
  Check(PositionsText(MeterBackbeats(7, 8)) = '1.5 2.5', '7/8 backbeats (3+2+2): ' + PositionsText(MeterBackbeats(7, 8)));
  Check(PositionsText(MeterBackbeats(5, 4)) = '3', '5/4 backbeat (3+2): ' + PositionsText(MeterBackbeats(5, 4)));

  { ---- the drum-tab grid in a meter ---- }
  P := BuildDrumTabPattern('t', ['K x. .. x.'], 1.0, 1, 3, 4);
  Check(P.Beats.Count = 2, '3/4: two kicks');
  Check(Near(P.Beats[0].Position, 0.0) and Near(P.Beats[1].Position, 2.0), '3/4: kicks on 0 and 2 quarters');
  CheckGrid(P, 3, 4, '3/4 tab');
  P.Free;

  P := BuildDrumTabPattern('t', ['K xxxxxxx', 'S ...x.x.'], 1.0, 1, 7, 8);
  Check(P.Beats.Count = 9, '7/8: 7 kicks and 2 snares');
  Check(Near(P.Beats[1].Position, 0.5), '7/8: eighths are half a quarter apart');
  Check(Near(P.DurationBars, 1.0), '7/8: one bar');
  CheckGrid(P, 7, 8, '7/8 tab');
  P.Free;

  P := BuildDrumTabPattern('t', ['K x......x......', 'S ..x....x.x.x..'], 1.0, 1, 7, 8);
  Check(P.Beats.Count = 6, '7/8: sixteenth grid (14 steps): ' + IntToStr(P.Beats.Count));
  Check(Near(P.Beats[0].Position, 0.0) and Near(P.Beats[1].Position, 1.75),
    '7/8, 14 steps: the second kick is at step 7 = 1.75 quarters (a bar is 3.5)');
  P.Free;

  { a grid that does not divide the bar is refused, with the valid counts named }

  Msg := '';

  try

    P := BuildDrumTabPattern('t', ['K x... .... x... ....'], 1.0, 1, 5, 4);
    P.Free;
  except
    on E: Exception do Msg := E.Message;
  end;
  Check((Pos('5/4', Msg) > 0) and (Pos('5, 10, 15, 20, 30 or 40', Msg) > 0),
    '16 steps in 5/4 is refused and the valid counts are named: ' + Msg);
  Msg := '';
  try
    P := BuildDrumTabPattern('t', ['K x.x.x.x.x.x.x.x.x'], 1.0, 1, 7, 8);
    P.Free;
  except
    on E: Exception do Msg := E.Message;
  end;
  Check(Pos('7, 14, 21, 28, 42 or 56', Msg) > 0, '19 steps in 7/8 is refused: ' + Msg);
  Msg := '';
  try
    P := BuildDrumTabPattern('t', ['K x... .... x... ....'], 1.0, 1, 4, 4);
    P.Free;
  except
    on E: Exception do Msg := E.Message;
  end;
  Check(Msg = '', '4/4 still takes 16 steps: ' + Msg);

  { ---- the plain fallbacks ---- }
  for I := 0 to High(Meters) do
  begin
    N := Meters[I, 0];
    D := Meters[I, 1];
    Joined := Format('%d/%d', [N, D]);
    P := BuildMeterFallbackGroove('plain', N, D, 0.5);
    CheckGrid(P, N, D, 'plain groove ' + Joined);
    Check(P.Beats.Count >= N, 'plain groove ' + Joined + ' has a hi-hat on every unit');
    Check(Near(P.DurationBars, 1.0), 'plain groove ' + Joined + ' is one bar');
    P.Free;
    P := BuildMeterFallbackFill('f', N, D, True);
    CheckGrid(P, N, D, 'plain fill ' + Joined);
    Check(P.Beats.Count >= 1, 'plain fill ' + Joined + ' has notes');
    P.Free;
    P := BuildMeterFallbackFill('f', N, D, False);
    Check(P.Beats.Count >= 1, 'plain short fill ' + Joined + ' has notes');
    P.Free;
  end;
  P := BuildMeterFallbackGroove('plain', 7, 8, 0.5);
  Joined := '';
  for I := 0 to P.Beats.Count - 1 do
    if Pos('snare', P.Beats[I].Instrument.Name) = 1 then
      Joined := Joined + Dot(P.Beats[I].Position) + ' ';
  Check(Trim(Joined) = '1.5 2.5', '7/8 plain groove: snare where the 2-groups start: ' + Joined);
  P.Free;

  { ---- groove files with a meter ---- }
  Root := IncludeTrailingPathDelimiter(GetTempDir) + 'cd_meter_test' + PathDelim;
  ConfigRootOverride := Root + 'none';
  ConfigWarnings.Clear;
  ReloadGrooveLibrary;
  Check(GrooveVariantCount('rock', 'classic', 'verse', 3, 7, 8) >= 1, 'a 7/8 rock groove exists in the shipped file');
  Check(GrooveVariantCount('rock', 'classic', 'verse', 3, 4, 4) = 3, 'rock classic 4/4 still has its 3 grooves');
  Check(GrooveVariantCount('rock', 'punk', 'verse', 3, 7, 8) >= 1,
    'a style without a 7/8 groove uses another style''s 7/8 groove of the genre');
  Check(GrooveVariantCount('rock', 'classic', 'verse', 3, 15, 16) = 1, 'a meter with no groove anywhere counts 1 (the plain one)');

  ConfigRootOverride := Root + 'g1';
  ConfigWarnings.Clear;
  WriteText(Root + 'g1' + PathDelim + 'grooves' + PathDelim + 'rock.tab',
    '[classic verse 7/8 intensity=0.1-0.9]'#10'K x.. x. x.'#10'S ... x. x.'#10 +
    '[classic verse 7/8 intensity=0.5-1.0]'#10'K xxx xx xx'#10'S ... x. x.'#10 +
    '[classic verse 3/4]'#10'K x. .. x.'#10 +
    '[classic verse intensity=0.3-0.7]'#10'K x... .... x... ....'#10);
  ReloadGrooveLibrary;
  Check(ConfigWarnings.Count = 0, 'a file with meter headers has no warnings: ' + ConfigWarnings.Text);
  Check(GrooveVariantCount('rock', 'classic', 'verse', 3, 7, 8) = 2, 'two 7/8 grooves in the file');
  Check(GrooveVariantCount('rock', 'classic', 'verse', 3, 3, 4) = 1, 'one 3/4 groove');
  Check(GrooveVariantCount('rock', 'classic', 'verse', 3, 4, 4) = 1, 'and one 4/4 groove (the header without a meter)');
  P := BuildGroove('rock', 'classic', 'verse', 1, 1.0, ['K x... .... x... ....'], 7, 8);
  Check(P.TimeSignature.Numerator = 7, 'the 7/8 groove carries 7/8');
  Check(P.Metadata.Items['valid_intensity_min'] = '0.50', 'with its own band: ' + P.Metadata.Items['valid_intensity_min']);
  Check(P.Beats.Count = 2 * (7 + 2), 'its notes (a groove phrase is 2 bars): ' + IntToStr(P.Beats.Count));
  CheckGrid(P, 7, 8, 'file 7/8 groove');
  P.Free;
  ConfigWarnings.Clear;
  P := BuildGroove('rock', 'classic', 'verse', 0, 1.0, ['K x... .... x... ....'], 9, 8);
  Check(P.Metadata.ContainsKey('meter_fallback'), 'no 9/8 groove: the plain one is built');
  Check((Pos('9/8', ConfigWarnings.Text) > 0) and (Pos('rock.tab', ConfigWarnings.Text) > 0) and
    (Pos('[classic verse 9/8]', ConfigWarnings.Text) > 0),
    'and the warning says which block to add where: ' + ConfigWarnings.Text);
  P.Free;

  { mistakes in a meter header: the file is ignored and reported with its line }
  ConfigRootOverride := Root + 'g2';
  ConfigWarnings.Clear;
  WriteText(Root + 'g2' + PathDelim + 'grooves' + PathDelim + 'jazz.tab',
    '[swing verse 7/3]'#10'K x.. x. x.'#10);
  ReloadGrooveLibrary;
  Check((Pos('jazz.tab (1)', ConfigWarnings.Text) > 0) and (Pos('denominator', ConfigWarnings.Text) > 0),
    'meter 7/3 in a header: ' + ConfigWarnings.Text);
  ConfigRootOverride := Root + 'g3';
  ConfigWarnings.Clear;
  WriteText(Root + 'g3' + PathDelim + 'grooves' + PathDelim + 'jazz.tab',
    '[swing verse 7/8]'#10'K x.x.x.x.x.x.x.x.x'#10);
  ReloadGrooveLibrary;
  Check((Pos('jazz.tab (1)', ConfigWarnings.Text) > 0) and (Pos('7/8', ConfigWarnings.Text) > 0) and
    (Pos('steps', ConfigWarnings.Text) > 0), 'wrong step count for 7/8: ' + ConfigWarnings.Text);
  ConfigRootOverride := Root + 'g4';
  ConfigWarnings.Clear;
  WriteText(Root + 'g4' + PathDelim + 'grooves' + PathDelim + 'jazz.tab',
    '[swing verse 7/8 5/4]'#10'K x.. x. x.'#10);
  ReloadGrooveLibrary;
  Check(Pos('two meters', ConfigWarnings.Text) > 0, 'two meters in one header: ' + ConfigWarnings.Text);

  { ---- fill files with a meter ---- }
  ConfigRootOverride := Root + 'f1';
  ConfigWarnings.Clear;
  WriteText(Root + 'f1' + PathDelim + 'fills' + PathDelim + 'weckl.tab',
    '[fill_44 energy=0.5]'#10'S .... .... .... xxxx'#10 +
    '[fill_78 energy=0.5 7/8]'#10'S ...x.xx'#10'T1 ......x'#10 +
    '[fill_78b energy=0.9 7/8]'#10'S ..x..x.'#10'K x.....x'#10 +
    '[fill_34 energy=0.5 3/4]'#10'S ..x.xx'#10);
  Gen := TDrumGenerator.Create;
  try
    Plugin := Gen.PluginManager.Registry.GetDrummerPlugin('weckl');
    Used := (Plugin as TDrummerPlugin).GetFillVocabulary('weckl', 7, 8);
    Check(Used.Count = 2, 'two 7/8 fills in the file: ' + IntToStr(Used.Count));
    if Used.Count = 2 then
    begin
      Check(Used[0].Pattern.Name = 'fill_78', 'the first is fill_78');
      CheckGrid(Used[0].Pattern, 7, 8, 'fill_78');
    end;
    for I := Used.Count - 1 downto 0 do Used[I].Free;
    Used.Free;
    Used := (Plugin as TDrummerPlugin).GetFillVocabulary('weckl', 3, 4);
    Check(Used.Count = 1, 'one 3/4 fill: ' + IntToStr(Used.Count));
    for I := Used.Count - 1 downto 0 do Used[I].Free;
    Used.Free;

    ConfigWarnings.Clear;
    Used := (Plugin as TDrummerPlugin).GetFillVocabulary('weckl', 11, 8);
    Check(Used.Count = 0, 'no 11/8 fill: the vocabulary is empty');
    Check((Pos('11/8', ConfigWarnings.Text) > 0) and (Pos('weckl.tab', ConfigWarnings.Text) > 0),
      'and the warning names the file to add one to: ' + ConfigWarnings.Text);
    Used.Free;

    { without a user file the built-in 4/4 fills are used }
    ConfigRootOverride := Root + 'none';
    ConfigWarnings.Clear;
    Used := (Plugin as TDrummerPlugin).GetFillVocabulary('weckl', 4, 4);
    Check(Used.Count = 3, 'weckl has its 3 fills in 4/4: ' + IntToStr(Used.Count));
    for I := Used.Count - 1 downto 0 do Used[I].Free;
    Used.Free;

    { ---- a generated song in each meter ---- }
    ConfigRootOverride := Root + 'none';
    ConfigWarnings.Clear;
    ReloadGrooveLibrary;
    Notes := 0;
    for I := 0 to High(Meters) do
    begin
      N := Meters[I, 0];
      D := Meters[I, 1];
      Joined := Format('%d/%d', [N, D]);
      Structure := nil;
      SetLength(Structure, 2);
      Structure[0] := ParseSectionSpec('verse:4');
      Structure[1] := ParseSectionSpec('chorus:4');
      S := Gen.CreateSong('rock', 'classic', 120, Structure, TDrumKit.FromKeymapName('gm'),
        'bonham', 0.5, 0.6, 0.0, 0.0, N, D);
      try
        Check((S.TimeSignature.Numerator = N) and (S.TimeSignature.Denominator = D),
          Joined + ': the song has the meter');
        Check(S.TotalBars = 8, Joined + ': 8 bars');
        for Sec in S.Sections do
        begin
          Check(Sec.Bars = 4, Joined + ' ' + Sec.Name + ': 4 bars');
          Check(Near(Sec.Pattern.DurationBars, 4.0),
            Format('%s %s: the section pattern is 4 bars, got %.3f', [Joined, Sec.Name, Sec.Pattern.DurationBars]));
          Check((Sec.Pattern.TimeSignature.Numerator = N) and (Sec.Pattern.TimeSignature.Denominator = D),
            Joined + ' ' + Sec.Name + ': the pattern carries the meter');
          Off := 0;
          for Beat in Sec.Pattern.Beats do
          begin
            Inc(Notes);
            if Beat.Position >= 4 * N * 4.0 / D - 1e-9 then
              Inc(Off);
          end;
          Check(Off = 0, Joined + ' ' + Sec.Name + ': no note beyond the 4 bars');
          Check(Sec.Pattern.Beats.Count > 0, Joined + ' ' + Sec.Name + ' has notes');
        end;
        Check(Gen.LastWarnings.Count = 0, Joined + ': Validate finds nothing: ' + Gen.LastWarnings.Text);

        { MIDI: one time signature event, the last note inside the bars }
        Path := Root + 'song_' + IntToStr(N) + '_' + IntToStr(D) + '.mid';
        ForceDirectories(Root);
        Gen.SaveSongMidi(S, Path);
        Sig := ReadSignatures(Path);
        try
          Check(Sig.Count = 1, Joined + ': one time signature event, got ' + IntToStr(Sig.Count));
          if Sig.Count >= 1 then
            Check((Sig[0].Num = N) and (Sig[0].Den = D) and (Sig[0].Tick = 0),
              Format('%s: the MIDI says %d/%d at tick %d', [Joined, Sig[0].Num, Sig[0].Den, Sig[0].Tick]));
        finally
          Sig.Free;
        end;
        K := LastNoteTick(Path);
        Check(K < 8 * (960 * 4 * N div D), Format('%s: the last note (tick %d) is inside 8 bars (%d)',
          [Joined, K, 8 * (960 * 4 * N div D)]));
        Check(K >= 7 * (960 * 4 * N div D) - 960 * 4, Joined + ': and the song fills its bars');
      finally
        S.Free;
      end;
    end;
    Check(Notes > 0, 'notes were generated');

    { ---- mixed meters in one song: --segment ---- }
    Structure := nil;
    SetLength(Structure, 4);
    Structure[0] := ParseSectionSpec('intro:2');
    Structure[1] := ParseSegmentSpec('verse:4:100:7/8');
    Structure[2] := ParseSegmentSpec('chorus:4:-:5/4');
    Structure[3] := ParseSectionSpec('outro:2');
    S := Gen.CreateSong('rock', 'classic', 120, Structure, TDrumKit.FromKeymapName('gm'),
      'bonham', 0.5, 0.6, 0.0);
    try
      Path := Root + 'mixed.mid';
      Gen.SaveSongMidi(S, Path);
      Sig := ReadSignatures(Path);
      try
        { the header says 4/4; then 7/8, 5/4 and 4/4 again are meta events }
        Check(Sig.Count = 4, 'mixed song: 4/4 header, 7/8, 5/4, 4/4: ' + IntToStr(Sig.Count));
        if Sig.Count >= 4 then
        begin
          { 2 bars of 4/4 = 7680 ticks; 4 bars of 7/8 = 13440; 4 bars of 5/4 = 19200 }
          Check((Sig[1].Num = 7) and (Sig[1].Den = 8) and (Sig[1].Tick = 7680),
            Format('7/8 starts at tick 7680: %d/%d at %d', [Sig[1].Num, Sig[1].Den, Sig[1].Tick]));
          Check((Sig[2].Num = 5) and (Sig[2].Den = 4) and (Sig[2].Tick = 7680 + 13440),
            Format('5/4 starts at tick 21120: %d/%d at %d', [Sig[2].Num, Sig[2].Den, Sig[2].Tick]));
          Check((Sig[3].Num = 4) and (Sig[3].Den = 4) and (Sig[3].Tick = 21120 + 19200),
            Format('4/4 again at tick 40320: %d/%d at %d', [Sig[3].Num, Sig[3].Den, Sig[3].Tick]));
        end;
      finally
        Sig.Free;
      end;
      Check(S.Sections[1].EffectiveTempo(0, S.Tempo) = 100, 'the 7/8 section runs at 100');
      Check(S.Sections[2].EffectiveTempo(0, S.Tempo) = 120, 'the 5/4 section keeps the song tempo');
      Check(S.Sections[1].EffectiveTimeSignature(0, S.TimeSignature).Numerator = 7, 'section 1 is 7/8');
      Check(S.Sections[2].EffectiveTimeSignature(3, S.TimeSignature).Numerator = 5, 'section 2 is 5/4 in its last bar');
      Check(S.Sections[3].EffectiveTimeSignature(0, S.TimeSignature).Numerator = 4, 'the outro is 4/4');
      Specs := S.Sections[1].ResolvedBarSpecs(S.Tempo, S.TimeSignature);
      try
        Check((Specs.Count = 1) and (Specs[0].Bars = 4) and (Specs[0].Tempo = 100) and
          (Specs[0].TimeSignature.Denominator = 8), 'bar specs of the 7/8 section');
      finally
        Specs.Free;
      end;
      { 2 bars of 2 s + 4 bars of 3.5 quarters at 100 + 4 bars of 5 quarters at 120 + 2 bars of 2 s }
      Check(Abs(S.TotalDurationSeconds - (2 * 2.0 + 4 * 3.5 * 0.6 + 4 * 5 * 0.5 + 2 * 2.0)) < 1e-6,
        Format('the song lasts %.4f s', [S.TotalDurationSeconds]));
    finally
      S.Free;
    end;

    { ---- refused meters ---- }
    Msg := '';
    try
      S := Gen.CreateSong('rock', 'classic', 120, nil, TDrumKit.FromKeymapName('gm'), '', 0.5, 0.6, 0.0, 0.0, 7, 3);
      S.Free;
    except
      on E: Exception do Msg := E.Message;
    end;
    Check((Pos('7/3', Msg) > 0) and (Pos('denominator', Msg) > 0), 'a song in 7/3 is refused: ' + Msg);

    { ---- the default structure in an odd meter is still song length ---- }
    S := Gen.CreateSong('rock', 'classic', 120, nil, TDrumKit.FromKeymapName('gm'), 'bonham', 0.5, 0.6, 0.0, 0.0, 7, 8);
    try
      Check((S.TotalDurationSeconds > 120) and (S.TotalDurationSeconds < 300),
        Format('a default 7/8 song lasts a song length, not %.0f s', [S.TotalDurationSeconds]));
    finally
      S.Free;
    end;
  finally
    ConfigRootOverride := '';
    Gen.Free;
  end;

  if Failures = 0 then
    WriteLn('PASS: odd meters (', Notes, ' notes in 7 meters checked)')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
