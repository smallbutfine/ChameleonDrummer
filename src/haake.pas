unit Haake;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  THaakePlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function ApplyStyleForContext(const APattern: TPattern; const AGenre,
      AStyle: string; ATempo: Integer): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor THaakePlugin.Create;
begin inherited Create; end;

destructor THaakePlugin.Destroy;
begin inherited Destroy; end;

function THaakePlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1, Result2: TPattern;
begin
  // Haake style: Meshuggah mechanical precision + heavy blast beats + linear
  Result1 := ApplyAndFreeModifier(TMechanicalPrecision.Create, APattern, 0.95);
  Result2 := ApplyAndFreeModifier(THeavyAccents.Create(20), Result1, 0.9, True);
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result2.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(95, Result2.Beats[B].Velocity + 15));
    end;
  Result := Result2;
end;

function THaakePlugin.ApplyStyleForContext(const APattern: TPattern;
  const AGenre, AStyle: string; ATempo: Integer): TPattern;
var
  PedalType: string;
  Subdivision: Integer;
  Adapted: TPattern;
begin
  Result := inherited ApplyStyleForContext(APattern, AGenre, AStyle, ATempo);
  if not Assigned(Result) or not SameText(AGenre, 'metal') or
     (Result.TimeSignature.Numerator <> 4) or
     (Result.TimeSignature.Denominator <> 4) then
    Exit;

  PedalType := 'continuous';
  Subdivision := 16;
  if SameText(AStyle, 'doom') then
    Exit;
  if SameText(AStyle, 'power') then
    PedalType := 'gallop'
  else if SameText(AStyle, 'breakdown') then
  begin
    PedalType := 'burst';
    Subdivision := 32;
  end;

  Adapted := OverlayDoubleBassPedal(Result, PedalType, Subdivision, 0.8);
  Result.Free;
  Result := Adapted;
end;

function THaakePlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Progressive metal: fast bursts and syncopated kick/snare.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('haake_fill_short', 0.3, [
    'S .... .... .... x.xx',
    'K .... .... .... .x..'
  ]));
  Result.Add(MakeTabFill('haake_fill_half', 0.6, [
    'T1 .... .... x..x ..x.',
    'T2 .... .... ...x ..x.'
  ]));
  Result.Add(MakeTabFill('haake_fill_big', 0.9, [
    'K x.x. ..x. x.x. ..x.',
    'S .... x... .... x...',
    'T3 .... .... .... .xx.'
  ]));
end;

function THaakePlugin.GetDrummerName: String;
begin Result := 'haake'; end;

function THaakePlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'metal'; Result[1] := 'progressive'; end;

end.
