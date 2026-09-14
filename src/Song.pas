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
  FTriggerProbability: Double;
  FSectionPosition: string;
public
  constructor Create(APattern: TPattern);
  constructor Create(AName, ADescription: string); overload;
  destructor Destroy; override;

  property Pattern: TPattern read FPattern write FPattern;
  property TriggerProbability: Double read FTriggerProbability write FTriggerProbability;
  property SectionPosition: string read FSectionPosition write FSectionPosition;
end;

{ â”€â”€ PatternVariation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ Variation of a base pattern. }
TPatternVariation = class(TObject)
private
  FPattern: TPattern;
  FProbability: Double;
  FBars: specialize TList<Integer>;
public
  constructor Create(APattern: TPattern);
  destructor Destroy; override;

  property Pattern: TPattern read FPattern write FPattern;
  property Probability: Double read FProbability write FProbability;
  property Bars: specialize TList<Integer> read FBars; { nil = any bar }
end;

{ BarSpec — tempo/time-signature-homogeneous slice spec. }
TSongBarSpec = record
  Bars: Integer;
  Tempo: Integer;
  TimeSignature: TTimeSignature;
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
  FBeats: specialize TList<Integer>; { local bar indices for fills }
public
  Name: string;
  Pattern: TPattern;
  Bars: Integer;
  Variations: specialize TList<TPatternVariation>;
  Fills: specialize TList<TFill>;
  SectionParameters: specialize TDictionary<string, string>;
  Segments: specialize TList<TSongSegment>;
  GrooveOffsetsMs: specialize TList<Single>;

  constructor Create(const AName: string; APattern: TPattern; ABars: Integer = 4);
  destructor Destroy; override;

  procedure ValidateSegments;

  function SegmentForBar(ABarNumber: Integer): TSongSegment;
  function EffectiveTempo(ABarNumber, ASongTempo: Integer): Integer;
  function EffectiveTimeSignature(ABarNumber: Integer; ASongTimeSignature: TTimeSignature): TTimeSignature;
  function ResolvedBarSpecs(ASongTempo: Integer; ASongTimeSignature: TTimeSignature): specialize TList<TSongBarSpec>; { tuple of (bars, tempo, time_signature) }

  function GetEffectivePattern(ABarNumber: Integer): TPattern;
  function ShouldAddFill(ABarNumber: Integer; AFillFrequency: Double): TFill;
end;

{ â”€â”€ Song â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ Complete song structure with sections and global parameters. }
TSong = class(TObject)
public
  Name: string;
  Tempo: Integer;
  TimeSignature: TTimeSignature;
  Sections: specialize TList<TSection>;
  GlobalParameters: TGenerationParameters;
  Metadata: specialize TDictionary<string, string>;

  constructor Create(const AName: string; ATempo: Integer = 120);
  destructor Destroy; override;

  function AddSection(ASection: TSection): TSong;
  function TotalBars: Integer;
  function TotalDurationSeconds: Double;
  function SectionStartTimes: specialize TList<Single>;
  function GetSectionByName(const AName: string): TSection;
  function GetSectionsByName(const AName: string): specialize TList<TSection>;

  class function CreateSimpleStructure(const AName: string; ATempo: Integer = 120; const AGenre: string = 'metal'; const AStyle: string = 'heavy'): TSong; static;
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

constructor TFill.Create(AName, ADescription: string); overload;
begin
  inherited Create;
  FPattern := nil;
  FTriggerProbability := 1.0;
  FSectionPosition := AName;
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
  Variations := specialize TList<TPatternVariation>.Create;
  Fills := specialize TList<TFill>.Create;
  SectionParameters := specialize TDictionary<string, string>.Create;
  Segments := specialize TList<TSongSegment>.Create;
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
      raise Exception.CreateFmt('Section %s segments sum to %d bars but Section.bars is %d', [Name, SegmentBars, Bars]);
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

function TSection.ResolvedBarSpecs(ASongTempo: Integer; ASongTimeSignature: TTimeSignature): specialize TList<TSongBarSpec>;
var
  Segment: TSongSegment;
  Spec: TSongBarSpec;
begin
  Result := specialize TList<TSongBarSpec>.Create;
  if Segments.Count > 0 then
    for Segment in Segments do
    begin
      Spec.Bars := Segment.FBars;
      Spec.Tempo := Segment.FTempo;
      Spec.TimeSignature := TTimeSignature.Create(ASongTimeSignature.Numerator, ASongTimeSignature.Denominator);
      Result.Add(Spec);
    end
  else
  begin
    Spec.Bars := Bars;
    Spec.Tempo := ASongTempo;
    Spec.TimeSignature := TTimeSignature.Create(ASongTimeSignature.Numerator, ASongTimeSignature.Denominator);
    Result.Add(Spec);
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

function TSection.ShouldAddFill(ABarNumber: Integer; AFillFrequency: Double): TFill;
var
  TotalProb: Double;
  RandVal, CurrentSum: Double;
  Fill: TFill;
begin
  Result := nil;
  if Random >= AFillFrequency then
    Exit;

  if Fills.Count = 0 then
    Exit;

  TotalProb := 0;
  for Fill in Fills do
    TotalProb := TotalProb + Fill.FTriggerProbability;

  if TotalProb > 0 then
  begin
    RandVal := Random * TotalProb;
    CurrentSum := 0;
    for Fill in Fills do
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
  Sections := specialize TList<TSection>.Create;
  GlobalParameters := nil;
  Metadata := specialize TDictionary<string, string>.Create;

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

function TSong.TotalDurationSeconds: Double;
var
  Section: TSection;
  Spec: TSongBarSpec;
  BarSpecs: specialize TList<TSongBarSpec>;
begin
  Result := 0.0;
  for Section in Sections do
  begin
    BarSpecs := Section.ResolvedBarSpecs(Tempo, TimeSignature);
    for Spec in BarSpecs do
      Result := Result + (Spec.Bars * Spec.TimeSignature.BeatsPerBar) / (Spec.Tempo / 60.0);
  end;
end;

function TSong.SectionStartTimes: specialize TList<Single>;
var
  Elapsed: Single;
  Section: TSection;
  BarSpecs: specialize TList<TSongBarSpec>;
  Spec: TSongBarSpec;
begin
  Result := specialize TList<Single>.Create;
  Elapsed := 0.0;
  for Section in Sections do
  begin
    Result.Add(Elapsed);
    BarSpecs := Section.ResolvedBarSpecs(Tempo, TimeSignature);
    for Spec in BarSpecs do
      Elapsed := Elapsed + (Spec.Bars * Spec.TimeSignature.BeatsPerBar) / (Spec.Tempo / 60.0);
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

function TSong.GetSectionsByName(const AName: string): specialize TList<TSection>;
var
  Section: TSection;
begin
  Result := specialize TList<TSection>.Create;
  for Section in Sections do
    if Section.Name = AName then
      Result.Add(Section);
end;

class function TSong.CreateSimpleStructure(const AName: string; ATempo: Integer = 120; const AGenre: string = 'metal'; const AStyle: string = 'heavy'): TSong;
var
  VersePattern, ChorusPattern: TPattern;
  Song: TSong;
  Params: TGenerationParameters;
begin
  { Create placeholder patterns (will be generated by plugins) }
  VersePattern := TPattern.Create(AGenre + '_' + AStyle + '_verse');
  ChorusPattern := TPattern.Create(AGenre + '_' + AStyle + '_chorus');

  Song := TSong.Create(AName, ATempo);
  Params := TGenerationParameters.Create(AGenre, AStyle);
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
