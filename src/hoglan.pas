unit Hoglan;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  THoglanPlugin = class(TDrummerPlugin)
  private
    FMechPrecision: TMechanicalPrecision;
    FBlastBeats: TBlastBeatApplication;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor THoglanPlugin.Create;
begin
  inherited Create;
  FMechPrecision := TMechanicalPrecision.Create(0.97);
  FBlastBeats := TBlastBeatApplication.Create(0.8);
end;

destructor THoglanPlugin.Destroy;
begin
  FMechPrecision.Free;
  FBlastBeats.Free;
  inherited Destroy;
end;

function THoglanPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_hoglan';

  // Mechanical precision (Gene Hoglan signature)
  Styled := FMechPrecision.Apply(Styled, 0.97);

  // Blast beat application for metal
  Styled := FBlastBeats.Apply(Styled, 0.8);

  Result := Styled;
end;

function THoglanPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('hoglan_blast_fill', 'Gene Hoglan blast beat fill') do
  begin
    Pattern := TBlastBeat.Create('traditional', 0.95);
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function THoglanPlugin.GetDrummerName: String;
begin
  Result := 'hoglan';
end;

function THoglanPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('metal');
  Result.Add('death');
  Result.Add('thrash');
  Result.Add('progressive');
end;

end.
