unit Bonham;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, Song, time_signature,
  DrummerPlugin, patterns_templates, DrummerMods;

type
  TBonhamPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function ApplyStyleAtTempo(const APattern: TPattern; ATempo: Integer): TPattern; override;
    function ApplyStyleForContext(const APattern: TPattern; const AGenre,
      AStyle: string; ATempo: Integer): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

const
  { Bonham's snare sat behind the grid rather than on it. Expressed in
    milliseconds so the physical distance stays constant across tempos; the
    modifier converts it to beats using the song tempo. }
  BONHAM_BEHIND_BEAT_MS = 22.0;

  { Probability that an eighth-note offbeat is moved onto the triplet grid —
    the shuffle Bonham played in 12/8. }
  BONHAM_TRIPLET_PROBABILITY = 0.35;

  { How far a hit may sit from the backbeat and still count as the backbeat. }
  BONHAM_BACKBEAT_TOLERANCE = 0.1;

function IsSnareVoice(const AInstName: String): Boolean;
begin
  { There is no plain 'snare' instrument in the registry. The snare voices are
    'snare_rimshot_open_hit', 'snare_open_hit_open_lateral_hit',
    'snare_side_stick' and friends, so the family has to be matched by prefix. }
  Result := Pos('snare', AInstName) = 1;
end;

function IsBackbeatPosition(APosition: Double; AMeterNum: Integer = 4;
  AMeterDen: Integer = 4): Boolean;
var
  PosInBar, BarQuarters, Backbeat: Double;
begin
  { Backbeats are beats 2 and 4 of a 4/4 bar, i.e. positions 1.0 and 3.0; in
    other meters the starts of the later beat groups (MeterBackbeats).
    The tolerance absorbs the behind-the-beat shift and the humanization. }
  BarQuarters := AMeterNum * 4.0 / AMeterDen;
  PosInBar := APosition - (Floor(APosition / BarQuarters) * BarQuarters);
  Result := False;
  for Backbeat in MeterBackbeats(AMeterNum, AMeterDen) do
    if Abs(PosInBar - Backbeat) <= BONHAM_BACKBEAT_TOLERANCE then
      Exit(True);
end;

constructor TBonhamPlugin.Create;
begin
  inherited Create;
end;

destructor TBonhamPlugin.Destroy;
begin
  inherited Destroy;
end;

function TBonhamPlugin.ApplyStyle(const APattern: TPattern): TPattern;
begin
  Result := ApplyStyleAtTempo(APattern, 120);
end;

function TBonhamPlugin.ApplyStyleAtTempo(const APattern: TPattern;
  ATempo: Integer): TPattern;
var
  B: Integer;
  InstName: String;
  Result1, Result2: TPattern;
  BehindBeat: TBehindBeatTiming;
begin
  { Bonham's defining trait is the "drunk" feel: the snare and kick drag
    slightly behind the grid while the hi-hat stays on it. The delay is
    specified in milliseconds and converted to beats with the song tempo, so
    the feel is the same physical distance at 75 BPM and at 220 BPM. }
  if ATempo <= 0 then
    ATempo := 120;

  Result1 := APattern.Copy;

  BehindBeat := TBehindBeatTiming.Create(BONHAM_BEHIND_BEAT_MS);
  try
    Result2 := BehindBeat.ApplyAtTempo(Result1, 0.6, ATempo);
  finally
    BehindBeat.Free;
    Result1.Free;
  end;

  { Power accent: Bonham's backbeat was huge, and the snares that were not
    on the backbeat were pulled back so the accent reads as an accent. }
  for B := 0 to Result2.Beats.Count - 1 do
  begin
    if not Assigned(Result2.Beats[B].Instrument) then Continue;
    InstName := LowerCase(Result2.Beats[B].Instrument.Name);

    if Pos('kick', InstName) = 1 then
      Result2.Beats[B].Velocity := Min(127, Result2.Beats[B].Velocity + 10)
    else if IsSnareVoice(InstName) then
    begin
      if IsBackbeatPosition(Result2.Beats[B].Position,
        Result2.TimeSignature.Numerator, Result2.TimeSignature.Denominator) then
        Result2.Beats[B].Velocity := Min(127, Result2.Beats[B].Velocity + 15)
      else
        Result2.Beats[B].Velocity := Max(50, Result2.Beats[B].Velocity - 10);
    end
    else if Pos('hihat', InstName) = 1 then
      Result2.Beats[B].Velocity := Min(95, Result2.Beats[B].Velocity + 8);
  end;

  Result := Result2;
end;

function TBonhamPlugin.ApplyStyleForContext(const APattern: TPattern;
  const AGenre, AStyle: string; ATempo: Integer): TPattern;
var
  Adapted: TPattern;
begin
  Result := inherited ApplyStyleForContext(APattern, AGenre, AStyle, ATempo);
  if not Assigned(Result) then Exit;

  { Bonham's triplet vocabulary is a blues/rock trait — the shuffle he played
    behind "Good Times Bad Times" and the descending triplet run of the
    "Moby Dick" fill. On a punk or progressive rock pattern it would fight
    the style, so the shuffle stays scoped. }
  if not SameText(AGenre, 'rock') then Exit;
  if SameText(AStyle, 'punk') or SameText(AStyle, 'progressive') then Exit;

  Adapted := ApplyAndFreeModifier(TTripletVocabulary.Create(BONHAM_TRIPLET_PROBABILITY),
    Result, 0.5, True);
  Result := Adapted;
end;

function TBonhamPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  { Fill vocabulary as one-bar drum tabs (see TDrumTab in patterns_templates).
    Triplet fills (12 steps per bar): the Moby Dick triplets.
    The energy is the bar intensity a fill suits best; edit the tabs to
    change how this drummer fills. }
  Result := specialize TList<TFill>.Create;
  Result.Add(MakeTabFill('bonham_fill_short', 0.3, [
    'S ... ... ... xxx'
  ]));
  Result.Add(MakeTabFill('bonham_fill_half', 0.6, [
    'S ... ... xxx ...',
    'T1 ... ... ... x..',
    'T2 ... ... ... .x.',
    'T3 ... ... ... ..x'
  ]));
  Result.Add(MakeTabFill('bonham_fill_big', 0.9, [
    'S ... xxx ... ...',
    'T1 ... ... xxx ...',
    'T2 ... ... ... x.x',
    'T3 ... ... ... .x.',
    'K ... ... ... x..'
  ]));
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
