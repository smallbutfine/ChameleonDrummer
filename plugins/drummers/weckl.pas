unit Weckl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TWecklPlugin = class(TDrummerPlugin)
  private
    FLinearCoord: TLinearCoordination;
    FGhostNotes: TGhostNoteLayer;
    FTripeltVocab: TTripeltVocabulary;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TWecklPlugin.Create;
begin
  inherited Create;
  FLinearCoord := TLinearCoordination.Create(0.8);
  FGhostNotes := TGhostNoteLayer.Create(0.5);
  FTripeltVocab := TTripeltVocabulary.Create(0.3);
end;

destructor TWecklPlugin.Destroy;
begin
  FLinearCoord.Free;
  FGhostNotes.Free;
  FTripeltVocab.Free;
  inherited Destroy;
end;

function TWecklPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_weckl';

  // Linear coordination (Dave Weckl signature)
  Styled := FLinearCoord.Apply(Styled, 0.8);

  // Ghost notes for fusion precision
  Styled := FGhostNotes.Apply(Styled, 0.5);

  // Triplet vocabulary for fills
  Styled := FTripeltVocab.Apply(Styled, 0.3);

  Result := Styled;
end;

function TWecklPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('weckl_linear_fill', 'Dave Weckl linear fill') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TWecklPlugin.GetDrummerName: String;
begin
  Result := 'weckl';
end;

function TWecklPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('jazz');
  Result.Add('fusion');
  Result.Add('rock');
end;

end.
