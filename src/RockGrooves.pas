unit RockGrooves;

{$mode objfpc}{$H+}

{ Rock grooves written as drum tabs (see TDrumTab in patterns_templates).

  Every style has three grooves per section kind (verse, chorus, bridge),
  ordered from light to heavy. Blues is written on a 12-step (triplet) grid
  for the shuffle; all other styles use 16 steps per bar.

  Hand rules the grooves respect (see LimbConstraints): snare, toms 1/3 and
  crashes are played with the right hand; hi-hat, ride and tom 2 with the
  left. A crash never shares a step with the snare, and an open hat never
  shares a step with the closed hat. }

interface

uses
  SysUtils, patterns_templates;

{ Tab lines of one groove. Unknown styles fall back to 'classic'. }
function RockGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;

implementation

const
  SN24   = 'S .... x... .... x... | .... x... .... x...';
  SS24   = 'SS .... x... .... x... | .... x... .... x...';
  H8     = 'H x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  H4     = 'H x... x... x... x... | x... x... x... x...';
  H16    = 'H xxxx xxxx xxxx xxxx | xxxx xxxx xxxx xxxx';
  HO8    = 'HO x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  R8     = 'R x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  R4     = 'R x... x... x... x... | x... x... x... x...';
  CR_1   = 'C X... .... .... .... | .... .... .... ....';
  CR_11  = 'C X... .... .... .... | X... .... .... ....';
  CR_13  = 'C X... .... X... .... | X... .... X... ....';
  { Shuffle (12 steps per bar, three per beat) }
  SH_H   = 'H x.x x.x x.x x.x | x.x x.x x.x x.x';
  SH_R   = 'R x.x x.x x.x x.x | x.x x.x x.x x.x';
  SH_S   = 'S ... x.. ... x.. | ... x.. ... x..';
  SH_SS  = 'SS ... x.. ... x.. | ... x.. ... x..';
  SH_Q   = 'H x.. x.. x.. x.. | x.. x.. x.. x..';

function ClassicLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... .... x... .... | x... .... x... ....', SN24, HO8, CR_1];
      1: Result := ['K x... ..x. x... ..x. | x... ..x. x... ..x.', SN24, R8, CR_11];
    else
      Result := ['K x.x. ..x. x.x. ..x. | x.x. ..x. x.x. x.x.', SN24, R8, CR_13];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... ..x. ....', SS24, H4];
      1: Result := ['K x... .... x... .... | x... .... x... ....', SN24, R4,
           'C@0.5 X... .... .... .... | .... .... .... ....'];
    else
      Result := ['K x... ..x. .... ..x. | x... ..x. x... x.x.', SN24, R8,
        'T1@0.5 .... .... .... .... | .... .... .... ..x.'];
    end
  else
    case V of
      0: Result := ['K x... .... x... .... | x... .... x... ..x.', SN24, H8];
      1: Result := ['K x... ..x. x... ..x. | x... ..x. ..x. x...', SN24, H8,
           'S@0.6 .... ..g. .... ...g | .... ..g. .... ....'];
    else
      Result := ['K x... .x.. x... ..x. | x.x. .... x... .x..', SN24, R8];
    end;
end;

function BluesLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x.. ... x.. ... | x.. ... x.. ...', SH_S, SH_R, CR_1];
      1: Result := ['K x.. ..x x.. ..x | x.. ..x x.. ..x', SH_S, SH_R, CR_11];
    else
      Result := ['K x.. x.. x.. x.. | x.. x.. x.. x..', SH_S, SH_R,
        'C X.. ... ... ... | X.. ... ... ...'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x.. ... ... ... | x.. ... ... ...', SH_SS, SH_Q];
      1: Result := ['K x.. ... x.. ... | x.. ... x.. ...', SH_S,
           'R x.. x.. x.. x.. | x.. x.. x.. x..'];
    else
      Result := ['K x.. ..x x.. ..x | x.. ..x x.. x.x', SH_S, SH_R,
        'T1@0.5 ... ... ... ... | ... ... ... ..x'];
    end
  else
    case V of
      0: Result := ['K x.. ... x.. ... | x.. ... x.. ..x', SH_S, SH_H];
      1: Result := ['K x.. ... x.. ..x | x.. ... x.. ...', SH_S, SH_H,
           'S@0.6 ... ..g ... ... | ... ..g ... ..g'];
    else
      Result := ['K x.. x.. x.. x.. | x.. x.. x.. x..', SH_S, SH_R];
    end;
end;

function AlternativeLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... ..x. x... ..x. | x... ..x. x... ..x.', SN24, HO8, CR_1];
      1: Result := ['K x..x ..x. x..x ..x. | x..x ..x. x..x ..x.', SN24, R8, CR_11];
    else
      Result := ['K x.x. ..x. x.xx ..x. | x.x. ..x. x.xx ..x.', SN24, R8, CR_13];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... .... ....', SS24, H4];
      1: Result := ['K x... .... ..x. .... | x... .... ..x. ....',
           'S .... .... x... .... | .... .... x... ....', H8];
    else
      Result := ['K x... ..x. x... ..x. | x.x. x.x. xxxx xxxx', SN24, H8];
    end
  else
    case V of
      0: Result := ['K x... .... ..x. .... | x... ..x. .... ....', SN24,
           'HO ..x. ..x. ..x. ..x. | ..x. ..x. ..x. ..x.',
           'H x... x... x... x... | x... x... x... x...'];
      1: Result := ['K x..x ..x. .x.. ..x. | x..x ..x. .... x...',
           'S .... x... .... x... | .... x... ..g. x...', H8];
    else
      Result := ['K x... .... ..x. .x.. | x... .... ..x. ....',
        'S .... .... x... .... | .... .... x... ....', R8];
    end;
end;

function ProgressiveLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x.x. ..x. x... ..x. | x.x. ..x. x.x. ..x.', SN24, R8, CR_1];
      1: Result := ['K x..x ..x. x..x ..x. | x..x ..x. x..x ..x.', SN24, H8, CR_13];
    else
      Result := ['K x.xx ..xx x.xx ..xx | x.xx ..xx x.xx xxxx', SN24, R8, CR_13];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... .... ..x.',
           'SS .... x... .... x... | .... x... .... ....', H4];
      1: Result := ['K x..x .... ..x. ..x. | x... ..x. .... ....', SN24, R4];
    else
      Result := ['K x..x ..x. .x.. x.x. | x..x ..x. xxxx xxxx', SN24, H8, CR_1];
    end
  else
    case V of
      0: Result := ['K x..x ..x. .x.. x... | x..x ..x. .... x.x.', SN24, H8];
      1: Result := ['K x... .x.. ..x. x... | x.x. ..x. .x.. ..x.', SN24, R8];
    else
      Result := ['K x..x ..x. .x.. x.x. | x..x ..x. .x.. xx.x',
        'S .... x... .... x... | .... x... ..x. x...', R8,
        'S@0.6 ..g. .... ...g .... | .g.. .... .... ....'];
    end;
