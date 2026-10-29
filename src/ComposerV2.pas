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
  GMDPatternLibrary, LimbConstraints, PatternFixer, DrummerProfiles,
  patterns_templates;

type
  { Structure entry type for song sections - must match DrumGenerator.TStructureEntry }
  TSectionDef = record
    Name: string;
    Bars: Integer;
    { Tempo of this section in BPM; 0 = inherit the song tempo. }
    Tempo: Integer;
    { Complexity of this section; only used when HasComplexity is set, so a
      zero-filled record (the default) inherits the song's complexity. }
    HasComplexity: Boolean;
    Complexity: Double;
    { Meter of this section (7/8: 7 and 8); 0 = the song's meter. }
    MeterNum, MeterDen: Integer;
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
    function GetSectionGrooveContext(const ASectionName: string; ABars: Integer): String;
  public
    function SelectPatternForPhrase(const Available: specialize TList<TPattern>;
      PhraseIndex: Integer; IntensityPt: Double; Phase: TMacroPhase;
      PreviousPattern: TPattern; ARng: TThreadedRandom): TPattern;
    function GenerateForBar(BasePattern: TPattern; ABarIndex: Integer; ABars: Integer;
      IntensityPt, Complexity, Dynamics: Double; const ADrummer: string;
      PreviousBars: specialize TList<TPattern>): TPattern;
  end;

  { TFillPicker — determines fill placement and type }
  TFillPicker = class
  private
    function IsStructuralFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string; IntensityPt: Double): Boolean;
    function IsReactiveFill(const Genre: string; ABarIndex: Integer; ABars: Integer; const ASectionName: string; IntensityPt: Double): Boolean;
    function SelectFillType(const Genre: string; const SectionName: string; ABarIndex: Integer; IntensityPt: Double): String;
    function GenerateFillPattern(FillType: String; ABarsToFill: Integer; AFullBar: Boolean): TPattern;
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
      const Available: specialize TList<TPattern>; const BarIntensity: Double; ARng: TThreadedRandom): TPattern;
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
    AHumanization: Double = 0.5; ASwing: Double = 0.0;
    ASongMeterNum: Integer = 4; ASongMeterDen: Integer = 4;
    AStrictMeter: Boolean = False): TSong;

  property PluginManager: PluginRegistry.TPluginManager read FPluginManager write FPluginManager;
end;

implementation

{ TBarSelector — Bar-level pattern selection and modulation }

function TBarSelector.SelectPatternForPhrase(const Available: specialize TList<TPattern>;
  PhraseIndex: Integer; IntensityPt: Double; Phase: TMacroPhase;
  PreviousPattern: TPattern; ARng: TThreadedRandom): TPattern;
{ A weighted random draw, not a rotation: every groove that suits the bar has a
  chance, the ones that fit its intensity best have the most, the one that
  just played has little (so it can still return, but rarely), and the phase
  leans the draw: establishing favours the lightest groove, a build the
  heaviest. }
var
  Weights: array of Double;
  I, Heaviest, Lightest: Integer;
  PMin, PMax, PMid, MidOfHeaviest, MidOfLightest, Total, Pick, Sum: Double;
begin
  Result := nil;
  if not Assigned(Available) or (Available.Count = 0) then
    Exit;
  if Available.Count = 1 then
    Exit(Available[0]);

  SetLength(Weights, Available.Count);
  Heaviest := 0;
  Lightest := 0;
  MidOfHeaviest := -1;
  MidOfLightest := 2;
  for I := 0 to Available.Count - 1 do
  begin
    TryGetIntensityRange(Available[I], PMin, PMax);
    WriteLn(Format('ComposerV2.SelectPatternForPhrase: about to compute PMid = (PMin + PMax) / 2.0 = (%f + %f) / 2.0', [PMin, PMax]));
    PMid := (PMin + PMax) / 2.0;
    WriteLn(Format('ComposerV2.SelectPatternForPhrase: PMid = %f', [PMid]));
    if PMid > MidOfHeaviest then begin MidOfHeaviest := PMid; Heaviest := I; end;
    if PMid < MidOfLightest then begin MidOfLightest := PMid; Lightest := I; end;
    { 1.0 at the middle of the groove's band, falling to 0.1 a quarter away
      and below; a groove that does not suit the bar at all keeps a small
      chance, so nothing is ever shut out. }
    Weights[I] := Max(0.1, 1.0 - Abs(PMid - IntensityPt) * 3.0);
    if (IntensityPt >= PMin) and (IntensityPt <= PMax) then
      Weights[I] := Weights[I] + 0.5;
    if Available[I] = PreviousPattern then
      Weights[I] := Weights[I] * 0.25;
  end;

  case Phase of
    mpEstablish: Weights[Lightest] := Weights[Lightest] * 2.0;
    mpBuild: Weights[Heaviest] := Weights[Heaviest] * 2.0;
  end;

  Total := 0;
  for I := 0 to High(Weights) do
    Total := Total + Weights[I];
  Pick := ARng.NextDouble * Total;
  Sum := 0;
  for I := 0 to High(Weights) do
  begin
    Sum := Sum + Weights[I];
    if Pick < Sum then
      Exit(Available[I]);
  end;
  Result := Available[Available.Count - 1];
