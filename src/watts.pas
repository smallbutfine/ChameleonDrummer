unit Watts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TWattsPlugin = class(TDrummerPlugin)
  private
    FLinearCoord: TLinearCoordination;
    FGhostNotes: TGhostNoteLayer;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TWattsPlugin.Create;
begin
  inherited Create;
  FLinearCoord := TLinearCoordination.Create(0.7);
  FGhostNotes := TGhostNoteLayer.Create(0.5);
end;

destructor TWattsPlugin.Destroy;
begin
  FLinearCoord.Free;
  FGhostNotes.Free;
  inherited Destroy;
end;

function TWattsPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_watts';

  // Linear coordination for modern rock
  Styled := FLinearCoord.Apply(Styled, 0.7);

  // Ghost notes for groove
  Styled := FGhostNotes.Apply(Styled, 0.5);

  Result := Styled;
end;

function TWattsPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('watts_modern_fill', 'Watts modern fill') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TWattsPlugin.GetDrummerName: String;
begin
  Result := 'watts';
end;

function TWattsPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('rock');
  Result.Add('alternative');
  Result.Add('progressive');
end;

end.
