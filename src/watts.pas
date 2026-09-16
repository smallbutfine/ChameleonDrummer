unit Watts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TWattsPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TWattsPlugin.Create;
begin
  inherited Create;
end;

destructor TWattsPlugin.Destroy;
begin
  inherited Destroy;
end;

function TWattsPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Watts style: Arctic Monkeys energy, tight punk-funk pocket
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(75, Beat.Velocity + 8))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(80, Beat.Velocity + 10))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(95, Max(70, Beat.Velocity + 3));
    end;
  end;
end;

function TWattsPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('watts_groove_fill', 'Chris Watts groove fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TWattsPlugin.GetDrummerName: String;
begin
  Result := 'watts';
end;

function TWattsPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'rock';
  Result[1] := 'metal';
end;

end.
