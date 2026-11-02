program midi_to_tab;

{$mode objfpc}{$H+}

{ midi_to_tab — Convert a MIDI file to ChameleonDrummer .tab groove/fill format.

  Usage:
    midi_to_tab input.mid [output.tab]
    midi_to_tab input.mid --fill --name bonham_fill --energy 0.6
    midi_to_tab input.mid --meter 7/8 --resolution 16
    midi_to_tab input.mid --mapping mappings/ad2.json
    midi_to_tab input.mid -ad2 --style metal --kind verse --intensity 0.2-0.6
    midi_to_tab input.mid -gm -ezd3 -xg -template

  Reads MIDI notes (channel 10 / percussion zone), quantizes to a grid, groups
  into bars, and writes [style kind intensity=...] or [name energy=...] blocks.
  Supports GM and AD2 (extended) mappings via JSON files in the mappings folder.
  Short flags (-ad2, -gm, -ezd3, -xg, -template, ...) are auto-discovered from
  the mappings/ directory.

  Self-contained MIDI parser — no modifications to src/ units required.
}

uses
  SysUtils, Classes, fpjson, jsonparser, Math;

type
  TMidiEvent = record
    DeltaTick: Int64;
    Status: Byte;
    Note: Byte;
    Velocity: Byte;
  end;

  TMidiEventArray = array of TMidiEvent;

  TInstAbbr = record
    MidiNote: Integer;
    Abbr: string;
  end;

  TInstMap = array of TInstAbbr;

  TInstCharEntry = record
    Abbr: string;
    Chars: array of Char;
  end;

  TBarGrid = record
    InstChars: array of TInstCharEntry;
  end;

  TBarGridArray = array of TBarGrid;

  TMapFlag = record
    Flag: string;   { e.g. "-ad2" }
    Path: string;   { e.g. "mappings/ad2.json" }
  end;

  TMapFlags = array of TMapFlag;

const
  VEL_GHOST = 32;
  VEL_SOFT  = 64;
  VEL_ACCENT = 96;

  INST_ORDER: array[0..16] of string = (
    'K', 'S', 'RS', 'SS', 'H', 'HO', 'HP', 'R', 'RB', 'C', 'C2', 'CH', 'SP',
    'T1', 'T2', 'T3', 'T4'
  );

{ ------------------------------------------------------------------ }
{ Velocity -> step character                                         }
{ ------------------------------------------------------------------ }

function VelToChar(Vel: Byte): Char;
begin
  if Vel < VEL_GHOST then
    Result := 'g'
  else if Vel < VEL_SOFT then
    Result := 'o'
  else if Vel >= VEL_ACCENT then
    Result := 'X'
  else
    Result := 'x';
end;

{ ------------------------------------------------------------------ }
{ Instrument abbreviation from AD2/GM instrument name                }
{ ------------------------------------------------------------------ }

function InstrumentAbbr(const Name: string): string;
var
  N: string;
begin
  N := LowerCase(Name);
  if (Pos('kick', N) > 0) or (Pos('bass_drum', N) > 0) then
    Exit('K');
  if (Pos('snare', N) > 0) and (Pos('rim', N) = 0) and (Pos('side', N) = 0) then
    Exit('S');
  if (Pos('rimshot', N) > 0) or (Pos('rim_shot', N) > 0) then
    Exit('RS');
  if Pos('side_stick', N) > 0 then
    Exit('SS');
  if (Pos('hihat_closed', N) > 0) or (Pos('hihat_pedal_closed', N) > 0) then
    Exit('H');
  if Pos('hihat_open', N) > 0 then
    Exit('HO');
  if (Pos('hihat_pedal', N) > 0) and (Pos('open', N) = 0) then
    Exit('HP');
  if (Pos('ride', N) > 0) and (Pos('bell', N) > 0) then
    Exit('RB');
  if Pos('ride', N) > 0 then
    Exit('R');
  if Pos('crash', N) > 0 then
    Exit('C');
  if Pos('china', N) > 0 then
    Exit('CH');
  if Pos('splash', N) > 0 then
    Exit('SP');
  if (Pos('tom_1', N) > 0) or (Pos('high_tom', N) > 0) then
    Exit('T1');
  if Pos('tom_2', N) > 0 then
    Exit('T2');
  if (Pos('tom_3', N) > 0) or (Pos('hi_mid_tom', N) > 0) then
    Exit('T3');
  if (Pos('tom_4', N) > 0) or (Pos('low_floor_tom', N) > 0) then
    Exit('T4');
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ FileToStr — read entire file into string                           }
{ ------------------------------------------------------------------ }

