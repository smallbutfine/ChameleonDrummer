unit Copeland;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TCopelandPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TCopelandPlugin.Create;
begin
  inherited Create;
end;

destructor TCopelandPlugin.Destroy;
begin
  inherited Destroy;
end;

function TCopelandPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Copeland style: reggae/ska off-beat, cross-stick snare feel, light touch
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(60, Beat.Velocity - 10))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(85, Max(45, Beat.Velocity - 20)) // Cross-stick feel
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(90, Max(60, Beat.Velocity + 5));
    end;
  end;
end;

function TCopelandPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('copeland_offbeat_fill', 'Stewart Copeland offbeat fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TCopelandPlugin.GetDrummerName: String;
begin
  Result := 'copeland';
end;

function TCopelandPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'rock';
  Result[1] := 'funk';
end;

end.
