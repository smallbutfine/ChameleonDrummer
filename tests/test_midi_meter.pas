program test_midi_meter;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, jsonparser, DrumGenerator, Song, Pattern, Kit, time_signature;

type
  TNoteEvent = record
    Tick: Int64;
    Note: Byte;
  end;
  TNoteEvents = array of TNoteEvent;
  TTimeSignatureEvent = record
    Tick: Int64;
    Numerator: Byte;
    Denominator: Integer;
  end;
  TTimeSignatureEvents = array of TTimeSignatureEvent;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
  end;
end;

procedure CheckBpm(const Genre, Style: string; Expected: Integer);
begin
  Check(GetDefaultBpm(Genre, Style) = Expected,
    Format('default BPM for %s/%s changed', [Genre, Style]));
end;

function ReadByte(Stream: TStream): Byte;
begin
  Stream.ReadBuffer(Result, SizeOf(Result));
end;

function ReadWordBE(Stream: TStream): Word;
begin
  Result := (Word(ReadByte(Stream)) shl 8) or ReadByte(Stream);
end;

function ReadLongWordBE(Stream: TStream): LongWord;
begin
  Result := (LongWord(ReadByte(Stream)) shl 24) or
    (LongWord(ReadByte(Stream)) shl 16) or
    (LongWord(ReadByte(Stream)) shl 8) or ReadByte(Stream);
end;

function ReadVarLen(Stream: TStream): LongWord;
var
  B: Byte;
begin
  Result := 0;
  repeat
    B := ReadByte(Stream);
    Result := (Result shl 7) or (B and $7F);
  until (B and $80) = 0;
end;

procedure AddNote(var Notes: TNoteEvents; Tick: Int64; Note: Byte);
begin
  SetLength(Notes, Length(Notes) + 1);
  Notes[High(Notes)].Tick := Tick;
  Notes[High(Notes)].Note := Note;
end;

procedure AddTimeSignature(var Events: TTimeSignatureEvents;
  Tick: Int64; Numerator: Byte; Denominator: Integer);
begin
  SetLength(Events, Length(Events) + 1);
  Events[High(Events)].Tick := Tick;
  Events[High(Events)].Numerator := Numerator;
  Events[High(Events)].Denominator := Denominator;
end;

procedure CheckBpmDefaults;
begin
  CheckBpm('metal', 'heavy', 140);
  CheckBpm('metal', 'death', 195);
  CheckBpm('metal', 'power', 160);
  CheckBpm('metal', 'progressive', 140);
  CheckBpm('metal', 'thrash', 200);
  CheckBpm('metal', 'doom', 70);
  CheckBpm('metal', 'breakdown', 100);
  CheckBpm('rock', 'classic', 120);
  CheckBpm('rock', 'blues', 100);
  CheckBpm('rock', 'alternative', 130);
  CheckBpm('rock', 'progressive', 120);
  CheckBpm('rock', 'punk', 180);
  CheckBpm('rock', 'hard', 140);
  CheckBpm('rock', 'pop', 120);
  CheckBpm('jazz', 'swing', 180);
  CheckBpm('jazz', 'bebop', 250);
  CheckBpm('jazz', 'fusion', 200);
  CheckBpm('jazz', 'latin', 160);
  CheckBpm('jazz', 'ballad', 90);
  CheckBpm('jazz', 'hard_bop', 200);
  CheckBpm('jazz', 'contemporary', 140);
  CheckBpm('funk', 'classic', 110);
  CheckBpm('funk', 'pfunk', 120);
  CheckBpm('funk', 'shuffle', 130);
  CheckBpm('funk', 'new_orleans', 140);
  CheckBpm('funk', 'fusion', 160);
  CheckBpm('funk', 'minimal', 100);
  CheckBpm('funk', 'heavy', 110);
  CheckBpm('electronic', 'house', 125);
  CheckBpm('electronic', 'techno', 130);
  CheckBpm('electronic', 'drum_and_bass', 174);
  CheckBpm('electronic', 'dubstep', 140);
end;

procedure CheckGenreTempoResolution(Generator: TDrumGenerator);
var
  Structure: TSongStructureArray;
  GeneratedSong: TSong;
begin
  SetLength(Structure, 1);
  Structure[0].Name := 'verse';
  Structure[0].Bars := 1;

  GeneratedSong := Generator.CreateSong('rock', 'blues', 0, Structure, nil, 'bonham');
  try
    Check(GeneratedSong.Tempo = 100,
      'omitted tempo must resolve to the rock/blues default');
  finally
    GeneratedSong.Free;
  end;

  GeneratedSong := Generator.CreateSong('rock', 'blues', 120, Structure, nil, 'bonham');
  try
    Check(GeneratedSong.Tempo = 120,
      'an explicit 120 BPM request must override the style default');
  finally
    GeneratedSong.Free;
  end;
