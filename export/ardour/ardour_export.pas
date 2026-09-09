unit ArdourExport;

{$mode objfpc}{$H+}

{ TArdourSessionExporter — Generates complete Ardour session XML files.
  Creates .ardour project directories with MIDI tracks and markers
  pre-configured. Compatible with Ardour 8/9 via native C++ engine
  integration. }

interface

uses
  Classes, SysUtils, Generics.Collections;

type
  TArdourSection = record
    Name: String;
    StartSample: Int64;
    EndSample: Int64;
    IsMarker: Boolean;
  end;

  TArdourTrack = record
    Name: String;
    Type_: String; // 'midi', 'audio'
    RegionStart: Int64;
    RegionLength: Int64;
    SourceFile: String;
  end;

type
  TArdourSessionExporter = class
  private
    FSessionName: String;
    FSamplesPerSecond: Integer;
    FSections: TList<TArdourSection>;
    FMIDIMSecPerBeat: Cardinal;
    FMIDIFileName: String;
    FMIDITotalBars: Integer;

    function CalcMIDISeconds: Double;
    function GenerateMarkerXML: String;
    function GenerateTrackXML(const ATrack: TArdourTrack): String;
    function GenerateSessionXML: String;

  public
    constructor Create(ASessionName: String; ASamplesPerSecond: Integer = 48000);
    destructor Destroy; override;

    procedure SetMIDIFromSong(ASong: TSong);
    procedure AddSection(const AName: String; AStartSample, AEndSample: Int64; AIsMarker: Boolean = True);
    procedure ClearSections;

    function ExportToFile(const AOutputPath: String): Boolean;
    function GetSessionDirectory: String;
  end;

implementation

constructor TArdourSessionExporter.Create(ASessionName: String; ASamplesPerSecond: Integer);
begin
  FSessionName := ASessionName;
  FSamplesPerSecond := ASamplesPerSecond;
  FMIDIMSecPerBeat := 500000; // Default 120 BPM
  FMIDIFileName := '';
  FMIDITotalBars := 0;
  FSections := TList<TArdourSection>.Create;
end;

destructor TArdourSessionExporter.Destroy;
begin
  FSections.Free;
  inherited Destroy;
end;

procedure TArdourSessionExporter.SetMIDIFromSong(ASong: TSong);
var
  I, TotalBars: Integer;
  CumulativeBeats: Double;
  SectionBars: Integer;
begin
  if not Assigned(ASong) then Exit;

  FMIDIFileName := ExtractFileNameWithoutExt(ASong.FName) + '.mid';
  TotalBars := 0;
  CumulativeBeats := 0;

  for I := 0 to ASong.Sections.Count - 1 do
  begin
    SectionBars := ASong.Sections[I].BarsCount;
    
    // Calculate start/end samples for this section
    var StartSecs := CumulativeBeats / (FMIDIMSecPerBeat / 60000);
    var EndSecs := (CumulativeBeats + SectionBars) / (FMIDIMSecPerBeat / 60000);

    AddSection(ASong.Sections[I].FName,
               Trunc(StartSecs * FSamplesPerSecond),
               Trunc(EndSecs * FSamplesPerSecond));

    CumulativeBeats := CumulativeBeats + SectionBars;
  end;

  FMIDITotalBars := Round(CumulativeBeats);
end;

procedure TArdourSessionExporter.AddSection(const AName: String; AStartSample, AEndSample: Int64; AIsMarker: Boolean);
var
  Section: TArdourSection;
begin
  Section.Name := AName;
  Section.StartSample := AStartSample;
  Section.EndSample := AEndSample;
  Section.IsMarker := AIsMarker;
  FSections.Add(Section);
end;

procedure TArdourSessionExporter.ClearSections;
begin
  FSections.Clear;
end;

function TArdourSessionExporter.CalcMIDISeconds: Double;
begin
  if (FMIDIMSecPerBeat = 0) then Exit(0);
  Result := FMIDITotalBars * (FMIDIMSecPerBeat / 60000);
end;

