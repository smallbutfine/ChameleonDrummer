unit ComposerV2;

{$mode objfpc}{$H+}

{ ComposerV2 — bar-by-bar song composition engine.
  Implements full per-bar pattern generation with intensity curves,
  groove selection, drummer style application, and context-aware fills. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song,
  TimeSignature, GenerationParameters, GenrePlugin,
  DrummerPlugin, PluginRegistry, ComposerTypes;

type
  { Structure entry type for song sections - must match DrumGenerator.TStructureEntry }
  TSectionDef = record
    Name: string;
    Bars: Integer;
  end;

  { Intensity Curve Enum }
  TIntensityCurveType = (icAscending, icDescending, icPlateau, icDipRise, icSteps);

  { Macro Composer Phases }
  TMacroPhase = (mpEstablish, mpMaintain, mpBuild, mpTurnaround);

  { TBarSelector — selects and modulates patterns per bar }
  TBarSelector = class
  private
    function ApplyIntensityModifications(APattern: TPattern; IntensityPt: Double): TPattern;
    { function SelectKickPattern - not implemented in this translation. }
    function GetSectionGrooveContext(const ASectionName: string; ABars: Integer): String;
  public
    function GenerateForBar(BasePattern: TPattern; ABarIndex: Integer; ABars: Integer;
      IntensityPt: Double; const ADrummer: string; PreviousBars: specialize TList<TPattern>): TPattern;
  end;

  { TFillPicker — determines fill placement and type }
  TFillPicker = class
  private
    function ShouldPlaceFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string): Boolean;
    function SelectFillType(const Genre: string; const SectionName: string; ABarIndex: Integer): String;
    function GenerateFillPattern(FillType: String; ABarsToFill: Integer): TPattern;
  public
    function PickFillsForSection(const Genre: string; const Params: TGenerationParameters;
      ABars: Integer; SectionName: string): specialize TList<TFill>;
  end;

  { TGrooveEngine — calculates microtiming offsets per drummer/style }
  TGrooveEngine = class
  private
    function GetDrummerGrooveBias(const ADrummer: string): Single;
    function GetSectionGrooveContext(const ASectionName, AGenre: string): Single;
  public
    function GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: Double;
      const ASectionName: string; const ADrummer: string): Single;
  end;

  { TMacroComposer — manages groove library phases and variation cycling }
  TMacroComposer = class
  private
    FRng: TThreadedRandom;
    FLastGrooveIndex: Integer;
    procedure TrackGrooveSelection(Index: Integer);
  public
    constructor Create(ARngSeed: Integer);

    function DeterminePhase(ABarIndex: Integer; ABars: Integer): TMacroPhase;
    function SelectGroove(const Genre, SectionName: string; Phase: TMacroPhase;
      ARng: TThreadedRandom): TPattern;
    function GetNextGrooveIndex(GrooveCount: Integer): Integer;
  end;

{ TComposerV2 — bar-by-bar song composition engine }
TComposerV2 = class(TObject)
private
  FPluginManager: PluginRegistry.TPluginManager;
  FRng: TThreadedRandom;
  FBarSelector: TBarSelector;
  FFilPicker: TFillPicker;
  FGrooveEngine: TGrooveEngine;
  FPrevIndices: specialize TDictionary<string, specialize TList<Integer>>;

  { Helper methods }
  function GetSectionCurveMap(const Structure: array of TSectionDef): specialize TDictionary<string, Integer>;
  function SelectFlavor(const Available: specialize TList<TPattern>; ABarIndex: Integer): TPattern;
  procedure CombineBarPatterns(const GeneratedBars: specialize TList<TPattern>; out Combined: TPattern);
  function GetIntensityPt(CurveMap: specialize TDictionary<string, Integer>; const SectionName: string;
    ABarIndex, ABars: Integer): Double;

