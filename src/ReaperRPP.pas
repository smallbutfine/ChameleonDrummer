unit ReaperRPP;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, StrUtils;

// ============================================================================
// TReaperMarker — a marker or a region in a .rpp project.
//
// Positions are in SECONDS, which is what REAPER stores in a project file:
//   MARKER    <id> <position>            "<name>" <color> <flags>
//   RPR_MARKER <id> <start> <end>        "<name>" <color> <flags>
// ============================================================================
type
  TReaperMarker = record
    Position: Double;
    EndPosition: Double;
    Name: String;
    IsRegion: Boolean;
  end;

// ============================================================================
// TReaperTempoPoint - one point of the project tempo envelope (<TEMPOENVEX).
// Position is in SECONDS. SetsMeter says whether the point also sets the time
// signature (REAPER packs it as 65536 * denominator + numerator).
// ============================================================================
type
  TReaperTempoPoint = record
    Position: Double;
    BPM: Integer;
    Num: Integer;
    Denom: Integer;
    SetsMeter: Boolean;
  end;

// ============================================================================
// TReaperRPPReader — parses .rpp files to extract markers and regions
// ============================================================================
type
  TReaperRPPReader = class
  private
    FMarkers: specialize TList<TReaperMarker>;
    function ParseMarkerLine(const Line: String): TReaperMarker;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromFile(const AFilePath: String): Boolean;
    function GetMarkers: specialize TList<TReaperMarker>;
  end;

// ============================================================================
// TReaperRPPWriter — writes .rpp project files
// ============================================================================
type
  TReaperRPPWriter = class
  private
    FMarkers: specialize TList<TReaperMarker>;
    FTitle: String;
    FTempo: Integer;
    FTempoNum: Integer;
    FTempoDenom: Integer;
    FTrackName: String;
    FMIDILength: Double;
    FTempoPoints: specialize TList<TReaperTempoPoint>;
    function EscapeRPPString(const S: String): String;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetTitle(const ATitle: String);
    procedure SetTempo(ABPM, ANumerator, ADenominator: Integer);
    procedure SetMIDITrack(const AName: String; ALengthSeconds: Double);
    procedure AddMarker(APosition: Double; const AMarkerName: String);
    procedure AddRegion(AStart, AEnd: Double; const ARegionName: String);
    procedure ClearMarkers;
    { The first point is the song's starting tempo, the following ones are the
      changes. The envelope is only written when there is more than one point,
      so a song at one tempo keeps its plain TEMPO line. }
    procedure AddTempoPoint(APosition: Double; ABPM, ANumerator, ADenominator: Integer;
      ASetsMeter: Boolean);
    procedure ClearTempoPoints;

    function SaveToFile(const AFilePath: String; const AMIDIFile: String): Boolean;
    function GetMarkers: specialize TList<TReaperMarker>;
    function TempoPointCount: Integer;
  end;

implementation

