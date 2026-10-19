program test_genre_patterns;

{$mode objfpc}{$H+}

uses
  SysUtils, Generics.Collections, jsonparser, Pattern, Kit, Song, generation_parameters,
  GenrePlugin, Metal, Rock, Jazz, Funk, Electronic, DrumGeneratorAPI;

type
  TGenrePluginClass = class of TGenrePlugin;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
  end;
end;

procedure CheckStyleContract(APluginClass: TGenrePluginClass;
  const AGenre, AValidStyle, AInvalidStyle: string;
  const ARegistryStyles: specialize TArray<string>);
var
  Plugin: TGenrePlugin;
  Params: TGenerationParameters;
  Patterns: specialize TList<TPattern>;
  SupportedStyles: TStringArray;
  PatternItem: TPattern;
  I: Integer;
  Rejected: Boolean;
begin
  Plugin := APluginClass.Create;
  Params := nil;
  Patterns := nil;
  try
    SupportedStyles := Plugin.GetSupportedStyles;
    Check(SameText(Plugin.GetGenreName, AGenre),
      AGenre + ' plugin must report its genre name');
    Check(Length(SupportedStyles) = Length(ARegistryStyles),
      AGenre + ' plugin style metadata must match the registry');
    for I := 0 to High(SupportedStyles) do
    begin
      Check(SameText(SupportedStyles[I], ARegistryStyles[I]),
        AGenre + ' plugin style metadata must match the registry');
      Check(Plugin.SupportsStyle(SupportedStyles[I]),
        AGenre + ' plugin must support each registered style');
    end;
    for I := 0 to High(SupportedStyles) do
    begin
      Params := TGenerationParameters.Create(AGenre, SupportedStyles[I]);
      try
        Patterns := Plugin.GetSectionFlavors('verse', Params);
        try
          Check((Patterns.Count > 0) and
            (Pos(LowerCase(AGenre + '_' + SupportedStyles[I] + '_verse_'),
              LowerCase(Patterns[0].Name)) = 1),
            AGenre + ' must generate verse patterns for style ' +
              SupportedStyles[I]);
        finally
          for PatternItem in Patterns do
            PatternItem.Free;
          Patterns.Free;
          Patterns := nil;
        end;
      finally
        Params.Free;
        Params := nil;
      end;
    end;

    Check(Plugin.SupportsStyle(UpperCase(AValidStyle)),
      AGenre + ' style validation must be case-insensitive');
    Check(not Plugin.SupportsStyle(AInvalidStyle),
      AGenre + ' plugin must reject styles that belong to another genre');

    Params := TGenerationParameters.Create(AGenre, AInvalidStyle);
    Check(not Plugin.ValidateParameters(Params),
      AGenre + ' parameter validation must reject unsupported styles');
    Rejected := False;
    try
      Patterns := Plugin.GetSectionFlavors('verse', Params);
    except
      on E: Exception do
        Rejected := Pos('Unsupported style', E.Message) > 0;
    end;
    Check(Rejected,
      AGenre + ' pattern generation must report unsupported styles explicitly');
  finally
    if Assigned(Patterns) then
    begin
      for PatternItem in Patterns do
        PatternItem.Free;
      Patterns.Free;
    end;
    Params.Free;
    Plugin.Free;
  end;
end;

procedure CheckPublicPatternGeneration;
var
  API: TDrumGeneratorAPI;
  GeneratedPattern: TPattern;
  GeneratedSong: TSong;
  Rejected: Boolean;
begin
  API := TDrumGeneratorAPI.Create;
  try
    GeneratedPattern := API.GeneratePattern('rock', 'blues');
    try
      Check(Pos('rock_blues_verse_', GeneratedPattern.Name) = 1,
        'public pattern API must use its style argument and generate a verse');
    finally
      GeneratedPattern.Free;
    end;

    Rejected := False;
    try
      GeneratedPattern := API.GeneratePattern('rock', 'doom');
      GeneratedPattern.Free;
    except
      on E: Exception do
        Rejected := Pos('Unsupported style', E.Message) > 0;
    end;
    Check(Rejected,
      'public pattern API must reject a style unsupported by the genre');

    Rejected := False;
    try
      GeneratedSong := API.CreateSong('rock', 'doom');
      GeneratedSong.Free;
    except
      on E: Exception do
        Rejected := Pos('Unsupported style', E.Message) > 0;
    end;
    Check(Rejected,
      'public song API must reject a style unsupported by the genre');
  finally
    API.Free;
  end;
end;

function GetChorusSignature(APluginClass: TGenrePluginClass;
  const AGenre, AStyle, AExpectedDefaultStyle: string): string;
var
  Plugin: TGenrePlugin;
  Params: TGenerationParameters;
  Patterns: specialize TList<TPattern>;
  PatternItem, GeneratedPattern: TPattern;
  Beat: TBeat;
  I: Integer;
