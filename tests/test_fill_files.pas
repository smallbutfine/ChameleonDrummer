program test_fill_files;

{$mode objfpc}{$H+}

{ config/fills/<drummer>.tab: the shipped files equal the built-in fills of
  all drummers, a user file replaces a drummer's fills, a broken file is
  reported and ignored. Run from the project root. }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, Pattern, Song,
  DrumGenerator, PluginRegistry, DrummerPlugin, ConfigFiles, TabFiles, FillLibrary;

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

function Content(F: TFill): string;
var
  B: TBeat;
  Items: TStringList;
begin
  Items := TStringList.Create;
  try
    Items.Sorted := True;
    Items.Duplicates := dupAccept;
    for B in F.Pattern.Beats do
      Items.Add(Format('%.4f/%s/%d/%d', [B.Position, B.Instrument.Name, B.Velocity,
        Ord(B.GhostNote)]));
    Items.Delimiter := ';';
    Items.StrictDelimiter := True;
    Result := Format('%s|%s|e=%.2f|bars=%s', [F.Pattern.Name, Items.DelimitedText,
      F.Energy, F.Pattern.Metadata.Items['phrase_bars']]);
  finally
    Items.Free;
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

function FromFile(const ADrummer: string): specialize TList<TFill>;
begin
  Result := FileFills(ADrummer);
end;

var
  Gen: TDrumGenerator;
  Names: TStringArray;
  D, Warn, Root: string;
  Plugin: TObject;
  Built, Filed, Used: specialize TList<TFill>;
  I, Compared, Drummers: Integer;
