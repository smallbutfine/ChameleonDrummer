unit Rock;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  patterns_templates,
  Kit,
  generation_parameters,
  GenrePlugin,
  config_constants, RockGrooves, GrooveLibrary;

type
  TRockContext = record
    Style: String;
    Section: String;
    Complexity: Double;
    Intensity: Double;
  end;

  TRockGenrePlugin = class(TGenrePlugin)
  private
    FStyle: String;
    FSection: String;
    FComplexity: Double;
    FIntensity: Double;
    function GetRideTimekeeper: String;
    function MakeGroove(const AKind: String; AVariant: Integer): TPattern;
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
    function HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument; override;
    function GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double;
      BarIndex: Integer): TDrumInstrument; override;
    function GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern; override;
    function GetSectionFlavors(const Section: string; const Parameters: TGenerationParameters): specialize TList<TPattern>; override;

    function GetVerseFlavor(BarIndex: Integer): TPattern;
    function GetChorusFlavor(BarIndex: Integer): TPattern;
    function GetBridgeFlavor(BarIndex: Integer): TPattern;
    function GetSectionFlavorsFiltered(const Section: string; const Parameters: TGenerationParameters; MinIntensity, MaxIntensity: Double): specialize TList<TPattern>; override;
  end;

implementation

function TRockGenrePlugin.GetGenreName: string;
begin
  Result := 'rock';
end;

function TRockGenrePlugin.GetSupportedStyles: TStringArray;
begin
  Result := WithFileStyles('rock', ['classic', 'blues', 'alternative', 'progressive', 'punk',
    'hard', 'pop']);
end;

constructor TRockGenrePlugin.Create;
begin
  inherited Create;
  FStyle := 'classic';
  FSection := 'verse';
  FComplexity := 0.5;
  FIntensity := 0.6;
end;

destructor TRockGenrePlugin.Destroy;
begin
  inherited Destroy;
end;

procedure TRockGenrePlugin.SetStyle(const AStyle: String);
begin
  FStyle := LowerCase(AStyle);
end;

procedure TRockGenrePlugin.SetSection(const ASection: String);
begin
  FSection := LowerCase(ASection);
end;

procedure TRockGenrePlugin.SetComplexity(AValue: Double);
begin
  if (AValue < 0.0) then FComplexity := 0.0
  else if (AValue > 1.0) then FComplexity := 1.0
  else FComplexity := AValue;
end;

procedure TRockGenrePlugin.SetIntensity(AValue: Double);
begin
  if (AValue < 0.0) then FIntensity := 0.0
  else if (AValue > 1.0) then FIntensity := 1.0
  else FIntensity := AValue;
end;

function TRockGenrePlugin.GetRideTimekeeper: String;
begin
  // Classic and hard rock use standard ride pattern
  Result := 'ride_1_tip_hit_softer';
end;

function TRockGenrePlugin.GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double; BarIndex: Integer): TDrumInstrument;
begin
  case (BarIndex mod 2) of
    0: Result := TInstrumentRegistry.Get('cymbal_1_hit'); // crash 1
    1: Result := TInstrumentRegistry.Get('cymbal_2_hit'); // crash 2
  else
    Result := TInstrumentRegistry.Get('cymbal_3_hit');
  end;
end;

function TRockGenrePlugin.MakeGroove(const AKind: String; AVariant: Integer): TPattern;
begin
  { Grooves are drum tabs in RockGrooves.pas: three per style and section
    kind, tagged with overlapping intensity bands. }
  Result := BuildGroove('rock', FStyle, AKind, AVariant, FComplexity,
    RockGrooveLines(FStyle, AKind, AVariant mod 3),
    MeterNum, MeterDen);
end;

function TRockGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
begin
  Result := MakeGroove('verse', BarIndex mod 3);
end;

function TRockGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
begin
  Result := MakeGroove('chorus', BarIndex mod 3);
end;

function TRockGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
begin
  Result := MakeGroove('bridge', BarIndex mod 3);
end;

function TRockGenrePlugin.GetVerseFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorVerse(BarIndex);
end;

function TRockGenrePlugin.GetChorusFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorChorus(BarIndex);
end;

function TRockGenrePlugin.GetBridgeFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorBridge(BarIndex);
end;

function TRockGenrePlugin.GetSectionGrooves: specialize TList<TPattern>;
var
  GrooveList: specialize TList<TPattern>;
  BarIdx: Integer;
