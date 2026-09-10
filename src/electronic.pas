unit Electronic;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  patterns_templates, generation_builders_pattern_builder,
  plugins_interfaces_genre_plugin;

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
    function GetHighEnergyTimekeeper: String; override;

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
    0: Result := 'cymbal_1_hit';
    1: Result := 'cymbal_4_hit';
    2: Result := 'cymbal_6_hit';
  else
    Result := 'ride_1_bell';
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
        // Four on the floor kick pattern
        Composer.Add(TBasicGroove.Create);
      end;
    'techno':
      begin
        // Driving electronic beat
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'drum_and_bass':
      begin
        // Fast breakbeat pattern
        Composer.Add(TBasicGroove.Create);
      end;
    'dubstep':
      begin
        // Heavy half-time feel
        Composer.Add(TDoubleBassPedal.Create('burst', 16));
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
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
      end;
    'techno':
      begin
        Composer.Add(TDoubleBassPedal.Create('continuous', 16));
      end;
    'drum_and_bass':
      begin
        Composer.Add(TBasicGroove.Create);
        if (BarIndex mod 2 = 0) then
          Composer.Add(TTomFill.Create('descending'));
      end;
    'dubstep':
      begin
        Composer.Add(TDoubleBassPedal.Create('burst', 16));
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
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
        if (BarIndex mod 2 = 0) then
          Composer.Add(TBasicGroove.Create)
        else
          Composer.Add(TSteadyRide.Create);
      end;
    'techno':
      begin
        Composer.Add(TDoubleBassPedal.Create('gallop', 16));
      end;
    'drum_and_bass':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'dubstep':
      begin
        if (BarIndex mod 2 = 0) then
          Composer.Add(TDoubleBassPedal.Create('burst', 16))
        else
          Composer.Add(TSteadyRide.Create);
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

  for BarIdx := 0 to 3 do
    GrooveList.Add(GetFlavorVerse(BarIdx));

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorChorus(BarIdx));

  for BarIdx := 0 to 1 do
    GrooveList.Add(GetFlavorBridge(BarIdx));

  Result := GrooveList;
end;

function TElectronicGenrePlugin.GetCommonFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('electronic_tom_drop', 'Electronic tom drop') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TElectronicGenrePlugin.GetHighEnergyTimekeeper: String;
begin
  // Electronic uses ride or cymbal for energy
  Result := 'ride_1_tip_hit';
end;

end.
