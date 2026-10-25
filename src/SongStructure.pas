unit SongStructure;

{$mode objfpc}{$H+}

{ Song structure given by the user: the --section command-line syntax and the
  structure file (--structure / --sidecar), both turned into the section list
  the composer works from.

      --section name:bars          a section of that many bars
      --section name:bars@tempo    the same, at its own tempo in BPM

  Structure file (JSON, a superset of the REAPER sidecar format):

      {
        "genre": "rock", "style": "classic",      optional defaults, the
        "tempo": 120,                              command line overrides them
        "time_signature": [4, 4],                  only 4/4 for now
        "sections": [
          {"name": "intro",  "bars": 4},
          {"name": "verse",  "bars": 8, "tempo": 110, "complexity": 0.4},
          {"name": "chorus", "bars": 8, "complexity": 0.9}
        ]
      }

  The composer treats these section names specially: intro, verse, pre_chorus,
  chorus, bridge, breakdown, solo, outro. Any other name plays like a verse. }

interface

uses
  SysUtils, Classes, Generics.Collections, fpjson, jsonparser, ComposerV2;

const
  MAX_SECTION_BARS = 256;
  MIN_SECTION_TEMPO = 60;
  MAX_SECTION_TEMPO = 300;
  MAX_SECTIONS = 200;
  MAX_SECTION_NAME = 64;

type
  { What a structure file contains. Tempo 0 and empty strings mean "not given". }
  TStructureInfo = record
    Genre: string;
    Style: string;
    Tempo: Integer;
    Sections: specialize TArray<TSectionDef>;
    { Things in the file that are ignored, one readable line each. }
    Warnings: specialize TArray<string>;
  end;

{ Parses one --section value. Raises an Exception that names the offending
  text and shows the expected syntax when the value is not valid. }
function ParseSectionSpec(const ASpec: string): TSectionDef;

{ Loads a structure file. Raises an Exception that names the file and the
  place in it (section number and name, key) when something is wrong. }
function LoadStructureFile(const APath: string): TStructureInfo;

{ The structure as one readable line, e.g. "intro:4 verse:8@120 chorus:8". }
function DescribeStructure(const AStructure: array of TSectionDef): string;

implementation

const
  SYNTAX_HELP = 'expected name:bars or name:bars@tempo, e.g. verse:8 or chorus:8@140';

function IsNameChar(C: Char; AFirst: Boolean): Boolean;
begin
  if AFirst then
    Result := C in ['a'..'z', 'A'..'Z']
  else
    Result := C in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-'];
end;

function ParseSectionSpec(const ASpec: string): TSectionDef;
var
  Text, NamePart, BarsPart, TempoPart: string;
  ColonPos, AtPos, I: Integer;
begin
  Text := Trim(ASpec);
  Result.Name := '';
  Result.Bars := 0;
  Result.Tempo := 0;
  Result.HasComplexity := False;
  Result.Complexity := 0.0;

  ColonPos := Pos(':', Text);
  if ColonPos < 2 then
    raise Exception.CreateFmt('Invalid --section "%s": %s', [ASpec, SYNTAX_HELP]);

  NamePart := Copy(Text, 1, ColonPos - 1);
  BarsPart := Copy(Text, ColonPos + 1, MaxInt);
  TempoPart := '';
  AtPos := Pos('@', BarsPart);
  if AtPos > 0 then
  begin
    TempoPart := Copy(BarsPart, AtPos + 1, MaxInt);
    BarsPart := Copy(BarsPart, 1, AtPos - 1);
  end;

  for I := 1 to Length(NamePart) do
    if not IsNameChar(NamePart[I], I = 1) then
      raise Exception.CreateFmt(
        'Invalid --section "%s": the name must start with a letter and contain only letters, digits, _ and -',
        [ASpec]);

  if not TryStrToInt(BarsPart, Result.Bars) then
    raise Exception.CreateFmt('Invalid --section "%s": "%s" is not a bar count (%s)',
      [ASpec, BarsPart, SYNTAX_HELP]);
  if (Result.Bars < 1) or (Result.Bars > MAX_SECTION_BARS) then
    raise Exception.CreateFmt('Invalid --section "%s": bars must be between 1 and %d',
      [ASpec, MAX_SECTION_BARS]);

  if AtPos > 0 then
  begin
    if not TryStrToInt(TempoPart, Result.Tempo) then
      raise Exception.CreateFmt('Invalid --section "%s": "%s" is not a tempo (%s)',
        [ASpec, TempoPart, SYNTAX_HELP]);
    if (Result.Tempo < MIN_SECTION_TEMPO) or (Result.Tempo > MAX_SECTION_TEMPO) then
      raise Exception.CreateFmt('Invalid --section "%s": tempo must be between %d and %d BPM',
        [ASpec, MIN_SECTION_TEMPO, MAX_SECTION_TEMPO]);
  end;

  Result.Name := LowerCase(NamePart);