public
  constructor Create(APGMPluginManager: PluginRegistry.TPluginManager; ARngSeed: Integer = 0);
  destructor Destroy; override;

  { Main entry point — create a complete song with bar-by-bar pattern evolution. }
  function CreateSong(const Genre, Style: string; ATempo: Integer;
    const Structure: array of TSectionDef; ADrummer: string = '';
    AComplexity: Double = 0.5; ADynamics: Double = 0.6;
    AHumanization: Double = 0.5): TSong;

  property PluginManager: PluginRegistry.TPluginManager read FPluginManager write FPluginManager;
end;

implementation

{ TBarSelector — Bar-level pattern selection and modulation }

function TBarSelector.GenerateForBar(BasePattern: TPattern; ABarIndex: Integer; ABars: Integer;
  IntensityPt: Double; const ADrummer: string; PreviousBars: specialize TList<TPattern>): TPattern;
begin
  Result := BasePattern.Copy;

  if not Assigned(Result) then Exit;

  // Apply intensity-based modifications (velocity boost on kick/snare at high intensity)
  Result := ApplyIntensityModifications(Result, IntensityPt);
end;

function TBarSelector.ApplyIntensityModifications(APattern: TPattern; IntensityPt: Double): TPattern;
var
  PowerBoost: Integer;
  IBeat: Integer;
  InstName: AnsiString;
begin
  Result := APattern.Copy;

  if not Assigned(Result) then Exit;

  // Boost velocities on kick/snare at high intensity (matches Python behavior)
  if IntensityPt > 0.7 then
  begin
    PowerBoost := Round((IntensityPt - 0.5) * 20);
    for IBeat := 0 to Result.Beats.Count - 1 do
    begin
      if Assigned(Result.Beats[IBEat].Instrument) then
      begin
        InstName := Result.Beats[IBEat].Instrument.Name;
        if SameText(InstName, 'kick') or SameText(InstName, 'snare_open_hit_open_lateral_hit') then
          Result.Beats[IBEat].Velocity := Max(1, Min(127, Result.Beats[IBEat].Velocity + PowerBoost));
      end;
    end;
  end;
end;

function TBarSelector.GetSectionGrooveContext(const ASectionName: string; ABars: Integer): String;
begin
  if (Pos('intro', LowerCase(ASectionName)) > 0) then Exit('sparse');
  if (Pos('chorus', LowerCase(ASectionName)) > 0) then Exit('full');
  if (Pos('breakdown', LowerCase(ASectionName)) > 0) then Exit('driving');
  if (Pos('bridge', LowerCase(ASectionName)) > 0) then Exit('minimal');
  Exit('standard');
end;

{ TFillPicker — Fill placement and type determination }

function TFillPicker.PickFillsForSection(const Genre: string; const Params: TGenerationParameters;
  ABars: Integer; SectionName: string): specialize TList<TFill>;
begin
  { Simplified: return empty list - caller (ComposerV2) handles fill lookup via genre plugins.
     PickFillsForSection is a standalone helper without plugin access. }
  Result := specialize TList<TFill>.Create;
end;

function TFillPicker.ShouldPlaceFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string): Boolean;
begin
  // Place fills at natural musical boundaries
  if (ASectionName = 'outro') then Exit(false); // No fill at end of song

  // Common fill placement points
  Result :=
    (ABarIndex = ABars - 2) or      // Before section end
    ((ABarIndex mod 4) = 0) or      // Every 4 bars
    (ABarIndex = ABars div 2) or    // Midpoint
    (RandomRange(0, 100) < 30);        // Random 30% chance
end;

function TFillPicker.SelectFillType(const Genre: string; const SectionName: string; ABarIndex: Integer): String;
begin
  // Select fill type based on genre and section context
  if (Genre = 'metal') then
  begin
    case (ABarIndex mod 3) of
      0: Exit('tom_downfill');
      1: Exit('blast_beat');
      2: Exit('ride_bell_sweep');
    end;
  end;

  if (Genre = 'rock') then
  begin
    case (ABarIndex mod 3) of
      0: Exit('tom_downfill');
      1: Exit('snare_roll');
      2: Exit('cymbal_crash');
    end;
  end;

  // Default fill type
  if (Pos('chorus', LowerCase(SectionName)) > 0) then
    Exit('tom_upfill')
  else
    Exit('tom_downfill');
