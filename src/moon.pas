unit Moon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
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
  Beat: TBeat;
  InstName: string;
begin
  // Moon style: tool-influenced minimal power, spacious grooves
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(70, Beat.Velocity - 5))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(110, Max(60, Beat.Velocity + 3))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(85, Beat.Velocity - 5); // Minimal touch
    end;
  end;
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
