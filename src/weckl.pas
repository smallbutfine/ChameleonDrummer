unit Weckl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TWecklPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TWecklPlugin.Create;
begin inherited Create; end;

destructor TWecklPlugin.Destroy;
begin inherited Destroy; end;

function TWecklPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; Result1, Result2: TPattern;
begin
  // Weckl style: linear coordination (remove simultaneous kick+snare),
  // tight even velocity, ghost notes on snare, crisp HH
  Result1 := ApplyAndFreeModifier(TLinearCoordination.Create(0.85), APattern, 0.9);
  Result2 := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.3), Result1, 0.6, True);
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) and
       not Result2.Beats[B].GhostNote then
      Result2.Beats[B].Velocity := Min(127, Max(75, Round(85 + Random * 30)));
  Result := Result2;
end;

function TWecklPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Linear fills: hands and feet take turns, never two hits on one step.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('weckl_fill_short', 0.3, [
    'S .... .... .... x.x.',
    'K .... .... .... .x.x'
  ]));
  Result.Add(MakeTabFill('weckl_fill_half', 0.6, [
    'S .... .... x..x ....',
    'K .... .... .x.. x...',
    'T1 .... .... .... ..xx'
  ]));
  Result.Add(MakeTabFill('weckl_fill_big', 0.9, [
    'S .... x..x ..x. ....',
    'K .... .x.. ...x x...',
    'T3 .... .... x... ....',
    'T1 .... .... .... .xx.',
    'T2 .... .... .... ...x'
  ]));
end;

function TWecklPlugin.GetDrummerName: String;
begin Result := 'weckl'; end;

function TWecklPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 3); Result[0] := 'jazz'; Result[1] := 'fusion'; Result[2] := 'rock'; end;

end.
