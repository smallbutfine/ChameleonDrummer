unit Rock;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  patterns_templates, generation_builders_pattern_builder,
  plugins_interfaces_genre_plugin;

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

    function GetSectionGrooves: TList<TPattern>;
    function GetCommonFills: TList<TFill>;
    function GetHighEnergyTimekeeper: String; override;

    function GetVerseFlavor(BarIndex: Integer): TPattern;
    function GetChorusFlavor(BarIndex: Integer): TPattern;
    function GetBridgeFlavor(BarIndex: Integer): TPattern;
  end;

implementation

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
  Result := 'ride_1_tip_hit';
end;

function TRockGenrePlugin.GetOpenHHCrashVariant(BarIndex: Integer): String;
begin
  case (BarIndex mod 2) of
    0: Result := 'cymbal_1_hit'; // crash 1
    1: Result := 'cymbal_2_hit'; // crash 2
  else
    Result := 'cymbal_3_hit';
  end;
end;

function TRockGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('rock_' + FStyle + '_verse_b' + IntToStr(BarIndex));

  case FStyle of
    'classic':
      begin
        // Led Zeppelin/Deep Purple style
        Composer.Add(TBasicGroove.Create);
        if (BarIndex mod 2 = 0) then
          Composer.Add(TTomFill.Create('descending'));
      end;
    'blues':
      begin
        // Blues rock with shuffle feel
        Composer.Add(TBasicGroove.Create);
      end;
    'alternative':
      begin
        // 90s alternative syncopation
        Composer.Add(TBasicGroove.Create);
        if (BarIndex mod 3 = 0) then
          Composer.Add(TTomFill.Create('descending'));
      end;
    'progressive':
      begin
        // Complex progressive rock
        Composer.Add(TBasicGroove.Create);
      end;
    'punk':
      begin
        // Fast aggressive punk
        Composer.Add(TBasicGroove.Create);
      end;
    'hard':
      begin
        // Hard rock heavy emphasis
        Composer.Add(TBasicGroove.Create);
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
      end;
    'pop':
      begin
        // Clean pop rock
        Composer.Add(TBasicGroove.Create);
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TRockGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('rock_' + FStyle + '_chorus_b' + IntToStr(BarIndex));

  case FStyle of
    'classic':
      begin
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TCrashAccents.Create);
      end;
    'blues':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'alternative':
      begin
        Composer.Add(TBasicGroove.Create);
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
      end;
    'progressive':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'punk':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'hard':
      begin
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TCrashAccents.Create);
      end;
    'pop':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TRockGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('rock_' + FStyle + '_bridge_b' + IntToStr(BarIndex));

  case FStyle of
    'classic':
      begin
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TTomFill.Create('descending'));
      end;
    'blues':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'alternative':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'progressive':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'punk':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'hard':
      begin
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TCrashAccents.Create);
      end;
    'pop':
      begin
        Composer.Add(TSteadyRide.Create);
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
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

function TRockGenrePlugin.GetSectionGrooves: TList<TPattern>;
var
  GrooveList: TList<TPattern>;
  BarIdx: Integer;
begin
  GrooveList := TList<TPattern>.Create;

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

function TRockGenrePlugin.GetCommonFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('rock_tom_downfill', 'Rock tom cascade') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TRockGenrePlugin.GetHighEnergyTimekeeper: String;
begin
  // Rock uses standard ride, no china override
  Result := GetRideTimekeeper;
end;

end.
