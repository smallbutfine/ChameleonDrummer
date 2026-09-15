unit kit;

{$mode objfpc}{$H+}

{ DrumKit - drum kit configuration and instrument mapping.
  All MIDI note mappings are loaded dynamically from JSON keymap files in midi_drums/mappings/.
  No MIDI notes or instrument names are hardcoded anywhere. }

interface

uses
  Classes, SysUtils, fpjson, Generics.Collections, Math;

type
  TStrDict = specialize TDictionary<string, string>;
  TStrBoolDict = specialize TDictionary<string, boolean>;


{ DrumInstrument - dynamic drum instrument identity. }
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

  property Name: string read FName write SetName;
  property Description: string read FDescription write SetDescription;
  property Metadata: TStrDict read FMetadata;

  function Equals(Other: TDrumInstrument): boolean;
end;

type
  TDrumInstrumentArray = array of TDrumInstrument;

{ InstrumentRegistry - manages all registered drum instruments. }
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

{ KeymapLoader - loads and manages keymap JSON files. }
TKeymapLoader = class(TObject)
private
  class var FLoadedKeymaps: specialize TDictionary<string, TJSONData>;
public
  class function LoadAll: specialize TArray<TJSONData>; static;
  class function GetKeymap(const AName: string): TJSONData; static;
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

{ DrumKit - the main class that uses dynamic instrument resolution. }
TDrumKit = class(TObject)
private
  FVelocityRanges: specialize TDictionary<string, TVelocityRange>;
  FCustomMappings: specialize TDictionary<string, Integer>;
public
  Name: string;
  Channel: Integer;

  constructor Create(const AName: string; AChannel: Integer);
  destructor Destroy; override;

  function GetMidiNote(const InstrumentName, KeymapName: string): Integer;
  function GetVelocityRange(const InstrumentType: string): TVelocityRange;
  function RandomizeVelocity(const InstrumentType: string; BaseVelocity: Integer = -1): Integer;

  class function FromKeymapName(const KeymapName: string): TDrumKit; static;
  class function ListPresets: specialize TDictionary<string, string>; static;
  class function FromPreset(const PresetName: string): TDrumKit; static;
  class function FromJson(const Path: string): TDrumKit; static;
end;

procedure Initialize;
function FileToStr(const AFilename: string): string;

implementation


{ ── DrumInstrument ─────────────────────────────────────── }

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
  if not Assigned(Other) then Exit(false);
  Result := FName = Other.FName;
end;


{ ── InstrumentRegistry ─────────────────────────────────── }

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

class function TInstrumentRegistry.Register(const AName: string; const ADescription: string = ''; const AMetadata: specialize TDictionary<string, string> = nil): TDrumInstrument;
var
  Inst: TDrumInstrument;
begin
  if Finstruments.TryGetValue(AName, Result) then Exit;
  Inst := TDrumInstrument.Create(AName, ADescription, AMetadata);
  Finstruments.Add(AName, Inst);
  Result := Inst;
end;

class function TInstrumentRegistry.Get(const AName: string): TDrumInstrument;
begin
  if Finstruments.TryGetValue(AName, Result) then Exit;
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

class function TInstrumentRegistry.GetAllNames: specialize TDictionary<string, boolean>;
var
  Item: specialize TPair<string, TDrumInstrument>;
begin
  Result := specialize TDictionary<string, boolean>.Create;
  for Item in Finstruments do
    if not Result.ContainsKey(Item.Key) then
      Result.Add(Item.Key, true);
end;

class procedure TInstrumentRegistry.LoadFromTemplate(const ATemplatePath: string);
var
  TemplatePath, InstName, InstDesc: string;
  JsonValue, InstrumentsObj, DescVal: TJSONData;
  Instruments, InstObj: TJSONObject;
  Inst: TDrumInstrument;
  Metadata: TStrDict;
  SourceVal: TJSONData;
  I: Integer;
