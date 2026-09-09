unit generation_parameters;

{$mode objfpc}{$H+}

{ Generation parameters value object. }

interface

uses Generics.Collections;

type

{ GenerationParameters — parameters controlling pattern generation. }
TGenerationParameters = class(TObject)
private
  FGenre: string;
  FStyle: string;
  FDrummer: string;
  FComplexity: float;
  FDynamics: float;
  FHumanization: float;
  FFillFrequency: float;
  FSwingRatio: float;
  FRideThreshold: float;
  FSongGenreContext: string;
  FContextBlend: float;
  FCustomParameters: TDictionary<string, string>;
public
  constructor Create(AGenre, AStyle: string; ADrummer: string = '';
    AComplexity: float = 0.5; ADynamics: float = 0.6; AHumanization: float = 0.5;
    AFillFrequency: float = 0.35; ASwingRatio: float = 0.12; ARideThreshold: float = 0.9);
  destructor Destroy; override;

  property Genre: string read FGenre write FGenre;
  property Style: string read FStyle write FStyle;
  property Drummer: string read FDrummer write FDrummer;
  property Complexity: float read FComplexity write FComplexity;
  property Dynamics: float read FDynamics write FDynamics;
  property Humanization: float read FHumanization write FHumanization;
  property FillFrequency: float read FFillFrequency write FFillFrequency;
  property SwingRatio: float read FSwingRatio write FSwingRatio;
  property RideThreshold: float read FRideThreshold write FRideThreshold;
  property SongGenreContext: string read FSongGenreContext write FSongGenreContext;
  property ContextBlend: float read FContextBlend write FContextBlend;
  property CustomParameters: TDictionary<string, string> read FCustomParameters;
end;

implementation

{ ── GenerationParameters ─────────────────────────────────────────────────── }

constructor TGenerationParameters.Create(AGenre, AStyle: string; ADrummer: string = '';
  AComplexity: float = 0.5; ADynamics: float = 0.6; AHumanization: float = 0.5;
  AFillFrequency: float = 0.35; ASwingRatio: float = 0.12; ARideThreshold: float = 0.9);
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
  FCustomParameters := TDictionary<string, string>.Create;

  { Validate }
  for var ParamValue: float in [FComplexity, FDynamics, FHumanization, FFillFrequency, FSwingRatio, FRideThreshold, FContextBlend] do
  begin
    if (ParamValue < 0.0) or (ParamValue > 1.0) then
      raise Exception.CreateFmt('Parameter must be between 0.0 and 1.0, got %f', [ParamValue]);
  end;
end;

destructor TGenerationParameters.Destroy;
begin
  FCustomParameters.Free;
  inherited Destroy;
end;

end.
