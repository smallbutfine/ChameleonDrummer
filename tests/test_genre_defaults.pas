program test_genre_defaults;

{$mode objfpc}{$H+}

{ config/defaults/<genre>.ini and config/sections/<genre>.json: the shipped
  files equal the built-in defaults, user files replace them, mistakes are
  reported and fall back. Run from the project root. }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, Pattern, Song,
  ComposerV2, DrumGenerator, PluginRegistry, ConfigFiles, GenreDefaults, Math;

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

procedure UseDir(const ADir: string);
begin
  ConfigRootOverride := ADir;
  ConfigWarnings.Clear;
end;

function Join(const A: TStringArray): string;
var
  S: string;
begin
  Result := '';
  for S in A do
    Result := Result + S + ',';
end;

const
  Genres: array[0..4] of string = ('metal', 'rock', 'jazz', 'funk', 'electronic');
  Preferred: array[0..4] of string = (
    'bonham,roeder,dee,hoglan,peart,carey,watts,haake,doomblues,',
    'bonham,porcaro,weckl,chambers,dee,rich,copeland,smith,moon,watts,doomblues,',
    'weckl,chambers,rich,halpern,',
    'porcaro,chambers,copeland,smith,moon,',
    '');

var
  Gen: TDrumGenerator;
  G, I, J, Compared: Integer;
  Styles: TStringArray;
  Style, Root, Warn: string;
  FromFile: specialize TArray<TSectionDef>;
  Archetype: TSongStructureArray;
  Drummers: specialize TArray<string>;
