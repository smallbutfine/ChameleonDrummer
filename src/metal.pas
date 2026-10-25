unit Metal;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  patterns_templates,
  Kit,
  generation_parameters,
  GenrePlugin, DrummerPlugin,
  config_constants;

type
  // Context blending for metal styles
  TMetalContext = record
    Style: String;
    Section: String;
    Complexity: Double;
    Intensity: Double;
  end;

  TMetalGenrePlugin = class(TGenrePlugin)
  private
    FStyle: String;
    FSection: String;
    FComplexity: Double;
    FIntensity: Double;
    function GetChinaTimekeeper(const AStyle: String): String;
    function GetFlavorVerseInternal(BarIndex: Integer; const Style: String): TPattern;
    function GetFlavorChorusInternal(BarIndex: Integer; const Style: String): TPattern;
    function GetFlavorBridgeInternal(BarIndex: Integer; const Style: String): TPattern;
    function GetFlavorVerse(BarIndex: Integer): TPattern;
    function GetFlavorChorus(BarIndex: Integer): TPattern;
    function GetFlavorBridge(BarIndex: Integer): TPattern;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure SetStyle(const AStyle: String);
    procedure SetSection(const ASection: String);
    procedure SetComplexity(AValue: Double);
    procedure SetIntensity(AValue: Double);

    function GetGenreName: string; override;
    function GetSupportedStyles: TStringArray; override;
    function GetSectionGrooves: specialize TList<TPattern>;
    function GetCommonFills: specialize TList<TFill>; override;
    function GetSectionFlavors(const Section: string; const Parameters: TGenerationParameters): specialize TList<TPattern>; override;
    function AdaptExternalPattern(const APattern: TPattern;
      const Parameters: TGenerationParameters): TPattern; override;
    function HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument; override;
    function GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double;
      BarIndex: Integer): TDrumInstrument; override;
    function GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern; override;

    // Flavor rotation helpers
    function GetVerseFlavor(BarIndex: Integer): TPattern;
    function GetChorusFlavor(BarIndex: Integer): TPattern;
    function GetBridgeFlavor(BarIndex: Integer): TPattern;

    // Intensity-aware flavor filtering (Phase 1 P0)
    function GetSectionFlavorsFiltered(const Section: string; const Parameters: TGenerationParameters; MinIntensity, MaxIntensity: Double): specialize TList<TPattern>;
  end;

implementation

constructor TMetalGenrePlugin.Create;
begin
  inherited Create;
  FStyle := 'heavy';
  FSection := 'verse';
  FComplexity := 0.5;
  FIntensity := 0.7;
end;

destructor TMetalGenrePlugin.Destroy;
begin
  inherited Destroy;
end;

procedure TMetalGenrePlugin.SetStyle(const AStyle: String);
begin
  FStyle := LowerCase(AStyle);
end;

procedure TMetalGenrePlugin.SetSection(const ASection: String);
begin
  FSection := LowerCase(ASection);
end;

procedure TMetalGenrePlugin.SetComplexity(AValue: Double);
begin
  if (AValue < 0.0) then FComplexity := 0.0
  else if (AValue > 1.0) then FComplexity := 1.0
  else FComplexity := AValue;
end;

procedure TMetalGenrePlugin.SetIntensity(AValue: Double);
begin
  if (AValue < 0.0) then FIntensity := 0.0
  else if (AValue > 1.0) then FIntensity := 1.0
  else FIntensity := AValue;
end;

function TMetalGenrePlugin.GetChinaTimekeeper(const AStyle: String): String;
begin
  // Death and thrash metal drive the section with a crash-style timekeeper,
  // everything else uses the ride bell. There is no china cymbal in the
  // template keymaps, so cymbal_1_hit stands in for it.
  if (AStyle = 'death') or (AStyle = 'thrash') then
    Result := 'cymbal_1_hit'
  else
    Result := 'ride_1_bell';
end;

function TMetalGenrePlugin.GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double; BarIndex: Integer): TDrumInstrument;
begin
  // Cycle through AD2 crash variants per bar
  case (BarIndex mod 3) of
    0: Result := TInstrumentRegistry.Get('cymbal_4_hit'); // heavy
    1: Result := TInstrumentRegistry.Get('cymbal_2_hit'); // light
    2: Result := TInstrumentRegistry.Get('cymbal_6_hit'); // splash
  else
    Result := TInstrumentRegistry.Get('cymbal_1_hit');
  end;
end;

function TMetalGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorVerseInternal(BarIndex, FStyle);
end;

function TMetalGenrePlugin.GetFlavorVerseInternal(BarIndex: Integer; const Style: String): TPattern;
var
  Composer: TTemplateComposer;
  IntensityFactor: Double;
begin
  { Complexity is the density control and dynamics is how hard the part is
    played. Combining them lets either one open the pattern gates below -
    with dynamics alone at its default the gates could never be reached. }
  IntensityFactor := (FIntensity + FComplexity) / 2;
  Composer := TTemplateComposer.Create('metal_' + Style + '_verse_b' + IntToStr(BarIndex));

  case Style of
    'heavy':
      begin
        // Classic heavy metal — Sabbath/Iron Maiden style
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        if (BarIndex mod 2 = 0) then
          Composer.Add(TDoubleBassPedal.Create('continuous', 8));
      end;
    'death':
      begin
        // Death metal â€” blast beats, double bass
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
        if (IntensityFactor > 0.7) then
          Composer.Add(TBlastBeat.Create('traditional', IntensityFactor));
      end;
    'power':
      begin
        // Power metal — anthemic, driving
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TDoubleBassPedal.Create('gallop', 16));
      end;
    'progressive':
      begin
        // Progressive â€" complex syncopation
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        if (BarIndex mod 3 = 0) then
          Composer.Add(TDoubleBassPedal.Create('continuous', 8));
      end;
    'thrash':
      begin
        // Thrash â€” fast aggressive
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
        if (IntensityFactor > 0.6) then
          Composer.Add(TBlastBeat.Create('hammer', IntensityFactor * 0.9));
      end;
    'doom':
      begin
        // Doom â€" slow, heavy, crushing
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
      end;
    'breakdown':
      begin
        // Breakdown â€” syncopated chugs
        Composer.Add(TDoubleBassPedal.Create('burst', 32));
      end;
  else
    Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TMetalGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorChorusInternal(BarIndex, FStyle);
end;

function TMetalGenrePlugin.GetFlavorChorusInternal(BarIndex: Integer; const Style: String): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('metal_' + Style + '_chorus_b' + IntToStr(BarIndex));

  case Style of
    'heavy':
      begin
        // Heavy chorus â€" bigger crash accents
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TCrashAccents.Create);
      end;
    'death':
      begin
        // Death chorus â€” extended blast
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
        Composer.Add(TBlastBeat.Create('gravity', FIntensity));
      end;
    'power':
      begin
        // Power chorus â€” gallop drive
        Composer.Add(TDoubleBassPedal.Create('gallop', 16));
        Composer.Add(TCrashAccents.Create);
      end;
    'progressive':
      begin
        // Progressive chorus â€" odd meter feel
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        if (BarIndex mod 2 = 0) then
          Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'thrash':
      begin
        // Thrash chorus â€” relentless double bass
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'doom':
      begin
        // Doom chorus â€" crushing sustained hits
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TCrashAccents.Create);
      end;
    'breakdown':
      begin
        // Breakdown chorus â€” half-time chugs
        Composer.Add(TDoubleBassPedal.Create('burst', 32));
      end;
  else
    Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TMetalGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorBridgeInternal(BarIndex, FStyle);
end;

function TMetalGenrePlugin.GetFlavorBridgeInternal(BarIndex: Integer; const Style: String): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('metal_' + Style + '_bridge_b' + IntToStr(BarIndex));

  case Style of
    'heavy':
      begin
        // Heavy bridge â€" build up with tom fill
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TTomFill.Create('descending'));
      end;
    'death':
      begin
        // Death bridge â€” sparse blast
        if (BarIndex mod 2 = 0) then
          Composer.Add(TBlastBeat.Create('traditional', FIntensity * 0.8));
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'power':
      begin
        // Power bridge â€” melodic ride pattern
        Composer.Add(TSteadyRide.Create);
      end;
    'progressive':
      begin
        // Progressive bridge â€" complex layering
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        if (BarIndex mod 2 = 0) then
          Composer.Add(TDoubleBassPedal.Create('gallop', 16));
      end;
    'thrash':
      begin
        // Thrash bridge â€” half-time chug
        Composer.Add(TDoubleBassPedal.Create('burst', 32));
      end;
    'doom':
      begin
        // Doom bridge â€" minimal crushing
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
      end;
    'breakdown':
      begin
        // Breakdown bridge â€” stop-time feel
        Composer.Add(TDoubleBassPedal.Create('burst', 32));
      end;
  else
    Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TMetalGenrePlugin.GetVerseFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorVerse(BarIndex);
