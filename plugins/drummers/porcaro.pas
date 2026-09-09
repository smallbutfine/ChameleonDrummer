unit Porcaro;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TPorcaroPlugin = class(TDrummerPlugin)
  private
    FShuffleFeel: TShuffleFeelApplication;
    FGhostNotes: TGhostNoteLayer;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TPorcaroPlugin.Create;
begin
  inherited Create;
  FShuffleFeel := TShuffleFeelApplication.Create(0.5);
  FGhostNotes := TGhostNoteLayer.Create(0.6);
end;

destructor TPorcaroPlugin.Destroy;
begin
  FShuffleFeel.Free;
  FGhostNotes.Free;
  inherited Destroy;
end;

function TPorcaroPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_porcaro';

  // Half-time shuffle feel (Jeff Porcaro signature)
  Styled := FShuffleFeel.Apply(Styled, 0.5);

  // Ghost notes for studio precision
  Styled := FGhostNotes.Apply(Styled, 0.6);

  Result := Styled;
end;

function TPorcaroPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('porcaro_shuffle_fill', 'Jeff Porcaro shuffle fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TPorcaroPlugin.GetDrummerName: String;
begin
  Result := 'porcaro';
end;

function TPorcaroPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('rock');
  Result.Add('funk');
  Result.Add('pop');
end;

end.
