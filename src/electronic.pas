unit Electronic;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  patterns_templates,
  Kit,
  generation_parameters,
  GenrePlugin;

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
    function GetOpenHHCrashVariant(BarIndex: Integer): String;
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

    function GetSectionGrooves: specialize TList<TPattern>;
    function GetCommonFills: specialize TList<TFill>;
    function HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument; override;

    function GetVerseFlavor(BarIndex: Integer): TPattern;
    function GetChorusFlavor(BarIndex: Integer): TPattern;
    function GetBridgeFlavor(BarIndex: Integer): TPattern;
  end;

implementation

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

function TElectronicGenrePlugin.GetOpenHHCrashVariant(BarIndex: Integer): String;
begin
  case (BarIndex mod 3) of
    0: Result := 'cymbal_4_hit';
    1: Result := 'cymbal_2_hit';
  else
    Result := 'cymbal_6_hit';
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
  Result := TInstrumentRegistry.Register('ride_1_tip_hit', 'Ride cymbal');
end;

end.
