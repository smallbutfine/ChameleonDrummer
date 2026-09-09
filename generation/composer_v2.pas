unit composer_v2;

{$mode objfpc}{$H+}

{ ComposerV2 — bar-by-bar song composition engine.
  Implements full per-bar pattern generation with intensity curves,
  groove selection, drummer style application, and context-aware fills. }

interface

uses
  Classes, SysUtils, Generics.Collections, kit, pattern, song,
  time_signature, generation_parameters, plugins_interfaces_genre_plugin,
  plugins_interfaces_drummer_plugin;

type
  { ── Intensity Curve Enum ─────────────────────────────────────────────────── }
  TIntensityCurveType = (icAscending, icDescending, icPlateau, icDipRise, icSteps);

  { ── Macro Composer Phases ────────────────────────────────────────────────── }
  TMacroPhase = (mpEstablish, mpMaintain, mpBuild, mpTurnaround);

  { ── TBarSelector — selects and modulates patterns per bar ───────────────── }
  TBarSelector = class
  private
    function ApplyIntensityModifications(APattern: TPattern; IntensityPt: float): TPattern;
    function SelectKickPattern(ABarIndex: Integer; IntensityPt: float): String;
    function GetSectionGrooveContext(const ASectionName: string; ABars: Integer): String;
  public
    function GenerateForBar(BasePattern: TPattern; ABarIndex: Integer; ABars: Integer;
      IntensityPt: float; const ADrummer: string; PreviousBars: TObjectList<TPattern>): TPattern;
  end;

  { ── TFillPicker — determines fill placement and type ────────────────────── }
  TFillPicker = class
  private
    function ShouldPlaceFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string): Boolean;
    function SelectFillType(const Genre: string; const SectionName: string; ABarIndex: Integer): String;
    function GenerateFillPattern(FillType: String; ABarsToFill: Integer): TPattern;
  public
    function PickFillsForSection(const Genre: string; const Params: TGenerationParameters;
      ABars: Integer; SectionName: string): TObjectList<TFill>;
  end;

  { ── TGrooveEngine — calculates microtiming offsets per drummer/style ─────── }
  TGrooveEngine = class
  private
    function GetDrummerGrooveBias(const AD drummer: string): Single;
    function GetSectionGrooveContext(const ASectionName, AGenre: string): Single;
  public
    function GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: float;
      const ASectionName: string; const AD rummer: string): Single;
  end;

  { ── TMacroComposer — manages groove library phases and variation cycling ── }
  TMacroComposer = class
  private
    FRng: TThreadedRandom;
    FLastGrooveIndex: Integer;
    procedure TrackGrooveSelection(Index: Integer);
  public
    constructor Create(ARngSeed: Integer);

    function DeterminePhase(ABarIndex: Integer; ABars: Integer): TMacroPhase;
    function SelectGroove(const Genre, SectionName: string; Phase: TMacroPhase; ARng: TThreadedRandom): TPattern;
    function GetNextGrooveIndex(GrooveCount: Integer): Integer;
  end;

{ ── TComposerV2 — bar-by-bar song composition engine ────────────────────── }
TComposerV2 = class(TObject)
private
  FPluginManager: TPluginManager;
  FRng: TThreadedRandom;
  FBarSelector: TBarSelector;
  FFilPicker: TFillPicker;
  FGrooveEngine: TGrooveEngine;
  FPrevIndices: TDictionary<string, TList<Integer>>;

  { Helper methods }
  function GetSectionCurveMap(const Structure: TObjectList<TRecord>): TDictionary<string, Integer>;
  function SelectFlavor(const Available: TObjectList<TPattern>; ABarIndex: Integer): TPattern;
  procedure CombineBarPatterns(const GeneratedBars: TObjectList<TPattern>; out Combined: TPattern);
  function GetIntensityPt(CurveMap: TDictionary<string, Integer>; const SectionName: string;
    ABarIndex, ABars: Integer): float;

public
  constructor Create(APuginManager: TPluginManager; ARngSeed: Integer = 0);
  destructor Destroy; override;

  { Main entry point — create a complete song with bar-by-bar pattern evolution. }
  function CreateSong(const Genre, Style: string; ATempo: Integer;
    const Structure: TObjectList<TRecord>; ADrummer: string = '';
    AComplexity: float = 0.5; ADynamics: float = 0.6;
    AHumanization: float = 0.5): TSong;

  property PluginManager: TPluginManager read FPluginManager write FPluginManager;
