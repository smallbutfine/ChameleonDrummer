unit Peart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TPeartPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TPeartPlugin.Create;
begin
  inherited Create;
end;

destructor TPeartPlugin.Destroy;
begin
  inherited Destroy;
end;

function TPeartPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Peart style: extreme precision, linear limb independence, tight control
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(85, Beat.Velocity + 5))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(90, Beat.Velocity + 8))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(95, Max(70, Beat.Velocity));
    end;
  end;
end;

function TPeartPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('peart_polyrhythmic_fill', 'Neil Peart polyrhythmic fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TPeartPlugin.GetDrummerName: String;
begin
  Result := 'peart';
end;

function TPeartPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'progressive';
  Result[1] := 'metal';
end;

end.
