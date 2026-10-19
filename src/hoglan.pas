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
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('hoglan_blast_fill', 'Gene Hoglan blast fill');
  LFill.Pattern := CreateSignatureFillPattern('blast_beat');
  FillList.Add(LFill);
  Result := FillList;
end;

function THoglanPlugin.GetDrummerName: String;
begin Result := 'hoglan'; end;

function THoglanPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'metal'; Result[1] := 'progressive'; end;

end.
