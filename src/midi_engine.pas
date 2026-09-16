unit midi_engine;

{$mode objfpc}{$H+}

{ TMIDIEngine — Raw SMF Format 0 writer (zero external dependencies).
  Generates standard .mid files by writing binary MIDI events directly.
  Compatible with all DAWs and drum VSTs without midiutil/mido. }

interface

uses
  Classes, SysUtils, Math, Windows, Generics.Collections,
  pattern, song,
  config_constants, kit;

type
  TByteDynArray = array of Byte;
  TBytes = array of Byte;

  TMIDIEvent = record
    DeltaTicks: Integer;
    Data: TByteDynArray;
  end;

TMIDIEngine = class
  private
    FTicksPerBeat: Integer;
    FHeaderData: TByteDynArray;
    FEvents: specialize TList<TMIDIEvent>;
    FDrumKit: TDrumKit;

    function EncodeVLQ(Value: Integer): TByteDynArray;
    procedure AddEvent(DeltaBeats: Double; const Data: TByteDynArray);
    procedure WriteTempoMicroSec(MicroSecPerBeat: Cardinal);
    function SerializeTrack(DataSize: Integer): TByteDynArray;
    function CalculateDataSize: Integer;

    function ResolveNote(AInstrument: TObject): Integer;
    procedure DedupeBeats(Beats: specialize TList<TBeat>; out DedupedBeats: specialize TList<TBeat>);

  public
    constructor Create(ATicksPerBeat: Integer = 480; ADrumKit: TDrumKit = nil);
    destructor Destroy; override;

    function PatternToBytes(APattern: TPattern; ADrumKit: TDrumKit): TBytes;
    function SongToBytes(ASong: TSong; ADrumKit: TDrumKit): TBytes;
    procedure SavePattern(APattern: TPattern; const AFileName: String; ADrumKit: TDrumKit);
    procedure SaveSong(ASong: TSong; const AFileName: String; ADrumKit: TDrumKit);

    property DrumKit: TDrumKit read FDrumKit write FDrumKit;
  end;

implementation

function IntToBinBE(Value, Bytes: Integer): TByteDynArray;
var I: Integer;
begin
  SetLength(Result, Bytes);
  for I := Bytes - 1 downto 0 do
    Result[I] := (Value shr (I * 8)) and $FF;
end;

procedure VarLengthToVLQ(Value: Integer; out Output: TByteDynArray);
var Temp, I, Count: Integer;
begin
  SetLength(Output, 4);
  I := 0;
  Temp := Value;
  Output[3] := Temp and $7F;
  Temp := Temp shr 7;
  if Temp > 0 then begin
    Output[2] := $80 or (Temp and $7F);
    Temp := Temp shr 7;
  end;
  if Temp > 0 then begin
    Output[1] := $80 or (Temp and $7F);
    Temp := Temp shr 7;
  end;
  if Temp > 0 then begin
    Output[0] := $80 or (Temp and $7F);
    I := 4;
  end else
    I := 3;

  Count := 0;
  for Temp := 0 to 3 do
    if Temp >= I then Break
    else Inc(Count);

  SetLength(Output, Count);
end;

constructor TMIDIEngine.Create(ATicksPerBeat: Integer; ADrumKit: TDrumKit);
begin
  FTicksPerBeat := ATicksPerBeat;
  FEvents := specialize TList<TMIDIEvent>.Create;
  FDrumKit := ADrumKit;

  SetLength(FHeaderData, 14);
  FHeaderData[0]  := $4D; FHeaderData[1]  := $54; FHeaderData[2]  := $68; FHeaderData[3]  := $64;
  FHeaderData[4]  := $00; FHeaderData[5]  := $00; FHeaderData[6]  := $00; FHeaderData[7]  := $06;
  FHeaderData[8]  := $00; FHeaderData[9]  := $00;
  FHeaderData[10] := $00; FHeaderData[11] := $01;
  FHeaderData[12] := Byte(FTicksPerBeat shr 8);
  FHeaderData[13] := Byte(FTicksPerBeat and $FF);
end;

destructor TMIDIEngine.Destroy;
begin
  inherited Destroy;
end;

