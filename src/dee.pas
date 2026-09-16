unit Dee;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
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
  Beat: TBeat;
  InstName: string;
begin
  // Dee style: speed/precision, powerful accents, twisted backbeats
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Beat.Velocity + 10)
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(85, Beat.Velocity + 12))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(95, Beat.Velocity + 3);
    end;
  end;
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
