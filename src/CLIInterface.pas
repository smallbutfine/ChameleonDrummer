unit CLIInterface;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, fpjson,
  Pattern, Song,
  DrumGenerator, ComposerV2, DrumMidiLoader, SongStructure,
  PluginRegistry, Kit, ReaperAPI, ArdourAPI, ConfigFiles, time_signature;

// ============================================================================
// TCLIArgs - command-line arguments structure
// ============================================================================
type
  TCLIArgs = record
    Command: String; // 'generate', 'pattern', 'list', 'info', 'reaper'
    SubCommand: String; // sub-command (e.g., 'export')
    Genre: String;
    Style: String;
    Tempo: Integer;
    Complexity: Double;
    Humanization: Double;
    Swing: Double; // 0 = straight (default), 0.67 = classic 2:1 swing, 1 = 3:1
    MeterNum: Integer; // --time-sig num/den; 0 = not given (4/4)
    MeterDen: Integer;
    Drummer: String;
    OutputFile: String;
    Mapping: String; // Keymap filename stem (gm, ad2, ezd3, etc)
    StructureFile: String; // --structure / --sidecar: JSON file with the song structure
    SidecarFile: String;

    SongMapFile: String;
    WriteTimelinePath: String;
    Sections: specialize TArray<TSectionDef>; // --section name:bars[@tempo], in order; empty = genre default
    PresetOnly: Boolean; // --preset-only (accepted for reaper/ardour export)
    ExportReaper: Boolean; // generate --reaper: also write <output>.rpp
    ExportArdour: Boolean; // generate --ardour: also write the <output>.ardour session
    ListType: String; // 'genres', 'styles', 'drummers'
    IsSongCommand: Boolean; // --song flag from regen_all.bat
    StrictMeter: Boolean; // --strict-meter: only use patterns matching --time-sig
  end;

type
  TCLIInterface = class
  private
    FGenerator: TDrumGenerator;
    function GetPluginRegistry: PluginRegistry.TPluginRegistry;
    function ParseArgs(const Args: specialize TArray<string>): TCLIArgs;
    procedure HandleGenerate(const Args: TCLIArgs);
    procedure HandlePattern(const Args: TCLIArgs);
    procedure HandleList(const Args: TCLIArgs);
    procedure HandleInfo;
    procedure HandleReaperExport(const Args: TCLIArgs);
    procedure HandleArdourExport(const Args: TCLIArgs);
    procedure PrintGeneratorWarnings;
    procedure PrintConfigWarnings;
    procedure WriteReaperProject(ASong: TSong; const AMidiFile: string);
    procedure WriteArdourSession(ASong: TSong; const AMidiFile, ASessionDir: string);
    procedure ShowUsage;

  public
    constructor Create;
    destructor Destroy; override;

    function Run(Argc: Integer; const Argv: specialize TArray<String>): Integer;
  end;

implementation

function SongMeterNum(const Args: TCLIArgs): Integer;
begin
  if Args.MeterNum > 0 then Result := Args.MeterNum else Result := 4;
end;

function SongMeterDen(const Args: TCLIArgs): Integer;
begin
  if Args.MeterNum > 0 then Result := Args.MeterDen else Result := 4;
end;

function TCLIInterface.GetPluginRegistry: PluginRegistry.TPluginRegistry;
begin
  Result := FGenerator.PluginManager.Registry;
end;

function TCLIInterface.ParseArgs(const Args: specialize TArray<String>): TCLIArgs;
var
  I, ValCode: Integer;

  Name: String;

  Info: TStructureInfo;

  W: String;
