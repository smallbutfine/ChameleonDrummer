unit Hoglan;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  THoglanPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor THoglanPlugin.Create;
begin
  inherited Create;
end;

destructor THoglanPlugin.Destroy;
begin
  inherited Destroy;
end;

function THoglanPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_hoglan');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.9);
end;

function THoglanPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('hoglan_blast_fill', 'Gene Hoglan blast fill');
  LFill.Pattern := TPattern.Create('blast_beat');
  FillList.Add(LFill);
  Result := FillList;
end;

function THoglanPlugin.GetDrummerName: String;
begin
  Result := 'hoglan';
end;

function THoglanPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'metal';
  Result[1] := 'progressive';
end;

end.
