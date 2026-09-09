unit genre_plugin;

{$mode objfpc}{$H+}

{ GenrePlugin interface — abstract base class for genre-specific pattern generators.
  Each concrete genre (metal, rock, jazz, funk, electronic) extends this class
  to provide its own style patterns and fill libraries. }

interface

uses
  Classes, SysUtils, Generics.Collections, kit, pattern, song,
  time_signature, generation_parameters;

type

{ GenrePlugin — abstract base class for genre-specific pattern generators.
  Concrete implementations (MetalGenrePlugin, RockGenrePlugin, etc.) must:
  - Override genre_name and supported_styles properties
  - Implement generate_pattern() for each section type
  - Implement get_common_fills() to return characteristic fills }

TGenrePlugin = abstract class(TObject)
private
  FIntensityProfile: TDictionary<string, float>; { cached. */

protected
  procedure SetIntensityProfile(const AProfile: TDictionary<string, float>); virtual;

public
  constructor Create; virtual;
  destructor Destroy; override;

  { ── Abstract properties (must be overridden). */ }
  property GenreName: string read GetGenreName write SetGenreName abstract;
  property SupportedStyles: TArray<string> read GetSupportedStyles write SetSupportedStyles abstract;

  { ── Intensity profile — characteristic "feel" of this genre. */ }
  property IntensityProfile: TDictionary<string, float> read FIntensityProfile write SetIntensityProfile;
  function GetIntensityProfile: TDictionary<string, float>; virtual;

  { ── Core abstract methods. */ }
  function GeneratePattern(const Section: string; const Parameters: TGenerationParameters): TPattern; abstract;
  function GetCommonFills: TObjectList<TFill>; abstract;

  { ── Context blending — adapt patterns for cross-genre songs. */ }
  function ApplyContextBlend(const APattern: TPattern; const ContextProfile: TDictionary<string, float>;
    BlendAmount: float): TPattern;

  { ── Hi-hat → ride/crash promotion logic. */ }
  function HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument; virtual;
  function GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: float; BarIndex: Integer): TDrumInstrument; virtual;
  function ApplyRideHihatLogic(const APattern: TPattern; const Section: string;
    const Parameters: TGenerationParameters): TPattern;

  { ── Helper methods. */ }
  function GetSectionVariations(const Section: string): TObjectList<TPattern>; virtual;
  function GetSectionFlavors(const Section: string; const Parameters: TGenerationParameters): TObjectList<TPattern>; virtual;
  function SupportsStyle(const Style: string): boolean;
  function ValidateParameters(const Parameters: TGenerationParameters): boolean;

protected
  { Virtual helpers for subclasses. */ }
  function ApplyContextBlendInternal(const APattern: TPattern; const ContextProfile: TDictionary<string, float>;
    BlendAmount: float): TPattern; virtual;
end;

{ ── Promotable timekeeping cymbals set (shared with timekeeping.pas). */ }