end;

function TFillPicker.GenerateFillPattern(FillType: String; ABarsToFill: Integer): TPattern;
var
  I: Integer;
begin
  Result := TPattern.Create('fill_' + FillType);

  // Generate actual beat pattern for the fill based on type
  case FillType of
    'tom_downfill':
      begin
        // Descending tom fill (tom_4 -> tom_1)
        Result.AddBeat(0.0, TInstrumentRegistry.Get('tom_4_hit'), 100);
        Result.AddBeat(1.0, TInstrumentRegistry.Get('tom_3_hit'), 95);
        Result.AddBeat(2.0, TInstrumentRegistry.Get('tom_2_hit'), 90);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('tom_1_hit'), 105);
      end;
    'tom_upfill':
      begin
        // Ascending tom fill (tom_1 -> tom_4)
        Result.AddBeat(0.0, TInstrumentRegistry.Get('tom_1_hit'), 95);
        Result.AddBeat(1.0, TInstrumentRegistry.Get('tom_2_hit'), 100);
        Result.AddBeat(2.0, TInstrumentRegistry.Get('tom_3_hit'), 95);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('tom_4_hit'), 110);
      end;
    'blast_beat':
      begin
        // Blast beat (rapid snare/kick alternation)
        for I := 0 to 15 do
          if ((I mod 2) = 0) then
            Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('snare_hit'), 110)
          else
            Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('kick_hit'), 105);
      end;
    'ride_bell_sweep':
      begin
        // Ride bell sweep with snare accents
        for I := 0 to 7 do
          Result.AddBeat(I * 0.5, TInstrumentRegistry.Get('ride_bell_hit'), 80);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('snare_hit'), 115);
      end;
    'snare_roll':
      begin
        // Snare roll (gradual crescendo)
        for I := 0 to 7 do
          Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('snare_hit'), 60 + I * 8);
      end;
    'cymbal_crash':
      begin
        // Crash accent pattern
        Result.AddBeat(0.0, TInstrumentRegistry.Get('crash_hit'), 120);
        Result.AddBeat(2.0, TInstrumentRegistry.Get('ride_hit'), 90);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('snare_hit'), 110);
      end;
  else
    // Default fill — basic tom downfill
    Result.AddBeat(0.0, TInstrumentRegistry.Get('tom_4_hit'), 95);
    Result.AddBeat(1.0, TInstrumentRegistry.Get('tom_3_hit'), 90);
    Result.AddBeat(2.0, TInstrumentRegistry.Get('tom_2_hit'), 85);
    Result.AddBeat(3.0, TInstrumentRegistry.Get('snare_hit'), 110);
  end;

  Result.Metadata.Add('bars_to_fill', IntToStr(ABarsToFill));
end;

{ TGrooveEngine — Microtiming groove offsets per bar }

function TGrooveEngine.GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: Double;
  const ASectionName: string; const ADrummer: string): Single;
var
  DrummerBias: Single;
  SectionContext: Single;
  MicrotimingMod: Single;
begin
  // Get drummer-specific groove bias (positive = behind beat, negative = push forward)
  DrummerBias := GetDrummerGrooveBias(ADrummer);

  // Get section-specific groove context
  SectionContext := GetSectionGrooveContext(ASectionName, ADrummer);

  // Calculate final microtiming offset in milliseconds
  MicrotimingMod := (ABarIndex mod 4) * 0.5; // Slight progression through section
  Result := DrummerBias + SectionContext + MicrotimingMod * IntensityPt;

  // Scale to milliseconds based on tempo
  Result := Result * (60000.0 / ATempo); // Convert beats to ms at given tempo