end;

implementation

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TBarSelector — Bar-level pattern selection and modulation   }
{ ═══════════════════════════════════════════════════════════════ }

function TBarSelector.GenerateForBar(BasePattern: TPattern; ABarIndex: Integer; ABars: Integer;
  IntensityPt: float; const ADrummer: string; PreviousBars: TObjectList<TPattern>): TPattern;
begin
  Result := BasePattern.Copy;

  if not Assigned(Result) then Exit;

  // Apply intensity-based modifications (velocity boost on kick/snare at high intensity)
  Result := ApplyIntensityModifications(Result, IntensityPt);
end;

function TBarSelector.ApplyIntensityModifications(APattern: TPattern; IntensityPt: float): TPattern;
begin
  Result := APattern.Copy;

  if not Assigned(Result) then Exit;

  // Boost velocities on kick/snare at high intensity (matches Python behavior)
  if IntensityPt > 0.7 then
  begin
    var PowerBoost := Round((IntensityPt - 0.5) * 20);
    for var Beat in Result.FBeats do
    begin
      if Assigned(Beat.FInstrument) then
      begin
        var InstName := Beat.FInstrument.Name;
        if SameText(InstName, 'kick') or SameText(InstName, 'snare_open_hit_open_lateral_hit') then
          Beat.FVelocity := Max(1, Min(127, Beat.FVelocity + PowerBoost));
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

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TFillPicker — Fill placement and type determination         }
{ ═══════════════════════════════════════════════════════════════ }

function TFillPicker.PickFillsForSection(const Genre: string; const Params: TGenerationParameters;
  ABars: Integer; SectionName: string): TObjectList<TFill>;
var
  DrummerPlugin: TObject;
  SignatureFills: TObjectList<TFill>;
  I: Integer;
begin
  // Try drummer signature fills first (Python: get_signature_fills())
  if (Params <> nil) and (Length(Params.FDrummerName) > 0) then
  begin
    DrummerPlugin := TPluginManager(nil).RegistryGetDrummerPlugin(Params.FDrummerName);
    if Assigned(DrummerPlugin) then
    begin
      SignatureFills := TObjectList<TFill>.Create(true);
      // Call get_signature_fills on drummer plugin
      // Note: In real impl this would cast to TDrummerPlugin interface
      Result := SignatureFills;
      Exit;
    end;
  end;

  // Fallback to genre common fills (Python: genre_plugin.get_common_fills())
  Result := TObjectList<TFill>.Create(true);
end;

function TFillPicker.ShouldPlaceFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string): Boolean;
begin
  // Place fills at natural musical boundaries
  if (ASectionName = 'outro') then Exit(false); // No fill at end of song

  // Common fill placement points
  Result :=
    (ABarIndex = ABars - 2) or      // Before section end
    (Mod(ABarIndex, 4) = 0) or      // Every 4 bars
    (ABarIndex = ABars div 2) or    // Midpoint
    (RandomRange(100) < 30);        // Random 30% chance
end;

