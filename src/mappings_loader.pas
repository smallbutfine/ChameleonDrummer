unit MappingsLoader;

{$mode objfpc}{$H+}

{ Keymap Loader — discover, validate, and load drum instrument mappings.
  Direct translation of midi_drums/mappings/loader.py }

interface

uses
  Classes, SysUtils, fpjson, Generics.Collections;

type
  // TKeymapInfo — metadata about a single loaded keymap file
  TKeymapInfo = class(TObject)
  private
    FName: string;
    FVersion: string;
    FDescription: string;
    FSource: string;
    FPath: string;
    Finstruments: specialize TDictionary<string,TJSONObject>;
  public
    constructor Create;
    destructor Destroy; override;

    property name: string read FName write FName;
    property version: string read FVersion write FVersion;
    property description: string read FDescription write FDescription;
    property source: string read FSource write FSource;
    property path: string read FPath write FPath;
    property instruments: specialize TDictionary<string,TJSONObject> read Finstruments write Finstruments;
  end;

// ── Template & Discovery Functions ───────────────────────────────────────────
function load_template(const template_path: string = ''): TKeymapInfo;
procedure discover_keymaps(const mappings_dir: string; out keymaps: TArray<TKeymapInfo>);
function get_all_instruments(const template_path: string = ''): specialize TDictionary<string,string>;
function get_mapped_instruments(const keymap_name, mappings_dir: string): specialize TDictionary<string,string>;
function get_unmapped_instruments(const keymap_name, mappings_dir: string): specialize TDictionary<string,string>;
procedure generate_user_keymap(const target_path: string);
procedure print_keymap_summary(keymaps: TArray<TKeymapInfo> = nil; const cnt: Integer = 0);
procedure print_missing(const keymap_name, mappings_dir: string);

// ── Internals ────────────────────────────────────────────────────────────────
function _default_template_path: string;
function _default_mappings_dir: string;
function _load_keymap_file(const path: string): TKeymapInfo;
function _validate_keymap(const keymap: TKeymapInfo): TArray<string>;

implementation

// ── TKeymapInfo ──────────────────────────────────────────────────────────────
constructor TKeymapInfo.Create;
begin
  inherited Create;
  Finstruments := specialize TDictionary<string,TJSONObject>.Create;
end;

destructor TKeymapInfo.Destroy;
var
  Entry: TPair<string,TJSONObject>;
begin
  for Entry in Finstruments do
    if Assigned(Entry.Value) then Entry.Value.Free;
  Finstruments.Free;
  inherited Destroy;
end;

// ── Default paths ────────────────────────────────────────────────────────────
function _default_mappings_dir: string;
const
  DEFAULT_DIR = 'mappings';
begin
  Result := DEFAULT_DIR;
end;

function _default_template_path: string;
begin
  Result := _default_mappings_dir() + '/template.json';
end;

// ── load_template ────────────────────────────────────────────────────────────
function load_template(const template_path: string = ''): TKeymapInfo;
var
  Lpath: string;
begin
  if (template_path = '') then
    Lpath := _default_template_path()
  else
    Lpath := template_path;
  Result := _load_keymap_file(Lpath);
end;

// ── _load_keymap_file ────────────────────────────────────────────────────────
function _load_keymap_file(const path: string): TKeymapInfo;
var
  LJDoc: TJSONValue;
  LJObj: TJJSONObject;
begin
  if (not FileExists(path)) then
    raise EInOutError.Create('Keymap file not found: ' + path);

  Result := TKeymapInfo.Create;

  LJDoc := ParseJSONValue(FileToStr(path));
  if (LJDoc <> nil) and (LJDoc is TJJSONObject) then
  begin
    LJObj := TJJSONObject(LJDoc);
    Result.name := LJObj.GetValue('name');
    Result.version := LJObj.GetValue('version');
    Result.description := LJObj.GetValue('description');
    Result.source := LJObj.GetValue('source');
    Result.path := path;

    // Load instruments map
    var LI: TJSONValue;
    if LJObj.TryGetValue('instruments', LI) and (LI is TJJSONObject) then
    begin
      var LInstObj: TJJSONObject := TJJSONObject(LI);
      var J: Integer;
      for J := 0 to LInstObj.Count - 1 do
        Result.instruments.AddOrSetValue(LInstObj.Names[J], TJJSONObject(LInstObj.Values[J]));
    end;
  end;

  if Assigned(LJDoc) then LJDoc.Free;