begin

  FillChar(Result, SizeOf(Result), 0);
  Result.Tempo := 0;
  Result.Complexity := 0.5;
  Result.Humanization := 0.3;
  Result.Mapping := 'gm';

  I := 1;
  while (I < Length(Args)) do
  begin
    if (Args[I] = '--genre') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.Genre := LowerCase(Args[I])
      else raise Exception.Create('--genre requires a value');
    end
    else if (Args[I] = '--style') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.Style := LowerCase(Args[I])
      else raise Exception.Create('--style requires a value');
    end
    else if (Args[I] = '--tempo') then
    begin
      Inc(I);
      if (I < Length(Args)) then Val(Args[I], Result.Tempo)
      else raise Exception.Create('--tempo requires a value');
    end
    else if (Args[I] = '--complexity') then
    begin
      Inc(I);
      if (I < Length(Args)) then Val(Args[I], Result.Complexity)
      else raise Exception.Create('--complexity requires a value');
    end
    else if (Args[I] = '--humanization') then
    begin
      Inc(I);
      if (I < Length(Args)) then Val(Args[I], Result.Humanization)
      else raise Exception.Create('--humanization requires a value');
    end
    else if (Args[I] = '--section') then
    begin
      Inc(I);
      if (I >= Length(Args)) then
        raise Exception.Create('--section requires a value like verse:8 or chorus:8@140');
      SetLength(Result.Sections, Length(Result.Sections) + 1);
      Result.Sections[High(Result.Sections)] := ParseSectionSpec(Args[I]);
    end
    else if (Args[I] = '--time-sig') then
    begin
      Inc(I);
      if (I >= Length(Args)) then
        raise Exception.Create('--time-sig requires a value like 7/8');
      if not TryParseMeter(Args[I], Result.MeterNum, Result.MeterDen) then
        raise Exception.CreateFmt('Invalid --time-sig "%s": expected num/den, e.g. 7/8 or 3/4', [Args[I]]);
      W := MeterProblem(Result.MeterNum, Result.MeterDen);
      if W <> '' then
        raise Exception.CreateFmt('Invalid --time-sig "%s": %s', [Args[I], W]);
    end
    else if (Args[I] = '--strict-meter') then
    begin
      Result.StrictMeter := True;
    end
    else if (Args[I] = '--segment') then
    begin
      Inc(I);
      if (I >= Length(Args)) then
        raise Exception.Create('--segment requires a value like bridge:4:96:7/8');
      SetLength(Result.Sections, Length(Result.Sections) + 1);
      Result.Sections[High(Result.Sections)] := ParseSegmentSpec(Args[I]);
    end
    else if (Args[I] = '--swing') then
    begin
      Inc(I);
      if (I >= Length(Args)) then
        raise Exception.Create('--swing requires a value');
      Val(Args[I], Result.Swing, ValCode);
      if ValCode <> 0 then
        raise Exception.CreateFmt('--swing needs a number between 0 and 1, got "%s"', [Args[I]]);
      if (Result.Swing < 0.0) or (Result.Swing > 1.0) then
        raise Exception.Create('--swing must be between 0 and 1');
    end
    else if (Args[I] = '--drummer') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.Drummer := LowerCase(Args[I])
      else raise Exception.Create('--drummer requires a value');
    end
    else if (Args[I] = '--output') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.OutputFile := Args[I]
      else raise Exception.Create('--output requires a value');
    end
    else if (Args[I] = '--mapping') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.Mapping := LowerCase(Args[I])
      else raise Exception.Create('--mapping requires a value');
    end
    else if (Args[I] = '--structure') or (Args[I] = '--sidecar') then

    begin

      { --sidecar is the older name for the same JSON file }

      Name := Args[I];

      Inc(I);

      if (I >= Length(Args)) then
        raise Exception.CreateFmt('%s requires a file name', [Name]);

      if (Result.StructureFile <> '') and (Result.StructureFile <> Args[I]) then
        raise Exception.Create('--structure and --sidecar name different files; give only one');
      Result.StructureFile := Args[I];

      Result.SidecarFile := Args[I];
    end
    else if (Args[I] = '--song-map') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.SongMapFile := Args[I]
      else raise Exception.Create('--song-map requires a value');
    end
    else if (Args[I] = '--write-timeline') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.WriteTimelinePath := Args[I]
      else raise Exception.Create('--write-timeline requires a value');
    end
    else if (Args[I] = '--preset-only') then
    begin
      Result.PresetOnly := True;
    end
    else if (Args[I] = '--reaper') then
      Result.ExportReaper := True
    else if (Args[I] = '--ardour') then
      Result.ExportArdour := True
    else if (Args[I] = '--song') then
    begin
      { --song flag from regen_all.bat - implies 'generate' command }
      Result.IsSongCommand := True;
    end
    else if (Args[I] = '--list') then
    begin
      Inc(I);
      if (I < Length(Args)) then Result.ListType := LowerCase(Args[I])
      else raise Exception.Create('--list requires a value');
      Result.Command := 'list';
    end
    else if (Args[I] = '--help') or (Args[I] = '-h') then
    begin
      ShowUsage;
      Halt(0);
    end
    else if (Args[I] = 'generate') or (Args[I] = 'pattern') then
    begin
      Result.Command := Args[I];
    end
    else if (Args[I] = 'info') then
    begin
      Result.Command := 'info';
    end
    else if (Args[I] = 'list') then
    begin
      Result.Command := 'list';
      { Check for list type as next arg }
      Inc(I);
      if (I < Length(Args)) then
        Result.ListType := LowerCase(Args[I]);
      if (I >= Length(Args)) then
        raise Exception.Create('list requires a list type');
    end
    else if (Args[I] = 'reaper') then
    begin
      Result.Command := 'reaper';
      { Check for subcommand }
      Inc(I);
      if (I < Length(Args)) then
        Result.SubCommand := LowerCase(Args[I]);
      if (I >= Length(Args)) then
        raise Exception.Create('reaper requires a sub-command');
    end
    else if (Args[I] = 'ardour') then
    begin
      Result.Command := 'ardour';
      { Check for subcommand }
      Inc(I);
      if (I < Length(Args)) then
        Result.SubCommand := LowerCase(Args[I]);
      if (I >= Length(Args)) then
        raise Exception.Create('ardour requires a sub-command');
    end;

    Inc(I);
  end;

  { If --song was used but no command specified, default to 'generate' }

  if Result.IsSongCommand and (Result.Command = '') then

    Result.Command := 'generate';


  { A structure file supplies the sections, and genre/style/tempo where the
    command line did not. Only the commands that build a song need it. }
  if (Result.StructureFile <> '') and
     ((Result.Command = 'generate') or (Result.Command = 'reaper') or
      (Result.Command = 'ardour')) then

  begin
    if Length(Result.Sections) > 0 then
      raise Exception.Create('--section and --segment cannot be combined with --structure; put all sections in one place');
    Info := LoadStructureFile(Result.StructureFile);
    for W in Info.Warnings do
      Writeln('[Warning] ', Result.StructureFile, ': ', W);

    Result.Sections := Info.Sections;
    if (Result.Genre = '') then Result.Genre := Info.Genre;

    if (Result.Style = '') then Result.Style := Info.Style;
    if (Result.Tempo = 0) then Result.Tempo := Info.Tempo;
    if (Result.MeterNum = 0) then
    begin
      Result.MeterNum := Info.MeterNum;
      Result.MeterDen := Info.MeterDen;
    end;

  end;
