unit Haake;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  THaakePlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor THaakePlugin.Create;
begin
  inherited Create;
end;

destructor THaakePlugin.Destroy;
begin
  inherited Destroy;
end;

function THaakePlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Haake style: Meshuggah mechanical polyrhythms, extreme quantization
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(95, Beat.Velocity + 15))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(90, Beat.Velocity + 12))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(100, Max(85, Beat.Velocity + 5)); // Tight HH
    end;
  end;
end;

function THaakePlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('haake_polyrhythm_fill', 'Fabio Haake polyrhythm fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function THaakePlugin.GetDrummerName: String;
begin
  Result := 'haake';
end;

function THaakePlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'metal';
  Result[1] := 'progressive';
end;

end.
