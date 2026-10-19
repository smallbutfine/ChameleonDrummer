program test_gmd_pattern_library;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Generics.Collections, jsonparser, DrumGenerator, Song,
  GMDPatternLibrary, Pattern;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
  end;
end;

procedure CheckPatterns(APatternLibrary: TGMDPatternLibrary; const Genre, Style,
  PatternType: string; Numerator, Denominator, MinimumCount: Integer);
var
  Patterns: specialize TList<TPattern>;
  PatternItem: TPattern;
  SourceId, License: string;
begin
  Patterns := APatternLibrary.GetPatterns(Genre, Style, PatternType, Numerator, Denominator);
  try
    Check(Patterns.Count >= MinimumCount,
      Format('%s/%s %s %d/%d returned %d patterns, expected at least %d',
        [Genre, Style, PatternType, Numerator, Denominator, Patterns.Count, MinimumCount]));
    for PatternItem in Patterns do
    begin
      Check(PatternItem.Beats.Count > 0, 'GMD patterns must contain drum events');
      Check(PatternItem.TimeSignature.Numerator = Numerator,
        'pattern numerator must match the requested meter');
      Check(PatternItem.TimeSignature.Denominator = Denominator,
        'pattern denominator must match the requested meter');
      Check(PatternItem.Metadata.TryGetValue('gmd_source_id', SourceId) and
        (SourceId <> ''), 'GMD source ID must be preserved');
      Check(PatternItem.Metadata.TryGetValue('gmd_license', License) and
        (License = 'CC BY 4.0'), 'GMD license metadata must be preserved');
    end;
  finally
    for PatternItem in Patterns do
      PatternItem.Free;
    Patterns.Free;
  end;
end;

function ReadByte(Stream: TStream): Byte;
begin
  Stream.ReadBuffer(Result, SizeOf(Result));
end;

function ReadLongWordBE(Stream: TStream): LongWord;
begin
  Result := (LongWord(ReadByte(Stream)) shl 24) or
    (LongWord(ReadByte(Stream)) shl 16) or
    (LongWord(ReadByte(Stream)) shl 8) or ReadByte(Stream);
end;

function ReadVarLen(Stream: TStream): LongWord;
var
  Value: Byte;
begin
  Result := 0;
  repeat
    Value := ReadByte(Stream);
    Result := (Result shl 7) or (Value and $7F);
  until (Value and $80) = 0;
end;

function MaxMidiNoteOnTick(const FileName: string): Int64;
var
  Stream: TFileStream;
  ChunkId: array[0..3] of Char;
  TrackEnd, Tick: Int64;
  Status, EventType, Note, Velocity: Byte;
  Delta, MetaLength: LongWord;
begin
  Result := 0;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Stream.ReadBuffer(ChunkId, SizeOf(ChunkId));
    Check(ChunkId = 'MThd', 'exported fill MIDI must have a header');
    Stream.Seek(4, soCurrent);
    Stream.Seek(6, soCurrent);
    Stream.ReadBuffer(ChunkId, SizeOf(ChunkId));
    Check(ChunkId = 'MTrk', 'exported fill MIDI must have a track');
    TrackEnd := Stream.Position + ReadLongWordBE(Stream);
    Tick := 0;
    while Stream.Position < TrackEnd do
    begin
      Delta := ReadVarLen(Stream);
      Inc(Tick, Delta);
      Status := ReadByte(Stream);
      if Status = $FF then
      begin
        EventType := ReadByte(Stream);
        MetaLength := ReadVarLen(Stream);
        if EventType = $2F then
          Break;
        Stream.Seek(MetaLength, soCurrent);
      end
      else if ((Status and $F0) = $90) or ((Status and $F0) = $80) then
      begin
        Note := ReadByte(Stream);
        Velocity := ReadByte(Stream);
        if ((Status and $F0) = $90) and (Velocity > 0) and (Tick > Result) then
          Result := Tick;
      end
      else
        raise Exception.CreateFmt('Unexpected MIDI status byte $%.2x', [Status]);
    end;
  finally
    Stream.Free;
  end;
