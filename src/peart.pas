unit Peart;

{$mode objffc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TPeartPlugin = class(TDrummerPlugin)
  private
    FExtremePrecision: TSpeedPrecision;
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

constructor TPeartPlugin.Create;
begin
  inherited Create;
  FExtremePrecision := TSpeedPrecision.Create(0.99);
  FLinearCoord := TLinearCoordination.Create(0.85);
end;

destructor TPeartPlugin.Destroy;
begin
  FExtremePrecision.Free;
  FLinearCoord.Free;
  inherited Destroy;
end;

function TPeartPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_peart';

  // Extreme timing precision (Neil Peart signature)
  Styled := FExtremePrecision.Apply(Styled, 0.99);

  // Linear limb independence
  Styled := FLinearCoord.Apply(Styled, 0.85);

  Result := Styled;
end;

function TPeartPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('peart_polyrhythm_fill', 'Neil Peart polyrhythmic fill') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TPeartPlugin.GetDrummerName: String;
begin
  Result := 'peart';
end;

function TPeartPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('progressive');
  Result.Add('metal');
  Result.Add('hard');
end;

end.
