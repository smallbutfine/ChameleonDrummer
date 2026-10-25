unit ComposerV2;

{$mode objfpc}{$H+}

{ ComposerV2 — bar-by-bar song composition engine.
  Implements full per-bar pattern generation with intensity curves,
  groove selection, drummer style application, and context-aware fills. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song,
  time_signature, generation_parameters, GenrePlugin,
  DrummerPlugin, PluginRegistry, ComposerTypes, AdvancedHumanization,
  GMDPatternLibrary, LimbConstraints, PatternFixer;

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
    function ApplyParameterModifications(APattern: TPattern; IntensityPt,
      Complexity, Dynamics: Double): TPattern;
    { function SelectKickPattern - not implemented in this translation. }
    function GetSectionGrooveContext(const ASectionName: string; ABars: Integer): String;
  public
    function GenerateForBar(BasePattern: TPattern; ABarIndex: Integer; ABars: Integer;
      IntensityPt, Complexity, Dynamics: Double; const ADrummer: string;
      PreviousBars: specialize TList<TPattern>): TPattern;
  end;

  { TFillPicker — determines fill placement and type }
  TFillPicker = class
  private
    function ShouldPlaceFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string; IntensityPt: Double): Boolean;
    function SelectFillType(const Genre: string; const SectionName: string; ABarIndex: Integer; IntensityPt: Double): String;
    function GenerateFillPattern(FillType: String; ABarsToFill: Integer): TPattern;
  public
    function PickFillsForSection(const Genre: string; const Params: TGenerationParameters;
      ABars: Integer; SectionName: string; out FillBarIndices: specialize TArray<Integer>; const IntensityValues: specialize TArray<Double>): specialize TList<TFill>;
  end;

  { TGrooveEngine — calculates microtiming offsets per drummer/style }
  TGrooveEngine = class
  private
    function GetDrummerGrooveBias(const ADrummer: string): Single;
    function GetSectionGrooveContext(const ASectionName, AGenre: string): Single;
  public
    function GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: Double;
      const ASectionName, AGenre, ADrummer: string): Single;
  end;

  { TMacroComposer — manages groove library phases and variation cycling }
  TMacroComposer = class
  private
    FRng: TThreadedRandom;
    FLastGrooveIndex: Integer;
    procedure TrackGrooveSelection(Index: Integer);
  public
    constructor Create(ARngSeed: Integer);
    destructor Destroy; override;

    function DeterminePhase(ABarIndex: Integer; ABars: Integer): TMacroPhase;
    function SelectGroove(const Genre, SectionName: string; Phase: TMacroPhase;
      const Available: specialize TList<TPattern>; ARng: TThreadedRandom): TPattern;
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
  FHumanizer: TAdvancedHumanizer;
  FGMDPatternLibrary: TGMDPatternLibrary;
  FFixer: TPatternFixer;
  FPrevIndices: specialize TDictionary<string, specialize TList<Integer>>;

  { Helper methods }
  function GetSectionCurveMap(const Structure: array of TSectionDef): specialize TDictionary<string, Integer>;
  function ExtractPatternBar(APattern: TPattern; ABarIndex: Integer): TPattern;
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
  IntensityPt, Complexity, Dynamics: Double; const ADrummer: string;
  PreviousBars: specialize TList<TPattern>): TPattern;
begin
  if not Assigned(BasePattern) then
    Exit(nil);

  Result := BasePattern.Copy;
  Result := ApplyParameterModifications(Result, IntensityPt, Complexity, Dynamics);
end;

function TBarSelector.ApplyParameterModifications(APattern: TPattern;
  IntensityPt, Complexity, Dynamics: Double): TPattern;
var
  VelocityBias, NewVelocity: Integer;
  DynamicsScale, ComplexityScale: Double;
  Beat: TBeat;
begin
  Result := APattern;
  if not Assigned(Result) then
    Exit;

  ComplexityScale := 0.5 + EnsureRange(Complexity, 0.0, 1.0);
  DynamicsScale := EnsureRange(Dynamics, 0.0, 1.0) / 0.6;
  VelocityBias := Round(
    (EnsureRange(IntensityPt, 0.0, 1.0) - 0.5) * 20 * ComplexityScale);

  for Beat in Result.Beats do
  begin
    if Beat.Velocity <= 0 then
      Continue;
    NewVelocity := Round((Beat.Velocity + VelocityBias) * DynamicsScale);
    Beat.Velocity := Max(1, Min(127, NewVelocity));
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
  ABars: Integer; SectionName: string; out FillBarIndices: specialize TArray<Integer>;
  const IntensityValues: specialize TArray<Double>): specialize TList<TFill>;