end;

// ── discover_keymaps ─────────────────────────────────────────────────────────
procedure discover_keymaps(const mappings_dir: string; out keymaps: TArray<TKeymapInfo>);
var
  SearchRec: TSearchRec;
  LFileName, LBaseName: string;
begin
  SetLength(keymaps, 0);

  if (FindFirst(mappings_dir + '/*.json', faAnyFile, SearchRec) = 0) then
  try
    repeat
      LFileName := SearchRec.Name;
      LBaseName := LowerCase(ChangeFileExt(LFileName, ''));

      // Skip the template file itself
      if (LBaseName <> 'template') and (Pos('template', LBaseName) = 0) then
      begin
        SetLength(keymaps, Length(keymaps) + 1);
        keymaps[High(keymaps)] := _load_keymap_file(mappings_dir + '/' + LFileName);
      end;
    until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

// ── get_all_instruments ──────────────────────────────────────────────────────
function get_all_instruments(const template_path: string = ''): specialize TDictionary<string,string>;
var
  Ltmpl: TKeymapInfo;
  Entry: TPair<string,TJSONObject>;
begin
  Result := specialize TDictionary<string,string>.Create;
  Ltmpl := load_template(template_path);
  for Entry in Ltmpl.instruments do
    Result.AddOrSetValue(Entry.Key, ''); // just keys
  Ltmpl.Free;
end;

// ── get_mapped_instruments ───────────────────────────────────────────────────
function get_mapped_instruments(const keymap_name, mappings_dir: string): specialize TDictionary<string,string>;
var
  Lpath: string;
  Linfo: TKeymapInfo;
  Entry: TPair<string,TJSONObject>;
begin
  Result := specialize TDictionary<string,string>.Create;

  // If no extension, search for matching file
  if (ExtractFileExt(keymap_name) = '') then
  begin
    Lpath := '';
    if (FindFirst(mappings_dir + '/' + LowerCase(keymap_name) + '*.json', faAnyFile, SearchRec) = 0) then
    try
      Lpath := mappings_dir + '/' + SearchRec.Name;
    finally
      FindClose(SearchRec);
    end;

    if (Lpath = '') then Exit; // no candidates found
  end
  else
    Lpath := keymap_name;

  Linfo := _load_keymap_file(Lpath);
  try
    for Entry in Linfo.instruments do
    begin
      // Check if midi_note is not null
      var LJVal: TJSONValue;
      if Entry.Value.TryGetValue('midi_note', LJVal) then
        if (LJVal <> nil) and not (LJVal is TJNull) then
          Result.AddOrSetValue(Entry.Key, '');
    end;
  finally
    Linfo.Free;
  end;
end;

// ── get_unmapped_instruments ─────────────────────────────────────────────────
function get_unmapped_instruments(const keymap_name, mappings_dir: string): specialize TDictionary<string,string>;
var
  LMapped, LAll: specialize TDictionary<string,string>;
  Key: string;
begin
  Result := specialize TDictionary<string,string>.Create;
  LMapped := get_mapped_instruments(keymap_name, mappings_dir);
  LAll := get_all_instruments();

  for Key in LAll.Keys do
    if not LMapped.ContainsKey(Key) then
      Result.AddOrSetValue(Key, ''); // unmapped

  LMapped.Free;
  LAll.Free;
end;

// ── generate_user_keymap ─────────────────────────────────────────────────────
procedure generate_user_keymap(const target_path: string);
var
  LTemplate: TKeymapInfo;
  LJOutput, LIInst: TJJSONObject;
  Entry: TPair<string,TJSONObject>;
