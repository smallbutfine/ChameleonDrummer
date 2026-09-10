unit Carey;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TCareyPlugin = class(TDrummerPlugin)
  private
    FPocketStretch: TPocketStretching;
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

constructor TCareyPlugin.Create;
begin
  inherited Create;
  FPocketStretch := TPocketStretching.Create;
  FLinearCoord := TLinearCoordination.Create(0.6);
  FGhostNotes := TGhostNoteLayer.Create(0.3);
end;

destructor TCareyPlugin.Destroy;
begin
  FPocketStretch.Free;
  FLinearCoord.Free;
  FGhostNotes.Free;
  inherited Destroy;
end;

function TCareyPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_carey';

  // Pocket stretching (Danny Carey signature)
  Styled := FPocketStretch.Apply(Styled, 0.8);

  // Linear coordination to avoid limb overlap
  Styled := FLinearCoord.Apply(Styled, 0.6);

  // Subtle ghost notes
  Styled := FGhostNotes.Apply(Styled, 0.3);

  Result := Styled;
end;

function TCareyPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('carey_tom_cascade', 'Danny Carey deep tom cascade') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TCareyPlugin.GetDrummerName: String;
begin
  Result := 'carey';
end;

function TCareyPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('rock');
  Result.Add('metal');
  Result.Add('funk');
  Result.Add('progressive');
end;

end.