begin
  GrooveList := specialize TList<TPattern>.Create;

  for BarIdx := 0 to 2 do
    GrooveList.Add(GetFlavorVerse(BarIdx));

  case FStyle of
    'classic', 'hard':
      begin
        GrooveList.Add(GetFlavorChorus(0));
        GrooveList.Add(GetFlavorChorus(1));
      end;
  else
    GrooveList.Add(GetFlavorChorus(0));
  end;

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorBridge(BarIdx));

  Result := GrooveList;
end;

function TRockGenrePlugin.GetCommonFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;

  LFill := TFill.Create('rock_tom_downfill', 'Rock tom cascade');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);

  Result := FillList;
end;

function TRockGenrePlugin.HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument;
begin
  // Rock uses standard ride, no china override
  Result := TInstrumentRegistry.Get(GetRideTimekeeper);
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('ride_1_tip_hit_softer');
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('ride_1_bell');
end;

function TRockGenrePlugin.GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern;
var
  PreviousStyle: String;
  PreviousComplexity: Double;
begin
  PreviousStyle := FStyle;
  PreviousComplexity := FComplexity;
  try
    if (Parameters <> nil) and (Parameters.Style <> '') then
      FStyle := LowerCase(Parameters.Style);
    if Parameters <> nil then
      FComplexity := Parameters.Complexity;
    Result := MakeGroove(GrooveKindOfSection(Section), 1);
  finally
    FStyle := PreviousStyle;
    FComplexity := PreviousComplexity;
  end;
end;

function TRockGenrePlugin.GetSectionFlavors(const Section: string;
  const Parameters: TGenerationParameters): specialize TList<TPattern>;
var
  BarIdx: Integer;
  SectionName, PreviousStyle, PreviousSection: string;
  PreviousComplexity, PreviousIntensity: Double;
begin
  RequireValidParameters(Parameters);
  Result := specialize TList<TPattern>.Create;
  PreviousStyle := FStyle;
  PreviousSection := FSection;
  PreviousComplexity := FComplexity;
  PreviousIntensity := FIntensity;
  try
    try
      if Assigned(Parameters) then
      begin
        if Parameters.Style <> '' then
          FStyle := LowerCase(Parameters.Style);
        FComplexity := Parameters.Complexity;
        FIntensity := Parameters.Dynamics;
      end;
      FSection := LowerCase(Section);
      SectionName := FSection;

      for BarIdx := 0 to GrooveVariantCount('rock', FStyle, GrooveKindOfSection(Section), 3, MeterNum, MeterDen) - 1 do
        Result.Add(MakeGroove(GrooveKindOfSection(Section), BarIdx));

    except
      while Result.Count > 0 do
      begin
        Result[Result.Count - 1].Free;
        Result.Delete(Result.Count - 1);
      end;
      Result.Free;
      raise;
    end;
  finally
    FStyle := PreviousStyle;
    FSection := PreviousSection;
    FComplexity := PreviousComplexity;
    FIntensity := PreviousIntensity;
  end;
end;

function TRockGenrePlugin.GetSectionFlavorsFiltered(const Section: string; const Parameters: TGenerationParameters; MinIntensity, MaxIntensity: Double): specialize TList<TPattern>;
{ Filter flavors by actual intensity metadata tags rather than list index.
  Each flavor is tagged with valid_intensity_min / valid_intensity_max when
  created. A pattern is compatible when its midpoint falls within the
  section's observed intensity range. }
var
  BaseFlavors: specialize TList<TPattern>;
  I: Integer;
  PMin, PMax, PMid: Double;
  PMinStr, PMaxStr: string;
begin
  Result := specialize TList<TPattern>.Create;
  BaseFlavors := GetSectionFlavors(Section, Parameters);
  if not Assigned(BaseFlavors) or (BaseFlavors.Count = 0) then Exit;

  for I := 0 to BaseFlavors.Count - 1 do
  begin
    { Read tagged intensity range; fall back to full range if untagged. }
    TryGetIntensityRange(BaseFlavors[I], PMin, PMax);
    PMid := (PMin + PMax) / 2.0;

    { Include if pattern's midpoint overlaps the section intensity band. }
    if (PMid >= MinIntensity - 0.15) and (PMid <= MaxIntensity + 0.15) then
      Result.Add(BaseFlavors[I]);
  end;

  { Safety net: return all flavors if nothing matched to avoid empty song. }
  if Result.Count = 0 then
    for I := 0 to BaseFlavors.Count - 1 do
      Result.Add(BaseFlavors[I]);
end;

end.
