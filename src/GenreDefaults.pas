unit GenreDefaults;

{$mode objfpc}{$H+}

{ What a genre does when the user says nothing, from files named after it:

  config/defaults/<genre>.ini        tempo per style, drummers that suit it

      [bpm]
      default=140                    any style not listed below
      heavy=140
      doom=70

      [drummers]
      preferred=bonham, roeder, dee  picked at random when no --drummer is given

  config/sections/<genre>.json       the default song structure, in the same
                                     format as --structure:
      {"sections": [{"name": "intro", "bars": 4}, {"name": "verse", "bars": 8}]}

  A value that is missing or a file with a mistake falls back to what is built
  into the program, and the mistake goes to ConfigWarnings. }

interface

uses
  Classes, SysUtils, Generics.Collections, IniFiles, ComposerV2, ConfigFiles, SongStructure;

{ Tempo of a genre and style from its defaults file; 0 when the file has no
  value for it. }
function FileDefaultBpm(const AGenre, AStyle: string): Integer;

{ The preferred drummers of a genre from its defaults file; nil when the file
  has none. }
function FilePreferredDrummers(const AGenre: string): specialize TArray<string>;

{ The default structure of a genre from its sections file; nil when there is
  none (or it has a mistake). }
function FileDefaultStructure(const AGenre: string): specialize TArray<TSectionDef>;

implementation

function OpenDefaults(const AGenre: string): TIniFile;
var
  Path: string;
begin
  Result := nil;
  Path := FindConfigFile('defaults', LowerCase(AGenre) + '.ini');
  if Path <> '' then
    Result := TIniFile.Create(Path);
end;

function FileDefaultBpm(const AGenre, AStyle: string): Integer;
var
  Ini: TIniFile;
  Text: string;
begin
  Result := 0;
  Ini := OpenDefaults(AGenre);
  if Ini = nil then
    Exit;
  try
    Text := Trim(Ini.ReadString('bpm', LowerCase(AStyle), ''));
    if Text = '' then
      Text := Trim(Ini.ReadString('bpm', 'default', ''));
    if Text = '' then
      Exit;
    if not TryStrToInt(Text, Result) or (Result < MIN_SECTION_TEMPO) or
       (Result > MAX_SECTION_TEMPO) then
    begin
      AddConfigWarning(Format('%s.ini [bpm]: "%s" is not a tempo between %d and %d - ignored',
        [LowerCase(AGenre), Text, MIN_SECTION_TEMPO, MAX_SECTION_TEMPO]));
      Result := 0;
    end;
  finally
    Ini.Free;
  end;
end;

function FilePreferredDrummers(const AGenre: string): specialize TArray<string>;
var
  Ini: TIniFile;
  Parts: TStringList;
  I: Integer;
  Name: string;
begin
  Result := nil;
  Ini := OpenDefaults(AGenre);
  if Ini = nil then
    Exit;
  Parts := TStringList.Create;
  try
    if not Ini.ValueExists('drummers', 'preferred') then
      Exit;
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    Parts.DelimitedText := Ini.ReadString('drummers', 'preferred', '');
    for I := 0 to Parts.Count - 1 do
    begin
      Name := LowerCase(Trim(Parts[I]));
      if Name = '' then
        Continue;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Name;
    end;
  finally
    Parts.Free;
    Ini.Free;
  end;
end;

function FileDefaultStructure(const AGenre: string): specialize TArray<TSectionDef>;
var
  Path: string;
  Info: TStructureInfo;
begin
  Result := nil;
  Path := FindConfigFile('sections', LowerCase(AGenre) + '.json');
  if Path = '' then
    Exit;
  try
    Info := LoadStructureFile(Path);
    Result := Info.Sections;
  except
    on E: Exception do
      AddConfigWarning(E.Message + ' - the file is ignored');
  end;
end;

end.
