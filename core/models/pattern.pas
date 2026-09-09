unit pattern;

{$mode objfpc}{$H+}

{ Pattern data models - Beat and Pattern. }

interface

uses
  Classes, SysUtils, Generics.Collections, kit, time_signature;

type

{ ── Beat ─────────────────────────────────────────────────────────────────── }

{ Individual drum hit within a pattern.
  instrument_promoted is provenance, not a playing instruction: it is True only when this beat's instrument was changed in place by GenrePlugin._apply_ride_hihat_logic promoting an existing hi-hat beat to a higher-energy cymbal for a high-energy section. }
TBeat = class(TObject)
private
  FPosition: float;
  FInstrument: TDrumInstrument;
  FVelocity: Integer;
  FDuration: float;
  FGhostNote: boolean;
  FAccent: boolean;
  FInstrumentPromoted: boolean;
public
  constructor Create(APosition: float; AInstrument: TDrumInstrument; AVelocity: Integer = 100);
  destructor Destroy; override;

  property Position: float read FPosition write FPosition;
  property Instrument: TDrumInstrument read FInstrument write FInstrument;
  property Velocity: Integer read FVelocity write FVelocity;
  property Duration: float read FDuration write FDuration;
  property GhostNote: boolean read FGhostNote write FGhostNote;
  property Accent: boolean read FAccent write FAccent;
  property InstrumentPromoted: boolean read FInstrumentPromoted write FInstrumentPromoted;

  procedure Validate;
end;

{ ── Pattern ───────────────────────────────────────────────────────────────── }

{ Complete drum pattern with timing and metadata. }
TPattern = class(TObject)
private
  FName: string;
  FBeats: TObjectList<TBeat>;
  FTimeSignature: TTimeSignature;
  FSubdivision: Integer;
  FSwingRatio: float;
  FMetadata: TDictionary<string, string>;
public
  constructor Create(const AName: string); overload;
  destructor Destroy; override;

  property Name: string read FName write FName;
  property Beats: TObjectList<TBeat> read FBeats;
  property TimeSignature: TTimeSignature read FTimeSignature write FTimeSignature;
  property Subdivision: Integer read FSubdivision write FSubdivision;
  property SwingRatio: float read FSwingRatio write FSwingRatio;
  property Metadata: TDictionary<string, string> read FMetadata;

  function AddBeat(APosition: float; AInstrument: TDrumInstrument; AVelocity: Integer = 100): TPattern; overload;
  function GetBeatsAtPosition(APosition: float; ATolerance: float = 0.01): TObjectList<TBeat>;
  function GetBeatsByInstrument(AInstrument: TDrumInstrument): TObjectList<TBeat>;
  function DurationBars: float;
  function Humanize(ATimingVariance: float = 0.02; AVelocityVariance: Integer = 10): TPattern;
  function Copy: TPattern;
end;

implementation

{ ── Beat ─────────────────────────────────────────────────────────────────── }

constructor TBeat.Create(APosition: float; AInstrument: TDrumInstrument; AVelocity: Integer = 100);
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

{ ── Pattern ───────────────────────────────────────────────────────────────── }

constructor TPattern.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FBeats := TObjectList<TBeat>.Create(true); { auto-destroy items }
  FTimeSignature := TTimeSignature.Create(4, 4);
  FSubdivision := 16;
  FSwingRatio := 0.0;
  FMetadata := TDictionary<string, string>.Create;
end;

destructor TPattern.Destroy;
begin
  FBeats.Free;
  FMetadata.Free;
  inherited Destroy;
end;

function TPattern.AddBeat(APosition: float; AInstrument: TDrumInstrument; AVelocity: Integer = 100): TPattern;
var
  Beat: TBeat;
begin
  Beat := TBeat.Create(APosition, AInstrument, AVelocity);
  FBeats.Add(Beat);
  Result := Self;
end;

function TPattern.GetBeatsAtPosition(APosition: float; ATolerance: float = 0.01): TObjectList<TBeat>;
var
  Beat: TBeat;
begin
  Result := TObjectList<TBeat>.Create(true);
  for Beat in FBeats do
  begin
    if Abs(Beat.FPosition - APosition) <= ATolerance then
      Result.Add(Beat);
  end;
end;

function TPattern.GetBeatsByInstrument(AInstrument: TDrumInstrument): TObjectList<TBeat>;
var
  Beat: TBeat;
begin
  Result := TObjectList<TBeat>.Create(true);
  for Beat in FBeats do
  begin
    if Beat.FInstrument.Equals(AInstrument) then
      Result.Add(Beat);
  end;
end;

function TPattern.DurationBars: float;
var
  MaxPos: float;
  Beat: TBeat;
begin
  if FBeats.Count = 0 then
    Exit(1.0);

  MaxPos := FBeats[0].FPosition;
  for Beat in FBeats do
  begin
    if Beat.FPosition > MaxPos then
      MaxPos := Beat.FPosition;
  end;

  Result := Max(1.0, (MaxPos + 1.0) / FTimeSignature.BeatsPerBar);
end;

function TPattern.Humanize(ATimingVariance: float = 0.02; AVelocityVariance: Integer = 10): TPattern;
var
  Beat: TBeat;
  HumanizedBeats: TObjectList<TBeat>;
begin
  HumanizedBeats := TObjectList<TBeat>.Create(true);

  for Beat in FBeats do
  begin
    { Add slight timing variations }
    var TimingOffset := Random * (ATimingVariance - (-ATimingVariance)) + (-ATimingVariance);
    var NewPosition := Max(0, Beat.FPosition + TimingOffset);

    { Add velocity variations }
    var VelocityOffset := Random(AVelocityVariance * 2 + 1) - AVelocityVariance;
    var NewVelocity := Max(1, Min(127, Beat.FVelocity + VelocityOffset));

    var HumanizedBeat := TBeat.Create(NewPosition, Beat.FInstrument, NewVelocity);
    HumanizedBeat.FDuration := Beat.FDuration;
    HumanizedBeat.FGhostNote := Beat.FGhostNote;
    HumanizedBeat.FAccent := Beat.FAccent;
    HumanizedBeat.FInstrumentPromoted := Beat.FInstrumentPromoted;
    HumanizedBeats.Add(HumanizedBeat);
  end;

  Result := TPattern.Create(FName + '_humanized');
  Result.FTimeSignature := FTimeSignature;
  Result.FSubdivision := FSubdivision;
  Result.FSwingRatio := FSwingRatio;

  var Meta: TPair<string, string>;
  for Meta in FMetadata do
    Result.FMetadata.Add(Meta.Key, Meta.Value);
  Result.FMetadata.Add('humanized', 'true');

  Result.FBeats.Assign(HumanizedBeats);
  HumanizedBeats.Free;
end;

function TPattern.Copy: TPattern;
begin
  { Log warning if pattern has no beats - aids debugging }
  if FBeats.Count = 0 then
    WriteLn('[WARNING] Pattern ' + FName + ' has no beats - copying empty pattern.');

  Result := TPattern.Create(FName);
  var Beat: TBeat;
  for Beat in FBeats do
  begin
    var NewBeat := TBeat.Create(Beat.FPosition, Beat.FInstrument, Beat.FVelocity);
    NewBeat.FDuration := Beat.FDuration;
    NewBeat.FGhostNote := Beat.FGhostNote;
    NewBeat.FAccent := Beat.FAccent;
    NewBeat.FInstrumentPromoted := Beat.FInstrumentPromoted;
    Result.FBeats.Add(NewBeat);
  end;

  Result.FTimeSignature := TTimeSignature.Create(FTimeSignature.Numerator, FTimeSignature.Denominator);
  Result.FSubdivision := FSubdivision;
  Result.FSwingRatio := FSwingRatio;

  var Meta: TPair<string, string>;
  for Meta in FMetadata do
    Result.FMetadata.Add(Meta.Key, Meta.Value);
end;

end.