function FileToStr(const AFileName: string): string;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Pointer(Result)^, LStream.Size);
  finally
    LStream.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ DiscoverMappingFlags — scan mappings/ for *.json files and build   }
{ short flags like -ad2, -gm, -ezd3, -xg, -template                  }
{ ------------------------------------------------------------------ }

procedure DiscoverMappingFlags(out Flags: TMapFlags);
var
  SR: TSearchRec;
  NameOnly: string;
  I: Integer;
begin
  Flags := nil;
  if FindFirst('mappings' + PathDelim + '*.json', faAnyFile, SR) = 0 then
  begin
    repeat
      { Strip .json extension and build flag like -ad2 }
      NameOnly := SR.Name;
      I := Pos('.json', NameOnly);
      if I > 0 then
        NameOnly := Copy(NameOnly, 1, I - 1);
      SetLength(Flags, Length(Flags) + 1);
      Flags[High(Flags)].Flag := '-' + LowerCase(NameOnly);
      Flags[High(Flags)].Path := 'mappings' + PathDelim + SR.Name;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ ------------------------------------------------------------------ }
{ Load mapping JSON -> array of (midi_note, abbr)                  }
{ ------------------------------------------------------------------ }

function LoadMapping(const Path: string; out Map: TInstMap): Boolean;
var
  JDoc: TJSONData;
  JObj: TJSONObject;
  InstObj: TJSONObject;
  I, J, N: Integer;
  NoteVal: Int64;
  Abbr: string;
  KeyName: string;
  JVal, JVal2: TJSONData;
  Found: Boolean;
begin
  Result := False;
  Map := nil;
  if Path = '' then Exit;
  if not FileExists(Path) then Exit;

  try
    JDoc := GetJSON(FileToStr(Path));
    if (JDoc = nil) or not (JDoc is TJSONObject) then
    begin
      if JDoc <> nil then JDoc.Free;
      Exit;
    end;
    try
      JObj := TJSONObject(JDoc);
      N := 0;
      Found := JObj.Find('instruments', InstObj);
      if Found then
        for I := 0 to InstObj.Count - 1 do
        begin
          KeyName := InstObj.Names[I];
          NoteVal := 0;
          JVal := InstObj.Items[I];
          if JVal is TJSONObject then
          begin
            for J := 0 to TJSONObject(JVal).Count - 1 do
              if TJSONObject(JVal).Names[J] = 'midi_note' then
              begin
                JVal2 := TJSONObject(JVal).Items[J];
                if JVal2 is TJSONIntegerNumber then
                  NoteVal := TJSONIntegerNumber(JVal2).AsInt64
                else if JVal2 is TJSONNumber then
                  NoteVal := TJSONNumber(JVal2).AsInt64;
                Break;
              end;
          end
          else if JVal is TJSONIntegerNumber then
            NoteVal := TJSONIntegerNumber(JVal).AsInt64
          else if JVal is TJSONNumber then
            NoteVal := TJSONNumber(JVal).AsInt64;
          Abbr := InstrumentAbbr(KeyName);
          if Abbr <> '' then
          begin
            SetLength(Map, N + 1);
            Map[N].MidiNote := NoteVal;
            Map[N].Abbr := Abbr;
            Inc(N);
          end;
        end;
      Result := True;
    finally
      JDoc.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('Warning: could not load mapping "', Path, '": ', E.Message);
    end;
  end;
