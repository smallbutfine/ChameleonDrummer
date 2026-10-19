unit GMDPatternLibrary;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, fpjson, jsonparser, Kit, Pattern,
  time_signature;

type
  TGMDPatternLibrary = class
  private
    FPatterns: specialize TList<TPattern>;
    procedure LoadFromFile(const AFileName: string);
    function MatchesGenre(const AGenre, AStyle, ASourceStyle: string): Boolean;
    function StyleMatchScore(const AGenre, AStyle, ASourceStyle: string): Integer;
  public
    constructor Create(const AFileName: string = '');
    destructor Destroy; override;
    function GetPatterns(const AGenre, AStyle, AType: string;
      ANumerator: Integer = 4; ADenominator: Integer = 4): specialize TList<TPattern>;
  end;

implementation

const
  GMDAssetRelativePath = 'Assets' + DirectorySeparator + 'GMD' +
    DirectorySeparator + 'gmd_patterns.json';
  GMDLicenseUrl = 'https://creativecommons.org/licenses/by/4.0/';

function ResolveCorpusPath(const AFileName: string): string;
var
  Candidate: string;
begin
  if AFileName <> '' then
  begin
    if not FileExists(AFileName) then
      raise Exception.CreateFmt('GMD pattern corpus not found: %s', [AFileName]);
    Exit(ExpandFileName(AFileName));
  end;

  Candidate := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    GMDAssetRelativePath;
  if FileExists(Candidate) then
    Exit(Candidate);

  Candidate := IncludeTrailingPathDelimiter(GetCurrentDir()) + GMDAssetRelativePath;
  if FileExists(Candidate) then
    Exit(Candidate);

  raise Exception.CreateFmt('GMD pattern corpus not found at %s or %s',
    [IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + GMDAssetRelativePath,
     IncludeTrailingPathDelimiter(GetCurrentDir()) + GMDAssetRelativePath]);
end;

constructor TGMDPatternLibrary.Create(const AFileName: string);
begin
  inherited Create;
  FPatterns := specialize TList<TPattern>.Create;
  LoadFromFile(ResolveCorpusPath(AFileName));
end;

destructor TGMDPatternLibrary.Destroy;
var
  PatternItem: TPattern;
begin
  for PatternItem in FPatterns do
    PatternItem.Free;
  FPatterns.Free;
  inherited Destroy;
end;

procedure TGMDPatternLibrary.LoadFromFile(const AFileName: string);
var
  JsonFile: TStringList;
  JsonData: TJSONData;
  Root: TJSONObject;
  Patterns: TJSONArray;
  PatternData: TJSONObject;
  Notes: TJSONArray;
  NoteData: TJSONArray;
  PatternItem: TPattern;
  Instrument: TDrumInstrument;
  InstrumentName, PatternId: string;
  SourceUrl, LicenseName, LicenseUrl: string;
  Numerator, Denominator, SourcePPQ: Integer;
  I, J, SourcePitch, Velocity, PositionTicks: Integer;
  Signature: TJSONArray;

  function InstrumentNameForPitch(APitch: Integer): string;
  begin
    case APitch of
      36: Result := 'kick';
      37: Result := 'snare_side_stick';
      38: Result := 'snare_open_hit_open_lateral_hit';
      40: Result := 'snare_rimshot_open_hit';
      42, 22: Result := 'hihat_closed_1_tip_closed_1_hit';
      44: Result := 'hihat_pedal_closed';
      46, 26: Result := 'hihat_open_a';
      43, 58: Result := 'tom_3_open_hit';
      45, 47: Result := 'tom_2_open_hit';
      48, 50: Result := 'tom_1_open_hit';
      49, 55, 52: Result := 'cymbal_1_hit';
      57: Result := 'cymbal_2_hit';
      51, 59: Result := 'ride_1_tip_hit_softer';
      53: Result := 'ride_1_bell';
    else
      raise Exception.CreateFmt('Unsupported GMD drum pitch %d in %s',
        [APitch, AFileName]);
    end;
  end;

  function RequiredString(AObject: TJSONObject; const AName: string): string;
  var
    Value: TJSONData;
  begin
    Value := AObject.Find(AName);
    if not Assigned(Value) or (Value.JSONType <> jtString) then
      raise Exception.CreateFmt('Missing or invalid GMD field "%s"', [AName]);
    Result := Value.AsString;
  end;