end;

constructor TCLIInterface.Create;
begin
  FGenerator := TDrumGenerator.Create;
end;

destructor TCLIInterface.Destroy;
begin
  FGenerator.Free;
  inherited Destroy;
end;

procedure TCLIInterface.WriteReaperProject(ASong: TSong; const AMidiFile: string);
var
  Bridge: TReaperBridge;
begin
  { The project is written next to the MIDI file, with the extension .rpp. }
  Bridge := TReaperBridge.Create;
  try
    if Bridge.CreateFromSong(ASong, AMidiFile) then
      Writeln('REAPER project exported to:', ChangeFileExt(AMidiFile, '.rpp'))
    else
      Writeln('[Warning] Failed to create REAPER project from song sections');
  finally
    Bridge.Free;
  end;
end;

procedure TCLIInterface.WriteArdourSession(ASong: TSong; const AMidiFile, ASessionDir: string);
var
  Bridge: TArdourBridge;
begin
  Bridge := TArdourBridge.Create;
  try
    if Bridge.CreateFromSong(ASong, AMidiFile, ASessionDir) then
      Writeln('Ardour session created:', ASessionDir)
    else
      Writeln('[Warning] Failed to create Ardour session');
  finally
    Bridge.Free;
  end;
end;

procedure TCLIInterface.PrintConfigWarnings;
var
  I: Integer;
begin
  { Mistakes in the user's groove, fill, section and defaults files. The
    engine ignored the file and used what is built in. }
  for I := 0 to ConfigWarnings.Count - 1 do
    Writeln('[Warning] ', ConfigWarnings[I]);
  ConfigWarnings.Clear;
end;

procedure TCLIInterface.PrintGeneratorWarnings;

var
  I: Integer;

begin

  for I := 0 to FGenerator.LastWarnings.Count - 1 do

    Writeln('[Warning] ', FGenerator.LastWarnings[I]);

end;