function TMIDIEngine.EncodeVLQ(Value: Integer): TByteDynArray;
var TempBytes: specialize TList<Integer>; Temp, I: Integer;
begin
  TempBytes := specialize TList<Integer>.Create;
  try
    if Value < 0 then Value := Abs(Value);
    repeat
      Temp := Value and $7F;
      Value := Value shr 7;
      TempBytes.Add(Temp);
    until Value = 0;

    SetLength(Result, TempBytes.Count);
    for I := TempBytes.Count - 1 downto 0 do
      Result[TempBytes.Count - 1 - I] := Byte(TempBytes[I]);
  finally
    TempBytes.Free;
  end;
end;

procedure TMIDIEngine.AddEvent(DeltaBeats: Double; const Data: TByteDynArray);
var Event: TMIDIEvent;
begin
  Event.DeltaTicks := Round(Abs(DeltaBeats) * FTicksPerBeat);
  SetLength(Event.Data, Length(Data));
  if Length(Data) > 0 then
    Move(Data[0], Event.Data[0], Length(Data));

  FEvents.Add(Event);
end;

procedure TMIDIEngine.WriteTempoMicroSec(MicroSecPerBeat: Cardinal);
var Bytes: Array[0..4] of Byte;
begin
  Bytes[0] := $FF;
  Bytes[1] := $51;
  Bytes[2] := $03;
  Bytes[3] := Byte(MicroSecPerBeat shr 16);
  Bytes[4] := Byte(MicroSecPerBeat shr 8);

  AddEvent(0.0, Bytes);
end;

function TMIDIEngine.CalculateDataSize: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to FEvents.Count - 1 do
  begin
    Inc(Result, Length(EncodeVLQ(FEvents[I].DeltaTicks)));
    Inc(Result, Length(FEvents[I].Data));
  end;
end;

function TMIDIEngine.SerializeTrack(DataSize: Integer): TByteDynArray;
var I, VLQLen, Offset: Integer; VLQBuf: TByteDynArray;
begin
  SetLength(Result, DataSize);
  Offset := 0;

  for I := 0 to FEvents.Count - 1 do
  begin
    VLQBuf := EncodeVLQ(FEvents[I].DeltaTicks);
    VLQLen := Length(VLQBuf);
    Move(VLQBuf[0], Result[Offset], VLQLen);
    Inc(Offset, VLQLen);

    if Length(FEvents[I].Data) > 0 then
    begin
      Move(FEvents[I].Data[0], Result[Offset], Length(FEvents[I].Data));
      Inc(Offset, Length(FEvents[I].Data));
    end;
  end;
end;

function TMIDIEngine.ResolveNote(AInstrument: TObject): Integer;
var InstName: string; Note: Integer; KeymapName: string;
begin
  Result := -1;

  if Assigned(AInstrument) and (AInstrument.ClassType = TDrumInstrument) then
    InstName := TDrumInstrument(AInstrument).Name
  else
    InstName := 'unknown';

  KeymapName := '';
  if FDrumKit <> nil then
    KeymapName := FDrumKit.Name;

  if FDrumKit <> nil then
  begin
    Note := FDrumKit.GetMidiNote(InstName, KeymapName);
    Result := Note;
  end;
end;

procedure TMIDIEngine.DedupeBeats(Beats: specialize TList<TBeat>; out DedupedBeats: specialize TList<TBeat>);
var KeyDict: specialize TDictionary<string, TBeat>; Beat: TBeat; InstName: string; KeyStr: string; Existing: TBeat; Item: specialize TPair<string, TBeat>;
begin
  DedupedBeats := specialize TList<TBeat>.Create;
  KeyDict := specialize TDictionary<string, TBeat>.Create;

  try
    for Beat in Beats do
    begin
      if Assigned(Beat.Instrument) then
        InstName := Beat.Instrument.Name
      else
        InstName := 'unknown';

      KeyStr := Format('%s|%.6f', [InstName, Beat.Position]);

      if KeyDict.TryGetValue(KeyStr, Existing) then
      begin
        if Beat.Velocity > Existing.Velocity then
          KeyDict[KeyStr] := Beat
      end
      else
        KeyDict.Add(KeyStr, Beat);
    end;

    for Item in KeyDict do
      DedupedBeats.Add(Item.Value);
  finally
    KeyDict.Free;
  end;
