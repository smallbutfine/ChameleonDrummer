unit Halpern;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  THalpernPlugin = class(TDrummerPlugin)
  private
    FLinearCoord: TLinearCoordination;
    FGhostNotes: TGhostNoteLayer;
    FBehindBeat: TBehindBeatTiming;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor THalpernPlugin.Create;
begin
  inherited Create;
  FLinearCoord := TLinearCoordination.Create(0.6);
  FGhostNotes := TGhostNoteLayer.Create(0.4);
  FBehindBeat := TBehindBeatTiming.Create(15.0);
end;

destructor THalpernPlugin.Destroy;
begin
  FLinearCoord.Free;
  FGhostNotes.Free;
  FBehindBeat.Free;
  inherited Destroy;
end;

function THalpernPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_halpern';

  // Linear coordination for jazz fusion versatility
  Styled := FLinearCoord.Apply(Styled, 0.6);

  // Subtle ghost notes
  Styled := FGhostNotes.Apply(Styled, 0.4);

  // Slight behind-beat feel
  Styled := FBehindBeat.Apply(Styled, 0.5);

  Result := Styled;
end;

function THalpernPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('halpern_jazz_fill', 'Halpern jazz fusion fill') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function THalpernPlugin.GetDrummerName: String;
begin
  Result := 'halpern';
end;

function THalpernPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('jazz');
  Result.Add('fusion');
  Result.Add('contemporary');
end;

end.
