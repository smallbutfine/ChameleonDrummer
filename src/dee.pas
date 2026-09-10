unit Dee;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TDeePlugin = class(TDrummerPlugin)
  private
    FSpeedPrecision: TSpeedPrecision;
    FTwistedAccents: TTwistedAccents;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TDeePlugin.Create;
begin
  inherited Create;
  FSpeedPrecision := TSpeedPrecision.Create(0.95);
  FTwistedAccents := TTwistedAccents.Create(12);
end;

destructor TDeePlugin.Destroy;
begin
  FSpeedPrecision.Free;
  FTwistedAccents.Free;
  inherited Destroy;
end;

function TDeePlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_dee';

  // Speed and precision (Mikkey Dee signature)
  Styled := FSpeedPrecision.Apply(Styled, 0.95);

  // Twisted/displaced accents
  Styled := FTwistedAccents.Apply(Styled, 0.7);

  Result := Styled;
end;

function TDeePlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('dee_power_fill', 'Mikkey Dee power fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TDeePlugin.GetDrummerName: String;
begin
  Result := 'dee';
end;

function TDeePlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('metal');
  Result.Add('rock');
  Result.Add('hard');
end;

end.
