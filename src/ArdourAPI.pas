unit ArdourAPI;

{$mode objfpc}{$H+}

{ Ardour bridge.

  Ardour has no text project format like REAPER's .rpp: a session is a
  directory whose state is an XML document produced by Ardour itself, and
  every node in it is version-stamped. Writing that by hand would be brittle
  across releases, so the exporter does not.

  Instead it writes

    - the MIDI file, and
    - a small Lua data file describing the tempo map and the song structure,

  and then invokes Ardour's standalone Lua interpreter (ardour9-lua) with
  ardour/import_chameleon_song.lua, which builds the session inside Ardour
  itself: the MIDI track, the tempo map, one range location (region) and one
  point marker per song section, and the MIDI region.

  Positions are carried in beats, which is Ardour's own time domain for
  locations, so no conversion happens on Ardour's side. }

interface

uses
  Classes, SysUtils, Generics.Collections, process, Song;

type
  { One section of the song, in beats from the start of the song. }
  TArdourSection = record
    Name: String;
    StartBeat: Double;
    EndBeat: Double;
  end;

  { One tempo/meter change point, in beats from the start of the song. }
  TArdourTempoPoint = record
    Beat: Double;
    BPM: Integer;
    BeatsPerBar: Integer;
  end;

  TArdourBridge = class(TObject)
  private
    FSampleRate: Integer;
    function FindArdourLua(out ADataPath: String): String;
    function FindLuaScript: String;
    function LuaQuote(const AValue: String): String;
    function WriteDataFile(const ASong: TSong; const AMIDIFile, ADataPath,
      ASessionDir, ASessionName: String;
      const ASections: specialize TList<TArdourSection>;
      const ATempoPoints: specialize TList<TArdourTempoPoint>;
      ATotalBeats: Double): Boolean;
    function DeleteTree(const ADir: String): Boolean;
    function RunArdourLua(const ALuaExe, AScript, ADataPath: String;
      out ALog: String): Integer;
  public
    constructor Create(ASampleRate: Integer = 48000);
    destructor Destroy; override;

    { Creates a complete Ardour session for ASong.

      AMIDIFile is the MIDI file that was written for the song; ASessionDir
      is the session directory to create. An existing directory of the same
      name is replaced.

      Returns True when the session was built. }
    function CreateFromSong(const ASong: TSong; const AMIDIFile,
      ASessionDir: String): Boolean;
  end;

implementation

const
  LuaScriptName = 'import_chameleon_song.lua';
  { Candidate names of Ardour's standalone Lua interpreter, newest first. }
  ArdourLuaNames: array[0..2] of String = (
    'ardour9-lua.exe', 'ardour8-lua.exe', 'ardour-lua.exe');

{ Locale-independent float formatting - the Lua data file must always use a
  decimal point. }
function FloatToStrDot(Value: Double): String;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.000000', Value, FS);
end;

constructor TArdourBridge.Create(ASampleRate: Integer);
begin
  inherited Create;
  FSampleRate := ASampleRate;
  if FSampleRate <= 0 then
    FSampleRate := 48000;
end;

destructor TArdourBridge.Destroy;
begin
  inherited Destroy;
end;

function TArdourBridge.LuaQuote(const AValue: String): String;
var
  S: String;
  I: Integer;
  C: Char;
begin
  S := '';
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];
    case C of
      '"': S := S + '\"';
      '\': S := S + '\\';
      #10: S := S + '\n';
      #13: S := S + '\r';
    else
      S := S + C;
    end;
  end;
  Result := '"' + S + '"';
end;

function TArdourBridge.FindArdourLua(out ADataPath: String): String;
var
  ProgramFiles, Path, Dir, Name: String;
  I, J, K: Integer;
  Major: Integer;
begin
  Result := '';
  ADataPath := '';

  { 1. the standard install locations }
  ProgramFiles := GetEnvironmentVariable('ProgramFiles');
  if ProgramFiles = '' then
    ProgramFiles := GetEnvironmentVariable('ProgramFiles(x86)');
  if ProgramFiles <> '' then
    for I := Low(ArdourLuaNames) to High(ArdourLuaNames) do
    begin
      Major := 9 - I;
      Dir := IncludeTrailingPathDelimiter(ProgramFiles) + 'Ardour' +
        IntToStr(Major) + '\bin\';
      Name := Dir + ArdourLuaNames[I];
      if FileExists(Name) then
      begin
        Result := Name;
        { Ardour looks for its data files relative to the binary. }
        ADataPath := IncludeTrailingPathDelimiter(ProgramFiles) + 'Ardour' +
          IntToStr(Major) + '\share\ardour' + IntToStr(Major);
        if not DirectoryExists(ADataPath) then
          ADataPath := '';
        Exit;
      end;
    end;

  { 2. anywhere on PATH }
  Path := GetEnvironmentVariable('PATH');
  if Path <> '' then
  begin
    I := 1;
    while I <= Length(Path) do
    begin
      J := Pos(';', Copy(Path, I, Length(Path)));
      if J = 0 then
      begin
        Dir := Copy(Path, I, Length(Path));
        I := Length(Path) + 1;
      end
      else
      begin
        Dir := Copy(Path, I, J - 1);
        I := I + J;
      end;
      if Dir <> '' then
      begin
        Dir := IncludeTrailingPathDelimiter(Dir);
        for K := Low(ArdourLuaNames) to High(ArdourLuaNames) do
          if FileExists(Dir + ArdourLuaNames[K]) then
          begin
            Result := Dir + ArdourLuaNames[K];
            Exit;
          end;
      end;
    end;
  end;
end;

function TArdourBridge.FindLuaScript: String;
var
  ExeDir, Cwd: String;
begin
  Result := '';
  ExeDir := ExtractFilePath(ParamStr(0));
  if ExeDir = '' then
    ExeDir := IncludeTrailingPathDelimiter(GetCurrentDir);
  Cwd := IncludeTrailingPathDelimiter(GetCurrentDir);

  if FileExists(ExeDir + 'ardour\' + LuaScriptName) then
    Exit(ExeDir + 'ardour\' + LuaScriptName);
  if FileExists(ExeDir + LuaScriptName) then
    Exit(ExeDir + LuaScriptName);
  if FileExists(Cwd + 'ardour\' + LuaScriptName) then
    Exit(Cwd + 'ardour\' + LuaScriptName);
  if FileExists(Cwd + LuaScriptName) then
    Exit(Cwd + LuaScriptName);
end;

function TArdourBridge.WriteDataFile(const ASong: TSong; const AMIDIFile, ADataPath,
  ASessionDir, ASessionName: String;
  const ASections: specialize TList<TArdourSection>;
  const ATempoPoints: specialize TList<TArdourTempoPoint>;
  ATotalBeats: Double): Boolean;
var
  Lines: TStringList;
  Section: TArdourSection;
  Point: TArdourTempoPoint;
  I: Integer;
  MidiPath: String;
begin
  Result := False;
  { Ardour and Lua both understand forward slashes on Windows. }
  MidiPath := StringReplace(AMIDIFile, '\', '/', [rfReplaceAll]);

  Lines := TStringList.Create;
  try
    Lines.Add('-- generated by ChameleonDrummer - do not edit');
    Lines.Add('return {');
    Lines.Add('  session_dir = ' +
      LuaQuote(StringReplace(ASessionDir, '\', '/', [rfReplaceAll])) + ',');
    Lines.Add('  session_name = ' + LuaQuote(ASessionName) + ',');
    Lines.Add('  sample_rate = ' + IntToStr(FSampleRate) + ',');
    Lines.Add('  title = ' + LuaQuote(ASong.Name) + ',');
    Lines.Add('  midi_file = ' + LuaQuote(MidiPath) + ',');
    Lines.Add('  total_beats = ' + FloatToStrDot(ATotalBeats) + ',');
    Lines.Add('  tempo_points = {');
    for I := 0 to ATempoPoints.Count - 1 do
    begin
      Point := ATempoPoints[I];
      Lines.Add('    { beat = ' + FloatToStrDot(Point.Beat) +
        ', bpm = ' + IntToStr(Point.BPM) +
        ', beats_per_bar = ' + IntToStr(Point.BeatsPerBar) + ' },');
    end;
    Lines.Add('  },');
    Lines.Add('  sections = {');
    for I := 0 to ASections.Count - 1 do
    begin
      Section := ASections[I];
      Lines.Add('    { name = ' + LuaQuote(Section.Name) +
        ', start_beat = ' + FloatToStrDot(Section.StartBeat) +
        ', end_beat = ' + FloatToStrDot(Section.EndBeat) + ' },');
    end;
    Lines.Add('  },');
    Lines.Add('}');
    Lines.SaveToFile(ADataPath);
    Result := True;
  except
    on E: Exception do
    begin
      WriteLn('[Error] Could not write Ardour data file: ', ADataPath,
        ' (', E.Message, ')');
      Result := False;
    end;
  end;
  Lines.Free;
end;

function TArdourBridge.DeleteTree(const ADir: String): Boolean;
var
  SR: TSearchRec;
  Sub: String;
begin
  Result := True;
  if not DirectoryExists(ADir) then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        Sub := IncludeTrailingPathDelimiter(ADir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          Result := DeleteTree(Sub) and Result
        else
          Result := DeleteFile(Sub) and Result;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  Result := RemoveDir(ADir) and Result;
end;

function TArdourBridge.RunArdourLua(const ALuaExe, AScript, ADataPath: String;
  out ALog: String): Integer;
var
  BatchFile, LogFile: String;
  Batch: TStringList;
begin
  { Ardour's plugin scan is very chatty, so the child runs through a small
    batch file that captures its output. The log is shown only when the run
    fails. }
  Result := -1;
  ALog := '';
  LogFile := ChangeFileExt(ADataPath, '.log');
  BatchFile := ChangeFileExt(ADataPath, '.run.bat');

  Batch := TStringList.Create;
  try
    Batch.Add('@echo off');
    Batch.Add('"' + ALuaExe + '" "' + AScript + '" "' + ADataPath + '" > "' +
      LogFile + '" 2>&1');
    Batch.Add('exit /b %ERRORLEVEL%');
    Batch.SaveToFile(BatchFile);
  finally
    Batch.Free;
  end;

  try
    Result := ExecuteProcess('cmd.exe', ['/c', BatchFile]);
  finally
    DeleteFile(BatchFile);
  end;

  if FileExists(LogFile) then
  begin
    ALog := '';
    with TStringList.Create do
    try
      LoadFromFile(LogFile);
      ALog := Text;
    finally
      Free;
    end;
  end;
end;

function TArdourBridge.CreateFromSong(const ASong: TSong; const AMIDIFile,
  ASessionDir: String): Boolean;
var
  Sections: specialize TList<TArdourSection>;
  TempoPoints: specialize TList<TArdourTempoPoint>;
  Section: TSection;
  Spec: TSongBarSpec;
  BarSpecs: specialize TList<TSongBarSpec>;
  Entry: TArdourSection;
  Point: TArdourTempoPoint;
  BeatCursor, SliceBeats, TotalBeats: Double;
  SessionName, DataPath, LuaExe, DataDir, Script, MidiPath, Log: String;
  Args: array of UnicodeString;
  ExitCode: Integer;
begin
  Result := False;
  if not Assigned(ASong) or (ASong.Sections.Count = 0) then
    Exit;

  DataDir := '';  // Ensure initialized before passing to FindArdourLua
  LuaExe := FindArdourLua(DataDir);
  if LuaExe = '' then
  begin
    WriteLn('[Error] Ardour Lua interpreter (ardour9-lua) not found - ' +
      'install Ardour 8/9 or add it to PATH');
    Exit;
  end;

  Script := FindLuaScript;
  if Script = '' then
  begin
    WriteLn('[Error] Ardour import script not found (ardour\' + LuaScriptName + ')');
    Exit;
  end;
  if Script = '' then
  begin
    WriteLn('[Error] Ardour import script not found (ardour\' + LuaScriptName + ')');
    Exit;
  end;

  { Build the section list and the tempo map, both in beats. }
  Sections := specialize TList<TArdourSection>.Create;
  TempoPoints := specialize TList<TArdourTempoPoint>.Create;
  try
    BeatCursor := 0.0;
    TotalBeats := 0.0;
    for Section in ASong.Sections do
    begin
      Entry.Name := Section.Name;
      Entry.StartBeat := BeatCursor;
      BarSpecs := Section.ResolvedBarSpecs(ASong.Tempo, ASong.TimeSignature);
      try
        for Spec in BarSpecs do
        begin
          SliceBeats := Spec.Bars * Spec.TimeSignature.BeatsPerBar;
          Point.Beat := BeatCursor;
          Point.BPM := Spec.Tempo;
          Point.BeatsPerBar := Trunc(Spec.TimeSignature.BeatsPerBar);
          if Point.BeatsPerBar < 1 then
            Point.BeatsPerBar := 4;
          TempoPoints.Add(Point);
          BeatCursor := BeatCursor + SliceBeats;
        end;
      finally
        BarSpecs.Free;
      end;
      Entry.EndBeat := BeatCursor;
      Sections.Add(Entry);
      TotalBeats := BeatCursor;
    end;

    SessionName := ChangeFileExt(ExtractFileName(ASessionDir), '');
    DataPath := ChangeFileExt(ASessionDir, '.ardour.lua');
    MidiPath := ChangeFileExt(ASessionDir, '.mid');

    if not WriteDataFile(ASong, MidiPath, DataPath, ASessionDir, SessionName,
      Sections, TempoPoints, TotalBeats) then
      Exit;

    { Ardour refuses to create a session whose directory already exists. }
    if DirectoryExists(ASessionDir) then
      if not DeleteTree(ASessionDir) then
      begin
        WriteLn('[Error] Could not replace existing session directory: ', ASessionDir);
        Exit;
      end;

    SetLength(Args, 2);
    Args[0] := UTF8Encode(Script);
    Args[1] := UTF8Encode(DataPath);
    ExitCode := RunArdourLua(LuaExe, Script, DataPath, Log);
    if ExitCode <> 0 then
    begin
      WriteLn('[Error] ardour-lua failed with exit code ', ExitCode);
      if Log <> '' then
        WriteLn(Log);
      Exit;
    end;

    Result := DirectoryExists(ASessionDir);
  finally
    Sections.Free;
    TempoPoints.Free;
  end;
end;

end.
