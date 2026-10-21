unit Dee;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TDeePlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TDeePlugin.Create;
begin inherited Create; end;

destructor TDeePlugin.Destroy;
begin inherited Destroy; end;

function TDeePlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; InstName: String; Result1, Result2, Result3: TPattern;
begin
  // Dee style: precise grid + twisted backbeats + heavy metal power accents.
  // SpeedPrecision quantises to 1/32, so it has to run before TwistedAccents
  // — otherwise the quantiser would erase the deliberate off-grid twist.
  Result1 := ApplyAndFreeModifier(TSpeedPrecision.Create, APattern, 0.7);
  Result2 := ApplyAndFreeModifier(TTwistedAccents.Create(0.5), Result1, 0.7, True);
  Result3 := ApplyAndFreeModifier(THeavyAccents.Create(15), Result2, 0.9, True);
  for B := 0 to Result3.Beats.Count - 1 do
    if Assigned(Result3.Beats[B].Instrument) then
    begin
      InstName := LowerCase(Result3.Beats[B].Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Result3.Beats[B].Velocity := Min(127, Max(90, Result3.Beats[B].Velocity + 10));
    end;
  Result := Result3;
end;

function TDeePlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('dee_power_fill', 'Mikkey Dee power fill');
  LFill.Pattern := CreateSignatureFillPattern('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TDeePlugin.GetDrummerName: String;
begin Result := 'dee'; end;

function TDeePlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 2); Result[0] := 'metal'; Result[1] := 'rock'; end;

end.
