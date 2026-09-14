unit Halpern;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  THalpernPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor THalpernPlugin.Create;
begin
  inherited Create;
end;

destructor THalpernPlugin.Destroy;
begin
  inherited Destroy;
end;

function THalpernPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_halpern');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.6);
end;

function THalpernPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('halpern_jazz_fill', 'Eric Halpern jazz fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function THalpernPlugin.GetDrummerName: String;
begin
  Result := 'halpern';
end;

function THalpernPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'jazz';
  Result[1] := 'fusion';
end;

end.
