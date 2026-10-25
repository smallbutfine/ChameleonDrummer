unit time_signature;

{$mode objfpc}{$H+}

{ Time signature value object. }

interface

uses
  Classes, SysUtils, Generics.Collections;

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

const
  { The meters the engine plays: any numerator from 2 to 32 over 2, 4, 8 or 16
    (2/4, 3/4, 5/4, 7/8, 9/8, 11/8, 13/8, 15/16 ...). }
  MIN_METER_NUMERATOR = 2;
  MAX_METER_NUMERATOR = 32;

{ "7/8" -> 7 and 8. False when the text is not two whole numbers around a
  slash. The numbers are not range-checked here, see MeterProblem. }
function TryParseMeter(const AText: string; out ANum, ADen: Integer): Boolean;

{ '' when the engine can play the meter, else what is wrong with it. }
function MeterProblem(ANum, ADen: Integer): string;

type
  TMeterGroups = array of Integer;

{ How a drummer counts one bar: the sizes of its beat groups, in units of
  1/ADen. 7/8 is 3+2+2, 9/8 3+3+3, 5/4 3+2, 11/8 3+3+3+2, 13/8 3+3+3+2+2;
  2/4, 3/4 and 4/4 count every quarter. The groups of an irregular bar start
  with the threes. }
function MeterGrouping(ANum, ADen: Integer): TMeterGroups;

{ Where a drummer puts the snare in a bar, in quarter notes from the bar
  start: beats 2 and 4 of 4/4, beat 2 of 2/4, 2 and 3 of 3/4, and for the
  irregular meters the start of every beat group after the first (5/4 = 3+2:
  the snare on the 4th beat; 7/8 = 3+2+2: on the 4th and 6th eighth). }
function MeterBackbeats(ANum, ADen: Integer): specialize TArray<Double>;

{ Length of one unit (1/ADen) in quarter notes. }
function MeterUnitQuarters(ADen: Integer): Double;

{ '7/8' }
function MeterName(ANum, ADen: Integer): string;

implementation

function OnlyDigits(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9']) then
      Exit(False);
end;

function TryParseMeter(const AText: string; out ANum, ADen: Integer): Boolean;
var
  P: Integer;
  T, A, B: string;
begin
  ANum := 0;
  ADen := 0;
  T := Trim(AText);
  P := Pos('/', T);
  Result := False;
  if P < 2 then
    Exit;
  A := Trim(Copy(T, 1, P - 1));
  B := Trim(Copy(T, P + 1, MaxInt));
  if (Length(A) > 4) or (Length(B) > 4) or not OnlyDigits(A) or not OnlyDigits(B) then
    Exit;
  ANum := StrToInt(A);
  ADen := StrToInt(B);
  Result := True;
end;

function MeterProblem(ANum, ADen: Integer): string;
begin
  Result := '';
  if (ANum < MIN_METER_NUMERATOR) or (ANum > MAX_METER_NUMERATOR) then
    Result := Format('the numerator must be between %d and %d, not %d',
      [MIN_METER_NUMERATOR, MAX_METER_NUMERATOR, ANum])
  else if not (ADen in [2, 4, 8, 16]) then
    Result := Format('the denominator must be 2, 4, 8 or 16, not %d', [ADen]);
end;

function MeterGrouping(ANum, ADen: Integer): TMeterGroups;
var
  I, Threes, Rest, N: Integer;
begin
  Result := nil;
  if (ANum < 1) then
    Exit;
  { Simple meters: every quarter (or half) is a beat. }
  if (ADen in [2, 4]) and (ANum <= 4) then
  begin
    SetLength(Result, ANum);
    for I := 0 to ANum - 1 do
      Result[I] := 1;
    Exit;
  end;
  Threes := ANum div 3;
  Rest := ANum mod 3;
  if Rest = 1 then
  begin
    { a three gives way to two twos: 4 = 2+2, 7 = 3+2+2, 10 = 3+3+2+2 }
    Dec(Threes);
    N := Threes + 2;
  end
  else if Rest = 2 then
    N := Threes + 1
  else
    N := Threes;
  SetLength(Result, N);
  for I := 0 to Threes - 1 do
    Result[I] := 3;
  if Rest = 1 then
  begin
    Result[Threes] := 2;
    Result[Threes + 1] := 2;
  end
  else if Rest = 2 then
    Result[Threes] := 2;
end;

function MeterBackbeats(ANum, ADen: Integer): specialize TArray<Double>;
var
  Groups: TMeterGroups;
  G, Start: Integer;
  UnitQ: Double;
begin
  Result := nil;
  if (ANum = 4) and (ADen = 4) then
  begin
    SetLength(Result, 2);
    Result[0] := 1.0;
    Result[1] := 3.0;
    Exit;
  end;
  Groups := MeterGrouping(ANum, ADen);
  UnitQ := MeterUnitQuarters(ADen);
  Start := 0;
  for G := 0 to High(Groups) do
  begin
    if G > 0 then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Start * UnitQ;
    end;
    Inc(Start, Groups[G]);
  end;
end;

function MeterUnitQuarters(ADen: Integer): Double;
begin
  if ADen <= 0 then
    Result := 1.0
  else
    Result := 4.0 / ADen;
end;

function MeterName(ANum, ADen: Integer): string;
begin
  Result := IntToStr(ANum) + '/' + IntToStr(ADen);
end;

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