begin
  LTemplate := load_template();

  LJOutput := TJJSONObject.Create;
  LJOutput.Add('name', 'User Custom Kit');
  LJOutput.Add('version', LTemplate.Version);
  LJOutput.Add('description',
    'Custom keymap - fill in midi_note values. Leave as null for unavailable articulations.');
  LIInst := TJJSONObject.Create;

  for Entry in LTemplate.Instruments do
  begin
    var LI: TJSONObject := TJSONObject.Create;
    LI.Add('midi_note', TJNull.GetNull);
    // Description - extract from instrument entry if present
    var LD: TJSONValue;
    try
      if Entry.Value.TryGetValue('description', LD) then
        LI.Add('description', TJSONString.Create(LD.Value));
    except
    end;
    LIInst.Add(Entry.Key, LI);
  end;

  LJOutput.Add('instruments', LIInst);

  // Write JSON with indentation (fpjson doesn't auto-indent, write as-is)
  var LDirc: string := ExtractFilePath(target_path);
  if (LDirc <> '') then ForceDirectories(LDirc);

  var LStream: TFileStream := TFileStream.Create(target_path, fmCreate);
  try
    var LStr: string := LJOutput.AsJSON;
    LStream.WriteBuffer(LStr[1], Length(LStr));
  finally
    LStream.Free;
  end;

  LIInst.Free;
  LJOutput.Free;
  LTemplate.Free;
end;

// ── print_keymap_summary ─────────────────────────────────────────────────────
procedure print_keymap_summary(keymaps: TArray<TKeymapInfo>; const cnt: Integer);
var
  Lall_instruments, LMapped: specialize TDictionary<string,string>;
  Ltotal_instruments, LMappedCnt, LUnmapped: Integer;
  I: Integer;
begin
  if (keymaps = nil) or (Length(keymaps) = 0) then
    discover_keymaps(_default_mappings_dir(), keymaps);

  Lall_instruments := get_all_instruments();
  Ltotal_instruments := Length(Lall_instruments.Keys);

  Writeln('Discovered ', Length(keymaps), ' keymap(s):');
  WriteLn;

  // Header: Keymap, Mapped, Unmapped, Coverage
  Write('Keymap':<20);
  Write('Mapped':>8);
  Write('Unmapped':>10);
  WriteLn('Coverage':>10);
  WriteLn(StringOfChar('-', 52));

  for I := Low(keymaps) to High(keymaps) do
  begin
    LMapped := get_mapped_instruments(keymaps[I].path, '');
    LMappedCnt := Length(LMapped.Keys);
    LUnmapped := Ltotal_instruments - LMappedCnt;

    Write(keymaps[I].name:<20);
    Write(LMappedCnt:>8);
    Write(LUnmapped:>10);

    if (Ltotal_instruments > 0) then
      WriteLn((LMappedCnt * 100 div Ltotal_instruments):>10, '%')
    else
      WriteLn('N/A':>10);

    LMapped.Free;
  end;

  Lall_instruments.Free;
end;

// ── print_missing ────────────────────────────────────────────────────────────
procedure print_missing(const keymap_name, mappings_dir: string);
var
  Lunmapped: specialize TDictionary<string,string>;
  Ltmpl: TKeymapInfo;
  LKey, LDsc: string;