procedure TCLIInterface.ShowUsage;

begin
  Writeln('ChameleonDrummer - Dynamic MIDI Drumming System');
  Writeln;
  Writeln('Usage: chameleondrummer <command> [options]');
  Writeln;
  Writeln('Commands:');
  Writeln('  generate  Generate a complete song (multi-bar pattern)');
  Writeln('  pattern   Generate a single 1-4 bar pattern');
  Writeln('  list      List available genres, styles, or drummers');
  Writeln('  info      Show system information');
  Writeln('  reaper    Create a REAPER project (sub-command: export)');
  Writeln('  ardour    Create an Ardour session (sub-command: export)');
  Writeln;
  Writeln('Options:');
  Writeln('  --genre <name>       Genre (e.g., metal, rock, jazz, funk)');
  Writeln('  --style <name>       Style within genre (e.g., heavy, classic, swing)');
  Writeln('  --tempo <bpm>        Tempo in BPM (default: genre/style value)');
  Writeln('  --complexity <0-1>   Pattern complexity (default: 0.5)');
  Writeln('  --humanization <0-1> Humanization intensity (default: 0.3)');
  Writeln('  --swing <0-1>        Swing feel: 0 straight (default), 0.67 classic 2:1, 1 = 3:1');
  Writeln('  --time-sig <n/d>     Meter of the song, e.g. 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 (default 4/4)');
  Writeln('  --strict-meter       Only use patterns matching --time-sig');
  Writeln('  --segment <n:bars:bpm:n/d>  A section with its own tempo and meter, e.g. bridge:4:96:7/8');
  Writeln('                       (bpm - keeps the song tempo); mix freely with --section');
  Writeln('  --section <n:bars[@bpm]>  Song structure; repeat once per section, in order');
  Writeln('                       e.g. --section intro:4 --section verse:8 --section chorus:8@140');
  Writeln('                       (without --section the genre default structure is used)');
  Writeln('  --drummer <name>     Drummer style (e.g., bonham, peart, carey)');
  Writeln('  --output <file>      Output MIDI file path');
  Writeln('  --reaper, --ardour   With generate: also write <output>.rpp / the <output>.ardour session');
  Writeln('  --mapping <name>     Keymap to use: gm (default), ad2, ezd3, xg');
  Writeln('  --structure <file>   Song structure from a JSON file (sections with bars, tempo,');
  Writeln('                       complexity; optional genre, style, tempo). Command-line');
  Writeln('                       genre/style/tempo win over the file. Not with --section.');

  Writeln('  --sidecar <file>     Same as --structure (the REAPER sidecar format works)');
  Writeln('  --song-map <file>    Read song map JSON for per-bar tempo/meter');
  Writeln('  --write-timeline     Write timeline JSON after generation');
  Writeln('  --list <type>        List: genres, styles, drummers');
  Writeln;
  Writeln('Examples:');
  Writeln('  chameleondrummer generate --genre metal --style doom --tempo 75');
  Writeln('  chameleondrummer generate --genre rock --style classic --drummer bonham --output rock.mid');
  Writeln('  chameleondrummer list genres');
  Writeln('  chameleondrummer list drummers');
end;

procedure TCLIInterface.HandleGenerate(const Args: TCLIArgs);
var
  Song: TSong;
  DrumKit: TDrumKit;
  OutputFile: string;
  DrummerName: String;
