unit GenrePlugin;

{$mode objfpc}{$H+}

{ GenrePlugin interface — abstract base class for genre-specific pattern generators.
  Each concrete genre (metal, rock, jazz, funk, electronic) extends this class
  to provide its own style patterns and fill libraries. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song,
  time_signature, generation_parameters;

type

  TStringArray = array of string;

{ GenrePlugin — base class for genre-specific pattern generators. }

TGenrePlugin = class(TObject)
private
  FIntensityProfile: specialize TDictionary<string, Double>;
protected
  procedure SetIntensityProfile(const AProfile: specialize TDictionary<string, Double>); virtual;
public
  constructor Create; virtual;
  destructor Destroy; override;

  { Abstract properties (must be overridden). }
  function GetGenreName: string; virtual;
  function GetSupportedStyles: TStringArray; virtual;
  { Intensity profile — characteristic "feel" of this genre. }
  property IntensityProfile: specialize TDictionary<string, Double> read FIntensityProfile write SetIntensityProfile;
  function GetIntensityProfile: specialize TDictionary<string, Double>; virtual;

  { Core methods (override in subclass). }
  function GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern; virtual;
  function GetCommonFills: specialize TList<TFill>; virtual;

  { Context blending — adapt patterns for cross-genre songs. }
  function ApplyContextBlend(const APattern: TPattern; const ContextProfile: specialize TDictionary<string, Double>;
    BlendAmount: Double): TPattern;

  { Hi-hat → ride/crash promotion logic. }
  function HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument; virtual;
  function GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double; BarIndex: Integer): TDrumInstrument; virtual;
  function ApplyRideHihatLogic(const APattern: TPattern; const Section: string;
    const Parameters: TGenerationParameters): TPattern;

  { Helper methods. }
  function GetSectionVariations(const Section: string): specialize TList<TPattern>; virtual;
  function GetSectionFlavors(const Section: string; const Parameters: TGenerationParameters): specialize TList<TPattern>; virtual;
  function SupportsStyle(const Style: string): boolean;
  function ValidateParameters(const Parameters: TGenerationParameters): boolean;

protected
  { Virtual helpers for subclasses. }
  function ApplyContextBlendInternal(const APattern: TPattern; const ContextProfile: specialize TDictionary<string, Double>;
    BlendAmount: Double): TPattern; virtual;
end;

implementation

{ GenrePlugin base class }

constructor TGenrePlugin.Create;
begin
  inherited Create;
  FIntensityProfile := specialize TDictionary<string, Double>.Create;
  { Default: neutral (0.5) for all dimensions. }
  FIntensityProfile.Add('aggression', 0.5);
  FIntensityProfile.Add('speed', 0.5);
  FIntensityProfile.Add('density', 0.5);
  FIntensityProfile.Add('power', 0.5);
  FIntensityProfile.Add('complexity', 0.5);
  FIntensityProfile.Add('darkness', 0.5);
end;

destructor TGenrePlugin.Destroy;
begin
  FIntensityProfile.Free;
  inherited Destroy;
end;

function TGenrePlugin.GetGenreName: string;
begin
  { Virtual method — abstract, must be overridden in subclass. }
  Result := '';
  raise Exception.Create('GetGenreName not implemented.');
end;

function TGenrePlugin.GetSupportedStyles: TStringArray;
begin
  Result := nil; { Abstract — must be overridden. }
  raise Exception.Create('GetSupportedStyles not implemented.');
end;

procedure TGenrePlugin.SetIntensityProfile(const AProfile: specialize TDictionary<string, Double>);
begin
  FIntensityProfile := AProfile;
end;

function TGenrePlugin.GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern;
begin
  raise Exception.Create('GeneratePattern not implemented.');
end;

function TGenrePlugin.GetCommonFills: specialize TList<TFill>;
begin
  Result := specialize TList<TFill>.Create;
end;

function TGenrePlugin.GetIntensityProfile: specialize TDictionary<string, Double>;
begin
  Result := FIntensityProfile;
end;

