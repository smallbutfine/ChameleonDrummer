unit Carey;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TCareyPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TCareyPlugin.Create;
begin inherited Create; end;

destructor TCareyPlugin.Destroy;
begin inherited Destroy; end;

function TCareyPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1, Result2: TPattern;
begin
  // Carey style: polyrhythmic ghost notes + deep tom emphasis
  Result1 := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.6), APattern, 0.7);
  Result2 := ApplyAndFreeModifier(TPocketStretching.Create, Result1, 0.5, True);
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result2.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result2.Beats[B].Velocity := Min(127, Result2.Beats[B].Velocity + 5);
    end;
  Result := Result2;
end;

function TCareyPlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('carey_polyrhythmic_fill', 'Danny Carey polyrhythmic fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TCareyPlugin.GetDrummerName: String;
begin Result := 'carey'; end;

function TCareyPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'metal'; Result[1] := 'progressive'; end;

end.
