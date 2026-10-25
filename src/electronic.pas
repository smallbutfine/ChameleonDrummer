unit Electronic;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  patterns_templates,
  Kit,
  generation_parameters,
  GenrePlugin,
  config_constants;

type
  TElectronicContext = record
    Style: String;
    Section: String;
    Complexity: Double;
    Intensity: Double;
  end;

  TElectronicGenrePlugin = class(TGenrePlugin)
  private
    FStyle: String;
    FSection: String;
    FComplexity: Double;
    FIntensity: Double;
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

function TElectronicGenrePlugin.GetGenreName: string;
begin
  Result := 'electronic';
end;

function TElectronicGenrePlugin.GetSupportedStyles: TStringArray;
begin
  Result := ['house', 'techno', 'drum_and_bass', 'dubstep'];
end;

constructor TElectronicGenrePlugin.Create;
begin
  inherited Create;
  FStyle := 'house';
  FSection := 'verse';
  FComplexity := 0.5;
  FIntensity := 0.6;
end;

destructor TElectronicGenrePlugin.Destroy;
begin
  inherited Destroy;
end;

procedure TElectronicGenrePlugin.SetStyle(const AStyle: String);
begin
  FStyle := LowerCase(AStyle);
end;

procedure TElectronicGenrePlugin.SetSection(const ASection: String);
begin
  FSection := LowerCase(ASection);
end;

procedure TElectronicGenrePlugin.SetComplexity(AValue: Double);
begin
  if (AValue < 0.0) then FComplexity := 0.0
  else if (AValue > 1.0) then FComplexity := 1.0
  else FComplexity := AValue;
end;

procedure TElectronicGenrePlugin.SetIntensity(AValue: Double);
begin
  if (AValue < 0.0) then FIntensity := 0.0
  else if (AValue > 1.0) then FIntensity := 1.0
  else FIntensity := AValue;
end;

function TElectronicGenrePlugin.GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double; BarIndex: Integer): TDrumInstrument;
begin
  case (BarIndex mod 3) of
    0: Result := TInstrumentRegistry.Get('cymbal_4_hit');
    1: Result := TInstrumentRegistry.Get('cymbal_2_hit');
  else
    Result := TInstrumentRegistry.Get('cymbal_6_hit');
  end;
end;

function TElectronicGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('electronic_' + FStyle + '_verse_b' + IntToStr(BarIndex));
  case FStyle of
    'house':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'techno':
      begin
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'drum_and_bass':
      begin
        Composer.Add(TDoubleBassPedal.Create('burst', 16));
      end;
    'dubstep':
      begin
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;
  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TElectronicGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('electronic_' + FStyle + '_chorus_b' + IntToStr(BarIndex));
  case FStyle of
    'house':
      begin
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TCrashAccents.Create);
      end;
    'techno':
      begin
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'drum_and_bass':
      begin
        Composer.Add(TDoubleBassPedal.Create('burst', 16));
      end;
    'dubstep':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;
  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TElectronicGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('electronic_' + FStyle + '_bridge_b' + IntToStr(BarIndex));
  case FStyle of
    'house':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'techno':
      begin
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'drum_and_bass':
      begin
        Composer.Add(TDoubleBassPedal.Create('burst', 16));
      end;
    'dubstep':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;
  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TElectronicGenrePlugin.GetVerseFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorVerse(BarIndex);
end;

function TElectronicGenrePlugin.GetChorusFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorChorus(BarIndex);
end;

function TElectronicGenrePlugin.GetBridgeFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorBridge(BarIndex);
end;

function TElectronicGenrePlugin.GetSectionGrooves: specialize TList<TPattern>;
var
  GrooveList: specialize TList<TPattern>;
  BarIdx: Integer;
begin
  GrooveList := specialize TList<TPattern>.Create;
  for BarIdx := 0 to 2 do
    GrooveList.Add(GetFlavorVerse(BarIdx));
  case FStyle of
    'house', 'techno':
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

function TElectronicGenrePlugin.GetCommonFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('electronic_tom_drop', 'Electronic tom drop');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TElectronicGenrePlugin.HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument;
begin
  // Electronic drives high-energy sections with a crash-style timekeeper
  Result := TInstrumentRegistry.Get('cymbal_1_hit');
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('ride_1_tip_hit_softer');
  if not Assigned(Result) then
    Result := TInstrumentRegistry.Get('ride_1_bell');
end;

function TElectronicGenrePlugin.GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern;
var
  Patterns: specialize TList<TPattern>;
  PatternItem: TPattern;
begin
  Patterns := GetSectionFlavors(Section, Parameters);
  try
    if Patterns.Count = 0 then
      raise Exception.CreateFmt(
        'No electronic patterns available for section %s', [Section]);
    Result := Patterns[0].Copy;
  finally
    for PatternItem in Patterns do
      PatternItem.Free;
    Patterns.Free;
  end;
end;

function TElectronicGenrePlugin.GetSectionFlavors(const Section: string;
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
      begin
        if (Pos('chorus', SectionName) > 0) then
          Result.Add(GetFlavorChorus(BarIdx))
        else if (Pos('bridge', SectionName) > 0) or
                (Pos('pre_chorus', SectionName) > 0) or
                (Pos('breakdown', SectionName) > 0) then
          Result.Add(GetFlavorBridge(BarIdx))
        else
          Result.Add(GetFlavorVerse(BarIdx));
      end;
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

function TElectronicGenrePlugin.GetSectionFlavorsFiltered(const Section: string; const Parameters: TGenerationParameters; MinIntensity, MaxIntensity: Double): specialize TList<TPattern>;
var
  BaseFlavors: specialize TList<TPattern>;
  I: Integer;
begin
  Result := specialize TList<TPattern>.Create;
  BaseFlavors := GetSectionFlavors(Section, Parameters);
  if not Assigned(BaseFlavors) or (BaseFlavors.Count = 0) then Exit;
  for I := 0 to BaseFlavors.Count - 1 do
  begin
    case I of
      0: if (MaxIntensity > 0.0) and (MinIntensity < 0.4) then Result.Add(BaseFlavors[I]);
      1: if (MaxIntensity > 0.35) and (MinIntensity < 0.7) then Result.Add(BaseFlavors[I]);
    else
      if (MaxIntensity > 0.65) then Result.Add(BaseFlavors[I]);
    end;
  end;
  if Result.Count = 0 then for I := 0 to BaseFlavors.Count - 1 do Result.Add(BaseFlavors[I]);
end;

end.