end;

function TMetalGenrePlugin.GetChorusFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorChorus(BarIndex);
end;

function TMetalGenrePlugin.GetBridgeFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorBridge(BarIndex);
end;

function TMetalGenrePlugin.GetSectionGrooves: specialize TList<TPattern>;
var
  GrooveList: specialize TList<TPattern>;
  BarIdx: Integer;
begin
  GrooveList := specialize TList<TPattern>.Create;

  // Verse grooves (3 per style)
  for BarIdx := 0 to 2 do
    GrooveList.Add(GetFlavorVerse(BarIdx));

  // Chorus grooves (2-3 per style)
  case FStyle of
    'heavy', 'power', 'doom':
      begin
        GrooveList.Add(GetFlavorChorus(0));
        GrooveList.Add(GetFlavorChorus(1));
        GrooveList.Add(GetFlavorChorus(2));
      end;
  else
    GrooveList.Add(GetFlavorChorus(0));
    GrooveList.Add(GetFlavorChorus(1));
  end;

  // Bridge grooves (2 per style)
  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorBridge(BarIdx));

  Result := GrooveList;
end;

function TMetalGenrePlugin.GetGenreName: string;
begin
  Result := 'metal';
end;

function TMetalGenrePlugin.GetSupportedStyles: TStringArray;
begin
  Result := ['heavy', 'death', 'power', 'progressive', 'thrash', 'doom',
    'breakdown'];
end;

function TMetalGenrePlugin.GetSectionFlavors(const Section: string; const Parameters: TGenerationParameters): specialize TList<TPattern>;
var
  GrooveList: specialize TList<TPattern>;
  BarIdx: Integer;
  StyleForVerse: String;
  PreviousStyle: String;
  PreviousComplexity, PreviousIntensity: Double;
begin
  RequireValidParameters(Parameters);
  GrooveList := specialize TList<TPattern>.Create;
  PreviousStyle := FStyle;
  PreviousComplexity := FComplexity;
  PreviousIntensity := FIntensity;
  try
    if (Parameters <> nil) and (Parameters.Style <> '') then
      StyleForVerse := LowerCase(Parameters.Style)
    else
      StyleForVerse := FStyle;
    FStyle := StyleForVerse;
    if Parameters <> nil then
    begin
      FComplexity := Parameters.Complexity;
      FIntensity := Parameters.Dynamics;
    end;

    for BarIdx := 0 to 2 do
      GrooveList.Add(GetFlavorVerseInternal(BarIdx, StyleForVerse));

    case StyleForVerse of
      'heavy', 'power', 'doom':
        begin
          GrooveList.Add(GetFlavorChorusInternal(0, StyleForVerse));
          GrooveList.Add(GetFlavorChorusInternal(1, StyleForVerse));
          GrooveList.Add(GetFlavorChorusInternal(2, StyleForVerse));
        end;
    else
      GrooveList.Add(GetFlavorChorusInternal(0, StyleForVerse));
      GrooveList.Add(GetFlavorChorusInternal(1, StyleForVerse));
    end;

    for BarIdx := 0 to 1 do
      GrooveList.Add(GetFlavorBridgeInternal(BarIdx, StyleForVerse));

    Result := GrooveList;
    GrooveList := nil;
  finally
    FStyle := PreviousStyle;
    FComplexity := PreviousComplexity;
    FIntensity := PreviousIntensity;
    if Assigned(GrooveList) then
    begin
      for BarIdx := GrooveList.Count - 1 downto 0 do
        GrooveList[BarIdx].Free;
      GrooveList.Free;
    end;
  end;
end;

function TMetalGenrePlugin.GetSectionFlavorsFiltered(const Section: string; const Parameters: TGenerationParameters; MinIntensity, MaxIntensity: Double): specialize TList<TPattern>;
{ Filter section flavors by intensity range. Pattern indices encode intensity:
  Index 0 = low (intensity 0–0.4), Index 1 = medium (0.4–0.7), Index 2+ = high (>0.7) }
var
  BaseFlavors: specialize TList<TPattern>;
  I, MaxIdx: Integer;
