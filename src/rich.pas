unit Rich;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TRichPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TRichPlugin.Create;
begin
  inherited Create;
end;

destructor TRichPlugin.Destroy;
begin
  inherited Destroy;
end;

function TRichPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Rich style: virtuosic speed, dramatic dynamic contrast, powerful accents
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Max(80, Beat.Velocity + 15))
      else if Pos('snare', InstName) = 1 then
        Beat.Velocity := Min(127, Max(90, Beat.Velocity + 18))
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(100, Max(65, Beat.Velocity + 5));
    end;
  end;
end;

function TRichPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('rich_virtuoso_fill', 'Buddy Rich virtuoso fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TRichPlugin.GetDrummerName: String;
begin
  Result := 'rich';
end;

function TRichPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'jazz';
  Result[1] := 'rock';
end;

end.
