unit FunkGrooves;

{$mode objfpc}{$H+}

{ Funk grooves written as drum tabs (see TDrumTab in patterns_templates).

  Every style has three grooves per section kind (verse, chorus, bridge),
  ordered from light to heavy. The shuffle style uses a 12-step (triplet)
  grid, everything else 16 steps per bar. Ghost notes ('g') carry the
  feel: they sit on the 16ths around the backbeat.

  Hand rules the grooves respect (see LimbConstraints): snare, crashes and
  toms 1/3 are played with the right hand; hi-hat and ride with the left.
  A crash never shares a step with the snare, a ride never shares a step
  with the hi-hat, and no step has more than three hits. }

interface

uses
  SysUtils, patterns_templates;

{ Tab lines of one groove. Unknown styles fall back to 'classic'. }
function FunkGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;

implementation

const
  S24   = 'S .... x... .... x... | .... x... .... x...';
  SS24  = 'SS .... x... .... x... | .... x... .... x...';
  RS24  = 'RS .... X... .... X... | .... X... .... X...';
  H16   = 'H xoxo xoxo xoxo xoxo | xoxo xoxo xoxo xoxo';
  H8    = 'H x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  H4    = 'H x... x... x... x... | x... x... x... x...';
  R8    = 'R x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  CR1   = 'C X... .... .... .... | .... .... .... ....';
  CR11  = 'C X... .... .... .... | X... .... .... ....';
  { shuffle (12 steps) }
  SH_S  = 'S ... x.. ... x.. | ... x.. ... x..';
  SH_H  = 'H x.x x.x x.x x.x | x.x x.x x.x x.x';
  SH_G  = 'S@0.5 ..g ..g ..g ..g | ..g ..g ..g ..g';

function ClassicLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K X... ..x. .x.. .... | X... ..x. .... .x..', S24, H16, CR1];
      1: Result := ['K X... ..x. .x.. ..x. | X... ..x. .x.. ....', S24, R8, CR11,
           'S@0.5 ...g .... .g.. .... | ..g. .... .g.. ...g'];
      else
        Result := ['K X..x ..x. .x.. ..x. | X..x ..x. .x.x ..x.', S24, R8, CR11,
          'S@0.5 ...g .g.. .g.. ...g | ..g. .g.. .g.. ...g'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K X... .... .... .... | X... .... .... ....', SS24, H4];
      1: Result := ['K X... ..x. .... .... | X... .... ..x. ....', SS24, H8];
    else
      Result := ['K X... ..x. .x.. .... | X... ..x. .x.. ..x.', S24, H16];
    end
  else
    case V of
      0: Result := ['K X... .... ..x. .... | X... ..x. .... ....', S24, H16];
      1: Result := ['K X... ..x. .x.. .... | X... ..x. .... .x..', S24, H16,
           'S@0.4 ...g .... .g.. ...g | ..g. .... .g.. ....'];
    else
      Result := ['K X... ..x. .x.. ..x. | X... ..x. .x.. ....', S24,
        'H xoxo xoxo xoxo xo.o | xoxo xoxo xoxo xo.o',
        'HO .... .... .... ..x. | .... .... .... ..x.',
        'S@0.4 ...g .g.. .g.. ...g | ..g. .g.. .... ...g'];
    end;
end;

function PFunkLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K X..x ..x. .x.. ..x. | X..x ..x. .x.. ....', S24, H16, CR1];
      1: Result := ['K X.xx ..x. .x.x ..x. | X.xx ..x. .x.. xx..', S24, R8, CR11];
    else
      Result := ['K X.xx x.x. .x.x ..xx | X.xx x.x. .x.x xx..', S24, R8, CR11,
        'S@0.6 ...g .g.. ...g .... | ..g. .... .g.. ...g'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K X... .... .... .... | X... .... ..x. ....', SS24, H8];
      1: Result := ['K X..x .... ..x. .... | X..x .... ..x. ....', S24, H16];
    else
      Result := ['K X..x ..x. .x.. ..x. | X..x ..x. .x.x xx..', S24, H16,
        'T1@0.5 .... .... .... .... | .... .... .... ..xx'];
    end
  else
    case V of
      0: Result := ['K X... ..x. .... ..x. | X... ..x. .x.. ....', S24, H16];
      1: Result := ['K X..x ..x. .x.. ..x. | X..x ..x. .x.. .x..', S24, H16,
           'S@0.5 ...g .... .g.. .... | ..g. .... .g.. ...g'];
    else
      Result := ['K X..x ..x. .x.x ..x. | X.xx ..x. .x.. xx.x', S24, H16,
        'S@0.5 ...g .g.. ...g ..g. | ..g. .g.. .g.. ...g'];
    end;
end;

function ShuffleLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K X.. ... x.. ... | X.. ... x.. ..x', SH_S, SH_H, 'C X.. ... ... ... | ... ... ... ...'];
      1: Result := ['K X.. ..x x.. ... | X.. ..x x.. ..x', SH_S, SH_H, SH_G,
           'C X.. ... ... ... | X.. ... ... ...'];
    else
      Result := ['K X.. x.x x.. x.. | X.. x.x x.. x.x', SH_S,
        'R x.x x.x x.x x.x | x.x x.x x.x x.x', SH_G, 'C X.. ... ... ... | X.. ... ... ...'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K X.. ... ... ... | X.. ... ... ...', 'SS ... x.. ... x.. | ... x.. ... x..',
           'H x.. x.. x.. x.. | x.. x.. x.. x..'];
      1: Result := ['K X.. ... ..x ... | X.. ... ... ...', SH_S, 'H x.x x.x x.x x.x | x.x x.x x.x x.x'];
    else
      Result := ['K X.. ..x x.. ..x | X.. ..x x.. ..x', SH_S, SH_H, SH_G];
    end
  else
    case V of
      0: Result := ['K X.. ... x.. ... | X.. ... x.. ...', SH_S, SH_H];
      1: Result := ['K X.. ... x.. ..x | X.. ... x.. ...', SH_S, SH_H, 'S@0.5 ... ..g ... ... | ... ..g ... ..g'];
    else
      Result := ['K X.. ..x x.. ... | X.. ..x x.. ..x', SH_S, SH_H, SH_G];
    end;
end;

function NewOrleansLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... ..x. .... x... | x... ..x. .... x...',
           'S .... x..x ..x. x... | .... x..x ..x. x...', H8, CR1];
      1: Result := ['K x..x ..x. .x.. x... | x..x ..x. .x.. x...',
           'S .... x..x ..x. x... | .... x..x ..x. xx.x', R8, CR11];
    else
      Result := ['K x.xx ..x. .x.x x... | x.xx ..x. .x.x x.x.',
        'S ..x. x..x ..x. x.xx | ..x. x..x ..x. x.xx', R8, CR11];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... x... | x... .... .... ....',
           'SS .... x... .... x... | .... x... .... x...', H4];
      1: Result := ['K x... ..x. .... x... | x... ..x. .... ....',
           'S .... x..x .... x... | .... x..x .... x...', H8];
    else
      Result := ['K x..x ..x. .x.. x... | x..x ..x. .x.. x...',
        'S .... x..x ..x. x... | .... x..x ..x. x.xx', H8];
    end
  else
    case V of
      0: Result := ['K x... .... .... x... | x... ..x. .... ....',
           'S .... x... .... x... | .... x... .... x...', H8];
      1: Result := ['K x... ..x. .... x... | x... ..x. .... x...',
           'S .... x..x ..x. x... | .... x..x ..x. x...', H8];
    else
      Result := ['K x..x ..x. .x.. x... | x..x ..x. .x.. x.x.',
        'S ..x. x..x ..x. x..x | ..x. x..x ..x. x.xx', H8,
        'S@0.5 ...g .... .g.. .... | .... .... .... ....'];
    end;
end;

function FusionLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x..x ..x. x... ..x. | x..x ..x. x... ..x.', S24, R8, CR1];
      1: Result := ['K x.xx ..x. x.x. ..xx | x.xx ..x. x.x. ..x.', S24, R8, CR11,
           'S@0.5 ...g .g.. ...g .g.. | ..g. .g.. ...g .g..'];
    else
      Result := ['K x.xx x.x. x.xx ..xx | x.xx x.x. x.xx x.x.', S24,
        'R xxxx xxxx xxxx xxxx | xxxx xxxx xxxx xxxx', CR11,
        'S@0.5 ...g .g.. ...g .g.. | ..g. .g.. ...g .g..'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... ..x. ....', SS24, H4];
      1: Result := ['K x..x .... ..x. ..x. | x... ..x. .... ....', S24, H8];
    else
      Result := ['K x..x ..x. .x.x ..x. | x..x ..x. .x.. xx.x', S24, H16,
        'T3@0.5 .... .... .... .... | .... .... .... ..x.'];
    end
  else
    case V of
      0: Result := ['K x..x ..x. .x.. ..x. | x..x ..x. .x.. ....', S24, H16];
      1: Result := ['K x.xx ..x. .x.x ..x. | x..x ..x. .x.x ..xx', S24, H16,
           'S@0.5 ...g .g.. ...g .g.. | ..g. .g.. ...g ....'];
    else
      Result := ['K x.xx x.x. .x.x ..xx | x.xx ..x. .x.x x.x.', S24,
        'H xoxo xoxo xoxo xo.o | xoxo xoxo xoxo xo.o',
        'HO .... .... .... ..x. | .... .... .... ..x.',
        'S@0.5 ...g .g.. ...g .g.. | ..g. .g.. ...g .g..'];
    end;
end;

function MinimalLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K X... .... .... .... | X... .... ..x. ....', SS24, H8, CR1];
      1: Result := ['K X... ..x. .... ..x. | X... ..x. .... ....', S24, H8, CR1];
    else
      Result := ['K X..x ..x. .... ..x. | X..x ..x. .x.. ....', S24, H16, CR11];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K X... .... .... .... | .... .... .... ....', 'SS .... .... x... .... | .... .... x... ....', H4];
      1: Result := ['K X... .... .... .... | X... .... ..x. ....', SS24, H4];
    else
      Result := ['K X... ..x. .... .... | X... ..x. .... ..x.', SS24, H8];
    end
  else
    case V of
      0: Result := ['K X... .... .... .... | X... .... ..x. ....', SS24, H4];
      1: Result := ['K X... ..x. .... .... | X... .... ..x. ....', SS24, H8];
    else
      Result := ['K X... ..x. .... ..x. | X... .... ..x. ....', S24, H8,
        'S@0.5 ...g .... .... .... | .... ..g. .... ...g'];
    end;
end;

function HeavyLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K X..x ..x. X... ..x. | X..x ..x. X... ..x.', RS24, H8, CR1];
      1: Result := ['K X.xx ..x. X.x. ..x. | X.xx ..x. X.x. x.x.', RS24, R8, CR11];
    else
      Result := ['K X.xx x.x. X.xx ..x. | X.xx x.x. X.xx x.xx', RS24, R8, CR11];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K X... .... ..x. .... | X... .... ..x. ....', S24, H4];
      1: Result := ['K X..x .... X... .... | X..x .... X... ....', S24, H8];
    else
      Result := ['K X..x ..x. X.x. ..x. | X..x ..x. X.x. xxxx', S24, H8, CR1];
    end
  else
    case V of
      0: Result := ['K X..x ..x. .... ..x. | X..x ..x. .... ....', S24, H8];
      1: Result := ['K X..x ..x. .x.. ..x. | X..x ..x. .x.. ..x.', S24, H16];
    else
      Result := ['K X.xx ..x. .x.x ..x. | X.xx ..x. .x.. x.x.', S24, H16,
        'S@0.5 ...g .... .g.. .... | ..g. .... .g.. ...g'];
    end;
end;

function FunkGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;
var
  V: Integer;
begin
  V := AVariant;
  if V < 0 then V := 0;
  if V > 2 then V := 2;
  case LowerCase(AStyle) of
    'pfunk': Result := PFunkLines(AKind, V);
    'shuffle': Result := ShuffleLines(AKind, V);
    'new_orleans': Result := NewOrleansLines(AKind, V);
    'fusion': Result := FusionLines(AKind, V);
    'minimal': Result := MinimalLines(AKind, V);
    'heavy': Result := HeavyLines(AKind, V);
  else
    Result := ClassicLines(AKind, V);
  end;
end;

end.