var
  I: Integer;
begin
  Result := specialize TList<TFill>.Create;
  FillBarIndices := nil;
  { Place fills at musical boundaries using genre-aware fill selection }
  for I := 0 to ABars - 1 do
  begin
    if ShouldPlaceFill(I, ABars, SectionName, IntensityValues[I]) then
    begin
      SetLength(FillBarIndices, Length(FillBarIndices) + 1);
      FillBarIndices[High(FillBarIndices)] := I;
      Result.Add(TFill.Create(
        GenerateFillPattern(SelectFillType(Genre, SectionName, I, IntensityValues[I]), 1)
      ));
    end;
  end;
end;

function TFillPicker.ShouldPlaceFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string; IntensityPt: Double): Boolean;
begin
  // No fills at the end of an outro section — that would interrupt the fade-out
  if (ASectionName = 'outro') then Exit(false);

  // Fills belong at phrase boundaries, not at bar 0 or arbitrary midpoints
  // Bar N-1: last bar before section ends — universal fill location
  if (ABarIndex = ABars - 1) then Exit(true);
  
  // Bar N-2: second-to-last bar — common transition point to final fill
  if (ABarIndex = ABars - 2) then Exit(true);

  // Mid-section fills only at phrase boundaries (every 4 bars) AND at high intensity
  // This is where a drummer might place a "fill within the verse" before the chorus builds
  if ((ABars >= 8) and ((ABarIndex mod 4) = 3)) then
  begin
    // Only place mid-phrase fills when intensity justifies it (>0.6)
    Result := (IntensityPt > 0.6);
    Exit;
  end;

  // Intensity-gated random chance for jazz/funk — these genres use reactive fills
  // At high intensity (>0.75), jazz and funk drummers place fills reactively ~10% of the time
  if ((IntensityPt > 0.75) and (ABarIndex >= 2) and (ABarIndex < ABars - 1)) then
  begin
    case LowerCase(ASectionName) of
      'verse': Result := RandomRange(0, 100) < 8;   // 8% at high intensity for verse
      'chorus': Result := RandomRange(0, 100) < 5;  // 5% for chorus (already dense)
    else
      Result := false;
    end;
    Exit;
  end;

  Result := false;
end;

function TFillPicker.SelectFillType(const Genre: string; const SectionName: string; ABarIndex: Integer; IntensityPt: Double): String;
var
  LowerGenre, LowerSection: string;