end;

function TMIDIEngine.PatternToBytes(APattern: TPattern; ADrumKit: TDrumKit): TBytes;
var I, MIDINote, Vel: Integer;
    LNoteOn: TByteDynArray; LNoteOff: TByteDynArray; LEndTrack: TByteDynArray;
    LDataSize: Integer; LTrackBytes: TBytes;
    LHeader: array[0..6] of Byte; LB: Byte;
begin
  Result := nil;
  FEvents.Clear;

  WriteTempoMicroSec(500000);

  if Assigned(APattern) and Assigned(APattern.Beats) then
  begin
    for I := 0 to APattern.Beats.Count - 1 do
    begin
      MIDINote := ADrumKit.GetMIDINote(APattern.Beats[I].Instrument.Name, ADrumKit.Name);

      if (MIDINote < 0) or (MIDINote > 127) then Continue;

      Vel := Min(Max(APattern.Beats[I].Velocity, 1), 127);

      SetLength(LNoteOn, 3);
      LNoteOn[0] := $9A;
      LNoteOn[1] := Byte(MIDINote);
      LNoteOn[2] := Byte(Vel);

      AddEvent(APattern.Beats[I].Position, LNoteOn);

      SetLength(LNoteOff, 3);
      LNoteOff[0] := $8A;
      LNoteOff[1] := Byte(MIDINote);
      LNoteOff[2] := $00;

      AddEvent(0.2, LNoteOff);
    end;
  end;

  SetLength(LEndTrack, 3);
  LEndTrack[0] := $FF;
  LEndTrack[1] := $2F;
  LEndTrack[2] := $00;
  AddEvent(0.0, LEndTrack);

  LDataSize := CalculateDataSize();
  SetLength(Result, 4 + LDataSize);

  LHeader[0] := $4D; LHeader[1] := $54; LHeader[2] := $72; LHeader[3] := $6B;
  Move(LHeader[0], Result[0], 4);

  LB := Byte(LDataSize shr 16); Move(LB, Result[4], 1);
  LB := Byte(LDataSize shr 8);  Move(LB, Result[5], 1);
  LB := Byte(LDataSize);        Move(LB, Result[6], 1);

  LTrackBytes := SerializeTrack(LDataSize);
  if Length(LTrackBytes) > 0 then
    Move(LTrackBytes[0], Result[7], Length(LTrackBytes));
end;

function TMIDIEngine.SongToBytes(ASong: TSong; ADrumKit: TDrumKit): TBytes;
var I, J, SectionBars, MIDINote, Vel, debugJ: Integer;
    DebugF: TextFile;
    LNoteOn: TByteDynArray; LNoteOff: TByteDynArray; LEndTrack: TByteDynArray;
    LCumTime: Double; LTempoUSec: Cardinal;
    LPat: TPattern; LDeduped: specialize TList<TBeat>; LB: TBeat;
    LDataSize: Integer; LTrackBytes: TBytes;
    LHeader: array[0..6] of Byte; LByteVal: Byte;
