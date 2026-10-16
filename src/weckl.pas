unit Weckl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TWecklPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TWecklPlugin.Create;
begin inherited Create; end;

destructor TWecklPlugin.Destroy;
begin inherited Destroy; end;

function TWecklPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var B: Integer; Result1, Result2: TPattern;
begin
  // Weckl style: linear coordination (remove simultaneous kick+snare),
  // tight even velocity, ghost notes on snare, crisp HH
  Result1 := TLinearCoordination.Create(0.85).Apply(APattern, 0.9);
  Result2 := TGhostNoteLayer.Create(0.3).Apply(Result1, 0.6);
  for B := 0 to Result2.Beats.Count - 1 do
    if Assigned(Result2.Beats[B].Instrument) then
      Result2.Beats[B].Velocity := Min(127, Max(75, Round(85 + Random * 30)));
  Result := Result2;
end;

function TWecklPlugin.GetSignatureFills: specialize TList<TFill>;
var FillList: specialize TList<TFill>; LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('weckl_linear_fill', 'Dave Weckl linear fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TWecklPlugin.GetDrummerName: String;
begin Result := 'weckl'; end;

function TWecklPlugin.GetPreferredGenres: TStringArray;
begin SetLength(Result, 3); Result[0] := 'jazz'; Result[1] := 'fusion'; Result[2] := 'rock'; end;

end.
