unit MidiIO;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { Erweiterte Drum-Standards für präzises Remapping }
  TMappingType = (mapGM, mapAD2, mapGGD, mapEZD);

  { Einzelnes MIDI-Event mit absoluter Zeitbasis }
  TMidiEvent = record
    DeltaTick: Int64; 
    Status: Byte;    
    Note: Byte;      
    Velocity: Byte;  
  end;

  TMidiEventArray = array of TMidiEvent;

  { Resultat des Ladevorgangs inkl. der neuen Heuristik-Scores }
  TMidiLoadResult = record
    Events: TMidiEventArray;
    PPQ: Integer;              
    FileBPM: Integer;          
    HeuristicGuess: TMappingType; 
  end;

  TMidiIO = class
  private
    class function Swap16(val: Word): Word;
    class function Swap32(val: Cardinal): Cardinal;
    class function ReadVLQ(Stream: TStream): Int64;
    class procedure WriteVLQ(Stream: TStream; Value: Int64);
    class procedure SortEvents(var Events: TMidiEventArray);
  public
    class function LoadMidi(const FileName: string): TMidiLoadResult;
class procedure SaveMidi(
  const FileName: string; 
  const Events: TMidiEventArray; 
  PPQ: Integer;
  BPM: Integer { <-- Dieser Parameter muss hier auch rein! }
);
  end;

implementation

class function TMidiIO.Swap16(val: Word): Word;
begin
  Result := ((val and $FF) shl 8) or ((val and $FF00) shr 8);
end;

class function TMidiIO.Swap32(val: Cardinal): Cardinal;
begin
  Result := ((val and $FF) shl 24) or 
            ((val and $FF00) shl 8) or 
            ((val and $FF0000) shr 8) or 
            ((val and $FF000000) shr 24);
end;

class function TMidiIO.ReadVLQ(Stream: TStream): Int64;
var
  b: Byte;
begin
  Result := 0;
  repeat
    if Stream.Read(b, 1) = 0 then break;
    Result := (Result shl 7) or (b and $7F);
  until (b and $80) = 0;
end;

class procedure TMidiIO.WriteVLQ(Stream: TStream; Value: Int64);
var
  Buffer: Cardinal;
begin
  Buffer := Value and $7F;
  while (Value > $7F) do 
  begin
    Value := Value shr 7;
    Buffer := (Buffer shl 8) or $80 or (Value and $7F);
  end;
  repeat
    Stream.Write(Buffer, 1);
    if (Buffer and $80) <> 0 then Buffer := Buffer shr 8 else break;
  until False;
end;

class procedure TMidiIO.SortEvents(var Events: TMidiEventArray);
var
  i, j: Integer;
  temp: TMidiEvent;
begin
  if Length(Events) < 2 then Exit;
  for i := High(Events) downto 0 do
    for j := 0 to i - 1 do
      if Events[j].DeltaTick > Events[j + 1].DeltaTick then 
      begin
        temp := Events[j];
        Events[j] := Events[j + 1];
        Events[j + 1] := temp;
      end;
end;

class function TMidiIO.LoadMidi(const FileName: string): TMidiLoadResult;
var
  FS: TFileStream;
  Header: array[0..3] of Char;
  ChunkSize: Cardinal;
  Delta, AbsoluteTick, StartPos, TempoMicros: Int64;
  uStatus, uLastStatus, uMetaType, uNote, uVel, uReadByte: Byte; 
  Division: Word;
  ScoreAD2, ScoreGGD, ScoreEZD: Integer;