begin
  LowerGenre := LowerCase(Genre);
  LowerSection := LowerCase(SectionName);

  // High-intensity fills get more aggressive types regardless of genre
  if (IntensityPt > 0.8) then
  begin
    case LowerGenre of
      'metal': Exit('blast_beat');
      'rock', 'punk': Exit('cymbal_crash');
      'jazz': Exit('snare_roll');
      'funk': Exit('tom_downfill');
      'electronic': Exit('cymbal_crash');
    end;
  end;

  // Genre-specific fill selection
  case LowerGenre of
    'metal':
      begin
        // Metal uses aggressive fills that match section context
        if (Pos('chorus', LowerSection) > 0) then
          Exit('blast_beat')
        else if (Pos('bridge', LowerSection) > 0) then
          Exit('ride_bell_sweep')
        else
          Exit('tom_downfill');
      end;
    'rock':
      begin
        // Rock fills are more traditional and contextual
        if (Pos('chorus', LowerSection) > 0) then
          Exit('snare_roll')
        else if (Pos('bridge', LowerSection) > 0) then
          Exit('tom_downfill')
        else
          Exit('cymbal_crash');
      end;
    'jazz':
      begin
        // Jazz uses subtler fills — ride bell sweeps and snare rolls
        if (Pos('chorus', LowerSection) > 0) then
          Exit('ride_bell_sweep')
        else
          Exit('snare_roll');
      end;
    'funk':
      begin
        // Funk uses tom fills and crash accents for the "one"
        if (Pos('chorus', LowerSection) > 0) then
          Exit('tom_downfill')
        else
          Exit('cymbal_crash');
      end;
    'electronic':
      begin
        // Electronic uses crash accents for impact
        Exit('cymbal_crash');
      end;
  else
    // Default — tom downfill is universally applicable
    Exit('tom_downfill');
  end;
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
        Result.AddBeat(0.0, TInstrumentRegistry.Get('tom_4_open_hit'), 100);
        Result.AddBeat(1.0, TInstrumentRegistry.Get('tom_3_open_hit'), 95);
        Result.AddBeat(2.0, TInstrumentRegistry.Get('tom_2_open_hit'), 90);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('tom_1_open_hit'), 105);
      end;
    'tom_upfill':
      begin
        // Ascending tom fill (tom_1 -> tom_4)
        Result.AddBeat(0.0, TInstrumentRegistry.Get('tom_1_open_hit'), 95);
        Result.AddBeat(1.0, TInstrumentRegistry.Get('tom_2_open_hit'), 100);
        Result.AddBeat(2.0, TInstrumentRegistry.Get('tom_3_open_hit'), 95);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('tom_4_open_hit'), 110);
      end;
    'blast_beat':
      begin
        // Blast beat (rapid snare/kick alternation)
        for I := 0 to 15 do
          if ((I mod 2) = 0) then
            Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 110)
          else
            Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('kick'), 105);
      end;
    'ride_bell_sweep':
      begin
        // Ride bell sweep with snare accents
        for I := 0 to 7 do
          Result.AddBeat(I * 0.5, TInstrumentRegistry.Get('ride_1_bell'), 80);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 115);
      end;
    'snare_roll':
      begin
        // Snare roll (gradual crescendo)
        for I := 0 to 7 do
          Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 60 + I * 8);
      end;
    'cymbal_crash':
      begin
        // Crash accent pattern
        Result.AddBeat(0.0, TInstrumentRegistry.Get('cymbal_1_hit'), 120);
        Result.AddBeat(2.0, TInstrumentRegistry.Get('ride_1_tip_hit_softer'), 90);
        Result.AddBeat(3.0, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 110);
      end;
  else
    // Default fill — basic tom downfill
    Result.AddBeat(0.0, TInstrumentRegistry.Get('tom_4_open_hit'), 95);
    Result.AddBeat(1.0, TInstrumentRegistry.Get('tom_3_open_hit'), 90);
    Result.AddBeat(2.0, TInstrumentRegistry.Get('tom_2_open_hit'), 85);
    Result.AddBeat(3.0, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 110);
  end;

  Result.Metadata.Add('bars_to_fill', IntToStr(ABarsToFill));
end;

{ TGrooveEngine — Microtiming groove offsets per bar }

function TGrooveEngine.GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: Double;
  const ASectionName, AGenre, ADrummer: string): Single;
var
  DrummerBias: Single;
  SectionContext: Single;
  MicrotimingMod: Single;
begin
  if ATempo <= 0 then
    Exit(0);

  // Get drummer-specific groove bias (positive = behind beat, negative = push forward)
  DrummerBias := GetDrummerGrooveBias(ADrummer);

  // Get section-specific groove context
  SectionContext := GetSectionGrooveContext(ASectionName, AGenre);

  // Bias values are fractions of a beat; convert once to bounded milliseconds.
  MicrotimingMod := (ABarIndex mod 4) * 0.005;
  Result := DrummerBias + SectionContext + MicrotimingMod * IntensityPt;
  Result := EnsureRange(Result * (60000.0 / ATempo), -25.0, 25.0);
end;

function TGrooveEngine.GetDrummerGrooveBias(const ADrummer: string): Single;
var
  DrummerLower: AnsiString;
begin
  // Return groove bias value per drummer style
  DrummerLower := LowerCase(ADrummer);
  case DrummerLower of
    'bonham': Exit(0.025);
    'porcaro': Exit(-0.010);
    'weckl': Exit(0.005);
    'chambers': Exit(-0.005);
    'carey': Exit(0.015);
    'peart': Exit(0.0);
    'hoglan': Exit(-0.002);
    'copeland': Exit(0.020);
    else Exit(0.005);
  end;
end;

function TGrooveEngine.GetSectionGrooveContext(const ASectionName, AGenre: string): Single;
begin
  // Adjust groove context based on section type and genre
  if (Pos('intro', LowerCase(ASectionName)) > 0) then Exit(-0.015);
  if (Pos('chorus', LowerCase(ASectionName)) > 0) then Exit(0.010);
  if (Pos('breakdown', LowerCase(ASectionName)) > 0) then Exit(0.005);
  if (Pos('bridge', LowerCase(ASectionName)) > 0) then Exit(-0.020);

  case LowerCase(AGenre) of
    'funk': Exit(0.015);
    'jazz': Exit(0.020);
    'metal': Exit(-0.005);
    else Exit(0.0);
  end;
