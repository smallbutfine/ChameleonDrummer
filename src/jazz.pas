unit Jazz;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  patterns_templates, generation_builders_pattern_builder,
  plugins_interfaces_genre_plugin;

type
  TJazzContext = record
    Style: String;
    Section: String;
    Complexity: Double;
    Intensity: Double;
  end;

  TJazzGenrePlugin = class(TGenrePlugin)
  private
    FStyle: String;
    FSection: String;
    FComplexity: Double;
    FIntensity: Double;
    function GetRideSwingPattern: String;
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
    function GetHighEnergyTimekeeper: String; override;

    function GetVerseFlavor(BarIndex: Integer): TPattern;
    function GetChorusFlavor(BarIndex: Integer): TPattern;
    function GetBridgeFlavor(BarIndex: Integer): TPattern;
  end;

implementation

constructor TJazzGenrePlugin.Create;
begin
  inherited Create;
  FStyle := 'swing';
  FSection := 'verse';
  FComplexity := 0.6;
  FIntensity := 0.5;
end;

destructor TJazzGenrePlugin.Destroy;
begin
  inherited Destroy;
end;

procedure TJazzGenrePlugin.SetStyle(const AStyle: String);
begin
  FStyle := LowerCase(AStyle);
end;

procedure TJazzGenrePlugin.SetSection(const ASection: String);
begin
  FSection := LowerCase(ASection);
end;

procedure TJazzGenrePlugin.SetComplexity(AValue: Double);
begin
  if (AValue < 0.0) then FComplexity := 0.0
  else if (AValue > 1.0) then FComplexity := 1.0
  else FComplexity := AValue;
end;

procedure TJazzGenrePlugin.SetIntensity(AValue: Double);
begin
  if (AValue < 0.0) then FIntensity := 0.0
  else if (AValue > 1.0) then FIntensity := 1.0
  else FIntensity := AValue;
end;

function TJazzGenrePlugin.GetRideSwingPattern: String;
begin
  // Jazz uses ride pattern with swing feel
  Result := 'ride_1_tip_hit';
end;

function TJazzGenrePlugin.GetOpenHHCrashVariant(BarIndex: Integer): String;
begin
  case (BarIndex mod 2) of
    0: Result := 'cymbal_1_hit';
    1: Result := 'cymbal_2_hit';
  else
    Result := 'ride_1_bell';
  end;
end;

function TJazzGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('jazz_' + FStyle + '_verse_b' + IntToStr(BarIndex));

  case FStyle of
    'swing':
      begin
        // Traditional swing with ride pattern
        Composer.Add(TJazzRidePattern.Create('swing'));
      end;
    'bebop':
      begin
        // Fast complex bebop
        Composer.Add(TJazzRidePattern.Create('elvin'));
      end;
    'fusion':
      begin
        // Electric jazz fusion energy
        Composer.Add(TBasicGroove.Create);
      end;
    'latin':
      begin
        // Latin jazz clave patterns
        Composer.Add(TBasicGroove.Create);
      end;
    'ballad':
      begin
        // Soft brushed ballad
        Composer.Add(TSteadyRide.Create);
      end;
    'hard_bop':
      begin
        // Aggressive hard bop
        Composer.Add(TJazzRidePattern.Create('swing'));
      end;
    'contemporary':
      begin
        // Modern contemporary jazz
        Composer.Add(TJazzRidePattern.Create('tony'));
      end;
  else
    Composer.Add(TSteadyRide.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TJazzGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('jazz_' + FStyle + '_chorus_b' + IntToStr(BarIndex));

  case FStyle of
    'swing':
      begin
        Composer.Add(TJazzRidePattern.Create('swing'));
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
      end;
    'bebop':
      begin
        Composer.Add(TJazzRidePattern.Create('elvin'));
      end;
    'fusion':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'latin':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'ballad':
      begin
        Composer.Add(TSteadyRide.Create);
      end;
    'hard_bop':
      begin
        Composer.Add(TJazzRidePattern.Create('swing'));
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
      end;
    'contemporary':
      begin
        Composer.Add(TJazzRidePattern.Create('tony'));
      end;
  else
    Composer.Add(TSteadyRide.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TJazzGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('jazz_' + FStyle + '_bridge_b' + IntToStr(BarIndex));

  case FStyle of
    'swing':
      begin
        // Bridge â€” switch to ride bell or hi-hat
        if (BarIndex mod 2 = 0) then
          Composer.Add(TSteadyRide.Create)
        else
          Composer.Add(TJazzRidePattern.Create('swing'));
      end;
    'bebop':
      begin
        Composer.Add(TJazzRidePattern.Create('elvin'));
      end;
    'fusion':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'latin':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'ballad':
      begin
        Composer.Add(TSteadyRide.Create);
      end;
    'hard_bop':
      begin
        Composer.Add(TJazzRidePattern.Create('swing'));
      end;
    'contemporary':
      begin
        Composer.Add(TJazzRidePattern.Create('tony'));
      end;
  else
    Composer.Add(TSteadyRide.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TJazzGenrePlugin.GetVerseFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorVerse(BarIndex);
end;

function TJazzGenrePlugin.GetChorusFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorChorus(BarIndex);
end;

function TJazzGenrePlugin.GetBridgeFlavor(BarIndex: Integer): TPattern;
begin
  Result := GetFlavorBridge(BarIndex);
end;

function TJazzGenrePlugin.GetSectionGrooves: specialize TList<TPattern>;
var
  GrooveList: specialize TList<TPattern>;
  BarIdx: Integer;
begin
  GrooveList := specialize TList<TPattern>.Create;

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorVerse(BarIdx));

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorChorus(BarIdx));

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorBridge(BarIdx));

  Result := GrooveList;
end;

function TJazzGenrePlugin.GetCommonFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('jazz_tom_roll', 'Jazz tom roll') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TJazzGenrePlugin.GetHighEnergyTimekeeper: String;
begin
  // Jazz uses ride bell for energy
  Result := 'ride_1_bell';
end;

end.
