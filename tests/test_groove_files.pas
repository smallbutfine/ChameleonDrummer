program test_groove_files;

{$mode objfpc}{$H+}

{ config/grooves/<genre>.tab: the files play exactly what the compiled-in
  grooves played, a user file can replace and extend them, and a broken file is
  reported and ignored. Run from the project root (needs config\ and
  mappings\). }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, Pattern,
  patterns_templates, MetalGrooves, RockGrooves, JazzGrooves, FunkGrooves,
  ElectronicGrooves, ConfigFiles, TabFiles, GrooveLibrary;

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

{ Order-independent text form of a pattern: positions, instruments, velocities,
  the intensity tags and its length. }
function Content(P: TPattern): string;
var
  B: TBeat;
  Items: TStringList;
  S, Lo, Hi: string;
begin
  Items := TStringList.Create;
  try
    Items.Sorted := True;
    Items.Duplicates := dupAccept;
    for B in P.Beats do
      Items.Add(Format('%.4f/%s/%d/%d', [B.Position, B.Instrument.Name, B.Velocity,
        Ord(B.GhostNote)]));
    Items.Delimiter := ';';
    Items.StrictDelimiter := True;
    S := Items.DelimitedText;
  finally
    Items.Free;
  end;
  if not P.Metadata.TryGetValue('valid_intensity_min', Lo) then Lo := '-';
  if not P.Metadata.TryGetValue('valid_intensity_max', Hi) then Hi := '-';
  Result := Format('%s|%s-%s|bars=%s', [S, Lo, Hi, P.Metadata.Items['phrase_bars']]);
end;

type
  TLinesFn = function(const AStyle, AKind: string; AVariant: Integer): TTabLines;

procedure CompareGenre(const AGenre: string; const AStyles: array of string;
  AFn: TLinesFn; var Compared: Integer);
const
  Kinds: array[0..2] of string = ('verse', 'chorus', 'bridge');
  Complexities: array[0..2] of Double = (0.2, 0.5, 1.0);
var
  Style, Kind: string;
  V, C: Integer;
  FromFile, BuiltIn: TPattern;
begin
  for Style in AStyles do
    for Kind in Kinds do
      for V := 0 to 2 do
        for C := 0 to 2 do
        begin
          FromFile := BuildGroove(AGenre, Style, Kind, V, Complexities[C], AFn(Style, Kind, V));
          BuiltIn := BuildTaggedGroove('x', Kind, V, AFn(Style, Kind, V), Complexities[C]);
          Check(Content(FromFile) = Content(BuiltIn),
            Format('%s %s %s variant %d complexity %.1f: the file differs from the built-in groove',
              [AGenre, Style, Kind, V, Complexities[C]]));
          Inc(Compared);
          FromFile.Free;
          BuiltIn.Free;
        end;
end;

var
  TempRoot: string;

procedure UseConfigDir(const ADir: string);
begin
  { The override folder is searched first, so a folder with a groove file wins. }
  ConfigRootOverride := ADir;
  ConfigWarnings.Clear;
  ReloadGrooveLibrary;
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

function Joined(L: TStrings): string;
begin
  Result := L.Text;
end;

const
  GenreNames: array[0..4] of string = ('metal', 'rock', 'jazz', 'funk', 'electronic');

var
  Compared: Integer;
  Names, Styles: TStringList;
  Variants: TGrooveVariants;
  P: TPattern;
  Dir, Warn: string;
  I: Integer;
