unit Chambers;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TChambersPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TChambersPlugin.Create;
begin
  inherited Create;
end;

destructor TChambersPlugin.Destroy;
begin
  inherited Destroy;
end;

function TChambersPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Chambers style: funk mastery, ghost notes on snare, deep kick pocket
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(80, Beat.Velocity + 5))
      else if Pos('snare', InstName) = 1 then
      begin
        if Random < 0.35 then
          Beat.Velocity := Max(35, Beat.Velocity - 30) // Ghost notes
        else
          Beat.Velocity := Min(127, Beat.Velocity + 5);
      end
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(88, Beat.Velocity - 3); // Pocket-focused HH
    end;
  end;
end;

function TChambersPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('chambers_funk_fill', 'Dennis Chambers funk fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TChambersPlugin.GetDrummerName: String;
begin
  Result := 'chambers';
end;

function TChambersPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'funk';
  Result[1] := 'jazz';
  Result[2] := 'rock';
end;

end.
