unit generation_parameters;

{$mode objfpc}{$H+}

{ Generation parameters value object. }

interface

uses Classes, SysUtils, Generics.Collections;

type

{ GenerationParameters — parameters controlling pattern generation. }
TGenerationParameters = class(TObject)
private
  FGenre: string;
  FStyle: string;
  FDrummer: string;
  FComplexity: Double;
  FDynamics: Double;
  FHumanization: Double;
  FFillFrequency: Double;
  FSwingRatio: Double;
  FRideThreshold: Double;
  FSongGenreContext: string;
  FContextBlend: Double;
  FCustomParameters: specialize TDictionary<string, string>;
public
  constructor Create(AGenre, AStyle: string; ADrummer: string = '';
    AComplexity: Double = 0.5; ADynamics: Double = 0.6; AHumanization: Double = 0.5;
    AFillFrequency: Double = 0.35; ASwingRatio: Double = 0.12; ARideThreshold: Double = 0.9);
  destructor Destroy; override;

  property Genre: string read FGenre write FGenre;
  property Style: string read FStyle write FStyle;
  property Drummer: string read FDrummer write FDrummer;
  property Complexity: Double read FComplexity write FComplexity;
  property Dynamics: Double read FDynamics write FDynamics;
  property Humanization: Double read FHumanization write FHumanization;
  property FillFrequency: Double read FFillFrequency write FFillFrequency;
  property SwingRatio: Double read FSwingRatio write FSwingRatio;
  property RideThreshold: Double read FRideThreshold write FRideThreshold;
  property SongGenreContext: string read FSongGenreContext write FSongGenreContext;
  property ContextBlend: Double read FContextBlend write FContextBlend;
  property CustomParameters: specialize TDictionary<string, string> read FCustomParameters;
end;

implementation

{ ---- GenerationParameters ---- }

constructor TGenerationParameters.Create(AGenre, AStyle: string; ADrummer: string = '';
  AComplexity: Double = 0.5; ADynamics: Double = 0.6; AHumanization: Double = 0.5;
  AFillFrequency: Double = 0.35; ASwingRatio: Double = 0.12; ARideThreshold: Double = 0.9);
var
  ParamValue: Double;
begin
  inherited Create;
  FGenre := AGenre;
  FStyle := AStyle;
  FDrummer := ADrummer;
  FComplexity := AComplexity;
  FDynamics := ADynamics;
  FHumanization := AHumanization;
  FFillFrequency := AFillFrequency;
  FSwingRatio := ASwingRatio;
  FRideThreshold := ARideThreshold;
  FSongGenreContext := '';
  FContextBlend := 0.0;
  FCustomParameters := specialize TDictionary<string, string>.Create;

  { Validate }
  ParamValue := FComplexity;
  if (ParamValue < 0.0) or (ParamValue > 1.0) then
    raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
  ParamValue := FDynamics;
  if (ParamValue < 0.0) or (ParamValue > 1.0) then
    raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
  ParamValue := FHumanization;
  if (ParamValue < 0.0) or (ParamValue > 1.0) then
    raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
  ParamValue := FFillFrequency;
  if (ParamValue < 0.0) or (ParamValue > 1.0) then
    raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
  ParamValue := FSwingRatio;
  if (ParamValue < 0.0) or (ParamValue > 1.0) then
    raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
  ParamValue := FRideThreshold;
  if (ParamValue < 0.0) or (ParamValue > 1.0) then
    raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
  ParamValue := FContextBlend;
  if (ParamValue < 0.0) or (ParamValue > 1.0) then
    raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
end;

destructor TGenerationParameters.Destroy;
begin
  FCustomParameters.Free;
  inherited Destroy;
end;

end.
