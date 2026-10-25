unit DrummerProfiles;

{$mode objfpc}{$H+}

{ Loads per-drummer timing profiles from config/drummer_profiles.ini.

  The file is looked up next to the executable (config/drummer_profiles.ini)
  and, for development runs, one directory above it. When no file is found
  the built-in defaults below are used, so the engine behaves the same as it
  did before the profiles were externalised. }

interface

uses
  Classes, SysUtils, IniFiles;

type
  TInstrumentFamily = (ifKick, ifSnare, ifHihat, ifCymbal, ifTom, ifOther);

  TDrummerProfile = record
    GrooveBias: Double;                       { fraction of a beat }
    TimingMs: array[TInstrumentFamily] of Double; { constant offset per family }
  end;

{ Profile for the given drummer; unknown drummers get the default profile. }
function GetDrummerProfile(const ADrummer: string): TDrummerProfile;

{ Instrument family of a drum instrument name (kick, snare, hh_*, ride_* ...). }
function InstrumentFamilyOf(const AInstrumentName: string): TInstrumentFamily;

{ Path of the profile file that was loaded ('' when built-in defaults are used). }
function LoadedProfilePath: string;

{ Forces the profile file to be read again on the next lookup. }
procedure ReloadDrummerProfiles;

implementation

var
  GLoaded: Boolean = False;
  GPath: string = '';
  GDefault: TDrummerProfile;
  GProfiles: TStringList = nil;   { name -> index into GStore }
  GStore: array of TDrummerProfile;

function EmptyProfile(ABias: Double): TDrummerProfile;
var
  F: TInstrumentFamily;
begin
  Result.GrooveBias := ABias;
  for F := Low(TInstrumentFamily) to High(TInstrumentFamily) do
    Result.TimingMs[F] := 0.0;
end;

procedure AddProfile(const AName: string; const AProfile: TDrummerProfile);
begin
  SetLength(GStore, Length(GStore) + 1);
  GStore[High(GStore)] := AProfile;
  GProfiles.AddObject(LowerCase(AName), TObject(PtrInt(High(GStore))));
end;

procedure LoadBuiltInDefaults;
begin
  GDefault := EmptyProfile(0.005);
  AddProfile('bonham', EmptyProfile(0.025));
  AddProfile('porcaro', EmptyProfile(-0.010));
  AddProfile('weckl', EmptyProfile(0.005));
  AddProfile('chambers', EmptyProfile(-0.005));
  AddProfile('carey', EmptyProfile(0.015));
  AddProfile('peart', EmptyProfile(0.0));
  AddProfile('hoglan', EmptyProfile(-0.002));
  AddProfile('copeland', EmptyProfile(0.020));
end;

function FindProfileFile: string;
var
  ExeDir: string;
begin
  ExeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := ExeDir + 'config' + DirectorySeparator + 'drummer_profiles.ini';
  if FileExists(Result) then
    Exit;
  Result := ExeDir + '..' + DirectorySeparator + 'config' + DirectorySeparator +
    'drummer_profiles.ini';
  if FileExists(Result) then
    Exit;
  Result := '';
end;

function ReadProfile(AIni: TIniFile; const ASection: string;
  const AFallback: TDrummerProfile): TDrummerProfile;
var
  Fmt: TFormatSettings;
  function ReadF(const AKey: string; ADefault: Double): Double;
  var
    S: string;
  begin
    S := Trim(AIni.ReadString(ASection, AKey, ''));
    if S = '' then
      Exit(ADefault);
    if not TryStrToFloat(S, Result, Fmt) then
      Result := ADefault;
  end;
begin
  Fmt := DefaultFormatSettings;
  Fmt.DecimalSeparator := '.';
  Result.GrooveBias := ReadF('groove_bias', AFallback.GrooveBias);
  Result.TimingMs[ifKick] := ReadF('timing_kick', AFallback.TimingMs[ifKick]);
  Result.TimingMs[ifSnare] := ReadF('timing_snare', AFallback.TimingMs[ifSnare]);
  Result.TimingMs[ifHihat] := ReadF('timing_hihat', AFallback.TimingMs[ifHihat]);
  Result.TimingMs[ifCymbal] := ReadF('timing_cymbal', AFallback.TimingMs[ifCymbal]);
  Result.TimingMs[ifTom] := ReadF('timing_tom', AFallback.TimingMs[ifTom]);
  Result.TimingMs[ifOther] := 0.0;
end;

procedure EnsureLoaded;
var
  Ini: TIniFile;
  Sections: TStringList;
  I: Integer;
begin
  if GLoaded then
    Exit;
  GLoaded := True;
  GPath := '';
  SetLength(GStore, 0);
  if GProfiles = nil then
    GProfiles := TStringList.Create
  else
    GProfiles.Clear;

  LoadBuiltInDefaults;

  GPath := FindProfileFile;
  if GPath = '' then
    Exit;

  Ini := TIniFile.Create(GPath);
  Sections := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    if Sections.IndexOf('default') >= 0 then
      GDefault := ReadProfile(Ini, 'default', GDefault);
    for I := 0 to Sections.Count - 1 do
      if not SameText(Sections[I], 'default') then
        AddProfile(Sections[I], ReadProfile(Ini, Sections[I], GDefault));
  finally
    Sections.Free;
    Ini.Free;
  end;
end;

function GetDrummerProfile(const ADrummer: string): TDrummerProfile;
var
  I: Integer;
begin
  EnsureLoaded;
  Result := GDefault;
  { Later entries (from the file) override the built-in ones. }
  for I := GProfiles.Count - 1 downto 0 do
    if GProfiles[I] = LowerCase(Trim(ADrummer)) then
    begin
      Result := GStore[PtrInt(GProfiles.Objects[I])];
      Exit;
    end;
end;

function InstrumentFamilyOf(const AInstrumentName: string): TInstrumentFamily;
var
  N: string;
begin
  N := LowerCase(Trim(AInstrumentName));
  if Copy(N, 1, 4) = 'kick' then
    Result := ifKick
  else if Copy(N, 1, 5) = 'snare' then
    Result := ifSnare
  else if (Copy(N, 1, 3) = 'hh_') or (Copy(N, 1, 5) = 'hihat') then
    Result := ifHihat
  else if (Copy(N, 1, 5) = 'ride_') or (Copy(N, 1, 6) = 'cymbal') or
          (Copy(N, 1, 5) = 'crash') or (Copy(N, 1, 5) = 'china') or
          (Copy(N, 1, 6) = 'splash') then
    Result := ifCymbal
  else if Copy(N, 1, 4) = 'tom_' then
    Result := ifTom
  else
    Result := ifOther;
end;

function LoadedProfilePath: string;
begin
  EnsureLoaded;
  Result := GPath;
end;

procedure ReloadDrummerProfiles;
begin
  GLoaded := False;
end;

finalization
  GProfiles.Free;

end.
