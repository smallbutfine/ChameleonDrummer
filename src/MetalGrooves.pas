unit MetalGrooves;

{$mode objfpc}{$H+}

{ Metal grooves written as drum tabs (see TDrumTab in patterns_templates).

  Every style has three grooves per section kind (verse, chorus, bridge),
  ordered from light to heavy. Variant 0 is the most restrained, variant 2 the
  most intense; GrooveBand() gives them overlapping intensity bands.

  Hand rules the grooves respect (see LimbConstraints): the snare and the
  crash/china cymbals are both played with the right hand, hi-hat and ride
  with the left, so a crash never lands on the same step as a snare hit. }

interface

uses
  SysUtils, patterns_templates;

{ Tab lines of one groove. Unknown styles fall back to 'heavy'. }
function MetalGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;

implementation

const
  { Building blocks shared by many grooves. }
  SNARE_24   = 'S .... x... .... x... | .... x... .... x...';
  SNARE_3    = 'S .... .... x... .... | .... .... x... ....';
  SNARE_BLAST = 'S .x.x .x.x .x.x .x.x | .x.x .x.x .x.x .x.x';
  SNARE_GRAV = 'S .xxx xxxx xxxx xxxx | .xxx xxxx xxxx xxxx';
  HAT_8      = 'H x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  HAT_Q      = 'H x... x... x... x... | x... x... x... x...';
  RIDE_8     = 'R x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  RIDE_Q     = 'R x... x... x... x... | x... x... x... x...';
  BELL_Q     = 'RB x... x... x... x... | x... x... x... x...';
  CRASH_1    = 'C X... .... .... .... | X... .... .... ....';
  CRASH_1A   = 'C X... .... .... .... | .... .... .... ....';
  CRASH_13   = 'C X... .... X... .... | X... .... X... ....';
  KICK_16    = 'K xxxx xxxx xxxx xxxx | xxxx xxxx xxxx xxxx';
  KICK_8     = 'K x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  KICK_GALLOP = 'K x.xx x.xx x.xx x.xx | x.xx x.xx x.xx x.xx';

function HeavyLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... ..x. x... ..x. | x... ..x. x... x.x.', SNARE_24, RIDE_8, CRASH_13];
      1: Result := ['K x.x. ..x. x.x. ..x. | x.x. ..x. x.xx ..x.', SNARE_24, RIDE_8, CRASH_13];
    else
      Result := [KICK_GALLOP, SNARE_24, RIDE_8, CRASH_13,
        'CH@0.6 ..x. .... ..x. .... | ..x. .... ..x. ....'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... ..x. ..x.', SNARE_3, HAT_Q, CRASH_1A];
      1: Result := ['K x... .... x... .... | x... .... x... ..x.', SNARE_24, RIDE_Q,
           'T2@0.5 .... .... .... .... | .... .... .... ..xx'];
    else
      Result := ['K x.xx x.xx x.xx x.xx | xxxx xxxx xxxx xxxx', SNARE_24, HAT_8, CRASH_1A];
    end
  else
    case V of
      0: Result := ['K x... .... x... .... | x... ..x. x... ....', SNARE_24, HAT_8, CRASH_1A];
      1: Result := ['K x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.xx', SNARE_24, HAT_8, CRASH_1,
           'S@0.7 .... .... .... ..g. | .... .... g... ..g.'];
    else
      Result := [KICK_GALLOP, SNARE_24, HAT_8, CRASH_1];
    end;
end;

function DeathLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x.x. x.x. x.x. x.x. | x.xx x.xx x.xx x.xx', SNARE_24, RIDE_8, CRASH_13];
      1: Result := [KICK_8, SNARE_BLAST, RIDE_8, CRASH_1];
    else
      Result := [KICK_16, SNARE_GRAV, BELL_Q, CRASH_1];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... x.x. .... | x... .... x... ..x.', SNARE_3, BELL_Q, CRASH_1A];
      1: Result := ['K x.x. x.x. x.x. x.x. | xxxx xxxx xxxx xxxx', SNARE_24, RIDE_Q];
    else
      Result := ['K x.x. x.x. x.x. x.x. | x... .... x... x.x.',
        'S .x.x .x.x .x.x .x.x | .... x... .... x...',
        'H x.x. x.x. x.x. x.x. | x... x... x... x...'];
    end
  else
    case V of
      0: Result := ['K x.x. x.xx x.x. x.xx | x.x. x.xx x.x. xxxx', SNARE_24, HAT_8, CRASH_1];
      1: Result := [KICK_8, SNARE_BLAST, HAT_8, CRASH_1];
    else
      Result := [KICK_16, SNARE_GRAV, RIDE_8, CRASH_1];
    end;
end;

function PowerLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... x... x... x... | x... x... x... x...', SNARE_24,
           'H x... x... x... x... | x... x... x... x...',
           'HO ..x. ..x. ..x. ..x. | ..x. ..x. ..x. ..x.', CRASH_1];
      1: Result := [KICK_GALLOP, SNARE_24, RIDE_8, CRASH_13];
    else
      Result := [KICK_16, SNARE_24, RIDE_8, CRASH_13];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... ..x. ..x.', SNARE_3, RIDE_8];
      1: Result := ['K x... .... x... .... | x... .... x... ..x.', SNARE_24, RIDE_8,
           'T3@0.6 .... .... .... .... | .... .... .... .x.x'];
    else
      Result := ['K x... .... x... .... | x.xx x.xx x.xx x.xx', SNARE_24, HAT_8, CRASH_1A];
    end
  else
    case V of
      0: Result := ['K x... ..x. x... ..x. | x... ..x. x... x.x.', SNARE_24, HAT_8, CRASH_1];
      1: Result := ['K x.xx x.xx x.xx x.xx | x.xx x.xx x.xx xxxx', SNARE_24, RIDE_8, CRASH_1];
    else
      Result := [KICK_16, SNARE_24, RIDE_8,
        'C X... .... X... .... | X... .... .... ....'];
    end;
