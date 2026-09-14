unit Weckl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TWecklPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TWecklPlugin.Create;
begin
  inherited Create;
end;

destructor TWecklPlugin.Destroy;
begin
  inherited Destroy;
end;

function TWecklPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_weckl');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.6);
end;

function TWecklPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('weckl_linear_fill', 'Dave Weckl linear fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TWecklPlugin.GetDrummerName: String;
begin
  Result := 'weckl';
end;

function TWecklPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'jazz';
  Result[1] := 'fusion';
  Result[2] := 'rock';
end;

end.
