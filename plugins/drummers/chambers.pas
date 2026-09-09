unit Chambers;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TChambersPlugin = class(TDrummerPlugin)
  private
    FGhostNotes: TGhostNoteLayer;
    FPocketStretch: TPocketStretching;
    FFastChops: TFastChopsTriplets;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TChambersPlugin.Create;
begin
  inherited Create;
  FGhostNotes := TGhostNoteLayer.Create(0.5);
  FPocketStretch := TPocketStretching.Create;
  FFastChops := TFastChopsTriplets.Create(0.4);
end;

destructor TChambersPlugin.Destroy;
begin
  FGhostNotes.Free;
  FPocketStretch.Free;
  FFastChops.Free;
  inherited Destroy;
end;

function TChambersPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_chambers';

  // Heavy ghost notes (Dennis Chambers signature)
  Styled := FGhostNotes.Apply(Styled, 0.5);

  // Pocket stretching for funk grooves
  Styled := FPocketStretch.Apply(Styled, 0.7);

  // Fast chops triplets for fills
  Styled := FFastChops.Apply(Styled, 0.4);

  Result := Styled;
end;

function TChambersPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('chambers_funk_fill', 'Dennis Chambers funk fill') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TChambersPlugin.GetDrummerName: String;
begin
  Result := 'chambers';
end;

function TChambersPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('funk');
  Result.Add('fusion');
  Result.Add('rock');
end;

end.
