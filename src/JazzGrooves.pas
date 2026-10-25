unit JazzGrooves;

{$mode objfpc}{$H+}

{ Jazz grooves written as drum tabs (see TDrumTab in patterns_templates).

  Every style has three grooves per section kind (verse, chorus, bridge),
  ordered from light to heavy. Swing, bebop, hard bop and ballad use a
  12-step (triplet) grid so the ride pattern really swings; latin uses
  8 steps per bar (bossa/samba with a son clave on the side stick);
  fusion and contemporary use 16 steps.

  Hand rules the grooves respect (see LimbConstraints): the ride, hi-hat and
  tom 2 are played with the left hand; snare, side stick, crashes and toms
  1/3 with the right. The hi-hat pedal and the kick are feet. A ride and a
  bell never share a step, and no step has more than three hits. }

interface

uses
  SysUtils, patterns_templates;

{ Tab lines of one groove. Unknown styles fall back to 'swing'. }
function JazzGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;

implementation

const
  { 12-step swing building blocks: beat = 3 steps, the skip note is the
    third triplet of beats 2 and 4. }
  SWR  = 'R x.. x.x x.. x.x | x.. x.x x.. x.x';
  RQ   = 'R x.. x.. x.. x.. | x.. x.. x.. x..';
  HPS  = 'HP ... x.. ... x.. | ... x.. ... x..';
  FEA  = 'K o.. o.. o.. o.. | o.. o.. o.. o..';
  CR12 = 'C X.. ... ... ... | ... ... ... ...';
  { 16-step building blocks }
  S24  = 'S .... x... .... x... | .... x... .... x...';
  R8   = 'R x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  R4   = 'R x... x... x... x... | x... x... x... x...';
  H8   = 'H x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  HP24 = 'HP .... x... .... x... | .... x... .... x...';
  CR16 = 'C X... .... .... .... | .... .... .... ....';
  CR16B = 'C X... .... .... .... | X... .... .... ....';
  { 8-step latin building blocks }
  BOSSA_K = 'K x..x x..x | x..x x..x';
  CLAVE   = 'SS x..x ..x. | ..x. x...';
  L_H8    = 'H x.x. x.x. | x.x. x.x.';
  L_R8    = 'R x.x. x.x. | x.x. x.x.';
  L_HP    = 'HP ..x. ..x. | ..x. ..x.';

function SwingLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := [SWR, HPS, 'K x.. ... x.. ... | x.. ... x.. ...', CR12];
      1: Result := [SWR, HPS, FEA, 'S ... ..x ... .o. | ... ..x ... ..o', CR12];
    else
      Result := [SWR, HPS, 'K x.. o.. x.. o.. | x.. o.. x.. ..x',
        'S ... ..x .x. ..x | ... ..x ..x .x.', CR12];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := [RQ, HPS, 'K x.. ... ... ... | ... ... ... ...',
           'S ... ... ... ... | ... ..o ... ...'];
      1: Result := [SWR, HPS, 'SS ... x.. ... x.. | ... x.. ... x..'];
    else
      Result := [SWR, HPS, FEA, 'T1@0.5 ... ... ... ... | ... ... ..x ..x'];
    end
  else
    case V of
      0: Result := [SWR, HPS, FEA];
      1: Result := [SWR, HPS, FEA, 'S ... ..o ... ... | ... ..o ... ...'];
    else
      Result := [SWR, HPS, FEA, 'S ... ..x .x. ... | ... ..o ... .x.',
        'K@0.6 ... ... ... ..x | ... ... ... ...'];
    end;
end;

function BebopLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := [SWR, HPS, 'K x.. ..o x.. ..o | x.. ..o x.. ..o', CR12];
      1: Result := [SWR, HPS, 'K x.. ..o x.. ..o | x.. ..o x.. ..x',
           'S ... ..x .x. ... | ... ..x ..x .o.', CR12];
    else
      Result := [SWR, HPS, 'K x.. ..x x.. ..x | x.. ..x x.. ..x',
        'S .x. ..x .x. ..x | .x. ..x ..x .x.', CR12];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := [RQ, HPS, 'K o.. ... ... ... | o.. ... ... ...',
           'S ... ... ... ..o | ... ... ... ...'];
      1: Result := [SWR, HPS, FEA, 'S ... ..o ... ... | ... ... ..o ...'];
    else
      Result := [SWR, HPS, 'K o.. ..x o.. ..x | o.. ..x o.. ..x',
        'S ... ..x .x. ..x | ... ..x .x. ...',
        'T1@0.6 ... ... ... ... | ... ... ... .xx'];
    end
  else
    case V of
      0: Result := [SWR, HPS, FEA, 'S@0.5 ... ... ..o ... | ... ..o ... ...'];
      1: Result := [SWR, HPS, 'K o.. ... o.. ..x | o.. ..x ... ...',
           'S ... ..x ... .o. | ... ..x .o. ...'];
    else
      Result := [SWR, HPS, 'K o.. ..x o.. ... | o.. ... ..x ..x',
        'S ... ..x .x. ... | .x. ..x ... ..x',
        'C@0.6 ... ... ... ... | X.. ... ... ...'];
    end;
end;

function HardBopLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := [SWR, HPS, 'K x.. ... x.. ... | x.. ... x.. ...',
           'S ... x.. ... x.. | ... x.. ... x..', CR12];
      1: Result := [SWR, HPS, 'K x.. ..x x.. ... | x.. ... x.. ..x',
           'S ... x.. ..x x.. | ... x.. ... x..', CR12];
    else
      Result := [SWR, HPS, 'K x.. ..x x.. ..x | x.. ..x x.. ..x',
        'S ... x.. .x. x.. | ... x.. ..x x..', CR12];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := [RQ, HPS, 'K x.. ... ... ... | ... ... ... ...',
           'SS ... ... ... x.. | ... ... ... ...'];
      1: Result := [SWR, HPS, 'K o.. ... ... ... | o.. ... ... ...',
           'S ... x.. ... ... | ... ... ... x..'];
    else
      Result := [SWR, HPS, 'K x.. ... x.. ..x | x.. ... x.. ...',
        'S ... x.. ... x.. | ... x.. ... x..', CR12];
    end
  else
    case V of
      0: Result := [SWR, HPS, 'K x.. ... ... ... | x.. ... ... ...',
           'S ... ..o ... ... | ... ..o ... ...'];
      1: Result := [SWR, HPS, 'K x.. ... x.. ... | x.. ... x.. ...',
           'S ... x.. ... x.. | ... x.. ... x..'];
    else
      Result := [SWR, HPS, 'K x.. ... x.. ..x | x.. ..x x.. ...',
        'S ... x.. ... x.. | ... x.. ..x x..',
        'C@0.6 X.. ... ... ... | ... ... ... ...'];
    end;
end;

function BalladLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := [RQ, HPS, 'K x.. ... x.. ... | x.. ... x.. ...', CR12];
      1: Result := [SWR, HPS, 'K x.. ... ..o ... | x.. ... ..o ...',
           'S ... ..o ... ... | ... ..o ... ...', CR12];
    else
      Result := [SWR, HPS, 'K x.. ... ... ..x | x.. ... ... ..x',
        'S ... x.. ... x.. | ... x.. ... x..', CR12];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := [RQ, 'K x.. ... ... ... | ... ... ... ...'];
      1: Result := [RQ, HPS, 'SS ... ... ... x.. | ... ... ... ...'];
    else
      Result := [RQ, HPS, FEA, 'S ... ... ..o ... | ... ... ... ...'];
    end
  else
    case V of
      0: Result := [RQ, HPS, 'K x.. ... ... ... | ... ... ... ...'];
      1: Result := [RQ, HPS, FEA];
    else
      Result := [SWR, HPS, FEA, 'S ... ... ... ..o | ... ..o ... ...'];
    end;
end;

function LatinLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := [BOSSA_K, CLAVE, L_R8, 'C .... .... | X... ....'];
      1: Result := [BOSSA_K, CLAVE, L_R8, L_HP, 'C .... .... | X... ....'];
    else
      Result := ['K x.xx x.xx | x.xx x.xx', 'S x..x ..x. | ..x. x...',
        L_R8, 'C .... .... | X... ....'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... | x... ....', 'SS ..x. .... | ..x. ....', L_H8];
      1: Result := ['K x..x .... | x..x ....', CLAVE, L_HP];
    else
      Result := [BOSSA_K, CLAVE, L_H8, 'T1@0.5 .... .... | .... .xx.'];
    end
  else
    case V of
      0: Result := [BOSSA_K, CLAVE, L_H8];
      1: Result := [BOSSA_K, CLAVE, L_R8, L_HP];
    else
      Result := ['K x.xx x..x | x..x x.xx', CLAVE, L_R8, L_HP,
        'S@0.6 .... .g.. | .... ...g'];
    end;
end;

function FusionLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... ..x. x... ..x. | x... ..x. x... ..x.', S24, R8, CR16];
      1: Result := ['K x..x ..x. x... ..x. | x..x ..x. x..x ..x.', S24, H8, CR16];
    else
      Result := ['K x.xx ..x. x.xx ..x. | x.xx ..xx x.xx ..x.', S24, R8, CR16B,
        'S@0.6 ..g. .g.. ..g. .g.. | ..g. .g.. ..g. .g..'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... ..x. ....',
           'S .... .... x... .... | .... .... x... ....', R4];
      1: Result := ['K x... ..x. .... ..x. | x... ..x. .... ..x.',
           'SS .... x... .... x... | .... x... .... x...', H8];
    else
      Result := ['K x..x ..x. .x.. x.x. | x..x ..x. .x.. x.x.', S24, R8,
        'T1@0.5 .... .... .... .... | .... .... .... .xx.'];
    end
  else
    case V of
      0: Result := ['K x... ..x. .x.. ..x. | x... ..x. .x.. ....', S24, H8];
      1: Result := ['K x..x ..x. .x.. ..x. | x..x ..x. .x.. ....', S24, R8, HP24];
    else
      Result := ['K x..x ..x. .x.x ..x. | x..x ..x. .x.. .xx.', S24, R8, HP24,
        'S@0.5 ..g. .g.. ...g .... | .g.. ..g. .... .g..'];
    end;
end;

function ContemporaryLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... .... x... .... | x... .... x... ....', S24, R4, CR16];
      1: Result := ['K x..x ..x. x... ..x. | x..x ..x. x... ....', S24, R8, CR16B];
    else
      Result := ['K x.xx ..x. x.xx ..x. | x.xx ..x. x.xx .xx.', S24, R8, CR16B, HP24];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | .... .... x... ....',
           'SS .... .... x... .... | .... .... .... ....',
           'R x... .... x... .... | x... .... x... ....'];
      1: Result := ['K x... .... ..x. .... | x... .... ..x. ....',
           'S .... .... x... .... | .... .... x... ....', H8];
    else
      Result := ['K x..x .... ..x. ..x. | x... ..x. x... ....', S24, R8,
        'T1@0.5 .... .... .... .... | .... .... .... .xx.'];
    end
  else
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... .... ..x.',
           'SS .... .... x... .... | .... .... x... ....', R4];
      1: Result := ['K x... ..x. .... ..x. | x... .... ..x. ....',
           'S .... .... x... .... | .... .... x... ....', R8];
    else
      Result := ['K x..x ..x. ..x. .x.. | x... ..x. .x.. ..x.', S24, R8,
        'S@0.5 ...g .... ..g. .... | .g.. .... ...g ....', HP24];
    end;
end;

function JazzGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;
var
  V: Integer;
begin
  V := AVariant;
  if V < 0 then V := 0;
  if V > 2 then V := 2;
  case LowerCase(AStyle) of
    'bebop': Result := BebopLines(AKind, V);
    'hard_bop': Result := HardBopLines(AKind, V);
    'ballad': Result := BalladLines(AKind, V);
    'latin': Result := LatinLines(AKind, V);
    'fusion': Result := FusionLines(AKind, V);
    'contemporary': Result := ContemporaryLines(AKind, V);
  else
    Result := SwingLines(AKind, V);
  end;
end;

end.
