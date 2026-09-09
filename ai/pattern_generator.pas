unit AIPatternGenerator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, JSON, Generics.Collections,
  core_models_pattern, core_models_song,
  generation_engines_drum_generator, ai_backends;

// ============================================================================
// TAIGenerationRequest — Request parameters for AI pattern generation
// ============================================================================
type
  TAIGenerationRequest = record
    Genre: String;
    Style: String;
    Section: String;
    Description: String;  // Natural language description of desired pattern
    Tempo: Integer;
    Complexity: Double;
    Drummer: String;
  end;

// ============================================================================
// TAIGenerationResult — Result from AI pattern generation
// ============================================================================
type
  TAIGenerationResult = record
    Pattern: TPattern;
    Confidence: Double;
    Description: String;
    Error: String;
  end;

// ============================================================================
// TAIPatternGenerator — High-level AI-driven pattern generation API
// ============================================================================
type
  TAIPatternGenerator = class
  private
    FBackendManager: TAIBackendManager;
    FGenerator: TD rumGenerator;
    function BuildPrompt(const ARequest: TAIGenerationRequest): String;
    function ParseResult(const ARawResponse: String): TAIGenerationResult;
  public
    constructor Create;
    destructor Destroy; override;

    function GeneratePattern(const ARequest: TAIGenerationRequest): TAIGenerationResult;
    function GenerateSongStructure(const AGenre, AStyle: String): TArray<Record>;
    function GetAvailableBackends: Integer;

    property BackendManager: TAIBackendManager read FBackendManager;
    property Generator: TD rumGenerator read FGenerator;
  end;

implementation

constructor TAIPatternGenerator.Create;
begin
  FBackendManager := TAIBackendManager.Create;
  FGenerator := TD rumGenerator.Create;
end;

destructor TAIPatternGenerator.Destroy;
begin
  FBackendManager.Free;
  FGenerator.Free;
  inherited Destroy;
end;

function TAIPatternGenerator.BuildPrompt(const ARequest: TAIGenerationRequest): String;
begin
  Result := Format(
    'Generate a drum pattern for:\n' +
    'Genre: %s\n' +
    'Style: %s\n' +
    'Section: %s\n' +
    'Tempo: %d BPM\n' +
    'Complexity: %.2f\n' +
    'Drummer style: %s\n' +
    'Description: %s\n\n' +
    'Return the pattern in this JSON format:\n' +
    '{\n' +
    '  "bars": <number of bars>,\n' +
    '  "kick_positions": [<time positions>],\n' +
    '  "snare_positions": [<time positions>],\n' +
    '  "hihat_open": [<time positions>],\n' +
    '  "hihat_closed": [<time positions>],\n' +
    '  "crash_positions": [<time positions>],\n' +
    '  "tom_fills": [[bar_index, tom_type, velocities]]\n' +
    '}\n',
    [AGenre, AStyle, ARequest.Section, ARequest.Tempo,
     ARequest.Complexity, ARequest.Drummer, ARequest.Description]
  );
end;

function TAIPatternGenerator.ParseResult(const ARawResponse: String): TAIGenerationResult;
var
  JDoc: TJSONObject;
  JVal: TJSONValue;
begin
  FillChar(Result, SizeOf(Result), 0);

  // Placeholder: parse JSON response from AI backend
  // Would use TJSONObject.ParseJSONValue for actual implementation
  Result.Pattern := nil;
  Result.Confidence := 0.0;
  Result.Description := '';
  Result.Error := 'Not yet implemented';
end;

function TAIPatternGenerator.GeneratePattern(const ARequest: TAIGenerationRequest): TAIGenerationResult;
var
  PromptText: String;
  RawResponse: String;
begin
  // Build prompt from request
  PromptText := BuildPrompt(ARequest);

  // Get response from backend
  RawResponse := FBackendManager.Prompt(PromptText);

  if (RawResponse = '') then
  begin
    Result.Error := 'AI backend returned empty response';
    Result.Confidence := 0.0;
  end
  else
  begin
    // Parse the JSON response into a pattern
    Result := ParseResult(RawResponse);
    Result.Description := ARequest.Description;
  end;
end;

function TAIPatternGenerator.GenerateSongStructure(const AGenre, AStyle: String): TArray<Record>;
begin
  // Return suggested song structure from AI based on genre/style
  // Placeholder — would query AI for creative structure suggestions
  SetLength(Result, 0);
end;

function TAIPatternGenerator.GetAvailableBackends: Integer;
var
  I: Integer;
  Count: Integer;
begin
  Count := 0;
  for I := 0 to FBackendManager.BackendManager.FBackends.Count - 1 do
  begin
    if (FBackendManager.GetBackend(I).Available) then
      Inc(Count);
  end;
  Result := Count;
end;

end.
