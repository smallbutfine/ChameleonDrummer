unit DrumGeneratorAPI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrumGenerator, ComposerV2,
  PluginRegistry, Kit;

// ============================================================================
// TDrumGeneratorAPI â€” high-level API for MIDI Drums Generator
// ============================================================================
type
  TBatchGenerationSpec = record
    Genre: String;
    Style: String;
    Tempo: Integer;
  end;

  TDrumGeneratorAPI = class
  private
    FGenerator: TDrumGenerator;
    FKeymapName: string;
    function GetPluginRegistry: TPluginRegistry;
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
    function GetAvailableMappings: specialize TArray<String>;
    function LoadKeymap(const AMappingName: String): TDrumKit;

    // Listing methods
    function ListGenres: specialize TArray<String>;
    function ListStyles(const AGenre: String): specialize TArray<String>;
    function ListDrummers: specialize TArray<String>;

    // Batch generation
    function BatchGenerate(const ASpecs: specialize TArray<TBatchGenerationSpec>;
      const AOutputDir: String): specialize TArray<String>;

    property Generator: TDrumGenerator read FGenerator;
    property PluginRegistry: TPluginRegistry read GetPluginRegistry;
  end;

implementation

constructor TDrumGeneratorAPI.Create;
begin
  FGenerator := TDrumGenerator.Create;
  FKeymapName := 'gm';
end;

destructor TDrumGeneratorAPI.Destroy;
begin
  FGenerator.Free;
  inherited Destroy;
end;

function TDrumGeneratorAPI.GetPluginRegistry: TPluginRegistry;
begin
  Result := FGenerator.PluginManager.Registry;
end;

function TDrumGeneratorAPI.CreateSong(const AGenre, AStyle: String; ATempo: Integer = 120;
  const ADrummer: String = ''): TSong;
begin
  Result := FGenerator.CreateSong(AGenre, AStyle, ATempo, nil, nil, ADrummer);
end;

function TDrumGeneratorAPI.MetalSong(const AStyle: String; ATempo: Integer = 155;
  AComplexity: Double = 0.7): TSong;
begin
  Result := CreateSong('metal', AStyle, ATempo);
end;

function TDrumGeneratorAPI.GeneratePattern(const AGenre, AStyle: String): TPattern;
begin
  Result := FGenerator.GeneratePattern(AGenre, AStyle, FGenerator.DrumKit);
end;

procedure TDrumGeneratorAPI.SaveAsMIDI(ASong: TSong; const AFileName: String);
begin
  FGenerator.SaveSongMidi(ASong, AFileName);
end;

procedure TDrumGeneratorAPI.SavePatternAsMIDI(APattern: TPattern; const AFileName: String;
  ATempo: Integer = 120);
begin
  FGenerator.SavePatternMidi(APattern, AFileName, ATempo);
end;

function TDrumGeneratorAPI.GetAvailableMappings: specialize TArray<String>;
var
  Dir, Filename: String;
  SearchRec: TSearchRec;
begin
  Result := nil;
  Dir := ExtractFilePath(ParamStr(0)) + 'mappings' + DirectorySeparator;
  if not DirectoryExists(Dir) then Exit;

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
  FGenerator.DrumKit := TDrumKit.FromKeymapName(AMappingName);
  FKeymapName := AMappingName;
  Result := FGenerator.DrumKit;
end;

function TDrumGeneratorAPI.ListGenres: specialize TArray<String>;
begin
  Result := PluginRegistry.GetAvailableGenres;
end;

function TDrumGeneratorAPI.ListStyles(const AGenre: String): specialize TArray<String>;
begin
  Result := PluginRegistry.GetStylesForGenre(AGenre);
end;

function TDrumGeneratorAPI.ListDrummers: specialize TArray<String>;
begin
  Result := PluginRegistry.GetAvailableDrummers;
end;

function TDrumGeneratorAPI.BatchGenerate(const ASpecs: specialize TArray<TBatchGenerationSpec>;
  const AOutputDir: String): specialize TArray<String>;
var
  I: Integer;
  Song: TSong;
  OutputPath: String;
begin
  if not ForceDirectories(AOutputDir) then
    raise Exception.CreateFmt('Could not create output directory: %s', [AOutputDir]);

  Result := nil;
  SetLength(Result, Length(ASpecs));

  for I := 0 to Length(ASpecs) - 1 do
  begin
    Song := CreateSong(ASpecs[I].Genre, ASpecs[I].Style, ASpecs[I].Tempo);
    try
      OutputPath := IncludeTrailingPathDelimiter(AOutputDir) +
        Format('%s_%s_%d.mid', [ASpecs[I].Genre, ASpecs[I].Style, ASpecs[I].Tempo]);
      SaveAsMIDI(Song, OutputPath);
      Result[I] := OutputPath;
    finally
      Song.Free;
    end;
  end;
end;

end.
