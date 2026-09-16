unit Bonham;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TBonhamPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TBonhamPlugin.Create;
begin
  inherited Create;
end;

destructor TBonhamPlugin.Destroy;
begin
  inherited Destroy;
end;

function TBonhamPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Beat: TBeat;
  InstName: string;
begin
  // Bonham style: behind-the-beat feel, powerful accents on kick/snare,
  // slightly reduced hi-hat for "drunk" groove feel
  Result := APattern.Copy;
  for Beat in Result.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      InstName := LowerCase(Beat.Instrument.Name);
      if Pos('kick', InstName) = 1 then
        Beat.Velocity := Min(127, Beat.Velocity + 8)
      else if (InstName = 'snare') or (InstName = 'snare_sticks') or (InstName = 'snare_open_hit_open_lateral_hit') then
      begin
        if Random < 0.4 then
          Beat.Velocity := Max(50, Beat.Velocity - 15);
      end
      else if Pos('hihat', InstName) = 1 then
        Beat.Velocity := Min(95, Beat.Velocity + 5);
    end;
  end;
end;

function TBonhamPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill1, LFill2: TFill;
begin
  FillList := specialize TList<TFill>.Create;

  LFill1 := TFill.Create('bonham_moby_dick_fill', 'Moby Dick solo fill');
  LFill1.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill1);

  LFill2 := TFill.Create('bonham_triplet_fill', 'Bonham triplet fill');
  LFill2.Pattern := TPattern.Create('blast_beat');
  FillList.Add(LFill2);

  Result := FillList;
end;

function TBonhamPlugin.GetDrummerName: String;
begin
  Result := 'bonham';
end;

function TBonhamPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'rock';
  Result[1] := 'metal';
  Result[2] := 'blues';
end;

end.