end;

function DescribeStructure(const AStructure: array of TSectionDef): string;
var
  I: Integer;
  Part: string;
begin
  Result := '';
  for I := 0 to High(AStructure) do
  begin
    Part := Format('%s:%d', [AStructure[I].Name, AStructure[I].Bars]);
    if AStructure[I].Tempo > 0 then
      Part := Part + '@' + IntToStr(AStructure[I].Tempo);
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + Part;
  end;
end;

{ ---- structure file --------------------------------------------------- }

function ReadTextFile(const APath: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[1], Stream.Size);
  finally
    Stream.Free;
  end;
  { A UTF-8 byte order mark would stop the JSON parser. }
  if (Length(Result) >= 3) and (Result[1] = #$EF) and (Result[2] = #$BB) and
     (Result[3] = #$BF) then
    Delete(Result, 1, 3);
end;

function TypeName(AData: TJSONData): string;
begin
  case AData.JSONType of
    jtNumber: Result := 'a number';
    jtString: Result := 'a string';
    jtBoolean: Result := 'true/false';
    jtNull: Result := 'null';
    jtArray: Result := 'a list';
    jtObject: Result := 'an object';
  else
    Result := 'something else';
  end;
end;

function LoadStructureFile(const APath: string): TStructureInfo;
var
  Root, SectionObj: TJSONObject;
  Data, Item: TJSONData;
  SectionsArr: TJSONArray;
  Text: string;
  I, J: Integer;

  procedure Fail(const AWhere, AMessage: string);
  begin
    raise Exception.CreateFmt('Structure file "%s": %s%s', [APath,
      AWhere, AMessage]);
  end;

  procedure Warn(const AMessage: string);
  begin
    SetLength(Result.Warnings, Length(Result.Warnings) + 1);
    Result.Warnings[High(Result.Warnings)] := AMessage;
  end;

  function WholeNumber(AValue: TJSONData; const AWhere, AKey: string;
    ALow, AHigh: Integer): Integer;
  var
    F: Double;
  begin
    if AValue.JSONType <> jtNumber then
      Fail(AWhere, Format('"%s" must be a number, got %s', [AKey, TypeName(AValue)]));
    F := AValue.AsFloat;
    if Frac(F) <> 0 then
      Fail(AWhere, Format('"%s" must be a whole number, got %s', [AKey, AValue.AsString]));
    if (F < ALow) or (F > AHigh) then
      Fail(AWhere, Format('"%s" must be between %d and %d, got %s',
        [AKey, ALow, AHigh, AValue.AsString]));
    Result := Round(F);
  end;

  function Text0(AValue: TJSONData; const AWhere, AKey: string): string;
  begin
    if AValue.JSONType <> jtString then
      Fail(AWhere, Format('"%s" must be text, got %s', [AKey, TypeName(AValue)]));
    Result := Trim(AValue.AsString);
  end;

  { time_signature must be [4, 4] - other meters need pattern work first. }
  procedure CheckMeter(AValue: TJSONData; const AWhere: string);
  var
    Arr: TJSONArray;
  begin
    if (AValue.JSONType <> jtArray) or (TJSONArray(AValue).Count <> 2) then
      Fail(AWhere, '"time_signature" must be a list of two numbers, like [4, 4]');
    Arr := TJSONArray(AValue);
    if (Arr[0].JSONType <> jtNumber) or (Arr[1].JSONType <> jtNumber) then
      Fail(AWhere, '"time_signature" must be a list of two numbers, like [4, 4]');
    if (Arr[0].AsInteger <> 4) or (Arr[1].AsInteger <> 4) then
      Fail(AWhere, Format('time signature %d/%d is not supported yet, only 4/4',
        [Arr[0].AsInteger, Arr[1].AsInteger]));
  end;

  function ParseSection(AIndex: Integer; AObj: TJSONObject): TSectionDef;
  var
    Where, Key: string;
    HasName, HasBars: Boolean;
    F: Double;
    K, C: Integer;
  begin
    Result.Name := '';
    Result.Bars := 0;
    Result.Tempo := 0;
    Result.HasComplexity := False;
    Result.Complexity := 0.0;
    HasName := False;
    HasBars := False;
    Where := Format('section %d: ', [AIndex + 1]);

    { The name first, so every following message can show it. }
    Item := AObj.Find('name');
    if Item <> nil then
    begin
      Result.Name := LowerCase(Text0(Item, Where, 'name'));
      HasName := Result.Name <> '';
      if Length(Result.Name) > MAX_SECTION_NAME then
        Fail(Where, Format('the name is longer than %d characters', [MAX_SECTION_NAME]));
      for C := 1 to Length(Result.Name) do
        if Result.Name[C] < ' ' then
          Fail(Where, 'the name contains a control character');
    end;
    if not HasName then
      Fail(Where, 'every section needs a "name"');
    Where := Format('section %d ("%s"): ', [AIndex + 1, Result.Name]);

    for K := 0 to AObj.Count - 1 do
    begin
      Key := AObj.Names[K];
      Item := AObj.Items[K];
      case LowerCase(Key) of
        'name': ;
        'bars':
          begin
            Result.Bars := WholeNumber(Item, Where, 'bars', 1, MAX_SECTION_BARS);
            HasBars := True;
          end;
        'tempo':
          Result.Tempo := WholeNumber(Item, Where, 'tempo',
            MIN_SECTION_TEMPO, MAX_SECTION_TEMPO);
        'complexity':
          begin
            if Item.JSONType <> jtNumber then
              Fail(Where, Format('"complexity" must be a number, got %s', [TypeName(Item)]));
            F := Item.AsFloat;
            if (F < 0.0) or (F > 1.0) then
              Fail(Where, Format('"complexity" must be between 0 and 1, got %s',
                [Item.AsString]));
            Result.Complexity := F;
            Result.HasComplexity := True;
          end;
        'time_signature': CheckMeter(Item, Where);
        'pattern_template', 'fill_policy':
          Warn(Format('%s"%s" is not supported yet and is ignored', [Where, Key]));
      else
        Warn(Format('%sunknown key "%s" is ignored', [Where, Key]));
      end;
    end;
    if not HasBars then
      Fail(Where, 'every section needs "bars"');
  end;

begin
  Result.Genre := '';
  Result.Style := '';
  Result.Tempo := 0;
  Result.Sections := nil;
  Result.Warnings := nil;

  if not FileExists(APath) then
    raise Exception.CreateFmt('Structure file not found: %s', [APath]);

  Text := ReadTextFile(APath);
  try
    Data := GetJSON(Text);
  except
    on E: Exception do
      raise Exception.CreateFmt('Structure file "%s" is not valid JSON: %s',
        [APath, E.Message]);
  end;

  try
    if (Data = nil) or (Data.JSONType <> jtObject) then
      Fail('', 'the top level must be an object like {"sections": [...]}');
    Root := TJSONObject(Data);

    for I := 0 to Root.Count - 1 do
    begin
      Item := Root.Items[I];
      case LowerCase(Root.Names[I]) of
        'source', 'title', 'name', 'sections', '_comment', 'comment': ;
        'genre': Result.Genre := LowerCase(Text0(Item, '', 'genre'));
        'style': Result.Style := LowerCase(Text0(Item, '', 'style'));
        'tempo': Result.Tempo := WholeNumber(Item, '', 'tempo',
          MIN_SECTION_TEMPO, MAX_SECTION_TEMPO);
        'time_signature': CheckMeter(Item, '');
        'pattern_template', 'fill_policy':
          Warn(Format('"%s" is not supported yet and is ignored', [Root.Names[I]]));
      else
        Warn(Format('unknown key "%s" is ignored', [Root.Names[I]]));
      end;
    end;

    Item := Root.Find('sections');
    if (Item = nil) or (Item.JSONType <> jtArray) then
      Fail('', 'needs a "sections" list');
    SectionsArr := TJSONArray(Item);
    if SectionsArr.Count = 0 then
      Fail('', 'the "sections" list is empty');
    if SectionsArr.Count > MAX_SECTIONS then
      Fail('', Format('has %d sections, the limit is %d', [SectionsArr.Count, MAX_SECTIONS]));

    SetLength(Result.Sections, SectionsArr.Count);
    for J := 0 to SectionsArr.Count - 1 do
    begin
      Item := SectionsArr[J];
      if Item.JSONType <> jtObject then
        Fail(Format('section %d: ', [J + 1]),
          Format('must be an object like {"name": "verse", "bars": 8}, got %s', [TypeName(Item)]));
      SectionObj := TJSONObject(Item);
      Result.Sections[J] := ParseSection(J, SectionObj);
    end;
  finally
    Data.Free;
  end;
end;

end.