{ Note: Actual set is defined in timekeeping.pas. This unit references it. */

implementation

{ ── GenrePlugin base class ──────────────────────────────────────────────── }

constructor TGenrePlugin.Create;
begin
  inherited Create;
  FIntensityProfile := TDictionary<string, float>.Create;
  { Default: neutral (0.5) for all dimensions. */
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
  { Virtual method — abstract, must be overridden in subclass. */
  raise Exception.Create('GetGenreName not implemented.');
end;

procedure TGenrePlugin.SetGenreName(const Value: string);
begin
  FIntensityProfile := nil; { Stub. */
end;

function TGenrePlugin.GetSupportedStyles: TArray<string>;
begin
  Result := nil; { Abstract — must be overridden. */
end;

procedure TGenrePlugin.SetSupportedStyles(const Value: TArray<string>);
begin
  { Stub. */
end;

function TGenrePlugin.GetIntensityProfile: TDictionary<string, float>;
begin
  Result := FIntensityProfile;
end;

function TGenrePlugin.ApplyContextBlend(const APattern: TPattern; const ContextProfile: TDictionary<string, float>;
  BlendAmount: float): TPattern;
{ Adapt pattern to match context genre characteristics. Blends power/aggression/density dimensions. */
begin
  if BlendAmount <= 0.0 then
    Exit(APattern);

  Result := ApplyContextBlendInternal(APattern, ContextProfile, BlendAmount);
end;

function TGenrePlugin.ApplyContextBlendInternal(const APattern: TPattern; const ContextProfile: TDictionary<string, float>;
  BlendAmount: float): TPattern;
{ Core blend logic — power boost on kick/snare, timing quantization for aggression, ghost notes for density. */
var
  Adapted: TPattern;
  BlendedPower, BlendedAggression, BlendedDensity: float;
  PowerBoost: Integer;
  Beat: TBeat;
  QuantizeStrength: float;
  QuantizedPos: float;
begin
  { Default implementation applies power/aggression/density blending. */
  Adapted := APattern.Copy;

  BlendedPower := FIntensityProfile['power'] + (ContextProfile['power'] - FIntensityProfile['power']) * BlendAmount;
  BlendedAggression := FIntensityProfile['aggression'] + (ContextProfile['aggression'] - FIntensityProfile['aggression']) * BlendAmount;
  BlendedDensity := FIntensityProfile['density'] + (ContextProfile['density'] - FIntensityProfile['density']) * BlendAmount;

  { Apply power adjustment to kick and snare. */
  PowerBoost := Round((BlendedPower - FIntensityProfile['power']) * 20);
  for Beat in Adapted.FBeats do
  begin
    if Assigned(Beat.FInstrument) then
    begin
      var InstName := Beat.FInstrument.Name;
      if (InstName = 'kick') or (InstName = 'snare_open_hit_open_lateral_hit') then
        Beat.FVelocity := Max(1, Min(127, Beat.FVelocity + PowerBoost));
    end;
  end;

  { Apply aggression (tighter timing). */
  if BlendedAggression > 0.7 then
  begin
    QuantizeStrength := BlendAmount * 0.5;
    for Beat in Adapted.FBeats do
    begin
      QuantizedPos := Round(Beat.FPosition / 0.25) * 0.25;
      Beat.FPosition := Beat.FPosition + (QuantizedPos - Beat.FPosition) * QuantizeStrength;
    end;
  end;

  { Apply density (add ghost notes on snare). */
  if BlendedDensity > FIntensityProfile['density'] then
  begin
    var DensityIncrease := (BlendedDensity - FIntensityProfile['density']) * BlendAmount;
    if DensityIncrease > 0.2 then
    begin
      for Beat in Adapted.FBeats do
        if Assigned(Beat.FInstrument) and (Beat.FInstrument.Name = 'snare_rimshot_open_hit') then
          if not Beat.FGhostNote then
            { Add ghost note before main hit (simplified). */
    end;
  end;

  Result := Adapted;
end;

function TGenrePlugin.HighEnergyTimekeeper(const Section: string; const Parameters: TGenerationParameters): TDrumInstrument;
{ Instrument that hi-hat timekeeping is promoted to for high-energy sections.
  Default = ride cymbal. Subclasses may override (e.g., rock/metal → crash/china). */
begin
  Result := TInstrumentRegistry.Get('ride_1_tip_hit_softer'); { Default ride timekeeper. */
end;

function TGenrePlugin.GetOpenHhCrashVariant(const APattern: TPattern; BeatPos: float; BarIndex: Integer): TDrumInstrument;
{ Return the crash instrument for an open hi-hat accent. Cycle through variants across bars. */
begin
  Result := TInstrumentRegistry.Get('cymbal_2_hit'); { Default: single crash variant. */
end;

function TGenrePlugin.ApplyRideHihatLogic(const APattern: TPattern; const Section: string;
  const Parameters: TGenerationParameters): TPattern;
{ Switch hi-hat timekeeping to ride/crash for high-energy sections (chorus/bridge/pre_chorus).
  Adds hi-hat foot pedal ("chick") on every other beat once switched. */
var
  IsHighEnergy: boolean;
  Timekeeper: TDrumInstrument;
  Switched: TPattern;
  Beat: TBeat;
  HHInstrumentNames: TArray<string>;
  InstName: string;
  IsDownbeat: boolean;
  BarIndex: Integer;
  PromotedInst, PromotedCrash: TDrumInstrument;
begin
  { High-energy if section name in [chorus, bridge, pre_chorus] OR complexity > ride_threshold. */
  const RideSections: TArray<string> = ['chorus', 'bridge', 'pre_chorus'];

  IsHighEnergy := false;
  for var RS in RideSections do
    if SameText(RS, Section) then
    begin
      IsHighEnergy := true;
      Break;
    end;

  if not IsHighEnergy and (Parameters.FRideThreshold > 0) then
    IsHighEnergy := Parameters.FComplexity >= Parameters.FRideThreshold;

  if not IsHighEnergy then
    Exit(APattern); { No switching needed. */

  { Check if pattern has any hi-hat beats to promote. */
  var HasHiHat := false;
  for Beat in APattern.FBeats do
    if Assigned(Beat.FInstrument) then
    begin
      InstName := Beat.FInstrument.Name;
      if Pos('hihat', LowerCase(InstName)) = 1 then
      begin
        HasHiHat := true;
        Break;
      end;
    end;

  if not HasHiHat then
    Exit(APattern); { No hi-hats to promote. */

  Timekeeper := HighEnergyTimekeeper(Section, Parameters);
  Switched := APattern.Copy;

  for Beat in Switched.FBeats do
  begin
    InstName := '';
    if Assigned(Beat.FInstrument) then
      InstName := Beat.FInstrument.Name;

    if SameText(InstName, 'hihat_pedal_closed') then
      Continue; { Keep pedal as-is. */

    if Pos('hihat', LowerCase(InstName)) <> 1 then
      Continue; { Not a hi-hat beat. */

    IsDownbeat := (Trunc(Beat.FPosition) = Beat.FPosition);
    BarIndex := Trunc(Beat.FPosition) div Round(Switched.FTimeSignature.BeatsPerBar);

    if Pos('hihat_open', InstName) = 1 then
    begin
      { Open HH → crash/choke accent (not a timekeeper). */
      PromotedCrash := GetOpenHhCrashVariant(APattern, Beat.FPosition, BarIndex);
      Beat.FInstrument := PromotedCrash;
      Beat.FVelocity := Min(Max(Beat.FVelocity, 0), 127);
    end
    else if IsDownbeat and (BarIndex >= 4) and ((BarIndex - 4) mod 4 = 0) then
    begin
      { Every 4th bar from bar 5 → bell accent for timbral variety. */
      Beat.FInstrument := TInstrumentRegistry.Get('ride_1_bell');
      Beat.FVelocity := Min(Max(Beat.FVelocity, 0), 127);
    end
    else if IsDownbeat then
    begin
      { Downbeat → main timekeeper (ride, china, or crash per genre). */
      Beat.FInstrument := Timekeeper;
      Beat.FVelocity := Min(Max(Beat.FVelocity, 0), 127);
    end
    else
    begin
      { Offbeat → ride shaft / lighter variant. */
      Beat.FInstrument := TInstrumentRegistry.Get('ride_1_shaft_hit_stronger');
      Beat.FVelocity := Min(Max(Beat.FVelocity, 0), 127);
    end;

    Beat.FInstrumentPromoted := true;
  end;

  { Add hi-hat pedal ("chick") on every other beat. */
  var BeatsPerBar: Integer := Round(Switched.FTimeSignature.BeatsPerBar);
  var DurationBars := Switched.DurationBars;
  for var Bar := 0 to Trunc(DurationBars) do
  begin
    var BarOffset := Bar * BeatsPerBar;
    var BeatNum := 1.0;
    while BeatNum < BeatsPerBar do
    begin
      var Position := BarOffset + BeatNum;
      { Check if already present (simplified). */
      Switched.AddBeat(Position, TInstrumentRegistry.Get('hihat_pedal_closed'), 80);
      BeatNum := BeatNum + 2.0;
    end;
  end;

  Result := Switched;
end;

function TGenrePlugin.GetSectionVariations(const Section: string): TObjectList<TPattern>;
{ Default returns empty — override in subclass for section variations. */
begin
  Result := TObjectList<TPattern>.Create(true);
end;

function TGenrePlugin.GetSectionFlavors(const Section: string; const Parameters: TGenerationParameters): TObjectList<TPattern>;
{ Get alternative pattern flavors for a section. Default returns only the standard pattern. */
var
  StandardPattern: TPattern;
begin
  Result := TObjectList<TPattern>.Create(true);

  { Default: return only the standard pattern (no flavor variety). */
  try
    StandardPattern := GeneratePattern(Section, Parameters);
    Result.Add(StandardPattern);
  except
    on E: Exception do
      ; { Ignore errors in flavor generation. */
  end;
end;

function TGenrePlugin.SupportsStyle(const Style: string): boolean;
{ Check if this plugin supports the given style (must be overridden). */
begin
  Result := False; { Abstract — must be overridden. */
end;

function TGenrePlugin.ValidateParameters(const Parameters: TGenerationParameters): boolean;
{ Validate that parameters are appropriate for this genre (checks genre and style). */
begin
  if Parameters.FGenre <> GenreName then
    Exit(False);

  Result := SupportsStyle(Parameters.Style);
end;

end.
