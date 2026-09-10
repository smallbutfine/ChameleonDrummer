unit Song;

{$mode objfpc}{$H+}

{ Song structure models - Song, Section, Fill, PatternVariation. }

interface

uses
  Classes, SysUtils, Generics.Collections, pattern, time_signature, generation_parameters;

type

{ â”€â”€ Fill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ A drum fill pattern. }
TFill = class(TObject)
private
  FPattern: TPattern;
  FTriggerProbability: float;
  FSectionPosition: string;
public
  constructor Create(APattern: TPattern);
  destructor Destroy; override;

  property Pattern: TPattern read FPattern write FPattern;
  property TriggerProbability: float read FTriggerProbability write FTriggerProbability;
  property SectionPosition: string read FSectionPosition write FSectionPosition;
end;

{ â”€â”€ PatternVariation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ Variation of a base pattern. }
TPatternVariation = class(TObject)
private
  FPattern: TPattern;
  FProbability: float;
  FBars: TObjecspecialize TList<Integer>;
public
  constructor Create(APattern: TPattern);
  destructor Destroy; override;

  property Pattern: TPattern read FPattern write FPattern;
  property Probability: float read FProbability write FProbability;
  property Bars: TObjecspecialize TList<Integer> read FBars; { nil = any bar }
end;

{ â”€â”€ SongSegment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ A tempo/time-signature-homogeneous slice within a Section.
  Mirrors the song_creator REAPER tool's region-segment shape ({bars, bpm, num, denom}) so a Section can contain a mid-section tempo or meter change.
  tempo/time_signature of nil means "inherit the parent Song's global value". }
TSongSegment = class(TObject)
private
  FBars: Integer;
  FTempo: Integer;
  FTimeSignature: TTimeSignature;
public
  constructor Create(ABars: Integer);
  destructor Destroy; override;

  property Bars: Integer read FBars write FBars;
  property Tempo: Integer read FTempo write FTempo; { -1 = inherit }
  property TimeSignature: TTimeSignature read FTimeSignature write FTimeSignature;
end;

{ â”€â”€ Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ Song section (verse, chorus, etc.) with pattern and variations. }
TSection = class(TObject)
private
  FBeats: TObjecspecialize TList<Integer>; { local bar indices for fills }
public
  Name: string;
  Pattern: TPattern;
  Bars: Integer;
  Variations: TObjecspecialize TList<TPatternVariation>;
  Fills: TObjecspecialize TList<TFill>;
  SectionParameters: specialize TDictionary<string, string>;
  Segments: TObjecspecialize TList<TSongSegment>;
  GrooveOffsetsMs: specialize TList<Single>;

  constructor Create(const AName: string; APattern: TPattern; ABars: Integer = 4);
  destructor Destroy; override;

  procedure ValidateSegments;

  function SegmentForBar(ABarNumber: Integer): TSongSegment;
  function EffectiveTempo(ABarNumber, ASongTempo: Integer): Integer;
  function EffectiveTimeSignature(ABarNumber: Integer; ASongTimeSignature: TTimeSignature): TTimeSignature;
  function ResolvedBarSpecs(ASongTempo: Integer; ASongTimeSignature: TTimeSignature): TObjecspecialize TList<TRecord>; { tuple of (bars, tempo, time_signature) }

  function GetEffectivePattern(ABarNumber: Integer): TPattern;
  function ShouldAddFill(ABarNumber: Integer; AFillFrequency: float): TFill;
end;

{ â”€â”€ Song â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ Complete song structure with sections and global parameters. }
TSong = class(TObject)
public
  Name: string;
  Tempo: Integer;
  TimeSignature: TTimeSignature;
  Sections: TObjecspecialize TList<TSection>;
  GlobalParameters: TGenerationParameters;
  Metadata: specialize TDictionary<string, string>;

  constructor Create(const AName: string; ATempo: Integer = 120);
  destructor Destroy; override;

  function AddSection(ASection: TSection): TSong;
  function TotalBars: Integer;
  function TotalDurationSeconds: float;
  function SectionStartTimes: specialize TList<Single>;
  function GetSectionByName(const AName: string): TSection;
  function GetSectionsByName(const AName: string): TObjecspecialize TList<TSection>;

  class function CreateSimpleStructure(const AName: string; ATempo: Integer = 120; const AGenre, AStyle: string): TSong; static;
end;

implementation

