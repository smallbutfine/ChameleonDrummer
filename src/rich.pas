unit Rich;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TRichPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TRichPlugin.Create;
begin inherited Create; end;

destructor TRichPlugin.Destroy;
begin inherited Destroy; end;

function TRichPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1: TPattern;
begin
  // Rich style: dramatic dynamic contrast + heavy accents (virtuosic speed)
  Result1 := ApplyAndFreeModifier(THeavyAccents.Create(20), APattern, 0.9);
  for B := 0 to Result1.Beats.Count - 1 do
    if Assigned(Result1.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result1.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result1.Beats[B].Velocity := Min(127, Max(90, Result1.Beats[B].Velocity + 15));
    end;
  Result := Result1;
end;

function TRichPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Virtuoso snare rolls with a crescendo.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('rich_fill_short', 0.3, [
    'S .... .... .... xxxx'
  ]));
  Result.Add(MakeTabFill('rich_fill_half', 0.6, [
    'S .... .... oooo xxxx',
    'K .... .... x... ....'
  ]));
  Result.Add(MakeTabFill('rich_fill_big', 0.9, [
    'S oooo oooo xxxx XXXX',
    'K x... .... x... ....'
  ]));
end;

function TRichPlugin.GetDrummerName: String;
begin Result := 'rich'; end;

function TRichPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'jazz'; Result[1] := 'rock'; end;

end.
