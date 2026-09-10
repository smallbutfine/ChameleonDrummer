unit kit;

{$mode objfpc}{$H+}

{ DrumKit - drum kit configuration and instrument mapping.
  All MIDI note mappings are loaded dynamically from JSON keymap files in midi_drums/mappings/.
  No MIDI notes or instrument names are hardcoded anywhere. All instruments come from the master template. }

interface

uses
  Classes, SysUtils, fpjson, Generics.Collections;

type
  { Type aliases for FPC 3.2.x compatibility }
  TStrDict = specialize TDictionary<string, string>;
  TStrBoolDict = specialize TDictionary<string, boolean>;
  TJVal = fpjson.TJSONData;
  TJObj = fpjson.TJSONObject;

{ KeymapStore - stores loaded keymaps (TJSONObject per stem name) }
TKeymapStore = specialize TDictionary<string, TJVal>;


{ DrumInstrument - dynamic drum instrument identity.
  All instruments are registered at runtime from the master template keymap.
  MIDI note mappings live in separate JSON keymap files. }
TDrumInstrument = class(TObject)
private
  FName: string;
  FDescription: string;
  FMetadata: TStrDict;
protected
  procedure SetName(const Value: string);
  procedure SetDescription(const Value: string);
public
  constructor Create(const AName, ADescription: string; const AMetadata: TStrDict = nil); overload;
  destructor Destroy; override;

  { Properties }
  property Name: string read FName write SetName;
  property Description: string read FDescription write SetDescription;
  property Metadata: TStrDict read FMetadata;

  { Equality }
  function Equals(Other: TDrumInstrument): boolean;
end;

type
  TDrumInstrumentArray = array of TDrumInstrument;

{ InstrumentRegistry - manages all registered drum instruments.
  Initialized from the master template at startup. }
TInstrumentRegistry = class(TObject)
private
  class var Finstruments: specialize TDictionary<string, TDrumInstrument>;
  class var FInitialized: boolean;
  class procedure ClearInternal; static;
public
  class procedure Clear; static;
  class function Register(const AName: string; const ADescription: string = ''; const AMetadata: TStrDict = nil): TDrumInstrument; static;
  class function Get(const AName: string): TDrumInstrument; static;
  class function GetAll: TDrumInstrumentArray; static;
  class function GetAllNames: TStrBoolDict; static;
  class procedure LoadFromTemplate(const ATemplatePath: string = ''); static;
  class procedure EnsureLoaded; static;

  class constructor Create;
  class destructor Destroy;
end;

{ KeymapLoader - loads and manages keymap JSON files from the mappings directory. }
TKeymapLoader = class(TObject)
private
  FLoadedKeymaps: TKeymapStore;
public
  class function LoadAll: specialize TArray<TJVal>; static;
  class function GetKeymap(const AName: string): TJVal; static;
  class function GetMidiNote(const InstrumentName, KeymapName: string): Integer; static;
  class function GetAllInstruments: TStrBoolDict; static;
  class function GetUnmappedInstruments(const KeymapName: string): TStrBoolDict; static;
  class procedure GenerateUserKeymap(const TargetPath: string); static;

  class constructor Create;
  class destructor Destroy;
end;

{ VelocityRange - velocity range for realistic drum dynamics. }
TVelocityRange = class
private
  FMinVelocity: Integer;
  FMaxVelocity: Integer;
  FDefaultVelocity: Integer;
public
  constructor Create(AMin, AMax, ADefault: Integer);
  procedure Validate;
  property MinVelocity: Integer read FMinVelocity;
  property MaxVelocity: Integer read FMaxVelocity;
  property DefaultVelocity: Integer read FDefaultVelocity;
end;

{ DrumKit - the main class that uses dynamic instrument resolution }
TDrumKit = class(TObject)
private
  FVelocityRanges: specialize TDictionary<string, TVelocityRange>;
  FCustomMappings: specialize TDictionary<string, Integer>;
