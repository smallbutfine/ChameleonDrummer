unit ReaperRPP;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections;

// ============================================================================
// TReaperMarker — represents a single marker in an .rpp file
// ============================================================================
type
  TReaperMarker = record
    Measure: Double;
    Name: String;
    IsRegion: Boolean;
  end;

// ============================================================================
// TReaperRPPReader — parses .rpp files to extract markers and regions
// ============================================================================
type
  TReaperRPPReader = class
  private
    FMarkers: TList<TReaperMarker>;
    function ParseMarkerLine(const Line: String): TReaperMarker;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromFile(const AFilePath: String): Boolean;
    function GetMarkers: TList<TReaperMarker>;
  end;

// ============================================================================
// TReaperRPPWriter — writes .rpp files with markers and regions
// ============================================================================
type
  TReaperRPPWriter = class
  private
    FMarkers: TList<TReaperMarker>;
    FTitle: String;
    FTMPFile: String;
    function EscapeRPPString(const S: String): String;
  public
    constructor Create;

    procedure SetTitle(const ATitle: String);
    procedure AddMarker(Measure: Double; const AMarkerName: String);
    procedure ClearMarkers;

    function SaveToFile(const AFilePath: String; const AMIDIFile: String): Boolean;
    function GetMarkers: TList<TReaperMarker>;
  end;

implementation

constructor TReaperRPPReader.Create;
begin
  FMarkers := TList<TReaperMarker>.Create;
end;

destructor TReaperRPPReader.Destroy;
begin
  FMarkers.Free;
  inherited Destroy;
end;

function TReaperRPPReader.ParseMarkerLine(const Line: String): TReaperMarker;
var
  MarkerStart, QuoteStart, QuoteEnd: Integer;
  MeasureStr: String;
begin
  // Parse MARKER/RPR_MARKER format: MARKER <measure> "name"
  Result.IsRegion := False;

  if (Pos('MARKER', Line) > 0) then
    MarkerStart := Pos('MARKER', Line) + 6
  else if (Pos('RPR_MARKER', Line) > 0) then
    MarkerStart := Pos('RPR_MARKER', Line) + 10
  else
  begin
    Result.Measure := 0;
    Result.Name := '';
    Exit;
  end;

  // Extract measure value (skip whitespace after MARKER)
  while (MarkerStart <= Length(Line)) and (Line[MarkerStart] in [' ', #9]) do
    Inc(MarkerStart);

  MeasureStr := '';
  while (MarkerStart <= Length(Line)) and (Line[MarkerStart] in ['0'..'9', '.']) do
  begin
    MeasureStr := MeasureStr + Line[MarkerStart];
    Inc(MarkerStart);
  end;

  if (MeasureStr <> '') then
    Val(MeasureStr, Result.Measure)
  else
    Result.Measure := 0;

  // Find quoted name
  QuoteStart := PosEx('"', Line, MarkerStart);
  if (QuoteStart > 0) then
  begin
    QuoteEnd := PosEx('"', Line, QuoteStart + 1);
    if (QuoteEnd > QuoteStart) then
      Result.Name := Copy(Line, QuoteStart + 1, QuoteEnd - QuoteStart - 1);

    // Check if it's a region
    if (Pos('REGION', Line) > 0) then
      Result.IsRegion := True;
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
      if (Marker.Measure > 0) or (Marker.Name <> '') then
        FMarkers.Add(Marker);
    end;

    Result := FMarkers.Count > 0;
  finally
    FileLines.Free;
  end;
end;

function TReaperRPPReader.GetMarkers: TList<TReaperMarker>;
begin
  Result := FMarkers;
end;

{ TReaperRPPWriter }
constructor TReaperRPPWriter.Create;
begin
  FMarkers := TList<TReaperMarker>.Create;
  FTitle := '';
  FTMPFile := '';
end;

procedure TReaperRPPWriter.SetTitle(const ATitle: String);
begin
  FTitle := ATitle;
end;

procedure TReaperRPPWriter.AddMarker(Measure: Double; const AMarkerName: String);
var
  Marker: TReaperMarker;
begin
  Marker.Measure := Measure;
  Marker.Name := AMarkerName;
  Marker.IsRegion := False;
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
  ReplaceText(Result, #10, '\n');
  ReplaceText(Result, #13, '\r');
end;

function TReaperRPPWriter.SaveToFile(const AFilePath: String; const AMIDIFile: String): Boolean;
var
  Output: TStringList;
  I: Integer;
  BaseName: String;
begin
  Result := False;

  // Extract base name from file path
  BaseName := ChangeFileExt(ExtractFileName(AFilePath), '');

  Output := TStringList.Create;
  try
    // Write header
    Output.Add('[Project]');
    Output.Add('wVersion=1028');
    if (FTitle <> '') then
      Output.Add('sTitle=' + EscapeRPPString(FTitle));

    // Write file references
    Output.Add('[File]');
    Output.Add(Format('f%s', [iLength(BaseName)] + BaseName));

    // Write markers
    Output.Add('[Markers]');
    for I := 0 to FMarkers.Count - 1 do
    begin
      Output.Add(Format('MARKER %d %.6f "%s"', [I, FMarkers[I].Measure,
        EscapeRPPString(FMarkers[I].Name)]));
    end;

    // Write regions if any
    Output.Add('[Regions]');
    for I := 0 to FMarkers.Count - 1 do
    begin
      if (FMarkers[I].IsRegion) then
      begin
        Output.Add(Format('RPR_MARKER %d %.6f "%s"', [I, FMarkers[I].Measure,
          EscapeRPPString(FMarkers[I].Name)]));
      end;
    end;

    // Write tempo map
    Output.Add('[TempoMap]');
    Output.Add('0 0.000000 75.000000 4 4');

    Result := True;
  finally
    Output.Free;
  end;
end;

function TReaperRPPWriter.GetMarkers: TList<TReaperMarker>;
begin
  Result := FMarkers;
end;

end.
