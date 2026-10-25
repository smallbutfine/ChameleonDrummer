unit DOOM_BLUES;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TDoomBluesPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function ApplyStyleAtTempo(const APattern: TPattern;
      ATempo: Integer): TPattern; override;
    function ApplyStyleForContext(const APattern: TPattern; const AGenre,
      AStyle: string; ATempo: Integer): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TDoomBluesPlugin.Create;
begin
  inherited Create;
end;

destructor TDoomBluesPlugin.Destroy;
begin
  inherited Destroy;
end;

function TDoomBluesPlugin.ApplyStyle(const APattern: TPattern): TPattern;
begin
  Result := ApplyStyleAtTempo(APattern, 120);
end;

function TDoomBluesPlugin.ApplyStyleAtTempo(const APattern: TPattern;
  ATempo: Integer): TPattern;
var
  B: Integer;
  InstName: String;
  Result1, Result2: TPattern;
begin
  { DoomBlues composite: layered Roeder + Chambers techniques.
    Roeder's sparse, atmospheric minimalism strips the pattern back, then
    Chambers' ghost note layer adds the shuffle-and-groove detail that the
    raw Random branch used to fake. }
  Result1 := ApplyAndFreeModifier(TMinimalCreativity.Create, APattern, 0.3);
  Result2 := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.5), Result1, 0.5, True);

  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result2.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(80, Result2.Beats[B].Velocity + 8))
      else if Pos('snare', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(127, Max(75, Result2.Beats[B].Velocity + 8))
      else if Pos('hihat', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(85, Max(50, Result2.Beats[B].Velocity - 5));
    end;

  Result := Result2;
end;

function TDoomBluesPlugin.ApplyStyleForContext(const APattern: TPattern;
  const AGenre, AStyle: string; ATempo: Integer): TPattern;
var
  Adapted: TPattern;
begin
  Result := inherited ApplyStyleForContext(APattern, AGenre, AStyle, ATempo);
  if not Assigned(Result) then Exit;

  { Porcaro's shuffle is the third layer of the composite, but it belongs to
    the rock/blues half of it. On a metal pattern the shuffle would fight the
    genre, so it stays scoped. }
  if not (SameText(AGenre, 'rock') or SameText(AGenre, 'blues')) then Exit;

  Adapted := ApplyAndFreeModifier(TShuffleFeelApplication.Create(0.35), Result, 0.5, True);
  Result := Adapted;
end;

function TDoomBluesPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Composite doom/blues: slow blues triplets on the toms (12 steps).
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('doomblues_fill_short', 0.3, [
    'S ... ... ... x.x',
    'K ... ... ... ..x'
  ]));
  Result.Add(MakeTabFill('doomblues_fill_half', 0.6, [
    'T4 ... ... x.. ...',
    'T3 ... ... ... x..',
    'S ... ... ... .x.'
  ]));
  Result.Add(MakeTabFill('doomblues_fill_big', 0.9, [
    'T1 ... xxx ... ...',
    'T2 ... ... xxx ...',
    'T4 ... ... ... xxx',
    'K x.. ... ... ...'
  ]));
end;

function TDoomBluesPlugin.GetDrummerName: String;
begin
  Result := 'doom_blues';
end;

function TDoomBluesPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'metal';
  Result[1] := 'rock';
  Result[2] := 'blues';
end;

end.
