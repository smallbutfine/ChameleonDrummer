unit Hoglan;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  THoglanPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor THoglanPlugin.Create;
begin inherited Create; end;

destructor THoglanPlugin.Destroy;
begin inherited Destroy; end;

function THoglanPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1, Result2: TPattern;
begin
  // Hoglan style: mechanical precision + heavy blast-beat-ready accents
  Result1 := ApplyAndFreeModifier(TMechanicalPrecision.Create, APattern, 0.85);
  Result2 := ApplyAndFreeModifier(THeavyAccents.Create(18), Result1, 0.9, True);
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result2.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(95, Result2.Beats[B].Velocity + 10));
    end;
  Result := Result2;
end;

function THoglanPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Blast bursts: snare and kick alternate on sixteenths.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('hoglan_fill_short', 0.3, [
    'S .... .... .... x.x.',
    'K .... .... .... .x.x'
  ]));
  Result.Add(MakeTabFill('hoglan_fill_half', 0.6, [
    'S .... .... x.x. x.x.',
    'K .... .... .x.x .x.x'
  ]));
  Result.Add(MakeTabFill('hoglan_fill_big', 0.9, [
    'S x.x. x.x. x.x. x.x.',
    'K .x.x .x.x .x.x .x.x'
  ]));
end;

function THoglanPlugin.GetDrummerName: String;
begin Result := 'hoglan'; end;

function THoglanPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'metal'; Result[1] := 'progressive'; end;

end.
