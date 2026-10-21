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
    function EscapeRPPString(const S: String): String;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetTitle(const ATitle: String);
    procedure SetTempo(ABPM, ANumerator, ADenominator: Integer);
    procedure AddMarker(APosition: Double; const AMarkerName: String);
    procedure AddRegion(AStart, AEnd: Double; const ARegionName: String);
    procedure ClearMarkers;

    function SaveToFile(const AFilePath: String; const AMIDIFile: String): Boolean;
    function GetMarkers: specialize TList<TReaperMarker>;
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
  FTitle := '';
  FTempo := 120;
  FTempoNum := 4;
  FTempoDenom := 4;
end;

destructor TReaperRPPWriter.Destroy;
begin
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
  MidiPath: String;

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

    { REAPER resolves the media path relative to the project file and
      expects forward slashes. }
    MidiPath := StringReplace(AMIDIFile, '\', '/', [rfReplaceAll]);
    Output.Add('  FILE ' + Quote(MidiPath));

    if (FTitle <> '') then
      Output.Add('  NAME ' + Quote(FTitle));

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

end.