end;

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

{ How well a fill suits the energy of its bar: 1.2 for a perfect match down
  to 0.2. A fill without a declared energy suits every bar equally. }
function FillEnergyWeight(AFill: TFill; ABarIntensity: Double): Double;
begin
  if AFill.Energy < 0 then
    Exit(0.7);
  Result := 0.2 + (1.0 - Abs(AFill.Energy - ABarIntensity));
end;

{ Relative weight of a drummer's fill slot for a section kind and energy:
  slot 0 short, slot 1 half bar, slot 2 big. }
function DrummerFillSlotWeight(ASlot: Integer; const AKind: string;
  AIntensity: Double): Double;
begin
  case ASlot of
    0: if AIntensity < 0.5 then Result := 3.0 else Result := 1.5;
    1: Result := 2.0;
  else
    if (AKind = 'chorus') or (AIntensity > 0.8) then
      Result := 3.0
    else if AIntensity > 0.6 then
      Result := 1.5
    else
      Result := 0.5;
  end;
end;

{ TFillPicker — Fill placement and type determination }

function TFillPicker.PickFillsForSection(const Genre: string; const Params: TGenerationParameters;
  ABars: Integer; SectionName: string; out FillBarIndices: specialize TArray<Integer>;
  const IntensityValues: specialize TArray<Double>): specialize TList<TFill>;
var
  I: Integer;
  Placed: array of Boolean;
begin
  Result := specialize TList<TFill>.Create;
  FillBarIndices := nil;
  SetLength(Placed, Max(ABars, 0));

  { Pass 1 - structural fills: the transition into the next section and,
    in long sections, the end of a phrase. These always win. }
  for I := 0 to ABars - 1 do
    Placed[I] := IsStructuralFill(I, ABars, SectionName, IntensityValues[I]);

  { Pass 2 - reactive fills (jazz/funk only), never next to another fill. }
  for I := 1 to ABars - 2 do
    if (not Placed[I]) and (not Placed[I - 1]) and (not Placed[I + 1]) and
       IsReactiveFill(Genre, I, ABars, SectionName, IntensityValues[I]) then
      Placed[I] := True;

  for I := 0 to ABars - 1 do
    if Placed[I] then
    begin
      SetLength(FillBarIndices, Length(FillBarIndices) + 1);
      FillBarIndices[High(FillBarIndices)] := I;
      { A fill only takes over the whole bar when the music is at full
        energy; otherwise it fills the last two beats and the groove
        keeps playing before it. The built-in generic fills are written
        for 4/4; another meter gets a tom run that fits its bar. }
      if (Params.MeterNum <> 4) or (Params.MeterDen <> 4) then
        Result.Add(TFill.Create(BuildMeterFallbackFill('fill_' +
          IntToStr(Params.MeterNum) + '_' + IntToStr(Params.MeterDen),
          Params.MeterNum, Params.MeterDen, IntensityValues[I] > 0.8)))
      else
        Result.Add(TFill.Create(GenerateFillPattern(
          SelectFillType(Genre, SectionName, I, IntensityValues[I]), 1,
          IntensityValues[I] > 0.8)));
      Result[Result.Count - 1].TargetBar := I;
    end;
end;

