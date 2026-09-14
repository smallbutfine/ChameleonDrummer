unit Smith;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TSmithPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TSmithPlugin.Create;
begin
  inherited Create;
end;

destructor TSmithPlugin.Destroy;
begin
  inherited Destroy;
end;

function TSmithPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_smith');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.6);
end;

function TSmithPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('smith_pocket_fill', 'Chad Smith pocket fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TSmithPlugin.GetDrummerName: String;
begin
  Result := 'chadsmith';
end;

function TSmithPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'rock';
  Result[1] := 'funk';
end;

end.
