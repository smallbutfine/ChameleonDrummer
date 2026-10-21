unit Moon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TMoonPlugin = class(TDrummerPlugin)
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

constructor TMoonPlugin.Create;
begin inherited Create; end;

destructor TMoonPlugin.Destroy;
begin inherited Destroy; end;

function TMoonPlugin.ApplyStyle(const APattern: TPattern): TPattern;
begin
  Result := ApplyStyleAtTempo(APattern, 120);
end;

function TMoonPlugin.ApplyStyleAtTempo(const APattern: TPattern;
  ATempo: Integer): TPattern;
var B: Integer; InstName: String; Result1, Result2, Result3: TPattern;
  BehindBeat: TBehindBeatTiming;
begin
  // Moon style: minimal power + spacious feel + light touch
  if ATempo <= 0 then
    ATempo := 120;

  Result1 := ApplyAndFreeModifier(TMinimalCreativity.Create, APattern, 0.3);
  Result2 := ApplyAndFreeModifier(TPocketStretching.Create, Result1, 0.4, True);

  { The spacious feel: a light, tempo-relative push behind the grid. }
  BehindBeat := TBehindBeatTiming.Create(12.0);
  try
    Result3 := BehindBeat.ApplyAtTempo(Result2, 0.35, ATempo);
  finally
    BehindBeat.Free;
    Result2.Free;
  end;

  for B := 0 to Result3.Beats.Count - 1 do
    if Assigned(Result3.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result3.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result3.Beats[B].Velocity := Min(127, Max(65, Result3.Beats[B].Velocity - 5));
    end;
  for B := 0 to Result3.Beats.Count - 1 do
    if Assigned(Result3.Beats[B].Instrument) then
      if Pos('snare', LowerCase(Result3.Beats[B].Instrument.Name)) = 1 then
        Result3.Beats[B].Velocity := Min(110, Max(55, Result3.Beats[B].Velocity + 3));
  Result := Result3;
end;

function TMoonPlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('moon_fill', 'Moon signature fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TMoonPlugin.GetDrummerName: String;
begin Result := 'moon'; end;

function TMoonPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'rock'; Result[1] := 'funk'; end;

end.