function TFillPicker.IsStructuralFill(ABarIndex: Integer; ABars: Integer; const ASectionName: string; IntensityPt: Double): Boolean;
begin
  Result := False;

  { A fill announces a transition. The outro fades out, and a one-bar
    section has no room for a fill that is not the whole section. }
  if Pos('outro', LowerCase(ASectionName)) > 0 then Exit;
  if ABars < 2 then Exit;

  { Drummers do not fill where a phrase starts. }
  if ABarIndex = 0 then Exit;

  { The last bar leads into the next section - the one mandatory fill. }
  if ABarIndex = ABars - 1 then Exit(True);

  { Never a second fill right before that one. }
  if ABarIndex = ABars - 2 then Exit;

  { In long sections the end of a four-bar phrase gets a fill too, but only
    when the energy justifies it. }
  if (ABars >= 8) and ((ABarIndex mod 4) = 3) then
    Result := IntensityPt > 0.6;
end;

function TFillPicker.IsReactiveFill(const Genre: string; ABarIndex: Integer; ABars: Integer; const ASectionName: string; IntensityPt: Double): Boolean;
const
  THRESHOLD = 0.7;
  MAX_CHANCE = 0.15;
begin
  Result := False;

  { Jazz and funk drummers react to what is happening and drop fills in
    spontaneously at high energy. Metal and rock fill on the structure only. }
  if not (SameText(Genre, 'jazz') or SameText(Genre, 'funk')) then Exit;
  if Pos('outro', LowerCase(ASectionName)) > 0 then Exit;
  if (ABars < 4) or (ABarIndex < 1) or (ABarIndex >= ABars - 1) then Exit;
  if (ABarIndex mod 4) = 0 then Exit;
  if IntensityPt <= THRESHOLD then Exit;

  { 0 at the threshold, 15 percent at full intensity. }
  if THRESHOLD >= 1.0 then
    Result := False
  else
  begin
    WriteLn(Format('TFillPicker.SelectFillType: about to compute (IntensityPt - THRESHOLD) / (1.0 - THRESHOLD) = (%f - %f) / (1.0 - %f)', [IntensityPt, THRESHOLD, THRESHOLD]));
    Result := Random < MAX_CHANCE * (IntensityPt - THRESHOLD) / (1.0 - THRESHOLD);
    WriteLn(Format('TFillPicker.SelectFillType: Result=%f', [Result]));
  end;
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

{ Squeezes a one-bar fill into the last two beats of the bar. }
procedure ShortenFillToLastBeats(APattern: TPattern; const AFillType: string);
var
  I: Integer;
  Beat: TBeat;
begin
  for I := APattern.Beats.Count - 1 downto 0 do
  begin
    Beat := APattern.Beats[I];
    if (AFillType = 'tom_downfill') or (AFillType = 'tom_upfill') then
      Beat.Position := 2.0 + Beat.Position * 0.5
    else if AFillType = 'snare_roll' then
      Beat.Position := 2.0 + Beat.Position
    else if Beat.Position < 2.0 then
    begin
      Beat.Free;
      APattern.Beats.Delete(I);
    end;
  end;
end;

function TFillPicker.GenerateFillPattern(FillType: String; ABarsToFill: Integer; AFullBar: Boolean): TPattern;
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

  { A crash belongs on the next downbeat, never on the first beat of the
    bar before it. }
  if (not AFullBar) or (FillType = 'cymbal_crash') then
    ShortenFillToLastBeats(Result, FillType);

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
begin
  { Per-drummer bias comes from config/drummer_profiles.ini; the loader
    falls back to built-in values when the file is missing. }
  Result := GetDrummerProfile(ADrummer).GrooveBias;
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
  const Available: specialize TList<TPattern>; const BarIntensity: Double; ARng: TThreadedRandom): TPattern;
var
  Idx: Integer;
  Compatible: specialize TList<TPattern>;
  CI: Integer;
  PMin, PMax, PMid: Double;
