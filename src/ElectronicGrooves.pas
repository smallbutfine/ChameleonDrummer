unit ElectronicGrooves;

{$mode objfpc}{$H+}

{ Electronic grooves written as drum tabs (see TDrumTab in patterns_templates).

  Every style has three grooves per section kind (verse, chorus = drop,
  bridge = breakdown), ordered from light to heavy. All styles use 16 steps
  per bar. The rimshot stands in for the clap.

  Hand rules the grooves respect (see LimbConstraints): rimshot/snare,
  crashes and toms 1/3 are right hand; closed and open hi-hat and ride are
  left hand. A closed and an open hat never share a step, a crash never
  shares a step with the rimshot, and no step has more than three hits. }

interface

uses
  SysUtils, patterns_templates;

{ Tab lines of one groove. Unknown styles fall back to 'house'. }
function ElectronicGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;

implementation

const
  FOUR   = 'K x... x... x... x... | x... x... x... x...';
  CLAP   = 'RS .... X... .... X... | .... X... .... X...';
  OFFHAT = 'HO ..x. ..x. ..x. ..x. | ..x. ..x. ..x. ..x.';
  GHOSTH = 'H@0.5 .o.o .o.o .o.o .o.o | .o.o .o.o .o.o .o.o';
  ONHAT  = 'H o... o... o... o... | o... o... o... o...';
  H16    = 'H xoxo xoxo xoxo xoxo | xoxo xoxo xoxo xoxo';
  H8     = 'H x.x. x.x. x.x. x.x. | x.x. x.x. x.x. x.x.';
  H4     = 'H x... x... x... x... | x... x... x... x...';
  CR1    = 'C X... .... .... .... | .... .... .... ....';
  CR11   = 'C X... .... .... .... | X... .... .... ....';
  SNARE_DNB = 'S .... x... .... x... | .... x... .... x...';

function HouseLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := [FOUR, CLAP, OFFHAT, ONHAT, CR1];
      1: Result := [FOUR, CLAP, OFFHAT, GHOSTH, CR11];
    else
      Result := [FOUR, CLAP, OFFHAT, GHOSTH, CR11,
        'RS .... .... .... ..x. | .... .... .... .xx.'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['RS .... .... .... .... | .... X... .... ....', H4];
      1: Result := ['K x... .... .... .... | x... .... .... ....', CLAP, H8];
    else
      Result := ['K x... .... x... .... | x... .... x... ....', CLAP, H8,
        'RS@0.5 .... .... .... .... | .... .... xxxx xxxx'];
    end
  else
    case V of
      0: Result := [FOUR, CLAP, OFFHAT];
      1: Result := [FOUR, CLAP, OFFHAT, ONHAT];
    else
      Result := [FOUR, CLAP, OFFHAT, GHOSTH,
        'RS .... .... .... .... | .... .... .... ...x'];
    end;
end;

function TechnoLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := [FOUR, OFFHAT, ONHAT, CR1];
      1: Result := [FOUR, CLAP, OFFHAT, GHOSTH, CR11];
    else
      Result := [FOUR, CLAP, OFFHAT, GHOSTH, CR11,
        'RS .... .... .... .... | .... .... .... xxxx'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... .... ....', H4];
      1: Result := ['K x... .... x... .... | x... .... x... ....', OFFHAT];
    else
      Result := [FOUR, OFFHAT, 'RS@0.5 .... .... .... .... | .... .... xx.x xxxx'];
    end
  else
    case V of
      0: Result := [FOUR, OFFHAT];
      1: Result := [FOUR, OFFHAT, ONHAT];
    else
      Result := [FOUR, OFFHAT, GHOSTH,
        'RS .... .... .... .... | .... .... .... ...x'];
    end;
end;

function DrumAndBassLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... ..x. ....', SNARE_DNB, H8, CR1];
      1: Result := ['K x... .... ..x. .x.. | x... .... ..x. ....', SNARE_DNB, H16, CR11,
           'S@0.5 ...g .... ..g. .... | .... ...g ..g. ....'];
    else
      Result := ['K x.x. .... ..x. .x.. | x... ..x. ..x. .x..', SNARE_DNB, H16, CR11,
        'S@0.5 ...g ..g. ..g. ...g | ..g. ...g ..g. ...g'];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | x... .... .... ....', 'SS .... .... x... .... | .... .... x... ....', H4];
      1: Result := ['K x... .... ..x. .... | x... .... .... ..x.', SNARE_DNB, H8];
    else
      Result := ['K x... .... ..x. .... | x... .... ..x. ....', SNARE_DNB, H8,
        'S@0.5 .... .... .... .... | .... .... xxxx xxxx'];
    end
  else
    case V of
      0: Result := ['K x... .... ..x. .... | x... .... ..x. ....', SNARE_DNB, H8];
      1: Result := ['K x... .... ..x. .x.. | x... .... ..x. ....', SNARE_DNB, H8,
           'S@0.5 ...g .... ..g. .... | .... ...g .... ....'];
    else
      Result := ['K x.x. .... ..x. .x.. | x... .x.. ..x. ....', SNARE_DNB, H16,
        'S@0.5 ...g .... ..g. ...g | .... ...g ..g. ....'];
    end;
end;

function DubstepLines(const AKind: string; V: Integer): TTabLines;
begin
  Result := nil;
  if AKind = 'chorus' then
    case V of
      0: Result := ['K x... .... .... ..x. | x... .... .... ....',
           'RS .... .... X... .... | .... .... X... ....', H8, CR1];
      1: Result := ['K x... .... ..x. .... | x... .... .... ..x.',
           'RS .... .... X... .... | .... .... X... ....', H16, CR11];
    else
      Result := ['K x..x .... ..x. ..x. | x... ..x. .... x...',
        'RS .... .... X... .... | .... .... X... ..x.', H16, CR11];
    end
  else if AKind = 'bridge' then
    case V of
      0: Result := ['K x... .... .... .... | .... .... .... ....', H4];
      1: Result := ['K x... .... .... .... | x... .... .... ....',
           'RS .... .... .... .... | .... .... X... ....', H8];
    else
      Result := ['K x... .... ..x. .... | x... .... ..x. ....',
        'RS .... .... X... .... | .... .... X... ....', H8,
        'RS@0.5 .... .... .... .... | .... .... .... xxxx'];
    end
  else
    case V of
      0: Result := ['K x... .... .... .... | x... .... ..x. ....',
           'RS .... .... X... .... | .... .... X... ....', H8];
      1: Result := ['K x... .... .... ..x. | x... .... ..x. ....',
           'RS .... .... X... .... | .... .... X... ....', H8,
           'S@0.5 .... ...g .... .... | .... .... ...g ....'];
    else
      Result := ['K x..x .... ..x. .... | x... ..x. .... ..x.',
        'RS .... .... X... .... | .... .... X... ....', H16];
    end;
end;

function ElectronicGrooveLines(const AStyle, AKind: string; AVariant: Integer): TTabLines;
var
  V: Integer;
begin
  V := AVariant;
  if V < 0 then V := 0;
  if V > 2 then V := 2;
  case LowerCase(AStyle) of
    'techno': Result := TechnoLines(AKind, V);
    'drum_and_bass': Result := DrumAndBassLines(AKind, V);
    'dubstep': Result := DubstepLines(AKind, V);
  else
    Result := HouseLines(AKind, V);
  end;
end;

end.