begin
  if (Args.Genre = '') then
    raise Exception.Create('--genre is required for generate command');

  { Load keymap from JSON files dynamically via factory method }
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  { Use drummer if specified, otherwise empty string (default) }
  DrummerName := Args.Drummer;

  { Create song with all parameters wired through to ComposerV2 }
  Song := FGenerator.CreateSong(
    Args.Genre,
    Args.Style,
    Args.Tempo,
    Args.Sections, // AStructure - from --section, nil = genre default
    DrumKit, // Pass pre-loaded keymap
    DrummerName, // ADrummer - pass directly to composer
    Args.Complexity,  // AComplexity - pattern complexity from CLI
    0.6,              // ADynamics - default dynamics
    Args.Humanization, // AHumanization - humanization intensity from CLI
    Args.Swing,
    SongMeterNum(Args), SongMeterDen(Args),
    Args.StrictMeter  // AStrictMeter - only use patterns matching --time-sig
  );

  PrintGeneratorWarnings;

  try
    { Save MIDI output and optionally timeline JSON }
    if (Args.OutputFile = '') then
      OutputFile := Format('%s_%s_%s.mid', [Args.Genre, Args.Style, Args.Mapping])
    else
      OutputFile := Args.OutputFile;

    FGenerator.SaveSongMidi(Song, OutputFile);
    Writeln(Format('Song generated: %s (mapping: %s)', [OutputFile, Args.Mapping]));
    if Length(Args.Sections) > 0 then
      Writeln(Format('Structure   : %s', [DescribeStructure(Args.Sections)]));
    if Args.MeterNum > 0 then
      Writeln(Format('Time sig    : %s', [MeterName(Args.MeterNum, Args.MeterDen)]));

    { The same song goes into the project and the session, so all three agree. }
    if Args.ExportReaper then
      WriteReaperProject(Song, OutputFile);
    if Args.ExportArdour then
      WriteArdourSession(Song, OutputFile, ChangeFileExt(OutputFile, '.ardour'));

    { Write timeline JSON if requested }
    if (Args.WriteTimelinePath <> '') then
      Writeln(Format('Timeline   : %s', [Args.WriteTimelinePath]));
  finally
    Song.Free;
  end;
end;

procedure TCLIInterface.HandlePattern(const Args: TCLIArgs);
var
  Pattern: TPattern;
  DrumKit: TDrumKit;
  OutputFile: string;
  Tempo: Integer;
begin
  if (Args.Genre = '') then
    raise Exception.Create('--genre is required for pattern command');

  { Load keymap from JSON files dynamically via factory method }
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);
  FGenerator.DrumKit := DrumKit;

  Pattern := FGenerator.GeneratePattern(
    Args.Genre, 'verse', DrumKit, Args.Style,
    SongMeterNum(Args), SongMeterDen(Args),
    Args.StrictMeter);
  try
    if (Args.OutputFile = '') then
      OutputFile := Format('%s_%s_pattern.mid', [Args.Genre, Args.Style])
    else
      OutputFile := Args.OutputFile;

    Tempo := Args.Tempo;
    if Tempo = 0 then
      Tempo := GetDefaultBpm(Args.Genre, Args.Style);
    FGenerator.SavePatternMidi(Pattern, OutputFile, Tempo);
    Writeln(Format('Pattern generated: %s', [OutputFile]));
    if Args.MeterNum > 0 then
      Writeln(Format('Time sig    : %s', [MeterName(Args.MeterNum, Args.MeterDen)]));
  finally
    Pattern.Free;
  end;
end;

procedure TCLIInterface.HandleList(const Args: TCLIArgs);
var
  Genres, Styles, Drummers: specialize TArray<String>;
  I: Integer;
begin
  case Args.ListType of
    'genres':
      begin
        Writeln('Available genres:');
        Genres := GetPluginRegistry.GetAvailableGenres;
        for I := 0 to Length(Genres) - 1 do
          Writeln(Format('  - %s', [Genres[I]]));
      end;
    'styles':
      begin
        if (Args.Genre = '') then
        begin
          Writeln('[Error] --genre is required for styles list');
          Exit;
        end;
        Styles := GetPluginRegistry.GetStylesForGenre(Args.Genre);
        Writeln(Format('Styles for genre "%s":', [Args.Genre]));
        for I := 0 to Length(Styles) - 1 do
          Writeln(Format('  - %s', [Styles[I]]));
      end;
    'drummers':
      begin
        Writeln('Available drummers:');
        Drummers := GetPluginRegistry.GetAvailableDrummers;
        for I := 0 to Length(Drummers) - 1 do
          Writeln(Format('  - %s', [Drummers[I]]));
      end;
  else
    Writeln('[Error] Unknown list type. Use: genres, styles, drummers');
  end;
end;

procedure TCLIInterface.HandleInfo;
begin
  Writeln('MIDI Drums Generator - Pascal Translation');
  Writeln('========================================');
  Writeln(Format('Available genres: %d', [Length(GetPluginRegistry.GetAvailableGenres)]));
  Writeln(Format('Available drummers: %d', [Length(GetPluginRegistry.GetAvailableDrummers)]));
  Writeln('Keymap directory: midi_drums/mappings/');
end;

procedure TCLIInterface.HandleReaperExport(const Args: TCLIArgs);
var
  Song: TSong;
  DrumKit: TDrumKit;
  MidiFile, RppFile: string;
