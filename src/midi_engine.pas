unit MIDIEngine;

{$mode objfpc}{$H+}

{ TMIDIEngine — Raw SMF Format 0 writer (zero external dependencies).
  Generates standard .mid files by writing binary MIDI events directly.
  Compatible with all DAWs and drum VSTs without midiutil/mido. }

interface

uses
  Classes, SysUtils, Math, Windows,
  core_models_pattern, core_models_song,
  config_constants, core_models_kit;

type
  TMIDIEvent = record
    DeltaTicks: Integer; // delta time in ticks
    Data: TArray<Byte>;
  end;

  { ── Helper functions (standalone) ───────────────────────────────────── }

function IntToBinBE(Value, Bytes: Integer): TByteArray;
procedure VarLengthToVLQ(Value: Integer; out Output: TByteArray);

  TMIDIEngine = class
  private
    FTicksPerBeat: Integer;
    FHeaderData: TArray<Byte>;
    FEvents: TList<TMIDIEvent>;
    FDrumKit: TDrumKit;

    function EncodeVLQ(Value: Integer): TArray<Byte>;
    procedure AddEvent(DeltaBeats: Double; const Data: TArray<Byte>);
    procedure WriteTempoMicroSec(MicroSecPerBeat: Cardinal);
    function SerializeTrack(DataSize: Integer): TBytes;
    function CalculateDataSize: Integer;

    { Dynamic MIDI note resolution using drum kit/keymap (CRITICAL!) }
    function ResolveNote(AInstrument: TObject): Integer;

    { Beat deduplication — keeps loudest when same instrument at same position }
    procedure DedupeBeats(Beats: TObjectList<TBeat>; out DedupedBeats: TObjectList<TBeat>);

  public
    constructor Create(ATicksPerBeat: Integer = Defaults.MIDI_RESOLUTION; ADrumKit: TDrumKit = nil);
    destructor Destroy; override;

    function PatternToBytes(APattern: TPattern; ADrumKit: TDrumKit): TBytes;
    function SongToBytes(ASong: TSong; ADrumKit: TDrumKit): TBytes;
    procedure SavePattern(APattern: TPattern; const AFileName: String; ADrumKit: TDrumKit);
    procedure SaveSong(ASong: TSong; const AFileName: String; ADrumKit: TDrumKit);

    property DrumKit: TDrumKit read FDrumKit write FDrumKit;
  end;

implementation

{ ── Helper Functions ───────────────────────────────────────────────────── }

function IntToBinBE(Value, Bytes: Integer): TByteArray;
var I: Integer;
begin
  SetLength(Result, Bytes);
  for I := Bytes - 1 downto 0 do
    Result[I] := (Value shr (I * 8)) and $FF;
end;

procedure VarLengthToVLQ(Value: Integer; out Output: TByteArray);
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

{ ── Constructor/Destructor ─────────────────────────────────────────────── }

constructor TMIDIEngine.Create(ATicksPerBeat: Integer; ADrumKit: TDrumKit);
begin
  FTicksPerBeat := ATicksPerBeat;
  FEvents := TList<TMIDIEvent>.Create;
  FDrumKit := ADrumKit;

  // SMF Format 0 header: MThd <length name="6"> <format name="0"> <ntrks name="1"> <division>
  SetLength(FHeaderData, 14);
  FHeaderData[0]  := $4D; FHeaderData[1]  := $54; FHeaderData[2]  := $68; FHeaderData[3]  := $64; // "MThd"
  FHeaderData[4]  := $00; FHeaderData[5]  := $00; FHeaderData[6]  := $00; FHeaderData[7]  := $06; // Length = 6
  FHeaderData[8]  := $00; FHeaderData[9]  := $00; // Format 0
  FHeaderData[10] := $00; FHeaderData[11] := $01; // 1 track
  FHeaderData[12] := HighByte(FTicksPerBeat);
  FHeaderData[13] := LowByte(FTicksPerBeat);
end;

destructor TMIDIEngine.Destroy;
var I: Integer;
begin
  for I := 0 to FEvents.Count - 1 do
    SetLength(FEvents[I].Data, 0);
  FEvents.Free;
  inherited Destroy;
end;

{ ── Internal Helpers ───────────────────────────────────────────────────── }

function TMIDIEngine.EncodeVLQ(Value: Integer): TArray<Byte>;
var TempBytes: TList<Byte>; Temp: Integer;
begin
  TempBytes := TList<Byte>.Create;
  try
    if Value < 0 then Value := Abs(Value);

    repeat
      Temp := Value and $7F;
      Value := Value shr 7;
      TempBytes.Add(Temp);
    until Value = 0;

    SetLength(Result, TempBytes.Count);
    for I := 0 to TempBytes.Count - 2 do
      Result[I] := TempBytes[TempBytes.Count - 1 - I] or $80; // continuation bit

    if TempBytes.Count > 0 then
      Result[TempBytes.Count - 1] := TempBytes[0]; // no continuation bit on last byte
  finally
    TempBytes.Free;
  end;
end;