end;

function FindAbbr(const Map: TInstMap; MidiNote: Integer; out Abbr: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  Abbr := '';
  for I := 0 to High(Map) do
    if Map[I].MidiNote = MidiNote then
    begin
      Abbr := Map[I].Abbr;
      Exit(True);
    end;
end;

{ ------------------------------------------------------------------ }
{ Default GM mapping (fallback)                                      }
{ ------------------------------------------------------------------ }

procedure DefaultGMMap(out Map: TInstMap);
const
  GM_COUNT = 47;
  GM_NOTES: array[0..GM_COUNT-1] of record
    Note: Integer;
    Abbr: string;
  end = (
    (Note: 35; Abbr: 'K'),  (Note: 36; Abbr: 'K'),
    (Note: 37; Abbr: 'SS'), (Note: 38; Abbr: 'S'),  (Note: 39; Abbr: 'S'),  (Note: 40; Abbr: 'RS'),
    (Note: 41; Abbr: 'T4'), (Note: 42; Abbr: 'H'),  (Note: 43; Abbr: 'T3'), (Note: 44; Abbr: 'HP'),
    (Note: 45; Abbr: 'T2'), (Note: 46; Abbr: 'HO'), (Note: 47; Abbr: 'T2'), (Note: 48; Abbr: 'T3'),
    (Note: 49; Abbr: 'C'),  (Note: 50; Abbr: 'T1'), (Note: 51; Abbr: 'R'),  (Note: 52; Abbr: 'CH'),
    (Note: 53; Abbr: 'RB'), (Note: 54; Abbr: 'SP'), (Note: 55; Abbr: 'SP'), (Note: 56; Abbr: 'C2'),
    (Note: 57; Abbr: 'C2'), (Note: 58; Abbr: 'T1'), (Note: 59; Abbr: 'R'),
    (Note: 60; Abbr: 'T1'), (Note: 61; Abbr: 'RB'), (Note: 62; Abbr: 'C'),  (Note: 63; Abbr: 'C'),
    (Note: 64; Abbr: 'C'),  (Note: 65; Abbr: 'T4'), (Note: 66; Abbr: 'T4'), (Note: 67; Abbr: 'CH'),
    (Note: 68; Abbr: 'SP'), (Note: 69; Abbr: 'C'),  (Note: 70; Abbr: 'C'),  (Note: 71; Abbr: 'C'),
    (Note: 72; Abbr: 'C'),  (Note: 73; Abbr: 'C'),  (Note: 74; Abbr: 'C'),  (Note: 75; Abbr: 'SP'),
    (Note: 76; Abbr: 'SP'), (Note: 77; Abbr: 'SP'), (Note: 78; Abbr: 'SP'), (Note: 79; Abbr: 'SP'),
    (Note: 80; Abbr: 'SP'), (Note: 81; Abbr: 'SP')
  );
var
  I: Integer;
begin
  SetLength(Map, GM_COUNT);
  for I := 0 to GM_COUNT - 1 do
  begin
    Map[I].MidiNote := GM_NOTES[I].Note;
    Map[I].Abbr := GM_NOTES[I].Abbr;
  end;
end;

{ ------------------------------------------------------------------ }
{ Self-contained MIDI parser                                         }
{ ------------------------------------------------------------------ }

function ReadVLQ(Stream: TStream; out Value: Int64): Boolean;
var
  b: Byte;
begin
  Result := False;
  Value := 0;
  repeat
    if Stream.Read(b, 1) = 0 then Exit;
    Value := (Value shl 7) or (b and $7F);
    Result := True;
  until (b and $80) = 0;
end;

function LoadMidiFile(const FileName: string; out Events: TMidiEventArray; out PPQ: Integer): Boolean;
var
  FS: TFileStream;
  Header: array[0..3] of Char;
  ChunkSize: Cardinal;
  Delta, AbsoluteTick: Int64;
  uStatus, uLastStatus, uMetaType, uNote, uVel, uReadByte: Byte;
  Division: Word;
  TrackStart: Int64;
  I: Integer;
begin
  Result := False;
  Events := nil;
  PPQ := 480;

  if not FileExists(FileName) then Exit;

  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    { MIDI Header }
    if (FS.Read(Header, 4) < 4) or (Header <> 'MThd') then Exit;
    FS.Seek(8, soFromCurrent); { Skip size(4) + format(2) + ntracks(2) }
    FS.Read(Division, 2);
    PPQ := ((Division and $FF) shl 8) or ((Division and $FF00) shr 8);

    { Track scanning }
    while FS.Position < FS.Size - 8 do
    begin
      if FS.Read(Header, 4) < 4 then Break;
      FS.Read(ChunkSize, 4);
      ChunkSize := ((ChunkSize and $FF) shl 24) or
                   ((ChunkSize and $FF00) shl 8) or
                   ((ChunkSize and $FF0000) shr 8) or
                   ((ChunkSize and $FF000000) shr 24);
      TrackStart := FS.Position;

      if Header = 'MTrk' then
      begin
        AbsoluteTick := 0;
        uLastStatus := 0;
        while FS.Position < TrackStart + ChunkSize do
        begin
          if not ReadVLQ(FS, Delta) then Break;
          AbsoluteTick := AbsoluteTick + Delta;

          if FS.Read(uReadByte, 1) = 0 then Break;

          { Running status }
          if uReadByte >= $80 then
          begin
            uStatus := uReadByte;
            if uReadByte < $F0 then uLastStatus := uReadByte;
          end else
          begin
            uStatus := uLastStatus;
            FS.Seek(-1, soFromCurrent);
          end;

          { Note-On }
          if (uStatus >= $90) and (uStatus <= $9F) then
          begin
            FS.Read(uNote, 1);
            FS.Read(uVel, 1);

            if ((uStatus and $0F) = 9) and (uVel > 0) then
            begin
              SetLength(Events, Length(Events) + 1);
              I := High(Events);
              Events[I].DeltaTick := AbsoluteTick;
              Events[I].Status := uStatus;
              Events[I].Note := uNote;
              Events[I].Velocity := uVel;
            end;
          end
          else if (uStatus >= $80) and (uStatus <= $EF) then
          begin
            if uStatus in [$C0..$DF] then FS.Seek(1, soFromCurrent)
            else FS.Seek(2, soFromCurrent);
          end
          else if uStatus = $FF then
          begin
            FS.Read(uMetaType, 1);
            if not ReadVLQ(FS, Delta) then Break;
            FS.Seek(Delta, soFromCurrent);
          end
          else if uStatus in [$F0, $F7] then
          begin
            if not ReadVLQ(FS, Delta) then Break;
            FS.Seek(Delta, soFromCurrent);
          end;
        end;
      end;
      FS.Position := TrackStart + ChunkSize;
    end;

    Result := True;
  finally
    FS.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ Convert MIDI events to tab grid data                               }
{ ------------------------------------------------------------------ }

