unit Dee;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TDeePlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TDeePlugin.Create;
begin
  inherited Create;
end;

destructor TDeePlugin.Destroy;
begin
  inherited Destroy;
end;

function TDeePlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_dee');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.8);
end;

function TDeePlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('dee_power_fill', 'Mikkey Dee power fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TDeePlugin.GetDrummerName: String;
begin
  Result := 'dee';
end;

function TDeePlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'metal';
  Result[1] := 'rock';
end;

end.