begin
  Gen := TDrumGenerator.Create;
  try
    { ---- shipped files equal the built-in fills ---- }
    Names := Gen.PluginManager.Registry.GetAvailableDrummers;
    Drummers := 0;
    Compared := 0;
    for D in Names do
    begin
      Plugin := Gen.PluginManager.Registry.GetDrummerPlugin(D);
      if not (Plugin is TDrummerPlugin) then
        Continue;
      Inc(Drummers);
      Built := (Plugin as TDrummerPlugin).GetSignatureFills;
      Filed := FromFile(D);
      Check(Filed <> nil, 'a fill file exists for ' + D);
      if Filed <> nil then
      begin
        Check(Filed.Count = Built.Count,
          Format('%s: %d fills in the file, %d built in', [D, Filed.Count, Built.Count]));
        for I := 0 to Built.Count - 1 do
          if I < Filed.Count then
          begin
            Check(Content(Filed[I]) = Content(Built[I]),
              D + ': fill ' + IntToStr(I) + ' differs: ' + Content(Filed[I]) + ' <> ' + Content(Built[I]));
            Inc(Compared);
          end;
        { the composer's view: the file }
        Used := (Plugin as TDrummerPlugin).GetFillVocabulary(D);
        Check(Used.Count = Filed.Count, D + ': GetFillVocabulary gives the file fills');
        for I := Used.Count - 1 downto 0 do Used[I].Free;
        Used.Free;
        for I := Filed.Count - 1 downto 0 do Filed[I].Free;
        Filed.Free;
      end;
      for I := Built.Count - 1 downto 0 do Built[I].Free;
      Built.Free;
    end;
    Check(Drummers = 17, Format('17 drummers, got %d', [Drummers]));
    Check(ConfigWarnings.Count = 0, 'the shipped files have no mistakes: ' + ConfigWarnings.Text);

    { ---- a user file replaces the fills ---- }
    Root := IncludeTrailingPathDelimiter(GetTempDir) + 'cd_fill_test' + PathDelim;
    UseDir(Root + 'user');
    WriteText(Root + 'user' + PathDelim + 'fills' + PathDelim + 'weckl.tab',
      '# mine'#10'[my_roll energy=0.8]'#10'S .... .... .... xxxx'#10'T1 .... .... .... ....'#10 +
      '[my_pickup]'#10'K .... .... .... ..x.'#10);
    Plugin := Gen.PluginManager.Registry.GetDrummerPlugin('weckl');
    Used := (Plugin as TDrummerPlugin).GetFillVocabulary('weckl');
    Check(Used.Count = 2, 'the user file gives weckl 2 fills, got ' + IntToStr(Used.Count));
    if Used.Count = 2 then
    begin
      Check(Used[0].Pattern.Name = 'my_roll', 'fill name: ' + Used[0].Pattern.Name);
      Check(Abs(Used[0].Energy - 0.8) < 1e-9, 'fill energy 0.8');
      Check(Used[1].Energy < 0, 'a fill without energy suits every bar');
      Check(Used[0].Pattern.Beats.Count = 4, 'the empty T1 line adds nothing: ' + IntToStr(Used[0].Pattern.Beats.Count));
    end;
    for I := Used.Count - 1 downto 0 do Used[I].Free;
    Used.Free;
    { another drummer keeps the file next to the program }
    Used := (Gen.PluginManager.Registry.GetDrummerPlugin('bonham') as TDrummerPlugin).GetFillVocabulary('bonham');
    Check(Used.Count = 3, 'bonham is not affected');
    for I := Used.Count - 1 downto 0 do Used[I].Free;
    Used.Free;

    { ---- mistakes: file ignored, built-in fills used, reported ---- }
    UseDir(Root + 'bad1');
    WriteText(Root + 'bad1' + PathDelim + 'fills' + PathDelim + 'weckl.tab',
      '[a_fill energy=1.5]'#10'S .... .... .... xxxx'#10);
    Used := (Plugin as TDrummerPlugin).GetFillVocabulary('weckl');
    Warn := ConfigWarnings.Text;
    Check((Pos('weckl.tab (1)', Warn) > 0) and (Pos('energy', Warn) > 0), 'energy out of range reported: ' + Warn);
    Check(Used.Count = 3, 'and the built-in fills are used');
    for I := Used.Count - 1 downto 0 do Used[I].Free;
    Used.Free;

    UseDir(Root + 'bad2');
    WriteText(Root + 'bad2' + PathDelim + 'fills' + PathDelim + 'weckl.tab',
      '[a_fill]'#10'XX .... .... .... xxxx'#10);
    Used := FileFills('weckl');
    Check(Used = nil, 'an unknown instrument gives no fills');
    Check(Pos('XX', ConfigWarnings.Text) > 0, 'and names it: ' + ConfigWarnings.Text);

    UseDir(Root + 'bad3');
    WriteText(Root + 'bad3' + PathDelim + 'fills' + PathDelim + 'weckl.tab',
      '[one two]'#10'S .... .... .... xxxx'#10);
    Used := FileFills('weckl');
    Check((Used = nil) and (Pos('one name', ConfigWarnings.Text) > 0), 'two names in a header reported: ' + ConfigWarnings.Text);

    UseDir(Root + 'bad4');
    WriteText(Root + 'bad4' + PathDelim + 'fills' + PathDelim + 'weckl.tab',
      '[a_fill]'#10'S .... .... xxxx'#10'K .. . ..'#10);
    Used := FileFills('weckl');
    Check((Used = nil) and (Pos('weckl.tab (1)', ConfigWarnings.Text) > 0) and (Pos('steps', ConfigWarnings.Text) > 0),
      'a wrong grid size reported: ' + ConfigWarnings.Text);

    UseDir(Root + 'none');
    Check(FileFills('weckl') <> nil, 'without a user file the installed one is found');
    Check(FileFills('') = nil, 'no drummer, no fills');
    Check(FileFills('nobody') = nil, 'no file, no fills');
  finally
    ConfigRootOverride := '';
    Gen.Free;
  end;

  if Failures = 0 then
    WriteLn('PASS: fill files (', Compared, ' fills of ', Drummers, ' drummers equal the built-in fills)')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