begin
  if FInitialized then Exit;

  if ATemplatePath = '' then
    TemplatePath := ExtractFilePath(ParamStr(0)) + 'mappings' + DirectorySeparator + 'template.json'
  else
    TemplatePath := ATemplatePath;

  if not FileExists(TemplatePath) then
    raise Exception.Create('Template not found at ' + TemplatePath);

  JsonValue := GetJSON(FileToStr(TemplatePath));
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then
      raise Exception.Create('Invalid template JSON: expected object');
    Instruments := TJSONObject(JsonValue);

    { Get the instruments object }
    InstrumentsObj := Instruments.Find('instruments');
    if not Assigned(InstrumentsObj) or (InstrumentsObj.JsonType <> jtObject) then
      raise Exception.Create('Template must have an "instruments" object');
    Instruments := TJSONObject(InstrumentsObj);

    { Get the source field }  
    SourceVal := Instruments.Find('source');

    InstName := '';
    for I := 0 to Instruments.Count - 1 do
    begin
      InstName := Instruments.Names[I];
      InstObj := Instruments.Objects[InstName];
      if not Assigned(InstObj) or (InstObj.JsonType <> jtObject) then Continue;
      InstObj := TJSONObject(InstObj);
      
      InstDesc := '';
      DescVal := InstObj.Find('description');
      if Assigned(DescVal) and (DescVal.JsonType = jtString) then
        InstDesc := DescVal.AsString;

      Metadata := TStrDict.Create;
      try
        if Assigned(SourceVal) and (SourceVal.JsonType <> jtNull) then
          Metadata.Add('source', SourceVal.AsString);

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
  if not FInitialized then LoadFromTemplate;
end;


{ ── KeymapLoader ──────────────────────────────────────── }

class constructor TKeymapLoader.Create;
begin
  FLoadedKeymaps := specialize TDictionary<string, TJSONData>.Create;
end;

class destructor TKeymapLoader.Destroy;
var
  Item: specialize TPair<string, TJSONData>;
begin
  for Item in FLoadedKeymaps do
    if Assigned(Item.Value) then Item.Value.Free;
  FLoadedKeymaps.Free;
end;

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

class function TKeymapLoader.LoadAll: specialize TArray<TJSONData>;
var
  DirHandle: TSearchRec;
  FilePath, MappingsDir, FileName, FileStem: string;
  JsonValue: TJSONData;
  I, Count: Integer;
  Item: specialize TPair<string, TJSONData>;
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
        
        if FLoadedKeymaps.ContainsKey(FileStem) then
          Continue; { Skip duplicate keymap names }    

        try
          JsonValue := GetJSON(FileToStr(FilePath));
          if Assigned(JsonValue) then
            try
              FLoadedKeymaps.Add(FileStem, JsonValue);
            except
              on E: Exception do
                WriteLn('[Warning] Failed to add keymap ' + FileStem + ': ' + E.Message);
            end;
        except
          on E: Exception do
            WriteLn('[Warning] Failed to load ' + FilePath + ': ' + E.Message);
        end;
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
    Result[I] := Item.Value;
    Inc(I);
  end;
end;

class function TKeymapLoader.GetKeymap(const AName: string): TJSONData;
var
  Item: specialize TPair<string, TJSONData>;
begin
  if FLoadedKeymaps.TryGetValue(AName, Result) then Exit;

  for Item in FLoadedKeymaps do
    if SameText(Item.Key, AName) then
    begin
      Result := Item.Value;
      Exit;
    end;

  Result := nil;
end;

class function TKeymapLoader.GetMidiNote(const InstrumentName, KeymapName: string): Integer;
var
  Keymap: TJSONData;
  Instruments, InstrumentData: TJSONObject;
  MidiNoteVal: TJSONData;
begin
  if FLoadedKeymaps.Count = 0 then
    LoadAll;

  Keymap := GetKeymap(KeymapName);
  if not Assigned(Keymap) then
    Exit(-1);

  Instruments := (Keymap as TJSONObject);
  if not Assigned(Instruments) then
    Exit(-1);

  InstrumentData := Instruments.Objects[InstrumentName];
  if not Assigned(InstrumentData) then
    Exit(-1);

  MidiNoteVal := InstrumentData.Find('midi_note');
  if (MidiNoteVal = nil) or (MidiNoteVal.JsonType = jtNull) then
    Exit(-1);

  Result := MidiNoteVal.AsInteger;
end;

class function TKeymapLoader.GetAllInstruments: TStrBoolDict;
var
  Item: specialize TPair<string, TJSONData>;
  KeymapName: string;
  I: Integer;
  Instruments: TJSONObject;
begin
  Result := specialize TDictionary<string, boolean>.Create;
  for Item in (FLoadedKeymaps as specialize TDictionary<string, TJSONData>) do
  begin
    Instruments := (Item.Value as TJSONObject);
    if Assigned(Instruments) then
      for I := 0 to Instruments.Count - 1 do
        Result.Add(Instruments.Names[I], true);
  end;
end;

