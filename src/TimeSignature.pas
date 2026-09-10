unit TimeSignature;

{$mode objfpc}{$H+}

{ Time signature value object. }

interface

type

{ TimeSignature â€” time signature representation. }
TTimeSignature = record
  Numerator: Integer;
  Denominator: Integer;
public
  constructor Create(ANumerator, ADenominator: Integer = 4);
  procedure Validate;
  property BeatsPerBar: float read GetBeatsPerBar;
private
  function GetBeatsPerBar: float;
end;

implementation

{ â”€â”€ TimeSignature â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TTimeSignature.Create(ANumerator, ADenominator: Integer = 4);
begin
  Numerator := ANumerator;
  Denominator := ADenominator;
  Validate;
end;

procedure TTimeSignature.Validate;
var
  D: Integer;
begin
  if Numerator <= 0 then
    raise Exception.CreateFmt('Time signature numerator must be positive, got %d', [Numerator]);

  D := Denominator;
  if (D <= 0) or ((D and (D - 1)) <> 0) then
    raise Exception.CreateFmt(
      'Time signature denominator must be a positive power of two (1, 2, 4, 8, 16, ...), got %d',
      [Denominator]);
end;

function TTimeSignature.GetBeatsPerBar: float;
begin
  Result := Numerator * (4.0 / Denominator);
end;

end.