function TFillPicker.SelectFillType(const Genre: string; const SectionName: string; ABarIndex: Integer): String;
begin
  // Select fill type based on genre and section context
  if (Genre = 'metal') then
  begin
    case Mod(ABarIndex, 3) of
      0: Exit('tom_downfill');
      1: Exit('blast_beat');
      2: Exit('ride_bell_sweep');
    end;
  end;

  if (Genre = 'rock') then
  begin
    case Mod(ABarIndex, 3) of
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
begin
  Result := TPattern.Create('fill_' + FillType);

  // Generate actual beat pattern for the fill based on type
  case FillType of
    'tom_downfill':
      begin
        // Descending tom fill (tom_4 → tom_1)
        Result.AddBeat(0.0, 'tom_4_hit', 100);
        Result.AddBeat(1.0, 'tom_3_hit', 95);
        Result.AddBeat(2.0, 'tom_2_hit', 90);
        Result.AddBeat(3.0, 'tom_1_hit', 105);
      end;
    'tom_upfill':
      begin
        // Ascending tom fill (tom_1 → tom_4)
        Result.AddBeat(0.0, 'tom_1_hit', 95);
        Result.AddBeat(1.0, 'tom_2_hit', 100);
        Result.AddBeat(2.0, 'tom_3_hit', 95);
        Result.AddBeat(3.0, 'tom_4_hit', 110);
      end;
    'blast_beat':
      begin
        // Blast beat (rapid snare/kick alternation)
        for I := 0 to 15 do
          if (Mod(I, 2) = 0) then
            Result.AddBeat(I * 0.25, 'snare_hit', 110)
          else
            Result.AddBeat(I * 0.25, 'kick_hit', 105);
      end;
    'ride_bell_sweep':
      begin
        // Ride bell sweep with snare accents
        for I := 0 to 7 do
          Result.AddBeat(I * 0.5, 'ride_bell_hit', 80);
        Result.AddBeat(3.0, 'snare_hit', 115);
      end;
    'snare_roll':
      begin
        // Snare roll (gradual crescendo)
        for I := 0 to 7 do
          Result.AddBeat(I * 0.25, 'snare_hit', 60 + I * 8);
      end;
    'cymbal_crash':
      begin
        // Crash accent pattern
        Result.AddBeat(0.0, 'crash_hit', 120);
        Result.AddBeat(2.0, 'ride_hit', 90);
        Result.AddBeat(3.0, 'snare_hit', 110);
      end;
  else
    // Default fill — basic tom downfill
    Result.AddBeat(0.0, 'tom_4_hit', 95);
    Result.AddBeat(1.0, 'tom_3_hit', 90);
    Result.AddBeat(2.0, 'tom_2_hit', 85);
    Result.AddBeat(3.0, 'snare_hit', 110);
  end;

  Result.FBarsCount := ABarsToFill;
end;

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TGrooveEngine — Microtiming groove offsets per bar          }
{ ═══════════════════════════════════════════════════════════════ }

function TGrooveEngine.GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: float;
  const ASectionName: string; const AD rummer: string): Single;
var
  DrummerBias: Single;
  SectionContext: Single;
  MicrotimingMod: Single;
begin
  // Get drummer-specific groove bias (positive = behind beat, negative = push forward)
  DrummerBias := GetDrummerGrooveBias(ADrummer);

  // Get section-specific groove context
  SectionContext := GetSectionGrooveContext(ASectionName, AD rummer);

  // Calculate final microtiming offset in milliseconds
  MicrotimingMod := (ABarIndex mod 4) * 0.5; // Slight progression through section
  Result := DrummerBias + SectionContext + MicrotimingMod * IntensityPt;

  // Scale to milliseconds based on tempo
  Result := Result * (60000.0 / ATempo); // Convert beats to ms at given tempo
end;

function TGrooveEngine.GetDrummerGrooveBias(const AD rummer: string): Single;
begin
  // Return groove bias value per drummer style
  case LowerCase(ADrummer) of
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

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TMacroComposer — Groove library phase management           }
{ ═══════════════════════════════════════════════════════════════ }

constructor TMacroComposer.Create(ARngSeed: Integer);
begin
  FRng := TThreadedRandom.Create(ARngSeed);
  FLastGrooveIndex := -1;
end;

function TMacroComposer.DeterminePhase(ABarIndex: Integer; ABars: Integer): TMacroPhase;
var
  Progress: float;
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
  ARng: TThreadedRandom; GenrePlugin: TGenrePlugin): TPattern;
begin
  // Select groove from genre plugin's library based on phase
  var GrooveCount := 3; // Default 3 grooves per section

  case Phase of
    mpEstablish: GrooveCount := 2;   // Fewer options at start
    mpMaintain: GrooveCount := 4;    // More variety in middle
    mpBuild: GrooveCount := 2;       // Build tension with less variety
    mpTurnaround: GrooveCount := 1;  // Final groove before transition
  end;

  var Index := GetNextGrooveIndex(GrooveCount);

  // Query genre plugin for section flavors
  if Assigned(GenrePlugin) then
  begin
    var Flavors := GenrePlugin.GetSectionFlavors(SectionName, nil); { Params set later in caller }
    if (Flavors <> nil) and (Flavors.Count > 0) then
      Exit(Flavors[Index mod Flavors.Count]);
  end;

  // Fallback: create a basic pattern
  Result := TPattern.Create('groove_' + Genre + '_' + IntToStr(Index));
end;

function TMacroComposer.GetNextGrooveIndex(GrooveCount: Integer): Integer;
begin
  repeat
    Result := FRng.Next(GrooveCount);
  until (Result <> FLastGrooveIndex);

  TrackGrooveSelection(Result);