class function TKeymapLoader.GetUnmappedInstruments(const KeymapName: string): TStrBoolDict;
var
  AllInstruments: TStrBoolDict;
  Keymap: TJSONData;
  Instruments, InstrumentData: TJSONObject;
  MidiNoteVal: TJSONData;
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

  Instruments := (Keymap as TJSONObject);
  Result := specialize TDictionary<string, boolean>.Create;
  for I := 0 to Instruments.Count - 1 do
  begin
    MappedName := Instruments.Names[I];
    InstrumentData := Instruments.Objects[MappedName];
    if Assigned(InstrumentData) then
    begin
      MidiNoteVal := InstrumentData.Find('midi_note');
      if (MidiNoteVal <> nil) and (MidiNoteVal.JsonType <> jtNull) then
        AllInstruments.Remove(MappedName);
    end;
  end;

  Result := AllInstruments;
end;

class procedure TKeymapLoader.GenerateUserKeymap(const TargetPath: string);
var
  Template, Output: TJSONData;
  InstrumentsObj: TJSONObject;
  Instruments, InstObj: TJSONObject;
  VersionVal, DescVal: TJSONData;
  I, FS: Integer;
  InstName: string;
begin
  Template := GetKeymap('template');
  if not Assigned(Template) then
    raise Exception.Create('No template keymap found in mappings directory.');

  Instruments := (Template as TJSONObject);
  Output := TJSONObject.Create;
  try
    (Output as TJSONObject).Strings['name'] := 'User Custom Kit';
    VersionVal := Instruments.Find('version');
    if Assigned(VersionVal) then
      (Output as TJSONObject).Strings['version'] := VersionVal.AsString;
    (Output as TJSONObject).Strings['description'] := 'Custom keymap - fill in midi_note values.';
    (Output as TJSONObject).Strings['source'] := 'User generated from template';

    InstrumentsObj := TJSONObject.Create;
    for I := 0 to Instruments.Count - 1 do
    begin
      InstName := Instruments.Names[I];
      InstObj := TJSONObject.Create;
      InstObj.Add('midi_note', TJSONData(nil));
      DescVal := Instruments.Objects[InstName].Find('description');
      if Assigned(DescVal) then
        InstObj.Strings['description'] := DescVal.AsString;
      InstrumentsObj.Objects[Instruments.Names[I]] := InstObj;
    end;

    (Output as TJSONObject).Objects['instruments'] := InstrumentsObj;

    FS := FileCreate(TargetPath);
    try
      FileWrite(FS, (Output as TJSONObject).AsJSON[1], Length((Output as TJSONObject).AsJSON));
    finally
      FileClose(FS);
    end;
  finally
    InstrumentsObj.Free;
    Output.Free;
  end;
end;


{ ── VelocityRange ─────────────────────────────────────── }

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
    if (VelArray[I] < 1) or (VelArray[I] > 127) then
      raise Exception.CreateFmt('Velocity must be 1-127, got %d', [VelArray[I]]);

  if MinVelocity > MaxVelocity then
    raise Exception.Create('Min velocity cannot be greater than max velocity');
end;


{ ── DrumKit ───────────────────────────────────────────── }

constructor TDrumKit.Create(const AName: string; AChannel: Integer);
begin
  inherited Create;
  Name := AName;
  Channel := AChannel;
  FVelocityRanges := specialize TDictionary<string, TVelocityRange>.Create;
  FCustomMappings := specialize TDictionary<string, Integer>.Create;

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
  if FCustomMappings.TryGetValue(InstrumentName, Note) then Exit(Note);
  Result := TKeymapLoader.GetMidiNote(InstrumentName, KeymapName);
end;

function TDrumKit.GetVelocityRange(const InstrumentType: string): TVelocityRange;
begin
  if FVelocityRanges.TryGetValue(InstrumentType, Result) then Exit;
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
  Keymap, InstrumentsObj, NameVal: TJSONData;
  RootObj, Instruments, InstrumentData: TJSONObject;
  MidiNoteVal: TJSONData;
  CustomMappings: specialize TDictionary<string, Integer>;
  InstName: string;
  I: Integer;