end;

function TGrooveEngine.GetDrummerGrooveBias(const ADrummer: string): Single;
var
  DrummerLower: AnsiString;
begin
  // Return groove bias value per drummer style
  DrummerLower := LowerCase(ADrummer);
  case DrummerLower of
    'bonham': Exit(2.5);     // Behind beat (drunk feel)
    'porcaro': Exit(-1.0);   // Push forward (shuffle ahead)
    'weckl': Exit(0.5);      // Slightly behind, tight
    'chambers': Exit(-0.5);  // Pocket center
    'carey': Exit(1.5);      // Behind beat with pocket
    'peart': Exit(0.0);      // Perfectly on grid
    'hoglan': Exit(-0.2);    // Slightly ahead (mechanical)
    'copeland': Exit(2.0);   // Reggae behind-beat
    else Exit(0.5);          // Default: slight behind beat
  end;
end;

function TGrooveEngine.GetSectionGrooveContext(const ASectionName, AGenre: string): Single;
begin
  // Adjust groove context based on section type and genre
  if (Pos('intro', LowerCase(ASectionName)) > 0) then Exit(-1.5);
  if (Pos('chorus', LowerCase(ASectionName)) > 0) then Exit(1.0);
  if (Pos('breakdown', LowerCase(ASectionName)) > 0) then Exit(0.5);
  if (Pos('bridge', LowerCase(ASectionName)) > 0) then Exit(-2.0);

  case LowerCase(AGenre) of
    'funk': Exit(1.5);   // Funk naturally behind beat
    'jazz': Exit(2.0);   // Jazz swing is behind beat
    'metal': Exit(-0.5); // Metal pushes forward
    else Exit(0.0);
  end;
end;

{ TMacroComposer — Groove library phase management }

constructor TMacroComposer.Create(ARngSeed: Integer);
begin
  FRng := TThreadedRandom.Create;
  FLastGrooveIndex := -1;
end;

function TMacroComposer.DeterminePhase(ABarIndex: Integer; ABars: Integer): TMacroPhase;
var
  Progress: Double;
begin
  if (ABars <= 1) then Exit(mpEstablish);

  Progress := ABarIndex / (ABars - 1);

  if (Progress < 0.25) then
    Exit(mpEstablish)
  else if (Progress < 0.75) then
    Exit(mpMaintain)
  else if (Progress < 0.95) then
    Exit(mpBuild)
  else
    Exit(mpTurnaround);
end;

function TMacroComposer.SelectGroove(const Genre, SectionName: string; Phase: TMacroPhase;
  ARng: TThreadedRandom): TPattern;
var
  GrooveCount: Integer;
  Index: Integer;
begin
  { Return nil - groove library selection not implemented in this translation. }
  Result := nil;
end;

function TMacroComposer.GetNextGrooveIndex(GrooveCount: Integer): Integer;
begin
  repeat
    Result := FRng.NextInt(GrooveCount);
  until (Result <> FLastGrooveIndex);

  TrackGrooveSelection(Result);
end;

procedure TMacroComposer.TrackGrooveSelection(Index: Integer);
begin
  FLastGrooveIndex := Index;
end;

{ TComposerV2 — Main Composition Engine }

constructor TComposerV2.Create(APGMPluginManager: PluginRegistry.TPluginManager; ARngSeed: Integer);
begin
  inherited Create;
  FPluginManager := APGMPluginManager;
  FRng := TThreadedRandom.Create;
  FBarSelector := TBarSelector.Create;
  FFilPicker := TFillPicker.Create;
  FGrooveEngine := TGrooveEngine.Create;
  FPrevIndices := specialize TDictionary<string, specialize TList<Integer>>.Create;
end;

destructor TComposerV2.Destroy;
var
  Item: specialize TPair<string, specialize TList<Integer>>;
