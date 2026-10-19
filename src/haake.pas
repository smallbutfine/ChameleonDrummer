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

function THaakePlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('haake_polyrhythm_fill', 'Fabio Haake polyrhythm fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function THaakePlugin.GetDrummerName: String;
begin Result := 'haake'; end;

function THaakePlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'metal'; Result[1] := 'progressive'; end;

end.