begin
  Lunmapped := get_unmapped_instruments(keymap_name, mappings_dir);

  if (Length(Lunmapped.Keys) = 0) then
  begin
    WriteLn('All instruments mapped for ''', keymap_name, '''');
    Exit;
  end;

  Ltmpl := load_template();
  Writeln;
  Writeln('Unmapped instruments in ''', keymap_name, ''' (',
           Length(Lunmapped.Keys), ' of ', Length(Ltmpl.instruments.Keys), '):');
  WriteLn;

  // Sort keys manually for deterministic output
  var Lkeys: TArray<string>;
  SetLength(Lkeys, Length(Lunmapped.Keys));
  var I := 0;
  for LKey in Lunmapped.Keys do
    Lkeys[I] := LKey;
  Inc(I);

  // Simple insertion sort
  var J, K: Integer;
  var LT: string;
  for I := 1 to Length(Lkeys) - 1 do
  begin
    LT := Lkeys[I];
    J := I - 1;
    while (J >= 0) and (Lkeys[J] > LT) do
    begin
      Lkeys[J + 1] := Lkeys[J];
      Dec(J);
    end;
    Lkeys[J + 1] := LT;
  end;

  for I := Low(Lkeys) to High(Lkeys) do
  begin
    LDsc := '';
    // Get description from template instruments
    if Ltmpl.instruments.ContainsKey(I) then
    begin
      var LJ: TJSONValue;
      if Ltmpl.instruments[I].TryGetValue('description', LJ) and (LJ <> nil) then
        LDsc := TJString(J).Value;
    end;

    WriteLn('  - ', I.PadRight(50), ' ', LDsc);
  end;

  Lunmapped.Free;
  Ltmpl.Free;
end;

// ── _validate_keymap ─────────────────────────────────────────────────────────
function _validate_keymap(const keymap: TKeymapInfo): TArray<string>;
var
  Ltmpl: TKeymapInfo;
  Lwarnings: TStringList;
  ExtraCount, MissingCount: Integer;
  Key: string;
begin
  Lwarnings := TStringList.Create;

  Ltmpl := load_template();
  ExtraCount := 0;
  MissingCount := 0;

  // Check for instruments in keymap but not in template
  for Key in keymap.instruments.Keys do
    if not Ltmpl.instruments.ContainsKey(Key) then
      Inc(ExtraCount);

  if (ExtraCount > 0) then
    Lwarnings.Add('WARNING: Keymap has ' + IntToStr(ExtraCount) +
                  ' instruments not in template');

  // Check for instruments in template but missing from keymap
  for Key in Ltmpl.instruments.Keys do
    if not keymap.instruments.ContainsKey(Key) then
      Inc(MissingCount);

  if (MissingCount > 0) then
    Lwarnings.Add('INFO: ' + IntToStr(MissingCount) +
                  ' instruments from template are missing from this keymap');

  SetLength(Result, Lwarnings.Count);
  for I := Low(Lwarnings) to High(Lwarnings) do
    Result[I] := Lwarnings[I];

  Ltmpl.Free;
  Lwarnings.Free;
end;

// ── Helper: FileToStr ────────────────────────────────────────────────────────
function FileToStr(const AFileName: string): string;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if (LStream.Size > 0) then
      LStream.ReadBuffer(Pointer(Integer(@Result[1])^), LStream.Size);
  finally
    LStream.Free;
  end;
end;

// ── Helper: TJJSONObject.TryGetValue ─────────────────────────────────────────
{ fpjson TJSONObject doesn't have TryGetValue in FPC 3.2 — we patch via inline }
type
  TJJSONObjectHelper = class helper for TJJSONObject
    function TryGetValue(const AName: string; out AValue: TJSONValue): Boolean;
  end;

function TJJSONObjectHelper.TryGetValue(const AName: string; out AValue: TJSONValue): Boolean;
var
  I: Integer;
begin
  for I := FList.Count - 1 downto 0 do
    if (SameText(FList[I].Fname, AName)) then
    begin
      AValue := FList[I];
      Exit(True);
    end;
  Result := False;
end;

// ── Helper: TJString ─────────────────────────────────────────────────────────
{ fpjson TJSONString wrapper }
type
  TJSONString = class(TJSONString) // forward ref, already defined in fpjson
  public
    function Value: string;
  end;

function TJSONString.Value: string;
begin
  Result := FValue; // fpjson internal field
end;

// ── Stub: TStringList.IndexOfName (fpjson uses this internally) ──────────────
{ Already defined in fpjson — no need to reimplement }

end.
