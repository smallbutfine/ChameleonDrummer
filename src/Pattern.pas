unit Pattern;

{$mode objfpc}{$H+}

{ Pattern data models - Beat and Pattern. }

interface

uses
  Classes, SysUtils, Generics.Collections, kit, time_signature, Math;

type

{ â”€â”€ Beat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ Individual drum hit within a pattern.
  instrument_promoted is provenance, not a playing instruction: it is True only when this beat's instrument was changed in place by GenrePlugin._apply_ride_hihat_logic promoting an existing hi-hat beat to a higher-energy cymbal for a high-energy section. }
TBeat = class(TObject)
private
  FPosition: Double;
  FInstrument: TDrumInstrument;
  FVelocity: Integer;
  FDuration: Double;
  FGhostNote: boolean;
  FAccent: boolean;
  FInstrumentPromoted: boolean;
public
  constructor Create(APosition: Double; AInstrument: TDrumInstrument; AVelocity: Integer = 100);
  destructor Destroy; override;

  property Position: Double read FPosition write FPosition;
  property Instrument: TDrumInstrument read FInstrument write FInstrument;
  property Velocity: Integer read FVelocity write FVelocity;
  property Duration: Double read FDuration write FDuration;
  property GhostNote: boolean read FGhostNote write FGhostNote;
  property Accent: boolean read FAccent write FAccent;
  property InstrumentPromoted: boolean read FInstrumentPromoted write FInstrumentPromoted;

  procedure Validate;
end;

{ â”€â”€ Pattern â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ Complete drum pattern with timing and metadata. }
TPattern = class(TObject)
private
  FName: string;
  FBeats: specialize TList<TBeat>;
  FTimeSignature: TTimeSignature;
  FSubdivision: Integer;
  FSwingRatio: Double;
  FMetadata: specialize TDictionary<string, string>;
public
  constructor Create(const AName: string); overload;
  destructor Destroy; override;

  property Name: string read FName write FName;
  property Beats: specialize TList<TBeat> read FBeats;
  property TimeSignature: TTimeSignature read FTimeSignature write FTimeSignature;
  property Subdivision: Integer read FSubdivision write FSubdivision;
  property SwingRatio: Double read FSwingRatio write FSwingRatio;
  property Metadata: specialize TDictionary<string, string> read FMetadata;

  function AddBeat(APosition: Double; AInstrument: TDrumInstrument; AVelocity: Integer = 100): TPattern; overload;
  function GetBeatsAtPosition(APosition: Double; ATolerance: Double = 0.01): specialize TList<TBeat>;
  function GetBeatsByInstrument(AInstrument: TDrumInstrument): specialize TList<TBeat>;
  function DurationBars: Double;
  function Humanize(ATimingVariance: Double = 0.02; AVelocityVariance: Integer = 10): TPattern;
  function Copy: TPattern;

  { Swing as a grid distortion (not a timing offset): inside every beat the
    offbeat eighth moves from 0.5 to 0.5 + 0.25 * AAmount of the beat, and the
    sixteenths around it move with it. AAmount 0 is straight, about 0.67 is
    the classic 2:1 triplet swing, 1.0 is a 3:1 dotted feel. SwingRatio
    records the amount that was applied.
    Nothing is changed (False is returned) when the amount is 0, when the
    pattern was swung before, when the meter is not x/4, or when the pattern
    already sits on a triplet grid (shuffles, jazz ride patterns). }
  function ApplySwing(AAmount: Double): Boolean;



  { Checks the pattern against its declared length and appends one readable
    line per problem to AWarnings (it can be nil). Nothing is raised and the
    pattern is not changed: a pattern cut out of a larger one may well have
    a beat near its edge, and the caller decides what to do with the lines.
    Returns the number of problems found.
    Checked: beats at or after the end of the declared length (phrase_bars
    bars of the pattern's meter) - the exporter would play them in a bar the
    pattern was never meant to have - and beats without an instrument. }
  function Validate(AWarnings: TStrings = nil): Integer;
end;

{ Reads the valid_intensity_min/max metadata tags of a pattern. Parsing is
  locale independent ('0.25' works under a German locale too). AMin/AMax are
  0.0/1.0 when a tag is missing or malformed; the result is True only when
  both tags were present and valid. }
function TryGetIntensityRange(APattern: TPattern; out AMin, AMax: Double): Boolean;

implementation

type
  TBeatList = specialize TList<TBeat>;

function TryGetIntensityRange(APattern: TPattern; out AMin, AMax: Double): Boolean;
var
  Fmt: TFormatSettings;
  S: string;
  HasMin, HasMax: Boolean;
begin
  AMin := 0.0;
  AMax := 1.0;
  Result := False;
  if APattern = nil then
    Exit;
  Fmt := DefaultFormatSettings;
  Fmt.DecimalSeparator := '.';
  S := '';
  HasMin := APattern.Metadata.TryGetValue('valid_intensity_min', S) and
    TryStrToFloat(Trim(S), AMin, Fmt);
  if not HasMin then
    AMin := 0.0;
  S := '';
  HasMax := APattern.Metadata.TryGetValue('valid_intensity_max', S) and
    TryStrToFloat(Trim(S), AMax, Fmt);
  if not HasMax then
    AMax := 1.0;
  Result := HasMin and HasMax;
end;

{ â”€â”€ Beat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TBeat.Create(APosition: Double; AInstrument: TDrumInstrument; AVelocity: Integer = 100);
begin
  inherited Create;
  FPosition := APosition;
  FInstrument := AInstrument;
  FVelocity := AVelocity;
  FDuration := 0.25;
  FGhostNote := false;
  FAccent := false;
  FInstrumentPromoted := false;
  Validate;
end;

destructor TBeat.Destroy;
begin
  inherited Destroy;
end;

procedure TBeat.Validate;
begin
  if (FVelocity < 0) or (FVelocity > 127) then
    raise Exception.CreateFmt('Velocity must be 0-127, got %d', [FVelocity]);
  if FPosition < 0 then
    raise Exception.CreateFmt('Position cannot be negative, got %f', [FPosition]);
end;

{ â”€â”€ Pattern â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TPattern.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FBeats := specialize TList<TBeat>.Create;
  FTimeSignature := TTimeSignature.Create(4, 4);
  FSubdivision := 16;
  FSwingRatio := 0.0;
  FMetadata := specialize TDictionary<string, string>.Create;
end;

destructor TPattern.Destroy;
var
  Beat: TBeat;
begin
  for Beat in FBeats do
    Beat.Free;
  FBeats.Free;
  FTimeSignature.Free;
  FMetadata.Free;
  inherited Destroy;
end;

function TPattern.AddBeat(APosition: Double; AInstrument: TDrumInstrument; AVelocity: Integer = 100): TPattern;
var
  Beat: TBeat;
begin
  Beat := TBeat.Create(APosition, AInstrument, AVelocity);
  FBeats.Add(Beat);
  Result := Self;
end;

function TPattern.GetBeatsAtPosition(APosition: Double; ATolerance: Double = 0.01): specialize TList<TBeat>;
var
  Beat: TBeat;
begin
  Result := specialize TList<TBeat>.Create;
  for Beat in FBeats do
  begin
    if Abs(Beat.FPosition - APosition) <= ATolerance then
      Result.Add(Beat);
  end;
end;

function TPattern.GetBeatsByInstrument(AInstrument: TDrumInstrument): specialize TList<TBeat>;
var
  Beat: TBeat;
begin
  Result := specialize TList<TBeat>.Create;
  for Beat in FBeats do
  begin
    if Beat.FInstrument.Equals(AInstrument) then
      Result.Add(Beat);
  end;
end;

function TPattern.DurationBars: Double;
var
  MaxPos: Double;
  Beat: TBeat;
  ExplicitBars: string;
  BarCount: Integer;
begin
  if FMetadata.TryGetValue('phrase_bars', ExplicitBars) and
     TryStrToInt(ExplicitBars, BarCount) and (BarCount > 0) then
    Exit(BarCount);

  if FBeats.Count = 0 then
    Exit(1.0);

  MaxPos := FBeats[0].FPosition;
  for Beat in FBeats do
  begin
    if Beat.FPosition > MaxPos then
      MaxPos := Beat.FPosition;
  end;

  Result := Trunc(MaxPos / FTimeSignature.BeatsPerBar) + 1;
end;

function TPattern.Validate(AWarnings: TStrings = nil): Integer;
var
  Beat: TBeat;

  Declared: string;
  Bars: Integer;
  LengthQuarters, FirstLate: Double;

  LateCount, NoInstrument: Integer;



  procedure Report(const AText: string);

  begin

    Inc(Result);
    if AWarnings <> nil then
      AWarnings.Add(Format('pattern "%s": %s', [FName, AText]));
  end;


begin
  Result := 0;
  LateCount := 0;
  NoInstrument := 0;

  FirstLate := 0.0;


  { Without phrase_bars the length is taken from the last beat, so no beat can
    lie beyond it. }

  if FMetadata.TryGetValue('phrase_bars', Declared) and

     TryStrToInt(Declared, Bars) and (Bars > 0) then
  begin
    LengthQuarters := Bars * FTimeSignature.BeatsPerBar;

    for Beat in FBeats do
      if Beat.Position >= LengthQuarters then
      begin
        if LateCount = 0 then

          FirstLate := Beat.Position;
        Inc(LateCount);

      end;

    if LateCount > 0 then

      Report(Format('%d beat(s) lie beyond its %d bar(s) (%.2f quarter notes); the first is at %.3f',
        [LateCount, Bars, LengthQuarters, FirstLate]));
  end;

  for Beat in FBeats do
    if Beat.Instrument = nil then
      Inc(NoInstrument);
  if NoInstrument > 0 then

    Report(Format('%d beat(s) have no instrument and are never played', [NoInstrument]));

end;


function TPattern.Humanize(ATimingVariance: Double = 0.02; AVelocityVariance: Integer = 10): TPattern;

var
  Beat: TBeat;
  HumanizedBeats: TBeatList;
  TimingOffset, NewPosition, VelocityOffset: Double;
  iNewVelocity: Integer;
  HumanizedBeat: TBeat;
  Meta: specialize TPair<string, string>;
  B: TBeat;
begin
  HumanizedBeats := specialize TList<TBeat>.Create;

  for Beat in FBeats do
  begin
    { Add slight timing variations }
    TimingOffset := Random * (ATimingVariance - (-ATimingVariance)) + (-ATimingVariance);
    NewPosition := Math.Max(0.0, Beat.FPosition + TimingOffset);

    { Add velocity variations }
    VelocityOffset := Random(AVelocityVariance * 2 + 1) - AVelocityVariance;
    iNewVelocity := Math.Max(1, Math.Min(127, Beat.FVelocity + Round(VelocityOffset)));

    HumanizedBeat := TBeat.Create(NewPosition, Beat.FInstrument, iNewVelocity);
    HumanizedBeat.FDuration := Beat.FDuration;
    HumanizedBeat.FGhostNote := Beat.FGhostNote;
    HumanizedBeat.FAccent := Beat.FAccent;
    HumanizedBeat.FInstrumentPromoted := Beat.FInstrumentPromoted;
    HumanizedBeats.Add(HumanizedBeat);
  end;

  Result := TPattern.Create(FName + '_humanized');
  Result.FTimeSignature.Free;
  Result.FTimeSignature := TTimeSignature.Create(FTimeSignature.Numerator, FTimeSignature.Denominator);
  Result.FSubdivision := FSubdivision;
  Result.FSwingRatio := FSwingRatio;

  for Meta in FMetadata do
    Result.FMetadata.Add(Meta.Key, Meta.Value);
  Result.FMetadata.Add('humanized', 'true');

  for B in HumanizedBeats do
    Result.FBeats.Add(B);
  HumanizedBeats.Free;
end;

function TPattern.ApplySwing(AAmount: Double): Boolean;
var
  Beat: TBeat;
  Whole, Frac, OffbeatPos: Double;
begin
  Result := False;
  AAmount := Math.Min(1.0, AAmount);
  if AAmount <= 0.0001 then
    Exit;
  if FSwingRatio > 0 then
    Exit;
  if FTimeSignature.Denominator <> 4 then
    Exit;

  { A pattern with notes on the triplet grid is already swung or shuffled. }
  for Beat in FBeats do
  begin
    Frac := Beat.Position - Math.Floor(Beat.Position);
    if (Abs(Frac - 1.0 / 3.0) < 0.02) or (Abs(Frac - 2.0 / 3.0) < 0.02) then
      Exit;
  end;

  OffbeatPos := 0.5 + 0.25 * AAmount;
  for Beat in FBeats do
  begin
    Whole := Math.Floor(Beat.Position);
    Frac := Beat.Position - Whole;
    if Frac < 0.5 then
      Frac := Frac * 2.0 * OffbeatPos
    else
      Frac := OffbeatPos + (Frac - 0.5) * 2.0 * (1.0 - OffbeatPos);
    Beat.Position := Whole + Frac;
  end;
  FSwingRatio := AAmount;
  Result := True;
end;

function TPattern.Copy: TPattern;
var
  Beat, NewBeat: TBeat;
  Meta: specialize TPair<string, string>;
begin
  { Log warning if pattern has no beats - aids debugging }
  if FBeats.Count = 0 then
    WriteLn(StdErr, '[WARNING] Pattern ' + FName + ' has no beats - copying empty pattern.');

  Result := TPattern.Create(FName);
  for Beat in FBeats do
  begin
    NewBeat := TBeat.Create(Beat.FPosition, Beat.FInstrument, Beat.FVelocity);
    NewBeat.FDuration := Beat.FDuration;
    NewBeat.FGhostNote := Beat.FGhostNote;
    NewBeat.FAccent := Beat.FAccent;
    NewBeat.FInstrumentPromoted := Beat.FInstrumentPromoted;
    Result.FBeats.Add(NewBeat);
  end;

  Result.FTimeSignature.Free;
  Result.FTimeSignature := TTimeSignature.Create(FTimeSignature.Numerator, FTimeSignature.Denominator);
  Result.FSubdivision := FSubdivision;
  Result.FSwingRatio := FSwingRatio;

  for Meta in FMetadata do
    Result.FMetadata.Add(Meta.Key, Meta.Value);
end;

end.
