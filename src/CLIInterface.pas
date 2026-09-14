unit CLIInterface;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrumGenerator, ComposerV2,
  PluginRegistry, Kit, midi_engine;

// ============================================================================
// TCLIInterface â€” command-line interface for MIDI Drums Generator
// ============================================================================
type
  TCLIArgs = record
    Command: String; // 'generate', 'pattern', 'list', 'info'
    Genre: String;
    Style: String;
    Tempo: Integer;
    Complexity: Double;
    Humanization: Double;
    Drummer: String;
    OutputFile: String;
    Mapping: String; // Keymap filename stem (gm, ad2, ezd3, etc.)
    SidecarFile: String;
    SongMapFile: String;
    WriteTimeline: String;
    ListType: String; // 'genres', 'styles', 'drummers'
  end;

type
  TCLIInterface = class
  private
    FGenerator: TDrumGenerator;
    FPluginRegistry: TPluginRegistry;
    function ParseArgs(const Args: specialize TArray<String>): TCLIArgs;
    procedure HandleGenerate(const Args: TCLIArgs);
    procedure HandlePattern(const Args: TCLIArgs);
    procedure HandleList(const Args: TCLIArgs);
    procedure HandleInfo;
    procedure ShowUsage;
  public
    constructor Create;
    destructor Destroy; override;

    function Run(Argc: Integer; const Argv: specialize TArray<String>): Integer;
  end;

implementation

function TCLIInterface.ParseArgs(const Args: specialize TArray<String>): TCLIArgs;
var
  I: Integer;begin
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
      if (I <= Length(Args)) then Result.WriteTimeline := Args[I];
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
    end;

    Inc(I);
  end;
end;

constructor TCLIInterface.Create;
begin
  FGenerator := TDrumGenerator.Create;
  FPluginRegistry := TPluginRegistry.Create;
end;

destructor TCLIInterface.Destroy;
begin
  FPluginRegistry.Free;
  FGenerator.Free;
  inherited Destroy;
end;

procedure TCLIInterface.ShowUsage;
begin
  Writeln('MIDI Drums Generator - Dynamic MIDI Drum Pattern System');
  Writeln;
  Writeln('Usage: pascal_midi_drums <command> [options]');
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
  Writeln('  pascal_midi_drums generate --genre metal --style doom --tempo 75');
  Writeln('  pascal_midi_drums generate --genre rock --style classic --drummer bonham --output rock.mid');
  Writeln('  pascal_midi_drums list genres');
  Writeln('  pascal_midi_drums list drummers');
end;

procedure TCLIInterface.HandleGenerate(const Args: TCLIArgs);
var
  Song: TSong;
  DrumKit: TDrumKit;
  OutputFile: string;
begin
  if (Args.Genre = '') then
  begin
    Writeln('[Error] --genre is required for generate command');
    Exit;
  end;

  // Load keymap from JSON files dynamically via factory method
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  Song := FGenerator.CreateSong(
    Args.Genre,
    Args.Style,
    Args.Tempo,
    nil,   // AStructure - use genre default
    DrumKit // Pass pre-loaded keymap
  );

  // Save MIDI output
  if (Args.OutputFile = '') then
    OutputFile := Format('%s_%s_%s.mid', [Args.Genre, Args.Style, Args.Mapping])
  else
    OutputFile := Args.OutputFile;

  FGenerator.SaveSongMidi(Song, OutputFile);
  Writeln(Format('Song generated: %s (mapping: %s)', [OutputFile, Args.Mapping]));
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

  // Load keymap from JSON files dynamically via factory method
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
        Genres := FPluginRegistry.GetAvailableGenres;
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
        Styles := FPluginRegistry.GetStylesForGenre(Args.Genre);
        Writeln(Format('Styles for genre "%s":', [Args.Genre]));
        for I := 0 to Length(Styles) - 1 do
          Writeln(Format('  - %s', [Styles[I]]));
      end;
    'drummers':
      begin
        Writeln('Available drummers:');
        Drummers := FPluginRegistry.GetAvailableDrummers;
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
  Writeln(Format('Available genres: %d', [Length(FPluginRegistry.GetAvailableGenres)]));
  Writeln(Format('Available drummers: %d', [Length(FPluginRegistry.GetAvailableDrummers)]));
  Writeln('Keymap directory: midi_drums/mappings/');
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