begin
  JsonFile := TStringList.Create;
  try
    JsonFile.LoadFromFile(AFileName);
    JsonData := GetJSON(JsonFile.Text);
  finally
    JsonFile.Free;
  end;
  try
    if not (JsonData is TJSONObject) then
      raise Exception.Create('GMD corpus root must be a JSON object');
    Root := TJSONObject(JsonData);
    SourceUrl := RequiredString(Root, 'source_url');
    LicenseName := RequiredString(Root, 'license');
    LicenseUrl := RequiredString(Root, 'license_url');
    if (SourceUrl = '') or (LicenseName <> 'CC BY 4.0') or
       (LicenseUrl <> GMDLicenseUrl) then
      raise Exception.Create('GMD corpus source or license metadata is invalid');

    SourcePPQ := Root.Get('ppq', 0);
    if SourcePPQ <= 0 then
      raise Exception.Create('GMD corpus has an invalid PPQ value');
    Patterns := Root.Arrays['patterns'];
    for I := 0 to Patterns.Count - 1 do
    begin
      PatternData := Patterns.Objects[I];
      Signature := PatternData.Arrays['time_signature'];
      if Signature.Count <> 2 then
        raise Exception.Create('GMD pattern has an invalid time signature');
      Numerator := Signature[0].AsInteger;
      Denominator := Signature[1].AsInteger;
      PatternId := RequiredString(PatternData, 'id');
      PatternItem := TPattern.Create(
        'gmd_' + StringReplace(PatternId, '/', '_', [rfReplaceAll]));
      try
        PatternItem.TimeSignature.Free;
        PatternItem.TimeSignature := TTimeSignature.Create(Numerator, Denominator);
        PatternItem.Metadata.AddOrSetValue('phrase_bars',
          IntToStr(PatternData.Get('bars', 1)));
        PatternItem.Metadata.AddOrSetValue('gmd_source_id',
          RequiredString(PatternData, 'source_id'));
        PatternItem.Metadata.AddOrSetValue('gmd_source_style',
          RequiredString(PatternData, 'style'));
        PatternItem.Metadata.AddOrSetValue('gmd_source_type',
          RequiredString(PatternData, 'type'));
        PatternItem.Metadata.AddOrSetValue('gmd_source_bpm',
          IntToStr(PatternData.Get('bpm', 0)));
        PatternItem.Metadata.AddOrSetValue('gmd_source_url', SourceUrl);
        PatternItem.Metadata.AddOrSetValue('gmd_license', LicenseName);

        Notes := PatternData.Arrays['notes'];
        for J := 0 to Notes.Count - 1 do
        begin
          NoteData := Notes.Arrays[J];
          if NoteData.Count <> 3 then
            raise Exception.CreateFmt('GMD pattern %s has an invalid note entry',
              [PatternId]);
          PositionTicks := NoteData[0].AsInteger;
          SourcePitch := NoteData[1].AsInteger;
          Velocity := NoteData[2].AsInteger;
          InstrumentName := InstrumentNameForPitch(SourcePitch);
          Instrument := TInstrumentRegistry.Get(InstrumentName);
          if not Assigned(Instrument) then
            raise Exception.CreateFmt(
              'GMD pitch %d maps to unregistered instrument "%s"',
              [SourcePitch, InstrumentName]);
          PatternItem.AddBeat(PositionTicks / SourcePPQ, Instrument, Velocity);
        end;
        FPatterns.Add(PatternItem);
        PatternItem := nil;
      finally
        PatternItem.Free;
      end;
    end;
  finally
    JsonData.Free;
  end;
end;

function TGMDPatternLibrary.MatchesGenre(const AGenre, AStyle,
  ASourceStyle: string): Boolean;
var
  PrimaryStyle: string;
  SlashPosition: SizeInt;
begin
  SlashPosition := Pos('/', ASourceStyle);
  if SlashPosition > 0 then
    PrimaryStyle := Copy(ASourceStyle, 1, SlashPosition - 1)
  else
    PrimaryStyle := ASourceStyle;

  case LowerCase(AGenre) of
    'rock':
      Result := (PrimaryStyle = 'rock') or (PrimaryStyle = 'punk') or
        ((SameText(AStyle, 'blues')) and (PrimaryStyle = 'blues')) or
        ((SameText(AStyle, 'pop')) and (PrimaryStyle = 'pop'));
    'metal':
      Result := (PrimaryStyle = 'rock') or (PrimaryStyle = 'punk');
    'funk':
      Result := (PrimaryStyle = 'funk') or (PrimaryStyle = 'neworleans');
    'jazz':
      Result := (PrimaryStyle = 'jazz') or
        ((SameText(AStyle, 'latin')) and (PrimaryStyle = 'latin'));
    'electronic':
      Result := (PrimaryStyle = 'dance') or (PrimaryStyle = 'hiphop');
  else
    Result := False;
  end;
