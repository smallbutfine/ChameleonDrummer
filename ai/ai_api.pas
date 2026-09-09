unit AIAPI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  ai_pattern_generator, core_models_song;

// ============================================================================
// TAIAPI — High-level AI generation API entry point
// ============================================================================
type
  TAIAPI = class
  private
    FPatternGenerator: TAIPatternGenerator;
  public
    constructor Create;
    destructor Destroy; override;

    // AI-driven song generation from natural language prompt
    function GenerateSongFromPrompt(const APrompt: String): TSong;

    // Get available AI backends
    function GetAvailableBackends: Integer;

    // Suggest structure for a genre/style
    function SuggestStructure(const AGenre, AStyle: String): TArray<Record>;

    property PatternGenerator: TAIPatternGenerator read FPatternGenerator;
  end;

implementation

constructor TAIAPI.Create;
begin
  FPatternGenerator := TAIPatternGenerator.Create;
end;

destructor TAIAPI.Destroy;
begin
  FPatternGenerator.Free;
  inherited Destroy;
end;

function TAIAPI.GenerateSongFromPrompt(const APrompt: String): TSong;
var
  Genres, Styles: TArray<String>;
  I: Integer;
begin
  // Parse prompt to extract genre/style hints
  // Placeholder: simple keyword matching
  Result := nil;

  for I := 0 to 0 do // Would iterate parsed options
    if (Pos('metal', LowerCase(APrompt)) > 0) then
    begin
      // Use default metal structure as fallback
      Exit; // Would call generator with detected parameters
    end;
end;

function TAIAPI.GetAvailableBackends: Integer;
begin
  Result := FPatternGenerator.GetAvailableBackends;
end;

function TAIAPI.SuggestStructure(const AGenre, AStyle: String): TArray<Record>;
begin
  Result := FPatternGenerator.GenerateSongStructure(AGenre, AStyle);
end;

end.