end;

procedure CheckMultiBarComposition(Generator: TDrumGenerator);
var
  Structure: TSongStructureArray;
  GeneratedSong: TSong;
  Beat: TBeat;
begin
  SetLength(Structure, 1);
  Structure[0].Name := 'verse';
  Structure[0].Bars := 2;

  GeneratedSong := Generator.CreateSong('metal', 'heavy', 140, Structure, nil, 'hoglan');
  try
    Check(GeneratedSong.Sections.Count = 1, 'two-bar composition should create one section');
    Check(GeneratedSong.Sections[0].Pattern.Beats.Count > 0,
      'two-bar composition should contain generated drum hits');
    Check(GeneratedSong.Sections[0].Pattern.DurationBars <= 2,
      'multi-bar source patterns must be sliced before bars are combined');
    for Beat in GeneratedSong.Sections[0].Pattern.Beats do
      Check(Beat.Position < 8.0,
        'combined two-bar phrase must not contain duplicated overflow bars');
  finally
    GeneratedSong.Free;
  end;
end;

procedure CheckDefaultRadioDuration(Generator: TDrumGenerator);
var
  GeneratedSong: TSong;
  Genre, Style: string;
  I: Integer;
  Cases: array[0..4] of record Genre, Style: string; Tempo: Integer end;
begin
  Cases[0].Genre := 'rock'; Cases[0].Style := 'classic'; Cases[0].Tempo := 120;
  Cases[1].Genre := 'metal'; Cases[1].Style := 'doom'; Cases[1].Tempo := 70;
  Cases[2].Genre := 'jazz'; Cases[2].Style := 'bebop'; Cases[2].Tempo := 250;
  Cases[3].Genre := 'funk'; Cases[3].Style := 'minimal'; Cases[3].Tempo := 100;
  Cases[4].Genre := 'electronic'; Cases[4].Style := 'drum_and_bass'; Cases[4].Tempo := 174;

  RandSeed := 424242;
  for I := Low(Cases) to High(Cases) do
  begin
    Genre := Cases[I].Genre;
    Style := Cases[I].Style;
    GeneratedSong := Generator.CreateSong(
      Genre, Style, Cases[I].Tempo, nil, nil, '', 0.5, 0.6, 0.0);
    try
      Check((GeneratedSong.TotalDurationSeconds >= 174.0) and
        (GeneratedSong.TotalDurationSeconds <= 240.0),
        Format('default %s/%s radio duration must be between 174 and 240 seconds, got %.1f',
          [Genre, Style, GeneratedSong.TotalDurationSeconds]));
    finally
      GeneratedSong.Free;
    end;
  end;
end;

procedure ConfigureSection(Section: TSection; Numerator, Denominator: Integer);
var
  Segment: TSongSegment;
begin
  Segment := TSongSegment.Create(1);
  Segment.TimeSignature := TTimeSignature.Create(Numerator, Denominator);
  Section.Segments.Add(Segment);
  Section.ValidateSegments;
end;