{ REAPER project files always use a full stop as the decimal separator and
  positions are plain seconds, regardless of the machine's locale. }
function FormatRPPFloat(Value: Double): String;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.000000', Value, FS);
end;

{ REAPER identifies tracks and items by GUID. Generate stable ones from a
  seed so that re-exporting the same project keeps the same ids. }
function MakeGUID(const Seed: String): String;
var
  H: QWord;
  I, K: Integer;
  B: array[0..15] of Byte;
  V1, V2, V3, V4, V5: QWord;
begin
  H := 14695981039346656037;
  for I := 1 to Length(Seed) do
  begin
    H := H xor QWord(Byte(Seed[I]));
    H := H * 1099511628211;
  end;
  for K := 0 to 15 do
  begin
    B[K] := Byte(H and $FF);
    H := H shr 8;
    if H = 0 then
      H := 14695981039346656037;
  end;
  V1 := (QWord(B[0]) shl 24) or (QWord(B[1]) shl 16) or (QWord(B[2]) shl 8) or QWord(B[3]);
  V2 := (QWord(B[4]) shl 8) or QWord(B[5]);
  V3 := (QWord(B[6]) shl 8) or QWord(B[7]);
  V4 := (QWord(B[8]) shl 8) or QWord(B[9]);
  V5 := (QWord(B[10]) shl 24) or (QWord(B[11]) shl 16) or (QWord(B[12]) shl 8) or
        (QWord(B[13]) shl 32) or (QWord(B[14]) shl 40) or QWord(B[15]);
  Result := Format('%.8X-%.4X-%.4X-%.4X-%.12X',
    [Int64(V1 and $FFFFFFFF), Int64(V2), Int64(V3), Int64(V4), Int64(V5)]);
end;

function ParseRPPFloat(const S: String; out Value: Double): Boolean;
var
  FS: TFormatSettings;
  T: String;
begin
  FS := DefaultFormatSettings;
  T := S;
  if FS.DecimalSeparator <> '.' then
    T := StringReplace(T, '.', FS.DecimalSeparator, [rfReplaceAll]);
  Result := TryStrToFloat(T, Value, FS);
end;

// ============================================================================
// TReaperRPPReader
// ============================================================================

constructor TReaperRPPReader.Create;
begin
  FMarkers := specialize TList<TReaperMarker>.Create;
end;

destructor TReaperRPPReader.Destroy;
begin
  FMarkers.Free;
  inherited Destroy;
end;

function TReaperRPPReader.ParseMarkerLine(const Line: String): TReaperMarker;
var
  IsRegion: Boolean;
  Rest, Token: String;
  I: Integer;
  Ch: Char;
  InQuote: Boolean;
  Tokens: TStringList;
begin
  Result.IsRegion := False;
  Result.Position := 0.0;
  Result.EndPosition := 0.0;
  Result.Name := '';

  if Pos('RPR_MARKER', Line) > 0 then
  begin
    IsRegion := True;
    Rest := Copy(Line, Pos('RPR_MARKER', Line) + Length('RPR_MARKER'), MaxInt);
  end
  else if Pos('MARKER', Line) > 0 then
  begin
    IsRegion := False;
    Rest := Copy(Line, Pos('MARKER', Line) + Length('MARKER'), MaxInt);
  end
  else
    Exit;

  { Split into whitespace separated tokens, honouring double quotes. }
  Tokens := TStringList.Create;
  try
    Token := '';
    InQuote := False;
    for I := 1 to Length(Rest) do
    begin
      Ch := Rest[I];
      if Ch = '"' then
        InQuote := not InQuote
      else if (not InQuote) and (Ch in [' ', #9]) then
      begin
        if Token <> '' then
        begin
          Tokens.Add(Token);
          Token := '';
        end;
      end
      else
        Token := Token + Ch;
    end;
    if Token <> '' then
      Tokens.Add(Token);

    { MODERN: MARKER <id> <pos> <name> <color> <flags>
      REGION:  RPR_MARKER <id> <start> <end> <name> <color> <flags>
      LEGACY:  MARKER <measure> "<name>" }
    if (Tokens.Count >= 3) and ParseRPPFloat(Tokens[1], Result.Position) then
    begin
      if IsRegion and (Tokens.Count >= 4) and
         ParseRPPFloat(Tokens[2], Result.EndPosition) then
        Result.Name := Tokens[3]
      else
        Result.Name := Tokens[2];
      Result.IsRegion := IsRegion;
    end;
  finally
    Tokens.Free;
  end;
end;

function TReaperRPPReader.LoadFromFile(const AFilePath: String): Boolean;
var
  FileLines: TStringList;
  I: Integer;
  Marker: TReaperMarker;
begin
  Result := False;
  FMarkers.Clear;

  if not FileExists(AFilePath) then Exit;

  FileLines := TStringList.Create;
  try
    FileLines.LoadFromFile(AFilePath);

    for I := 0 to FileLines.Count - 1 do
    begin
      Marker := ParseMarkerLine(FileLines[I]);
      if (Marker.Position > 0) or (Marker.Name <> '') then
        FMarkers.Add(Marker);
    end;

    Result := FMarkers.Count > 0;
  finally
    FileLines.Free;
  end;
end;

function TReaperRPPReader.GetMarkers: specialize TList<TReaperMarker>;
begin
  Result := FMarkers;
end;

// ============================================================================
// TReaperRPPWriter
// ============================================================================

constructor TReaperRPPWriter.Create;
begin
  FMarkers := specialize TList<TReaperMarker>.Create;
  FTempoPoints := specialize TList<TReaperTempoPoint>.Create;
  FTitle := '';
  FTempo := 120;
  FTempoNum := 4;
  FTempoDenom := 4;
  FTrackName := '';
  FMIDILength := 0.0;
end;

destructor TReaperRPPWriter.Destroy;
begin
  FTempoPoints.Free;
  FMarkers.Free;
  inherited Destroy;
end;

procedure TReaperRPPWriter.SetTitle(const ATitle: String);
begin
  FTitle := ATitle;
end;

procedure TReaperRPPWriter.SetTempo(ABPM, ANumerator, ADenominator: Integer);
begin
  FTempo := ABPM;
  FTempoNum := ANumerator;
  FTempoDenom := ADenominator;
end;

procedure TReaperRPPWriter.SetMIDITrack(const AName: String; ALengthSeconds: Double);
begin
  FTrackName := AName;
  FMIDILength := ALengthSeconds;
end;

procedure TReaperRPPWriter.AddMarker(APosition: Double; const AMarkerName: String);
var
  Marker: TReaperMarker;
begin
  Marker.Position := APosition;
  Marker.EndPosition := APosition;
  Marker.Name := AMarkerName;
  Marker.IsRegion := False;
  FMarkers.Add(Marker);
end;

procedure TReaperRPPWriter.AddRegion(AStart, AEnd: Double; const ARegionName: String);
var
  Marker: TReaperMarker;
begin
  Marker.Position := AStart;
  Marker.EndPosition := AEnd;
  Marker.Name := ARegionName;
  Marker.IsRegion := True;
  FMarkers.Add(Marker);
end;

procedure TReaperRPPWriter.ClearMarkers;
begin
  FMarkers.Clear;
end;

procedure TReaperRPPWriter.AddTempoPoint(APosition: Double; ABPM, ANumerator,
  ADenominator: Integer; ASetsMeter: Boolean);
var
  Point: TReaperTempoPoint;
begin
  Point.Position := APosition;
  Point.BPM := ABPM;
  Point.Num := ANumerator;
  Point.Denom := ADenominator;
  Point.SetsMeter := ASetsMeter;
  FTempoPoints.Add(Point);
end;

procedure TReaperRPPWriter.ClearTempoPoints;
begin
  FTempoPoints.Clear;
end;

function TReaperRPPWriter.EscapeRPPString(const S: String): String;
begin
  // Escape special characters for .rpp format
  Result := S;
  ReplaceText(Result, '\', '\\');
  ReplaceText(Result, '"', '\"');
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
end;

function TReaperRPPWriter.SaveToFile(const AFilePath: String; const AMIDIFile: String): Boolean;
var
  Output: TStringList;
  I, Id: Integer;
  M: TReaperMarker;
  MidiPath, MidiName: String;

  { REAPER quotes a value only when it contains a space. }
  function Quote(const S: String): String;
  begin
    if (S = '') or (Pos(' ', S) > 0) then
      Result := '"' + EscapeRPPString(S) + '"'
    else
      Result := S;
  end;

begin
  Result := False;

  Output := TStringList.Create;
  try
    { REAPER project file. The format is the one REAPER itself writes: a
      <REAPER_PROJECT ...> block whose children are "TAG value..." lines.
      Marker and region positions are in SECONDS. }
    Output.Add('<REAPER_PROJECT 0.1 7.0 1234567890');
    Output.Add('  RIPPLE 0');
    Output.Add('  GROUPOVERRIDE 0 0 0');
    Output.Add('  AUTOXFADE 1');
    Output.Add('  TEMPO ' + IntToStr(FTempo) + ' ' + IntToStr(FTempoNum) +
      ' ' + IntToStr(FTempoDenom));
    Output.Add('  PLAYRATE 1 0 0.25 4');

    Id := 1;
    for I := 0 to FMarkers.Count - 1 do
    begin
      M := FMarkers[I];
      if M.IsRegion then
        Output.Add('  RPR_MARKER ' + IntToStr(Id) + ' ' + FormatRPPFloat(M.Position) +
          ' ' + FormatRPPFloat(M.EndPosition) + ' ' + Quote(M.Name) + ' 0 0')
      else
        Output.Add('  MARKER ' + IntToStr(Id) + ' ' + FormatRPPFloat(M.Position) +
          ' ' + Quote(M.Name) + ' 0 0');
      Inc(Id);
    end;

    { Tempo envelope. A "PT" line is: position (seconds), bpm, shape, meter,
      selected, flags. Shape 1 is a square step, so the tempo jumps exactly at
      the section boundary. The meter field is 65536 * denominator + numerator
      and flag bit 1 says the point sets it; a tempo-only point has both 0. }
    if FTempoPoints.Count > 1 then
    begin
      Output.Add('  <TEMPOENVEX');
      Output.Add('    EGUID ' + '{' + MakeGUID('tempoenv:' + FTitle) + '}');
      Output.Add('    ACT 1 -1');
      Output.Add('    VIS 1 1 1');
      Output.Add('    LANEHEIGHT 0 0');
      Output.Add('    ARM 0');
      Output.Add('    DEFSHAPE 1 -1 -1');
      for I := 0 to FTempoPoints.Count - 1 do
      begin
        if FTempoPoints[I].SetsMeter then
          Output.Add('    PT ' + FormatRPPFloat(FTempoPoints[I].Position) + ' ' +
            IntToStr(FTempoPoints[I].BPM) + ' 1 ' +
            IntToStr(65536 * FTempoPoints[I].Denom + FTempoPoints[I].Num) + ' 0 1')
        else
          Output.Add('    PT ' + FormatRPPFloat(FTempoPoints[I].Position) + ' ' +
            IntToStr(FTempoPoints[I].BPM) + ' 1 0 0 0');
      end;
      Output.Add('  >');
    end;

    { REAPER resolves the media path relative to the project file and
      expects forward slashes. }
    MidiPath := StringReplace(AMIDIFile, '\', '/', [rfReplaceAll]);
    Output.Add('  FILE ' + Quote(MidiPath));

    if (FTitle <> '') then
      Output.Add('  NAME ' + Quote(FTitle));

    { A MIDI track holding the generated performance, so the project opens
      with the drums on it instead of only referencing the file. The field set
      is the one REAPER itself writes for a track. }
    if (FTrackName <> '') and (FMIDILength > 0) then
    begin
      MidiName := ExtractFileName(MidiPath);
      Output.Add('  <TRACK ' + MakeGUID('track:' + FTrackName));
      Output.Add('    NAME ' + Quote(FTrackName));
      Output.Add('    PEAKCOL 16576');
      Output.Add('    BEAT -1');
      Output.Add('    AUTOMODE 0');
      Output.Add('    VOLPAN 1 0 -1 -1 1');
      Output.Add('    MUTESOLO 0 0 0');
      Output.Add('    IPHASE 0');
      Output.Add('    PLAYOFFS 0 1');
      Output.Add('    ISBUS 0 0');
      Output.Add('    BUSCOMP 0 0 0 0 0');
      Output.Add('    SHOWINMIX 1 0.6667 0.5 1 0.5 -1 -1 -1');
      Output.Add('    SEL 0');
      Output.Add('    REC 0 0 1 0 0 0 0 0');
      Output.Add('    VU 2');
      Output.Add('    TRACKHEIGHT 0 0 0 0 -1 0');
      Output.Add('    INQ 0 0 0 0.5 100 0 0 100');
      Output.Add('    NCHAN 2');
      Output.Add('    FX 1');
      Output.Add('    TRACKID ' + MakeGUID('track:' + FTrackName));
      Output.Add('    PERF 0');
      Output.Add('    MIDIOUT -1');
      Output.Add('    MAINSEND 1 0');
      Output.Add('    <ITEM');
      Output.Add('      POSITION 0');
      Output.Add('      SNAPOFFS 0');
      Output.Add('      LENGTH ' + FormatRPPFloat(FMIDILength));
      Output.Add('      LOOP 1');
      Output.Add('      ALLTAKES 0');
      Output.Add('      FADEIN 1 0.008824 0 1 0 0 0');
      Output.Add('      FADEOUT 1 0.008824 0 1 0 0 0');
      Output.Add('      MUTE 0 0');
      Output.Add('      SEL 0');
      Output.Add('      IGUID ' + MakeGUID('item:' + FTrackName));
      Output.Add('      IID 1');
      Output.Add('      NAME ' + Quote(MidiName));
      Output.Add('      VOLPAN 1 0 1 -1');
      Output.Add('      SOFFS 0');
      Output.Add('      PLAYRATE 1 1 0 -1 0 0.0025');
      Output.Add('      CHANMODE 0');
      Output.Add('      GUID ' + MakeGUID('itemguid:' + FTrackName));
      Output.Add('      <SOURCE MIDI');
      Output.Add('        FILE ' + Quote(MidiPath));
      Output.Add('      >');
      Output.Add('    >');
      Output.Add('  >');
    end;

    Output.Add('>');

    Output.SaveToFile(AFilePath);
    Result := True;
  finally
    Output.Free;
  end;
end;

function TReaperRPPWriter.GetMarkers: specialize TList<TReaperMarker>;
begin
  Result := FMarkers;
end;

function TReaperRPPWriter.TempoPointCount: Integer;
begin
  Result := FTempoPoints.Count;
end;

end.