end;

function ProgressiveLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x..x ..x. x..x ..x. | x..x ..x. x.x. ..x.', SNARE_24, RIDE_8, CRASH_1];
      1: Result := ['K x.x. x..x x.x. x..x | x.xx ..xx x.x. xx.x', SNARE_24, RIDE_8, CRASH_13];
    else
      Result := ['K xxxx x.xx xxxx x.xx | xxxx x.xx xxxx xxxx', SNARE_24, RIDE_8, CRASH_13];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... ..x. .... ..x. | x... .... ..x. ....',
           'SS .... x... .... x... | .... x... .... x...', HAT_Q,
           'R@0.5 ..x. ..x. ..x. ..x. | ..x. ..x. ..x. ..x.'];
      1: Result := ['K x..x ..x. .x.. x.x. | x..x ..x. .x.. x.x.', SNARE_24, RIDE_Q,
           'T1@0.5 .... .... .... ..x. | .... .... .... ....'];
    else
      Result := ['K x..x ..x. .x.. x.x. | x.xx x.xx x.xx x.xx', SNARE_24, HAT_8, CRASH_1A];
    end
  else
    case V of
      0: Result := ['K x..x ..x. .x.. x.x. | x..x ..x. .x.. x.x.',
           'S .... x... .... x... | .... x... ..x. ..x.', HAT_8];
      1: Result := ['K x..x ..x. .x.. x.x. | x..x ..x. .x.. ..x.',
           'S .... x... .... x... | .... x... ..x. ....', RIDE_8,
           'S@0.6 ..g. .... .g.. ...g | .... ..g. .... .g..'];
    else
      Result := ['K x.xx ..xx x..x xx.x | x.xx ..xx xxxx ..x.',
        'S .... x... .... x... | .... x... ..x. x...', RIDE_8, CRASH_1];
    end;
end;

function ThrashLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... x... x... x... | x... x... x... x...',
           'S ..x. ..x. ..x. ..x. | ..x. ..x. ..x. ..x.', HAT_Q];
      1: Result := [KICK_8, SNARE_24, RIDE_8, CRASH_13];
    else
      Result := [KICK_8, SNARE_BLAST, RIDE_8, CRASH_1];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... x... ..x. | x... .... x... ..x.', SNARE_24, HAT_Q];
      1: Result := ['K x.xx ..x. x.xx ..x. | x.xx ..x. x.xx ..x.', SNARE_3, BELL_Q, CRASH_1A];
    else
      Result := ['K x.x. x.x. x.x. x.x. | xxxx xxxx xxxx xxxx', SNARE_24, HAT_8, CRASH_1A];
    end
  else
    case V of
      0: Result := ['K x..x ..x. x..x ..x. | x..x ..x. x..x ..xx', SNARE_24, HAT_8, CRASH_1A];
      1: Result := ['K x.x. x.x. x.x. x.x. | x.x. x.x. x.x. xxxx', SNARE_24, HAT_8, CRASH_1];
    else
      Result := [KICK_16, SNARE_24, HAT_8,
        'C X... .... X... .... | X... .... X... ....'];
    end;