begin
  try
    TInstrumentRegistry.EnsureLoaded;
  except
    on E: Exception do
    begin
      Write('[DrumKit] EnsureLoaded error: ' + E.Message + #13#10);
      raise;
    end;
  end;

  Keymap := TKeymapLoader.GetKeymap(KeymapName);
  if not Assigned(Keymap) then
    raise Exception.Create('Keymap not found: ' + KeymapName);

  if Keymap.JsonType <> jtObject then
    raise Exception.CreateFmt('Expected object for keymap %s, got type %d', [KeymapName, Ord(Keymap.JsonType)]);

  try
    RootObj := TJSONObject(Keymap);
  except
    on E: Exception do
      raise Exception.CreateFmt('Cannot cast keymap to TJSONObject: %s (type=%d)', [E.Message, Ord(Keymap.JsonType)]);
  end;
  
  { Get the instruments object }
  InstrumentsObj := RootObj.Find('instruments');
  if not Assigned(InstrumentsObj) or (InstrumentsObj.JsonType <> jtObject) then
    raise Exception.CreateFmt('Keymap %s must have an "instruments" object', [KeymapName]);
  Instruments := TJSONObject(InstrumentsObj);
  
  { Get the name from root object }  
  NameVal := RootObj.Find('name');
  
  CustomMappings := specialize TDictionary<string, Integer>.Create;
  try
    for I := 0 to Instruments.Count - 1 do
    begin
      InstName := Instruments.Names[I];
      InstrumentData := Instruments.Objects[InstName];
      if Assigned(InstrumentData) and (InstrumentData.JsonType = jtObject) then
      begin
        MidiNoteVal := TJSONObject(InstrumentData).Find('midi_note');
        if (MidiNoteVal <> nil) and (MidiNoteVal.JsonType <> jtNull) then
          CustomMappings.Add(InstName, Integer(MidiNoteVal.AsInteger));
      end;
    end;

    Result := TDrumKit.Create('', 9);
    if Assigned(NameVal) and (NameVal.JsonType = jtString) then
      Result.Name := NameVal.AsString;
    Result.FCustomMappings := CustomMappings;
  except
    on E: Exception do
      raise Exception.CreateFmt('Error in keymap processing (%s): %s', [KeymapName, E.Message]);
  end;
end;

function _GetJsonValueString(AJsonVal: TJSONData; const AKey: string): string;
var
  Data: TJSONData;
begin
  Result := '';
  if not Assigned(AJsonVal) or (AJsonVal.JsonType <> jtObject) then Exit;
  Data := (AJsonVal as TJSONObject).Objects[AKey];
  if Assigned(Data) and (Data.JsonType = jtString) then
    Result := Data.AsString;
end;

class function TDrumKit.ListPresets: specialize TDictionary<string, string>;
var
  Item: specialize TPair<string, TJSONData>;
begin
  if TKeymapLoader.FLoadedKeymaps.Count = 0 then
    TKeymapLoader.LoadAll;

  Result := specialize TDictionary<string, string>.Create;
  for Item in TKeymapLoader.FLoadedKeymaps do
    if (Item.Key <> 'template') and Assigned(Item.Value) and (Item.Value.JsonType = jtObject) then
      Result.Add(Item.Key, _GetJsonValueString(Item.Value, 'description'));
end;

class function TDrumKit.FromPreset(const PresetName: string): TDrumKit;
var
  Keymap: TJSONData;
begin
  Keymap := TKeymapLoader.GetKeymap(PresetName);
  if not Assigned(Keymap) then
    raise Exception.Create('Unknown mapping ' + PresetName + '. Must be a JSON file stem in mappings/ (e.g. template, gm, ad2, ezd3, xg).');
  Result := FromKeymapName(PresetName);
end;

class function TDrumKit.FromJson(const Path: string): TDrumKit;
var
  JsonValue, InstrumentsObj, InstsObj, NameVal, NoteVal: TJSONData;
  Instruments, InstObj: TJSONObject;
  InstName: string;
  I: Integer;
begin
  if Path = '' then
    raise Exception.Create('Cannot create DrumKit from None path');

  JsonValue := GetJSON(FileToStr(Path));
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then
      raise Exception.Create('Invalid JSON: expected object at ' + Path);

    Instruments := (JsonValue as TJSONObject);
    Result := TDrumKit.Create('', 9);

    NameVal := Instruments.Find('name');
    if Assigned(NameVal) and (NameVal.JsonType = jtString) then
      Result.Name := NameVal.AsString;

    InstsObj := Instruments.Find('instruments');
    if Assigned(InstsObj) and (InstsObj.JsonType = jtObject) then
    begin
      for I := 0 to (InstsObj as TJSONObject).Count - 1 do
      begin
        InstName := (InstsObj as TJSONObject).Names[I];
        InstObj := TJSONObject((InstsObj as TJSONObject)[InstName]);
        if not Assigned(InstObj) then Continue;

        NoteVal := InstObj.Find('midi_note');
        if Assigned(NoteVal) and (NoteVal <> nil) and (NoteVal.JsonType <> jtNull) then
          Result.FCustomMappings.Add(InstName, StrToIntDef(NoteVal.AsString, -1));
      end;
    end;
  finally
    JsonValue.Free;
  end;
end;


{ ── Module Initialization ─────────────────────────────── }

procedure Initialize;
begin
  TInstrumentRegistry.EnsureLoaded;
  TKeymapLoader.LoadAll;
end;

initialization
  TInstrumentRegistry.EnsureLoaded;
  TKeymapLoader.LoadAll;
end.
