unit ReaperAPI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  export_reaper_reaper_rpp;

// ============================================================================
// TReaperBridge — high-level API for REAPER project integration
// ============================================================================
type
  TReaperBridge = class
  private
    FRPPWriter: TReaperRPPWriter;
    FMarkers: TList<TReaperMarker>;
  public
    constructor Create;
    destructor Destroy; override;

    // Create a REAPER project from song sections
    function CreateFromSections(const ATitle: String; const AMIDIFile: String;
      const ASections: TList<Record>; MeasureLength: Double): Boolean;

    // Merge markers into existing RPP file
    function MergeMarkers(const ASourceRPP: String; const ADestRPP: String): Boolean;

    property Markers: TList<TReaperMarker> read FMarkers;
  end;

implementation

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
  const ASections: TList<Record>; MeasureLength: Double): Boolean;
var
  I: Integer;
  AccumulatedMeasure: Double;
begin
  Result := False;

  FRPPWriter.ClearMarkers;
  FRPPWriter.SetTitle(ATitle);

  AccumulatedMeasure := 0;
  for I := 0 to ASections.Count - 1 do
  begin
    // Add marker for each section
    FRPPWriter.AddMarker(AccumulatedMeasure, ASections[I].Name);
    FMarkers.Add(FMarkers[FRPPWriter.GetMarkers.Count - 1]);

    // Advance by section length in measures
    AccumulatedMeasure := AccumulatedMeasure + ASections[I].Bars * MeasureLength;
  end;

  // Save to file (implementation would write the .rpp)
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

    Result := True; // Markers loaded successfully
  finally
    SourceReader.Free;
  end;
end;

end.
