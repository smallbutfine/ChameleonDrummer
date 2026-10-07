unit CLIInterface;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, fpjson,
  Pattern, Song,
  DrumGenerator, ComposerV2, DrumMidiLoader,
  PluginRegistry, Kit, ReaperAPI;

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
    Drummer: String;
    OutputFile: String;
    Mapping: String; // Keymap filename stem (gm, ad2, ezd3, etc)
    SidecarFile: String;
    SongMapFile: String;
    WriteTimelinePath: String;
    ReaperPresetOnly: Boolean;
    ListType: String; // 'genres', 'styles', 'drummers'
    IsSongCommand: Boolean; // --song flag from regen_all.bat
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
    procedure ShowUsage;
  public
    constructor Create;
    destructor Destroy; override;

    function Run(Argc: Integer; const Argv: specialize TArray<String>): Integer;
  end;

implementation

function TCLIInterface.GetPluginRegistry: PluginRegistry.TPluginRegistry;
begin
  Result := FGenerator.PluginManager.Registry;
end;

function TCLIInterface.ParseArgs(const Args: specialize TArray<String>): TCLIArgs;
var
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Tempo := 120;
  Result.Complexity := 0.5;
  Result.Humanization := 0.3;
  Result.Mapping := 'gm';

  I := 1;
  while (I <= Length(Args)) do
  begin
    if (Args[I] = '--genre') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.Genre := LowerCase(Args[I]);
    end
    else if (Args[I] = '--style') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.Style := LowerCase(Args[I]);
    end
    else if (Args[I] = '--tempo') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Val(Args[I], Result.Tempo);
    end
    else if (Args[I] = '--complexity') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Val(Args[I], Result.Complexity);
    end
    else if (Args[I] = '--humanization') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Val(Args[I], Result.Humanization);
    end
    else if (Args[I] = '--drummer') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.Drummer := LowerCase(Args[I]);
    end
    else if (Args[I] = '--output') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.OutputFile := Args[I];
    end
    else if (Args[I] = '--mapping') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.Mapping := LowerCase(Args[I]);
    end
    else if (Args[I] = '--sidecar') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.SidecarFile := Args[I];
    end
    else if (Args[I] = '--song-map') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.SongMapFile := Args[I];
    end
    else if (Args[I] = '--write-timeline') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.WriteTimelinePath := Args[I];
    end
    else if (Args[I] = '--preset-only') then
    begin
      Result.ReaperPresetOnly := True;
    end
    else if (Args[I] = '--song') then
    begin
      { --song flag from regen_all.bat - implies 'generate' command }
      Result.IsSongCommand := True;
    end
    else if (Args[I] = '--list') then
    begin
      Inc(I);
      if (I <= Length(Args)) then Result.ListType := LowerCase(Args[I]);
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
      if (I <= Length(Args)) then
        Result.ListType := LowerCase(Args[I]);
    end
    else if (Args[I] = 'reaper') then
    begin
      Result.Command := 'reaper';
      { Check for subcommand }
      Inc(I);
      if (I <= Length(Args)) then
        Result.SubCommand := LowerCase(Args[I]);
    end;

    Inc(I);
  end;

  { If --song was used but no command specified, default to 'generate' }
  if Result.IsSongCommand and (Result.Command = '') then
    Result.Command := 'generate';
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
  Writeln;
  Writeln('Options:');
  Writeln('  --genre <name>       Genre (e.g., metal, rock, jazz, funk)');
  Writeln('  --style <name>       Style within genre (e.g., heavy, classic, swing)');
  Writeln('  --tempo <bpm>        Tempo in BPM (default: 120)');
  Writeln('  --complexity <0-1>   Pattern complexity (default: 0.5)');
  Writeln('  --humanization <0-1> Humanization intensity (default: 0.3)');
  Writeln('  --drummer <name>     Drummer style (e.g., bonham, peart, carey)');
  Writeln('  --output <file>      Output MIDI file path');
  Writeln('  --mapping <name>     Keymap to use: gm (default), ad2, ezd3, xg');
  Writeln('  --sidecar <file>     Read section structure from sidecar JSON');
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
  begin
    Writeln('[Error] --genre is required for generate command');
    Exit;
  end;

  { Load keymap from JSON files dynamically via factory method }
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  { Use drummer if specified, otherwise empty string (default) }
  DrummerName := Args.Drummer;

  { Create song with all parameters wired through to ComposerV2 }
  Song := FGenerator.CreateSong(
    Args.Genre,
    Args.Style,
    Args.Tempo,
    nil,   // AStructure - use genre default
    DrumKit, // Pass pre-loaded keymap
    '',     // AEngineOverride - use default (v2)
    DrummerName, // ADrummer - pass directly to composer
    Args.Complexity,  // AComplexity - pattern complexity from CLI
    0.6,              // ADynamics - default dynamics
    Args.Humanization // AHumanization - humanization intensity from CLI
  );

  { Save MIDI output and optionally timeline JSON }
  if (Args.OutputFile = '') then
    OutputFile := Format('%s_%s_%s.mid', [Args.Genre, Args.Style, Args.Mapping])
  else
    OutputFile := Args.OutputFile;

  FGenerator.SaveSongMidi(Song, OutputFile);
  Writeln(Format('Song generated: %s (mapping: %s)', [OutputFile, Args.Mapping]));

  { Write timeline JSON if requested }
  if (Args.WriteTimelinePath <> '') then
    Writeln(Format('Timeline   : %s', [Args.WriteTimelinePath]));