begin
  { ---- the files equal the built-in grooves ---- }
  Names := TStringList.Create;
  Styles := TStringList.Create;
  try
    GrooveFileGenres(Names);
    for I := 0 to High(GenreNames) do
      Check(Names.IndexOf(GenreNames[I]) >= 0,
        'a groove file was found for ' + GenreNames[I] + ' (' + Names.CommaText + ')');
    Check(ConfigWarnings.Count = 0, 'the shipped files have no mistakes: ' + Joined(ConfigWarnings));

    Compared := 0;
    CompareGenre('metal', ['heavy', 'death', 'power', 'progressive', 'thrash', 'doom', 'breakdown'],
      @MetalGrooveLines, Compared);
    CompareGenre('rock', ['classic', 'blues', 'alternative', 'progressive', 'punk', 'hard', 'pop'],
      @RockGrooveLines, Compared);
    CompareGenre('jazz', ['swing', 'bebop', 'fusion', 'latin', 'ballad', 'hard_bop', 'contemporary'],
      @JazzGrooveLines, Compared);
    CompareGenre('funk', ['classic', 'pfunk', 'shuffle', 'new_orleans', 'fusion', 'minimal', 'heavy'],
      @FunkGrooveLines, Compared);
    CompareGenre('electronic', ['house', 'techno', 'drum_and_bass', 'dubstep'],
      @ElectronicGrooveLines, Compared);

    GrooveFileStyles('metal', Styles);
    Check(Styles.Count = 7, 'metal.tab has 7 styles, got ' + IntToStr(Styles.Count));
    Check(GrooveVariantCount('metal', 'doom', 'chorus') = 3, 'doom chorus has 3 variants');

    { ---- a user file ---- }
    TempRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'cd_groove_test' + PathDelim;

    { 1. adds a fourth variant with its own band, and a new style }
    Dir := TempRoot + 'user1';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'metal.tab',
      '# my grooves'#10 +
      '[heavy verse intensity=0.10-0.30]'#10'K x... .... x... ....'#10'S .... x... .... x...'#10 +
      '[heavy verse intensity=0.50-0.90]'#10'K x.x. x.x. x.x. x.x.'#10'S .... x... .... x...'#10'H x.x. x.x. x.x. x.x.'#10 +
      '[heavy verse intensity=0.70-1.00]'#10'K x.xx x.xx x.xx x.xx'#10'S .... x... .... x...'#10 +
      '[heavy verse intensity=0.95-1.00]'#10'K xxxx xxxx xxxx xxxx'#10'S .x.x .x.x .x.x .x.x'#10 +
      '[sludge verse]'#10'K x... .... x... ....'#10'S .... x... .... x...'#10 +
      '[sludge verse]'#10'K x... ..x. x... ....'#10'S .... x... .... x...'#10);
    UseConfigDir(Dir);
    Check(ConfigWarnings.Count = 0, 'a good user file has no warnings: ' + Joined(ConfigWarnings));
    Check(GrooveVariantCount('metal', 'heavy', 'verse') = 4, 'the user file gives heavy verse 4 variants');
    Check(GrooveVariantCount('metal', 'death', 'verse') = 3,
      'a style the user file does not mention keeps the built-in grooves');
    Variants := FileGrooveVariants('metal', 'heavy', 'verse');
    Check((Length(Variants) = 4) and Variants[3].HasBand and (Abs(Variants[3].BandMin - 0.95) < 1e-9),
      'the intensity band of the fourth variant is read');
    P := BuildGroove('metal', 'heavy', 'verse', 3, 1.0, MetalGrooveLines('heavy', 'verse', 0));
    Check(P.Metadata.Items['valid_intensity_min'] = '0.95', 'and written to the pattern: ' + P.Metadata.Items['valid_intensity_min']);
    Check(P.Beats.Count > 0, 'the user groove has notes');
    P.Free;
    P := BuildGroove('metal', 'heavy', 'verse', 4, 1.0, MetalGrooveLines('heavy', 'verse', 0));
    Check(Pos('v0', P.Name) > 0, 'variant 4 wraps around to the first: ' + P.Name);
    P.Free;
    { the first variant of the file wins over the built-in one }
    P := BuildGroove('metal', 'heavy', 'verse', 0, 1.0, MetalGrooveLines('heavy', 'verse', 0));
    Check(P.Metadata.Items['valid_intensity_max'] = '0.30', 'the user file replaces the built-in heavy verse');
    P.Free;
    { a style only the file knows }
    Check(WithFileStyles('metal', ['heavy', 'death'])[2] = 'sludge', 'a new style appears after the built-in ones');
    Check(Length(WithFileStyles('metal', ['heavy', 'death'])) = 3, 'and is listed once');
    { a kind the style lacks plays its verse grooves }
    Check(GrooveVariantCount('metal', 'sludge', 'chorus') = 2, 'sludge has no chorus: its 2 verse grooves are used');

    { 2. mistakes: file ignored as a whole, reported with file and line }
    Dir := TempRoot + 'bad_instrument';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'metal.tab',
      '[heavy verse]'#10'K x... .... x... ....'#10'ZZ x... .... .... ....'#10);
    UseConfigDir(Dir);
    Warn := Joined(ConfigWarnings);
    Check((Pos('metal.tab', Warn) > 0) and (Pos('(1)', Warn) > 0) and (Pos('ZZ', Warn) > 0),
      'unknown instrument: file, line and instrument named: ' + Warn);
    Check(GrooveVariantCount('metal', 'heavy', 'verse') = 3, 'the broken file is ignored, built-ins play');

    Dir := TempRoot + 'bad_steps';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'rock.tab',
      '[classic verse]'#10'K x.. ... x...'#10);
    UseConfigDir(Dir);
    Warn := Joined(ConfigWarnings);
    Check((Pos('rock.tab', Warn) > 0) and (Pos('steps', Warn) > 0), 'bad grid size reported: ' + Warn);

    Dir := TempRoot + 'bad_char';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'jazz.tab',
      '[swing verse]'#10'K x... q... x... ....'#10);
    UseConfigDir(Dir);
    Check(Pos('jazz.tab', Joined(ConfigWarnings)) > 0, 'unknown step character reported: ' + Joined(ConfigWarnings));

    Dir := TempRoot + 'bad_header';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'funk.tab',
      '# fine'#10#10'[classic]'#10'K x... .... x... ....'#10);
    UseConfigDir(Dir);
    Warn := Joined(ConfigWarnings);
    Check((Pos('funk.tab (3)', Warn) > 0) and (Pos('style and a kind', Warn) > 0),
      'header without kind: line 3 named: ' + Warn);

    Dir := TempRoot + 'bad_kind';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'funk.tab',
      '[classic outro]'#10'K x... .... x... ....'#10);
    UseConfigDir(Dir);
    Check(Pos('verse, chorus or bridge', Joined(ConfigWarnings)) > 0, 'unknown kind reported: ' + Joined(ConfigWarnings));

    Dir := TempRoot + 'bad_band';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'funk.tab',
      '[classic verse intensity=0.9-0.2]'#10'K x... .... x... ....'#10);
    UseConfigDir(Dir);
    Check(Pos('intensity must look like', Joined(ConfigWarnings)) > 0, 'reversed band reported: ' + Joined(ConfigWarnings));

    Dir := TempRoot + 'bad_empty';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'funk.tab', '[classic verse]'#10);
    UseConfigDir(Dir);
    Check(Pos('no drum-tab lines', Joined(ConfigWarnings)) > 0, 'a block without lines reported: ' + Joined(ConfigWarnings));

    Dir := TempRoot + 'bad_orphan';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'funk.tab', 'K x... .... x... ....'#10);
    UseConfigDir(Dir);
    Check(Pos('before the first [header]', Joined(ConfigWarnings)) > 0, 'a line before any header reported: ' + Joined(ConfigWarnings));

    Dir := TempRoot + 'bad_unclosed';
    WriteText(Dir + PathDelim + 'grooves' + PathDelim + 'funk.tab', '[classic verse'#10'K x... .... x... ....'#10);
    UseConfigDir(Dir);
    Check(Pos('must end with ]', Joined(ConfigWarnings)) > 0, 'an unclosed header reported: ' + Joined(ConfigWarnings));

    { an empty folder changes nothing: the installed files are found }
    UseConfigDir(TempRoot + 'nothing_here');
    Check(GrooveVariantCount('metal', 'heavy', 'verse') = 3, 'without a user file the installed one is used');
    Check(ConfigWarnings.Count = 0, 'and nothing is reported');
  finally
    ConfigRootOverride := '';
    Names.Free;
    Styles.Free;
  end;

  if Failures = 0 then
    WriteLn('PASS: groove files (', Compared, ' groove builds equal the built-in grooves)')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
