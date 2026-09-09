unit Smith;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TSmithPlugin = class(TDrummerPlugin)
  private
    FPocketGroove: TPocketStretching;
    FBehindBeat: TBehindBeatTiming;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TSmithPlugin.Create;
begin
  inherited Create;
  FPocketGroove := TPocketStretching.Create;
  FBehindBeat := TBehindBeatTiming.Create(22.0);
end;

destructor TSmithPlugin.Destroy;
begin
  FPocketGroove.Free;
  FBehindBeat.Free;
  inherited Destroy;
end;

function TSmithPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_smith';

  // Pocket groove (RHCP signature)
  Styled := FPocketGroove.Apply(Styled, 0.7);

  // Slight behind-beat feel
  Styled := FBehindBeat.Apply(Styled, 0.6);

  Result := Styled;
end;

function TSmithPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('smith_pocket_fill', 'Chad Smith pocket fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TSmithPlugin.GetDrummerName: String;
begin
  Result := 'smith';
end;

function TSmithPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('rock');
  Result.Add('funk');
  Result.Add('alternative');
end;

end.