end;

function DoomLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... .... x... .... | x... .... x... ..x.', SNARE_3,
           'R x... x... x... x... | x... x... x... x...', CRASH_1];
      1: Result := ['K x.. ... x.. x.. | x.. ... x.. ...', 'S ... ... x.. ... | ... ... x.. ...',
           'R x.x x.x x.x x.x | x.x x.x x.x x.x', 'C X.. ... ... ... | X.. ... ... ...'];
    else
      Result := ['K x.x. .... x.x. .... | x.x. .... x.xx ....', SNARE_3, RIDE_8, CRASH_1];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... .... ....',
           'S .... .... .... .... | .... .... x... ....',
           'RB x... .... x... .... | x... .... x... ....', CRASH_1A];
      1: Result := ['K x... .... ..x. .... | x... .... ..x. ....', SNARE_3, RIDE_Q,
           'T4@0.5 .... .... .... x... | .... .... .... ....'];
    else
      Result := ['K x... x... x... x... | x... x... x... x...', SNARE_3,
        'RB x... .... x... .... | x... .... x... ....', CRASH_1A];
    end
  else
    case V of
      0: Result := ['K x... .... .... .... | x... .... ..x. ....', SNARE_3, RIDE_Q, CRASH_1A];
      1: Result := ['K x.. ... x.. ... | x.. ... x.. x..', 'S ... ... x.. ... | ... ... x.. ...',
           'H x.x x.x x.x x.x | x.x x.x x.x x.x', 'C X.. ... ... ... | X.. ... ... ...'];
    else
      Result := ['K x... .... x... .... | x... x... x... ....', SNARE_3,
        'T4 .... x... .... x... | .... x... .... ....', CRASH_1];
    end;
end;

function BreakdownLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x.x. ..x. x.x. .x.. | x.x. ..x. x.x. xx..', SNARE_3, RIDE_Q, CRASH_1];
      1: Result := ['K x.xx ..x. x.xx .x.. | x.xx ..x. xxxx x.x.', SNARE_3, RIDE_8, CRASH_1];
    else
      Result := ['K xxxx ..xx xxxx ..xx | xxxx ..xx xxxx xxxx', SNARE_3, RIDE_8, CRASH_1];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... ..x. ....',
           'S .... .... .... .... | .... .... x... ....', CRASH_1A,
           'RB ..x. .... ..x. .... | ..x. .... .... ....'];
      1: Result := ['K x... ..x. .... ..x. | x... ..x. ..xx ....', SNARE_3, HAT_Q, CRASH_1A];
    else
      Result := ['K x.x. ..x. x... .x.. | x.xx x.xx x.xx x.xx',
        'S .... .... x... .... | .... x... .... x...', RIDE_Q, CRASH_1A];
    end
  else
    case V of
      0: Result := ['K x.x. ..x. x... .x.. | x.x. ..x. x... ....', SNARE_3, HAT_Q, CRASH_1A];
      1: Result := ['K x.xx ..x. x.x. .x.. | x.xx ..x. x... xx..', SNARE_3, RIDE_Q, CRASH_1A];
    else
      Result := ['K x.xx ..xx x.xx ..xx | x.xx ..xx xxxx xxxx', SNARE_3, RIDE_Q, CRASH_1A];
    end;
end;

function MetalGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;
var
  V: Integer;
begin
  V := AVariant;
  if V < 0 then V := 0;
  if V > 2 then V := 2;
  case LowerCase(AStyle) of
    'death': Result := DeathLines(AKind, V);
    'power': Result := PowerLines(AKind, V);
    'progressive': Result := ProgressiveLines(AKind, V);
    'thrash': Result := ThrashLines(AKind, V);
    'doom': Result := DoomLines(AKind, V);
    'breakdown': Result := BreakdownLines(AKind, V);
  else
    Result := HeavyLines(AKind, V);
  end;
end;

end.
