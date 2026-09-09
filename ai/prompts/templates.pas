unit AIPromptTemplates;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections;

// ============================================================================
// TAIPromptTemplate — Represents a single AI prompt template with placeholders
// ============================================================================
type
  TAIPromptTemplate = record
    Name: String;
    Template: String;
    Placeholders: TArray<String>;
  end;

// ============================================================================
// AIPROMPTS — All AI prompt templates for pattern generation
// Pre-built templates for common generation scenarios.
// Placeholders use {placeholder_name} syntax (compatible with FPC string formatting).
// ============================================================================
type
  TAIPromptTemplates = record class
  const
    // Pattern generation prompts
    GENERATE_PATTERN := TAIPromptTemplate(
      Name: 'generate_pattern';
      Template: '{system_prompt}'#13#10+
        #13#10+
        '## Request'#13#10+
        'Genre: {genre}'#13#10+
        'Style: {style}'#13#10+
        'Section: {section}'#13#10+
        'Tempo: {tempo} BPM'#13#10+
        'Complexity: {complexity}'#13#10+
        'Drummer: {drummer}'#13#10+
        #13#10+
        '## Instructions'#13#10+
        'Generate a drum pattern matching the request above.'#13#10+
        'Return JSON with these keys:'#13#10+
        '- bars: integer (number of bars)'#13#10+
        '- kick_positions: array of time positions'#13#10+
        '- snare_positions: array of time positions'#13#10+
        '- hihat_open: array of time positions'#13#10+
        '- hihat_closed: array of time positions'#13#10+
        '- crash_positions: array of time positions'#13#10+
        '- tom_fills: array of fill definitions';
      Placeholders: ['genre', 'style', 'section', 'tempo', 'complexity', 'drummer']
    );

    // Fill generation prompt
    GENERATE_FILL := TAIPromptTemplate(
      Name: 'generate_fill';
      Template: '{system_prompt}'#13#10+
        #13#10+
        '## Context'#13#10+
        'Current pattern:'#13#10+
        '  Bars: {bars}'#13#10+
        '  Sections: {sections}'#13#10+
        #13#10+
        '## Request'#13#10+
        'Generate a drum fill that:'#13#10+
        '- Flows naturally from the current pattern'#13#10+
        '- Duration: {duration} bars'#13#10+
        '- Style: {fill_style}'#13#10+
        #13#10+
        '## Output Format'#13#10+
        'Return JSON with:'#13#10+
        '- fill_type: string (tom_fill, blast_beat, linear, etc.)'#13#10+
        '- kick_notes: array [bar, time, velocity]'#13#10+
        '- snare_notes: array [bar, time, velocity]'#13#10+
        '- tom_notes: array [bar, time, velocity, tom_type]';
      Placeholders: ['bars', 'sections', 'duration', 'fill_style']
    );

    // Song structure suggestion prompt
    SUGGEST_STRUCTURE := TAIPromptTemplate(
      Name: 'suggest_structure';
      Template: '{system_prompt}'#13#10+
        #13#10+
        '## Genre & Style'#13#10+
        'Genre: {genre}'#13#10+
        'Style: {style}'#13#10+
        '## Context'#13#10+
        'Tempo range: {tempo_min}-{tempo_max} BPM'#13#10+
        'Target length: {target_length} bars'#13#10+
        #13#10+
        '## Request'#13#10+
        'Suggest a song structure with sections, bar counts, and intensity profiles.'#13#10+
        'Include intro, verse, chorus, bridge, solo (if appropriate), outro.'#13#10+
        #13#10+
        '## Output Format'#13#10+
        'Return JSON array of:'#13#10+
        '- name: section name'#13#10+
        '- bars: bar count'#13#10+
        '- intensity: 0-1 profile'#13#10+
        '- notes: optional description';
      Placeholders: ['genre', 'style', 'tempo_min', 'tempo_max', 'target_length']
    );

    // Pattern variation prompt
    GENERATE_VARIATION := TAIPromptTemplate(
      Name: 'generate_variation';
      Template: '{system_prompt}'#13#10+
        #13#10+
        '## Original Pattern'#13#10+
        'Bars: {bars}'#13#10+
        'Genre: {genre}'#13#10+
        'Style: {style}'#13#10+
        #13#10+
        '## Request'#13#10+
        'Generate a variation that:'#13#10+
        '- Maintains groove feel but adds complexity'#13#10+
        '- Variation type: {variation_type}'#13#10+
        '- Add/remove ghost notes, fills, or cymbal changes'#13#10+
        #13#10+
        '## Output Format'#13#10+
        'Return JSON with:'#13#10+
        '- changed_bars: array of bar indices that were modified'#13#10+
        '- change_description: string explaining the variation';
      Placeholders: ['bars', 'genre', 'style', 'variation_type']
    );

    // Drummer style adaptation prompt
    ADAPT_DRUMMER := TAIPromptTemplate(
      Name: 'adapt_drummer';
      Template: '{system_prompt}'#13#10+
        #13#10+
        '## Pattern to Adapt'#13#10+
        'Bars: {bars}'#13#10+
        'Current style: {current_style}'#13#10+
        #13#10+
        '## Target Drummer Style'#13#10+
        'Drummer: {drummer_name}'#13#10+
        'Known traits: {drummer_traits}'#13#10+
        #13#10+
        '## Request'#13#10+
        'Adapt the pattern to sound like this drummer. Describe:'#13#10+
        '- Timing modifications (behind-beat, push-forward, etc.)'#13#10+
        '- Velocity adjustments for ghost notes and accents'#13#10+
        '- Signature fills or rhythmic patterns to add';
      Placeholders: ['bars', 'current_style', 'drummer_name', 'drummer_traits']
    );

    // Genre-specific template selection prompt
    SELECT_TEMPLATE := TAIPromptTemplate(
      Name: 'select_template';
      Template: '{system_prompt}'#13#10+
        #13#10+
        '## Request'#13#10+
        'Genre: {genre}'#13#10+
        'Style: {style}'#13#10+
        'Section: {section}'#13#10+
        #13#10+
        '## Available Templates'#13#10+
        '- BasicGroove: Standard kick + snare patterns'#13#10+
        '- DoubleBassPedal: Continuous/gallop/burst double bass'#13#10+
        '- BlastBeat: Traditional/hammer/gravity blast beats'#13#10+
        '- SteadyRide: Ride cymbal timekeeping'#13#10+
        '- JazzRidePattern: Swing ride with accents'#13#10+
        '- FunkGhostNotes: Ghost note layers for funk grooves'#13#10+
        '- CrashAccents: Crash cymbal placement patterns'#13#10+
        '- TomFill: Descending/ascending tom fills'#13#10+
        #13#10+
        '## Request'#13#10+
        'Which template(s) best match this request? Justify your choice.';
      Placeholders: ['genre', 'style', 'section']
    );

    // All templates combined for easy iteration
    ALL_TEMPLATES: array[0..6] of TAIPromptTemplate = (
      GENERATE_PATTERN;
      GENERATE_FILL;
      SUGGEST_STRUCTURE;
      GENERATE_VARIATION;
      ADAPT_DRUMMER;
      SELECT_TEMPLATE;
      GENERATE_PATTERN // Duplicate placeholder for array bounds
    );

    // Helper to get template count
    TEMPLATE_COUNT: Integer = 6;
  end;

