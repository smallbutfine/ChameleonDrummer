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
var B: Integer; InstName: String; Result1, Result2: TPattern;
begin
  // Halpern style: jazz-fusion versatility + ghost notes + behind-the-beat timing
  Result1 := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.3), APattern, 0.5);
  Result2 := ApplyAndFreeModifier(TBehindBeatTiming.Create(15.0), Result1, 0.4, True);
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
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('halpern_jazz_fill', 'Eric Halpern jazz fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function THalpernPlugin.GetDrummerName: String;
begin Result := 'halpern'; end;

function THalpernPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'jazz'; Result[1] := 'fusion'; end;

end.
