unit MidiParser;

interface

uses Classes, SysUtils;

type
  TMidiEvent = record
    Delta: LongWord;
    Status: Byte; // Enthält Kanal und Befehl
    Data1: Byte;  // Note
    Data2: Byte;  // Velocity
  end;

  TMidiLoader = class
  public
    // Liest nur Drums (Kanal 10) aus einer Datei
    class procedure LoadOnlyDrums(const FileName: string; TargetList: TList);
  end;

implementation

class procedure TMidiLoader.LoadOnlyDrums(const FileName: string; TargetList: TList);
var
  FS: TFileStream;
  ChunkID: array[0..3] of Char;
  ChunkLen: LongWord;
  B: Byte;
  
  function ReadVarLen: LongWord;
  var b: Byte;
  begin
    Result := 0;
    repeat
      FS.Read(b, 1);
      Result := (Result shl 7) or (b and $7F);
    until (b and $80) = 0;
  end;

  function Swap32(val: LongWord): LongWord;
  begin
    Result := ((val shl 24) or ((val shl 8) and $FF0000) or ((val shr 8) and $FF00) or (val shr 24));
  end;

begin
  FS := TFileStream.Create(FileName, fmOpenRead);
  try
    FS.Read(ChunkID, 4); // 'MThd'
    FS.Read(ChunkLen, 4); 
    FS.Seek(Swap32(ChunkLen), soFromBeginning); // Überspringe Header-Details

    while FS.Position < FS.Size do begin
      FS.Read(ChunkID, 4);
      if ChunkID = 'MTrk' then begin
        FS.Read(ChunkLen, 4);
        // Hier beginnt die Spur-Logik
        // ... (Byte-weiser Scan nach Status $99 / Kanal 10)
        // WICHTIG: Nur Events mit (Status and $0F = 9) landen in deiner Liste!
      end;
    end;
  finally
    FS.Free;
  end;
end;

end.