end;

{ TMacroComposer — Groove library phase management }

constructor TMacroComposer.Create(ARngSeed: Integer);
begin
  FRng := TThreadedRandom.Create(QWord(ARngSeed));
  FLastGrooveIndex := -1;
end;

destructor TMacroComposer.Destroy;
begin
  FRng.Free;
  inherited Destroy;
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
  const Available: specialize TList<TPattern>; ARng: TThreadedRandom): TPattern;
var
  Idx: Integer;
begin
  { The macro phase decides which groove of the section's library plays, so
    the song has a purposeful shape (establish -> maintain -> build ->
    turnaround) instead of a random pick per phrase. }
  Result := nil;
  if (Available = nil) or (Available.Count = 0) then
    Exit;

  case Phase of
    mpEstablish:
      begin
        { The opening of a section states the groove plainly, so the listener
          can lock onto it — always the first flavour. }
        Idx := 0;
      end;
    mpMaintain:
      begin
        { The body of a section rotates through the library and never repeats
          the groove that was just used. }
        Idx := GetNextGrooveIndex(Available.Count);
      end;
    mpBuild:
      begin
        { The build pushes towards the densest groove in the library. }
        Idx := Available.Count - 1;
      end;
    mpTurnaround:
      begin
        { A turnaround breaks out of the rotation so the section can change
          gear. }
        Idx := ARng.NextInt(Available.Count);
      end;
  else
    Idx := GetNextGrooveIndex(Available.Count);
  end;

  if (Idx < 0) or (Idx >= Available.Count) then
    Idx := 0;

  { The returned pattern is owned by the caller's list — it must NOT be freed
    by the macro composer. }
  Result := Available[Idx];
end;

function TMacroComposer.GetNextGrooveIndex(GrooveCount: Integer): Integer;
begin
  { With a single groove there is nothing to alternate to — returning the
    only index avoids an infinite loop in the repeat/until below. }
  if GrooveCount <= 1 then
  begin
    Result := 0;
    TrackGrooveSelection(Result);
    Exit;
  end;

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
  FGMDPatternLibrary := TGMDPatternLibrary.Create;
  FRng := TThreadedRandom.Create(QWord(ARngSeed));
  RandSeed := ARngSeed;
  FBarSelector := TBarSelector.Create;
  FFilPicker := TFillPicker.Create;
  FGrooveEngine := TGrooveEngine.Create;
  FHumanizer := TAdvancedHumanizer.Create;
  FFixer := TPatternFixer.Create;
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
  FHumanizer.Free;
  FGMDPatternLibrary.Free;
  FFixer.Free;
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
  MacroComposer: TMacroComposer;
  BarIndex: Integer;
  IntensityPt: Double;
  Phase: TMacroPhase;
  BasePattern: TPattern;
  DrummedPattern: TPattern;
  BarSourcePattern: TPattern;
  FinalPattern: TPattern;
  FixedPattern: TPattern;
  HumanizedPattern: TPattern;
  CurrentPattern: TPattern;
  CurrentPatternOwned: Boolean;
  CurrentPhraseStartBar: Integer;
  NextPhraseBar: Integer;
  PhraseBars: Integer;
  HumanizationContext: THumanizationContext;
  Combined: TPattern;
  Fills: specialize TList<TFill>;
  SignatureFills: specialize TList<TFill>;
  SignatureFill: TFill;
  FillBarIndices: specialize TArray<Integer>;
  SectionIntensities: specialize TArray<Double>;
  MinIntensityRange, MaxIntensityRange: Double;
  AllDrummers: specialize TArray<string>;
  PreferredForGenre: specialize TList<string>;
  PreferredDrummers: specialize TArray<string>;
  I, J: Integer;
  DrummerPlugin: TObject;
  SectionDef: TSectionDef;
  FGenrePlugin: TGenrePlugin;
  Flavors: specialize TList<TPattern>;
  GMDFlavors: specialize TList<TPattern>;
  Available: specialize TList<TPattern>;
  FlavorItem: TPattern;
  OffsetMs: Single;
  JBar: Integer;
  Idx: Integer;
  Section: TSection;