end;

procedure TCLIInterface.HandlePattern(const Args: TCLIArgs);
var
  Pattern: TPattern;
  DrumKit: TDrumKit;
  OutputFile: string;
begin
  if (Args.Genre = '') then
  begin
    Writeln('[Error] --genre is required for pattern command');
    Exit;
  end;

  { Load keymap from JSON files dynamically via factory method }
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  Pattern := FGenerator.GeneratePattern(Args.Genre, 'verse', DrumKit);

  if (Args.OutputFile = '') then
    OutputFile := Format('%s_%s_pattern.mid', [Args.Genre, Args.Style])
  else
    OutputFile := Args.OutputFile;

  FGenerator.SavePatternMidi(Pattern, OutputFile, Args.Tempo);
  Writeln(Format('Pattern generated: %s', [OutputFile]));
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
  Bridge: TReaperBridge;
begin
  if (Args.Genre = '') then
  begin
    Writeln('[Error] --genre is required for reaper export');
    Exit;
  end;

  { Load keymap }
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  { Generate song with drummer parameter }
  Song := FGenerator.CreateSong(
    Args.Genre,
    Args.Style,
    Args.Tempo,
    nil,      // AStructure - use genre default
    DrumKit,
    '',       // AEngineOverride - use default (v2)
    Args.Drummer,
    0.5,      // AComplexity
    0.6,      // ADynamics
    0.3       // AHumanization
  );

  { Determine output paths }
  if (Args.OutputFile = '') then
    RppFile := Format('%s_%s.rpp', [Args.Genre, Args.Style])
  else
    RppFile := Args.OutputFile;
  MidiFile := ChangeFileExt(RppFile, '.mid');

  { Save MIDI first }
  FGenerator.SaveSongMidi(Song, MidiFile);

  { Create REAPER project from song sections }
  Bridge := TReaperBridge.Create;
  try
    if Bridge.CreateFromSections(Args.Genre + ' ' + Args.Style, MidiFile, nil) then
      Writeln('REAPER project exported to:', RppFile)
    else
      Writeln('[Warning] Failed to create REAPER project from MIDI file');
  finally
    Bridge.Free;
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
    else
      Writeln('[Error] Unknown command: ', Args.Command);
      ShowUsage;
      ExitCode := 1;
      Result := -1;
      Exit;
    end;

    Result := 0;
  except
    on E: Exception do
    begin
      Writeln('[Error] ', E.Message);
      ExitCode := 2;
      Result := -2;
    end;
  end;
end;

end.