end;

function PunkLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... x... x... x... | x... x... x... x...', SN24, HO8, CR_1];
      1: Result := ['K x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.', SN24, HO8, CR_1];
    else
      Result := ['K x.x. ..x. x.x. ..x. | x.x. ..x. x.x. ..x.', SN24, R8, CR_13];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... .... ....', SN24, H4];
      1: Result := ['K x... .... x... .... | x... .... x... x...', SN24, H8];
    else
      Result := ['K x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.', SN24, H8,
        'T3@0.5 .... .... .... .... | .... .... .... .xxx'];
    end
  else
    case V of
      0: Result := ['K x... .... x... .... | x... .... x... ....', SN24, H8];
      1: Result := ['K x... ..x. x... .... | x... ..x. x... ..x.', SN24, H8];
    else
      Result := ['K x.x. ..x. x.x. ..x. | x.x. ..x. x.x. ..x.', SN24, HO8];
    end;
end;

function HardLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... x... x... x... | x... x... x... x...', SN24, HO8, CR_1];
      1: Result := ['K x.x. ..x. x.x. ..x. | x.x. ..x. x.x. ..x.', SN24, R8, CR_13];
    else
      Result := ['K x.xx ..x. x.xx ..x. | x.xx ..x. x.xx ..x.', SN24, R8, CR_13,
        'T1@0.6 .... .... .... .... | .... .... .... ..xx'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... ..x. ....',
           'S .... .... x... .... | .... .... x... ....', R4];
      1: Result := ['K x... ..x. .... ..x. | x... ..x. x... ....', SN24, H8];
    else
      Result := ['K x..x ..x. x..x xxxx | x..x ..x. x..x xxxx', SN24, R8, CR_1];
    end
  else
    case V of
      0: Result := ['K x... .... x... ..x. | x... .... x... ....', SN24, H8, CR_1];
      1: Result := ['K x.x. ..x. x... ..x. | x.x. ..x. x... x.x.', SN24, H8];
    else
      Result := ['K x..x ..x. x... x.x. | x..x ..x. x... x.x.', SN24, R8];
    end;
end;

function PopLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... x... x... x... | x... x... x... x...', SN24, HO8, CR_1];
      1: Result := ['K x... ..x. x... ..x. | x... ..x. x... ..x.', SN24, R8, CR_11];
    else
      Result := ['K x.x. ..x. x.x. ..x. | x.x. ..x. x.x. ..x.', SN24, H16, CR_11];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... .... ....', SS24, H4];
      1: Result := ['K x... .... x... .... | x... .... x... ....', SS24, H8];
    else
      Result := ['K x... .... x... ..x. | x... ..x. x... ....', SS24, H8,
        'C@0.5 X... .... .... .... | .... .... .... ....'];
    end
  else
    case V of
      0: Result := ['K x... .... x... .... | x... .... x... ..x.', SS24, H8];
      1: Result := ['K x... ..x. x... .... | x... ..x. x... ..x.', SS24, H16];
    else
      Result := ['K x..x ..x. x... ..x. | x..x ..x. x... ....', SN24, H8];
    end;
end;

function RockGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;
var
  V: Integer;
begin
  V := AVariant;
  if V < 0 then V := 0;
  if V > 2 then V := 2;
  case LowerCase(AStyle) of
    'blues': Result := BluesLines(AKind, V);
    'alternative': Result := AlternativeLines(AKind, V);
    'progressive': Result := ProgressiveLines(AKind, V);
    'punk': Result := PunkLines(AKind, V);
    'hard': Result := HardLines(AKind, V);
    'pop': Result := PopLines(AKind, V);
  else
    Result := ClassicLines(AKind, V);
  end;
end;

end.
