unit Carey;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

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
begin
  inherited Create;
end;

destructor TCareyPlugin.Destroy;
begin
  inherited Destroy;
end;

function TCareyPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  PatternCopy: TPattern;
  Beat: TBeat;
begin
  // Copy the pattern and apply Danny Carey-style modifications:
  // - Deep tom cascades on fills
  // - Polyrhythmic ghost notes
  // - Pushed-ahead feel with deep tom accents
  PatternCopy := APattern.Copy;
  for Beat in PatternCopy.Beats do
  begin
    if Assigned(Beat.Instrument) then
    begin
      case LowerCase(Beat.Instrument.Name) of
        'kick':
          begin
            // Deep kick with slight velocity boost
            Beat.Velocity := Min(127, Beat.Velocity + 5);
          end;
        'snare', 'snare_sticks_hit':
          begin
            // Add ghost note texture - reduce velocity slightly for Carey style
            if Random < 0.3 then
              Beat.Velocity := Max(40, Beat.Velocity - 20);
          end;
      end;
    end;
  end;
  Result := PatternCopy;
end;

function TCareyPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill: TFill;
begin
  FillList := specialize TList<TFill>.Create;
  LFill := TFill.Create('carey_polyrhythmic_fill', 'Danny Carey polyrhythmic fill');
  LFill.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill);
  Result := FillList;
end;

function TCareyPlugin.GetDrummerName: String;
begin
  Result := 'carey';
end;

function TCareyPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'metal';
  Result[1] := 'progressive';
end;

end.
