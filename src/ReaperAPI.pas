unit ReaperAPI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, fpjson, jsonparser,
  Song, ReaperRPP;

// ============================================================================
// TReaperSection — section definition for REAPER marker/region creation
// ============================================================================
type
  TReaperSection = record
    Name: String;
    Bars: Integer;
    BPM: Integer;
    Num: Integer;   // time signature numerator
    Denom: Integer; // time signature denominator
  end;

// ============================================================================
// TReaperTimelinePoint — tempo/time-sig change point for song-map mode
// ============================================================================
type
  TReaperTimelinePoint = record
    MeasureStart: Double;
    BPM: Integer;
    Num: Integer;
    Denom: Integer;
    RegionName: String;
    ColorGroup: String;
  end;

// ============================================================================
// TReaperBridge — high-level API for REAPER project integration
// ============================================================================
type
  TReaperBridge = class
  private
    FRPPWriter: TReaperRPPWriter;
    FMarkers: specialize TList<TReaperMarker>;
    function MeasuresToSeconds(Measures, BarsPerMeasure: Integer; BPM: Integer): Double;
    // Load file contents as string (replaces missing FileToStr)
    function LoadFileToString(const APath: String): String;
  public
    constructor Create;
    destructor Destroy; override;

    // Create a REAPER project from song sections (sidecar-compatible)
    function CreateFromSections(const ATitle: String; const AMIDIFile: String;
      const ASections: specialize TArray<TReaperSection>): Boolean;

    // Merge markers into existing RPP file
    function MergeMarkers(const ASourceRPP: String; const ADestRPP: String): Boolean;

    // Load sidecar JSON and generate song from it
    function CreateFromSidecar(const ASidecarPath: String; const AMIDIFile: String): Boolean;

    // Generate per-bar tempo/meter timeline from song-map JSON
    function CreateFromSongMap(const ASongMapPath, AMIDIFile: String): Boolean;

    // Write resolved timeline JSON for Ardour integration
    function ExportTimelineJSON(const ATimelinePoints: specialize TArray<TReaperTimelinePoint>;
      const AColorGroups: specialize TList<String>; const AOutputPath: String): Boolean;

    property Markers: specialize TList<TReaperMarker> read FMarkers;
  end;

implementation

function TReaperBridge.LoadFileToString(const APath: String): String;
var
  StrList: TStringList;
begin
  StrList := TStringList.Create;
  try
    StrList.LoadFromFile(APath);
    Result := StrList.Text;
  finally
    StrList.Free;
  end;
end;

function TReaperBridge.MeasuresToSeconds(Measures, BarsPerMeasure: Integer; BPM: Integer): Double;
begin
  if BPM <= 0 then Exit(0);
  Result := (Measures * BarsPerMeasure) / (BPM / 60.0);
end;

constructor TReaperBridge.Create;
begin
  FRPPWriter := TReaperRPPWriter.Create;
  FMarkers := specialize TList<TReaperMarker>.Create;
end;

destructor TReaperBridge.Destroy;
begin
  FRPPWriter.Free;
  FMarkers.Free;
  inherited Destroy;
end;

function TReaperBridge.CreateFromSections(const ATitle: String; const AMIDIFile: String;
  const ASections: specialize TArray<TReaperSection>): Boolean;
var
  I: Integer;
  AccumulatedMeasure: Double;
  BarLen: Double;
  M: TReaperMarker;
begin
  Result := False;

  FRPPWriter.ClearMarkers;
  FRPPWriter.SetTitle(ATitle);

  AccumulatedMeasure := 0;
  if (Length(ASections) = 0) then Exit;

  // Use first section's BPM for measure length estimation
  BarLen := 60.0 / ASections[0].BPM; { seconds per bar }

  for I := Low(ASections) to High(ASections) do
  begin
    FRPPWriter.AddMarker(AccumulatedMeasure, ASections[I].Name);
    M.Measure := AccumulatedMeasure;
    M.Name := ASections[I].Name;
    M.IsRegion := False;
    FMarkers.Add(M);

    // Advance by section length in measures (each section = bars * bar_length)
    AccumulatedMeasure := AccumulatedMeasure + (ASections[I].Bars * BarLen);
  end;

  Result := FRPPWriter.SaveToFile(ChangeFileExt(AMIDIFile, '.rpp'), AMIDIFile);
end;

function TReaperBridge.MergeMarkers(const ASourceRPP: String; const ADestRPP: String): Boolean;
var
  SourceReader: TReaperRPPReader;
  I: Integer;
begin
  Result := False;

  SourceReader := TReaperRPPReader.Create;
  try
    if not SourceReader.LoadFromFile(ASourceRPP) then Exit;

    FMarkers.Clear;
    for I := 0 to SourceReader.GetMarkers.Count - 1 do
      FMarkers.Add(SourceReader.GetMarkers[I]);

    Result := True;
  finally
    SourceReader.Free;
  end;
end;

