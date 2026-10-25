program export_defaults;

{$mode objfpc}{$H+}

{ Writes the built-in defaults as files named after the genre:

      config/defaults/<genre>.ini     tempo per style, preferred drummers
      config/sections/<genre>.json    default song structure

  Run from the project root. The files play exactly what the engine does
  without them; after that they are the place to edit. }

uses
  SysUtils, Classes, StrUtils, Generics.Collections, jsonparser, ComposerV2, DrumGenerator;

type
  TTexts = array of string;

procedure Save(const AFile: string; const ALines: TStrings);
begin
  ForceDirectories(ExtractFilePath(AFile));
  ALines.SaveToFile(AFile);
  WriteLn('wrote ', AFile);
end;

procedure WriteGenre(AGen: TDrumGenerator; const AGenre: string);
var
  Ini, Json: TStringList;
  Styles, Drummers: TStringArray;
  Style, Preferred: string;
  Structure: specialize TArray<TSectionDef>;
  I: Integer;
begin
  Styles := AGen.PluginManager.Registry.GetStylesForGenre(AGenre);
  Drummers := AGen.PluginManager.Registry.GetPreferredDrummersForGenre(AGenre);

  Ini := TStringList.Create;
  try
    Ini.Add('; ' + AGenre + ' defaults.');
    Ini.Add(';');
    Ini.Add('; [bpm]       the tempo of each style when --tempo is not given;');
    Ini.Add(';             "default" is used for a style not listed (a style you add)');
    Ini.Add('; [drummers]  who plays when --drummer is not given, picked at random');
    Ini.Add('');
    Ini.Add('[bpm]');
    Ini.Add('default=' + IntToStr(GetDefaultBpm(AGenre, '')));
    for Style in Styles do
      Ini.Add(Style + '=' + IntToStr(GetDefaultBpm(AGenre, Style)));
    Ini.Add('');
    Ini.Add('[drummers]');
    Preferred := '';
    for I := 0 to High(Drummers) do
    begin
      if I > 0 then
        Preferred := Preferred + ', ';
      Preferred := Preferred + Drummers[I];
    end;
    Ini.Add('preferred=' + Preferred);
    Save('config' + PathDelim + 'defaults' + PathDelim + AGenre + '.ini', Ini);
  finally
    Ini.Free;
  end;

  Structure := AGen.DefaultStructure(AGenre);
  Json := TStringList.Create;
  try
    Json.Add('{');
    Json.Add('  "_comment": "Default song structure of ' + AGenre + ', used when --section and --structure are not given. Same format as --structure; the total length is fitted to a radio-length song.",');
    Json.Add('  "sections": [');
    for I := 0 to High(Structure) do
      Json.Add(Format('    { "name": "%s", "bars": %d }%s',
        [Structure[I].Name, Structure[I].Bars, IfThen(I < High(Structure), ',', '')]));
    Json.Add('  ]');
    Json.Add('}');
    Save('config' + PathDelim + 'sections' + PathDelim + AGenre + '.json', Json);
  finally
    Json.Free;
  end;
end;

var
  Gen: TDrumGenerator;
  Genre: string;
begin
  Gen := TDrumGenerator.Create;
  try
    for Genre in Gen.PluginManager.Registry.GetAvailableGenres do
      WriteGenre(Gen, Genre);
  finally
    Gen.Free;
  end;
end.