begin
  Compared := 0;
  Gen := TDrumGenerator.Create;
  try
    { ---- shipped files equal the built-in defaults ---- }
    for G := 0 to High(Genres) do
    begin
      Styles := Gen.PluginManager.Registry.GetStylesForGenre(Genres[G]);
      for Style in Styles do
      begin
        Check(FileDefaultBpm(Genres[G], Style) = BuiltInBpm(Genres[G], Style),
          Format('%s %s: file tempo %d, built-in %d',
            [Genres[G], Style, FileDefaultBpm(Genres[G], Style), BuiltInBpm(Genres[G], Style)]));
        Inc(Compared);
      end;
      Check(FileDefaultBpm(Genres[G], 'a_new_style') = BuiltInBpm(Genres[G], ''),
        Genres[G] + ': an unknown style gets the file default');

      Drummers := FilePreferredDrummers(Genres[G]);
      if Preferred[G] = '' then
        Check(Length(Drummers) = 0, Genres[G] + ': no preferred drummers')
      else
        Check(Join(Drummers) = Preferred[G], Genres[G] + ' preferred drummers: ' + Join(Drummers));
      Check(Join(Gen.PluginManager.Registry.GetPreferredDrummersForGenre(Genres[G])) = Preferred[G],
        Genres[G] + ' registered with the preferred drummers: ' +
        Join(Gen.PluginManager.Registry.GetPreferredDrummersForGenre(Genres[G])));

      FromFile := FileDefaultStructure(Genres[G]);
      Archetype := nil;
      for I := Low(GENRE_ARCHETYPES) to High(GENRE_ARCHETYPES) do
        if GENRE_ARCHETYPES[I].Genre = Genres[G] then
          Archetype := GENRE_ARCHETYPES[I].Structure;
      Check(Length(FromFile) = Length(Archetype),
        Format('%s: %d sections in the file, %d built in', [Genres[G], Length(FromFile), Length(Archetype)]));
      for J := 0 to Min(High(FromFile), High(Archetype)) do
        Check((FromFile[J].Name = Archetype[J].Name) and (FromFile[J].Bars = Archetype[J].Bars),
          Format('%s section %d differs', [Genres[G], J]));
      Check(Length(Gen.DefaultStructure(Genres[G])) = Length(Archetype), Genres[G] + ': the generator uses it');
    end;
    Check(ConfigWarnings.Count = 0, 'the shipped files have no mistakes: ' + ConfigWarnings.Text);

    { ---- user files ---- }
    Root := IncludeTrailingPathDelimiter(GetTempDir) + 'cd_defaults_test' + PathDelim;
    UseDir(Root + 'user');
    WriteText(Root + 'user' + PathDelim + 'defaults' + PathDelim + 'metal.ini',
      '[bpm]'#10'default=111'#10'doom=65'#10'[drummers]'#10'preferred= Weckl , nobody, bonham'#10);
    WriteText(Root + 'user' + PathDelim + 'sections' + PathDelim + 'metal.json',
      '{"sections":[{"name":"verse","bars":2},{"name":"chorus","bars":2}]}');
    Check(FileDefaultBpm('metal', 'doom') = 65, 'user tempo for doom');
    Check(FileDefaultBpm('metal', 'heavy') = 111, 'the user default for a style not listed');
    Check(GetDefaultBpm('metal', 'doom') = 65, 'GetDefaultBpm uses the user file');
    Check(GetDefaultBpm('rock', 'classic') = 120, 'another genre is not affected');
    Drummers := FilePreferredDrummers('metal');
    Check(Join(Drummers) = 'weckl,nobody,bonham,', 'user drummers (lower case, trimmed): ' + Join(Drummers));
    Check(Length(Gen.DefaultStructure('metal')) = 2, 'the user structure is used');
    Check(Gen.DefaultStructure('metal')[1].Name = 'chorus', 'in order');

    { A generator built now registers the user drummers and drops the unknown one. }
    Gen.Free;
    ConfigWarnings.Clear;
    Gen := TDrumGenerator.Create;
    Check(Join(Gen.PluginManager.Registry.GetPreferredDrummersForGenre('metal')) = 'weckl,bonham,',
      'registered: ' + Join(Gen.PluginManager.Registry.GetPreferredDrummersForGenre('metal')));
    Warn := ConfigWarnings.Text;
    Check((Pos('metal.ini', Warn) > 0) and (Pos('nobody', Warn) > 0), 'the unknown drummer is reported: ' + Warn);

    { ---- mistakes ---- }
    UseDir(Root + 'bad');
    WriteText(Root + 'bad' + PathDelim + 'defaults' + PathDelim + 'rock.ini',
      '[bpm]'#10'classic=fast'#10'punk=900'#10);
    Check(FileDefaultBpm('rock', 'classic') = 0, 'a tempo that is not a number gives 0 (built-in is used)');
    Check(FileDefaultBpm('rock', 'punk') = 0, 'a tempo of 900 gives 0');
    Check(GetDefaultBpm('rock', 'punk') = 180, 'and the built-in tempo plays');
    Warn := ConfigWarnings.Text;
    Check((Pos('rock.ini', Warn) > 0) and (Pos('fast', Warn) > 0) and (Pos('900', Warn) > 0),
      'both are reported: ' + Warn);

    UseDir(Root + 'bad2');
    WriteText(Root + 'bad2' + PathDelim + 'sections' + PathDelim + 'jazz.json',
      '{"sections":[{"name":"verse"}]}');
    Check(Length(FileDefaultStructure('jazz')) = 0, 'a section without bars gives no structure');
    Check((Pos('jazz.json', ConfigWarnings.Text) > 0) and (Pos('"bars"', ConfigWarnings.Text) > 0),
      'and names the file and key: ' + ConfigWarnings.Text);
    Check(Length(Gen.DefaultStructure('jazz')) = 6, 'the built-in jazz structure plays');

    UseDir(Root + 'bad3');
    WriteText(Root + 'bad3' + PathDelim + 'sections' + PathDelim + 'funk.json', '{"sections": [');
    Check(Length(FileDefaultStructure('funk')) = 0, 'broken JSON gives no structure');
    Check(Pos('funk.json', ConfigWarnings.Text) > 0, 'and is reported: ' + ConfigWarnings.Text);

    UseDir(Root + 'nothing');
    Check(FileDefaultBpm('metal', 'doom') = 70, 'without a user file the installed one is used');
  finally
    ConfigRootOverride := '';
    Gen.Free;
  end;

  if Failures = 0 then
    WriteLn('PASS: genre defaults (', Compared, ' tempos, 5 structures and 5 drummer lists equal the built-in ones)')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
