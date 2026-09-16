unit DOOM_BLUES;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TDoomBluesPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TDoomBluesPlugin.Create;
begin
  inherited Create;
end;

destructor TDoomBluesPlugin.Destroy;
begin
  inherited Destroy;
end;

function TDoomBluesPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // DoomBlues composite: layered Roeder + Porcaro + Chambers techniques
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(80, Beat.Velocity + 8))
      else if Pos('snare', InstName) = 1 then
      begin
        if Random < 0.3 then
          Beat.Velocity := Max(45, Beat.Velocity - 20) // Ghost notes
        else
          Beat.Velocity := Min(127, Max(75, Beat.Velocity + 8));
      end
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(85, Max(50, Beat.Velocity - 5));
    end;
  end;
end;

function TDoomBluesPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('doomblues_fill', 'Doom Blues composite fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TDoomBluesPlugin.GetDrummerName: String;
begin
  Result := 'doom_blues';
end;

function TDoomBluesPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'metal';
  Result[1] := 'rock';
  Result[2] := 'blues';
end;

end.
