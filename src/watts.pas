unit Watts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TWattsPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TWattsPlugin.Create;
begin inherited Create; end;

destructor TWattsPlugin.Destroy;
begin inherited Destroy; end;

function TWattsPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1, Result2: TPattern;
begin
  // Watts style: tight punk-funk pocket + linear coordination + pocket feel
  Result1 := ApplyAndFreeModifier(TLinearCoordination.Create(0.6), APattern, 0.7);
  Result2 := ApplyAndFreeModifier(TPocketStretching.Create, Result1, 0.5, True);
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result2.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(75, Result2.Beats[B].Velocity + 8));
    end;
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
      if Pos('snare', LowerCase(Result2.Beats[B].Instrument.Name)) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(80, Result2.Beats[B].Velocity + 10));
  Result := Result2;
end;

function TWattsPlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('watts_groove_fill', 'Chris Watts groove fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TWattsPlugin.GetDrummerName: String;
begin Result := 'watts'; end;

function TWattsPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'rock'; Result[1] := 'metal'; end;

end.