procedure ReadAndCheckMidi(const FileName: string; ExpectedKick: Byte);
var
  Stream: TFileStream;
  ChunkID: array[0..3] of Char;
  ChunkLength: LongWord;
  Division: Word;
  TrackEnd: Int64;
  Tick: Int64;
  Delta: LongWord;
  Status, EventType, Data1, Data2: Byte;
  MetaLength: LongWord;
  Notes: TNoteEvents;
  TimeSignatures: TTimeSignatureEvents;
  I: Integer;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Stream.ReadBuffer(ChunkID, SizeOf(ChunkID));
    Check(ChunkID = 'MThd', 'MIDI header chunk is missing');
    ChunkLength := ReadLongWordBE(Stream);
    Check(ChunkLength = 6, 'unexpected MIDI header length');
    Check(ReadWordBE(Stream) = 0, 'expected MIDI format 0');
    Check(ReadWordBE(Stream) = 1, 'expected one MIDI track');
    Division := ReadWordBE(Stream);
    Check(Division = 960, 'song MIDI PPQ must be 960 ticks per quarter note');

    Stream.ReadBuffer(ChunkID, SizeOf(ChunkID));
    Check(ChunkID = 'MTrk', 'MIDI track chunk is missing');
    TrackEnd := Stream.Position + ReadLongWordBE(Stream);
    Tick := 0;
    SetLength(Notes, 0);
    SetLength(TimeSignatures, 0);

    while Stream.Position < TrackEnd do
    begin
      Delta := ReadVarLen(Stream);
      Inc(Tick, Delta);
      Status := ReadByte(Stream);
      if Status = $FF then
      begin
        EventType := ReadByte(Stream);
        MetaLength := ReadVarLen(Stream);
        if EventType = $58 then
        begin
          Check(MetaLength = 4, 'time-signature meta-event length must be four');
          Data1 := ReadByte(Stream);
          Data2 := ReadByte(Stream);
          AddTimeSignature(TimeSignatures, Tick, Data1, 1 shl Data2);
          Stream.Seek(2, soCurrent);
        end
        else
          Stream.Seek(MetaLength, soCurrent);
        if EventType = $2F then
          Break;
      end
      else if ((Status and $F0) = $90) or ((Status and $F0) = $80) then
      begin
        Data1 := ReadByte(Stream);
        Data2 := ReadByte(Stream);
        if ((Status and $F0) = $90) and (Data2 > 0) and (Data1 = ExpectedKick) then
          AddNote(Notes, Tick, Data1);
      end
      else
        raise Exception.CreateFmt('Unexpected MIDI status byte $%.2x', [Status]);
    end;

    Check(Length(TimeSignatures) = 2, 'expected initial and changed time signatures');
    Check((TimeSignatures[0].Tick = 0) and
      (TimeSignatures[0].Numerator = 6) and
      (TimeSignatures[0].Denominator = 8),
      'initial 6/8 signature must be present at tick zero');
    Check((TimeSignatures[1].Tick = 2880) and
      (TimeSignatures[1].Numerator = 5) and
      (TimeSignatures[1].Denominator = 4),
      '5/4 change must begin after one 6/8 measure');

    Check(Length(Notes) = 4, 'expected four kick note-on events');
    Check((Notes[0].Tick = 24) and (Notes[1].Tick = 2424) and
      (Notes[2].Tick = 2904) and (Notes[3].Tick = 7224),
      'note positions must honor quarter-note ticks, meter lengths, and per-bar groove offsets');

    for I := 0 to High(Notes) do
      Check(Notes[I].Note = ExpectedKick, 'unexpected MIDI drum note');
  finally
    Stream.Free;
  end;
end;

var
  Generator: TDrumGenerator;
  TestSong: TSong;
  Pattern68, Pattern54: TPattern;
  Section68, Section54: TSection;
  Kick: TDrumInstrument;
  OutputPath: string;
begin
  CheckBpmDefaults;
  Check(ParamCount = 1, 'pass a temporary output MIDI path');
  OutputPath := ParamStr(1);

  Generator := TDrumGenerator.Create;
  try
    CheckGenreTempoResolution(Generator);
    CheckMultiBarComposition(Generator);
    CheckDefaultRadioDuration(Generator);
    TestSong := TSong.Create('meter_export_test', 120);
    Kick := TInstrumentRegistry.Get('kick');
    Check(Assigned(Kick), 'kick instrument must be registered');

    Pattern68 := TPattern.Create('six_eight');
    Pattern68.TimeSignature.Free;
    Pattern68.TimeSignature := TTimeSignature.Create(6, 8);
    Pattern68.AddBeat(0.0, Kick, 100);
    Pattern68.AddBeat(2.5, Kick, 100);
    Check(Pattern68.DurationBars = 1, '6/8 pattern should occupy one measure');
    Section68 := TSection.Create('waltz', Pattern68, 1);
    ConfigureSection(Section68, 6, 8);
    TestSong.AddSection(Section68);

    Pattern54 := TPattern.Create('five_four');
    Pattern54.TimeSignature.Free;
    Pattern54.TimeSignature := TTimeSignature.Create(5, 4);
    Pattern54.AddBeat(0.0, Kick, 100);
    Pattern54.AddBeat(4.5, Kick, 100);
    Check(Pattern54.DurationBars = 1, '5/4 pattern should occupy one measure');
    Section54 := TSection.Create('odd_meter', Pattern54, 1);
    ConfigureSection(Section54, 5, 4);
    TestSong.AddSection(Section54);

    Check(Abs(TestSong.TotalDurationSeconds - 4.0) < 0.0001,
      'song duration must account for 6/8 and 5/4 measures');
    Section68.GrooveOffsetsMs.Add(12.5);
    Section54.GrooveOffsetsMs.Add(12.5);
    Generator.SaveSongMidi(TestSong, OutputPath);
    ReadAndCheckMidi(OutputPath, Byte(Generator.DrumKit.GetMidiNote('kick')));
  finally
    if Assigned(TestSong) then
      TestSong.Free;
    Generator.Free;
  end;
  WriteLn('PASS: BPM defaults, 6/8 to 5/4 MIDI export, and groove timing offsets');
end.