begin
  if not Assigned(FPluginManager.Registry.GetGenrePlugin(Genre)) then
    raise Exception.CreateFmt('Unsupported genre: %s', [Genre]);
  FGenrePlugin := TGenrePlugin(FPluginManager.Registry.GetGenrePlugin(Genre));
  if (Style <> '') and not FGenrePlugin.SupportsStyle(Style) then
    raise Exception.CreateFmt('Unsupported style "%s" for genre "%s".',
      [Style, FGenrePlugin.GetGenreName]);
  if (ADrummer <> '') and
     not Assigned(FPluginManager.Registry.GetDrummerPlugin(ADrummer)) then
    raise Exception.CreateFmt('Unknown drummer: %s', [ADrummer]);

  { Create generation parameters }
  Params := TGenerationParameters.Create(
    Genre, Style, ADrummer, AComplexity, ADynamics, AHumanization);

  { Auto-select a random preferred drummer when none is specified }
  if ADrummer = '' then
  begin
    AllDrummers := FPluginManager.Registry.GetAvailableDrummers;
    PreferredDrummers := FPluginManager.Registry.GetPreferredDrummersForGenre(Genre);
    PreferredForGenre := specialize TList<string>.Create;
    try
      for J := 0 to Length(PreferredDrummers) - 1 do
      begin
        DrummerPlugin := FPluginManager.Registry.GetDrummerPlugin(PreferredDrummers[J]);
        if not Assigned(DrummerPlugin) or not (DrummerPlugin is TDrummerPlugin) then
          raise Exception.CreateFmt(
            'Genre %s references unavailable drummer plugin %s',
            [Genre, PreferredDrummers[J]]);
        PreferredForGenre.Add(PreferredDrummers[J]);
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
    Flavors := nil;
    GMDFlavors := nil;
    Available := nil;
    Fills := nil;
    CurrentPattern := nil;
    CurrentPatternOwned := False;
    MacroComposer := nil;
    try
      { Get genre plugin }
      FGenrePlugin := TGenrePlugin(FPluginManager.Registry.GetGenrePlugin(Genre));
      if not Assigned(FGenrePlugin) then
        Continue;

      { Calculate section intensity range from curve map for flavor filtering }
      MinIntensityRange := 1.0;
      MaxIntensityRange := 0.0;
      for JBar := 0 to Bars - 1 do
      begin
        MinIntensityRange := Min(MinIntensityRange, GetIntensityPt(CurveMap, SectionName, JBar, Bars));
        MaxIntensityRange := Max(MaxIntensityRange, GetIntensityPt(CurveMap, SectionName, JBar, Bars));
      end;

      { Load section patterns — intensity-aware flavor selection }
      FGenrePlugin := TGenrePlugin(FPluginManager.Registry.GetGenrePlugin(Genre));
      if not Assigned(FGenrePlugin) then
        Continue;

      { Load section patterns — intensity-aware flavor selection }
      Flavors := FGenrePlugin.GetSectionFlavorsFiltered(SectionName, Params, MinIntensityRange, MaxIntensityRange);
      if not Assigned(Flavors) then
        Flavors := specialize TList<TPattern>.Create;
      GMDFlavors := FGMDPatternLibrary.GetPatterns(
        Genre, Style, 'beat', Song.TimeSignature.Numerator,
        Song.TimeSignature.Denominator);
      try
        for Idx := 0 to GMDFlavors.Count - 1 do
        begin
          FlavorItem := GMDFlavors[Idx];
          try
            Flavors.Add(FGenrePlugin.AdaptExternalPattern(FlavorItem, Params));
          finally
            FlavorItem.Free;
            GMDFlavors[Idx] := nil;
          end;
        end;
      finally
        for FlavorItem in GMDFlavors do
          FlavorItem.Free;
        GMDFlavors.Free;
        GMDFlavors := nil;
      end;

      Available := specialize TList<TPattern>.Create;
      for FlavorItem in Flavors do
        if Assigned(FlavorItem) then
          Available.Add(FlavorItem);

      { Macro-composer phase tracking }
      MacroComposer := TMacroComposer.Create(FRng.NextInt(10000));
      NextPhraseBar := 0;
      CurrentPhraseStartBar := 0;

      for BarIndex := 0 to Bars - 1 do
      begin
        { Get intensity point for this bar position }
        IntensityPt := GetIntensityPt(CurveMap, SectionName, BarIndex, Bars);

        { Determine macro-composer phase for purposeful variation }
        Phase := MacroComposer.DeterminePhase(BarIndex, Bars);

        if BarIndex >= NextPhraseBar then
        begin
          if CurrentPatternOwned and Assigned(CurrentPattern) then
            CurrentPattern.Free;
          CurrentPattern := nil;
          CurrentPatternOwned := False;

          { Phase-aware groove selection — the macro phase decides which
            flavour of the section's library the phrase plays. }
          if Available.Count > 0 then
            CurrentPattern := MacroComposer.SelectGroove(Genre, SectionName,
              Phase, Available, FRng);
          if not Assigned(CurrentPattern) then
          begin
            CurrentPattern := FGenrePlugin.GeneratePattern(SectionName, Params);
            CurrentPatternOwned := Assigned(CurrentPattern);
          end;

          if Assigned(CurrentPattern) then
          begin
            CurrentPhraseStartBar := BarIndex;
            PhraseBars := Max(1, Ceil(CurrentPattern.DurationBars));
            NextPhraseBar := BarIndex + PhraseBars;
          end
          else
            NextPhraseBar := BarIndex + 1;
        end;

        BasePattern := CurrentPattern;
        DrummedPattern := nil;
        BarSourcePattern := nil;
        if not Assigned(BasePattern) then
          Continue;

        { Apply drummer style to the selected phrase, then extract its current bar. }
        DrummedPattern := BasePattern;
        if ADrummer <> '' then
        begin
          DrummerPlugin := FPluginManager.Registry.GetDrummerPlugin(ADrummer);
          if Assigned(DrummerPlugin) then
            DrummedPattern := (DrummerPlugin as TDrummerPlugin).
              ApplyStyleForContext(BasePattern, Genre, Style, ATempo);
        end;

        try
          BarSourcePattern := ExtractPatternBar(
            DrummedPattern, BarIndex - CurrentPhraseStartBar);
        finally
          if Assigned(DrummedPattern) and (DrummedPattern <> BasePattern) then
            DrummedPattern.Free;
        end;
        try
          FinalPattern := FBarSelector.GenerateForBar(
            BarSourcePattern, BarIndex, Bars, IntensityPt, Params.Complexity,
            Params.Dynamics, ADrummer, GeneratedBars);
        finally
          BarSourcePattern.Free;
        end;
        { Physically-playable constraint pass — remove hits a human could not
          actually play (two hits on the same hand at the same instant, more
          than three simultaneous hits, impossibly fast repeats on one limb).
          The fixer returns the same object when nothing had to be removed. }
        FixedPattern := FFixer.Fix(FinalPattern);
        if FixedPattern <> FinalPattern then
        begin
          FinalPattern.Free;
          FinalPattern := FixedPattern;
        end;
        if Params.Humanization > 0 then
        begin
          HumanizationContext.Genre := Genre;
          HumanizationContext.Style := Style;
          HumanizationContext.Section := SectionName;
          HumanizationContext.Complexity := Params.Complexity;
          HumanizationContext.Intensity := IntensityPt;
          HumanizationContext.Humanization := Params.Humanization;
          HumanizationContext.Tempo := ATempo;
          HumanizationContext.SourceRandom := FRng;
          try
            HumanizedPattern := FHumanizer.Apply(FinalPattern, HumanizationContext);
          finally
            FinalPattern.Free;
          end;
          FinalPattern := HumanizedPattern;
        end;
        GeneratedBars.Add(FinalPattern);
      end;

      { Combine bars into a section }
      Combined := nil;
      if GeneratedBars.Count > 0 then
        CombineBarPatterns(GeneratedBars, Combined);

      { Precompute per-bar intensity values for the fill picker }
      SetLength(SectionIntensities, Bars);
      for JBar := 0 to Bars - 1 do
        SectionIntensities[JBar] := GetIntensityPt(CurveMap, SectionName, JBar, Bars);
      {
        Determine fill placement based on section context using precomputed intensities
      }
      Fills := FFilPicker.PickFillsForSection(
        Genre, Params, Bars, SectionName, FillBarIndices, SectionIntensities);
      GMDFlavors := FGMDPatternLibrary.GetPatterns(
        Genre, Style, 'fill', Song.TimeSignature.Numerator,
        Song.TimeSignature.Denominator);
      try
        for FlavorItem in GMDFlavors do
          if (FlavorItem.DurationBars <= Bars) and
             (FlavorItem.Beats.Count > 0) then
            Fills.Add(TFill.Create(FlavorItem.Copy));
      finally
        for FlavorItem in GMDFlavors do
          FlavorItem.Free;
        GMDFlavors.Free;
        GMDFlavors := nil;
      end;
      if ADrummer <> '' then
      begin
        DrummerPlugin := FPluginManager.Registry.GetDrummerPlugin(ADrummer);
        if Assigned(DrummerPlugin) and (DrummerPlugin is TDrummerPlugin) then
        begin
          SignatureFills := (DrummerPlugin as TDrummerPlugin).GetSignatureFills;
          if Assigned(SignatureFills) then
            try
              for SignatureFill in SignatureFills do
                if Assigned(SignatureFill.Pattern) and
                   (SignatureFill.Pattern.Beats.Count > 0) then
                  Fills.Add(TFill.Create(SignatureFill.Pattern.Copy));
            finally
              for Idx := SignatureFills.Count - 1 downto 0 do
                SignatureFills[Idx].Free;
              SignatureFills.Free;
            end;
        end;
      end;

      { Calculate groove timing offsets per bar }
      Section := TSection.Create(SectionName, Combined, Bars);
      Section.SetFillBars(FillBarIndices);
      Section.Fills.Free;
      Section.Fills := Fills;
      Fills := nil;
      if ADrummer <> '' then
        for JBar := 0 to Bars - 1 do
        begin
          IntensityPt := GetIntensityPt(CurveMap, SectionName, JBar, Bars);
          OffsetMs := FGrooveEngine.GetBarOffsetMs(
            JBar, ATempo, IntensityPt, SectionName, Genre, ADrummer);
          Section.GrooveOffsetsMs.Add(OffsetMs);
        end;
      if Section.GrooveOffsetsMs.Count = 0 then
        for JBar := 0 to Bars - 1 do
          Section.GrooveOffsetsMs.Add(0.0);
      Song.Sections.Add(Section);
    finally
      if Assigned(MacroComposer) then
        MacroComposer.Free;
      if Assigned(GMDFlavors) then
      begin
        for FlavorItem in GMDFlavors do
          FlavorItem.Free;
        GMDFlavors.Free;
      end;
      if Assigned(Fills) then
      begin
        for Idx := Fills.Count - 1 downto 0 do
          Fills[Idx].Free;
        Fills.Free;
      end;
      if CurrentPatternOwned and Assigned(CurrentPattern) then
        CurrentPattern.Free;
      if Assigned(Available) then
        Available.Free;
      if Assigned(Flavors) then
      begin
        for FlavorItem in Flavors do
          if Assigned(FlavorItem) then
            FlavorItem.Free;
        Flavors.Free;
      end;
      for Idx := GeneratedBars.Count - 1 downto 0 do
        GeneratedBars[Idx].Free;
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
      Result.AddOrSetValue(SectionName, Ord(icAscending))
    else if (Pos('verse', SectionName) = 1) and (Pos('chorus', PrevSection) = 1) then
      Result.AddOrSetValue(SectionName, Ord(icDipRise))
    else if Pos('chorus', SectionName) = 1 then
      Result.AddOrSetValue(SectionName, Ord(icPlateau))
    else if Pos('bridge', SectionName) = 1 then
      if Pos('chorus', NextSection) = 1 then
        Result.AddOrSetValue(SectionName, Ord(icDipRise))
      else
        Result.AddOrSetValue(SectionName, Ord(icDescending))
    else if Pos('breakdown', SectionName) = 1 then
      Result.AddOrSetValue(SectionName, Ord(icDipRise))
    else if Pos('outro', SectionName) = 1 then
      Result.AddOrSetValue(SectionName, Ord(icDescending))
    else
      Result.AddOrSetValue(SectionName, Ord(icPlateau)); { default }
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

function TComposerV2.ExtractPatternBar(APattern: TPattern; ABarIndex: Integer): TPattern;
var
  BarLength, PatternBars, BarStart, BarEnd: Double;
  SourceBar, I, FallbackBar: Integer;
  Beat: TBeat;

  function BarHoldsNotes(ABarStart, ABarEnd: Double): Boolean;
  var
    B: TBeat;
  begin
    for B in APattern.Beats do
      if (B.Position >= ABarStart) and (B.Position < ABarEnd) then
        Exit(True);
    Result := False;
  end;

begin
  if not Assigned(APattern) then
    Exit(nil);

  BarLength := APattern.TimeSignature.BeatsPerBar;
  PatternBars := APattern.DurationBars;
  if (BarLength <= 0) or (PatternBars < 1) then
    raise Exception.CreateFmt('Pattern %s has invalid bar length or duration',
      [APattern.Name]);

  SourceBar := ABarIndex mod Trunc(PatternBars);

  { A bar with no notes would be a silent bar in the output. The GMD corpus
    can capture a phrase whose material starts after the first bar, so the
    bar this phrase lands on may hold nothing. Fall back to the first bar
    that does hold notes rather than emitting silence. }
  if not BarHoldsNotes(SourceBar * BarLength, (SourceBar + 1) * BarLength) then
    for FallbackBar := 0 to Trunc(PatternBars) - 1 do
      if BarHoldsNotes(FallbackBar * BarLength, (FallbackBar + 1) * BarLength) then
      begin
        SourceBar := FallbackBar;
        Break;
      end;

  BarStart := SourceBar * BarLength;
  BarEnd := BarStart + BarLength;
  Result := APattern.Copy;
  for I := Result.Beats.Count - 1 downto 0 do
  begin
    Beat := Result.Beats[I];
    if (Beat.Position < BarStart) or (Beat.Position >= BarEnd) then
    begin
      Beat.Free;
      Result.Beats.Delete(I);
    end
    else
      Beat.Position := Beat.Position - BarStart;
  end;
  Result.Name := APattern.Name + '_bar' + IntToStr(ABarIndex);
  Result.Metadata.AddOrSetValue('phrase_bars', '1');
end;

procedure TComposerV2.CombineBarPatterns(const GeneratedBars: specialize TList<TPattern>; out Combined: TPattern);
var
  TargetPattern: TPattern;
  Bar: TPattern;
  IBeat: Integer;
  Beat: TBeat;
  NewBeat: TBeat;
  Offset: Double;
  InstName: string;
//  DebugF: TextFile;
begin
  // Debug output for diagnosis
  //AssignFile(DebugF, 'combine_debug.txt');
  //Rewrite(DebugF);
  //WriteLn(DebugF, '[CombineBarPatterns] input_bars=' + IntToStr(GeneratedBars.Count));
  if not Assigned(GeneratedBars) or (GeneratedBars.Count = 0) then
    Exit;

  TargetPattern := GeneratedBars[0].Copy;
  //WriteLn(DebugF, '  bar0 beats:');
  for Beat in GeneratedBars[0].Beats do
  begin
    if Assigned(Beat.Instrument) then
      InstName := Beat.Instrument.Name
    else
      InstName := '(nil)';
  //  WriteLn(DebugF, '    beat[' + FloatToStr(Beat.Position) + '] name=' + InstName);
  end;

  for IBeat := 1 to GeneratedBars.Count - 1 do
  begin
    { Add beats from subsequent bars, offsetting positions. }
    Offset := IBeat * TargetPattern.TimeSignature.BeatsPerBar;
  //  WriteLn(DebugF, '  bar' + IntToStr(IBeat) + ' beats:');
    for Beat in GeneratedBars[IBEat].Beats do
    begin
      if Assigned(Beat.Instrument) then
        InstName := Beat.Instrument.Name
      else
        InstName := '(nil)';
   //   WriteLn(DebugF, '    beat[' + FloatToStr(Beat.Position + Offset) + '] name=' + InstName);
      TargetPattern.AddBeat(Beat.Position + Offset, Beat.Instrument, Beat.Velocity);
      NewBeat := TargetPattern.Beats[TargetPattern.Beats.Count - 1];
      NewBeat.Duration := Beat.Duration;
      NewBeat.GhostNote := Beat.GhostNote;
      NewBeat.Accent := Beat.Accent;
      NewBeat.InstrumentPromoted := Beat.InstrumentPromoted;
    end;
  end;

  TargetPattern.Metadata.AddOrSetValue('phrase_bars', IntToStr(GeneratedBars.Count));

//  WriteLn(DebugF, '  combined beats:');
  for Beat in TargetPattern.Beats do
  begin
    if Assigned(Beat.Instrument) then
      InstName := Beat.Instrument.Name
    else
      InstName := '(nil)';
 //   WriteLn(DebugF, '    beat[' + FloatToStr(Beat.Position) + '] name=' + InstName);
  end;

  Combined := TargetPattern;
end;

end.
