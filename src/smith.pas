unit Smith;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
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
  Beat: TBeat;
  InstName: string;
begin
  // Smith style: RHCP pocket groove, slap-bass influenced kick, bouncy feel
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(80, Beat.Velocity + 5))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(85, Beat.Velocity + 8))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(88, Beat.Velocity - 3); // Pocket-focused
    end;
  end;
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
