unit Chambers;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TChambersPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TChambersPlugin.Create;
begin inherited Create; end;

destructor TChambersPlugin.Destroy;
begin inherited Destroy; end;

function TChambersPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1, Result2, Result3: TPattern;
begin
  // Chambers style: ghost notes + fast chops + pocket stretching + deep kick
  Result1 := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.5), APattern, 0.8);
  Result2 := ApplyAndFreeModifier(TFastChopsTriplets.Create(0.6), Result1, 0.7, True);
  Result3 := ApplyAndFreeModifier(TPocketStretching.Create, Result2, 0.7, True);
  for B := 0 to Result3.Beats.Count - 1 do
    if Assigned(Result3.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result3.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result3.Beats[B].Velocity := Min(127, Max(85, Result3.Beats[B].Velocity + 5));
    end;
  Result := Result3;
end;

function TChambersPlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('chambers_funk_fill', 'Dennis Chambers funk fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TChambersPlugin.GetDrummerName: String;
begin Result := 'chambers'; end;

function TChambersPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 3); Result[0] := 'funk'; Result[1] := 'jazz'; Result[2] := 'rock'; end;

end.