end;

procedure CheckComposerFillIntegration(Generator: TDrumGenerator);
var
  Structure: TSongStructureArray;
  GeneratedSong: TSong;
  Fill: TFill;
  SourceType, OutputPath: string;
  HasGMDOneBarFill, HasGMDTwoBarFill: Boolean;
begin
  SetLength(Structure, 1);
  Structure[0].Name := 'verse';
  Structure[0].Bars := 4;
  GeneratedSong := Generator.CreateSong(
    'funk', 'classic', 110, Structure, nil, 'chambers', 0.5, 0.6, 0.0);
  OutputPath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'chameleon_gmd_fill_' + IntToStr(GetTickCount64) + '.mid';
  try
    GeneratedSong.GlobalParameters.FillFrequency := 1.0;
    HasGMDOneBarFill := False;
    HasGMDTwoBarFill := False;
    for Fill in GeneratedSong.Sections[0].Fills do
      if Assigned(Fill.Pattern) and
         Fill.Pattern.Metadata.TryGetValue('gmd_source_type', SourceType) and
         SameText(SourceType, 'fill') then
      if Fill.Pattern.DurationBars = 1 then
        HasGMDOneBarFill := True
      else if Fill.Pattern.DurationBars = 2 then
        HasGMDTwoBarFill := True;
    Check(HasGMDOneBarFill and HasGMDTwoBarFill,
      'composer must include one- and two-bar GMD fill phrases');

    Generator.SaveSongMidi(GeneratedSong, OutputPath);
    Check(MaxMidiNoteOnTick(OutputPath) <= 4 * 4 * 960,
      'fill notes must remain within the four-bar section');
  finally
    GeneratedSong.Free;
    if FileExists(OutputPath) then
      DeleteFile(OutputPath);
  end;
end;

var
  Generator: TDrumGenerator;
  GMDLibrary: TGMDPatternLibrary;
  Patterns: specialize TList<TPattern>;
  PatternItem: TPattern;
  HasMultiBarBeat: Boolean;
begin
  Generator := TDrumGenerator.Create;
  try
    GMDLibrary := TGMDPatternLibrary.Create('Assets\GMD\gmd_patterns.json');
    try
      CheckPatterns(GMDLibrary, 'rock', 'blues', 'beat', 4, 4, 1);
      CheckPatterns(GMDLibrary, 'metal', 'heavy', 'beat', 4, 4, 1);
      CheckPatterns(GMDLibrary, 'funk', 'classic', 'fill', 4, 4, 1);
      CheckPatterns(GMDLibrary, 'jazz', 'swing', 'beat', 3, 4, 1);
      CheckPatterns(GMDLibrary, 'rock', 'classic', 'beat', 6, 8, 1);
      CheckPatterns(GMDLibrary, 'rock', 'progressive', 'beat', 5, 4, 1);
      CheckPatterns(GMDLibrary, 'jazz', 'latin', 'beat', 5, 8, 1);
      CheckPatterns(GMDLibrary, 'jazz', 'swing', 'fill', 3, 4, 0);
      Patterns := GMDLibrary.GetPatterns('rock', 'classic', 'beat', 4, 4);
      try
        HasMultiBarBeat := False;
        for PatternItem in Patterns do
          if PatternItem.DurationBars > 1 then
            HasMultiBarBeat := True;
        Check(HasMultiBarBeat,
          'GMD beat selection must retain multi-bar performance phrases');
      finally
        for PatternItem in Patterns do
          PatternItem.Free;
        Patterns.Free;
      end;
      CheckComposerFillIntegration(Generator);
    finally
      GMDLibrary.Free;
    end;
  finally
    Generator.Free;
  end;
  WriteLn('PASS: GMD corpus metadata, genre/style selection, fills, and meter filtering');
end.
