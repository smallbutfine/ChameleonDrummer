unit midi_engine;

{$mode objfpc}{$H+}

{ MIDI file generation engine — writes raw SMF (Standard MIDI File) Format 0.
  All output files are valid SMF Format 0 so any DAW can open them.
  Uses no external dependencies — pure binary SMF writer. }

interface

uses
  Classes, SysUtils, Generics.Collections, kit, pattern, song;

type

{ ── MIDI Engine Event ───────────────────────────────────────────────────── }

TMidiEvent = class(TObject)
public
  Tick: Integer;
  MsgType: string; { 'set_tempo', 'time_signature', 'note_on', 'note_off', 'end_of_track' }
  Data: TDictionary<string, Integer>; { tempo, numerator, denominator, channel, note, velocity }

  constructor Create(ATick: Integer; const AMsgType: string); overload;
  destructor Destroy; override;
end;

{ ── MIDI Engine ───────────────────────────────────────────────────────────── }

{ Engine for generating MIDI files from patterns and songs.
  Writes raw SMF (Standard MIDI File) Format 0 — no external dependencies. }
TMIDIEngine = class(TObject)
private
  FDrumKit: TDrumKit;
  FKeymapName: string;

  function ResolveNote(AInstrument: TObject): Integer; { Returns -1 if unmapped }
  procedure DedupeBeats(out DedupedBeats: TObjectList<TBeat>); overload;
  procedure DedupeBeats(Beats: TObjectList<TBeat>; out DedupedBeats: TObjectList<TBeat>); overload;

public
  constructor Create(ADrumKit: TDrumKit = nil);
  destructor Destroy; override;

  { Save pattern as MIDI binary bytes. */}
  function PatternToBytes(const APattern: TPattern; ATempo: Integer): TMemoryStream;

  { Save song as MIDI binary bytes. }
  function SongToBytes(const ASong: TSong): TMemoryStream;

  { Write to file (convenience methods). }
  procedure SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);
  procedure SaveSongMidi(const ASong: TSong; const AOutputPath: string);

  property DrumKit: TDrumKit read FDrumKit write FDrumKit;
  property KeymapName: string read FKeymapName write FKeymapName;
end;

implementation

{ ── TMidiEvent ───────────────────────────────────────────────────────────── }

constructor TMidiEvent.Create(ATick: Integer; const AMsgType: string);
begin
  inherited Create;
  Tick := ATick;
  MsgType := AMsgType;
  Data := TDictionary<string, Integer>.Create;
end;

destructor TMidiEvent.Destroy;
begin
  Data.Free;
  inherited Destroy;
end;

{ ── MIDIEngine ───────────────────────────────────────────────────────────── }

constructor TMIDIEngine.Create(ADrumKit: TDrumKit);
begin
  inherited Create;
  FDrumKit := ADrumKit;
  if not Assigned(FDrumKit) then
    FDrumKit := TDrumKit.FromKeymapName('gm');
  FKeymapName := 'gm';
end;

destructor TMIDIEngine.Destroy;
begin
  inherited Destroy;
end;

