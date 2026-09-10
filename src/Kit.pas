unit kit;

{$mode objfpc}{$H+}

{ DrumKit â€” drum kit configuration and instrument mapping.
  All MIDI note mappings are loaded dynamically from JSON keymap files in midi_drums/mappings/.
  No MIDI notes or instrument names are hardcoded anywhere. All instruments come from the master template. }

interface

uses
  Classes, SysUtils, fpjson, Generics.Collections;

type
{ â”€â”€ Type aliases for FPC 3.2.x compatibility â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }
TStrDict = specialize TDictionary<string, string>;
TStrBoolDict = specialize TDictionary<string, boolean>;


{ DrumInstrument — dynamic drum instrument identity.
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

{ InstrumentRegistry â€” manages all registered drum instruments.
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

{ â”€â”€ Keymap Loader â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ KeymapLoader â€” loads and manages keymap JSON files from the mappings directory. }
TKeymapLoader = class(TObject)
private
  FLoadedKeymaps: TObject;
public
  class function LoadAll: Pointer; static;
  class function GetKeymap(const AName: string): Pointer; static;
  class function GetMidiNote(const InstrumentName, KeymapName: string): Integer; static;
  class function GetAllInstruments: TStrBoolDict; static;
  class function GetUnmappedInstruments(const KeymapName: string): TStrBoolDict; static;
  class procedure GenerateUserKeymap(const TargetPath: string); static;

  class constructor Create;
  class destructor Destroy;
end;

{ â”€â”€ VelocityRange â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

{ VelocityRange — velocity range for realistic drum dynamics. }
TVelocityRange = class
private
  FMinVelocity: Integer;
  FMaxVelocity: Integer;
  FDefaultVelocity: Integer;
public
  constructor Create(AMin, AMax: Integer; ADefault: Integer = 1);
  procedure Validate;
end;

{ ── DrumKit — the main class that uses dynamic instrument resolution ─────── }

{ DrumKit â€” drum kit configuration with instrument mappings and velocity ranges.
  MIDI note mappings are resolved at runtime by loading keymap files. }
TDrumKit = class(TObject)
private
FVelocityRanges: specialize TDictionary<string, TVelocityRange>;
FCustomMappings: specialize TDictionary<string, Integer>;
public
  Name: string;
  Channel: Integer;

  constructor Create(AName: string = 'Standard Kit'; AChannel: Integer = 9);
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

{ â”€â”€ Module Initialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

procedure Initialize;

implementation

{ â”€â”€ DrumInstrument â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

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

{ ── InstrumentRegistry ──────────────────────────────────────────────
{ â”€â”€ InstrumentRegistry â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

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
  Item: TPair<string, TDrumInstrument>;
  Count: Integer;
begin
  Count := Finstruments.Count;
  SetLength(Result, Count);
  var I := 0;
  for Item in Finstruments do
  begin
    Result[I] := Item.Value;
    Inc(I);
  end;
end;

class function TInstrumentRegistry.GetAllNames: specialize TDictionary<string, boolean>;
var
  Item: TPair<string, TDrumInstrument>;
begin
  Result  := specialize TDictionary<string, boolean>.Create;
  for Item in Finstruments do
    Result.Add(Item.Key, true);
end;

class procedure TInstrumentRegistry.LoadFromTemplate(const ATemplatePath: string);
var
  TemplatePath: string;
  JsonValue: TJSONValue;
  Instruments: TJSONObject;
  InstName, InstDesc: string;
  InstObj: TJSONObject;
  Inst: TDrumInstrument;
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

  JsonValue := TJSONObject.ParseJSONValue(FileToStr(TemplatePath));
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then
      raise Exception.Create('Invalid template JSON: expected object');
    Instruments := JsonValue.AsObject;

    InstName := '';
    for InstName in Instruments.Elements do
    begin
      InstObj := Instruments[InstName];
      InstDesc := '';
      if Assigned(InstObj) and (InstObj.Values['description'] <> nil) then
        InstDesc := InstObj.Values['description'].ValueS;

      { Source metadata }
      var Metadata: specialize TDictionary<string, string> := specialize TDictionary<string, string>.Create;
      try
        var SourceVal := Instruments.Values['source'];
        if Assigned(SourceVal) then
          Metadata.Add('source', SourceVal.ValueS);

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

{ â”€â”€ KeymapLoader â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

class constructor TKeymapLoader.Create;
begin
  FLoadedKeymaps := TObject(specialize TDictionary<string, TJSONValue>.Create);
end;

class destructor TKeymapLoader.Destroy;
var
  Item: TPair<string, TJSONValue>;
begin
  for Item in FLoadedKeymaps do
    Item.Value.Free;
  FLoadedKeymaps.Free;
end;

class function TKeymapLoader.LoadAll: TArray<TJSONValue>;
var
  DirHandle: TSearchRec;
  FilePath: string;
  FileName, FileStem: string;
  JsonValue: TJSONValue;
begin
  FLoadedKeymaps.Clear;

  var MappingsDir := ExtractFilePath(ParamStr(0)) + 'mappings' + DirectorySeparator;
  if not DirectoryExists(MappingsDir) then
    Exit(nil);

  if FindFirst(MappingsDir + '*.json', faAnyFile, DirHandle) = 0 then
  try
    repeat
      if (DirHandle.Name <> '.') and (DirHandle.Name <> '..') then
      begin
        FilePath := MappingsDir + DirHandle.Name;
        FileName := ExtractFileName(DirHandle.Name);
        FileStem := ChangeFileExt(FileName, '');

        JsonValue := TJSONObject.ParseJSONValue(FileToStr(FilePath));
        if Assigned(JsonValue) then
          FLoadedKeymaps.Add(FileStem, JsonValue);
      end;
    until FindNext(DirHandle) <> 0;
  finally
    FindClose(DirHandle);
  end;

  var Count := FLoadedKeymaps.Count;
  SetLength(Result, Count);
  var I := 0;
  var Item: TPair<string, TJSONValue>;
  for Item in FLoadedKeymaps do
  begin
    Result[I] := Item.Value;
    Inc(I);
  end;
end;

class function TKeymapLoader.GetKeymap(const AName: string): TJSONValue;
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
      Result := Found.Value;
      Exit;
    end;
  end;

  Result := nil;
end;

class function TKeymapLoader.GetMidiNote(const InstrumentName, KeymapName: string): Integer;
var
  Keymap: TJSONValue;
  Instruments: TJSONObject;
  InstrumentData: TJSONObject;
  MidiNoteVal: TJSONNode;
begin
  if FLoadedKeymaps.Count = 0 then
    LoadAll;

  Keymap := GetKeymap(KeymapName);
  if not Assigned(Keymap) then
    Exit(-1);

  Instruments := Keymap.AsObject;
  if not Assigned(Instruments) then
    Exit(-1);

  InstrumentData := Instruments[InstrumentName];
  if not Assigned(InstrumentData) then
    Exit(-1);

  MidiNoteVal := InstrumentData.Values['midi_note'];
  if (MidiNoteVal = nil) or (MidiNoteVal.ValueType = jvNone) or (MidiNoteVal.ValueType = jvNull) then
    Exit(-1);

  Result := MidiNoteVal.ValueI;
end;

class function TKeymapLoader.GetAllInstruments: specialize TDictionary<string, boolean>;
var
  Item: TPair<string, TJSONValue>;
  KeymapName: string;
begin
  Result  := specialize TDictionary<string, boolean>.Create;
  for Item in FLoadedKeymaps do
  begin
    var Instruments := Item.Value.AsObject;
    if Assigned(Instruments) then
      for KeymapName in Instruments.Elements do
        Result.Add(KeymapName, true);
  end;
end;

class function TKeymapLoader.GetUnmappedInstruments(const KeymapName: string): specialize TDictionary<string, boolean>;
var
  AllInstruments: specialize TDictionary<string, boolean>;
  Keymap: TJSONValue;
  Instruments: TJSONObject;
  InstrumentData: TJSONObject;
  MidiNoteVal: TJSONNode;
begin
  AllInstruments := GetAllInstruments;

  Keymap := GetKeymap(KeymapName);
  if not Assigned(Keymap) then
  begin
    Result := AllInstruments;
    Exit;
  end;

  Instruments := Keymap.AsObject;
  Result  := specialize TDictionary<string, boolean>.Create;
  var MappedName: string;
  for MappedName in Instruments.Elements do
  begin
    InstrumentData := Instruments[MappedName];
    if Assigned(InstrumentData) then
    begin
      MidiNoteVal := InstrumentData.Values['midi_note'];
      if (MidiNoteVal <> nil) and (MidiNoteVal.ValueType <> jvNone) and (MidiNoteVal.ValueType <> jvNull) then
        AllInstruments.Remove(MappedName);
    end;
  end;

  Result := AllInstruments;
end;

class procedure TKeymapLoader.GenerateUserKeymap(const TargetPath: string);
var
  Template: TJSONValue;
  Instruments: TJSONObject;
  Output: TJSONObject;
  InstObj: TJSONObject;
  JsonText: TJSONTextGen;
begin
  Template := GetKeymap('template');
  if not Assigned(Template) then
    raise Exception.Create('No template keymap found in mappings directory.');

  Instruments := Template.AsObject;
  Output := TJSONObject.Create;
  try
    Output.Values['name'].ValueS := 'User Custom Kit';
    var VersionVal := Instruments.Values['version'];
    if Assigned(VersionVal) then
      Output.Values['version'].ValueS := VersionVal.ValueS;
    Output.Values['description'].ValueS := 'Custom keymap â€” fill in midi_note values. Leave as null for unavailable articulations.';
    Output.Values['source'].ValueS := 'User generated from template';

    var InstrumentsObj := TJSONObject.Create;
    var InstName: string;
    for InstName in Instruments.Elements do
    begin
      InstObj := TJSONObject.Create;
      { Set midi_note to null } 
      InstObj.Add('midi_note', nil); { Adds as jvNull }
      var DescVal := Instruments[InstName].Values['description'];
      if Assigned(DescVal) then
        InstObj.Values['description'].ValueS := DescVal.ValueS;
      InstrumentsObj.Elements.Add(InstName, InstObj);
    end;
    Output.Values['instruments'] := InstrumentsObj;

    JsonText := TJSONTextGen.Create(0); { no indentation for simplicity }
    try
      var Strm := TBytesStream.Create;
      try
        JsonText.Emit(Strm, Output);
        WriteFileString(TargetPath, BytesToString(Strm.Bytes));
      finally
        Strm.Free;
      end;
    finally
      JsonText.Free;
    end;
  finally
    Output.Free;
  end;
end;

{ â”€â”€ DrumKit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TDrumKit.Create(AName: string = 'Standard Kit'; AChannel: Integer = 9);
begin
  inherited Create;
  Name := AName;
  Channel := AChannel;
  FVelocityRanges  := specialize TDictionary<string, TVelocityRange>.Create;
  FCustomMappings  := specialize TDictionary<string, Integer>.Create;

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
  Found: boolean;
begin
  if FCustomMappings.TryGetValue(InstrumentName, Result) then
    Exit;

  Result := TKeymapLoader.GetMidiNote(InstrumentName, KeymapName);
end;

function TDrumKit.GetVelocityRange(const InstrumentType: string): TVelocityRange;
var
  Found: boolean;
begin
  if FVelocityRanges.TryGetValue(InstrumentType, Result) then
    Exit;
  Result := TVelocityRange.Create(1, 127, 100); { default }
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
  Keymap: TJSONValue;
  Instruments: TJSONObject;
  InstName: string;
  InstObj: TJSONObject;
  MidiNoteVal: TJSONNode;
begin
  TInstrumentRegistry.EnsureLoaded;

  Keymap := TKeymapLoader.GetKeymap(KeymapName);
  if not Assigned(Keymap) then
    raise Exception.Create('Keymap not found: ' + KeymapName);

  Instruments := Keymap.AsObject;
  var CustomMappings  := specialize TDictionary<string, Integer>.Create;
  try
    for InstName in Instruments.Elements do
    begin
      InstObj := Instruments[InstName];
      if Assigned(InstObj) then
      begin
        MidiNoteVal := InstObj.Values['midi_note'];
        if (MidiNoteVal <> nil) and (MidiNoteVal.ValueType <> jvNone) and (MidiNoteVal.ValueType <> jvNull) then
          CustomMappings.Add(InstName, MidiNoteVal.ValueI);
      end;
    end;

    Result := TDrumKit.Create;
    Result.Name := Keymap.AsObject.Values['name'].AsString;
    Result.FCustomMappings := CustomMappings;
  except
    CustomMappings.Free;
    raise;
  end;
end;

class function TDrumKit.ListPresets: specialize TDictionary<string, string>;
begin
  if TKeymapLoader.FLoadedKeymaps.Count = 0 then
    TKeymapLoader.LoadAll;

  Result  := specialize TDictionary<string, string>.Create;
  var Item: TPair<string, TJSONValue>;
  for Item in TKeymapLoader.FLoadedKeymaps do
  begin
    if Item.Key <> 'template' then
      Result.Add(Item.Key, Item.Value.AsObject.Values['description'].AsString);
  end;
end;

class function TDrumKit.FromPreset(const PresetName: string): TDrumKit;
var
  Keymap: TJSONValue;
begin
  Keymap := TKeymapLoader.GetKeymap(PresetName);
  if not Assigned(Keymap) then
    raise Exception.Create('Unknown mapping ' + PresetName + '. Must be a JSON file stem in mappings/ (e.g. template, gm, ad2, ezd3, xg).');

  Result := FromKeymapName(PresetName);
end;

class function TDrumKit.FromJson(const Path: string): TDrumKit;
var
  JsonValue: TJSONValue;
  Instruments: TJSONObject;
  InstName: string;
  InstObj: TJSONObject;
  NoteVal: TJSONNode;
begin
  if Path = '' then
    raise Exception.Create('Cannot create DrumKit from None path');

  JsonValue := TJSONObject.ParseJSONValue(FileToStr(Path));
  try
    if not Assigned(JsonValue) or (JsonValue.JsonType <> jtObject) then
      raise Exception.Create('Invalid JSON: expected object at ' + Path);
    Instruments := JsonValue.AsObject;

    Result := TDrumKit.Create;
    var NameVal := Instruments.Values['name'];
    if Assigned(NameVal) then
      Result.Name := NameVal.ValueS;

    var InstsObj := Instruments.Values['instruments'];
    if Assigned(InstsObj) and (InstsObj.JsonType = jtObject) then
      for InstName in InstsObj.AsObject.Elements do
      begin
        InstObj := InstsObj.AsObject[InstName];
        if not Assigned(InstObj) then Continue;
        NoteVal := InstObj.Values['midi_note'];
        if (NoteVal <> nil) and (NoteVal.ValueType <> jvNone) and (NoteVal.ValueType <> jvNull) then
          Result.FCustomMappings.Add(InstName, NoteVal.ValueI);
      end;
  finally
    JsonValue.Free;
  end;
end;

{ â”€â”€ VelocityRange â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TVelocityRange.Create(AMin, AMax, ADefault: Integer = 1);
begin
  MinVelocity := AMin;
  MaxVelocity := AMax;
  DefaultVelocity := ADefault;
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

{ â”€â”€ Module Initialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

procedure Initialize;
begin
  TInstrumentRegistry.LoadFromTemplate;
  TKeymapLoader.LoadAll;
end;

initialization
  { Initialize at import time so instruments are ready immediately }
  Initialize;

end.




