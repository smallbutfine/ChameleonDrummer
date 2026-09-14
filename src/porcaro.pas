unit Porcaro;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TPorcaroPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TPorcaroPlugin.Create;
begin
  inherited Create;
end;

destructor TPorcaroPlugin.Destroy;
begin
  inherited Destroy;
end;

function TPorcaroPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_porcaro');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.6);
end;

function TPorcaroPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('porcaro_shuffle_fill', 'Jeff Porcaro shuffle fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TPorcaroPlugin.GetDrummerName: String;
begin
  Result := 'porcaro';
end;

function TPorcaroPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'rock';
  Result[1] := 'funk';
  Result[2] := 'pop';
end;

end.