// ============================================================================
// TAIPromptResolver — Resolves placeholders in templates with actual values
// ============================================================================
type
  TAIPromptResolver = class
  private
    FPlaceholders: TDictionary<String, String>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddPlaceholder(const AName, AValue: String);
    procedure Clear;

    function Resolve(const ATemplate: String): String;
    function ResolveWithTemplate(ATemplateIndex: Integer; APlaceholders: TDictionary<String, String>): String;
  end;

implementation

constructor TAIPromptResolver.Create;
begin
  FPlaceholders := TDictionary<String, String>.Create;
end;

destructor TAIPromptResolver.Destroy;
begin
  FPlaceholders.Free;
  inherited Destroy;
end;

procedure TAIPromptResolver.AddPlaceholder(const AName, AValue: String);
begin
  FPlaceholders.AddOrSetValue(AName, AValue);
end;

procedure TAIPromptResolver.Clear;
begin
  FPlaceholders.Clear;
end;

function TAIPromptResolver.Resolve(const ATemplate: String): String;
var
  Placeholder: String;
  PlaceholderStart, PlaceholderEnd: Integer;
  Value: String;
begin
  Result := ATemplate;

  // Simple placeholder resolution: {placeholder_name} -> value
  while (Pos('{', Result) > 0) do
  begin
    PlaceholderStart := Pos('{', Result);
    PlaceholderEnd := Pos('}', Result);
    
    if (PlaceholderEnd > PlaceholderStart) then
    begin
      Placeholder := Copy(Result, PlaceholderStart + 1, PlaceholderEnd - PlaceholderStart - 1);
      
      if (FPlaceholders.TryGetValue(Placeholder, Value)) then
        Result := ReplaceStr(Result, '{' + Placeholder + '}', Value)
      else
        Break; // Unknown placeholder — stop resolution
      
      Continue; // Re-check for more placeholders
    end
    else
      Break;
  end;
end;

function TAIPromptResolver.ResolveWithTemplate(ATemplateIndex: Integer; APlaceholders: TDictionary<String, String>): String;
var
  I: Integer;
begin
  // Copy placeholders to resolver
  Clear;
  for I := 0 to APlaceholders.Count - 1 do
    AddPlaceholder(APlaceholders.Keys[I], APlaceholders.Values[I]);
  
  // Resolve with template from TAIPromptTemplates
  Result := Resolve(TAIPromptTemplates.ALL_TEMPLATES[ATemplateIndex].Template);
end;

end.