procedure ConvertMidiToTab(const Events: array of TMidiEvent; PPQ: Integer;
  MeterNum, MeterDen, Resolution: Integer; const Map: TInstMap;
  out StepsPerBar: Integer; out Bars: TBarGridArray);
var
  StepTicks: Double;
  I, Step, BarIdx, StepInBar: Integer;
  Abbr: string;
  C: Char;
  Existing: Char;
  J, K, LIdx: Integer;
  Found: Boolean;
  Idx: Integer;
begin
  StepsPerBar := MeterNum * Resolution div MeterDen;
  if StepsPerBar < 1 then
    StepsPerBar := Resolution;

  StepTicks := PPQ * 4.0 / Resolution;

  Bars := nil;

  for I := 0 to High(Events) do
  begin
    if not FindAbbr(Map, Events[I].Note, Abbr) then
      Continue;

    Step := Round(Events[I].DeltaTick / StepTicks);
    BarIdx := Step div StepsPerBar;
    StepInBar := Step mod StepsPerBar;

    while Length(Bars) <= BarIdx do
    begin
      SetLength(Bars, Length(Bars) + 1);
      Bars[High(Bars)].InstChars := nil;
    end;

    { Find or create instrument entry in this bar }
    Found := False;
    for J := 0 to High(Bars[BarIdx].InstChars) do
      if Bars[BarIdx].InstChars[J].Abbr = Abbr then
      begin
        Found := True;
        Break;
      end;

    if not Found then
    begin
      Idx := Length(Bars[BarIdx].InstChars);
      SetLength(Bars[BarIdx].InstChars, Idx + 1);
      Bars[BarIdx].InstChars[Idx].Abbr := Abbr;
      SetLength(Bars[BarIdx].InstChars[Idx].Chars, StepsPerBar);
      for K := 0 to StepsPerBar - 1 do
        Bars[BarIdx].InstChars[Idx].Chars[K] := '.';
      J := Idx;
    end;

    C := VelToChar(Events[I].Velocity);
    Existing := Bars[BarIdx].InstChars[J].Chars[StepInBar];
    if (Existing = '.') or ((C = 'X') and (Existing <> 'X')) then
      Bars[BarIdx].InstChars[J].Chars[StepInBar] := C;
  end;
