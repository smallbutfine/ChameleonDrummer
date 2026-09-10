unit Haake;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  THaakePlugin = class(TDrummerPlugin)
  private
    FMechPrecision: TMechanicalPrecision;
    FLinearCoord: TLinearCoordination;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor THaakePlugin.Create;
begin
  inherited Create;
  FMechPrecision := TMechanicalPrecision.Create(0.98);
  FLinearCoord := TLinearCoordination.Create(0.7);
end;

destructor THaakePlugin.Destroy;
begin
  FMechPrecision.Free;
  FLinearCoord.Free;
  inherited Destroy;
end;

function THaakePlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_haake';

  // Mechanical precision (Meshuggah signature)
  Styled := FMechPrecision.Apply(Styled, 0.98);

  // Linear coordination for polyrhythmic feel
  Styled := FLinearCoord.Apply(Styled, 0.7);

  Result := Styled;
end;

function THaakePlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('haake_polyrhythm_fill', 'Haake polyrhythmic fill') do
  begin
    Pattern := TBlastBeat.Create('hammer', 0.9);
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function THaakePlugin.GetDrummerName: String;
begin
  Result := 'haake';
end;

function THaakePlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('metal');
  Result.Add('progressive');
  Result.Add('thrash');
end;

end.
