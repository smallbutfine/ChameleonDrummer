unit DrumGeneratorAPI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrumGenerator, ComposerV2,
  PluginRegistry, Kit, MIDIEngine;

// ============================================================================
// TDrumGeneratorAPI — high-level API for MIDI Drums Generator
// ============================================================================
type
  TDrumGeneratorAPI = class
  private
    FGenerator: TD rumGenerator;
    FPluginRegistry: TPluginRegistry;
    FMIDIEngine: TMIDIEngine;
  public
    constructor Create;
    destructor Destroy; override;

    // Song generation
    function CreateSong(const AGenre, AStyle: String; ATempo: Integer = 120;
      const ADrummer: String = ''): TSong;

    // Metal-specific convenience method
    function MetalSong(const AStyle: String; ATempo: Integer = 155;
      AComplexity: Double = 0.7): TSong;

    // Pattern generation
    function GeneratePattern(const AGenre, AStyle: String): TPattern;

    // MIDI export
    procedure SaveAsMIDI(ASong: TSong; const AFileName: String);
    procedure SavePatternAsMIDI(APattern: TPattern; const AFileName: String;
      ATempo: Integer = 120);

    // Keymap/Mapping management
    function GetAvailableMappings: TArray<String>;
    function LoadKeymap(const AMappingName: String): TDrumKit;

    // Listing methods
    function ListGenres: TArray<String>;
    function ListStyles(const AGenre: String): TArray<String>;
    function ListDrummers: TArray<String>;

    // Batch generation
    function BatchGenerate(const ASpecs: TArray<TRecord>; const AOutputDir: String): TArray<String>;

    property Generator: TD rumGenerator read FGenerator;
    property PluginRegistry: TPluginRegistry read FPluginRegistry;
    property MIDIEngine: TMIDIEngine read FMIDIEngine;
  end;

implementation

constructor TDrumGeneratorAPI.Create;
begin
  FGenerator := TD rumGenerator.Create;
  FPluginRegistry := TPluginRegistry.Create;
  FMIDIEngine := TMIDIEngine.Create;

  // Auto-discover and register all plugins/keymaps
  FPluginRegistry.AutoDiscoverPlugins;
end;

destructor TDrumGeneratorAPI.Destroy;
begin
  FMIDIEngine.Free;
  FPluginRegistry.Free;
  FGenerator.Free;
  inherited Destroy;
end;

function TDrumGeneratorAPI.CreateSong(const AGenre, AStyle: String; ATempo: Integer = 120;
  const ADrummer: String = ''): TSong;
begin
  // Let the generator create its own DrumKit with default GM keymap.
  Result := FGenerator.CreateSong(AGenre, AStyle, ATempo);
end;

function TDrumGeneratorAPI.MetalSong(const AStyle: String; ATempo: Integer = 155;
  AComplexity: Double = 0.7): TSong;
begin
  Result := CreateSong('metal', AStyle, ATempo);
end;

function TDrumGeneratorAPI.GeneratePattern(const AGenre, AStyle: String): TPattern;
begin
  Result := FGenerator.GeneratePattern(AGenre, 'verse', nil);
end;

procedure TDrumGeneratorAPI.SaveAsMIDI(ASong: TSong; const AFileName: String);
begin
  FGenerator.ExportMIDI(ASong, AFileName);
end;

procedure TDrumGeneratorAPI.SavePatternAsMIDI(APattern: TPattern; const AFileName: String;
  ATempo: Integer = 120);
begin
  FGenerator.ExportPatternMIDI(APattern, AFileName, ATempo);
end;

function TDrumGeneratorAPI.GetAvailableMappings: TArray<String>;
var
  Dir, Filename: String;
  SearchRec: TSearchRec;
begin
  // Scan midi_drums/mappings/ for .json files
  Dir := 'midi_drums/mappings/';
  if not DirectoryExists(Dir) then Exit;

  SetLength(Result, 0);
  if FindFirst(Dir + '*.json', faAnyFile, SearchRec) = 0 then
  try
    repeat
      if (SearchRec.Attr and faDirectory = 0) then
      begin
        Filename := ChangeFileExt(SearchRec.Name, '');
        SetLength(Result, Length(Result) + 1);
        Result[Length(Result) - 1] := Filename;
      end;
    until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

function TDrumGeneratorAPI.LoadKeymap(const AMappingName: String): TDrumKit;
begin
  Result := TDrumKit.Create;
  Result.SetKeymap(AMappingName);
end;

function TDrumGeneratorAPI.ListGenres: TArray<String>;
begin
  Result := FPluginRegistry.GetAvailableGenres;
end;

function TDrumGeneratorAPI.ListStyles(const AGenre: String): TArray<String>;
begin
  Result := FPluginRegistry.GetStylesForGenre(AGenre);
end;

function TDrumGeneratorAPI.ListDrummers: TArray<String>;
begin
  Result := FPluginRegistry.GetAvailableDrummers;
end;

function TDrumGeneratorAPI.BatchGenerate(const ASpecs: TArray<TRecord>; const AOutputDir: String): TArray<String>;
var
  I: Integer;
  Song: TSong;
  OutputPath: String;
begin
  SetLength(Result, Length(ASpecs));

  for I := 0 to Length(ASpecs) - 1 do
  begin
    try
      // Parse spec and generate song
      Song := CreateSong(ASpecs[I].Genre, ASpecs[I].Style, ASpecs[I].Tempo);

      OutputPath := AOutputDir + ChangeFileExt(Format('%s_%s_%d', [ASpecs[I].Genre, ASpecs[I].Style, ASpecs[I].Tempo]), '.mid');
      SaveAsMIDI(Song, OutputPath);
      Result[I] := OutputPath;
    except
      Result[I] := ''; // Mark failed entry
    end;
  end;
end;

end.
