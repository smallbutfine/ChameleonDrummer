unit ReaperAPI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, fpjson, jsonread, jsonwrite,
  core_models_song, ReaperRPP;

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
    FMarkers: TList<TReaperMarker>;
    function MeasuresToSeconds(Measures, BarsPerMeasure: Integer; BPM: Integer): Double;
  public
    constructor Create;
    destructor Destroy; override;

    // Create a REAPER project from song sections (sidecar-compatible)
    function CreateFromSections(const ATitle: String; const AMIDIFile: String;
      const ASections: TArray<TReaperSection>): Boolean;

    // Merge markers into existing RPP file
    function MergeMarkers(const ASourceRPP: String; const ADestRPP: String): Boolean;

    // Load sidecar JSON and generate song from it
    function CreateFromSidecar(const ASidecarPath: String; const AMIDIFile: String): Boolean;

    // Generate per-bar tempo/meter timeline from song-map JSON
    function CreateFromSongMap(const ASongMapPath, AMIDIFile: String): Boolean;

    // Write resolved timeline JSON for Ardour integration
    function ExportTimelineJSON(const ATimelinePoints: TArray<TReaperTimelinePoint>
      const AColorGroups: TList<TRecord>; const AOutputPath: String): Boolean;

    property Markers: TList<TReaperMarker> read FMarkers;
  end;

implementation

uses
  ReaperRPP;

function TReaperBridge.MeasuresToSeconds(Measures, BarsPerMeasure: Integer; BPM: Integer): Double;
begin
  if BPM <= 0 then Exit(0);
  Result := (Measures * BarsPerMeasure) / (BPM / 60.0);
end;

constructor TReaperBridge.Create;
begin
  FRPPWriter := TReaperRPPWriter.Create;
  FMarkers := TList<TReaperMarker>.Create;
end;

destructor TReaperBridge.Destroy;
begin
  FRPPWriter.Free;
  FMarkers.Free;
  inherited Destroy;
end;

function TReaperBridge.CreateFromSections(const ATitle: String; const AMIDIFile: String;
  const ASections: TArray<TReaperSection>): Boolean;
var
  I: Integer;
  AccumulatedMeasure: Double;
  BarLen: Double;
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
    FMarkers.Add((Measure: AccumulatedMeasure; Name: ASections[I].Name; IsRegion: False));

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
  JsonFile: TJSONFileReader;
  JsonValue: TJSONData;
  SectionsArr: TJSONArray;
  I: Integer;
  Title: String;
begin
  Result := False;

  if not FileExists(ASidecarPath) then Exit;

  JsonFile := TJSONFileReader.Create(ASidecarPath);
  try
    JsonValue := JsonFile.Data;
    var Root := JsonValue.AsObject;

    // Get title from sections[0].name or default
    SectionsArr := Root.Values['sections'].AsArray;
    Title := 'Generated Song';
    if (SectionsArr.Count > 0) then
      Title := Root.Values['sections'].AsArray[0].AsObject.Values['name'].AsString;

    // Build sections array for CreateFromSections
    var Sects: TArray<TReaperSection>;
    SetLength(Sects, SectionsArr.Count);
    for I := 0 to SectionsArr.Count - 1 do
    begin
      var SecObj := SectionsArr[I].AsObject;
      Sects[I].Name := SecObj.Values['name'].AsString;
      Sects[I].Bars := SecObj.Values['bars'].ValueI;
      Sects[I].BPM := Root.Values['tempo'].ValueI;
      Sects[I].Num := 4; // default
      Sects[I].Denom := 4; // default
    end;

    Result := CreateFromSections(Title, AMIDIFile, Sects);
  finally
    JsonFile.Free;
  end;
end;

function TReaperBridge.CreateFromSongMap(const ASongMapPath: String; const AMIDIFile: String): Boolean;
var
  JsonFile: TJSONFileReader;
  JsonValue: TJSONData;
  RegionsArr: TJSONArray;
  I, J: Integer;
  Sects: TArray<TReaperSection>;
  Title: String;
begin
  Result := False;

  if not FileExists(ASongMapPath) then Exit;

  JsonFile := TJSONFileReader.Create(ASongMapPath);
  try
    JsonValue := JsonFile.Data;
    var Root := JsonValue.AsObject;

    Title := Root.Values['title'].AsString;
    RegionsArr := Root.Values['regions'].AsArray;

    SetLength(Sects, RegionsArr.Count);
    for I := 0 to RegionsArr.Count - 1 do
    begin
      var RegObj := RegionsArr[I].AsObject;
      Sects[I].Name := RegObj.Values['name'].AsString;
      
      // Sum bars across all segments in this region
      var TotalBars := 0;
      var SegmentsArr := RegObj.Values['segments'].AsArray;
      for J := 0 to SegmentsArr.Count - 1 do
        TotalBars := TotalBars + SegmentsArr[J].AsObject.Values['bars'].ValueI;
      
      Sects[I].Bars := TotalBars;
      Sects[I].BPM := 120; // default, song-map may vary tempo mid-region
      Sects[I].Num := 4;
      Sects[I].Denom := 4;
    end;

    Result := CreateFromSections(Title, AMIDIFile, Sects);
  finally
    JsonFile.Free;
  end;
end;

function TReaperBridge.ExportTimelineJSON(const ATimelinePoints: TArray<TReaperTimelinePoint>;
  const AColorGroups: TList<Record>; const AOutputPath: String): Boolean;
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