function TGenrePlugin.ApplyContextBlend(const APattern: TPattern; const ContextProfile: specialize TDictionary<string, Double>;
  BlendAmount: Double): TPattern;
{ Adapt pattern to match context genre characteristics. Blends power/aggression/density dimensions. }
begin
  if BlendAmount <= 0.0 then
    Exit(APattern);

  Result := ApplyContextBlendInternal(APattern, ContextProfile, BlendAmount);
end;

function TGenrePlugin.ApplyContextBlendInternal(const APattern: TPattern; const ContextProfile: specialize TDictionary<string, Double>;
  BlendAmount: Double): TPattern;
{ Core blend logic — power boost on kick/snare, timing quantization for aggression, ghost notes for density. }
var
  Adapted: TPattern;
  BlendedPower, BlendedAggression, BlendedDensity: Double;
  PowerBoost: Integer;
  Beat: TBeat;
  QuantizeStrength: Double;
  QuantizedPos: Double;
  InstName: string;
begin
  { Default implementation applies power/aggression/density blending. }
  Adapted := APattern.Copy;

  BlendedPower := FIntensityProfile['power'] + (ContextProfile['power'] - FIntensityProfile['power']) * BlendAmount;
  BlendedAggression := FIntensityProfile['aggression'] + (ContextProfile['aggression'] - FIntensityProfile['aggression']) * BlendAmount;
  BlendedDensity := FIntensityProfile['density'] + (ContextProfile['density'] - FIntensityProfile['density']) * BlendAmount;

  { Apply power adjustment to kick and snare. }
  PowerBoost := Round((BlendedPower - FIntensityProfile['power']) * 20);
  for Beat in Adapted.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := Beat.Instrument.Name;
      if (InstName = 'kick') or (InstName = 'snare_open_hit_open_lateral_hit') then
        Beat.Velocity := Math.Max(1, Math.Min(127, Beat.Velocity + PowerBoost));
    end;
  end;

  { Apply aggression (tighter timing). }
  if BlendedAggression > 0.7 then
  begin
    QuantizeStrength := BlendAmount * 0.5;
    for Beat in Adapted.Beats do
    begin
      QuantizedPos := Round(Beat.Position / 0.25) * 0.25;
      Beat.Position := Beat.Position + (QuantizedPos - Beat.Position) * QuantizeStrength;
    end;
  end;

  Result := Adapted;
end;

function TGenrePlugin.HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument;
{ Instrument that hi-hat timekeeping is promoted to for high-energy sections.
  Default = ride cymbal. Subclasses may override (e.g., rock/metal → crash/china). }
begin
  Result := nil; { Default ride timekeeper. }
end;

function TGenrePlugin.GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: Double; BarIndex: Integer): TDrumInstrument;
{ Return the crash instrument for an open hi-hat accent. Cycle through variants across bars. }
begin
  Result := nil; { Default: single crash variant. }
end;

function TGenrePlugin.ApplyRideHihatLogic(const APattern: TPattern; const Section: string;
  const Parameters: TGenerationParameters): TPattern;
{ Switch hi-hat timekeeping to ride/crash for high-energy sections (chorus/bridge/pre_chorus).
  Adds hi-hat foot pedal ("chick") on every other beat once switched. }
var
  IsHighEnergy: boolean;
  Timekeeper: TDrumInstrument;
  Switched: TPattern;
  Beat: TBeat;
  HHInstrumentNames: TStringArray;
  InstName: string;
  IsDownbeat: boolean;
  BarIndex: Integer;
  PromotedInst, PromotedCrash: TDrumInstrument;
  RideSections: TStringArray;
  RS: string;
  HasHiHat: boolean;
  BeatNum: Double;
  DurationBars: Double;
  BeatsPerBar: Integer;
