unit CLIInterface;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrumGenerator, ComposerV2,
  PluginRegistry, Kit, MIDIEngine;

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
    FGenerator: TD rumGenerator;
    FPluginRegistry: TPluginRegistry;
    function ParseArgs: TCLIArgs;
    procedure HandleGenerate(const Args: TCLIArgs);
    procedure HandlePattern(const Args: TCLIArgs);
    procedure HandleList(const Args: TCLIArgs);
    procedure HandleInfo;
    procedure ShowUsage;
  public
    constructor Create;
    destructor Destroy; override;

    function Run(Argc: Integer; const Argv: TArray<String>): Integer;
  end;

implementation

constructor TCLIInterface.Create;
begin
  FGenerator := TD rumGenerator.Create;
  FPluginRegistry := TPluginRegistry.Create;
end;

destructor TCLIInterface.Destroy;
begin
  FPluginRegistry.Free;
  FGenerator.Free;
  inherited Destroy;
end;

function TCLIInterface.ParseArgs: TCLIArgs;
var
  I: Integer;
  Args: TCLIArgs;
begin
  FillChar(Args, SizeOf(Args), 0);
  Args.Tempo := 120;
  Args.Complexity := 0.5;
  Args.Humanization := 0.3;
  Args.Mapping := 'gm'; // Default to GM mapping

  I := 1;
  while (I <= Length(Argv)) do
  begin
    if (Argv[I] = '--genre') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.Genre := LowerCase(Argv[I]);
    end
    else if (Argv[I] = '--style') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.Style := LowerCase(Argv[I]);
    end
    else if (Argv[I] = '--tempo') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Val(Argv[I], Args.Tempo);
    end
    else if (Argv[I] = '--complexity') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Val(Argv[I], Args.Complexity);
    end
    else if (Argv[I] = '--humanization') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Val(Argv[I], Args.Humanization);
    end
    else if (Argv[I] = '--drummer') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.Drummer := LowerCase(Argv[I]);
    end
    else if (Argv[I] = '--output') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.OutputFile := Argv[I];
    end
    else if (Argv[I] = '--mapping') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.Mapping := LowerCase(Argv[I]);
    end
    else if (Argv[I] = '--sidecar') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.SidecarFile := Argv[I];
    end
    else if (Argv[I] = '--song-map') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.SongMapFile := Argv[I];
    end
    else if (Argv[I] = '--write-timeline') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.WriteTimeline := Argv[I];
    end
    else if (Argv[I] = '--list') then
    begin
      Inc(I);
      if (I <= Length(Argv)) then Args.ListType := LowerCase(Argv[I]);
      Args.Command := 'list';
    end
    else if (Argv[I] in ['--help', '-h']) then
    begin
      ShowUsage;
      Halt(0);
    end
    else if ((Argv[I] = 'generate') or (Argv[I] = 'pattern')) then
    begin
      Args.Command := Argv[I];
    end
    else if (Argv[I] = 'info') then
    begin
      Args.Command := 'info';
    end;

    Inc(I);
  end;

  Result := Args;
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
    Args.OutputFile := Format('%s_%s_%s.mid', [Args.Genre, Args.Style, Args.Mapping]);

  FGenerator.ExportMIDI(Song, Args.OutputFile);
  Writeln(Format('Song generated: %s (mapping: %s)', [Args.OutputFile, Args.Mapping]));
end;

procedure TCLIInterface.HandlePattern(const Args: TCLIArgs);
var
  Pattern: TPattern;
  DrumKit: TDrumKit;
begin
  if (Args.Genre = '') then
  begin
    Writeln('[Error] --genre is required for pattern command');
    Exit;
  end;

  // Load keymap from JSON files dynamically via factory method
  DrumKit := TDrumKit.FromKeymapName(Args.Mapping);

  Pattern := FGenerator.GeneratePattern(Args.Genre, Args.Style, DrumKit);

  if (Args.OutputFile = '') then
    Args.OutputFile := Format('%s_%s_pattern.mid', [Args.Genre, Args.Style]);

  FGenerator.ExportPatternMIDI(Pattern, Args.OutputFile, Args.Tempo);
  Writeln(Format('Pattern generated: %s', [Args.OutputFile]));
end;

procedure TCLIInterface.HandleList(const Args: TCLIArgs);
var
  Genres, Styles, Drummers: TArray<String>;
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

function TCLIInterface.Run(Argc: Integer; const Argv: TArray<String>): Integer;
var
  Args: TCLIArgs;
begin
  FillChar(Args, SizeOf(Args), 0);

  try
    Args := ParseArgs;

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
