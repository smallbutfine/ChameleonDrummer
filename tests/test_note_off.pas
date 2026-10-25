program test_note_off;

{$mode objfpc}{$H+}

{ A note-off must never arrive after the next hit of the same pitch, and the
  single-pattern export must use the same 960 ticks per quarter note as a
  song. Run from the project root (needs the mappings folder). }

uses
  SysUtils, Classes, jsonparser, Kit, Pattern, DrumGenerator, MidiIO;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AText: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AText);
    Inc(Failures);
  end;
end;

type
  TNoteEvent = record
    Tick: Int64;
    IsOn: Boolean;
    Note: Byte;
  end;

{ Reads ppq and the note events of a format-0 file written by SaveSongMidi. }
function ReadNotes(const APath: string; out APpq: Integer): specialize TArray<TNoteEvent>;
var
  S: TMemoryStream;
  B: Byte;
  Status: Byte;
  Tick: Int64;
  Len, Pos: Int64;
  E: TNoteEvent;
  Count: Integer;

  function ReadVar: Int64;
  var
    V: Byte;
  begin
    Result := 0;
    repeat
      V := S.ReadByte;
      Result := (Result shl 7) or (V and $7F);
    until (V and $80) = 0;
  end;

begin
  S := TMemoryStream.Create;
  try
    S.LoadFromFile(APath);
    S.Position := 12;
    APpq := (S.ReadByte shl 8) or S.ReadByte;
    S.Position := 22;
    Tick := 0; Status := 0; Count := 0;
    SetLength(Result, 0);
    while S.Position < S.Size do
    begin
      Tick := Tick + ReadVar;
      B := S.ReadByte;
      if B = $FF then
      begin
        S.ReadByte;
        Len := ReadVar;
        S.Position := S.Position + Len;
        Continue;
      end;
      if (B and $80) <> 0 then
        Status := B
      else
        S.Position := S.Position - 1;
      E.Note := S.ReadByte;
      Pos := S.ReadByte;
      E.Tick := Tick;
      E.IsOn := ((Status and $F0) = $90) and (Pos > 0);
      SetLength(Result, Count + 1);
      Result[Count] := E;
      Inc(Count);
    end;
  finally
    S.Free;
  end;
end;

{ Number of note-offs that do not land exactly on the tick of the next note-on
  of the same pitch. The last hit of a pitch is not counted. }
function CountEarlyStops(const AEvents: specialize TArray<TNoteEvent>): Integer;
var
  OnTick: array[0..127] of Int64;
  Sounding: array[0..127] of Boolean;
  OffTick: array[0..127] of Int64;
  HasOff: array[0..127] of Boolean;
  I: Integer;
begin
  Result := 0;
  FillChar(Sounding, SizeOf(Sounding), 0);
  FillChar(HasOff, SizeOf(HasOff), 0);
  FillChar(OnTick, SizeOf(OnTick), 0);
  FillChar(OffTick, SizeOf(OffTick), 0);
  for I := 0 to High(AEvents) do
    if AEvents[I].IsOn then
    begin
      if HasOff[AEvents[I].Note] and (OffTick[AEvents[I].Note] <> AEvents[I].Tick) then
        Inc(Result);
      HasOff[AEvents[I].Note] := False;
      OnTick[AEvents[I].Note] := AEvents[I].Tick;
      Sounding[AEvents[I].Note] := True;
    end
    else if Sounding[AEvents[I].Note] then
    begin
      OffTick[AEvents[I].Note] := AEvents[I].Tick;
      HasOff[AEvents[I].Note] := True;
      Sounding[AEvents[I].Note] := False;
    end;
end;

function CountOverlaps(const AEvents: specialize TArray<TNoteEvent>): Integer;
var
  Open: array[0..127] of Boolean;
  I: Integer;
begin
  Result := 0;
  FillChar(Open, SizeOf(Open), 0);
  for I := 0 to High(AEvents) do
    if AEvents[I].IsOn then
    begin
      if Open[AEvents[I].Note] then
        Inc(Result);
      Open[AEvents[I].Note] := True;
    end
    else
      Open[AEvents[I].Note] := False;
end;

var
  Gen: TDrumGenerator;
  P: TPattern;
  Kick, Hat: TDrumInstrument;
  Events: specialize TArray<TNoteEvent>;
  Ppq, I: Integer;
begin
  Gen := TDrumGenerator.Create;
  try
    Gen.DrumKit := TDrumKit.FromKeymapName('gm');
    Kick := TInstrumentRegistry.Get('kick');
    Hat := TInstrumentRegistry.Get('hihat_closed_1_tip_closed_1_hit');

    { 32nd-note kick roll: each hit is only 120 ticks after the last one and
      must stop its predecessor. The hi-hat at 0.0 has no later hit of its
      own pitch and rings to the end. }
    P := TPattern.Create('roll');
    for I := 0 to 15 do
      P.AddBeat(I * 0.125, Kick, 100);
    P.AddBeat(0.0, Hat, 90);
    P.AddBeat(2.0, Hat, 90);
    Gen.SavePatternMidi(P, '_note_off_test.mid', 120);
    P.Free;

    Events := ReadNotes('_note_off_test.mid', Ppq);
    Check(Ppq = 960, Format('pattern export must use 960 ppq, got %d', [Ppq]));
    Check(CountOverlaps(Events) = 0, 'no note may still sound when the next hit of its pitch starts');
    Check(CountEarlyStops(Events) = 0,
      'a note rings until the next hit of the same pitch stops it');
    I := 0;
    for I := 0 to High(Events) do
      if Events[I].IsOn and (Events[I].Note = 35) then
        Break;
    Check(I <= High(Events), 'the kick roll must be in the file');
  finally
    Gen.Free;
    if FileExists('_note_off_test.mid') then
      DeleteFile('_note_off_test.mid');
  end;

  if Failures = 0 then
    WriteLn('PASS: note-off before the next same-pitch hit, pattern export at 960 ppq')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
