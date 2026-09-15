unit patterns_templates;

{$mode objfpc}{$H+}

{ Stub pattern templates unit. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song;

type
  { Stub TPatternBuilder — full implementation in .pas file below }
  TPatternBuilder = class(TObject)
  private
    FPName: string;
    FBeats: specialize TList<TBeat>;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function Kick(AtPos: Double; AVel: Integer): TPatternBuilder; virtual;
    function Snare(AtPos: Double; AVel: Integer): TPatternBuilder; virtual;
    function HiHat(AtPos: Double; AVel: Integer): TPatternBuilder; virtual;
    function Tom(AtPos: Double; ATomNum: string): TPatternBuilder; virtual;
    function Build: TPattern; virtual;
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

implementation

constructor TPatternBuilder.Create(const AName: string);
begin
  inherited Create;
  FPName := AName;
  FBeats := specialize TList<TBeat>.Create;
end;

destructor TPatternBuilder.Destroy;
begin
  FBeats.Free;
  inherited Destroy;
end;

function TPatternBuilder.Kick(AtPos: Double; AVel: Integer): TPatternBuilder;
var Inst: TDrumInstrument;
begin
  Result := Self;
  Inst := TInstrumentRegistry.Get('kick');
  if Assigned(Inst) then FBeats.Add(TBeat.Create(AtPos, Inst, AVel));
end;

function TPatternBuilder.Snare(AtPos: Double; AVel: Integer): TPatternBuilder;
var Inst: TDrumInstrument;
begin
  Result := Self;
  Inst := TInstrumentRegistry.Get('snare_sticks');
  if Assigned(Inst) then FBeats.Add(TBeat.Create(AtPos, Inst, AVel));
end;

function TPatternBuilder.HiHat(AtPos: Double; AVel: Integer): TPatternBuilder;
var Inst: TDrumInstrument;
begin
  Result := Self;
  Inst := TInstrumentRegistry.Get('hihat_closed_1_tip_closed_1_hit');
  if Assigned(Inst) then FBeats.Add(TBeat.Create(AtPos, Inst, AVel));
end;

function TPatternBuilder.Tom(AtPos: Double; ATomNum: string): TPatternBuilder;
var Inst: TDrumInstrument; Key: string;
begin
  Result := Self;
  Key := 'tom_' + ATomNum + '_open_hit';
  Inst := TInstrumentRegistry.Get(Key);
  if Assigned(Inst) then FBeats.Add(TBeat.Create(AtPos, Inst, 100));
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
  KickPositions.Free;
  SnarePositions.Free;
  OpenHiHatPositions.Free;
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
var I: Integer;
begin
  Result := Builder;
  // Double bass pedal pattern based on type
  if SameText(PatternType, 'gallop') then
  begin
    // Gallop: 8th-note triplet feel (16th, 32nd, 16th)
    for I := 0 to 3 do
    begin
      Builder.Kick(I * 1.0, Trunc(100 * Intensity));
      Builder.Kick(I * 1.0 + 0.5, Trunc(95 * Intensity));
      Builder.Kick(I * 1.0 + 0.75, Trunc(100 * Intensity));
    end;
  end
  else if SameText(PatternType, 'burst') then
  begin
    // Burst: rapid kick on beat 1 only
    for I := 0 to 7 do
      Builder.Kick(0.0 + I * 0.125, Trunc(110 * Intensity));
  end
  else
  begin
    // Continuous: steady quarter-note double bass
    for I := 0 to 3 do
    begin
      Builder.Kick(I * 1.0, Trunc(105 * Intensity));
      Builder.Kick(I * 1.0 + 0.5, Trunc(98 * Intensity));
    end;
  end;
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
  // Crash accents handled via high-energy cymbal promotion in genre plugin HighEnergyTimekeeper.
end;

constructor TTomFill.Create(AFillType: string);
begin inherited Create; FillType := AFillType; end;

function TTomFill.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var I: Integer;
begin
  Result := Builder;
  // Descending tom fill: tom_4 -> tom_3 -> tom_2 -> tom_1
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
begin
  FTemplates.Free;
  inherited Destroy;
end;

function TTemplateComposer.Add(APattern: TPatternTemplate): TTemplateComposer;
begin
  FTemplates.Add(APattern);
  Result := Self;
end;

function TTemplateComposer.Build(ABars: Integer; AComplexity: Double): TPattern;
var Builder: TPatternBuilder; Template: TPatternTemplate; Kwargs: specialize TDictionary<string, string>;
begin
  Kwargs := specialize TDictionary<string, string>.Create;
  try
    Kwargs.Add('bars', IntToStr(ABars));
    Kwargs.Add('complexity', FloatToStr(AComplexity));
    Builder := TPatternBuilder.Create(FPName);
    for Template in FTemplates do Template.Generate(Builder, Kwargs);
    Result := Builder.Build;
  finally
    Kwargs.Free;
    Builder.Free;
  end;
end;

end.
