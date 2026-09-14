unit DOOM_BLUES;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TDoomBluesPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TDoomBluesPlugin.Create;
begin
  inherited Create;
end;

destructor TDoomBluesPlugin.Destroy;
begin
  inherited Destroy;
end;

function TDoomBluesPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_doomblues');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.7);
end;

function TDoomBluesPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('doomblues_fill', 'Doom Blues composite fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TDoomBluesPlugin.GetDrummerName: String;
begin
  Result := 'doom_blues';
end;

function TDoomBluesPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'metal';
  Result[1] := 'rock';
  Result[2] := 'blues';
end;

end.
