unit ConfigFiles;

{$mode objfpc}{$H+}

{ Where the engine finds its text files: grooves, fills, sections, defaults.

  Every file is named after what it describes (config/grooves/metal.tab,
  config/fills/weckl.tab, ...), so adding content is adding or editing a file.

  Folders are searched in this order, and the first folder that has the file
  wins - so a file in your own folder replaces the installed one without
  touching the installation:

    1. the user folder      %APPDATA%\ChameleonDrummer\config   (or ~/.config/ChameleonDrummer/config)
    2. next to the program  <exe folder>\config
    3. one folder above it  <exe folder>\..\config             (development builds)

  The environment variable CHAMELEON_CONFIG, when set, is searched first. }

interface

uses
  Classes, SysUtils;

var
  { When set, this folder is searched before all others (tests, tools). }
  ConfigRootOverride: string = '';

{ The folders that are searched, in order (they need not exist). }
function ConfigRoots: TStringArray;

{ Full path of ASubDir/AName in the first root that has it, '' if none. }
function FindConfigFile(const ASubDir, AName: string): string;

{ Names (without extension, lower case) of all files with AExt in ASubDir over
  all roots, each once, sorted. }
procedure ListConfigNames(const ASubDir, AExt: string; ANames: TStrings);

{ Mistakes found in config files, one line each, filled by the loaders. A
  loader that finds a mistake ignores that file and reports it here, so one
  bad file cannot stop the program. The command line tool prints them. }
function ConfigWarnings: TStringList;
procedure AddConfigWarning(const AText: string);

{ The whole text file as lines. Raises an Exception naming the file when it
  cannot be read. A UTF-8 byte order mark is dropped. }
procedure ReadConfigLines(const APath: string; ALines: TStrings);

implementation

var
  GWarnings: TStringList = nil;

function ConfigWarnings: TStringList;
begin
  if GWarnings = nil then
    GWarnings := TStringList.Create;
  Result := GWarnings;
end;

procedure AddConfigWarning(const AText: string);
begin
  if ConfigWarnings.IndexOf(AText) < 0 then
    ConfigWarnings.Add(AText);
end;

function ConfigRoots: TStringArray;
var
  List: TStringList;
  ExeDir, Base, Env: string;
  I: Integer;
begin
  List := TStringList.Create;
  try
    if ConfigRootOverride <> '' then
      List.Add(IncludeTrailingPathDelimiter(ConfigRootOverride));
    Env := GetEnvironmentVariable('CHAMELEON_CONFIG');
    if Env <> '' then
      List.Add(IncludeTrailingPathDelimiter(Env));

    {$IFDEF MSWINDOWS}
    Base := GetEnvironmentVariable('APPDATA');
    {$ELSE}
    Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
    if Base = '' then
      Base := IncludeTrailingPathDelimiter(GetUserDir) + '.config';
    {$ENDIF}
    if Base <> '' then
      List.Add(IncludeTrailingPathDelimiter(Base) + 'ChameleonDrummer' +
        PathDelim + 'config' + PathDelim);

    ExeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    List.Add(ExeDir + 'config' + PathDelim);
    List.Add(ExeDir + '..' + PathDelim + 'config' + PathDelim);

    SetLength(Result, List.Count);
    for I := 0 to List.Count - 1 do
      Result[I] := List[I];
  finally
    List.Free;
  end;
end;

function FindConfigFile(const ASubDir, AName: string): string;
var
  Root: string;
begin
  for Root in ConfigRoots do
  begin
    Result := Root + ASubDir + PathDelim + AName;
    if FileExists(Result) then
      Exit;
  end;
  Result := '';
end;

procedure ListConfigNames(const ASubDir, AExt: string; ANames: TStrings);
var
  Root, Name: string;
  Found: TSearchRec;
  Sorted: TStringList;
begin
  Sorted := TStringList.Create;
  try
    Sorted.Sorted := True;
    Sorted.Duplicates := dupIgnore;
    for Root in ConfigRoots do
      if FindFirst(Root + ASubDir + PathDelim + '*' + AExt, faAnyFile and not faDirectory, Found) = 0 then
      try
        repeat
          Name := LowerCase(ChangeFileExt(Found.Name, ''));
          if (Name <> '') and (Name[1] <> '_') then
            Sorted.Add(Name);
        until FindNext(Found) <> 0;
      finally
        FindClose(Found);
      end;
    ANames.Clear;
    ANames.AddStrings(Sorted);
  finally
    Sorted.Free;
  end;
end;

procedure ReadConfigLines(const APath: string; ALines: TStrings);
var
  Stream: TFileStream;
  Text: string;
begin
  try
    Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Text, Stream.Size);
      if Stream.Size > 0 then
        Stream.ReadBuffer(Text[1], Stream.Size);
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt('Cannot read "%s": %s', [APath, E.Message]);
  end;
  if (Length(Text) >= 3) and (Text[1] = #$EF) and (Text[2] = #$BB) and (Text[3] = #$BF) then
    Delete(Text, 1, 3);
  ALines.Text := Text;
end;

finalization
  GWarnings.Free;
end.
