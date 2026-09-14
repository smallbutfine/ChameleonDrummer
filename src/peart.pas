unit Peart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TPeartPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TPeartPlugin.Create;
begin
  inherited Create;
end;

destructor TPeartPlugin.Destroy;
begin
  inherited Destroy;
end;

function TPeartPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_peart');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.8);
end;

function TPeartPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('peart_polyrhythmic_fill', 'Neil Peart polyrhythmic fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TPeartPlugin.GetDrummerName: String;
begin
  Result := 'peart';
end;

function TPeartPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'progressive';
  Result[1] := 'metal';
end;

end.