begin
  Result := nil;
  LCumTime := 0.0;

  FEvents.Clear;

  LTempoUSec := 500000;
  if (ASong <> nil) and (ASong.Tempo > 0) then
    LTempoUSec := Round(60000000.0 / ASong.Tempo);
  WriteTempoMicroSec(LTempoUSec);

  if not Assigned(ADrumKit) then ADrumKit := FDrumKit;
  if not Assigned(ASong) or not Assigned(ASong.Sections) then Exit;

  // Debug output for diagnosis (write to file since console may not work)
  AssignFile(DebugF, 'midi_debug.txt');
  Rewrite(DebugF);
  WriteLn(DebugF, '[MIDI] SongToBytes: sections=' + IntToStr(ASong.Sections.Count));
  WriteLn(DebugF, '[MIDI] SongToBytes: drumkit.name=' + ADrumKit.Name);

  for I := 0 to ASong.Sections.Count - 1 do
  begin
    SectionBars := ASong.Sections[I].Bars;

    LPat := ASong.Sections[I].Pattern;
    if not Assigned(LPat) or not Assigned(LPat.Beats) then
    begin
      WriteLn(DebugF, '[MIDI] Section ' + IntToStr(I) + ': pattern is nil');
      Continue;
    end;

    // Debug: print first 3 beat instrument names and MIDI notes for this section
    WriteLn(DebugF, '[MIDI] Section ' + IntToStr(I) + ' (' + IntToStr(SectionBars) + ' bars): beats=' + IntToStr(LPat.Beats.Count));
    begin
      for debugJ := 0 to Min(2, LPat.Beats.Count - 1) do
      begin
        if Assigned(LPat.Beats[debugJ].Instrument) then
          WriteLn(DebugF, '   beat[' + IntToStr(debugJ) + '] name=' + LPat.Beats[debugJ].Instrument.Name + 
                  ' => midi=' + IntToStr(ADrumKit.GetMidiNote(LPat.Beats[debugJ].Instrument.Name, ADrumKit.Name)))
        else
          WriteLn(DebugF, '   beat[' + IntToStr(debugJ) + '] instrument is NIL');
      end;
    end;

    LDeduped := specialize TList<TBeat>.Create;
    DedupeBeats(LPat.Beats, LDeduped);

    for J := 0 to SectionBars - 1 do
    begin
      for LB in LDeduped do
      begin
        if not Assigned(LB.Instrument) then Continue;
        MIDINote := ADrumKit.GetMIDINote(LB.Instrument.Name, ADrumKit.Name);

        if (MIDINote < 0) or (MIDINote > 127) then Continue;

        Vel := Min(Max(LB.Velocity, 1), 127);

        SetLength(LNoteOn, 3);
        LNoteOn[0] := $9A;
        LNoteOn[1] := Byte(MIDINote);
        LNoteOn[2] := Byte(Vel);

        AddEvent(LCumTime + J + LB.Position, LNoteOn);

        SetLength(LNoteOff, 3);
        LNoteOff[0] := $8A;
        LNoteOff[1] := Byte(MIDINote);
        LNoteOff[2] := $00;

        AddEvent(Trunc(Round(0.2 * FTicksPerBeat)), LNoteOff);
      end;
    end;

    LCumTime := LCumTime + SectionBars;
    LDeduped.Free;
  end;

  SetLength(LEndTrack, 3);
  LEndTrack[0] := $FF;
  LEndTrack[1] := $2F;
  LEndTrack[2] := $00;
  AddEvent(0.0, LEndTrack);

  LDataSize := CalculateDataSize();
  SetLength(Result, 4 + LDataSize);

  LHeader[0] := $4D; LHeader[1] := $54; LHeader[2] := $72; LHeader[3] := $6B;
  Move(LHeader[0], Result[0], 4);

  LByteVal := Byte(LDataSize shr 16); Move(LByteVal, Result[4], 1);
  LByteVal := Byte(LDataSize shr 8);  Move(LByteVal, Result[5], 1);
  LByteVal := Byte(LDataSize);        Move(LByteVal, Result[6], 1);

  LTrackBytes := SerializeTrack(LDataSize);
  if Length(LTrackBytes) > 0 then
    Move(LTrackBytes[0], Result[7], Length(LTrackBytes));
  
  CloseFile(DebugF);
end;

procedure TMIDIEngine.SavePattern(APattern: TPattern; const AFileName: String; ADrumKit: TDrumKit);
var LData: TBytes; FStream: TFileStream;
begin
  LData := PatternToBytes(APattern, ADrumKit);
  if Length(LData) = 0 then Exit;

  FStream := TFileStream.Create(AFileName, fmCreate);
  try
    FStream.WriteBuffer(LData[0], Length(LData));
  finally
    FStream.Free;
  end;
end;

procedure TMIDIEngine.SaveSong(ASong: TSong; const AFileName: String; ADrumKit: TDrumKit);
var LData: TBytes; FStream: TFileStream;
begin
  LData := SongToBytes(ASong, ADrumKit);
  if Length(LData) = 0 then Exit;

  FStream := TFileStream.Create(AFileName, fmCreate);
  try
    FStream.WriteBuffer(LData[0], Length(LData));
  finally
    FStream.Free;
  end;
end;

end.