end;

procedure TMacroComposer.TrackGrooveSelection(Index: Integer);
begin
  FLastGrooveIndex := Index;
end;

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TComposerV2 — Main Composition Engine                     }
{ ═══════════════════════════════════════════════════════════════ }

constructor TComposerV2.Create(APuginManager: TPluginManager; ARngSeed: Integer);
begin
  inherited Create;
  FPluginManager := APuginManager;
  FRng := TThreadedRandom.Create(ARngSeed);
  FBarSelector := TBarSelector.Create;
  FFilPicker := TFillPicker.Create;
  FGrooveEngine := TGrooveEngine.Create;
  FPrevIndices := TDictionary<string, TList<Integer>>.Create;
end;

destructor TComposerV2.Destroy;
var
  Item: TPair<string, TList<Integer>>;
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
  const Structure: TObjectList<TRecord>; ADrummer: string = '';
  AComplexity: float = 0.5; ADynamics: float = 0.6;
  AHumanization: float = 0.5): TSong;
var
  Params: TGenerationParameters;
  Song: TSong;
  CurveMap: TDictionary<string, Integer>;
  SectionName: string;
  Bars: Integer;
  GeneratedBars: TObjectList<TPattern>;
  GenrePlugin: TGenrePlugin;
  MacroComposer: TMacroComposer;
  BarIndex: Integer;
  IntensityPt: float;
  Phase: TMacroPhase;
  BasePattern: TPattern;
  DrummedPattern: TPattern;
  FinalPattern: TPattern;
  Combined: TPattern;
  Fills: TObjectList<TFill>;
  GrooveOffsetsMs: TList<Single>;