end;

{ ------------------------------------------------------------------ }
{ Write tab output                                                   }
{ ------------------------------------------------------------------ }

procedure WriteTab(const Bars: TBarGridArray; StepsPerBar, MeterNum, MeterDen,
  Resolution: Integer; Mode: string; HeaderWords: array of string;
  IntensityLow, IntensityHigh: Double; FillName: string; FillEnergy: Double;
  var Output: string);
var
  Lines: TStringList;
  BarStrings: TStringList;
  I, J, K, StepsPerUnit, LIdx: Integer;
  Grouped: string;
  Inst: string;
  Header: string;
  Found: Boolean;
  HW0, HW1: string;
begin
  Lines := TStringList.Create;
  BarStrings := TStringList.Create;
  try
    { Build header }
    if Mode = 'fill' then
      Header := Format('[%s energy=%.2f]', [FillName, FillEnergy])
    else
    begin
      if Length(HeaderWords) = 0 then
      begin
        HW0 := 'midi';
        HW1 := 'verse';
      end
      else
      begin
        HW0 := HeaderWords[0];
        if Length(HeaderWords) > 1 then
          HW1 := HeaderWords[1]
        else
          HW1 := 'verse';
      end;
      Header := Format('[%s %s intensity=%.2f-%.2f]',
        [HW0, HW1, IntensityLow, IntensityHigh]);
    end;
    Lines.Add(Header);

    StepsPerUnit := Max(1, Resolution div MeterDen);

    for I := 0 to High(INST_ORDER) do
    begin
      Inst := INST_ORDER[I];
      BarStrings.Clear;
      for J := 0 to High(Bars) do
      begin
        Grouped := '';
        Found := False;
        for K := 0 to High(Bars[J].InstChars) do
          if Bars[J].InstChars[K].Abbr = Inst then
          begin
            Found := True;
            Break;
          end;
        if Found then
        begin
          for K := 0 to High(Bars[J].InstChars) do
            if Bars[J].InstChars[K].Abbr = Inst then
            begin
              for LIdx := 0 to StepsPerBar - 1 do
              begin
                if (LIdx > 0) and (LIdx mod StepsPerUnit = 0) then
                  Grouped := Grouped + ' ';
                Grouped := Grouped + Bars[J].InstChars[K].Chars[LIdx];
              end;
              Break;
            end;
        end;
        if Grouped = '' then
        begin
          Grouped := '';
          for LIdx := 0 to StepsPerBar - 1 do
          begin
            if (LIdx > 0) and (LIdx mod StepsPerUnit = 0) then
              Grouped := Grouped + ' ';
            Grouped := Grouped + '.';
          end;
        end;
        BarStrings.Add(Grouped);
      end;
      Lines.Add(Format('%-4s  %s', [Inst,
        StringReplace(BarStrings.CommaText, ',', ' | ', [rfReplaceAll])]));
    end;

    Output := Lines.Text;
    if Output <> '' then
      Output := Output + #13#10;
  finally
    Lines.Free;
    BarStrings.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ CLI parsing                                                        }
{ ------------------------------------------------------------------ }

