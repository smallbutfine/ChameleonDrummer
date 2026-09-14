unit Moon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TMoonPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TMoonPlugin.Create;
begin
  inherited Create;
end;

destructor TMoonPlugin.Destroy;
begin
  inherited Destroy;
end;

function TMoonPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_moon');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.5);
end;

function TMoonPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('moon_fill', 'Moon signature fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TMoonPlugin.GetDrummerName: String;
begin
  Result := 'moon';
end;

function TMoonPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'rock';
  Result[1] := 'funk';
end;

end.
