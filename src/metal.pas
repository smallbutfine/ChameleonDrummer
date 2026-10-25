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
  config_constants, MetalGrooves;

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
    function MakeGroove(const AKind, AStyle: String; AVariant: Integer): TPattern;
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

function TMetalGenrePlugin.MakeGroove(const AKind, AStyle: String;
  AVariant: Integer): TPattern;
begin
  { Grooves are drum tabs in MetalGrooves.pas: three per style and section
    kind, tagged with overlapping intensity bands. }
  Result := BuildTaggedGroove(
    'metal_' + AStyle + '_' + AKind + '_v' + IntToStr(AVariant), AKind,
    AVariant, MetalGrooveLines(AStyle, AKind, AVariant), FComplexity);
end;

function TMetalGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorVerseInternal(BarIndex, FStyle);
end;

function TMetalGenrePlugin.GetFlavorVerseInternal(BarIndex: Integer; const Style: String): TPattern;
begin
  Result := MakeGroove('verse', Style, BarIndex mod 3);
end;

function TMetalGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorChorusInternal(BarIndex, FStyle);
end;

function TMetalGenrePlugin.GetFlavorChorusInternal(BarIndex: Integer; const Style: String): TPattern;
begin
  Result := MakeGroove('chorus', Style, BarIndex mod 3);
end;

function TMetalGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorBridgeInternal(BarIndex, FStyle);
end;

function TMetalGenrePlugin.GetFlavorBridgeInternal(BarIndex: Integer; const Style: String): TPattern;
begin
  Result := MakeGroove('bridge', Style, BarIndex mod 3);
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
      GrooveList.Add(MakeGroove(GrooveKindOfSection(Section), StyleForVerse, BarIdx));

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
{ Filter flavors by actual intensity metadata tags rather than list index. }
var
  BaseFlavors: specialize TList<TPattern>;
  I: Integer;
  PMin, PMax, PMid: Double;
  PMinStr, PMaxStr: string;
begin
  Result := specialize TList<TPattern>.Create;
  BaseFlavors := Self.GetSectionFlavors(Section, Parameters);
  if not Assigned(BaseFlavors) or (BaseFlavors.Count = 0) then Exit;

  for I := 0 to BaseFlavors.Count - 1 do
  begin
    TryGetIntensityRange(BaseFlavors[I], PMin, PMax);
    PMid := (PMin + PMax) / 2.0;

    { Include if pattern midpoint overlaps the section intensity band. }
    if (PMid >= MinIntensity - 0.15) and (PMid <= MaxIntensity + 0.15) then
      Result.Add(BaseFlavors[I]);
  end;

  { Safety net: return all flavors if nothing matched to avoid empty song. }
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
  Style: String;
begin
  { Params override the style the plugin was created with. }
  if (Parameters <> nil) and (Parameters.Style <> '') then
    Style := LowerCase(Parameters.Style)
  else
    Style := FStyle;
  Result := MakeGroove(GrooveKindOfSection(Section), Style, 1);
end;

end.
