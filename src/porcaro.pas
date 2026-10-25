unit Porcaro;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TPorcaroPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TPorcaroPlugin.Create;
begin
  inherited Create;
end;

destructor TPorcaroPlugin.Destroy;
begin
  inherited Destroy;
end;

function TPorcaroPlugin.ApplyStyle(const APattern: TPattern): TPattern;
begin
  // Porcaro style: shuffle feel + ghost notes (matches Python implementation)
  Result := ApplyAndFreeModifier(TShuffleFeelApplication.Create(0.6), APattern, 0.8);
  Result := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.4), Result, 0.7, True);
end;

function TPorcaroPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Shuffle fills (12 steps): snare skips and ghost notes.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('porcaro_fill_short', 0.3, [
    'S ... ... ... x.x'
  ]));
  Result.Add(MakeTabFill('porcaro_fill_half', 0.6, [
    'S ... ... x.x ...',
    'T1 ... ... ... x.x'
  ]));
  Result.Add(MakeTabFill('porcaro_fill_big', 0.9, [
    'S ... g.g x.x ...',
    'T1 ... ... ... x.x',
    'T2 ... ... ... .x.'
  ]));
end;

function TPorcaroPlugin.GetDrummerName: String;
begin
  Result := 'porcaro';
end;

function TPorcaroPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'rock';
  Result[1] := 'funk';
  Result[2] := 'pop';
end;

end.
