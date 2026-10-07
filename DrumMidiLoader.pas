unit DrumMidiLoader;
{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

type
  TDrumEvent = record
    AbsoluteTick: QWord; // Zeitpunkt in Ticks
    Note: Byte;          // Die Drum-ID (z.B. 36=Kick)
    Velocity: Byte;      // Anschlagstärke
  end;
  PDrumEvent = ^TDrumEvent;

  { TMidiDrumLoader liest NUR Kanal 10 aus Standard MIDI Files (Format 0 & 1) }
  TMidiDrumLoader = class
  private
    class function ReadVarLen(Stream: TStream): LongWord;
    class function Swap32(val: LongWord): LongWord;
    class function Swap16(val: Word): Word;
  public
    class function LoadDrums(const FileName: string; TargetList: TList): Boolean;
  end;

implementation

class function TMidiDrumLoader.Swap32(val: LongWord): LongWord;
begin
  Result := ((val shl 24) or ((val shl 8) and $FF0000) or ((val shr 8) and $FF00) or (val shr 24));
end;

class function TMidiDrumLoader.Swap16(val: Word): Word;
begin
  Result := ((val shl 8) or (val shr 8));
end;

class function TMidiDrumLoader.ReadVarLen(Stream: TStream): LongWord;
var b: Byte;
begin
  Result := 0;
  repeat
    Stream.Read(b, 1);
    Result := (Result shl 7) or (b and $7F);
  until (b and $80) = 0;
end;

class function TMidiDrumLoader.LoadDrums(const FileName: string; TargetList: TList): Boolean;
var
  FS: TFileStream;
  HeaderID, TrackID: array[0..3] of Char;
  HdrLen, TrkLen, NextTrk: LongWord;
  Format, NumTracks, Division: Word;
  i: Integer;
  Delta, CurTick: QWord;
  Status, B, LastStatus: Byte;
  NewEvent: PDrumEvent;
begin
  Result := False;
  if not FileExists(FileName) then Exit;
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    // 1. Header lesen
    FS.Read(HeaderID, 4);
    if HeaderID <> 'MThd' then Exit;
    FS.Read(HdrLen, 4); // Meist 6
    FS.Read(Format, 2);
    FS.Read(NumTracks, 2);
    FS.Read(Division, 2);
    FS.Seek(Swap32(HdrLen) - 6, soFromCurrent); // Rest-Header überspringen

    for i := 1 to Swap16(NumTracks) do begin
      FS.Read(TrackID, 4);
      FS.Read(TrkLen, 4);
      TrkLen := Swap32(TrkLen);
      NextTrk := FS.Position + TrkLen;
      CurTick := 0;
      LastStatus := 0;

      while FS.Position < NextTrk do begin
        Delta := ReadVarLen(FS);
        CurTick := CurTick + Delta;
        FS.Read(Status, 1);

        // Running Status Handling
        if Status < $80 then begin
          B := Status;
          Status := LastStatus;
          FS.Seek(-1, soFromCurrent); // Zurück, damit B später gelesen wird
        end else LastStatus := Status;

        case (Status and $F0) of
          $80, $90: begin // Note Off / Note On
            B := 0; FS.Read(B, 1); // Note
            NewEvent := nil;
            // FILTER: Nur Kanal 10 (Status $99 oder $89)
            if (Status and $0F) = 9 then begin
              New(NewEvent);
              NewEvent^.AbsoluteTick := CurTick;
              NewEvent^.Note := B;
              FS.Read(NewEvent^.Velocity, 1);
              // Nur Note-On mit Velocity > 0 als echten Hit werten
              if ((Status and $F0) = $90) and (NewEvent^.Velocity > 0) then
                TargetList.Add(NewEvent)
              else
                Dispose(NewEvent);
            end else FS.Seek(1, soFromCurrent); // Velocity überspringen
          end;
          $A0, $B0, $E0: FS.Seek(2, soFromCurrent);
          $C0, $D0: FS.Seek(1, soFromCurrent);
          $F0: begin // System / Meta Events
            if Status = $FF then begin
              FS.Read(B, 1); // Type
              FS.Seek(ReadVarLen(FS), soFromCurrent); // Skip Meta Data
            end else if Status = $F0 then
              FS.Seek(ReadVarLen(FS), soFromCurrent);
          end;
        end;
      end;
      FS.Position := NextTrk; // Sicherstellen, dass wir nicht verrutschen
    end;
    Result := True;
  finally
    FS.Free;
  end;
end;

end.