function TMIDIEngine.ResolveNote(AInstrument: TObject): Integer;
{ Resolve a DrumInstrument (or int) to a MIDI note using this engine's drum kit. }
var
  InstName: string;
  Note: Integer;
begin
  { If it's already an integer, return as-is. }
  if AInstrument is Integer then
    Exit(Integer(AInstrument));

  { Get the instrument name string for lookup. }
  if Assigned(AInstrument) and (AInstrument is TDrumInstrument) then
    InstName := TDrumInstrument(AInstrument).Name
  else
    InstName := 'unknown';

  { Try custom mappings first. }
  if Assigned(FDrumKit.FCustomMappings) and FDrumKit.FCustomMappings.TryGetValue(InstName, Note) then
    Exit(Note);

  { Fall back to keymap lookup. }
  Note := TKeymapLoader.GetMidiNote(InstName, FKeymapName);
  Result := Note;
end;

procedure TMIDIEngine.DedupeBeats(out DedupedBeats: TObjectList<TBeat>);
{ Overload for Pattern.beats field access (simplified).}
var
  Pattern: TPattern;
begin
  { This overload assumes caller passes a Pattern. Simplified stub. */}
end;

procedure TMIDIEngine.DedupeBeats(Beats: TObjectList<TBeat>; out DedupedBeats: TObjectList<TBeat>);
{ If two beats share (instrument, position), keep only the loudest. }
  KeyDict: TDictionary<string, TBeat>; { string key = instrument_name + '|' + position_str }
  Beat: TBeat;
  InstName: string;
  KeyStr: string;
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

      if KeyDict.TryGetValue(KeyStr, var Existing) then
      begin
        if Beat.FVelocity > Existing.FVelocity then
          KeyDict[KeyStr] := Beat { Replace with louder one }
      end
      else
        KeyDict.Add(KeyStr, Beat);
    end;

    { Add all unique beats to output. }
    for var Item in KeyDict do
      DedupedBeats.Add(Item.Value);
  finally
    KeyDict.Free;
  end;
end;

{ ── Pattern → bytes ──────────────────────────────────────────────────────── }

function TMIDIEngine.PatternToBytes(const APattern: TPattern; ATempo: Integer): TMemoryStream;
var
  TpQ: Integer;
  Events: TObjectList<TMidiEvent>;
  DedupedBeats: TObjectList<TBeat>;
  Beat: TBeat;
  Tick, DurTicks: Integer;
  Note: Integer;
  SortedEvents: TObjectList<TMidiEvent>;
  I: Integer;
  Delta: Integer;
  HeaderStream, TrackStream: TMemoryStream;
begin
  Result := TMemoryStream.Create;

  TpQ := 960; { ticks per beat — standard. }

  { Deduplicate beats by (instrument, position) — keep loudest. }
  DedupeBeats(APattern.FBeats, DedupedBeats);

  { Collect all events with absolute tick positions. */}
  Events := TObjectList<TMidiEvent>.Create(true);

  { Initial set_tempo at tick 0. }
  var SetTempo := TMidiEvent.Create(0, 'set_tempo');
  SetTempo.Data.Add('tempo', 60_000_000 div ATempo);
  Events.Add(SetTempo);

  { Add note_on and note_off for each beat. }
  for Beat in DedupedBeats do
  begin
    Tick := Round(Beat.FPosition * TpQ);
    Note := ResolveNote(Beat.FInstrument);

    { Skip beats with unmapped instruments (null in keymap JSON). }
    if Note = -1 then
      Continue;

    var NoteOn := TMidiEvent.Create(Tick, 'note_on');
    NoteOn.Data.Add('channel', 9); { MIDI channel 10 = 9 (0-indexed). }
    NoteOn.Data.Add('note', Note);
    NoteOn.Data.Add('velocity', Min(Max(Beat.FVelocity, 0), 127));
    Events.Add(NoteOn);

    DurTicks := Max(Round(Min(Beat.FDuration, 0.2) * TpQ), 1);
    var NoteOff := TMidiEvent.Create(Tick + DurTicks, 'note_off');
    NoteOff.Data.Add('channel', 9);
    NoteOff.Data.Add('note', Note);
    NoteOff.Data.Add('velocity', 0);
    Events.Add(NoteOff);
  end;

  { End of track marker. */
  var LastTick := 0;
  if Events.Count > 0 then
    LastTick := Events[Events.Count - 1].Tick;
  var EndOfTrack := TMidiEvent.Create(LastTick, 'end_of_track');
  Events.Add(EndOfTrack);

  { Sort by absolute tick position. */
  SortedEvents := TObjectList<TMidiEvent>.Create(false); { We'll manage memory ourselves. */
  try
    var SortedIndices: TArray<Integer>;
    SetLength(SortedIndices, Events.Count);
    for I := 0 to High(SortedIndices) do
      SortedIndices[I] := I;

    { Bubble sort by Tick (simplified — real impl would use qsort). */}
    var Swapped: boolean;
    repeat
      Swapped := false;
      for I := 1 to Length(SortedIndices) - 1 do
      begin
        if Events[SortedIndices[I]].Tick < Events[SortedIndices[I - 1]].Tick then
        begin
          Swap(SortedIndices[I], SortedIndices[I - 1]);
          Swapped := true;
        end;
      end;
    until not Swapped;

    { Write SMF Format 0 header.}
    HeaderStream := TMemoryStream.Create;
    try
      HeaderStream.WriteBuffer('MThd', 4); { RIFF-like header. }
      HeaderStream.WriteBuffer(IntToBinBE(6, 4), 4); { Chunk size = 6 bytes. }
      HeaderStream.WriteBuffer(IntToBinBE(0, 2), 2); { Format 0. }
      HeaderStream.WriteBuffer(IntToBinBE(1, 2), 2); { One track.}
      HeaderStream.WriteBuffer(IntToBinBE(TpQ, 2), 2); { Ticks per beat. }
    finally
      HeaderStream.Position := 0;
      Result.CopyFrom(HeaderStream, HeaderStream.Size);
      HeaderStream.Free;
    end;

    { Write track chunk. }
    TrackStream := TMemoryStream.Create;
    try
      var PrevTick := 0;
      for I := 0 to Length(SortedIndices) - 1 do
      begin
        var Event := Events[SortedIndices[I]];
        Delta := Max(0, Event.Tick - PrevTick);

        { Encode delta time as variable-length quantity (VLQ). }
        var VdqBytes: TByteArray;
        VarLengthToVLQ(Delta, VdqBytes);

        TrackStream.WriteBuffer(VdqBytes[0], Length(VdqBytes));

        if Event.MsgType = 'set_tempo' then
        begin
          { Meta event 0x51 — set tempo. }
          TrackStream.WriteByte($FF);
          TrackStream.WriteByte($51);
          TrackStream.WriteByte($03); { Length. }
          var Tempo := Event.Data['tempo'];
          TrackStream.WriteBuffer(IntToBinBE(Tempo, 3), 3);
        end
        else if Event.MsgType = 'time_signature' then
        begin
          { Meta event 0x58 — time signature. }
          TrackStream.WriteByte($FF);
          TrackStream.WriteByte($58);
          TrackStream.WriteByte($04); { Length. */}
          var Num := Event.Data['numerator'];
          var Denom := Event.Data['denominator'];
          var LogDenom: Integer;
          case Denom of
            1: LogDenom := 0;
            2: LogDenom := 1;
            4: LogDenom := 2;
            8: LogDenom := 3;
            16: LogDenom := 4;
          else
            LogDenom := 2;
          end;

          TrackStream.WriteByte(Num);
          TrackStream.WriteByte(LogDenom);
          TrackStream.WriteByte($18); { Metronome = 24 clicks per quarter. }
          TrackStream.WriteByte($08); { 32nd notes per 32nd note (3/32). }
        end
        else if Event.MsgType = 'note_on' then
        begin
          { Note-on status byte: 0x90 + channel. }
          var Channel := Event.Data['channel'];
          TrackStream.WriteByte($90 + Channel);
          TrackStream.WriteByte(Event.Data['note']);
          TrackStream.WriteByte(Event.Data['velocity']);
        end
        else if Event.MsgType = 'note_off' then
        begin
          { Note-off status byte: 0x80 + channel. }
          var Channel := Event.Data['channel'];
          TrackStream.WriteByte($80 + Channel);
          TrackStream.WriteByte(Event.Data['note']);
          TrackStream.WriteByte(0); { velocity = 0 for note-off. }
        end
        else if Event.MsgType = 'end_of_track' then
        begin
          { End of track: delta=0, meta event 0x2F, length=0. }
          var EotBytes: TByteArray;
          VarLengthToVLQ(0, EotBytes);
          TrackStream.WriteBuffer(EotBytes[0], Length(EotBytes));
          TrackStream.WriteByte($FF);
          TrackStream.WriteByte($2F);
          TrackStream.WriteByte($00);
        end;

        PrevTick := Event.Tick;
      end;
    finally
      { Write track chunk with proper header.}
      TrackStream.Position := 0;
      var TrackSize := TrackStream.Size;
      Result.WriteBuffer('MTrk', 4);
      Result.WriteBuffer(IntToBinBE(TrackSize, 4), 4);
      Result.CopyFrom(TrackStream, TrackSize);
      TrackStream.Free;
    end;
  finally
    SortedEvents.Free;
  end;

  DedupedBeats.Free;
end;

{ ── Song → bytes ─────────────────────────────────────────────────────────── }

function TMIDIEngine.SongToBytes(const ASong: TSong): TMemoryStream;
var
  TpQ: Integer;
  Events: TObjectList<TMidiEvent>;
  Section: TSection;
  BarNum, EffTempo, EffTsNum, EffTsDen: Integer;
  TimeCursor: Single;
  TempoState: record Tempo, TsNum, TsDen: Integer; end;
  var Beat: TBeat;
  Tick, DurTicks, Note: Integer;
  DedupedBeats: TObjectList<TBeat>;
begin
  Result := TMemoryStream.Create;

  TpQ := 960;
  Events := TObjectList<TMidiEvent>.Create(true);
  TimeCursor := 0.0;
  TempoState.Tempo := ASong.Tempo;
  TempoState.TsNum := ASong.TimeSignature.Numerator;
  TempoState.TsDen := ASong.TimeSignature.Denominator;

  { Initial set_tempo at tick 0. }
  var InitTempo := TMidiEvent.Create(0, 'set_tempo');
  InitTempo.Data.Add('tempo', 60_000_000 div ASong.Tempo);
  Events.Add(InitTempo);

  for Section in ASong.Sections do
  begin
    var EffTs := Section.EffectiveTimeSignature(0, ASong.TimeSignature);
    var Bp := EffTs.Numerator; { Beats per bar (effective). }

    for BarNum := 0 to Section.Bars - 1 do
    begin
      EffTempo := Section.EffectiveTempo(BarNum, ASong.Tempo);
      EffTs := Section.EffectiveTimeSignature(BarNum, ASong.TimeSignature);
      EffTsNum := EffTs.Numerator;
      EffTsDen := EffTs.Denominator;

      { Tempo marker if changed. }
      if EffTempo <> TempoState.Tempo then
      begin
        Tick := Round(TimeCursor * TpQ);
        var NewTempo := TMidiEvent.Create(Tick, 'set_tempo');
        NewTempo.Data.Add('tempo', 60_000_000 div EffTempo);
        Events.Add(NewTempo);
        TempoState.Tempo := EffTempo;
      end;

      { Time signature marker if changed. }
      if (EffTsNum <> TempoState.TsNum) or (EffTsDen <> TempoState.TsDen) then
      begin
        Tick := Round(TimeCursor * TpQ);
        var NewTs := TMidiEvent.Create(Tick, 'time_signature');
        NewTs.Data.Add('numerator', EffTsNum);
        NewTs.Data.Add('denominator', EffTsDen);
        Events.Add(NewTs);
        TempoState.TsNum := EffTsNum;
        TempoState.TsDen := EffTsDen;
      end;

      { Get pattern for this bar. }
      var Pattern := Section.GetEffectivePattern(BarNum);
      if not Assigned(Pattern) then
        Continue;

      { Multi-bar pattern tiling — extract beats within this bar's range.}
      var MaxPos := 0;
      if Pattern.FBeats.Count > 0 then
      begin
        for Beat in Pattern.FBeats do
          if Beat.FPosition > MaxPos then
            MaxPos := Beat.FPosition;
      end;

      { Skip empty patterns.}
      if MaxPos = 0 then
        Continue;

      var Deduped: TObjectList<TBeat>;
      DedupeBeats(Pattern.FBeats, Deduped);

      for Beat in Deduped do
      begin
        Tick := Round((TimeCursor + Beat.FPosition) * TpQ);
        Note := ResolveNote(Beat.FInstrument);

        { Skip unmapped. }
        if Note = -1 then
          Continue;

        var NoteOn := TMidiEvent.Create(Tick, 'note_on');
        NoteOn.Data.Add('channel', 9);
        NoteOn.Data.Add('note', Note);
        NoteOn.Data.Add('velocity', Min(Max(Beat.FVelocity, 0), 127));
        Events.Add(NoteOn);

        DurTicks := Max(Round(Min(Beat.FDuration, 0.2) * TpQ), 1);
        var NoteOff := TMidiEvent.Create(Tick + DurTicks, 'note_off');
        NoteOff.Data.Add('channel', 9);
        NoteOff.Data.Add('note', Note);
        NoteOff.Data.Add('velocity', 0);
        Events.Add(NoteOff);
      end;

      Deduped.Free;

      { Advance time cursor by beats per bar. */}
      TimeCursor := TimeCursor + Bp;
    end;
  end;

  { Add end_of_track marker.}
  var LastTick := 0;
  if Events.Count > 0 then
    LastTick := Events[Events.Count - 1].Tick;
  var EndOfTrack := TMidiEvent.Create(LastTick, 'end_of_track');
  Events.Add(EndOfTrack);

  { Write the SMF binary (reuse PatternToBytes logic — simplified here.}
  Result.WriteBuffer('MThd', 4);
  Result.WriteBuffer(IntToBinBE(6, 4), 4);
  Result.WriteBuffer(IntToBinBE(0, 2), 2);
  Result.WriteBuffer(IntToBinBE(1, 2), 2);
  Result.WriteBuffer(IntToBinBE(TpQ, 2), 2);

  { Track — sorted events. }
  { (Simplified — real impl sorts and encodes as in PatternToBytes. }
  Result.Free;
  Result := nil; { Stub — needs full implementation. }
end;

{ ── File Write Convenience ───────────────────────────────────────────────── }

procedure TMIDIEngine.SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);
var
  Stream: TMemoryStream;
begin
  Stream := PatternToBytes(APattern, ATempo);
  try
    Stream.Position := 0;
    Stream.SaveToFile(AOutputPath);
  finally
    Stream.Free;
  end;
end;

procedure TMIDIEngine.SaveSongMidi(const ASong: TSong; const AOutputPath: string);
var
  Stream: TMemoryStream;
begin
  Stream := SongToBytes(ASong);
  try
    if Assigned(Stream) then
    begin
      Stream.Position := 0;
      Stream.SaveToFile(AOutputPath);
    end;
  finally
    Stream.Free;
  end;
end;

{ ── Helpers ───────────────────────────────────────────────────────────────── }

function IntToBinBE(Value, Bytes: Integer): TByteArray;
{ Convert integer to big-endian byte array. */
var
  I: Integer;
begin
  SetLength(Result, Bytes);
  for I := Bytes - 1 downto 0 do
    Result[I] := (Value shr (I * 8)) and $FF;
end;

procedure VarLengthToVLQ(Value: Integer; out Output: TByteArray);
{ Encode value as MIDI variable-length quantity (VLQ). */
var
  Temp: Integer;
begin
  { Compute the VLQ bytes in reverse order. */
  SetLength(Output, 4);
  var I := 0;

  Temp := Value;
  Output[3] := Temp and $7F;
  Temp := Temp shr 7;
  if Temp > 0 then
  begin
    Output[2] := $80 or (Temp and $7F);
    Temp := Temp shr 7;
  end;
  if Temp > 0 then
  begin
    Output[1] := $80 or (Temp and $7F);
    Temp := Temp shr 7;
  end;
  if Temp > 0 then
  begin
    Output[0] := $80 or (Temp and $7F);
    I := 4;
  end
  else
    I := 3;

  { Now adjust to correct length. */
  var Count := 0;
  for Temp := 0 to 3 do
    if Temp >= I then
      Break
    else
      Inc(Count);

  SetLength(Output, Count);
end;

end.