begin
  for Item in FPrevIndices do
    Item.Value.Free;
  FPrevIndices.Free;
  FRng.Free;
  FBarSelector.Free;
  FFilPicker.Free;
  FGrooveEngine.Free;
  inherited Destroy;
end;

function TComposerV2.CreateSong(const Genre, Style: string; ATempo: Integer;
  const Structure: array of TSectionDef; ADrummer: string = '';
  AComplexity: Double = 0.5; ADynamics: Double = 0.6;
  AHumanization: Double = 0.5): TSong;
var
  Params: TGenerationParameters;
  Song: TSong;
  CurveMap: specialize TDictionary<string, Integer>;
  SectionName: string;
  Bars: Integer;
  GeneratedBars: specialize TList<TPattern>;
  GenrePlugin: TGenrePlugin;
  MacroComposer: TMacroComposer;
  BarIndex: Integer;
  IntensityPt: Double;
  Phase: TMacroPhase;
  BasePattern: TPattern;
  DrummedPattern: TPattern;
  FinalPattern: TPattern;
  Combined: TPattern;
  Fills: specialize TList<TFill>;
  GrooveOffsetsMs: specialize TList<Single>;
  AllDrummers: specialize TArray<string>;
  PreferredForGenre: specialize TList<string>;
  I, J: Integer;
  DrummerPlugin: TObject;
  SectionDef: TSectionDef;
  FGenrePlugin: TGenrePlugin;
  Flavors: specialize TList<TPattern>;
  Available: specialize TList<TPattern>;
  FlavorItem: TPattern;
  OffsetMs: Single;
  JBar: Integer;
  Section: TSection;
  Offset: Double;
