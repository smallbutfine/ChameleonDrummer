unit Chambers;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TChambersPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TChambersPlugin.Create;
begin
  inherited Create;
end;

destructor TChambersPlugin.Destroy;
begin
  inherited Destroy;
end;

function TChambersPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_chambers');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.7);
end;

function TChambersPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('chambers_funk_fill', 'Dennis Chambers funk fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TChambersPlugin.GetDrummerName: String;
begin
  Result := 'chambers';
end;

function TChambersPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'funk';
  Result[1] := 'jazz';
  Result[2] := 'rock';
end;

end.
