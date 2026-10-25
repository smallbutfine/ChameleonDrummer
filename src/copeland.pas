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
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Offbeat splashes and sparse snare/tom answers.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('copeland_fill_short', 0.3, [
    'S .... .... ...x ....',
    'SP .... .... .... ..x.'
  ]));
  Result.Add(MakeTabFill('copeland_fill_half', 0.6, [
    'S .... .... x.x. ....',
    'T2 .... .... .... x.x.'
  ]));
  Result.Add(MakeTabFill('copeland_fill_big', 0.9, [
    'S .... x... x... x...',
    'T2 .... .x.. .x.. .x..',
    'HP x... .... .... ....'
  ]));
end;

function TCopelandPlugin.GetDrummerName: String;
begin Result := 'copeland'; end;

function TCopelandPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'rock'; Result[1] := 'funk'; end;

end.
