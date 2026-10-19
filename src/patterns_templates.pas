unit patterns_templates;

{$mode objfpc}{$H+}

{ Stub pattern templates unit. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song;

type
  { Stub TPatternBuilder � full implementation in .pas file below }
  TPatternBuilder = class(TObject)
  private
    FPName: string;
    FBeats: specialize TList<TBeat>;
    FPositionOffset: Double;
    procedure AddDrumHit(const AInstrumentName: string; AtPos: Double;
      AVelocity: Integer);
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
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

  TTemplateComposer = class(TObject)
  private
    FPName: string;
    FTemplates: specialize TList<TPatternTemplate>;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function Add(APattern: TPatternTemplate): TTemplateComposer;
    function Build(ABars: Integer; AComplexity: Double): TPattern;
  end;

function OverlayDoubleBassPedal(const APattern: TPattern;
  const APatternType: string; ASubdivision: Integer;
  AIntensity: Double = 0.7): TPattern;

implementation

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
  AtPos: Double; AVelocity: Integer);
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
      Beat.Velocity := Max(Beat.Velocity, AVelocity);
      Exit;
    end;
  FBeats.Add(TBeat.Create(AtPos + FPositionOffset, Instrument, AVelocity));
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
var Pos: Double; Vel: Integer; I: Integer;
begin
  for Pos in KickPositions do begin 
    Vel := Trunc(Max(Min(Pos * 50.0 + 80.0, 127.0), 1.0)); 
    Builder.Kick(Pos, Vel); 
  end;
  for Pos in SnarePositions do begin 
    Vel := Trunc(Max(Min(Pos * 50.0 + 90.0, 127.0), 1.0)); 
    Builder.Snare(Pos, Vel); 
  end;
  // Add hi-hat timekeeping
  if HiHatSubdivision > 0 then
  begin
    I := 0;
    while I * HiHatSubdivision <= 3.5 do
    begin
      Builder.HiHat(I * HiHatSubdivision, Trunc(80 * Min(Intensity + 0.2, 1.0)));
      Inc(I);
    end;
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
var I: Integer;
begin
  Result := Builder;
  // Steady ride pattern (for jazz/fusion metal bridge)
  for I := 0 to 7 do
    Builder.Hihat(I * 0.5, Trunc(70));
end;

constructor TJazzRidePattern.Create(APatternStyle: string);
begin inherited Create; PatternStyle := APatternStyle; end;

function TJazzRidePattern.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var I: Integer;
begin
  Result := Builder;
  // Jazz ride pattern - ride cymbal on quarters
  for I := 0 to 3 do
    Builder.Hihat(I * 1.0, Trunc(75));
end;

constructor TFunkGhostNotes.Create(AStyle: string);
begin inherited Create; Style := AStyle; end;

function TFunkGhostNotes.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var I: Integer;
begin
  Result := Builder;
  // Funk ghost notes on snare
  for I := 0 to 7 do
    Builder.Snare(I * 0.5, Trunc(50));
end;

constructor TFunkGhostNotes.CreateDefault;
begin inherited Create; Style := 'default'; end;

constructor TTemplateComposer.Create(const AName: string);
begin
  inherited Create;
  FPName := AName;
  FTemplates := specialize TList<TPatternTemplate>.Create;
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
begin
  if ABars <= 0 then
    raise Exception.CreateFmt('Template pattern bars must be positive, got %d',
      [ABars]);
  Kwargs := specialize TDictionary<string, string>.Create;
  Builder := TPatternBuilder.Create(FPName);
  try
    Kwargs.Add('bars', IntToStr(ABars));
    Kwargs.Add('complexity', FloatToStr(AComplexity));
    for BarIndex := 0 to ABars - 1 do
    begin
      Builder.PositionOffset := BarIndex * 4.0;
      Kwargs.AddOrSetValue('bar', IntToStr(BarIndex));
      for Template in FTemplates do
        Template.Generate(Builder, Kwargs);
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
