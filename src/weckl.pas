unit Weckl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TWecklPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TWecklPlugin.Create;
begin
  inherited Create;
end;

destructor TWecklPlugin.Destroy;
begin
  inherited Destroy;
end;

function TWecklPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Weckl style: linear coordination, tight punchy sound, even velocity
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(80, Beat.Velocity + 3))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(75, Beat.Velocity + 2))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(90, Beat.Velocity - 5); // Tighter HH
    end;
  end;
end;

function TWecklPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('weckl_linear_fill', 'Dave Weckl linear fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TWecklPlugin.GetDrummerName: String;
begin
  Result := 'weckl';
end;

function TWecklPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'jazz';
  Result[1] := 'fusion';
  Result[2] := 'rock';
end;

end.