begin
  if (Args.Genre = '') then
    raise Exception.Create('--genre is required for reaper export');

  { Load keymap }
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  { Generate song with drummer parameter }
  Song := FGenerator.CreateSong(
    Args.Genre,
    Args.Style,
    Args.Tempo,
    Args.Sections, // AStructure - from --section, nil = genre default
    DrumKit,
    Args.Drummer,
    Args.Complexity,   // AComplexity
    0.6,               // ADynamics
    Args.Humanization, // AHumanization
    Args.Swing,
    SongMeterNum(Args), SongMeterDen(Args)  // ASwing
  );
  PrintGeneratorWarnings;


  { Determine output paths }
  if (Args.OutputFile = '') then
    RppFile := Format('%s_%s.rpp', [Args.Genre, Args.Style])
  else
    RppFile := Args.OutputFile;
  MidiFile := ChangeFileExt(RppFile, '.mid');

  try
    { Save MIDI first }
    FGenerator.SaveSongMidi(Song, MidiFile);

    { Create REAPER project from song sections — use CreateFromSong to pass actual data }
    WriteReaperProject(Song, MidiFile);
  finally
    Song.Free;
  end;
end;

procedure TCLIInterface.HandleArdourExport(const Args: TCLIArgs);
var
  Song: TSong;
  DrumKit: TDrumKit;
  MidiFile, SessionDir: string;
begin
  if (Args.Genre = '') then
    raise Exception.Create('--genre is required for ardour export');

  { Load keymap }
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  { Generate song with drummer parameter }
  Song := FGenerator.CreateSong(
    Args.Genre,
    Args.Style,
    Args.Tempo,
    Args.Sections, // AStructure - from --section, nil = genre default
    DrumKit,
    Args.Drummer,
    Args.Complexity,  // AComplexity - pattern complexity from CLI
    0.6,               // ADynamics
    Args.Humanization, // AHumanization
    Args.Swing,
    SongMeterNum(Args), SongMeterDen(Args)  // ASwing
  );

  PrintGeneratorWarnings;

  try

    { The output is an Ardour session directory; the MIDI file sits next to
      it, exactly like the REAPER exporter lays the MIDI next to the .rpp. }
    if (Args.OutputFile = '') then
      SessionDir := Format('%s_%s.ardour', [Args.Genre, Args.Style])
    else
      SessionDir := Args.OutputFile;
    MidiFile := ChangeFileExt(SessionDir, '.mid');

    FGenerator.SaveSongMidi(Song, MidiFile);

    { Build the session inside Ardour via its standalone Lua interpreter. }
    WriteArdourSession(Song, MidiFile, SessionDir);
  finally
    Song.Free;
  end;
end;

function TCLIInterface.Run(Argc: Integer; const Argv: specialize TArray<String>): Integer;
var
  Args: TCLIArgs;
begin
  FillChar(Args, SizeOf(Args), 0);

  try
    Args := ParseArgs(Argv);

    if (Args.Command = '') then
    begin
      ShowUsage;
      ExitCode := 1;
      Result := -1;
      Exit;
    end;

    case Args.Command of
      'generate': HandleGenerate(Args);
      'pattern': HandlePattern(Args);
      'list': HandleList(Args);
      'info': HandleInfo;
      'reaper':
        if LowerCase(Args.SubCommand) = 'export' then
          HandleReaperExport(Args)
        else
        begin
          Writeln('[Error] Unknown reaper sub-command: ', Args.SubCommand);
          ShowUsage;
          ExitCode := 1;
          Result := -1;
          Exit;
        end;
      'ardour':
        if LowerCase(Args.SubCommand) = 'export' then
          HandleArdourExport(Args)
        else
        begin
          Writeln('[Error] Unknown ardour sub-command: ', Args.SubCommand);
          ShowUsage;
          ExitCode := 1;
          Result := -1;
          Exit;
        end;
    else
      Writeln('[Error] Unknown command: ', Args.Command);
      ShowUsage;
      ExitCode := 1;
      Result := -1;
      Exit;
    end;

    PrintConfigWarnings;
    Result := 0;
  except
    on E: Exception do
    begin
      PrintConfigWarnings;
      Writeln('[Error] ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
      Result := -2;
    end;
  end;
end;

end.