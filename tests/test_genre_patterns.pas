program test_genre_patterns;

{$mode objfpc}{$H+}

uses
  SysUtils, Generics.Collections, jsonparser, Pattern, Kit, Song, generation_parameters,
  GenrePlugin, Rock, Jazz, Funk, Electronic;

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
begin
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