public
  Name: string;
  Channel: Integer;

  constructor Create(const AName: string; AChannel: Integer);
  destructor Destroy; override;

  { Get MIDI note for an instrument by name.
    Resolution order:
      1. custom_mappings if present
      2. Keymap file for the given preset
      3. -1 (nil) if not found }
  function GetMidiNote(const InstrumentName, KeymapName: string): Integer;

  { Get velocity range for an instrument type. }
  function GetVelocityRange(const InstrumentType: string): TVelocityRange;

  { Randomize velocity within the instrument's range. }
  function RandomizeVelocity(const InstrumentType: string; BaseVelocity: Integer = -1): Integer;

  { Create a DrumKit from a keymap file by name. }
  class function FromKeymapName(const KeymapName: string): TDrumKit; static;

  { List all available keymaps as presets. }
  class function ListPresets: specialize TDictionary<string, string>; static;

  { Create a DrumKit from a mapping file name (exact file stem). }
  class function FromPreset(const PresetName: string): TDrumKit; static;

  { Create a DrumKit from a custom mapping JSON file. }
  class function FromJson(const Path: string): TDrumKit; static;
end;

{ Module Initialization }
procedure Initialize;

implementation

{ Forward declarations }
function FileToStr(const AFilename: string): string;

{
  { ── DrumInstrument implementation ──────────────────────────────────────── }

constructor TDrumInstrument.Create(const AName, ADescription: string; const AMetadata: TStrDict = nil);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  if Assigned(AMetadata) then
    FMetadata := AMetadata
  else
    FMetadata := TStrDict.Create;
end;

destructor TDrumInstrument.Destroy;
begin
  FMetadata.Free;
  inherited Destroy;
end;

procedure TDrumInstrument.SetName(const Value: string);
begin
  FName := Value;
end;

procedure TDrumInstrument.SetDescription(const Value: string);
begin
  FDescription := Value;
end;

function TDrumInstrument.Equals(Other: TDrumInstrument): boolean;
begin
  if not Assigned(Other) then
    Exit(false);
  Result := FName = Other.FName;
end;

{ ── InstrumentRegistry implementation ──────────────────────────────────── }

class constructor TInstrumentRegistry.Create;
begin
  Finstruments := specialize TDictionary<string, TDrumInstrument>.Create;
  FInitialized := false;
end;

class destructor TInstrumentRegistry.Destroy;
begin
  Finstruments.Free;
end;

class procedure TInstrumentRegistry.ClearInternal;
begin
  Finstruments.Clear;
  FInitialized := false;
end;

class procedure TInstrumentRegistry.Clear;
begin
  ClearInternal;
end;

class function TInstrumentRegistry.Register(const AName: string; const ADescription: string = ''; const AMetadata: TStrDict = nil): TDrumInstrument;
var
  Inst: TDrumInstrument;
begin
  if Finstruments.TryGetValue(AName, Result) then
    Exit;

  Inst := TDrumInstrument.Create(AName, ADescription, AMetadata);
  Finstruments.Add(AName, Inst);
  Result := Inst;
end;

class function TInstrumentRegistry.Get(const AName: string): TDrumInstrument;
begin
  if Finstruments.TryGetValue(AName, Result) then
    Exit;
  Result := nil;
end;

class function TInstrumentRegistry.GetAll: TDrumInstrumentArray;
var
  Item: specialize TPair<string, TDrumInstrument>;
  Count, I: Integer;
begin
  Count := Finstruments.Count;
  SetLength(Result, Count);
  I := 0;
  for Item in Finstruments do
  begin
    Result[I] := Item.Value;
    Inc(I);
  end;
end;

class function TInstrumentRegistry.GetAllNames: TStrBoolDict;
var
  Item: specialize TPair<string, TDrumInstrument>;
begin
  Result := specialize TDictionary<string, boolean>.Create;
  for Item in Finstruments do
    Result.Add(Item.Key, true);
end;

class procedure TInstrumentRegistry.LoadFromTemplate(const ATemplatePath: string);
var
  TemplatePath, InstName, InstDesc, SourceStr: string;
  JsonValue, Instruments: TJVal;
  InstObj: TJVal;
  Inst: TDrumInstrument;
  Metadata: TStrDict;
  I: Integer;
  ElemCount: Integer;
begin
  if FInitialized then
    Exit;

  if ATemplatePath = '' then
  begin
    TemplatePath := ExtractFilePath(ParamStr(0)) + 'mappings' + DirectorySeparator + 'template.json';
  end
  else
    TemplatePath := ATemplatePath;

  if not FileExists(TemplatePath) then
    raise Exception.Create('Template not found at ' + TemplatePath);

  { Read entire template file }
  JsonValue := GetJSON(FileToStr(TemplatePath), true);
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then
      raise Exception.Create('Invalid template JSON: expected object');
    Instruments := TJObj(JsonValue);

    { Iterate over all instrument entries in the 'instruments' sub-object }
    ElemCount := Instruments.Count;
    for I := 0 to ElemCount - 1 do
    begin
      InstName := Instruments.Name[I];
      InstObj := Instruments[I][I];
      
      if not Assigned(InstObj) or (InstObj.JsonType <> jtObject) then
        Continue;

      { Extract description field }
      InstDesc := '';
      if InstObj.Count > 0 then
      begin
        for I := 0 to InstObj.Count - 1 do
        begin
          if SameText(InstObj.Name[I], 'description') then
          begin
            InstDesc := InstObj[I][I].AsString;
            Break;
          end;
        end;
      end;

      { Source metadata }
      Metadata := TStrDict.Create;
      try
        for I := 0 to Instruments.Count - 1 do
        begin
          if SameText(Instruments.Name[I], 'source') then
          begin
            SourceStr := Instruments[I][I].AsString;
            if Length(SourceStr) > 0 then
              Metadata.Add('source', SourceStr);
            Break;
          end;
        end;

        Inst := Register(InstName, InstDesc, Metadata);
      finally
        Metadata.Free;
      end;
    end;
  finally
    JsonValue.Free;
  end;

  FInitialized := true;
end;

class procedure TInstrumentRegistry.EnsureLoaded;
begin
  if not FInitialized then
    LoadFromTemplate;
end;

{ ── KeymapLoader implementation ────────────────────────────────────────── }

class constructor TKeymapLoader.Create;
begin
  FLoadedKeymaps := specialize TKeymapStore.Create;
end;

class destructor TKeymapLoader.Destroy;
var
  Item: specialize TPair<string, TJVal>;
begin
  for Item in FLoadedKeymaps do
    if Assigned(Item.Value) then
      Item.Value.Free;
  FLoadedKeymaps.Free;
end;

{ Read a file to string }
function FileToStr(const AFilename: string): string;
var
  F: TStream;
begin
  F := TFileStream.Create(AFilename, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then
      F.ReadBuffer(Pointer(Result)^, F.Size);
  finally
    F.Free;
  end;
end;

class function TKeymapLoader.LoadAll: specialize TArray<TJVal>;
var
  DirHandle: TSearchRec;
  FilePath, MappingsDir, FileName, FileStem: string;
  JsonValue: TJVal;
  I, Count: Integer;
  Item: specialize TPair<string, TJVal>;
begin
  FLoadedKeymaps.Clear;

  MappingsDir := ExtractFilePath(ParamStr(0)) + 'mappings' + DirectorySeparator;
  if not DirectoryExists(MappingsDir) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  if FindFirst(MappingsDir + '*.json', faAnyFile, DirHandle) = 0 then
  try
    repeat
      if (DirHandle.Name <> '.') and (DirHandle.Name <> '..') then
      begin
        FilePath := MappingsDir + DirHandle.Name;
        FileName := ExtractFileName(DirHandle.Name);
        FileStem := ChangeFileExt(FileName, '');

        JsonValue := GetJSON(FileToStr(FilePath), true);
        if Assigned(JsonValue) then
          FLoadedKeymaps.Add(FileStem, JsonValue);
      end;
    until FindNext(DirHandle) <> 0;
  finally
    FindClose(DirHandle);
  end;

  Count := FLoadedKeymaps.Count;
  SetLength(Result, Count);
  I := 0;
  for Item in FLoadedKeymaps do
  begin
    Result[I] := TJVal(Item.Value);
    Inc(I);
  end;
end;

class function TKeymapLoader.GetKeymap(const AName: string): TJVal;
var
  Found: boolean;
begin
  if FLoadedKeymaps.TryGetValue(AName, Result) then
    Exit;

  { Case-insensitive fallback }
  for Found in FLoadedKeymaps do
  begin
    if SameText(Found.Key, AName) then
    begin
      Result := TJVal(Found.Value);
      Exit;
    end;
  end;

  Result := nil;
end;

class function TKeymapLoader.GetMidiNote(const InstrumentName, KeymapName: string): Integer;
var
  Keymap, InstrumentData, MidiNoteVal: TJVal;
  Instruments: TJObj;
begin
  if FLoadedKeymaps.Count = 0 then
    LoadAll;

  Keymap := GetKeymap(KeymapName);
  if not Assigned(Keymap) or (Keymap.JsonType <> jtObject) then
    Exit(-1);

  Instruments := TJObj(Keymap);
  InstrumentData := Instruments.FindElement(InstrumentName);
  if not Assigned(InstrumentData) or (InstrumentData.JsonType <> jtObject) then
    Exit(-1);

  { Get midi_note value }
  MidiNoteVal := InstrumentData.FindElement('midi_note');
  if not Assigned(MidiNoteVal) or (MidiNoteVal.JsonType = jtNull) then
    Exit(-1);

  Result := StrToIntDef(MidiNoteVal.AsString, -1);
end;

class function TKeymapLoader.GetAllInstruments: TStrBoolDict;
var
  Item: specialize TPair<string, TJVal>;
  Instruments: TJObj;
  KeymapName: string;
  I: Integer;
begin
  Result := specialize TDictionary<string, boolean>.Create;
  for Item in FLoadedKeymaps do
  begin
    if Assigned(Item.Value) and (Item.Value.JsonType = jtObject) then
    begin
      Instruments := TJObj(Item.Value);
      for I := 0 to Instruments.Count - 1 do
      begin
        KeymapName := Instruments.Name[I];
        Result.Add(KeymapName, true);
      end;
    end;
  end;
end;

class function TKeymapLoader.GetUnmappedInstruments(const KeymapName: string): TStrBoolDict;
var
  AllInstruments: TStrBoolDict;
  Keymap, InstrumentData, MidiNoteVal: TJVal;
  Instruments: TJObj;
  MappedName: string;
  I: Integer;
begin
  AllInstruments := GetAllInstruments;

  Keymap := GetKeymap(KeymapName);
  if not Assigned(Keymap) then
  begin
    Result := AllInstruments;
    Exit;
  end;

  if Keymap.JsonType <> jtObject then
  begin
    Result := AllInstruments;
    Exit;
  end;

  Instruments := TJObj(Keymap);
  Result := specialize TDictionary<string, boolean>.Create;
  
  for MappedName in GetAllInstruments do
  begin
    InstrumentData := Instruments.FindElement(MappedName);
    if Assigned(InstrumentData) and (InstrumentData.JsonType = jtObject) then
    begin
      MidiNoteVal := InstrumentData.FindElement('midi_note');
      if not Assigned(MidiNoteVal) or (MidiNoteVal.JsonType = jtNull) then
        Continue;
      { Mapped - remove from result }
      AllInstruments.Remove(MappedName);
    end;
  end;

  Result := specialize TDictionary<string, boolean>.Create;
  for MappedName in AllInstruments do
    Result.Add(MappedName, true);
end;

class procedure TKeymapLoader.GenerateUserKeymap(const TargetPath: string);
var
  Template, Instruments: TJVal;
  Output, InstrumentsObj, InstObj: TJObj;
  InstName, DescStr: string;
  I, J: Integer;
  DescVal: TJVal;
begin
  Template := GetKeymap('template');
  if not Assigned(Template) or (Template.JsonType <> jtObject) then
    raise Exception.Create('No template keymap found in mappings directory.');

  Instruments := TJObj(Template);
  Output := TJObj.Create;
  try
    { Set metadata fields }
    TJObj(Output).Count := 0;
    { Name }
    J := TJObj(Output).Count;
    TJObj(Output).Elements[J] := TJObj.Create;
    TJObj(TJObj(Output).Elements[J]).Name[0] := 'name';
    TJObj(TJObj(Output).Elements[J])[I][0] := CreateJSONString('User Custom Kit');
    
    { Version }
    DescVal := Instruments.FindElement('version');
    if Assigned(DescVal) and (DescVal.JsonType = jtString) then
    begin
      J := TJObj(Output).Count;
      TJObj(Output).Elements[J] := TJObj.Create;
      TJObj(TJObj(Output).Elements[J]).Name[0] := 'version';
      TJObj(TJObj(Output).Elements[J])[I][0] := CreateJSONString(DescVal.AsString);
    end;

    { Description }
    J := TJObj(Output).Count;
    TJObj(Output).Elements[J] := TJObj.Create;
    TJObj(TJObj(Output).Elements[J]).Name[0] := 'description';
    TJObj(TJObj(Output).Elements[J])[I][0] := CreateJSONString('Custom keymap - fill in midi_note values. Leave as null for unavailable articulations.');

    { Source }
    J := TJObj(Output).Count;
    TJObj(Output).Elements[J] := TJObj.Create;
    TJObj(TJObj(Output).Elements[J]).Name[0] := 'source';
    TJObj(TJObj(Output).Elements[J])[I][0] := CreateJSONString('User generated from template');

    { Instruments sub-object }
    InstrumentsObj := TJObj.Create;
    for I := 0 to Instruments.Count - 1 do
    begin
      InstName := Instruments.Name[I];
      InstObj := TJObj.Create;
      
      { midi_note is omitted (effectively null) for user to fill in }
      DescVal := GetJsonValue(TJObj(Instruments.FindElement(InstName)), 'description');
      if Assigned(DescVal) and (DescVal.JsonType = jtString) then
      begin
        J := TJObj(InstObj).Count;
        TJObj(InstObj).Elements[J] := TJObj.Create;
        TJObj(TJObj(InstObj).Elements[J]).Name[0] := 'description';
        TJObj(TJObj(InstObj).Elements[J])[I][0] := CreateJSONString(DescVal.AsString);
      end;
      
      TJObj(InstrumentsObj).AddObject(InstName, InstObj);
    end;
    
    J := TJObj(Output).Count;
    TJObj(Output).Elements[J] := TJObj.Create;
    TJObj(TJObj(Output).Elements[J]).Name[0] := 'instruments';
    TJObj(TJObj(Output).Elements[J])[I][0] := InstrumentsObj;

    { Write JSON to file }
    TFile.WriteAllText(TargetPath, Output.AsJSON);
  finally
    Output.Free;
  end;
end;

{ ── VelocityRange implementation ──────────────────────────────────────── }

constructor TVelocityRange.Create(AMin, AMax, ADefault: Integer);
begin
  FMinVelocity := AMin;
  FMaxVelocity := AMax;
  FDefaultVelocity := ADefault;
end;

procedure TVelocityRange.Validate;
var
  VelArray: array[0..2] of Integer;
  I: Integer;
begin
  VelArray[0] := MinVelocity;
  VelArray[1] := MaxVelocity;
  VelArray[2] := DefaultVelocity;
  for I := Low(VelArray) to High(VelArray) do
  begin
    if (VelArray[I] < 1) or (VelArray[I] > 127) then
      raise Exception.CreateFmt('Velocity must be 1-127, got %d', [VelArray[I]]);
  end;
  if MinVelocity > MaxVelocity then
    raise Exception.Create('Min velocity cannot be greater than max velocity');
end;

{ ── DrumKit implementation ───────────────────────────────────────────── }

constructor TDrumKit.Create(const AName: string; AChannel: Integer);
begin
  inherited Create;
  Name := AName;
  Channel := AChannel;
  FVelocityRanges := specialize TDictionary<string, TVelocityRange>.Create;
  FCustomMappings := specialize TDictionary<string, Integer>.Create;

  { Default velocity ranges }
  FVelocityRanges.Add('kick', TVelocityRange.Create(95, 120, 110));
  FVelocityRanges.Add('snare', TVelocityRange.Create(90, 127, 115));
  FVelocityRanges.Add('hihat', TVelocityRange.Create(60, 100, 80));
  FVelocityRanges.Add('toms', TVelocityRange.Create(85, 115, 100));
  FVelocityRanges.Add('cymbals', TVelocityRange.Create(70, 120, 95));
  FVelocityRanges.Add('ride', TVelocityRange.Create(65, 100, 80));
end;

destructor TDrumKit.Destroy;
begin
  FVelocityRanges.Free;
  FCustomMappings.Free;
  inherited Destroy;
end;

function TDrumKit.GetMidiNote(const InstrumentName, KeymapName: string): Integer;
var
  Note: Integer;
begin
  { Check custom mappings first }
  if FCustomMappings.TryGetValue(InstrumentName, Note) then
    Exit(Note);

  { Fall back to keymap lookup }
  Result := TKeymapLoader.GetMidiNote(InstrumentName, KeymapName);
end;

function TDrumKit.GetVelocityRange(const InstrumentType: string): TVelocityRange;
begin
  if FVelocityRanges.TryGetValue(InstrumentType, Result) then
    Exit;
  Result := TVelocityRange.Create(1, 127, 100);
end;

function TDrumKit.RandomizeVelocity(const InstrumentType: string; BaseVelocity: Integer = -1): Integer;
var
  VelRange: TVelocityRange;
  MinVel, MaxVel: Integer;
begin
  VelRange := GetVelocityRange(InstrumentType);

  if BaseVelocity = -1 then
  begin
    MinVel := VelRange.MinVelocity;
    MaxVel := VelRange.MaxVelocity;
  end
  else
  begin
    MinVel := Max(VelRange.MinVelocity, BaseVelocity - 15);
    MaxVel := Min(VelRange.MaxVelocity, BaseVelocity + 15);
  end;

  Result := Random(MaxVel - MinVel + 1) + MinVel;
end;

class function TDrumKit.FromKeymapName(const KeymapName: string): TDrumKit;
var
  Keymap, InstrumentData, MidiNoteVal: TJVal;
  Instruments: TJObj;
  InstName: string;
  I: Integer;
  CustomMappings: specialize TDictionary<string, Integer>;
begin
  TInstrumentRegistry.EnsureLoaded;

  Keymap := TKeymapLoader.GetKeymap(KeymapName);
  if not Assigned(Keymap) or (Keymap.JsonType <> jtObject) then
    raise Exception.Create('Keymap not found: ' + KeymapName);

  Instruments := TJObj(Keymap);
  CustomMappings := specialize TDictionary<string, Integer>.Create;
  try
    for I := 0 to Instruments.Count - 1 do
    begin
      InstName := Instruments.Name[I];
      InstrumentData := Instruments.FindElement(InstName);
      if Assigned(InstrumentData) and (InstrumentData.JsonType = jtObject) then
      begin
        MidiNoteVal := InstrumentData.FindElement('midi_note');
        if Assigned(MidiNoteVal) and (MidiNoteVal.JsonType <> jtNull) then
          CustomMappings.Add(InstName, StrToIntDef(MidiNoteVal.AsString, -1));
      end;
    end;

    Result := TDrumKit.Create(Keymap.FindElement('name').AsString, 9);
    Result.FCustomMappings := CustomMappings;
  except
    CustomMappings.Free;
    raise;
  end;
end;

class function TDrumKit.ListPresets: specialize TDictionary<string, string>;
var
  Item: specialize TPair<string, TJVal>;
begin
  if TKeymapLoader.FLoadedKeymaps.Count = 0 then
    TKeymapLoader.LoadAll;

  Result := specialize TDictionary<string, string>.Create;
  for Item in TKeymapLoader.FLoadedKeymaps do
  begin
    if Item.Key <> 'template' and Assigned(Item.Value) and (Item.Value.JsonType = jtObject) then
      Result.Add(Item.Key, GetJsonValueString(TJObj(Item.Value), 'description'));
  end;
end;

class function TDrumKit.FromPreset(const PresetName: string): TDrumKit;
var
  Keymap: TJVal;
begin
  Keymap := TKeymapLoader.GetKeymap(PresetName);
  if not Assigned(Keymap) then
    raise Exception.Create('Unknown mapping ' + PresetName + '. Must be a JSON file stem in mappings/ (e.g. template, gm, ad2, ezd3, xg).');

  Result := FromKeymapName(PresetName);
end;

class function TDrumKit.FromJson(const Path: string): TDrumKit;
var
  JsonValue, InstrumentsObj, InstsObj, NameVal, NoteVal: TJVal;
  Instruments, InstObj: TJObj;
  InstName: string;
  I: Integer;
begin
  if Path = '' then
    raise Exception.Create('Cannot create DrumKit from None path');

  JsonValue := GetJSON(FileToStr(Path), true);
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then
      raise Exception.Create('Invalid JSON: expected object at ' + Path);
    Instruments := TJObj(JsonValue);

    Result := TDrumKit.Create('', 9);
    NameVal := GetJsonValue(Instruments, 'name');
    if Assigned(NameVal) and (NameVal.JsonType = jtString) then
      Result.Name := NameVal.AsString;

    InstsObj := GetJsonValue(Instruments, 'instruments');
    if Assigned(InstsObj) and (InstsObj.JsonType = jtObject) then
    begin
      for I := 0 to TJObj(InstsObj).Count - 1 do
      begin
        InstName := TJObj(InstsObj).Name[I];
        InstObj := TJObj(GetJsonValue(TJObj(InstsObj), InstName));
        if not Assigned(InstObj) then Continue;
        
        NoteVal := GetJsonValue(InstObj, 'midi_note');
        if Assigned(NoteVal) and (NoteVal.JsonType <> jtNull) then
          Result.FCustomMappings.Add(InstName, StrToIntDef(NoteVal.AsString, -1));
      end;
    end;
  finally
    JsonValue.Free;
  end;
end;

{ ── Helper functions ─────────────────────────────────────────────────── }

function GetJsonValue(Obj: TJVal; const AKey: string): TJVal;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(Obj) then Exit;
  if Obj.JsonType <> jtObject then Exit;
  for I := 0 to TJObj(Obj).Count - 1 do
    if SameText(TJObj(Obj).Name[I], AKey) then
    begin
      Result := TJObj(Obj)[I][I];
      Exit;
    end;
end;

function GetJsonValueString(AJsonVal: TJVal; const AKey: string): string;
var
  Data: TJVal;
begin
  Result := '';
  if not Assigned(AJsonVal) or (AJsonVal.JsonType <> jtObject) then Exit;
  Data := GetJsonValue(AJsonVal, AKey);
  if Assigned(Data) and (Data.JsonType = jtString) then
    Result := Data.AsString;
end;

function IsJsonValueNull(Data: TJVal): boolean;
begin
  Result := not Assigned(Data) or (Assigned(Data) and (Data.JsonType = jtNull));
end;

{ Module Initialization }
procedure Initialize;
begin
  TInstrumentRegistry.EnsureLoaded;
  TKeymapLoader.LoadAll;
end;

initialization

{ Initialize at import time so instruments are ready immediately }
Initialize;

end.
