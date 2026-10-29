unit patterns_templates;

{$mode objfpc}{$H+}

{ Stub pattern templates unit. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song, time_signature,
  TabFiles;

type
  { Lines of a drum tab (see TDrumTab). }
  TTabLines = array of string;

  { Stub TPatternBuilder � full implementation in .pas file below }
  TPatternBuilder = class(TObject)
  private
    FPName: string;
    FBeats: specialize TList<TBeat>;
    FPositionOffset: Double;
    procedure AddDrumHit(const AInstrumentName: string; AtPos: Double;
      AVelocity: Integer; AGhost: Boolean = False; AAccent: Boolean = False);
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function Hit(const AInstrumentName: string; AtPos: Double; AVel: Integer;
      AGhost, AAccent: Boolean): TPatternBuilder; virtual;
    function Kick(AtPos: Double; AVel: Integer): TPatternBuilder; virtual;
    function Snare(AtPos: Double; AVel: Integer): TPatternBuilder; virtual;
    function Crash(AtPos: Double; AVel: Integer): TPatternBuilder; virtual;
    function HiHat(AtPos: Double; AVel: Integer): TPatternBuilder; virtual;
    function Tom(AtPos: Double; ATomNum: string): TPatternBuilder; virtual;
    function Build: TPattern; virtual;
    property PositionOffset: Double read FPositionOffset write FPositionOffset;
  end;

  TPatternTemplate = class(TObject)
  public
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; virtual; abstract;
  end;

  { Stub template types - concrete implementations moved to metal/rock etc. }
  TBasicGroove = class(TPatternTemplate)
  public
    KickPositions: specialize TList<Double>;
    SnarePositions: specialize TList<Double>;
    HiHatSubdivision: Double;
    UseOpenHiHat: boolean;
    OpenHiHatPositions: specialize TList<Double>;
    Intensity: Double;
    constructor Create; overload;
    constructor Create(AKickPos, ASnarePos: specialize TList<Double>; AHiHatSub: Double); virtual;
    destructor Destroy; override;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TDoubleBassPedal = class(TPatternTemplate)
  public
    { Note denominator: 8 = eighth notes, 16 = sixteenth notes, etc. }
    Subdivision: Double;
    Intensity: Double;
    PatternType: string;
    constructor Create(APatternType: string; ASubdiv: Double; AIntensity: Double = 0.7); virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TBlastBeat = class(TPatternTemplate)
  public
    Style: string;
    Intensity: Double;
    constructor Create(AStyle: string; AIntensity: Double); virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TCrashAccents = class(TPatternTemplate)
  public
    constructor Create; virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TTomFill = class(TPatternTemplate)
  public
    FillType: string;
    constructor Create(AFillType: string); virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TSteadyRide = class(TPatternTemplate)
  public
    Intensity: Double;
    constructor Create; virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TJazzRidePattern = class(TPatternTemplate)
  public
    PatternStyle: string;
    Intensity: Double;
    constructor Create(APatternStyle: string); virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TFunkGhostNotes = class(TPatternTemplate)
  public
    Style: string;
    Intensity: Double;
    constructor Create(AStyle: string); virtual;
    constructor CreateDefault; overload;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  { A groove written as a drum tab. Each line is
        <instrument>[@<min complexity>] <bar 1>|<bar 2>|...
    A bar is a row of steps; its length sets the grid (16 = sixteenths,
    12 = triplet eighths, 8 = eighths, 32 = thirty-seconds). Spaces inside a
    bar are ignored, so steps can be grouped by beat. Step characters:
        .  rest        x  normal hit     X  accent
        o  soft hit    g  ghost note
    Instruments: K kick, S snare, RS rimshot, SS side stick, H closed hat,
    HO open hat, HP pedal hat, R ride, RB ride bell, C crash, C2 crash 2,
    CH china-style cymbal, SP splash, T1..T4 toms.
    A line with @0.6 only plays when the song complexity is at least 0.6.
    A line with fewer bars than the tab repeats its bars.

    In a meter other than 4/4 the steps still divide the whole bar: a bar of
    N/D has N units (1/D notes), and k steps per unit, k = 1, 2, 3, 4, 6 or 8.
    7/8 therefore takes 7 (eighths), 14 (sixteenths), 21, 28, 42 or 56 steps;
    4/4 takes 4, 8, 12, 16, 24 or 32. }
TDrumTab = class(TPatternTemplate)
  private
    FLines: TStringList;
    FBarCount: Integer;
    FMeters: array of TabFiles.TMeterPair;  { header meters, empty = infer from tab }
  public
    constructor Create(const ALines: array of string);
    destructor Destroy; override;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
    property BarCount: Integer read FBarCount;
    { Set header meters. Empty = infer meter per bar from tab structure. }
    procedure SetMeters(const AMeters: array of TabFiles.TMeterPair);
  end;

  TTemplateComposer = class(TObject)
  private
    FPName: string;
    FTemplates: specialize TList<TPatternTemplate>;
    FMeterNum, FMeterDen: Integer;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function Add(APattern: TPatternTemplate): TTemplateComposer;
    { The meter of the bars that are built (4/4 unless set). }
    procedure SetMeter(ANum, ADen: Integer);
    function Build(ABars: Integer; AComplexity: Double): TPattern;
  end;

function OverlayDoubleBassPedal(const APattern: TPattern;
  const APatternType: string; ASubdivision: Integer;
  AIntensity: Double = 0.7): TPattern;

{ Section kind used to pick a groove set: 'verse', 'chorus' or 'bridge'.
  intro/outro/unknown sections play the verse grooves. }
function GrooveKindOfSection(const ASection: string): string;

{ Intensity band of groove variant AVariant (0 = lightest) for a section kind.
  The bands overlap on purpose, so neighbouring intensities share a groove
  and the selector can still rotate between them. }
procedure GrooveBand(const AKind: string; AVariant: Integer; out AMin, AMax: Double);

{ Writes valid_intensity_min/max metadata (locale independent). }
procedure TagIntensityBand(APattern: TPattern; AMin, AMax: Double);

{ Builds a groove from drum-tab lines and tags its intensity band. }
function BuildTaggedGroove(const AName, AKind: string; AVariant: Integer;
  const ALines: array of string; AComplexity: Double;
  AMeterNum: Integer = 4; AMeterDen: Integer = 4): TPattern;

{ Builds a pattern from drum-tab lines (see TDrumTab), in the given meter. }
function BuildDrumTabPattern(const AName: string; const ALines: array of string;
  AComplexity: Double; AMinBars: Integer = 2;
  const AMeters: array of TabFiles.TMeterPair): TPattern;

{ A plain groove for a meter that has no groove in the files: kick on the
  downbeat, snare at the start of every later beat group, hi-hat on every
  unit. AVariant 0..2 grows it from sparse to busy. The point is to keep the
  song playing until a groove for the meter is added to config\grooves. }
function BuildMeterFallbackGroove(const AName: string; AMeterNum, AMeterDen: Integer;
  AComplexity: Double): TPattern;

{ A short fill for a meter that has no fill in the files: a tom run down the
  last units of the bar. }
function BuildMeterFallbackFill(const AName: string; AMeterNum, AMeterDen: Integer;
  AFullBar: Boolean): TPattern;

{ The step counts a bar of the meter may have, e.g. '7, 14, 21, 28, 42 or 56'. }
function TabStepCountsText(AMeterNum: Integer): string;

{ Infers a time signature from a bar's step count. Returns True when a valid
  meter was found. Prefers 4/4, then common subdivisions (eighths, sixteenths,
  quarters), then smaller numerators. }
function InferMeterFromSteps(ASteps: Integer; out AMeterNum, AMeterDen: Integer): Boolean;

{ Infers meter from the first line's first bar step count. Raises on failure. }
procedure InferMeterFromTab(const ALines: TStringList; out AMeterNum, AMeterDen: Integer);

implementation

{ The complexity the composer was built with, 0..1. This is the density
  control: a simple groove stays sparse, a complex one gets busier. }
function TemplateComplexity(const Kwargs: specialize TDictionary<string, string>): Double;
var
  S: string;
begin
  Result := 0.5;
  if not Assigned(Kwargs) then
    Exit;
  S := Kwargs.Items['complexity'];
  if (S = '') or not TryStrToFloat(S, Result) then
    Result := 0.5;
  Result := EnsureRange(Result, 0.0, 1.0);
end;

constructor TPatternBuilder.Create(const AName: string);
begin
  inherited Create;
  FPName := AName;
  FBeats := specialize TList<TBeat>.Create;
end;

destructor TPatternBuilder.Destroy;
var
  Beat: TBeat;
begin
  for Beat in FBeats do
    Beat.Free;
  FBeats.Free;
  inherited Destroy;
end;

procedure TPatternBuilder.AddDrumHit(const AInstrumentName: string;
  AtPos: Double; AVelocity: Integer; AGhost: Boolean; AAccent: Boolean);
var
  Instrument: TDrumInstrument;
  Beat: TBeat;
begin
  Instrument := TInstrumentRegistry.Get(AInstrumentName);
  if not Assigned(Instrument) then
    Exit;
  for Beat in FBeats do
    if Assigned(Beat.Instrument) and
       SameText(Beat.Instrument.Name, Instrument.Name) and
       (Abs(Beat.Position - (AtPos + FPositionOffset)) < 0.000001) then
    begin
      if AVelocity > Beat.Velocity then
      begin
        Beat.Velocity := AVelocity;
        Beat.GhostNote := AGhost;
      end;
      Beat.Accent := Beat.Accent or AAccent;
      Exit;
    end;
  Beat := TBeat.Create(AtPos + FPositionOffset, Instrument, AVelocity);
  Beat.GhostNote := AGhost;
  Beat.Accent := AAccent;
  FBeats.Add(Beat);
end;

function TPatternBuilder.Hit(const AInstrumentName: string; AtPos: Double;
  AVel: Integer; AGhost, AAccent: Boolean): TPatternBuilder;
begin
  Result := Self;
  AddDrumHit(AInstrumentName, AtPos, AVel, AGhost, AAccent);
end;

function TPatternBuilder.Kick(AtPos: Double; AVel: Integer): TPatternBuilder;
begin
  Result := Self;
  AddDrumHit('kick', AtPos, AVel);
end;

function TPatternBuilder.Snare(AtPos: Double; AVel: Integer): TPatternBuilder;
begin
  Result := Self;
  AddDrumHit('snare_open_hit_open_lateral_hit', AtPos, AVel);
end;

function TPatternBuilder.Crash(AtPos: Double; AVel: Integer): TPatternBuilder;
begin
  Result := Self;
  AddDrumHit('cymbal_1_hit', AtPos, AVel);
end;

function TPatternBuilder.HiHat(AtPos: Double; AVel: Integer): TPatternBuilder;
begin
  Result := Self;
  AddDrumHit('hihat_closed_1_tip_closed_1_hit', AtPos, AVel);
end;

function TPatternBuilder.Tom(AtPos: Double; ATomNum: string): TPatternBuilder;
begin
  Result := Self;
  AddDrumHit('tom_' + ATomNum + '_open_hit', AtPos, 100);
end;

function TPatternBuilder.Build: TPattern;
var LPattern: TPattern;
    I, Count: Integer;
    Item: TBeat;
begin
  LPattern := TPattern.Create(FPName);
  Count := FBeats.Count;
  for I := 0 to Count - 1 do
  begin
    Item := FBeats[I];
    LPattern.AddBeat(Item.Position, Item.Instrument, Item.Velocity);
    LPattern.Beats[LPattern.Beats.Count - 1].GhostNote := Item.GhostNote;
    LPattern.Beats[LPattern.Beats.Count - 1].Accent := Item.Accent;
  end;
  Result := LPattern;
end;

constructor TBasicGroove.Create(AKickPos, ASnarePos: specialize TList<Double>; AHiHatSub: Double);
var I: Integer;
begin
  inherited Create;
  if Assigned(AKickPos) then KickPositions := AKickPos else
  begin
    KickPositions := specialize TList<Double>.Create;
    KickPositions.Add(0.0);   // beat 1 downbeat
    KickPositions.Add(2.0);   // beat 3
  end;
  if Assigned(ASnarePos) then SnarePositions := ASnarePos else
  begin
    SnarePositions := specialize TList<Double>.Create;
    SnarePositions.Add(1.0);  // beat 2 backbeat
    SnarePositions.Add(3.0);  // beat 4 backbeat
  end;
  HiHatSubdivision := AHiHatSub;
  Intensity := 0.7;
end;

constructor TBasicGroove.Create;
begin inherited Create; KickPositions := specialize TList<Double>.Create; SnarePositions := specialize TList<Double>.Create; HiHatSubdivision := 0.5; Intensity := 0.7; end;

destructor TBasicGroove.Destroy;
begin
  if Assigned(KickPositions) then KickPositions.Free;
  if Assigned(SnarePositions) then SnarePositions.Free;
  if Assigned(OpenHiHatPositions) then OpenHiHatPositions.Free;
  inherited Destroy;
end;

function TBasicGroove.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var Pos: Double; Vel: Integer; I: Integer; Complexity: Double; Sub: Double; GhostCount: Integer;
begin
  Complexity := TemplateComplexity(Kwargs);
  for Pos in KickPositions do begin 
    Vel := Trunc(Max(Min(Pos * 50.0 + 80.0, 127.0), 1.0)); 
    Builder.Kick(Pos, Vel); 
  end;
  for Pos in SnarePositions do begin 
    Vel := Trunc(Max(Min(Pos * 50.0 + 90.0, 127.0), 1.0)); 
    Builder.Snare(Pos, Vel); 
  end;
  { Add hi-hat timekeeping. A complex groove doubles the timekeeping grid. }
  Sub := HiHatSubdivision;
  if (Sub > 0) and (Complexity >= 0.6) then
    Sub := Sub / 2;
  if Sub > 0 then
  begin
    I := 0;
    while I * Sub <= 3.5 do
    begin
      Builder.HiHat(I * Sub, Trunc(80 * Min(Intensity + 0.2, 1.0)));
      Inc(I);
    end;
  end;
  { Busy grooves put ghost notes on the backbeat; how many scales with
    complexity, so the whole range above the default is meaningful. }
  GhostCount := Trunc((Complexity - 0.5) * 8);
  if GhostCount > 0 then
  begin
    Builder.Snare(0.5, 38);
    if GhostCount > 1 then Builder.Snare(2.5, 38);
    if GhostCount > 2 then Builder.Snare(1.5, 32);
    if GhostCount > 3 then Builder.Snare(3.5, 32);
  end;
  Result := Builder;
end;

constructor TDoubleBassPedal.Create(APatternType: string; ASubdiv: Double; AIntensity: Double = 0.7);
begin inherited Create; PatternType := APatternType; Subdivision := ASubdiv; Intensity := AIntensity; end;

function TDoubleBassPedal.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var
  I: Integer;
  Pulse: Integer;
  PulseCount: Integer;
  GridStep: Double;
  BarPosition: Double;
begin
  Result := Builder;
  if (Subdivision < 4) or (Subdivision > 32) or
     (Abs(Subdivision - Round(Subdivision)) > 0.000001) or
     ((Round(Subdivision) mod 4) <> 0) then
    raise Exception.CreateFmt(
      'Double-bass subdivision must be 4, 8, 16, or 32, got %s',
      [FloatToStr(Subdivision)]);
  GridStep := 4.0 / Subdivision;

  if SameText(PatternType, 'gallop') then
  begin
    if Subdivision < 16 then
      raise Exception.Create('Gallop double-bass patterns require a 16th-note grid or finer');
    for I := 0 to 3 do
    begin
      BarPosition := I * 1.0;
      Builder.Kick(BarPosition, Trunc(100 * Intensity));
      Builder.Kick(BarPosition + 0.5, Trunc(95 * Intensity));
      Builder.Kick(BarPosition + 0.75, Trunc(100 * Intensity));
    end;
  end
  else if SameText(PatternType, 'burst') then
  begin
    if Subdivision < 16 then
      raise Exception.Create('Burst double-bass patterns require a 16th-note grid or finer');
    PulseCount := Round(1.0 / GridStep);
    for Pulse := 0 to PulseCount - 1 do
      Builder.Kick(Pulse * GridStep, Trunc(110 * Intensity));
  end
  else if SameText(PatternType, 'continuous') then
  begin
    PulseCount := Round(4.0 / GridStep);
    for Pulse := 0 to PulseCount - 1 do
      Builder.Kick(Pulse * GridStep,
        Trunc((105 - (Pulse mod 2) * 7) * Intensity));
  end
  else
    raise Exception.CreateFmt('Unknown double-bass pattern type: %s',
      [PatternType]);
end;

constructor TBlastBeat.Create(AStyle: string; AIntensity: Double);
begin inherited Create; Style := AStyle; Intensity := AIntensity; end;

function TBlastBeat.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var I: Integer;
begin
  Result := Builder;
  // Blast beat: alternating kick and snare at 16th note speed
  for I := 0 to 15 do
    if (I mod 2 = 0) then
      Builder.Kick(I * 0.25, Trunc(105 * Intensity))
    else
      Builder.Snare(I * 0.25, Trunc(110 * Intensity));
end;

constructor TCrashAccents.Create;
begin inherited Create; end;

function TCrashAccents.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin
  Result := Builder;
  Builder.Crash(0.0, 110);
end;

constructor TTomFill.Create(AFillType: string);
begin inherited Create; FillType := AFillType; end;

function TTomFill.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var
  I, BarIndex, BarCount: Integer;
begin
  Result := Builder;
  BarIndex := StrToIntDef(Kwargs.Items['bar'], 0);
  BarCount := StrToIntDef(Kwargs.Items['bars'], 1);
  if BarIndex <> BarCount - 1 then
    Exit;
  for I := 0 to 3 do
    Builder.Tom(I * 0.75, IntToStr(4 - I));
end;

constructor TSteadyRide.Create;
begin inherited Create; end;

function TSteadyRide.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var I: Integer; Complexity: Double;
begin
  Result := Builder;
  Complexity := TemplateComplexity(Kwargs);
  { Steady ride pattern (for jazz/fusion metal bridge). A complex pattern
    doubles the timekeeping to sixteenth notes. }
  if Complexity >= 0.7 then
    for I := 0 to 15 do
      Builder.Hihat(I * 0.25, Trunc(60))
  else
    for I := 0 to 7 do
      Builder.Hihat(I * 0.5, Trunc(70));
end;

constructor TJazzRidePattern.Create(APatternStyle: string);
begin inherited Create; PatternStyle := APatternStyle; end;

function TJazzRidePattern.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var I: Integer; Complexity: Double;
begin
  Result := Builder;
  Complexity := TemplateComplexity(Kwargs);
  { Jazz ride pattern - ride cymbal on quarters. A complex pattern adds
    the eighth-note "ding" on top. }
  for I := 0 to 3 do
    Builder.Hihat(I * 1.0, Trunc(75));
  if Complexity >= 0.7 then
    for I := 0 to 7 do
      Builder.Hihat(I * 0.5, Trunc(58));
end;

constructor TFunkGhostNotes.Create(AStyle: string);
begin inherited Create; Style := AStyle; end;

function TFunkGhostNotes.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var I: Integer; Complexity: Double;
begin
  Result := Builder;
  Complexity := TemplateComplexity(Kwargs);
  { Funk ghost notes on the snare. A complex funk groove doubles them to
    sixteenths. }
  if Complexity >= 0.8 then
  begin
    for I := 0 to 15 do
      Builder.Snare(I * 0.25, Trunc(45));
  end
  else
    for I := 0 to 7 do
      Builder.Snare(I * 0.5, Trunc(50));
end;

constructor TFunkGhostNotes.CreateDefault;
begin inherited Create; Style := 'default'; end;

{ Drum-tab instrument alias -> keymap instrument name ('' when unknown). }
function TabInstrument(const AAlias: string): string;
begin
  case UpperCase(AAlias) of
    'K': Result := 'kick';
    'S': Result := 'snare_open_hit_open_lateral_hit';
    'RS': Result := 'snare_rimshot_open_hit';
    'SS': Result := 'snare_side_stick';
    'H': Result := 'hihat_closed_1_tip_closed_1_hit';
    'HO': Result := 'hihat_open_a';
    'HP': Result := 'hihat_pedal_closed';
    'R': Result := 'ride_1_tip_hit_softer';
    'RB': Result := 'ride_1_bell';
    'C': Result := 'cymbal_1_hit';
    'C2': Result := 'cymbal_2_hit';
    'CH': Result := 'cymbal_4_hit';
    'SP': Result := 'cymbal_6_hit';
    'T1': Result := 'tom_1_open_hit';
    'T2': Result := 'tom_2_open_hit';
    'T3': Result := 'tom_3_open_hit';
    'T4': Result := 'tom_4_open_hit';
  else
    Result := '';
  end;
end;

function CountBars(const ABody: string): Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 1 to Length(ABody) do
    if ABody[I] = '|' then
      Inc(Result);
end;

constructor TDrumTab.Create(const ALines: array of string);
var
  I, P: Integer;
  Line: string;
begin
  inherited Create;
  FLines := TStringList.Create;
  FBarCount := 1;
  for I := 0 to High(ALines) do
  begin
    Line := Trim(ALines[I]);
    if Line = '' then
      Continue;
    P := Pos(' ', Line);
    if P < 2 then
      raise Exception.CreateFmt('Drum tab line has no steps: "%s"', [Line]);
    FLines.Add(Line);
    FBarCount := Max(FBarCount, CountBars(Copy(Line, P + 1, MaxInt)));
  end;
end;

destructor TDrumTab.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

procedure TDrumTab.SetMeters(const AMeters: array of TMeterPair);
var
  I: Integer;
begin
  SetLength(FMeters, Length(AMeters));
  for I := 0 to High(AMeters) do
    FMeters[I] := AMeters[I];
end;

function TDrumTab.Generate(Builder: TPatternBuilder;
  const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var
  FS: TFormatSettings;
  Bars: TStringList;
  Line, Token, Seg, InstName: string;
  P, AtPos, I, StepCount, BarIdx: Integer;
  MinComplexity, Complexity: Double;
  Vel: Integer;
  Ghost, Accent: Boolean;
  BarMeterNum, BarMeterDen, PerUnit: Integer;
  BarQuarters: Double;
  PositionOffset: Double;
begin
  Result := Builder;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Complexity := TemplateComplexity(Kwargs);
  BarIdx := StrToIntDef(Kwargs.Items['bar'], 0);
  PositionOffset := StrToFloatDef(Kwargs.Items['position_offset'], 0.0, DefaultFormatSettings);
  Bars := TStringList.Create;
  try
    Bars.StrictDelimiter := True;
    Bars.Delimiter := '|';
    for I := 0 to FLines.Count - 1 do
    begin
      Line := Trim(FLines[I]);
      if Line = '' then
        Continue;
      P := Pos(' ', Line);
      if P = 0 then
        Continue;
      Token := Copy(Line, 1, P - 1);
      MinComplexity := 0.0;
      AtPos := Pos('@', Token);
      if AtPos > 0 then
      begin
        MinComplexity := StrToFloatDef(Copy(Token, AtPos + 1, MaxInt), 0.0, FS);
        Token := Copy(Token, 1, AtPos - 1);
      end;
      if Complexity < MinComplexity then
        Continue;
      InstName := TabInstrument(Token);
      if InstName = '' then
        raise Exception.CreateFmt('Unknown drum tab instrument "%s" in "%s"',
          [Token, Line]);

      Bars.DelimitedText := Copy(Line, P + 1, MaxInt);
      if BarIdx >= Bars.Count then
        BarIdx := BarIdx mod Bars.Count;
      Seg := StringReplace(Bars[BarIdx], ' ', '', [rfReplaceAll]);
      StepCount := Length(Seg);
      if StepCount = 0 then
        Continue;

      (* Use header meter if available, else infer from step count *)
      if Length(FMeters) > 0 then
      begin
        BarMeterNum := FMeters[BarIdx mod Length(FMeters)].Num;
        BarMeterDen := FMeters[BarIdx mod Length(FMeters)].Den;
      end
      else if not InferMeterFromSteps(StepCount, BarMeterNum, BarMeterDen) then
        raise Exception.CreateFmt(
          'Cannot infer meter from %d steps in "%s".', [StepCount, Line]);

      { Safety guards against division by zero }
      if BarMeterNum = 0 then
        BarMeterNum := 4;
      if BarMeterDen = 0 then
        BarMeterDen := 4;

      PerUnit := StepCount div BarMeterNum;
      if (StepCount mod BarMeterNum <> 0) or not (PerUnit in [1, 2, 3, 4, 6, 8]) then
        raise Exception.CreateFmt(
          'A %d/%d drum tab bar must have %s steps, got %d in "%s"',
          [BarMeterNum, BarMeterDen, TabStepCountsText(BarMeterNum), StepCount, Line]);

      WriteLn(Format('TDrumTab.Generate: about to compute BarQuarters = %d * 4.0 / %d', [BarMeterNum, BarMeterDen]));
      if BarMeterDen = 0 then
        raise Exception.CreateFmt('TDrumTab.Generate: BarMeterDen is 0! line=%s bar=%d', [Line, BarIdx]);
      BarQuarters := BarMeterNum * 4.0 / BarMeterDen;
      WriteLn(Format('TDrumTab.Generate: BarQuarters=%f', [BarQuarters]));

      for P := 1 to StepCount do
      begin
        Ghost := False;
        Accent := False;
        case Seg[P] of
          '.', '-': Continue;
          'x': Vel := 96;
          'X': begin Vel := 118; Accent := True; end;
          'o': Vel := 70;
          'g': begin Vel := 34; Ghost := True; end;
        else
          raise Exception.CreateFmt('Unknown drum tab step "%s" in "%s"',
            [Seg[P], Line]);
        end;
        try
          Builder.Hit(InstName, (P - 1) * BarQuarters / StepCount + PositionOffset, Vel, Ghost, Accent);
        except
          on E: Exception do
            raise Exception.CreateFmt(
              'TDrumTab.Generate: division error at line "%s", bar %d, step %d, meter %d/%d, BarQuarters=%f, StepCount=%d, PositionOffset=%f',
              [Line, BarIdx, P, BarMeterNum, BarMeterDen, BarQuarters, StepCount, PositionOffset]);
        end;
      end;
      WriteLn(Format('TDrumTab.Generate: line "%s" processed OK, meter %d/%d, BarQuarters=%f',
        [Line, BarMeterNum, BarMeterDen, BarQuarters]));
    end;
  finally
    Bars.Free;
  end;
end;

function TabStepCountsText(AMeterNum: Integer): string;
const
  PerUnit: array[0..5] of Integer = (1, 2, 3, 4, 6, 8);
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(PerUnit) do
  begin
    if I = High(PerUnit) then
      Result := Result + ' or '
    else if I > 0 then
      Result := Result + ', ';
    Result := Result + IntToStr(AMeterNum * PerUnit[I]);
  end;
end;

{ Score a candidate meter for step-count inference. Higher = better. }
function ScoreMeter(ANum, ADen, AKind: Integer): Integer;
begin
  Result := 0;
  if (ANum = 4) and (ADen = 4) then
    Result := 1000; { strongly prefer 4/4 }
  { Common subdivisions }
  if (AKind = 1) and (ADen = 8) then
    Inc(Result, 100); { eighth notes in 8-based meter }
  if (AKind = 2) and (ADen = 4) then
    Inc(Result, 100); { eighth notes in 4-based meter }
  if (AKind = 4) and (ADen = 4) then
    Inc(Result, 90);  { sixteenth notes in 4-based meter }
  if (AKind = 1) and (ADen = 4) then
    Inc(Result, 80);  { quarter notes }
  if (AKind = 2) and (ADen = 8) then
    Inc(Result, 80);  { sixteenth notes in 8-based meter }
  if (AKind = 1) and (ADen = 2) then
    Inc(Result, 70);  { half notes }
  if (AKind = 3) and (ADen = 4) then
    Inc(Result, 85);  { triplet eighths }
  if (AKind = 6) and (ADen = 8) then
    Inc(Result, 85);  { triplet sixteenths }
  if (AKind = 1) and (ADen = 16) then
    Inc(Result, 60);  { thirty-second notes }
  if (AKind = 8) and (ADen = 8) then
    Inc(Result, 50);  { thirty-second notes in 8-based }
end;

function InferMeterFromSteps(ASteps: Integer; out AMeterNum, AMeterDen: Integer): Boolean;
const
  ValidDen: array[0..3] of Integer = (2, 4, 8, 16);
  ValidK: array[0..5] of Integer = (1, 2, 3, 4, 6, 8);
var
  D, K, N, I, J: Integer;
  BestScore, Score: Integer;
  BestNum, BestDen: Integer;
  Problem: string;
begin
  Result := False;
  AMeterNum := 0;
  AMeterDen := 0;
  BestScore := -1;
  BestNum := 0;
  BestDen := 0;

  for I := 0 to High(ValidDen) do
  begin
    D := ValidDen[I];
    for J := 0 to High(ValidK) do
    begin
      K := ValidK[J];
      if ASteps mod K <> 0 then
        Continue;
      N := ASteps div K;
      if (N < MIN_METER_NUMERATOR) or (N > MAX_METER_NUMERATOR) then
        Continue;
      Problem := MeterProblem(N, D);
      if Problem <> '' then
        Continue;

      Score := ScoreMeter(N, D, K);
      { Tiebreaker: smaller numerator, then smaller denominator }
      if (Score > BestScore) or
         ((Score = BestScore) and ((N < BestNum) or ((N = BestNum) and (D < BestDen)))) then
      begin
        BestScore := Score;
        BestNum := N;
        BestDen := D;
      end;
    end;
  end;

  if BestScore >= 0 then
  begin
    AMeterNum := BestNum;
    AMeterDen := BestDen;
    Result := True;
  end;
end;

procedure InferMeterFromTab(const ALines: TStringList; out AMeterNum, AMeterDen: Integer);
var
  FirstLine, Content, FirstBar: string;
  P2: Integer;
  Bars: TStringList;
  StepCount: Integer;
begin
  if ALines.Count = 0 then
    raise Exception.CreateFmt('InferMeterFromTab: no tab lines.', []);
  FirstLine := Trim(ALines[0]);
  P2 := Pos(' ', FirstLine);
  if P2 = 0 then
    raise Exception.CreateFmt('InferMeterFromTab: cannot parse first tab line "%s".', [FirstLine]);
  Content := Copy(FirstLine, P2 + 1, MaxInt);
  Bars := TStringList.Create;
  Bars.StrictDelimiter := True;
  Bars.Delimiter := '|';
  Bars.DelimitedText := Content;
  FirstBar := Trim(Bars[0]);
  Bars.Free;
  StepCount := Length(StringReplace(FirstBar, ' ', '', [rfReplaceAll]));
  if not InferMeterFromSteps(StepCount, AMeterNum, AMeterDen) then
    raise Exception.CreateFmt('InferMeterFromTab: cannot infer meter from %d steps in "%s".', [StepCount, FirstLine]);
end;

function BuildDrumTabPattern(const AName: string; const ALines: array of string;
  AComplexity: Double; AMinBars: Integer; const AMeters: array of TabFiles.TMeterPair): TPattern;
var
  Tab: TDrumTab;
  Composer: TTemplateComposer;
  Bars: Integer;
  I: Integer;
  AllSame: Boolean;
begin
  Tab := TDrumTab.Create(ALines);
  Tab.SetMeters(AMeters);
  Bars := Max(Tab.BarCount, AMinBars);
  Composer := TTemplateComposer.Create(AName);
  try
    Composer.Add(Tab);
    Result := Composer.Build(Bars, AComplexity);
    Result.Metadata.AddOrSetValue('phrase_bars', IntToStr(Bars));

    if Length(AMeters) > 0 then
    begin
      AllSame := True;
      for I := 1 to High(AMeters) do
        if (AMeters[I].Num <> AMeters[0].Num) or
           (AMeters[I].Den <> AMeters[0].Den) then
        begin
          AllSame := False;
          Break;
        end;
      if AllSame then
      begin
        Result.TimeSignature.Free;
        Result.TimeSignature := TTimeSignature.Create(AMeters[0].Num, AMeters[0].Den);
      end;
      Result.Metadata.AddOrSetValue('first_meter_num', IntToStr(AMeters[0].Num));
      Result.Metadata.AddOrSetValue('first_meter_den', IntToStr(AMeters[0].Den));
    end;
  finally
    Composer.Free;
  end;
end;

function GrooveKindOfSection(const ASection: string): string;
var
  S: string;
begin
  S := LowerCase(ASection);
  if (Pos('chorus', S) > 0) and (Pos('pre', S) = 0) then
    Result := 'chorus'
  else if (Pos('bridge', S) > 0) or (Pos('breakdown', S) > 0) or
          (Pos('solo', S) > 0) or (Pos('pre', S) > 0) then
    Result := 'bridge'
  else
    Result := 'verse';
end;

procedure GrooveBand(const AKind: string; AVariant: Integer; out AMin, AMax: Double);
const
  VerseMin: array[0..2] of Double = (0.20, 0.40, 0.60);
  VerseMax: array[0..2] of Double = (0.60, 0.80, 1.00);
  ChorusMin: array[0..2] of Double = (0.40, 0.60, 0.75);
  ChorusMax: array[0..2] of Double = (0.80, 0.95, 1.00);
  BridgeMin: array[0..2] of Double = (0.10, 0.30, 0.50);
  BridgeMax: array[0..2] of Double = (0.50, 0.70, 0.90);
var
  V: Integer;
begin
  V := EnsureRange(AVariant, 0, 2);
  if AKind = 'chorus' then
  begin
    AMin := ChorusMin[V]; AMax := ChorusMax[V];
  end
  else if AKind = 'bridge' then
  begin
    AMin := BridgeMin[V]; AMax := BridgeMax[V];
  end
  else
  begin
    AMin := VerseMin[V]; AMax := VerseMax[V];
  end;
end;

procedure TagIntensityBand(APattern: TPattern; AMin, AMax: Double);
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  APattern.Metadata.AddOrSetValue('valid_intensity_min', FormatFloat('0.00', AMin, FS));
  APattern.Metadata.AddOrSetValue('valid_intensity_max', FormatFloat('0.00', AMax, FS));
end;

function BuildTaggedGroove(const AName, AKind: string; AVariant: Integer;
  const ALines: array of string; AComplexity: Double;
  AMeterNum, AMeterDen: Integer): TPattern;
var
  Lo, Hi: Double;
  Meters: array of TabFiles.TMeterPair;
begin
  if AMeterNum <> 0 then
  begin
    SetLength(Meters, 1);
    Meters[0].Num := AMeterNum;
    Meters[0].Den := AMeterDen;
  end
  else
    SetLength(Meters, 0);
  Result := BuildDrumTabPattern(AName, ALines, AComplexity, 2, Meters);
  GrooveBand(AKind, AVariant, Lo, Hi);
  TagIntensityBand(Result, Lo, Hi);
end;

function BuildMeterFallbackGroove(const AName: string; AMeterNum, AMeterDen: Integer;
  AComplexity: Double): TPattern;
var
  Groups: TMeterGroups;
  Unit_, G, I, Start: Integer;
  UnitQ: Double;
  Pat: TPattern;
begin
  Pat := TPattern.Create(AName);
  Result := Pat;
  Groups := MeterGrouping(AMeterNum, AMeterDen);
  UnitQ := MeterUnitQuarters(AMeterDen);
  { kick on the downbeat }
  Pat.AddBeat(0.0, TInstrumentRegistry.Get('kick'), 105);
  { snare where each later group starts }
  Start := 0;
  for G := 0 to High(Groups) do
  begin
    if G > 0 then
      Pat.AddBeat(Start * UnitQ, TInstrumentRegistry.Get('snare_open_hit_open_lateral_hit'), 100);
    Inc(Start, Groups[G]);
  end;
  { hi-hat on every unit, the group starts a little louder; at higher
    complexity the kick also marks the second group }
  for Unit_ := 0 to AMeterNum - 1 do
  begin
    Start := 0;
    I := 0;
    for G := 0 to High(Groups) do
    begin
      if Unit_ = Start then
        I := 1;
      Inc(Start, Groups[G]);
    end;
    Pat.AddBeat(Unit_ * UnitQ, TInstrumentRegistry.Get('hihat_closed_1_tip_closed_1_hit'),
      IfThen(I = 1, 86, 68));
  end;
  Pat.Metadata.AddOrSetValue('phrase_bars', '1');
  Pat.Metadata.AddOrSetValue('meter_fallback', 'true');
  Pat.TimeSignature.Free;
  Pat.TimeSignature := TTimeSignature.Create(AMeterNum, AMeterDen);
end;

function BuildMeterFallbackFill(const AName: string; AMeterNum, AMeterDen: Integer;
  AFullBar: Boolean): TPattern;
const
  Toms: array[0..3] of string = ('tom_1_open_hit', 'tom_2_open_hit', 'tom_3_open_hit', 'tom_4_open_hit');
var
  UnitQ: Double;
  First, U, N: Integer;
  Pat: TPattern;
begin
  Pat := TPattern.Create(AName);
  Result := Pat;
  UnitQ := MeterUnitQuarters(AMeterDen);
  { a full-energy fill runs over the second half of the bar, a short one
    over the last two units }
  if AFullBar then
    First := AMeterNum div 2
  else
    First := Max(AMeterNum - 2, 1);
  N := 0;
  for U := First to AMeterNum - 1 do
  begin
    Pat.AddBeat(U * UnitQ, TInstrumentRegistry.Get(Toms[Min(N, 3)]), 88 + Min(N, 5) * 5);
    Inc(N);
  end;
  Pat.Metadata.AddOrSetValue('phrase_bars', '1');
  Pat.Metadata.AddOrSetValue('meter_fallback', 'true');
  Pat.TimeSignature.Free;
  Pat.TimeSignature := TTimeSignature.Create(AMeterNum, AMeterDen);
end;

constructor TTemplateComposer.Create(const AName: string);
begin
  inherited Create;
  FPName := AName;
  FTemplates := specialize TList<TPatternTemplate>.Create;
  FMeterNum := 0; { 0 means: infer from tab structure }
  FMeterDen := 0;
end;

procedure TTemplateComposer.SetMeter(ANum, ADen: Integer);
var
  Problem: string;
begin
  Problem := MeterProblem(ANum, ADen);
  if Problem <> '' then
    raise Exception.CreateFmt('Meter %d/%d: %s', [ANum, ADen, Problem]);
  FMeterNum := ANum;
  FMeterDen := ADen;
end;

destructor TTemplateComposer.Destroy;
var
  I: Integer;
begin
  for I := FTemplates.Count - 1 downto 0 do
    FTemplates[I].Free;
  FTemplates.Free;
  inherited Destroy;
end;

function TTemplateComposer.Add(APattern: TPatternTemplate): TTemplateComposer;
begin
  FTemplates.Add(APattern);
  Result := Self;
end;

function TTemplateComposer.Build(ABars: Integer; AComplexity: Double): TPattern;
var
  Builder: TPatternBuilder;
  Template: TPatternTemplate;
  Kwargs: specialize TDictionary<string, string>;
  BarIndex: Integer;
  CumulativeQuarters: Double;
  BarMeterNum, BarMeterDen: Integer;
  BarQuarters: Double;
  FirstTab: TDrumTab;
begin
  if ABars <= 0 then
    raise Exception.CreateFmt('Template pattern bars must be positive, got %d',
      [ABars]);
  Kwargs := specialize TDictionary<string, string>.Create;
  Builder := TPatternBuilder.Create(FPName);
  try
    Kwargs.Add('bars', IntToStr(ABars));
    Kwargs.Add('complexity', FloatToStr(AComplexity));
    CumulativeQuarters := 0.0;
    FirstTab := nil;
    if FTemplates.Count > 0 then
      FirstTab := TDrumTab(FTemplates[0]);
    for BarIndex := 0 to ABars - 1 do
    begin
      { Get meter for this bar index: from header meters, else infer }
      BarMeterNum := 0;
      BarMeterDen := 0;
      if Assigned(FirstTab) and (Length(FirstTab.FMeters) > 0) then
      begin
        BarMeterNum := FirstTab.FMeters[BarIndex mod Length(FirstTab.FMeters)].Num;
        BarMeterDen := FirstTab.FMeters[BarIndex mod Length(FirstTab.FMeters)].Den;
      end
      else if Assigned(FirstTab) and (FirstTab.FLines.Count > 0) then
      begin
        { Infer from first bar's step count }
        try
          InferMeterFromTab(FirstTab.FLines, BarMeterNum, BarMeterDen);
        except
          BarMeterNum := 4;
          BarMeterDen := 4;
        end;
      end
      else
      begin
        BarMeterNum := 4;
        BarMeterDen := 4;
      end;
{ Guard against garbage/invalid meter values (e.g. from an unsafe cast
      when a non-TDrumTab template is in FTemplates[0]) }
      if BarMeterNum = 0 then
        BarMeterNum := 4;
      if BarMeterDen = 0 then
        BarMeterDen := 4;
      BarQuarters := BarMeterNum * 4.0 / BarMeterDen;
      Kwargs.AddOrSetValue('position_offset', FloatToStr(CumulativeQuarters));
      Kwargs.AddOrSetValue('bar', IntToStr(BarIndex));
      for Template in FTemplates do
        Template.Generate(Builder, Kwargs);
      CumulativeQuarters := CumulativeQuarters + BarQuarters;
    end;
    Result := Builder.Build;
  finally
    Kwargs.Free;
    Builder.Free;
  end;
end;

function OverlayDoubleBassPedal(const APattern: TPattern;
  const APatternType: string; ASubdivision: Integer;
  AIntensity: Double): TPattern;
var
  Composer: TTemplateComposer;
  PedalPattern: TPattern;
  PedalBeat, ExistingBeat: TBeat;
  BarCount, I: Integer;
  FoundKick: Boolean;
begin
  if not Assigned(APattern) then
    Exit(nil);
  Result := APattern.Copy;
  if (APattern.TimeSignature.Numerator <> 4) or
     (APattern.TimeSignature.Denominator <> 4) then
    Exit;

  BarCount := Max(1, Trunc(Ceil(APattern.DurationBars)));
  Composer := TTemplateComposer.Create(APattern.Name + '_double_bass');
  Composer.Add(TDoubleBassPedal.Create(APatternType, ASubdivision, AIntensity));
  try
    PedalPattern := Composer.Build(BarCount, 0.5);
    try
      for PedalBeat in PedalPattern.Beats do
      begin
        FoundKick := False;
        for I := 0 to Result.Beats.Count - 1 do
        begin
          ExistingBeat := Result.Beats[I];
          if Assigned(ExistingBeat.Instrument) and
             SameText(ExistingBeat.Instrument.Name, 'kick') and
             (Abs(ExistingBeat.Position - PedalBeat.Position) < 0.000001) then
          begin
            ExistingBeat.Velocity := Max(ExistingBeat.Velocity,
              PedalBeat.Velocity);
            FoundKick := True;
            Break;
          end;
        end;
        if not FoundKick then
          Result.AddBeat(PedalBeat.Position, PedalBeat.Instrument,
            PedalBeat.Velocity);
      end;
    finally
      PedalPattern.Free;
    end;
  finally
    Composer.Free;
  end;
end;

end.