begin
  Plugin := APluginClass.Create;
  Params := TGenerationParameters.Create(AGenre, AStyle);
  Patterns := nil;
  try
    Patterns := Plugin.GetSectionFlavors('chorus', Params);
    Check(Patterns.Count >= 2,
      AGenre + ' chorus must expose multiple style-specific pattern flavors');
    for PatternItem in Patterns do
      Check(Pos(AStyle + '_chorus_', PatternItem.Name) > 0,
        AGenre + ' chorus flavor must honor requested style ' + AStyle);

    PatternItem := Patterns[0];
    Result := IntToStr(PatternItem.Beats.Count);
    for I := 0 to PatternItem.Beats.Count - 1 do
    begin
      Beat := PatternItem.Beats[I];
      if Assigned(Beat.Instrument) then
        Result := Result + '|' + FormatFloat('0.000', Beat.Position) + ':' +
          Beat.Instrument.Name + ':' + IntToStr(Beat.Velocity);
    end;

    GeneratedPattern := Plugin.GeneratePattern('chorus', Params);
    try
      Check(Pos(AStyle + '_chorus_', GeneratedPattern.Name) > 0,
        AGenre + ' GeneratePattern must honor requested style ' + AStyle);
    finally
      GeneratedPattern.Free;
    end;

    for PatternItem in Patterns do
      PatternItem.Free;
    Patterns.Free;
    Patterns := Plugin.GetSectionFlavors('verse', Params);
    Check((Patterns.Count = 3) and
      (Pos(AStyle + '_verse_', Patterns[0].Name) > 0),
      AGenre + ' verse section must select the requested style');
    for PatternItem in Patterns do
      PatternItem.Free;
    Patterns.Free;
    Patterns := Plugin.GetSectionFlavors('bridge', Params);
    Check((Patterns.Count = 3) and
      (Pos(AStyle + '_bridge_', Patterns[0].Name) > 0),
      AGenre + ' bridge section must select the requested style');
    for PatternItem in Patterns do
      PatternItem.Free;
    Patterns.Free;
    Patterns := Plugin.GetSectionFlavors('chorus', nil);
    Check(Pos(AExpectedDefaultStyle + '_chorus_', Patterns[0].Name) > 0,
      AGenre + ' plugin must restore its configured default style after flavor generation');
  finally
    if Assigned(Patterns) then
    begin
      for PatternItem in Patterns do
        PatternItem.Free;
      Patterns.Free;
    end;
    Params.Free;
    Plugin.Free;
  end;
end;

var
  RockClassic, RockBlues: string;
  JazzSwing, JazzLatin: string;
  FunkClassic, FunkMinimal: string;
  ElectronicHouse, ElectronicDnB: string;
  API: TDrumGeneratorAPI;
begin
  API := TDrumGeneratorAPI.Create;
  try
    CheckStyleContract(TMetalGenrePlugin, 'metal', 'heavy', 'house',
      API.PluginRegistry.GetStylesForGenre('metal'));
    CheckStyleContract(TRockGenrePlugin, 'rock', 'classic', 'doom',
      API.PluginRegistry.GetStylesForGenre('rock'));
    CheckStyleContract(TJazzGenrePlugin, 'jazz', 'swing', 'doom',
      API.PluginRegistry.GetStylesForGenre('jazz'));
    CheckStyleContract(TFunkGenrePlugin, 'funk', 'classic', 'doom',
      API.PluginRegistry.GetStylesForGenre('funk'));
    CheckStyleContract(TElectronicGenrePlugin, 'electronic', 'house', 'doom',
      API.PluginRegistry.GetStylesForGenre('electronic'));
  finally
    API.Free;
  end;

  CheckPublicPatternGeneration;

  RockClassic := GetChorusSignature(TRockGenrePlugin, 'rock', 'classic', 'classic');
  RockBlues := GetChorusSignature(TRockGenrePlugin, 'rock', 'blues', 'classic');
  JazzSwing := GetChorusSignature(TJazzGenrePlugin, 'jazz', 'swing', 'swing');
  JazzLatin := GetChorusSignature(TJazzGenrePlugin, 'jazz', 'latin', 'swing');
  FunkClassic := GetChorusSignature(TFunkGenrePlugin, 'funk', 'classic', 'classic');
  FunkMinimal := GetChorusSignature(TFunkGenrePlugin, 'funk', 'minimal', 'classic');
  ElectronicHouse := GetChorusSignature(
    TElectronicGenrePlugin, 'electronic', 'house', 'house');
  ElectronicDnB := GetChorusSignature(
    TElectronicGenrePlugin, 'electronic', 'drum_and_bass', 'house');

  Check(RockClassic <> RockBlues,
    'rock classic and blues styles must differ structurally');
  Check(JazzSwing <> JazzLatin,
    'jazz swing and latin styles must differ structurally');
  Check(FunkClassic <> FunkMinimal,
    'funk classic and minimal styles must differ structurally');
  Check(ElectronicHouse <> ElectronicDnB,
    'electronic house and drum-and-bass styles must differ structurally');
  WriteLn('PASS: requested genre styles, section flavors, and plugin-state restoration');
end.
