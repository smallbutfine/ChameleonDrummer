unit time_signature;

{$mode objfpc}{$H+}

{ Time signature value object. }

interface

uses
  Classes, SysUtils;

type

{ TimeSignature â€” time signature representation. }
TTimeSignature = class
  Numerator: Integer;
  Denominator: Integer;
private
  function GetBeatsPerBar: double;
public
  constructor Create(ANumerator, ADenominator: Integer);
  destructor Destroy; override;
  procedure Validate;
  property BeatsPerBar: double read GetBeatsPerBar;
end;

implementation

{ ── TimeSignature ─────────────────────────────── }

constructor TTimeSignature.Create(ANumerator, ADenominator: Integer);
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

function TTimeSignature.GetBeatsPerBar: double;
begin
  Result := Numerator * (4.0 / Denominator);
end;

destructor TTimeSignature.Destroy;
begin
  inherited Destroy;
end;

end.