procedure TMIDIEngine.AddEvent(DeltaBeats: Double; const Data: TArray<Byte>);
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
  // MIDI tempo meta event: FF 51 03 [byte0 byte1 byte2]
  // Microseconds per quarter note (e.g., 500000 = 120 BPM)
  Bytes[0] := $FF;   // Meta event
  Bytes[1] := $51;   // Tempo
  Bytes[2] := $03;   // Length = 3 bytes
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
    Inc(Result, Length(EncodeVLQ(FEvents[I].DeltaTicks))); // delta time VLQ
    Inc(Result, Length(FEvents[I].Data));                  // event data
  end;
end;

function TMIDIEngine.SerializeTrack(DataSize: Integer): TBytes;
var I, VLQLen: Integer; VLQBuf: TArray<Byte>;
begin
  SetLength(Result, DataSize);

  for I := 0 to FEvents.Count - 1 do
  begin
    // Write delta time as VLQ
    VLQBuf := EncodeVLQ(FEvents[I].DeltaTicks);
    VLQLen := Length(VLQBuf);
    Move(VLQBuf[0], Result[0], VLQLen);
    Inc(Result, VLQLen);

    // Write event data
    if Length(FEvents[I].Data) > 0 then
    begin
      Move(FEvents[I].Data[0], Result[0], Length(FEvents[I].Data));
      Inc(Result, Length(FEvents[I].Data));
    end;
  end;
end;

{ ── CRITICAL PRODUCTION CODE: Dynamic Note Resolution ──────────────────── }

function TMIDIEngine.ResolveNote(AInstrument: TObject): Integer;
var InstName: string; Note: Integer;
begin
  // If it's already an integer, return as-is.
  if AInstrument is Integer then
    Exit(Integer(AInstrument));

  // Get the instrument name string for lookup.
  if Assigned(AInstrument) and (AInstrument is TDrumInstrument) then
    InstName := TDrumInstrument(AInstrument).Name
  else
    InstName := 'unknown';

  // Try custom mappings first.
  if FDrumKit <> nil and Assigned(FDrumKit.FCustomMappings) and FDrumKit.FCustomMappings.TryGetValue(InstName, Note) then
    Exit(Note);

  // Fall back to keymap lookup.
  if FDrumKit <> nil then
  begin
    Note := FDrumKit.GetMIDINote(InstName);
    Result := Note;
  end
  else
    Result := -1; { No drum kit available }
end;

{ ── CRITICAL PRODUCTION CODE: Beat Deduplication ───────────────────────── }

procedure TMIDIEngine.DedupeBeats(Beats: TObjectList<TBeat>; out DedupedBeats: TObjectList<TBeat>);
var KeyDict: TDictionary<string, TBeat>; Beat: TBeat; InstName: string; KeyStr: string; Existing: TBeat;
begin
  DedupedBeats := TObjectList<TBeat>.Create(true);
  KeyDict := TDictionary<string, TBeat>.Create;

  try
    for Beat in Beats do
    begin
      if Assigned(Beat.FInstrument) then
        InstName := Beat.FInstrument.Name
      else
        InstName := 'unknown';

      KeyStr := Format('%s|%.6f', [InstName, Beat.FPosition]);

      if KeyDict.TryGetValue(KeyStr, Existing) then
      begin
        if Beat.FVelocity > Existing.FVelocity then
          KeyDict[KeyStr] := Beat { Replace with louder one }
      end
      else
        KeyDict.Add(KeyStr, Beat);
    end;

    // Add all unique beats to output.
    for var Item in KeyDict do
      DedupedBeats.Add(Item.Value);
  finally
    KeyDict.Free;
  end;
end;

{ ── Pattern → bytes ───────────────────────────────────────────────────── }

function TMIDIEngine.PatternToBytes(APattern: TPattern; ADrumKit: TDrumKit): TBytes;
var I, J, MIDINote, Velocity: Integer; NoteOnEvent, NoteOffEvent: TArray<Byte>; EndOfTrack: TArray<Byte>;
begin
  Result := nil;

  FEvents.Clear;

  // Write start tempo (120 BPM = 500000 microseconds per quarter note)
  WriteTempoMicroSec(500000);

  if Assigned(APattern) and Assigned(APattern.Beats) then
  begin
    for I := 0 to APattern.BarsCount - 1 do
    begin
      if (I >= APattern.Beats.Count) then Break;

      for J := 0 to APattern.Beats[I].Count - 1 do
      begin
        MIDINote := ADrumKit.GetMIDINote(APattern.Beats[I][J].Instrument);

        // Skip unmapped instruments
        if (MIDINote < 0) or (MIDINote > 127) then Continue;

        Velocity := Clamp(APattern.Beats[I][J].Velocity, 1, 127);

        // Note On event: Channel 10 (drums) = $9A
        SetLength(NoteOnEvent, 3);
        NoteOnEvent[0] := $9A;
        NoteOnEvent[1] := Byte(MIDINote);
        NoteOnEvent[2] := Byte(Velocity);

        AddEvent(APattern.Beats[I][J].Time, NoteOnEvent);

        // Note Off event (default 0.2 beat duration)
        SetLength(NoteOffEvent, 3);
        NoteOffEvent[0] := $8A;
        NoteOffEvent[1] := Byte(MIDINote);
        NoteOffEvent[2] := $00;

        AddEvent(0.2, NoteOffEvent);
      end;
    end;
  end;

  // End of track marker: FF 2F 00
  SetLength(EndOfTrack, 3);
  EndOfTrack[0] := $FF;
  EndOfTrack[1] := $2F;
  EndOfTrack[2] := $00;
  AddEvent(0.0, EndOfTrack);

  // Build final binary
  var DataSize := CalculateDataSize();
  SetLength(Result, 4 + DataSize);

  Move($4D, Result[0], 4); // "MTrk"
  Move(Byte(DataSize shr 16), Result[4], 1);
  Move(Byte(DataSize shr 8), Result[5], 1);
  Move(Byte(DataSize), Result[6], 1);

  var TrackBytes := SerializeTrack(DataSize);
  if Length(TrackBytes) > 0 then
    Move(TrackBytes[0], Result[7], Length(TrackBytes));
