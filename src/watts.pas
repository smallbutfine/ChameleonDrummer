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
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Groove-first fills that stay close to the pocket.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('watts_fill_short', 0.3, [
    'S .... .... .... x...',
    'T1 .... .... .... ..x.'
  ]));
  Result.Add(MakeTabFill('watts_fill_half', 0.6, [
    'S .... .... x... ..x.',
    'T1 .... .... .... ...x'
  ]));
  Result.Add(MakeTabFill('watts_fill_big', 0.9, [
    'S .... x... x... ..x.',
    'T1 .... .... .... ...x',
    'T2 .... .... .... .x..'
  ]));
end;

function TWattsPlugin.GetDrummerName: String;
begin Result := 'watts'; end;

function TWattsPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'rock'; Result[1] := 'metal'; end;

end.