begin
  { Grundwerte initialisieren }
  uReadByte := 0; uStatus := 0; uLastStatus := 0; uMetaType := 0;
  uNote := 0; uVel := 0;
  ScoreAD2 := 0; ScoreGGD := 0; ScoreEZD := 0;
  
  Result.Events := nil;
  Result.PPQ := 480;
  Result.FileBPM := 120; 
  Result.HeuristicGuess := mapGM;

  if not FileExists(FileName) then Exit;
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    { 1. MIDI Header }
    if (FS.Read(Header, 4) < 4) or (Header <> 'MThd') then Exit;
    FS.Seek(8, soFromCurrent);
    FS.Read(Division, 2);
    Result.PPQ := Swap16(Division);

    { 2. Track Scanning }
    while (FS.Position < FS.Size - 8) do 
    begin
      if FS.Read(Header, 4) < 4 then break;
      FS.Read(ChunkSize, 4);
      ChunkSize := Swap32(ChunkSize);
      StartPos := FS.Position;

      if Header = 'MTrk' then 
      begin
        AbsoluteTick := 0; uLastStatus := 0;
        while (FS.Position < StartPos + ChunkSize) do 
        begin
          Delta := ReadVLQ(FS);
          AbsoluteTick := AbsoluteTick + Delta;
          
          if FS.Read(uReadByte, 1) = 0 then break;

          { --- RUNNING STATUS LOGIK (FIXED) --- }
          if uReadByte >= $80 then 
          begin
            uStatus := uReadByte;
            if uReadByte < $F0 then uLastStatus := uReadByte;
          end else 
          begin
            uStatus := uLastStatus;
            { Byte uReadByte ist bereits Teil der Daten, also Zeiger eins zurück! }
            FS.Seek(-1, soFromCurrent); 
          end;

          { --- EVENT VERARBEITUNG --- }
          if (uStatus >= $90) and (uStatus <= $9F) then { Note-On }
          begin
            FS.Read(uNote, 1);
            FS.Read(uVel, 1);
            
            { Heuristik-Punkte für Mapping }
            if uNote in [1, 16..19, 91..110] then Inc(ScoreEZD);
            if uNote in [60..75] then Inc(ScoreAD2);
            if uNote in [12..14] then Inc(ScoreGGD);

            { Filter: Nur Kanal 10 (Drums) und Velocity > 0 }
            if ((uStatus and $0F) = 9) and (uVel > 0) then 
            begin
              SetLength(Result.Events, Length(Result.Events) + 1);
              with Result.Events[High(Result.Events)] do
              begin
                DeltaTick := AbsoluteTick;
                Status := uStatus;
                Note := uNote;
                Velocity := uVel;
              end;
            end;
          end 
          else if (uStatus >= $80) and (uStatus <= $EF) then 
          begin
            { Andere Voice-Messages (Program Change etc.) überspringen }
            if (uStatus in [$C0..$DF]) then FS.Seek(1, soFromCurrent) 
            else FS.Seek(2, soFromCurrent);
          end 
          else if uStatus = $FF then { META EVENT }
          begin
            FS.Read(uMetaType, 1);
            Delta := ReadVLQ(FS); { Länge des Meta-Blocks }
            
            if uMetaType = $51 then { SET TEMPO EVENT }
            begin
              TempoMicros := 0;
              FS.Read(uReadByte, 1); TempoMicros := uReadByte shl 16;
              FS.Read(uReadByte, 1); TempoMicros := TempoMicros or (uReadByte shl 8);
              FS.Read(uReadByte, 1); TempoMicros := TempoMicros or uReadByte;
              if TempoMicros > 0 then 
                Result.FileBPM := Round(60000000 / TempoMicros);
            end 
            else FS.Seek(Delta, soFromCurrent); { Andere Meta-Daten überspringen }
          end 
          else if uStatus in [$F0, $F7] then 
          begin
            { System Exclusive Events überspringen }
            FS.Seek(ReadVLQ(FS), soFromCurrent);
          end;
        end;
      end;
      FS.Position := StartPos + ChunkSize;
    end;

    { 3. Finale Mapping Entscheidung }
    if Length(Result.Events) > 0 then 
    begin
      if (ScoreEZD > ScoreAD2) and (ScoreEZD > ScoreGGD) then Result.HeuristicGuess := mapEZD
      else if (ScoreAD2 > ScoreGGD) then Result.HeuristicGuess := mapAD2
      else if (ScoreGGD > 0) then Result.HeuristicGuess := mapGGD;
      
      SortEvents(Result.Events);
    end;
    
  finally FS.Free; end;
end;

{ --- Geänderte Signatur: BPM muss nun mit übergeben werden --- }
class procedure TMidiIO.SaveMidi(const FileName: string; const Events: TMidiEventArray; PPQ: Integer; BPM: Integer);
var 
  FS: TFileStream; 
  i: Integer; 
  LastTick, TrackStartPos, TrackEndPos: Int64;
  TempPPQ: Word;
  TrackSize, MicroSecondsPerBeat: Cardinal;
  b1, b2, b3: Byte;
  { Hilfsvariablen für Fix-Werte }
  mZero, mFF, mTempo, mLen3, mEnd: Byte;
begin
  { Fix-Werte initialisieren }
  mZero := 0; mFF := $FF; mTempo := $51; mLen3 := 3; mEnd := $2F;

  LastTick := 0;
  if BPM <= 0 then BPM := 120;
  MicroSecondsPerBeat := 60000000 div BPM;

  b1 := Byte(MicroSecondsPerBeat shr 16);
  b2 := Byte(MicroSecondsPerBeat shr 8);
  b3 := Byte(MicroSecondsPerBeat);

  FS := TFileStream.Create(FileName, fmCreate);
  try
    { MThd }
    FS.Write('MThd', 4);
    TrackSize := Swap32(6); 
    FS.Write(TrackSize, 4);
    TempPPQ := 0; { Format 0 }
    FS.Write(TempPPQ, 2);
    TempPPQ := Swap16(1); { 1 Track }
    FS.Write(TempPPQ, 2);
    TempPPQ := Swap16(Word(PPQ));
    FS.Write(TempPPQ, 2);

    { MTrk }
    FS.Write('MTrk', 4);
    TrackStartPos := FS.Position; 
    TrackSize := 0;
    FS.Write(TrackSize, 4); 
    
    { Tempo Meta Event }
    FS.Write(mZero, 1);       
    FS.Write(mFF, 1);     
    FS.Write(mTempo, 1);      
    FS.Write(mLen3, 1);       
    FS.Write(b1, 1);
    FS.Write(b2, 1);
    FS.Write(b3, 1);

    { Events }  
    for i := 0 to High(Events) do
    begin
      WriteVLQ(FS, Max(0, Events[i].DeltaTick - LastTick));
      FS.Write(Events[i].Status, 1);
      FS.Write(Events[i].Note, 1);  
      FS.Write(Events[i].Velocity, 1);
      LastTick := Events[i].DeltaTick;
    end;
    
    { End of Track: 00 FF 2F 00 }
    FS.Write(mZero, 1);
    FS.Write(mFF, 1);
    FS.Write(mEnd, 1);
    FS.Write(mZero, 1);

    { Track-Größe finalisieren }
    TrackEndPos := FS.Position;
    TrackSize := Swap32(Cardinal(TrackEndPos - TrackStartPos - 4));
    FS.Seek(TrackStartPos, soFromBeginning);
    FS.Write(TrackSize, 4); 
  finally 
    FS.Free; 
  end;
end;

end.