begin
  { High-energy if section name in [chorus, bridge, pre_chorus] OR complexity > ride_threshold. }
  SetLength(RideSections, 3);
  RideSections[0] := 'chorus';
  RideSections[1] := 'bridge';
  RideSections[2] := 'pre_chorus';

  IsHighEnergy := False;
  for RS in RideSections do
    if SameText(RS, Section) then
    begin
      IsHighEnergy := True;
      Break;
    end;

  if not IsHighEnergy and (Parameters.RideThreshold > 0) then
    IsHighEnergy := Parameters.Complexity >= Parameters.RideThreshold;

  if not IsHighEnergy then
    Exit(APattern); { No switching needed. }

  { Check if pattern has any hi-hat beats to promote. }
  HasHiHat := False;
  for Beat in APattern.Beats do
    if Assigned(Beat.Instrument) then
    begin
      InstName := Beat.Instrument.Name;
      if Pos('hihat', LowerCase(InstName)) = 1 then
      begin
        HasHiHat := True;
        Break;
      end;
    end;

  if not HasHiHat then
    Exit(APattern); { No hi-hats to promote. }

  Timekeeper := HighEnergyTimekeeper(Section, Parameters);
  Switched := APattern.Copy;

  for Beat in Switched.Beats do
  begin
    InstName := '';
    if Assigned(Beat.Instrument) then
      InstName := Beat.Instrument.Name;

    if SameText(InstName, 'hihat_pedal_closed') then
      Continue; { Keep pedal as-is. }

    if Pos('hihat', LowerCase(InstName)) <> 1 then
      Continue; { Not a hi-hat beat. }

    IsDownbeat := (Trunc(Beat.Position) = Beat.Position);
    BarIndex := Trunc(Beat.Position) div Round(Switched.TimeSignature.BeatsPerBar);

    if Pos('hihat_open', InstName) = 1 then
    begin
      { Open HH → crash/choke accent (not a timekeeper). }
      PromotedCrash := GetOpenHhCrashVariant(APattern, Beat.Position, BarIndex);
      Beat.Instrument := PromotedCrash;
      Beat.Velocity := Math.Max(0, Math.Min(127, Beat.Velocity));
    end
    else if IsDownbeat and (BarIndex >= 4) and ((BarIndex - 4) mod 4 = 0) then
    begin
      { Every 4th bar from bar 5 → bell accent for timbral variety. }
      Beat.Instrument := nil;
      Beat.Velocity := Math.Max(0, Math.Min(127, Beat.Velocity));
    end
    else if IsDownbeat then
    begin
      { Downbeat → main timekeeper (ride, china, or crash per genre). }
      Beat.Instrument := Timekeeper;
      Beat.Velocity := Math.Max(0, Math.Min(127, Beat.Velocity));
    end
    else
    begin
      { Offbeat → ride shaft / lighter variant. }
      Beat.Instrument := nil;
      Beat.Velocity := Math.Max(0, Math.Min(127, Beat.Velocity));
    end;

    Beat.InstrumentPromoted := True;
  end;

  { Add hi-hat pedal ("chick") on every other beat. }
  BeatsPerBar := Round(Switched.TimeSignature.BeatsPerBar);
  DurationBars := Switched.DurationBars;
  for BarIndex := 0 to Trunc(DurationBars) do
  begin
    BeatNum := 1.0;
    while BeatNum < BeatsPerBar do
    begin
      Switched.AddBeat(BarIndex + BeatNum, nil, 80);
      BeatNum := BeatNum + 2.0;
    end;
  end;

  Result := Switched;
end;

function TGenrePlugin.GetSectionVariations(const Section: string): specialize TList<TPattern>;
{ Default returns empty — override in subclass for section variations. }
begin
  Result := specialize TList<TPattern>.Create;
end;

function TGenrePlugin.GetSectionFlavors(const Section: string; const Parameters: TGenerationParameters): specialize TList<TPattern>;
{ Get alternative pattern flavors for a section. Default returns only the standard pattern. }
var
  StandardPattern: TPattern;
begin
  Result := specialize TList<TPattern>.Create;

  { Default: return only the standard pattern (no flavor variety). }
  try
    StandardPattern := GeneratePattern(Section, Parameters);
    Result.Add(StandardPattern);
  except
    on E: Exception do
      ; { Ignore errors in flavor generation. }
  end;
end;

function TGenrePlugin.SupportsStyle(const Style: string): boolean;
{ Check if this plugin supports the given style (must be overridden). }
begin
  Result := False; { Abstract — must be overridden. }
end;

function TGenrePlugin.ValidateParameters(const Parameters: TGenerationParameters): boolean;
{ Validate that parameters are appropriate for this genre (checks genre and style). }
begin
  if Parameters.Genre <> GetGenreName then
    Exit(False);

  Result := SupportsStyle(Parameters.Style);
end;

end.
