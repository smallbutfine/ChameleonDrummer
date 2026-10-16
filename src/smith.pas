unit Smith;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TSmithPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TSmithPlugin.Create;
begin inherited Create; end;

destructor TSmithPlugin.Destroy;
begin inherited Destroy; end;

function TSmithPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Stretched: TPattern;
begin
  // Smith style: RHCP pocket groove, bouncy kick, loose HH
  Stretched := TPocketStretching.Create.Apply(APattern, 0.6);
  for B := 0 to Stretched.Beats.Count - 1 do
    if Assigned(Stretched.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Stretched.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Stretched.Beats[B].Velocity := Min(127, Max(80, Stretched.Beats[B].Velocity + 5));
    end;
  for B := 0 to Stretched.Beats.Count - 1 do
    if Assigned(Stretched.Beats[B].Instrument) then
      if Pos('snare', LowerCase(Stretched.Beats[B].Instrument.Name)) = 1 then
        Stretched.Beats[B].Velocity := Min(127, Max(85, Stretched.Beats[B].Velocity + 8));
  Result := Stretched;
end;

function TSmithPlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('smith_pocket_fill', 'Chad Smith pocket fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TSmithPlugin.GetDrummerName: String;
begin Result := 'chadsmith'; end;

function TSmithPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'rock'; Result[1] := 'funk'; end;

end.