begin
  Result := specialize TList<TPattern>.Create;
  BaseFlavors := Self.GetSectionFlavors(Section, Parameters);
  if not Assigned(BaseFlavors) or (BaseFlavors.Count = 0) then
    Exit;

  // Filter by index range mapped to intensity bands:
  // Index 0 → low band (0.0–0.33)
  // Index 1 → mid band (0.33–0.67)
  // Index 2+ → high band (>0.67)
  for I := 0 to BaseFlavors.Count - 1 do
  begin
    case I of
      0: begin
        if (MaxIntensity > 0.0) and (MinIntensity < 0.4) then
          Result.Add(BaseFlavors[I]);
      end;
      1: begin
        if (MaxIntensity > 0.35) and (MinIntensity < 0.7) then
          Result.Add(BaseFlavors[I]);
      end;
    else // Index 2+
      if (MaxIntensity > 0.65) then
        Result.Add(BaseFlavors[I]);
    end;
  end;

  { Safety net: if nothing matched, return everything to avoid empty song }
  if Result.Count = 0 then
    for I := 0 to BaseFlavors.Count - 1 do
      Result.Add(BaseFlavors[I]);
end;

function TMetalGenrePlugin.GetCommonFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill1, LFill2: TFill;
begin
  FillList := specialize TList<TFill>.Create;

  // Tom fill variants
  LFill1 := TFill.Create('metal_tom_downfill', 'Descending tom cascade');
  LFill1.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill1);

  // Blast beat fill
  LFill2 := TFill.Create('metal_blast_fill', 'Traditional blast beat');
  LFill2.Pattern := TPattern.Create('blast_beat');
  FillList.Add(LFill2);

  Result := FillList;
end;

function TMetalGenrePlugin.AdaptExternalPattern(const APattern: TPattern;
  const Parameters: TGenerationParameters): TPattern;
var
  Style, PedalType: string;
  Subdivision: Integer;
begin
  if not Assigned(APattern) then
    Exit(nil);
  if not Assigned(Parameters) then
    Exit(APattern.Copy);
  if (APattern.TimeSignature.Numerator <> 4) or
     (APattern.TimeSignature.Denominator <> 4) then
    Exit(APattern.Copy);

  Style := LowerCase(Parameters.Style);
  PedalType := '';
  Subdivision := 0;
  case Style of
    'heavy':
      begin
        PedalType := 'continuous';
        Subdivision := 8;
      end;
    'death', 'thrash':
      begin
        PedalType := 'continuous';
        Subdivision := 16;
      end;
    'power':
      begin
        PedalType := 'gallop';
        Subdivision := 16;
      end;
    'progressive':
      begin
        PedalType := 'continuous';
        Subdivision := 8;
      end;
    'breakdown':
      begin
        PedalType := 'burst';
        Subdivision := 32;
      end;
  end;
  if PedalType = '' then
    Exit(inherited AdaptExternalPattern(APattern, Parameters));

  Result := OverlayDoubleBassPedal(APattern, PedalType, Subdivision);
end;

function TMetalGenrePlugin.HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument;
var
  StyleName: String;
begin
  StyleName := FStyle;
  if Assigned(Parameters) and (Parameters.Style <> '') then
    StyleName := LowerCase(Parameters.Style);

  Result := TInstrumentRegistry.Get(GetChinaTimekeeper(StyleName));
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('cymbal_1_hit');
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('ride_1_bell');
end;

function TMetalGenrePlugin.GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern;
var
  Composer: TTemplateComposer;
  Style: String;
begin
  // Read style from parameters (FStyle is set once in constructor, but params override it)
  if Parameters <> nil then
    Style := LowerCase(Parameters.Style)
  else
    Style := FStyle;
  
  { Generate default metal pattern using template system } 
  Composer := TTemplateComposer.Create(Section + '_metal_' + Style);
  try
    if SameText(Style, 'heavy') then
      begin
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TDoubleBassPedal.Create('continuous', 8));
      end
    else if SameText(Style, 'power') then
      begin
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TDoubleBassPedal.Create('gallop', 16));
      end
    else if SameText(Style, 'death') or SameText(Style, 'thrash') then
      begin
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
        Composer.Add(TBlastBeat.Create('traditional', 0.9));
      end
    else if SameText(Style, 'doom') then
      begin
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
      end
    else if SameText(Style, 'breakdown') then
      Composer.Add(TDoubleBassPedal.Create('burst', 32))
    else if SameText(Style, 'progressive') then
      begin
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TDoubleBassPedal.Create('continuous', 8));
      end
    else
      begin
        Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
        Composer.Add(TCrashAccents.Create);
      end;
    Result := Composer.Build(2, FComplexity);
  finally
    Composer.Free;
  end;
end;

end.
