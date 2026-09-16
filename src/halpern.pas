unit Halpern;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  THalpernPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor THalpernPlugin.Create;
begin
  inherited Create;
end;

destructor THalpernPlugin.Destroy;
begin
  inherited Destroy;
end;

function THalpernPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Halpern style: jazz-fusion versatility, dynamic range, studio precision
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(65, Beat.Velocity))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(50, Beat.Velocity + 3))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(90, Max(55, Beat.Velocity - 2)); // Brushed feel
    end;
  end;
end;

function THalpernPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('halpern_jazz_fill', 'Eric Halpern jazz fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function THalpernPlugin.GetDrummerName: String;
begin
  Result := 'halpern';
end;

function THalpernPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'jazz';
  Result[1] := 'fusion';
end;

end.