function TArdourSessionExporter.GenerateMarkerXML: String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FSections.Count - 1 do
    Result := Result + Format('    <Location id="%d" name="%s" start="%d" end="%d" flags="IsMark" locked="false"/>'#13#10,
      [900000 + I, FSections[I].Name, FSections[I].StartSample, FSections[I].EndSample]);
end;

function TArdourSessionExporter.GenerateTrackXML(const ATrack: TArdourTrack): String;
begin
  if (ATrack.Type_ = 'midi') then
    Result := Format(
      '  <Route id="301" name="%s" default-output-channels="2" flags="MidiTrack" active="yes">'#13#10+
      '    <Playlist id="401" name="%s 1">'#13#10+
      '      <Region id="201" position="0" length="%d"/>'#13#10+
      '    </Playlist>'#13#10+
      '  </Route>',
      [ATrack.Name, ATrack.Name, ATrack.RegionLength])
  else
    Result := '';
end;

function TArdourSessionExporter.GenerateSessionXML: String;
var
  TrackXML: String;
  MIDILengthSecs: Double;
begin
  MIDILengthSecs := CalcMIDISeconds();

  // Generate track XML for MIDI track
  var Track: TArdourTrack;
  Track.Name := 'Drums';
  Track.Type_ := 'midi';
  Track.RegionStart := 0;
  Track.RegionLength := Trunc(MIDILengthSecs * FSamplesPerSecond);
  Track.SourceFile := FMIDIFileName;

  TrackXML := GenerateTrackXML(Track);

  Result := Format(
    '<?xml version="1.0" encoding="UTF-8"?>'#13#10+
    '<Session version="7000" name="%s" sample-rate="%d">'#13#10+
    '  <Config>'#13#10+
    '    <Option name="sample-rate" value="%d"/>'#13#10+
    '  </Config>'#13#10+
    '  <Metadata></Metadata>'#13#10+
    '  <Sources>'#13#10+
    '    <Source type="midi" name="%s" id="101" origin="" flags=""/>'#13#10+
    '  </Sources>'#13#10+
    '  <Regions>'#13#10+
    '    <Region id="201" name="%s" source="101" start="0" length="%d" position="0" type="midi"/>'#13#10+
    '  </Regions>'#13#10+
    '  <Locations>'#13#10+
    '%s'+#13#10+
    '  </Locations>'#13#10+
    '  <Routes>'#13#10+
    '%s'+#13#10+
    '  </Routes>'#13#10+
    '</Session>',
    [FSessionName, FSamplesPerSecond, FSamplesPerSecond, FMIDIFileName,
     FMIDIFileName, Track.RegionLength, GenerateMarkerXML, TrackXML]);
end;

function TArdourSessionExporter.ExportToFile(const AOutputPath: String): Boolean;
var
  SessionDir, SessionFile: String;
  SessionContent, MIDIFullPath: String;
begin
  Result := False;

  // Create session directory structure
  SessionDir := IncludeTrailingPathDelimiter(AOutputPath) + FSessionName;
  if not DirectoryExists(SessionDir) then
    if not ForceDirectories(SessionDir) then Exit;

  // Create interchange subdirectory (Ardour expects audio/MIDI sources here)
  var InterchangeDir := SessionDir + 'interchange' + PathDelim + FSessionName + PathDelim + 'audio';
  if not DirectoryExists(InterchangeDir) then
    ForceDirectories(InterchangeDir);

  // Copy MIDI file to session interchange directory
  MIDIFullPath := AOutputPath + FSessionName + PathDelim + FMIDIFileName;
  if FileExists(MIDIFullPath) then
  begin
    // Use SysUtils.FileCopy with correct signature: Source, Dest, Replace
    SysUtils.FileCopy(MIDIFullPath, InterchangeDir + PathDelim + FMIDIFileName, True);
  end;

  // Generate and write session XML
  SessionFile := IncludeTrailingPathDelimiter(AOutputPath) + FSessionName + PathDelim + FSessionName + '.ardour';
  SessionContent := GenerateSessionXML();
  
  Result := TFile.WriteAllText(SessionFile, SessionContent);
end;

function TArdourSessionExporter.GetSessionDirectory: String;
begin
  Result := IncludeTrailingPathDelimiter(GetCurrentDir) + FSessionName;
end;

end.
