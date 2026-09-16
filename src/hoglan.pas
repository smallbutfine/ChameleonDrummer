unit Hoglan;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
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
  Beat: TBeat;
  InstName: string;
begin
  // Hoglan style: mechanical precision, extreme velocity consistency, blast-ready
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(95, Beat.Velocity + 10))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(95, Beat.Velocity + 10))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(100, Max(85, Beat.Velocity + 5));
    end;
  end;
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
