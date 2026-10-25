unit Halpern;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  THalpernPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function ApplyStyleAtTempo(const APattern: TPattern;
      ATempo: Integer): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor THalpernPlugin.Create;
begin inherited Create; end;

destructor THalpernPlugin.Destroy;
begin inherited Destroy; end;

function THalpernPlugin.ApplyStyle(const APattern: TPattern): TPattern;
begin
  Result := ApplyStyleAtTempo(APattern, 120);
end;

function THalpernPlugin.ApplyStyleAtTempo(const APattern: TPattern;
  ATempo: Integer): TPattern;
var
  B: Integer;
  InstName: String;
  Result1, Result2: TPattern;
  BehindBeat: TBehindBeatTiming;
begin
  // Halpern style: jazz-fusion versatility + ghost notes + behind-the-beat timing
  Result1 := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.3), APattern, 0.5);
  BehindBeat := TBehindBeatTiming.Create(15.0);
  try
    Result2 := BehindBeat.ApplyAtTempo(Result1, 0.4, ATempo);
  finally
    BehindBeat.Free;
    Result1.Free;
  end;
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result2.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(60, Result2.Beats[B].Velocity));
    end;
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
      if Pos('snare', LowerCase(Result2.Beats[B].Instrument.Name)) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(50, Result2.Beats[B].Velocity + 3));
  Result := Result2;
end;

function THalpernPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Jazz fusion: triplet runs around the kit (12 steps).
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('halpern_fill_short', 0.3, [
    'S ... ... ... ..x',
    'T2 ... ... ... x..'
  ]));
  Result.Add(MakeTabFill('halpern_fill_half', 0.6, [
    'S ... ... x.x ..x',
    'T2 ... ... ... x..',
    'K ... ... x.. ...'
  ]));
  Result.Add(MakeTabFill('halpern_fill_big', 0.9, [
    'S ... xx. x.x ..x',
    'T1 ... ... ... x..',
    'T2 ... ... .x. ...',
    'T3 ... ... ... .x.',
    'K x.. ... ... ...'
  ]));
end;

function THalpernPlugin.GetDrummerName: String;
begin Result := 'halpern'; end;

function THalpernPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'jazz'; Result[1] := 'fusion'; end;

end.