begin
  { Filter patterns by intensity compatibility for this specific bar.
    Only patterns whose valid_intensity_mid falls within the bar's intensity
    (with 0.15 buffer) are eligible. This ensures per-bar pattern variation.
    Phase then picks from this filtered set. }
  Compatible := specialize TList<TPattern>.Create;
  try
    for CI := 0 to Available.Count - 1 do
    begin
      PMin := 0.0; PMax := 1.0; PMid := 0.5;
      if TryGetIntensityRange(Available[CI], PMin, PMax) then
      begin
        PMid := (PMin + PMax) / 2.0;
        { Check overlap with bar intensity using a tolerance band. }
        if (PMid >= BarIntensity - 0.15) and (PMid <= BarIntensity + 0.15) then
          Compatible.Add(Available[CI]);
      end;
    end;

    { The macro phase decides which groove of the section's library plays, so
      the song has a purposeful shape (establish -> maintain -> build ->
      turnaround) instead of a random pick per phrase. }
    Result := nil;
    if Compatible.Count > 0 then
    begin
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
            Idx := GetNextGrooveIndex(Compatible.Count);
          end;
        mpBuild:
          begin
            { The build pushes towards the densest groove in the library. }
            Idx := Compatible.Count - 1;
          end;
        mpTurnaround:
          begin
            { A turnaround breaks out of the rotation so the section can change
              gear. }
            Idx := ARng.NextInt(Compatible.Count);
          end;
      else
        Idx := GetNextGrooveIndex(Compatible.Count);
      end;

      if (Idx < 0) or (Idx >= Compatible.Count) then
        Idx := 0;
    end
    else
      Idx := -1;

    { The returned pattern is owned by the caller's list — it must NOT be freed
      by the macro composer. }
    if Idx >= 0 then
      Result := Compatible[Idx];
  finally
    Compatible.Free;
  end;
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
  AHumanization: Double = 0.5; ASwing: Double = 0.0;
  ASongMeterNum: Integer = 4; ASongMeterDen: Integer = 4;
  AStrictMeter: Boolean = False): TSong;
