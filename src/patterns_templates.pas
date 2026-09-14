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
  public
    constructor Create(const AName: string);
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

  { Stub template types — concrete implementations moved to metal/rock etc. }
  TBasicGroove = class(TPatternTemplate)
  public
    KickPositions: specialize TList<Double>;
    SnarePositions: specialize TList<Double>;
    HiHatSubdivision: Double;
    UseOpenHiHat: boolean;
    OpenHiHatPositions: specialize TList<Double>;
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
    constructor Create; virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

  TJazzRidePattern = class(TPatternTemplate)
  public
    PatternStyle: string;
    constructor Create(APatternStyle: string); virtual;
    function Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder; override;
  end;

    TFunkGhostNotes = class(TPatternTemplate)
  public
    Style: string;
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
begin inherited Create; FPName := AName; end;

function TPatternBuilder.Kick(AtPos: Double; AVel: Integer): TPatternBuilder; begin Result := Self; end;
function TPatternBuilder.Snare(AtPos: Double; AVel: Integer): TPatternBuilder; begin Result := Self; end;
function TPatternBuilder.HiHat(AtPos: Double; AVel: Integer): TPatternBuilder; begin Result := Self; end;
function TPatternBuilder.Tom(AtPos: Double; ATomNum: string): TPatternBuilder; begin Result := Self; end;

function TPatternBuilder.Build: TPattern;
var LPattern: TPattern;
begin LPattern := TPattern.Create(FPName); Result := LPattern; end;

constructor TBasicGroove.Create(AKickPos, ASnarePos: specialize TList<Double>; AHiHatSub: Double);
begin
  inherited Create;
  if Assigned(AKickPos) then KickPositions := AKickPos else KickPositions := specialize TList<Double>.Create;
  if Assigned(ASnarePos) then SnarePositions := ASnarePos else SnarePositions := specialize TList<Double>.Create;
  HiHatSubdivision := AHiHatSub;
end;

    constructor TBasicGroove.Create;
begin inherited Create; KickPositions := specialize TList<Double>.Create; SnarePositions := specialize TList<Double>.Create; HiHatSubdivision := 0.5; end;

destructor TBasicGroove.Destroy;
begin KickPositions.Free; SnarePositions.Free; inherited Destroy; end;

function TBasicGroove.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
var Pos: Double; Vel: Integer;
begin
  for Pos in KickPositions do begin Vel := Trunc(Max(Min(Pos * 50.0 + 80.0, 127.0), 1.0)); Builder.Kick(Pos, Vel); end;
  for Pos in SnarePositions do begin Vel := Trunc(Max(Min(Pos * 50.0 + 90.0, 127.0), 1.0)); Builder.Snare(Pos, Vel); end;
  Result := Builder;
end;

constructor TDoubleBassPedal.Create(APatternType: string; ASubdiv: Double; AIntensity: Double = 0.7);
begin inherited Create; PatternType := APatternType; Subdivision := ASubdiv; Intensity := AIntensity; end;

function TDoubleBassPedal.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin Result := Builder; end;

constructor TBlastBeat.Create(AStyle: string; AIntensity: Double);
begin inherited Create; Style := AStyle; Intensity := AIntensity; end;

function TBlastBeat.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin Result := Builder; end;

constructor TCrashAccents.Create;
begin inherited Create; end;

function TCrashAccents.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin Result := Builder; end;

constructor TTomFill.Create(AFillType: string);
begin inherited Create; FillType := AFillType; end;

function TTomFill.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin Result := Builder; end;

constructor TSteadyRide.Create;
begin inherited Create; end;

function TSteadyRide.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin Result := Builder; end;

constructor TJazzRidePattern.Create(APatternStyle: string);
begin inherited Create; PatternStyle := APatternStyle; end;

function TJazzRidePattern.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin Result := Builder; end;

constructor TFunkGhostNotes.Create(AStyle: string);
begin inherited Create; Style := AStyle; end;

function TFunkGhostNotes.Generate(Builder: TPatternBuilder; const Kwargs: specialize TDictionary<string, string>): TPatternBuilder;
begin Result := Builder; end;

constructor TFunkGhostNotes.CreateDefault;
begin inherited Create; Style := 'default'; end;

constructor TTemplateComposer.Create(const AName: string);
begin inherited Create; FPName := AName; FTemplates := specialize TList<TPatternTemplate>.Create; end;

destructor TTemplateComposer.Destroy;
begin FTemplates.Free; inherited Destroy; end;

function TTemplateComposer.Add(APattern: TPatternTemplate): TTemplateComposer;
begin FTemplates.Add(APattern); Result := Self; end;

function TTemplateComposer.Build(ABars: Integer; AComplexity: Double): TPattern;
var Builder: TPatternBuilder; Template: TPatternTemplate; Kwargs: specialize TDictionary<string, string>;
begin
  Kwargs := specialize TDictionary<string, string>.Create;
  try
    Kwargs.Add('bars', ABars.ToString);
    Kwargs.Add('complexity', AComplexity.ToString);
    Builder := TPatternBuilder.Create(FPName);
    for Template in FTemplates do Template.Generate(Builder, Kwargs);
    Result := Builder.Build;
  finally
    Kwargs.Free; Builder.Free;
  end;
end;

end.