end;

{ ── Song → bytes (FIXED: now reads actual patterns instead of hardcoded notes) ─ }

function TMIDIEngine.SongToBytes(ASong: TSong; ADrumKit: TDrumKit): TBytes;
var I, J: Integer; SectionBars: Integer; MIDINote, Velocity: Integer;
  NoteOnEvent, NoteOffEvent: TArray<Byte>; EndOfTrack: TArray<Byte>; CumulativeTime: Double;
  Pattern: TPattern; DedupedBeats: TObjectList<TBeat>; Beat: TBeat;
begin
  Result := nil;
  CumulativeTime := 0.0;

  FEvents.Clear;

  // Write tempo meta event from actual song tempo
  var TempoMicroSec: Cardinal := 500000; { Default 120 BPM }
  if (ASong <> nil) and (ASong.Tempo > 0) then
    TempoMicroSec := Round(60000000.0 / ASong.Tempo);
  WriteTempoMicroSec(TempoMicroSec);

  if not Assigned(ADrumKit) then ADrumKit := FDrumKit;
  if not Assigned(ASong) or not Assigned(ASong.Sections) then Exit;

  for I := 0 to ASong.Sections.Count - 1 do
  begin
    SectionBars := ASong.Sections[I].BarsCount;

    // Get pattern for this section (handle multi-bar tiling)
    Pattern := ASong.Sections[I].Pattern;
    if not Assigned(Pattern) or not Assigned(Pattern.Beats) then Continue;

    // Deduplicate beats first
    DedupedBeats := TObjectList<TBeat>.Create(true);
    DedupeBeats(Pattern.Beats, DedupedBeats);

    for J := 0 to SectionBars - 1 do
    begin
      for Beat in DedupedBeats do
      begin
        MIDINote := ADrumKit.GetMIDINote(Beat.Instrument);

        // Skip unmapped instruments
        if (MIDINote < 0) or (MIDINote > 127) then Continue;

        Velocity := Clamp(Beat.Velocity, 1, 127);

        // Note On event: Channel 10 (drums) = $9A
        SetLength(NoteOnEvent, 3);
        NoteOnEvent[0] := $9A;
        NoteOnEvent[1] := Byte(MIDINote);
        NoteOnEvent[2] := Byte(Velocity);

        AddEvent(CumulativeTime + J + Beat.Time, NoteOnEvent);

        // Note Off event (default 0.2 beat duration)
        SetLength(NoteOffEvent, 3);
        NoteOffEvent[0] := $8A;
        NoteOffEvent[1] := Byte(MIDINote);
        NoteOffEvent[2] := $00;

        AddEvent(0.2, NoteOffEvent);
      end;
    end;

    CumulativeTime := CumulativeTime + SectionBars;
    DedupedBeats.Free;
  end;

  // End of track marker
  SetLength(EndOfTrack, 3);
  EndOfTrack[0] := $FF;
  EndOfTrack[1] := $2F;
  EndOfTrack[2] := $00;
  AddEvent(0.0, EndOfTrack);

  // Build final binary
  var DataSize := CalculateDataSize();
  SetLength(Result, 4 + DataSize);

  Move($4D, Result[0], 4); // "MTrk"
  Move(Byte(DataSize shr 16), Result[4], 1);
  Move(Byte(DataSize shr 8), Result[5], 1);
  Move(Byte(DataSize), Result[6], 1);

  var TrackBytes := SerializeTrack(DataSize);
  if Length(TrackBytes) > 0 then
    Move(TrackBytes[0], Result[7], Length(TrackBytes));
end;

{ ── File Write Convenience ─────────────────────────────────────────────── }

procedure TMIDIEngine.SavePattern(APattern: TPattern; const AFileName: String; ADrumKit: TDrumKit);
var LData: TBytes; FStream: TFileStream;
begin
  LData := PatternToBytes(APattern, ADrumKit);
  if Length(LData) = 0 then Exit;

  // Write binary directly to file
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

  // Write binary directly to file
  FStream := TFileStream.Create(AFileName, fmCreate);
  try
    FStream.WriteBuffer(LData[0], Length(LData));
  finally
    FStream.Free;
  end;
end;

end.