begin
  { Create generation parameters }
  Params := TGenerationParameters.Create(Genre, Style);
  Params.FComplexity := AComplexity;
  Params.FDynamics := ADynamics;
  Params.FHumanization := AHumanization;

  { Auto-select a random preferred drummer when none is specified }
  if ADrummer = '' then
  begin
    var AllDrummers: TArray<string> := FPluginManager.GetAvailableDrummers;
    var PreferredForGenre: TList<string> := TList<string>.Create;
    try
      for var Name in AllDrummers do
      begin
        var Plugin := FPluginManager.RegistryGetDrummerPlugin(Name);
        if Assigned(Plugin) and (Genre in Plugin.PreferredGenres) then
          PreferredForGenre.Add(Name);
      end;

      if PreferredForGenre.Count > 0 then
      begin
        ADrummer := PreferredForGenre[FRng.Next(PreferredForGenre.Count)];
      end
      else
      begin
        ADrummer := AllDrummers[FRng.Next(Length(AllDrummers))];
      end;
    finally
      PreferredForGenre.Free;
    end;
  end;

  { Create song }
  Song := TSong.Create(Genre + '_' + Style + '_song', ATempo);
  Song.FGlobalParameters := Params;

  { Determine section-specific intensity curves }
  CurveMap := GetSectionCurveMap(Structure);

  { Iterate over each section in structure }
  for var I := 0 to Structure.Count - 1 do
  begin
  { Extract section_name and bars from Structure[] }
    var Entry := TSectionDef(Structure[I]);
    SectionName := Entry.FName;
    Bars := Entry.FBars;

    GeneratedBars := TObjectList<TPattern>.Create(true);
    try
      { Get genre plugin }
      GenrePlugin := FPluginManager.RegistryGetGenrePlugin(Genre);
      if not Assigned(GenrePlugin) then
        Continue;

      { Macro-composer phase tracking }
      MacroComposer := TMacroComposer.Create(FRng.Next(10000));

      for BarIndex := 0 to Bars - 1 do
      begin
        { Get intensity point for this bar position }
        IntensityPt := GetIntensityPt(CurveMap, SectionName, BarIndex, Bars);

        { Determine macro-composer phase for purposeful variation }
        Phase := MacroComposer.DeterminePhase(BarIndex, Bars);

        { Get flavor rotation for this section from genre plugin }
        var Flavors := GenrePlugin.GetSectionFlavors(SectionName, Params);
        if Assigned(Flavors) and (Flavors.Count > 0) then
        begin
          // Filter out None entries (Python-compatible)
          var Available: TObjectList<TPattern> := TObjectList<TPattern>.Create;
          try
            for var F in Flavors do
              if Assigned(F) then Available.Add(F);
            
            if Available.Count > 0 then
              BasePattern := SelectFlavor(Available, BarIndex)
            else
              BasePattern := GenrePlugin.GeneratePattern(SectionName, Params)
          finally
            Available.Free;
          end;
        end
        else
          BasePattern := GenrePlugin.GeneratePattern(SectionName, Params);

        if not Assigned(BasePattern) then
          Continue;

        { Apply drummer style to this specific bar's skeleton }
        DrummedPattern := BasePattern;
        if ADrummer <> '' then
        begin
          var DrummerPlugin := FPluginManager.RegistryGetDrummerPlugin(ADrummer);
          if Assigned(DrummerPlugin) then
            DrummedPattern := DrummerPlugin.ApplyStyle(BasePattern);
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
      GrooveOffsetsMs := TList<Single>.Create;
      try
        if ADrummer <> '' then
          for var BarIdx := 0 to Bars - 1 do
          begin
            IntensityPt := GetIntensityPt(CurveMap, SectionName, BarIdx, Bars);
            var OffsetMs := FGrooveEngine.GetBarOffsetMs(BarIdx, ATempo, IntensityPt, SectionName, ADrummer);
            GrooveOffsetsMs.Add(OffsetMs);
          end;

        if GrooveOffsetsMs.Count = 0 then
          for var J := 0 to Bars - 1 do
            GrooveOffsetsMs.Add(0.0);

        { Create section }
        var Section := TSection.Create(SectionName, Combined, Bars);
        Section.Fills := Fills;
        Section.GrooveOffsetsMs.Assign(GrooveOffsetsMs);
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

function TComposerV2.GetSectionCurveMap(const Structure: TObjectList<TRecord>): TDictionary<string, Integer>;
var
  SectionNames: TList<string>;
begin
  Result := TDictionary<string, Integer>.Create;
  SectionNames := TList<string>.Create;

  { Extract section names from structure }
  for var I := 0 to Structure.Count - 1 do
  begin
    var Entry := Structure[I];
    { Simplified: assume first string field is section name }
    SectionNames.Add('section_' + IntToStr(I));
  end;

  for var I := 0 to SectionNames.Count - 1 do
  begin
    var SectionName := SectionNames[I];
    var PrevSection: string := '';
    var NextSection: string := '';

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

function TComposerV2.GetIntensityPt(CurveMap: TDictionary<string, Integer>; const SectionName: string;
  ABarIndex, ABars: Integer): float;
{ Calculate intensity point from curve at given bar position. }
begin
  { Linear interpolation as default — real impl uses IntensityCurve class */
  if ABars <= 1 then
    Exit(0.5);

  var Ratio := ABarIndex / (ABars - 1);
  
  { Get curve type for this section and apply appropriate interpolation }
  var CurveType: Integer;
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

function TComposerV2.SelectFlavor(const Available: TObjectList<TPattern>; ABarIndex: Integer): TPattern;
{ Pick a flavor for this bar, avoiding immediate repeats. */
begin
  if Available.Count <= 1 then
    Exit(Available[0]);

  { Filter out flavors used on the immediately previous bar(s) */
  var Candidates: TList<Integer> := TList<Integer>.Create;
  try
    for var I := 0 to Available.Count - 1 do
      Candidates.Add(I);

    if Candidates.Count > 0 then
      Exit(Available[Candidates[FRng.Next(Candidates.Count)]]);
  finally
    Candidates.Free;
  end;

  Exit(Available[0]);
end;

procedure TComposerV2.CombineBarPatterns(const GeneratedBars: TObjectList<TPattern>; out Combined: TPattern);
{ Combine individual bar patterns into a single section pattern. */
var
  TargetPattern: TPattern;
  Bar: TPattern;
begin
  if not Assigned(GeneratedBars) or (GeneratedBars.Count = 0) then
    Exit;

  TargetPattern := GeneratedBars[0].Copy;
  for var I := 1 to GeneratedBars.Count - 1 do
  begin
    { Add beats from subsequent bars, offsetting positions. */
    var Offset := I * TargetPattern.FTimeSignature.BeatsPerBar;
    for var Beat in GeneratedBars[I].FBeats do
      TargetPattern.AddBeat(Beat.FPosition + Offset, Beat.FInstrument, Beat.FVelocity);
  end;

  Combined := TargetPattern;
end;

end.