procedure PrintUsage(const MapFlags: TMapFlags);
var
  I: Integer;
begin
  WriteLn('midi_to_tab — Convert a MIDI file to ChameleonDrummer .tab format.');
  WriteLn('');
  WriteLn('Usage:');
  WriteLn('  midi_to_tab input.mid [output.tab]');
  WriteLn('  midi_to_tab input.mid --fill --name bonham_fill --energy 0.6');
  WriteLn('  midi_to_tab input.mid --meter 7/8 --resolution 16');
  WriteLn('  midi_to_tab input.mid --mapping mappings/ad2.json');
  WriteLn('  midi_to_tab input.mid -ad2 --style metal --kind verse --intensity 0.2-0.6');
  WriteLn('');
  WriteLn('Options:');
  WriteLn('  --fill              Treat as fill block (energy header)');
  WriteLn('  --name NAME         Fill name (default: fill)');
  WriteLn('  --energy VAL        Fill energy 0.0-1.0 (default: 0.5)');
  WriteLn('  --meter N/D         Time signature (default: 4/4)');
  WriteLn('  --resolution N      Grid resolution 4, 8, 16, 32 (default: 16)');
  WriteLn('  --mapping PATH      JSON mapping file path');
  for I := 0 to High(MapFlags) do
    WriteLn('  ' + MapFlags[I].Flag + '      Use mapping ' + MapFlags[I].Path);
  WriteLn('  --style WORD        Style word for groove header');
  WriteLn('  --kind WORD         Kind word for groove header');
  WriteLn('  --intensity LOW-HIGH Intensity range (default: 0.2-0.6)');
end;

var
  InputPath, OutputPath: string;
  Mode: string;
  MeterStr: string;
  Resolution: Integer;
  MappingPath: string;
  MapFlags: TMapFlags;
  HeaderWords: array of string;
  IntensityLow, IntensityHigh: Double;
  FillName: string;
  FillEnergy: Double;
  MeterNum, MeterDen: Integer;
  Events: TMidiEventArray;
  PPQ: Integer;
  Map: TInstMap;
  UseDefaultMap: Boolean;
  StepsPerBar: Integer;
  Bars: TBarGridArray;
  Output: string;
  F: TextFile;
  I, J: Integer;
  P: Integer;
  A, B: string;
  IntensityStr: string;