var
  SectionMeterNum, SectionMeterDen: Integer;
  MeterText: string;
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
  PreviousPhrasePattern: TPattern;
  CurrentPatternOwned: Boolean;
  CurrentPhraseStartBar: Integer;
  NextPhraseBar: Integer;
  PhraseBars: Integer;
  PhraseIndex: Integer;
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
  FirstMeterNumStr, FirstMeterDenStr: string;
  HasFirstMeter: Boolean;
  FirstMeterNum, FirstMeterDen: Integer;
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
  SectionTempo: Integer;
  SavedComplexity: Double;
  TempoSegment: TSongSegment;
  GmdCount: Integer;
  HasVocabulary: Boolean;
  GenericWeight, GmdShare, VocabShare, WeightSum: Double;
  NewFill: TFill;
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
  MeterText := MeterProblem(ASongMeterNum, ASongMeterDen);
  if MeterText <> '' then
    raise Exception.CreateFmt('Time signature %d/%d: %s',
      [ASongMeterNum, ASongMeterDen, MeterText]);

  { Create generation parameters }
  Params := TGenerationParameters.Create(
    Genre, Style, ADrummer, AComplexity, ADynamics, AHumanization,
    0.35, EnsureRange(ASwing, 0.0, 1.0));

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
  if (ASongMeterNum <> 4) or (ASongMeterDen <> 4) then
  begin
    Song.TimeSignature.Free;
    Song.TimeSignature := TTimeSignature.Create(ASongMeterNum, ASongMeterDen);
  end;

  { Determine section-specific intensity curves }
  CurveMap := GetSectionCurveMap(Structure);

  { Iterate over each section in structure }
  for I := 0 to Length(Structure) - 1 do
  begin
    SectionDef := Structure[I];
    SectionName := SectionDef.Name;
    Bars := SectionDef.Bars;
    { A section can run at its own tempo; everything that depends on the
      tempo inside the section (drummer feel, humanization, groove offsets)
      must use that one, not the song tempo. }
    if SectionDef.Tempo > 0 then
      SectionTempo := SectionDef.Tempo
    else
      SectionTempo := ATempo;
    { The meter of this section: its own, else the song's. }
    SectionMeterNum := ASongMeterNum;
    SectionMeterDen := ASongMeterDen;
    WriteLn(Format('ComposerV2.CreateSong: section %s, song meter %d/%d, section def meter %d/%d',
        [SectionName, SectionMeterNum, SectionMeterDen, SectionDef.MeterNum, SectionDef.MeterDen]));
    if SectionMeterDen = 0 then
      raise Exception.CreateFmt('ComposerV2.CreateSong: SectionMeterDen is 0 for section %s!', [SectionName]);
    if SectionMeterNum = 0 then
      raise Exception.CreateFmt('ComposerV2.CreateSong: SectionMeterNum is 0 for section %s!', [SectionName]);
    if SectionDef.MeterNum > 0 then
    begin
      MeterText := MeterProblem(SectionDef.MeterNum, SectionDef.MeterDen);
      if MeterText <> '' then
        raise Exception.CreateFmt('Section "%s": time signature %d/%d: %s',
          [SectionName, SectionDef.MeterNum, SectionDef.MeterDen, MeterText]);
      SectionMeterNum := SectionDef.MeterNum;
      SectionMeterDen := SectionDef.MeterDen;
    end;

    GeneratedBars := specialize TList<TPattern>.Create;
    Flavors := nil;
    GMDFlavors := nil;
    Available := nil;
    Fills := nil;
    CurrentPattern := nil;
    PreviousPhrasePattern := nil;
    CurrentPatternOwned := False;
    MacroComposer := nil;
    { A section can ask for its own complexity; it applies to everything the
      section generates and is put back in the finally below. }
    SavedComplexity := Params.Complexity;
    try
      if SectionDef.HasComplexity then
        Params.Complexity := SectionDef.Complexity;
      { Get genre plugin }
      FGenrePlugin := TGenrePlugin(FPluginManager.Registry.GetGenrePlugin(Genre));
      if not Assigned(FGenrePlugin) then
        Continue;
      { Grooves, fills and the fallback groove are built in this section's meter. }
      FGenrePlugin.SetMeter(SectionMeterNum, SectionMeterDen);
      Params.MeterNum := SectionMeterNum;
      Params.MeterDen := SectionMeterDen;

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
        Genre, Style, 'beat', SectionMeterNum, SectionMeterDen);
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

      { Strict meter filtering: when --strict-meter is set, only keep patterns
        whose time signature matches the requested song meter. }
      if AStrictMeter and (ASongMeterNum <> 0) and (ASongMeterDen <> 0) then
      begin
        J := Available.Count - 1;
        while J >= 0 do
        begin
          if (Available[J].TimeSignature.Numerator <> ASongMeterNum) or
             (Available[J].TimeSignature.Denominator <> ASongMeterDen) then
          begin
            Available[J].Free;
            Available.Delete(J);
          end;
          Dec(J);
        end;
        { If strict filtering removed everything, fall back to unfiltered patterns
          rather than crashing with no patterns available. }
        if Available.Count = 0 then
        begin
          Available := specialize TList<TPattern>.Create;
          for FlavorItem in Flavors do
            if Assigned(FlavorItem) then
              Available.Add(FlavorItem);
        end;
      end
      else
      { Non-strict meter filtering: when --time-sig is set without --strict-meter,
        only keep patterns whose FIRST bar meter matches the requested song meter.
        Patterns without first_meter metadata (inferred meter) are kept as-is. }
      if (not AStrictMeter) and (ASongMeterNum <> 0) and (ASongMeterDen <> 0) then
      begin
        J := Available.Count - 1;
        while J >= 0 do
        begin
          HasFirstMeter := Available[J].Metadata.TryGetValue('first_meter_num', FirstMeterNumStr) and
                           Available[J].Metadata.TryGetValue('first_meter_den', FirstMeterDenStr);
          if HasFirstMeter then
          begin
            FirstMeterNum := StrToIntDef(FirstMeterNumStr, -1);
            FirstMeterDen := StrToIntDef(FirstMeterDenStr, -1);
            if (FirstMeterNum <> ASongMeterNum) or (FirstMeterDen <> ASongMeterDen) then
            begin
              Available[J].Free;
              Available.Delete(J);
            end;
          end;
          Dec(J);
        end;
        { If non-strict filtering removed everything, fall back to unfiltered patterns. }
        if Available.Count = 0 then
        begin
          Available := specialize TList<TPattern>.Create;
          for FlavorItem in Flavors do
            if Assigned(FlavorItem) then
              Available.Add(FlavorItem);
        end;
      end;

      { Macro-composer phase tracking }
      MacroComposer := TMacroComposer.Create(FRng.NextInt(10000));
      NextPhraseBar := 0;
      CurrentPhraseStartBar := 0;
      PhraseIndex := 0;

      for BarIndex := 0 to Bars - 1 do
      begin
        { Get intensity point for this bar position }
        IntensityPt := GetIntensityPt(CurveMap, SectionName, BarIndex, Bars);

        { Determine macro-composer phase for purposeful variation }
        Phase := MacroComposer.DeterminePhase(BarIndex, Bars);

        if BarIndex >= NextPhraseBar then
        begin
          { Remember the phrase that just ended so the selector can avoid
            repeating it. Only borrowed patterns are kept: an owned one is
            freed below. }
          if CurrentPatternOwned then
            PreviousPhrasePattern := nil
          else
            PreviousPhrasePattern := CurrentPattern;
          if CurrentPatternOwned and Assigned(CurrentPattern) then
            CurrentPattern.Free;
          CurrentPattern := nil;
          CurrentPatternOwned := False;

          { Select once per phrase, not once per bar: this preserves multi-bar
            source patterns while varying successive phrases by intensity and
            phrase position. The selector returns a borrowed pattern from
            Available; only the fallback generated pattern is owned here. }
          if Available.Count > 0 then
            CurrentPattern := FBarSelector.SelectPatternForPhrase(
              Available, PhraseIndex, IntensityPt, Phase, PreviousPhrasePattern, FRng);
          Inc(PhraseIndex);
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
              ApplyStyleForContext(BasePattern, Genre, Style, SectionTempo);
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
        { Swing is a grid distortion applied after the bar is composed and
          before humanization, which only adds jitter on top. Recorded GMD
          patterns are skipped: a human already played their feel. }
        if (Params.SwingRatio > 0) and
           not BasePattern.Metadata.ContainsKey('gmd_source_style') then
          FinalPattern.ApplySwing(Params.SwingRatio);
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
          HumanizationContext.Tempo := SectionTempo;
          HumanizationContext.Drummer := ADrummer;
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

      { Where a fill comes from, by weight: the drummer's own vocabulary
        (GetSignatureFills of the drummer plugin) first, recorded GMD fills
        second, the generic fill the picker chose for that bar as the
        fallback. The generic fills are tied to their bar; the others compete
        for every placed bar. }
      SignatureFills := nil;
      if ADrummer <> '' then
      begin
        DrummerPlugin := FPluginManager.Registry.GetDrummerPlugin(ADrummer);
        if Assigned(DrummerPlugin) and (DrummerPlugin is TDrummerPlugin) then
          SignatureFills := (DrummerPlugin as TDrummerPlugin).GetFillVocabulary(
            ADrummer, SectionMeterNum, SectionMeterDen);
      end;
      HasVocabulary := Assigned(SignatureFills) and (SignatureFills.Count > 0);
      if HasVocabulary then
      begin
        GenericWeight := 0.15; GmdShare := 0.25; VocabShare := 0.6;
      end
      else
      begin
        GenericWeight := 0.4; GmdShare := 0.6; VocabShare := 0.0;
      end;
      for Idx := 0 to Fills.Count - 1 do
        Fills[Idx].TriggerProbability := GenericWeight;

      try
        if HasVocabulary then
          for J := 0 to Length(FillBarIndices) - 1 do
          begin
            WeightSum := 0;
            for SignatureFill in SignatureFills do
              if Assigned(SignatureFill.Pattern) and
                 (SignatureFill.Pattern.Beats.Count > 0) and
                 (SignatureFill.Pattern.DurationBars <= FillBarIndices[J] + 1) then
                WeightSum := WeightSum + FillEnergyWeight(
                  SignatureFill, SectionIntensities[FillBarIndices[J]]);
            if WeightSum <= 0 then
              Continue;
            for SignatureFill in SignatureFills do
              if Assigned(SignatureFill.Pattern) and
                 (SignatureFill.Pattern.Beats.Count > 0) and
                 (SignatureFill.Pattern.DurationBars <= FillBarIndices[J] + 1) then
              begin
                NewFill := TFill.Create(SignatureFill.Pattern.Copy);
                NewFill.Energy := SignatureFill.Energy;
                NewFill.TargetBar := FillBarIndices[J];
                WriteLn(Format('ComposerV2.CreateSong: about to compute VocabShare * FillEnergyWeight / WeightSum = %f * %f / %f', [VocabShare, FillEnergyWeight(SignatureFill, SectionIntensities[FillBarIndices[J]]), WeightSum]));
    NewFill.TriggerProbability := VocabShare * FillEnergyWeight(
                  SignatureFill, SectionIntensities[FillBarIndices[J]]) / WeightSum;
    WriteLn(Format('ComposerV2.CreateSong: TriggerProbability = %f', [NewFill.TriggerProbability]));
                Fills.Add(NewFill);
              end;
          end;
      finally
        if Assigned(SignatureFills) then
        begin
          for Idx := SignatureFills.Count - 1 downto 0 do
            SignatureFills[Idx].Free;
          SignatureFills.Free;
        end;
      end;

      { Fills written on the 16th grid swing with the groove; recorded GMD
        fills (added below) keep their own feel. }
      if Params.SwingRatio > 0 then
        for Idx := 0 to Fills.Count - 1 do
          if Assigned(Fills[Idx].Pattern) then
            Fills[Idx].Pattern.ApplySwing(Params.SwingRatio);

      GMDFlavors := FGMDPatternLibrary.GetPatterns(
        Genre, Style, 'fill', SectionMeterNum, SectionMeterDen);
      try
        GmdCount := 0;
        for FlavorItem in GMDFlavors do
          if (FlavorItem.DurationBars <= Bars) and
             (FlavorItem.Beats.Count > 0) then
            Inc(GmdCount);
        WriteLn(Format('ComposerV2.CreateSong: GmdCount=%d for section %s, meter %d/%d',
          [GmdCount, SectionName, SectionMeterNum, SectionMeterDen]));
        if GmdCount = 0 then
          raise Exception.CreateFmt('ComposerV2.CreateSong: GmdCount is 0 for section %s, meter %d/%d',
            [SectionName, SectionMeterNum, SectionMeterDen]);
        for FlavorItem in GMDFlavors do
          if (FlavorItem.DurationBars <= Bars) and
             (FlavorItem.Beats.Count > 0) then
          begin
            NewFill := TFill.Create(FlavorItem.Copy);
            WriteLn(Format('ComposerV2.CreateSong: about to compute GmdShare / GmdCount = %f / %d', [GmdShare, GmdCount]));
    NewFill.TriggerProbability := GmdShare / GmdCount;
    WriteLn(Format('ComposerV2.CreateSong: TriggerProbability = %f', [NewFill.TriggerProbability]));
            Fills.Add(NewFill);
          end;
      finally
        for FlavorItem in GMDFlavors do
          FlavorItem.Free;
        GMDFlavors.Free;
        GMDFlavors := nil;
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
            JBar, SectionTempo, IntensityPt, SectionName, Genre, ADrummer);
          Section.GrooveOffsetsMs.Add(OffsetMs);
        end;
      if Section.GrooveOffsetsMs.Count = 0 then
        for JBar := 0 to Bars - 1 do
          Section.GrooveOffsetsMs.Add(0.0);
      { The exporters read a section's tempo and meter from its segments. }
      if (SectionTempo <> ATempo) or (SectionMeterNum <> ASongMeterNum) or
         (SectionMeterDen <> ASongMeterDen) then
      begin
        TempoSegment := TSongSegment.Create(Bars);
        if SectionTempo <> ATempo then
          TempoSegment.Tempo := SectionTempo;
        if (SectionMeterNum <> ASongMeterNum) or (SectionMeterDen <> ASongMeterDen) then
          TempoSegment.TimeSignature := TTimeSignature.Create(SectionMeterNum, SectionMeterDen);
        Section.Segments.Add(TempoSegment);
        Section.ValidateSegments;
      end;
      Song.Sections.Add(Section);
    finally
      Params.Complexity := SavedComplexity;
      { The plugin is shared: leave it in 4/4 for whoever uses it next. }
      if Assigned(FGenrePlugin) then
        FGenrePlugin.SetMeter(4, 4);

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

  WriteLn(Format('ComposerV2.GetIntensityPt: about to compute Ratio = ABarIndex / (ABars - 1) = %d / (%d - 1)', [ABarIndex, ABars]));
  Ratio := ABarIndex / (ABars - 1);
  WriteLn(Format('ComposerV2.GetIntensityPt: Ratio = %f', [Ratio]));

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
