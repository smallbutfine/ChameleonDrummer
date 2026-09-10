unit Funk;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  patterns_templates, generation_builders_pattern_builder,
  plugins_interfaces_genre_plugin;

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

function TFunkGenrePlugin.GetOpenHHCrashVariant(BarIndex: Integer): String;
begin
  case (BarIndex mod 2) of
    0: Result := 'cymbal_1_hit';
    1: Result := 'cymbal_3_hit';
  else
    Result := 'cymbal_2_hit';
  end;
end;

function TFunkGenrePlugin.GetFlavorVerse(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('funk_' + FStyle + '_verse_b' + IntToStr(BarIndex));

  case FStyle of
    'classic':
      begin
        // James Brown "the one" emphasis
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TFunkGhostNotes.Create);
      end;
    'pfunk':
      begin
        // Parliament-Funkadelic grooves
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TFunkGhostNotes.Create);
      end;
    'shuffle':
      begin
        // Bernard Purdie shuffle
        Composer.Add(TBasicGroove.Create);
      end;
    'new_orleans':
      begin
        // Second line funk patterns
        Composer.Add(TBasicGroove.Create);
      end;
    'fusion':
      begin
        // Jazz-funk fusion
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TFunkGhostNotes.Create);
      end;
    'minimal':
      begin
        // Stripped-down pocket grooves
        Composer.Add(TBasicGroove.Create);
      end;
    'heavy':
      begin
        // Heavy funk with rock influence
        Composer.Add(TDoubleBassPedal.Create('gallop', 16));
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TFunkGenrePlugin.GetFlavorChorus(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('funk_' + FStyle + '_chorus_b' + IntToStr(BarIndex));

  case FStyle of
    'classic':
      begin
        Composer.Add(TBasicGroove.Create);
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
      end;
    'pfunk':
      begin
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TFunkGhostNotes.Create);
      end;
    'shuffle':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'new_orleans':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'fusion':
      begin
        Composer.Add(TBasicGroove.Create);
        if (BarIndex mod 2 = 0) then
          Composer.Add(TFunkGhostNotes.Create);
      end;
    'minimal':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'heavy':
      begin
        Composer.Add(TDoubleBassPedal.Create('gallop', 16));
        if (BarIndex mod 2 = 0) then
          Composer.Add(TCrashAccents.Create);
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
end;

function TFunkGenrePlugin.GetFlavorBridge(BarIndex: Integer): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create('funk_' + FStyle + '_bridge_b' + IntToStr(BarIndex));

  case FStyle of
    'classic':
      begin
        if (BarIndex mod 2 = 0) then
          Composer.Add(TBasicGroove.Create)
        else
          Composer.Add(TFunkGhostNotes.Create);
      end;
    'pfunk':
      begin
        Composer.Add(TBasicGroove.Create);
        Composer.Add(TFunkGhostNotes.Create);
      end;
    'shuffle':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'new_orleans':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'fusion':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'minimal':
      begin
        Composer.Add(TBasicGroove.Create);
      end;
    'heavy':
      begin
        Composer.Add(TDoubleBassPedal.Create('burst', 16));
      end;
  else
    Composer.Add(TBasicGroove.Create);
  end;

  Result := Composer.Build(2, FComplexity);
  Composer.Free;
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
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('funk_tom_snap', 'Funk tom snap') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TFunkGenrePlugin.GetHighEnergyTimekeeper: String;
begin
  // Funk uses standard ride or cymbal
  Result := 'ride_1_tip_hit';
end;

end.
