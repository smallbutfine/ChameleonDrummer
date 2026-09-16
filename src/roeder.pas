unit Roeder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TRoederPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TRoederPlugin.Create;
begin
  inherited Create;
end;

destructor TRoederPlugin.Destroy;
begin
  inherited Destroy;
end;

function TRoederPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Roeder style: atmospheric sludge, minimal creativity, crushing weight
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(90, Beat.Velocity + 15))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(80, Beat.Velocity + 10))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(75, Max(40, Beat.Velocity - 10)); // Sparse touch
    end;
  end;
end;

function TRoederPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('roeder_atmospheric_fill', 'Jason Roeder atmospheric fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TRoederPlugin.GetDrummerName: String;
begin
  Result := 'roeder';
end;

function TRoederPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'metal';
  Result[1] := 'doom';
end;

end.