function TReaperBridge.CreateFromSidecar(const ASidecarPath: String; const AMIDIFile: String): Boolean;
var
  JsonValue, SecsVal, TempObj: TJSONData;
  SectionsArr: TJSONArray;
  I: Integer;
  Title: String;
  Root: TJSONObject;
  SecObj: TJSONObject;
  Sects: specialize TArray<TReaperSection>;
begin
  Result := False;

  if not FileExists(ASidecarPath) then Exit;

  JsonValue := GetJSON(LoadFileToString(ASidecarPath));
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then Exit;
    Root := TJSONObject(JsonValue);

    // Get title from sections[0].name or default
    SecsVal := Root.Find('sections');
    if not Assigned(SecsVal) or (SecsVal.JsonType <> jtArray) then Exit;
    SectionsArr := TJSONArray(SecsVal);
    Title := 'Generated Song';
    if (SectionsArr.Count > 0) then
      Title := TJSONObject(TJSONData(SectionsArr[0])).Find('name').AsString;

    // Build sections array for CreateFromSections
    SetLength(Sects, SectionsArr.Count);
    for I := 0 to SectionsArr.Count - 1 do
    begin
      SecObj := TJSONObject(SectionsArr[I]);
      Sects[I].Name := SecObj.Find('name').AsString;
      TempObj := TJSONData(SecObj.Find('bars'));
      if Assigned(TempObj) then Sects[I].Bars := TempObj.AsInteger;
      TempObj := TJSONData(Root.Find('tempo'));
      if Assigned(TempObj) then Sects[I].BPM := TempObj.AsInteger;
      Sects[I].Num := 4; // default
      Sects[I].Denom := 4; // default
    end;

    Result := CreateFromSections(Title, AMIDIFile, Sects);
  finally
    JsonValue.Free;
  end;
end;

function TReaperBridge.CreateFromSongMap(const ASongMapPath: String; const AMIDIFile: String): Boolean;
var
  JsonValue, RegionsVal, TempObj: TJSONData;
  RegionsArr: TJSONArray;
  I, J: Integer;
  Sects: specialize TArray<TReaperSection>;
  Title: String;
  Root: TJSONObject;
  RegObj: TJSONObject;
  SegmentsArr: TJSONArray;
  TotalBars: Integer;
begin
  Result := False;

  if not FileExists(ASongMapPath) then Exit;

  JsonValue := GetJSON(LoadFileToString(ASongMapPath));
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then Exit;
    Root := TJSONObject(JsonValue);

    TempObj := Root.Find('title');
    if Assigned(TempObj) then
      Title := TempObj.AsString
    else
      Title := 'Song Map';
    RegionsVal := Root.Find('regions');
    if not Assigned(RegionsVal) or (RegionsVal.JsonType <> jtArray) then Exit;
    RegionsArr := TJSONArray(RegionsVal);

    SetLength(Sects, RegionsArr.Count);
    for I := 0 to RegionsArr.Count - 1 do
    begin
      RegObj := TJSONObject(RegionsArr[I]);
      Sects[I].Name := TJSONData(RegObj.Find('name')).AsString;

      // Sum bars across all segments in this region
      TotalBars := 0;
      TempObj := RegObj.Find('segments');
      if Assigned(TempObj) and (TempObj.JsonType = jtArray) then
      begin
        SegmentsArr := TJSONArray(TempObj);
        for J := 0 to SegmentsArr.Count - 1 do
        begin
          TempObj := TJSONData(TJSONObject(SegmentsArr[J]).Find('bars'));
          if Assigned(TempObj) then
            TotalBars := TotalBars + TempObj.AsInteger;
        end;
      end;

      Sects[I].Bars := TotalBars;
      Sects[I].BPM := 120; // default, song-map may vary tempo mid-region
      Sects[I].Num := 4;
      Sects[I].Denom := 4;
    end;

    Result := CreateFromSections(Title, AMIDIFile, Sects);
  finally
    JsonValue.Free;
  end;
end;

function TReaperBridge.ExportTimelineJSON(const ATimelinePoints: specialize TArray<TReaperTimelinePoint>;
  const AColorGroups: specialize TList<String>; const AOutputPath: String): Boolean;
{
  Write timeline JSON for Ardour integration.
  Flat format — no nested objects — parseable by Lua string patterns.
}
var
  Output: TStringList;
  I: Integer;
begin
  Result := False;

  Output := TStringList.Create;
  try
    Output.Add('{');

    // Tempo points (flat array)
    Output.Add('"tempo_points": [');
    for I := Low(ATimelinePoints) to High(ATimelinePoints) do
    begin
      if I > Low(ATimelinePoints) then Output.Add(',');
      Output.Add(Format('{"time": %.4f, "bpm": %d, "num": %d, "denom": %d}', [
        ATimelinePoints[I].MeasureStart, ATimelinePoints[I].BPM,
        ATimelinePoints[I].Num, ATimelinePoints[I].Denom]));
    end;
    Output.Add(']');

    // Color groups (flat array)
    Output.Add(',"color_groups": ["groove", "chorus", "fill"]');

    Output.Add('}');

    Output.SaveToFile(AOutputPath);
    Result := True;
  finally
    Output.Free;
  end;
end;

end.
