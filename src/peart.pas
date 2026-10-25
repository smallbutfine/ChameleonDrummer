unit Peart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TPeartPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TPeartPlugin.Create;
begin inherited Create; end;

destructor TPeartPlugin.Destroy;
begin inherited Destroy; end;

function TPeartPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1, Result2, Result3: TPattern;
begin
  // Peart style: linear coordination + mechanical precision + heavy accents
  Result1 := ApplyAndFreeModifier(TLinearCoordination.Create(0.9), APattern, 0.85);
  Result2 := ApplyAndFreeModifier(TMechanicalPrecision.Create, Result1, 0.95, True);
  Result3 := ApplyAndFreeModifier(THeavyAccents.Create(15), Result2, 0.8, True);
  for B := 0 to Result3.Beats.Count - 1 do
    if Assigned(Result3.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result3.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result3.Beats[B].Velocity := Min(127, Max(85, Result3.Beats[B].Velocity + 5));
    end;
  Result := Result3;
end;

function TPeartPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Polyrhythmic tom runs.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('peart_fill_short', 0.3, [
    'T1 .... .... .... x.x.',
    'T2 .... .... .... .x.x'
  ]));
  Result.Add(MakeTabFill('peart_fill_half', 0.6, [
    'T1 ... ... x.. x..',
    'T2 ... ... .x. .x.',
    'T3 ... ... ..x ..x'
  ]));
  Result.Add(MakeTabFill('peart_fill_big', 0.9, [
    'T1 x..x ..x. .x.. x..x',
    'T2 .x.. .... ..x. ....',
    'K x... .... x... ....'
  ]));
end;

function TPeartPlugin.GetDrummerName: String;
begin Result := 'peart'; end;

function TPeartPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'progressive'; Result[1] := 'metal'; end;

end.
