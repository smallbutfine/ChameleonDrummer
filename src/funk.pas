unit Funk;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  patterns_templates,
  Kit,
  generation_parameters,
  GenrePlugin,
  config_constants, FunkGrooves;

type
  TFunkContext = record
    Style: String;
    Section: String;
    Complexity: Double;
    Intensity: Double;
  end;

  TFunkGenrePlugin = class(TGenrePlugin)
  private
    FStyle: String;
    FSection: String;
    FComplexity: Double;
    FIntensity: Double;
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

function TFunkGenrePlugin.GetGenreName: string;
begin
  Result := 'funk';
end;

function TFunkGenrePlugin.GetSupportedStyles: TStringArray;
begin
  Result := ['classic', 'pfunk', 'shuffle', 'new_orleans', 'fusion',
    'minimal', 'heavy'];
end;

constructor TFunkGenrePlugin.Create;
begin
  inherited Create;
  FStyle := 'classic';
  FSection := 'verse';
  FComplexity := 0.6;
  FIntensity := 0.7;
end;

destructor TFunkGenrePlugin.Destroy;
begin
  inherited Destroy;
end;

procedure TFunkGenrePlugin.SetStyle(const AStyle: String);
begin
  FStyle := LowerCase(AStyle);
end;

procedure TFunkGenrePlugin.SetSection(const ASection: String);
begin
  FSection := LowerCase(ASection);
end;

procedure TFunkGenrePlugin.SetComplexity(AValue: Double);
begin
  if (AValue < 0.0) then FComplexity := 0.0
  else if (AValue > 1.0) then FComplexity := 1.0
  else FComplexity := AValue;
end;

procedure TFunkGenrePlugin.SetIntensity(AValue: Double);
begin
  if (AValue < 0.0) then FIntensity := 0.0
  else if (AValue > 1.0) then FIntensity := 1.0
  else FIntensity := AValue;
end;

function TFunkGenrePlugin.GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double; BarIndex: Integer): TDrumInstrument;
begin
  case (BarIndex mod 2) of
    0: Result := TInstrumentRegistry.Get('cymbal_1_hit');
    1: Result := TInstrumentRegistry.Get('cymbal_3_hit');
  else
    Result := TInstrumentRegistry.Get('cymbal_2_hit');
  end;
end;

function TFunkGenrePlugin.MakeGroove(const AKind: String; AVariant: Integer): TPattern;
begin
  { Grooves are drum tabs in FunkGrooves.pas: three per style and section
    kind, tagged with overlapping intensity bands. }
  Result := BuildTaggedGroove(
    'funk_' + FStyle + '_' + AKind + '_v' + IntToStr(AVariant), AKind,
    AVariant, FunkGrooveLines(FStyle, AKind, AVariant), FComplexity);
end;

function TFunkGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
begin
  Result := MakeGroove('verse', BarIndex mod 3);
end;

function TFunkGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
begin
  Result := MakeGroove('chorus', BarIndex mod 3);
end;

function TFunkGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
begin
  Result := MakeGroove('bridge', BarIndex mod 3);
end;

function TFunkGenrePlugin.GetVerseFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorVerse(BarIndex);
end;

function TFunkGenrePlugin.GetChorusFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorChorus(BarIndex);
end;

function TFunkGenrePlugin.GetBridgeFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorBridge(BarIndex);
end;

function TFunkGenrePlugin.GetSectionGrooves: specialize TList<TPattern>;
var
  GrooveList: specialize TList<TPattern>;
  BarIdx: Integer;
begin
  GrooveList := specialize TList<TPattern>.Create;

  for BarIdx := 0 to 2 do
    GrooveList.Add(GetFlavorVerse(BarIdx));

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorChorus(BarIdx));

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorBridge(BarIdx));

  Result := GrooveList;
end;

function TFunkGenrePlugin.GetCommonFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  var LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;

  LFill := TFill.Create('funk_tom_snap', 'Funk tom snap');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);

  Result := FillList;
end;

function TFunkGenrePlugin.HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument;
begin
  // Funk uses standard ride or crash for high energy
  Result := TInstrumentRegistry.Get('ride_1_tip_hit_softer');
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('ride_1_bell');
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('cymbal_1_hit');
end;

function TFunkGenrePlugin.GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern;
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

function TFunkGenrePlugin.GetSectionFlavors(const Section: string;
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

      for BarIdx := 0 to 2 do
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

function TFunkGenrePlugin.GetSectionFlavorsFiltered(const Section: string; const Parameters: TGenerationParameters; MinIntensity, MaxIntensity: Double): specialize TList<TPattern>;
{ Filter flavors by actual intensity metadata tags rather than list index. }
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
    TryGetIntensityRange(BaseFlavors[I], PMin, PMax);
    PMid := (PMin + PMax) / 2.0;

    { Include if pattern midpoint overlaps the section intensity band. }
    if (PMid >= MinIntensity - 0.15) and (PMid <= MaxIntensity + 0.15) then
      Result.Add(BaseFlavors[I]);
  end;

  if Result.Count = 0 then for I := 0 to BaseFlavors.Count - 1 do Result.Add(BaseFlavors[I]);
end;

end.
