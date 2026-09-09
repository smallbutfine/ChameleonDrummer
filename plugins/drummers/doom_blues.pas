unit DoomBlues;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TCompositeDoomBluesPlugin = class(TDrummerPlugin)
  private
    FMinimalCreativity: TMinimalCreativity;
    FShuffleFeel: TShuffleFeelApplication;
    FPocketStretch: TPocketStretching;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TCompositeDoomBluesPlugin.Create;
begin
  inherited Create;
  FMinimalCreativity := TMinimalCreativity.Create;
  FShuffleFeel := TShuffleFeelApplication.Create(0.4);
  FPocketStretch := TPocketStretching.Create;
end;

destructor TCompositeDoomBluesPlugin.Destroy;
begin
  FMinimalCreativity.Free;
  FShuffleFeel.Free;
  FPocketStretch.Free;
  inherited Destroy;
end;

function TCompositeDoomBluesPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_doomblues';

  // Layer Roeder's minimal creativity
  Styled := FMinimalCreativity.Apply(Styled, 0.7);

  // Layer Porcaro's shuffle feel
  Styled := FShuffleFeel.Apply(Styled, 0.4);

  // Layer Chambers' pocket stretching
  Styled := FPocketStretch.Apply(Styled, 0.6);

  Result := Styled;
end;

function TCompositeDoomBluesPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('doomblues_composite_fill', 'DoomBlues composite fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TCompositeDoomBluesPlugin.GetDrummerName: String;
begin
  Result := 'doomblues';
end;

function TCompositeDoomBluesPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('metal');
  Result.Add('doom');
  Result.Add('rock');
  Result.Add('blues');
end;

end.
