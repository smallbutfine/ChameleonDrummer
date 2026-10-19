program test_gmd_pattern_library;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Generics.Collections, jsonparser, DrumGenerator, Song,
  GMDPatternLibrary, Pattern, PluginRegistry, DrummerPlugin;

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

function MidiContainsNote(const FileName: string; ExpectedNote: Byte): Boolean;
var
  Stream: TFileStream;
  ChunkId: array[0..3] of Char;
  TrackEnd: Int64;
  Status, EventType, Note, Velocity: Byte;
  Delta, MetaLength: LongWord;
begin
  Result := False;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Stream.ReadBuffer(ChunkId, SizeOf(ChunkId));
    Check(ChunkId = 'MThd', 'exported MIDI must have a header');
    Stream.Seek(4, soCurrent);
    Stream.Seek(6, soCurrent);
    Stream.ReadBuffer(ChunkId, SizeOf(ChunkId));
    Check(ChunkId = 'MTrk', 'exported MIDI must have a track');
    TrackEnd := Stream.Position + ReadLongWordBE(Stream);
    while Stream.Position < TrackEnd do
    begin
      Delta := ReadVarLen(Stream);
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
        if ((Status and $F0) = $90) and (Velocity > 0) and
           (Note = ExpectedNote) then
          Exit(True);
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
  SourceType, OutputPath, SignatureOutputPath: string;
  HasGMDOneBarFill, HasGMDTwoBarFill: Boolean;
  HasDrummerSignatureFill: Boolean;
  FillIndex: Integer;
  MultiBarGMDPattern: TPattern;
  SignaturePattern: TPattern;
begin
  SetLength(Structure, 1);
  Structure[0].Name := 'verse';
  Structure[0].Bars := 4;
  GeneratedSong := Generator.CreateSong(
    'funk', 'classic', 110, Structure, nil, 'chambers', 0.5, 0.6, 0.0);
  MultiBarGMDPattern := nil;
  SignaturePattern := nil;
  OutputPath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'chameleon_gmd_fill_' + IntToStr(GetTickCount64) + '.mid';
  SignatureOutputPath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'chameleon_signature_fill_' + IntToStr(GetTickCount64) + '.mid';
  try
    GeneratedSong.GlobalParameters.FillFrequency := 1.0;
    HasGMDOneBarFill := False;
    HasGMDTwoBarFill := False;
    HasDrummerSignatureFill := False;
    for Fill in GeneratedSong.Sections[0].Fills do
      if Assigned(Fill.Pattern) and
         Fill.Pattern.Metadata.TryGetValue('gmd_source_type', SourceType) and
         SameText(SourceType, 'fill') then
      if Fill.Pattern.DurationBars = 1 then
        HasGMDOneBarFill := True
      else if Fill.Pattern.DurationBars = 2 then
      begin
        HasGMDTwoBarFill := True;
        if not Assigned(MultiBarGMDPattern) then
          MultiBarGMDPattern := Fill.Pattern.Copy;
      end;
    for Fill in GeneratedSong.Sections[0].Fills do
      if Assigned(Fill.Pattern) and (Fill.Pattern.Beats.Count > 0) and
         (Pos('signature_', Fill.Pattern.Name) = 1) then
      begin
        HasDrummerSignatureFill := True;
        if not Assigned(SignaturePattern) then
          SignaturePattern := Fill.Pattern.Copy;
      end;
    Check(HasGMDOneBarFill and HasGMDTwoBarFill,
      'composer must include one- and two-bar GMD fill phrases');
    Check(HasDrummerSignatureFill,
      'composer must include the selected drummer signature fills');

    Check(Assigned(MultiBarGMDPattern),
      'composer must provide a selectable two-bar GMD fill');
    for FillIndex := GeneratedSong.Sections[0].Fills.Count - 1 downto 0 do
      GeneratedSong.Sections[0].Fills[FillIndex].Free;
    GeneratedSong.Sections[0].Fills.Clear;
    GeneratedSong.Sections[0].Fills.Add(TFill.Create(MultiBarGMDPattern));
    MultiBarGMDPattern := nil;

    Generator.SaveSongMidi(GeneratedSong, OutputPath);
    Check(MaxMidiNoteOnTick(OutputPath) <= 4 * 4 * 960,
      'two-bar fill notes must be placed within the four-bar section');

    Check(Assigned(SignaturePattern),
      'composer must provide a playable drummer signature fill');
    for FillIndex := GeneratedSong.Sections[0].Fills.Count - 1 downto 0 do
      GeneratedSong.Sections[0].Fills[FillIndex].Free;
    GeneratedSong.Sections[0].Fills.Clear;
    GeneratedSong.Sections[0].Fills.Add(TFill.Create(SignaturePattern));
    SignaturePattern := nil;
    Generator.SaveSongMidi(GeneratedSong, SignatureOutputPath);
    Check(MidiContainsNote(SignatureOutputPath,
      Byte(Generator.DrumKit.GetMidiNote('tom_4_open_hit'))),
      'scheduled drummer signature fill must be exported to MIDI');
  finally
    MultiBarGMDPattern.Free;
    SignaturePattern.Free;
    GeneratedSong.Free;
    if FileExists(OutputPath) then
      DeleteFile(OutputPath);
    if FileExists(SignatureOutputPath) then
      DeleteFile(SignatureOutputPath);
  end;
end;

procedure CheckDrummerPreferenceRegistry(Generator: TDrumGenerator);
var
  Registry: TPluginRegistry;
  Genres, Drummers, PreferredDrummers: TStringArray;
  Genre, Drummer: string;
  Plugin: TObject;
  IsPreferred, IsRegisteredPreferred: Boolean;
  GenreIndex, DrummerIndex, PreferredIndex: Integer;
begin
  Registry := Generator.PluginManager.Registry;
  Genres := Registry.GetAvailableGenres;
  Drummers := Registry.GetAvailableDrummers;
  for GenreIndex := 0 to Length(Genres) - 1 do
  begin
    Genre := Genres[GenreIndex];
    PreferredDrummers := Registry.GetPreferredDrummersForGenre(Genre);
    for DrummerIndex := 0 to Length(Drummers) - 1 do
    begin
      Drummer := Drummers[DrummerIndex];
      Plugin := Registry.GetDrummerPlugin(Drummer);
      Check(Assigned(Plugin) and (Plugin is TDrummerPlugin),
        'every registered drummer must implement TDrummerPlugin');
      IsPreferred := (Plugin as TDrummerPlugin).IsPreferredForGenre(Genre);
      IsRegisteredPreferred := False;
      for PreferredIndex := 0 to Length(PreferredDrummers) - 1 do
        if SameText(PreferredDrummers[PreferredIndex], Drummer) then
          IsRegisteredPreferred := True;
      Check(IsPreferred = IsRegisteredPreferred,
        Format('registry and drummer genre preferences must agree for %s/%s',
          [Genre, Drummer]));
    end;
    for PreferredIndex := 0 to Length(PreferredDrummers) - 1 do
      Check(Assigned(Registry.GetDrummerPlugin(PreferredDrummers[PreferredIndex])),
        Format('preferred drummer %s for %s must be registered',
          [PreferredDrummers[PreferredIndex], Genre]));
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
    CheckDrummerPreferenceRegistry(Generator);
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