end;

function TGMDPatternLibrary.StyleMatchScore(const AGenre, AStyle,
  ASourceStyle: string): Integer;
var
  PrimaryStyle, SecondaryStyle, StyleName: string;
  SlashPosition: SizeInt;
begin
  StyleName := LowerCase(AStyle);
  SlashPosition := Pos('/', ASourceStyle);
  if SlashPosition > 0 then
  begin
    PrimaryStyle := Copy(ASourceStyle, 1, SlashPosition - 1);
    SecondaryStyle := Copy(ASourceStyle, SlashPosition + 1, MaxInt);
  end
  else
  begin
    PrimaryStyle := ASourceStyle;
    SecondaryStyle := '';
  end;

  if (StyleName = '') or (StyleName = PrimaryStyle) or
     (StyleName = SecondaryStyle) or
     (Pos(StyleName, ASourceStyle) > 0) then
    Exit(2);

  case LowerCase(AGenre) of
    'rock':
      if ((StyleName = 'classic') or (StyleName = 'hard')) and
         ((PrimaryStyle = 'rock') or (PrimaryStyle = 'punk')) then
        Exit(2)
      else if (StyleName = 'alternative') and (Pos('indie', ASourceStyle) > 0) then
        Exit(2)
      else if (StyleName = 'progressive') and (Pos('prog', ASourceStyle) > 0) then
        Exit(2)
      else if (StyleName = 'blues') and (Pos('shuffle', ASourceStyle) > 0) then
        Exit(2);
    'metal':
      if ((StyleName = 'heavy') or (StyleName = 'death') or
          (StyleName = 'power') or (StyleName = 'progressive') or
          (StyleName = 'thrash')) and
         ((PrimaryStyle = 'rock') or (PrimaryStyle = 'punk')) then
        Exit(2);
    'funk':
      if ((StyleName = 'classic') or (StyleName = 'heavy') or
          (StyleName = 'minimal') or (StyleName = 'pfunk')) and
         ((PrimaryStyle = 'funk') or (PrimaryStyle = 'neworleans')) then
        Exit(2)
      else if (StyleName = 'shuffle') and (Pos('shuffle', ASourceStyle) > 0) then
        Exit(2)
      else if (StyleName = 'new_orleans') and
              (PrimaryStyle = 'neworleans') then
        Exit(2)
      else if (StyleName = 'fusion') and (Pos('fusion', ASourceStyle) > 0) then
        Exit(2);
    'jazz':
      if ((StyleName = 'swing') and
          ((Pos('swing', ASourceStyle) > 0) or (PrimaryStyle = 'jazz'))) or
         ((StyleName = 'bebop') and
          ((Pos('fast', ASourceStyle) > 0) or (PrimaryStyle = 'jazz'))) or
         ((StyleName = 'fusion') and (Pos('fusion', ASourceStyle) > 0)) or
         ((StyleName = 'ballad') and (PrimaryStyle = 'jazz')) or
         ((StyleName = 'hard_bop') and (PrimaryStyle = 'jazz')) or
         ((StyleName = 'contemporary') and (PrimaryStyle = 'jazz')) then
        Exit(2);
    'electronic':
      if ((StyleName = 'house') and (Pos('disco', ASourceStyle) > 0)) or
         ((StyleName = 'techno') and (PrimaryStyle = 'dance')) then
        Exit(2);
  end;

  Result := 1;
end;

function TGMDPatternLibrary.GetPatterns(const AGenre, AStyle,
  AType: string; ANumerator, ADenominator: Integer): specialize TList<TPattern>;
var
  PatternItem, Candidate: TPattern;
  SourceStyle, SourceType: string;
  BestScore, Score: Integer;
begin
  Result := specialize TList<TPattern>.Create;
  BestScore := 0;
  for PatternItem in FPatterns do
  begin
    if not PatternItem.Metadata.TryGetValue('gmd_source_style', SourceStyle) or
       not PatternItem.Metadata.TryGetValue('gmd_source_type', SourceType) or
       not SameText(SourceType, AType) or
       (PatternItem.TimeSignature.Numerator <> ANumerator) or
       (PatternItem.TimeSignature.Denominator <> ADenominator) or
       not MatchesGenre(AGenre, AStyle, SourceStyle) then
      Continue;
    Score := StyleMatchScore(AGenre, AStyle, SourceStyle);
    if Score > BestScore then
    begin
      for Candidate in Result do
        Candidate.Free;
      Result.Clear;
      BestScore := Score;
    end;
    if Score = BestScore then
      Result.Add(PatternItem.Copy);
  end;
end;

end.