{ â”€â”€ Fill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TFill.Create(APattern: TPattern);
begin
  inherited Create;
  FPattern := APattern;
  FTriggerProbability := 1.0;
  FSectionPosition := 'end';
end;

destructor TFill.Destroy;
begin
  inherited Destroy;
end;

{ â”€â”€ PatternVariation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TPatternVariation.Create(APattern: TPattern);
begin
  inherited Create;
  FPattern := APattern;
  FProbability := 0.3;
  FBars := nil;
end;

destructor TPatternVariation.Destroy;
begin
  if Assigned(FBars) then
    FBars.Free;
  inherited Destroy;
end;

{ â”€â”€ SongSegment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TSongSegment.Create(ABars: Integer);
begin
  inherited Create;
  FBars := ABars;
  FTempo := -1; { inherit }
  FTimeSignature := nil;
end;

destructor TSongSegment.Destroy;
begin
  if Assigned(FTimeSignature) then
    FTimeSignature.Free;
  inherited Destroy;
end;

{ â”€â”€ Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TSection.Create(const AName: string; APattern: TPattern; ABars: Integer = 4);
begin
  inherited Create;
  Name := AName;
  Pattern := APattern;
  Bars := ABars;
  Variations := TObjecspecialize TList<TPatternVariation>.Create(true);
  Fills := TObjecspecialize TList<TFill>.Create(true);
  SectionParameters := TDictionary<string, string>.Create;
  Segments := TObjecspecialize TList<TSongSegment>.Create(true);
  GrooveOffsetsMs := specialize TList<Single>.Create;
  ValidateSegments;
end;

destructor TSection.Destroy;
begin
  Variations.Free;
  Fills.Free;
  SectionParameters.Free;
  Segments.Free;
  GrooveOffsetsMs.Free;
  inherited Destroy;
end;

procedure TSection.ValidateSegments;
var
  SegmentBars: Integer;
  Segment: TSongSegment;
begin
  if Segments.Count > 0 then
  begin
    SegmentBars := 0;
    for Segment in Segments do
      SegmentBars := SegmentBars + Segment.FBars;

    if SegmentBars <> Bars then
      raise Exception.CreateFmt("Section '%s' segments sum to %d bars but Section.bars is %d", [Name, SegmentBars, Bars]);
  end;
end;

function TSection.SegmentForBar(ABarNumber: Integer): TSongSegment;
var
  Cursor: Integer;
  Segment: TSongSegment;
begin
  Cursor := 0;
  for Segment in Segments do
  begin
    if (Cursor <= ABarNumber) and (ABarNumber < Cursor + Segment.FBars) then
      Exit(Segment);
    Inc(Cursor, Segment.FBars);
  end;
  Exit(nil);
end;

function TSection.EffectiveTempo(ABarNumber, ASongTempo: Integer): Integer;
var
  Segment: TSongSegment;
begin
  Segment := SegmentForBar(ABarNumber);
  if (Segment = nil) or (Segment.FTempo = -1) then
    Result := ASongTempo
  else
    Result := Segment.FTempo;
end;

function TSection.EffectiveTimeSignature(ABarNumber: Integer; ASongTimeSignature: TTimeSignature): TTimeSignature;
var
  Segment: TSongSegment;
begin
  Segment := SegmentForBar(ABarNumber);
  if (Segment = nil) or (Segment.FTimeSignature = nil) then
    Result := ASongTimeSignature
  else
    Result := Segment.FTimeSignature;
end;

function TSection.ResolvedBarSpecs(ASongTempo: Integer; ASongTimeSignature: TTimeSignature): TObjecspecialize TList<TRecord>;
{ Returns list of (bars, tempo, time_signature) triples }
begin
  Result := TObjecspecialize TList<TRecord>.Create(true);
  if Segments.Count > 0 then
    for var Segment in Segments do
    begin
      { Note: In real FPC, we'd use a proper record type or class for this tuple.
        For now, using TDictionary as a makeshift tuple structure. }
      var Spec := TDictionary<string, Integer>.Create;
      Spec.Add('bars', Segment.FBars);
      Spec.Add('tempo', Segment.FTempo);
      Result.Add(Spec); { Simplified - real impl needs proper record type }
    end
  else
  begin
    var SingleSpec := TDictionary<string, Integer>.Create;
    SingleSpec.Add('bars', Bars);
    SingleSpec.Add('tempo', ASongTempo);
    Result.Add(SingleSpec);
  end;
end;

function TSection.GetEffectivePattern(ABarNumber: Integer): TPattern;
var
  Variation: TPatternVariation;
begin
  for Variation in Variations do
  begin
    if (Variation.FBars = nil) or (Variation.FBars.Contains(ABarNumber)) then
    begin
      if Random < Variation.FProbability then
        Exit(Variation.FPattern);
    end;
  end;
  Result := Pattern;
end;

function TSection.ShouldAddFill(ABarNumber: Integer; AFillFrequency: float): TFill;
var
  TotalProb: float;
  RandVal, CurrentSum: float;
begin
  Result := nil;
  if Random >= AFillFrequency then
    Exit;

  if Fills.Count = 0 then
    Exit;

  TotalProb := 0;
  for var Fill in Fills do
    TotalProb := TotalProb + Fill.FTriggerProbability;

  if TotalProb > 0 then
  begin
    RandVal := Random * TotalProb;
    CurrentSum := 0;
    for var Fill in Fills do
    begin
      CurrentSum := CurrentSum + Fill.FTriggerProbability;
      if RandVal <= CurrentSum then
        Exit(Fill);
    end;
  end;
end;

{ â”€â”€ Song â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TSong.Create(const AName: string; ATempo: Integer = 120);
begin
  inherited Create;
  Name := AName;
  Tempo := ATempo;
  TimeSignature := TTimeSignature.Create(4, 4);
  Sections := TObjecspecialize TList<TSection>.Create(true);
  GlobalParameters := nil;
  Metadata := TDictionary<string, string>.Create;

  { Validate }
  if (Tempo < 60) or (Tempo > 300) then
    raise Exception.CreateFmt('Tempo must be between 60-300 BPM, got %d', [Tempo]);
end;

destructor TSong.Destroy;
begin
  Sections.Free;
  Metadata.Free;
  inherited Destroy;
end;

function TSong.AddSection(ASection: TSection): TSong;
begin
  Sections.Add(ASection);
  Result := Self;
end;

function TSong.TotalBars: Integer;
var
  Section: TSection;
begin
  Result := 0;
  for Section in Sections do
    Result := Result + Section.Bars;
end;

function TSong.TotalDurationSeconds: float;
var
  Section: TSection;
  BarSpecs: TObjecspecialize TList<TRecord>;
  Bars, Tempo: Integer;
  TimeSig: TTimeSignature;
begin
  Result := 0.0;
  for Section in Sections do
    for Bars, Tempo, TimeSig in Section.ResolvedBarSpecs(Tempo, TimeSignature) do
      Result := Result + (Bars * TimeSig.BeatsPerBar) / (Tempo / 60.0);
end;

function TSong.SectionStartTimes: specialize TList<Single>;
var
  Elapsed: Single;
  Section: TSection;
begin
  Result := specialize TList<Single>.Create;
  Elapsed := 0.0;
  for Section in Sections do
  begin
    Result.Add(Elapsed);
    for var Bars, Tempo, TimeSig in Section.ResolvedBarSpecs(Tempo, TimeSignature) do
      Elapsed := Elapsed + (Bars * TimeSig.BeatsPerBar) / (Tempo / 60.0);
  end;
end;

function TSong.GetSectionByName(const AName: string): TSection;
var
  Section: TSection;
begin
  for Section in Sections do
  begin
    if Section.Name = AName then
      Exit(Section);
  end;
  Result := nil;
end;

function TSong.GetSectionsByName(const AName: string): TObjecspecialize TList<TSection>;
var
  Section: TSection;
begin
  Result := TObjecspecialize TList<TSection>.Create(true);
  for Section in Sections do
    if Section.Name = AName then
      Result.Add(Section);
end;

class function TSong.CreateSimpleStructure(const AName: string; ATempo: Integer = 120; const AGenre, AStyle: string): TSong;
var
  VersePattern, ChorusPattern: TPattern;
  Song: TSong;
begin
  { Create placeholder patterns (will be generated by plugins) }
  VersePattern := TPattern.Create(AGenre + '_' + AStyle + '_verse');
  ChorusPattern := TPattern.Create(AGenre + '_' + AStyle + '_chorus');

  Song := TSong.Create(AName, ATempo);
  var Params := TGenerationParameters.Create(AGenre, AStyle);
  Song.GlobalParameters := Params;

  { Standard pop/rock structure }
  Song.AddSection(TSection.Create('intro', VersePattern, 4));
  Song.AddSection(TSection.Create('verse', VersePattern, 8));
  Song.AddSection(TSection.Create('chorus', ChorusPattern, 8));
  Song.AddSection(TSection.Create('verse', VersePattern, 8));
  Song.AddSection(TSection.Create('chorus', ChorusPattern, 8));
  Song.AddSection(TSection.Create('bridge', VersePattern, 4));
  Song.AddSection(TSection.Create('chorus', ChorusPattern, 8));
  Song.AddSection(TSection.Create('outro', ChorusPattern, 4));

  Result := Song;
end;

end.