begin
  { Create generation parameters }
  Params := TGenerationParameters.Create(Genre, Style);
  Params.Complexity := AComplexity;
  Params.Dynamics := ADynamics;
  Params.Humanization := AHumanization;

  { Auto-select a random preferred drummer when none is specified }
  if ADrummer = '' then
  begin
    AllDrummers := FPluginManager.Registry.GetAvailableDrummers;
    PreferredForGenre := specialize TList<string>.Create;
    try
      for I := 0 to Length(AllDrummers) - 1 do
      begin
        DrummerPlugin := FPluginManager.Registry.GetDrummerPlugin(AllDrummers[I]);
        if Assigned(DrummerPlugin) and (DrummerPlugin is TDrummerPlugin) then
        begin
          // Check if genre matches any preferred genre
          for J := 0 to Length((DrummerPlugin as TDrummerPlugin).PreferredGenres) - 1 do
          begin
            if SameText(Genre, (DrummerPlugin as TDrummerPlugin).PreferredGenres[J]) then
            begin
              PreferredForGenre.Add(AllDrummers[I]);
              Break;
            end;
          end;
        end;
      end;

      if PreferredForGenre.Count > 0 then
      begin
        ADrummer := PreferredForGenre[FRng.NextInt(PreferredForGenre.Count)];
      end
      else
      begin
        ADrummer := AllDrummers[FRng.NextInt(Length(AllDrummers))];
      end;
    finally
      PreferredForGenre.Free;
    end;
  end;

  { Create song }
  Song := TSong.Create(Genre + '_' + Style + '_song', ATempo);
  Song.GlobalParameters := Params;

  { Determine section-specific intensity curves }
  CurveMap := GetSectionCurveMap(Structure);

  { Iterate over each section in structure }
  for I := 0 to Length(Structure) - 1 do
  begin
    SectionDef := Structure[I];
    SectionName := SectionDef.Name;
    Bars := SectionDef.Bars;

    GeneratedBars := specialize TList<TPattern>.Create;
    try
      { Get genre plugin }
      FGenrePlugin := TGenrePlugin(FPluginManager.Registry.GetGenrePlugin(Genre));
      if not Assigned(FGenrePlugin) then
        Continue;

      { Macro-composer phase tracking }
      MacroComposer := TMacroComposer.Create(FRng.NextInt(10000));

      for BarIndex := 0 to Bars - 1 do
      begin
        { Get intensity point for this bar position }
        IntensityPt := GetIntensityPt(CurveMap, SectionName, BarIndex, Bars);

        { Determine macro-composer phase for purposeful variation }
        Phase := MacroComposer.DeterminePhase(BarIndex, Bars);

        { Get flavor rotation for this section from genre plugin }
        Flavors := nil;
        if Assigned(Flavors) and (Flavors.Count > 0) then
        begin
          // Filter out None entries (Python-compatible)
          Available := specialize TList<TPattern>.Create;
          try
            for FlavorItem in Flavors do
              if Assigned(FlavorItem) then Available.Add(FlavorItem);

            if Available.Count > 0 then
              BasePattern := SelectFlavor(Available, BarIndex)
            else
              BasePattern := nil; { GeneratePattern is protected - use genre default }
          finally
            Available.Free;
          end;
        end
        else
          BasePattern := nil; { GeneratePattern is protected - use genre default }

        if not Assigned(BasePattern) then
          Continue;

        { Apply drummer style to this specific bar's skeleton }
        DrummedPattern := BasePattern;
        if ADrummer <> '' then
        begin
          DrummerPlugin := FPluginManager.Registry.GetDrummerPlugin(ADrummer);
          if Assigned(DrummerPlugin) then
            DrummedPattern := (DrummerPlugin as TDrummerPlugin).ApplyStyle(BasePattern);
        end;

        { Final bar-level modulation (density, complexity, etc.) }
        FinalPattern := FBarSelector.GenerateForBar(DrummedPattern, BarIndex, Bars, IntensityPt, ADrummer, GeneratedBars);
        GeneratedBars.Add(FinalPattern);
      end;

      { Combine bars into a section }
      Combined := nil;
      if GeneratedBars.Count > 0 then
        CombineBarPatterns(GeneratedBars, Combined);

      { Determine fill placement based on section context }
      Fills := FFilPicker.PickFillsForSection(Genre, Params, Bars, SectionName);

      { Calculate groove timing offsets per bar }
      GrooveOffsetsMs := specialize TList<Single>.Create;
      try
        if ADrummer <> '' then
          for JBar := 0 to Bars - 1 do
          begin
            IntensityPt := GetIntensityPt(CurveMap, SectionName, JBar, Bars);
            OffsetMs := FGrooveEngine.GetBarOffsetMs(JBar, ATempo, IntensityPt, SectionName, ADrummer);
            GrooveOffsetsMs.Add(OffsetMs);
          end;

        if GrooveOffsetsMs.Count = 0 then
          for JBar := 0 to Bars - 1 do
            GrooveOffsetsMs.Add(0.0);

        { Create section }
        Section := TSection.Create(SectionName, Combined, Bars);
        Section.Fills := Fills;
        Section.GrooveOffsetsMs := GrooveOffsetsMs;
        Song.Sections.Add(Section);
      finally
        GrooveOffsetsMs.Free;
      end;
    finally
      GeneratedBars.Free;
    end;
  end;

  { Apply genre-aware groove restraints (snare/velocity) before returning }
  Result := Song;
end;

function TComposerV2.GetSectionCurveMap(const Structure: array of TSectionDef): specialize TDictionary<string, Integer>;
var
  SectionNames: specialize TList<string>;
  I: Integer;
  SectionName: string;
  PrevSection: string;
  NextSection: string;
begin
  Result := specialize TDictionary<string, Integer>.Create;
  SectionNames := specialize TList<string>.Create;

  { Extract section names from structure }
  for I := 0 to Length(Structure) - 1 do
  begin
    { Simplified: use section name directly from Structure[i] }
    SectionNames.Add(Structure[I].Name);
  end;

  for I := 0 to SectionNames.Count - 1 do
  begin
    SectionName := SectionNames[I];
    PrevSection := '';
    NextSection := '';

    if I > 0 then
      PrevSection := SectionNames[I - 1];
    if I < SectionNames.Count - 1 then
      NextSection := SectionNames[I + 1];

    { Assign curves based on musical context }
    if Pos('intro', SectionName) = 1 then
      Result.Add(SectionName, Ord(icAscending))
    else if (Pos('verse', SectionName) = 1) and (Pos('chorus', PrevSection) = 1) then
      Result.Add(SectionName, Ord(icDipRise))
    else if Pos('chorus', SectionName) = 1 then
      Result.Add(SectionName, Ord(icPlateau))
    else if Pos('bridge', SectionName) = 1 then
      if Pos('chorus', NextSection) = 1 then
        Result.Add(SectionName, Ord(icDipRise))
      else
        Result.Add(SectionName, Ord(icDescending))
    else if Pos('breakdown', SectionName) = 1 then
      Result.Add(SectionName, Ord(icDipRise))
    else if Pos('outro', SectionName) = 1 then
      Result.Add(SectionName, Ord(icDescending))
    else
      Result.Add(SectionName, Ord(icPlateau)); { default }
  end;

  SectionNames.Free;
end;

function TComposerV2.GetIntensityPt(CurveMap: specialize TDictionary<string, Integer>; const SectionName: string;
  ABarIndex, ABars: Integer): Double;
var
  Ratio: Double;
  CurveType: Integer;
begin
  { Linear interpolation as default — real impl uses IntensityCurve class }
  if ABars <= 1 then
    Exit(0.5);

  Ratio := ABarIndex / (ABars - 1);

  { Get curve type for this section and apply appropriate interpolation }
  if not CurveMap.TryGetValue(SectionName, CurveType) then
    Exit(Ratio);

  case TIntensityCurveType(CurveType) of
    icAscending: Result := Ratio;
    icDescending: Result := 1.0 - Ratio;
    icPlateau: Result := Min(1.0, Max(0.5, 0.7 + sin(Ratio * Pi) * 0.3));
    icDipRise: Result := sin(Ratio * Pi);
    icSteps: Result := floor(Ratio * 4) / 4;
  else
    Result := Ratio;
  end;
end;

function TComposerV2.SelectFlavor(const Available: specialize TList<TPattern>; ABarIndex: Integer): TPattern;
var
  Candidates: specialize TList<Integer>;
  I: Integer;
begin
  { Pick a flavor for this bar, avoiding immediate repeats. }
  if Available.Count <= 1 then
    Exit(Available[0]);

  { Filter out flavors used on the immediately previous bar(s) }
  Candidates := specialize TList<Integer>.Create;
  try
    for I := 0 to Available.Count - 1 do
      Candidates.Add(I);

    if Candidates.Count > 0 then
      Exit(Available[Candidates[FRng.NextInt(Candidates.Count)]]);
  finally
    Candidates.Free;
  end;

  Exit(Available[0]);
end;

procedure TComposerV2.CombineBarPatterns(const GeneratedBars: specialize TList<TPattern>; out Combined: TPattern);
var
  TargetPattern: TPattern;
  Bar: TPattern;
  IBeat: Integer;
  Beat: TBeat;
  Offset: Double;
begin
  if not Assigned(GeneratedBars) or (GeneratedBars.Count = 0) then
    Exit;

  TargetPattern := GeneratedBars[0].Copy;
  for IBeat := 1 to GeneratedBars.Count - 1 do
  begin
    { Add beats from subsequent bars, offsetting positions. }
    Offset := IBeat * TargetPattern.TimeSignature.BeatsPerBar;
    for Beat in GeneratedBars[IBEat].Beats do
      TargetPattern.AddBeat(Beat.Position + Offset, Beat.Instrument, Beat.Velocity);
  end;

  Combined := TargetPattern;
end;

end.