begin
  if ParamCount = 0 then
  begin
    DiscoverMappingFlags(MapFlags);
    PrintUsage(MapFlags);
    Halt(0);
  end;

  InputPath := '';
  OutputPath := '';
  Mode := 'groove';
  MeterStr := '';
  Resolution := 16;
  MappingPath := '';
  MapFlags := nil;
  HeaderWords := nil;
  IntensityLow := 0.2;
  IntensityHigh := 0.6;
  FillName := 'fill';
  FillEnergy := 0.5;

  { Auto-discover mapping flags from mappings/ directory }
  DiscoverMappingFlags(MapFlags);

  I := 1;
  while I <= ParamCount do
  begin
    if ParamStr(I) = '--fill' then
      Mode := 'fill'
    else if ParamStr(I) = '--name' then
    begin
      Inc(I);
      if I <= ParamCount then FillName := ParamStr(I);
    end
    else if ParamStr(I) = '--energy' then
    begin
      Inc(I);
      if I <= ParamCount then FillEnergy := StrToFloatDef(ParamStr(I), 0.5);
    end
    else if ParamStr(I) = '--meter' then
    begin
      Inc(I);
      if I <= ParamCount then MeterStr := ParamStr(I);
    end
    else if ParamStr(I) = '--resolution' then
    begin
      Inc(I);
      if I <= ParamCount then Resolution := StrToIntDef(ParamStr(I), 16);
    end
    else if ParamStr(I) = '--mapping' then
    begin
      Inc(I);
      if I <= ParamCount then MappingPath := ParamStr(I);
    end
    else if ParamStr(I) = '--style' then
    begin
      Inc(I);
      if I <= ParamCount then
      begin
        SetLength(HeaderWords, Length(HeaderWords) + 1);
        HeaderWords[High(HeaderWords)] := ParamStr(I);
      end;
    end
    else if ParamStr(I) = '--kind' then
    begin
      Inc(I);
      if I <= ParamCount then
      begin
        SetLength(HeaderWords, Length(HeaderWords) + 1);
        HeaderWords[High(HeaderWords)] := ParamStr(I);
      end;
    end
    else if ParamStr(I) = '--intensity' then
    begin
      Inc(I);
      if I <= ParamCount then
      begin
        IntensityStr := ParamStr(I);
        P := Pos('-', IntensityStr);
        if P > 0 then
        begin
          A := Copy(IntensityStr, 1, P - 1);
          B := Copy(IntensityStr, P + 1, MaxInt);
          IntensityLow := StrToFloatDef(A, 0.2);
          IntensityHigh := StrToFloatDef(B, 0.6);
        end
        else
          IntensityLow := StrToFloatDef(IntensityStr, 0.2);
      end
    end
    else
    begin
      { Check for mapping short flags like -ad2, -gm, -ezd3, -xg }
      for J := 0 to High(MapFlags) do
        if ParamStr(I) = MapFlags[J].Flag then
        begin
          MappingPath := MapFlags[J].Path;
          Break;
        end;
      if ParamStr(I)[1] = '-' then
      begin
        { skip unknown flags }
      end
      else
      begin
        if InputPath = '' then
          InputPath := ParamStr(I)
        else
          OutputPath := ParamStr(I);
      end;
    end;
    Inc(I);
  end;

  { Determine meter }
  MeterNum := 4;
  MeterDen := 4;
  if MeterStr <> '' then
  begin
    P := Pos('/', MeterStr);
    if P > 0 then
    begin
      A := Copy(MeterStr, 1, P - 1);
      B := Copy(MeterStr, P + 1, MaxInt);
      MeterNum := StrToIntDef(A, 4);
      MeterDen := StrToIntDef(B, 4);
    end;
  end;

  { Load MIDI }
  if not LoadMidiFile(InputPath, Events, PPQ) then
  begin
    WriteLn('Error: could not read MIDI file: ', InputPath);
    Halt(1);
  end;
  if Length(Events) = 0 then
  begin
    WriteLn('Error: no drum notes found in MIDI file: ', InputPath);
    Halt(1);
  end;

  { Load mapping }
  UseDefaultMap := False;
  if MappingPath <> '' then
  begin
    if not LoadMapping(MappingPath, Map) then
    begin
      WriteLn('Warning: failed to load mapping "', MappingPath, '", using default GM map.');
      UseDefaultMap := True;
    end
  end
  else
    UseDefaultMap := True;

  if UseDefaultMap then
    DefaultGMMap(Map);

  { Convert }
  ConvertMidiToTab(Events, PPQ, MeterNum, MeterDen,
    Resolution, Map, StepsPerBar, Bars);

  { Write output }
  WriteTab(Bars, StepsPerBar, MeterNum, MeterDen, Resolution,
    Mode, HeaderWords, IntensityLow, IntensityHigh, FillName, FillEnergy, Output);

  if OutputPath <> '' then
  begin
    AssignFile(F, OutputPath);
    Rewrite(F);
    Write(F, Output);
    CloseFile(F);
    WriteLn('Wrote ', OutputPath, ' (', Length(Events),
      ' notes -> ', Length(Bars), ' bars, ', MeterNum, '/', MeterDen,
      ', ', StepsPerBar, ' steps/bar)');
  end
  else
    Write(Output);
end.
