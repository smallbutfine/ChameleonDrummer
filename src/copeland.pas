unit Copeland;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

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
begin inherited Create; end;

destructor TCopelandPlugin.Destroy;
begin inherited Destroy; end;

function TCopelandPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Stretched, Result1: TPattern;
begin
  // Copeland style: reggae/ska off-beat feel + light touch + pocket stretching
  Stretched := ApplyAndFreeModifier(TPocketStretching.Create, APattern, 0.5);
  Result1 := ApplyAndFreeModifier(TMinimalCreativity.Create, Stretched, 0.2, True);
  for B := 0 to Result1.Beats.Count - 1 do
    if Assigned(Result1.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result1.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result1.Beats[B].Velocity := Min(127, Max(55, Result1.Beats[B].Velocity - 10));
    end;
  for B := 0 to Result1.Beats.Count - 1 do
    if Assigned(Result1.Beats[B].Instrument) then
      if Pos('snare', LowerCase(Result1.Beats[B].Instrument.Name)) = 1 then
        Result1.Beats[B].Velocity := Min(85, Max(40, Result1.Beats[B].Velocity - 20));
  Result := Result1;
end;

function TCopelandPlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('copeland_offbeat_fill', 'Stewart Copeland offbeat fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TCopelandPlugin.GetDrummerName: String;
begin Result := 'copeland'; end;

function TCopelandPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'rock'; Result[1] := 'funk'; end;

end.
