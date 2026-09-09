unit PluginRegistry;

{$mode objfpc}{$H+}

{ Plugin registry — stores genre/drummer plugins keyed by lowercase name,
  with parallel arrays holding style metadata to avoid circular imports. }

interface

uses
  Classes, SysUtils, Generics.Collections, pattern, song,
  generation_parameters;

type
  TGenreStyleInfo = record
    GenreName: string;
    Styles: TArray<string>;
    PreferredDrummers: TArray<string>;
  end;

  TDrummerPrefInfo = record
    DrummerName: string;
    PreferredGenres: TArray<string>;
  end;

TPluginRegistry = class(TObject)
private
  FGenrePlugins: TDictionary<string, TObject>;
  FDrummerPlugins: TDictionary<string, TObject>;
  FGenreStyles: TArray<TGenreStyleInfo>;
  FDrummerPrefs: TArray<TDrummerPrefInfo>;

  function FindGenreIdx(const GenreName: string): Integer;
  function FindDrummerIdx(const DrummerName: string): Integer;
  procedure FreeGenreStylesArray;
  procedure FreeDrummerPrefsArray;

public
  constructor Create;
  destructor Destroy; override;

  procedure RegisterGenrePlugin(const AName: string; APugin: TObject; ASupportedStyles: TArray<string> = nil;
                                APrefDrummers: TArray<string> = nil);
  procedure RegisterDrummerPlugin(const AName: string; APugin: TObject; APrefGenres: TArray<string> = nil);

  function GetGenrePlugin(const Genre: string): TObject;
  function GetDrummerPlugin(const Drummer: string): TObject;

  function GetAvailableGenres: TArray<string>;
  function GetAvailableDrummers: TArray<string>;
  function GetStylesForGenre(const Genre: string): TArray<string>;
  function GetPreferredDrummersForGenre(const Genre: string): TArray<string>;
end;

TPluginDiscovery = class(TObject)
private
  FRegistry: TPluginRegistry;
public
  constructor Create(ARegistry: TPluginRegistry);
  procedure Discover(APuginDirs: TArray<string> = nil);
  procedure LoadPluginsFromDirectory(const APuginDir: string);
end;

TPluginManager = class(TObject)
public
  Registry: TPluginRegistry;
  constructor Create;
  destructor Destroy; override;
  procedure DiscoverPlugins(APuginDirs: TArray<string> = nil);
  procedure LoadPluginsFromDirectory(const APuginDir: string);
end;

implementation

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TPluginRegistry                                             }
{ ═══════════════════════════════════════════════════════════════ }

constructor TPluginRegistry.Create;
begin
  inherited Create;
  FGenrePlugins := TDictionary<string, TObject>.Create;
  FDrummerPlugins := TDictionary<string, TObject>.Create;
end;

destructor TPluginRegistry.Destroy;
var
  Item: TPair<string, TObject>;
begin
  for Item in FGenrePlugins do
    if Assigned(Item.Value) then Item.Value.Free;
  for Item in FDrummerPlugins do
    if Assigned(Item.Value) then Item.Value.Free;

  FreeGenreStylesArray;
  FreeDrummerPrefsArray;

  FGenrePlugins.Clear;
  FGenrePlugins.Free;
  FDrummerPlugins.Clear;
  FDrummerPlugins.Free;
end;

function TPluginRegistry.FindGenreIdx(const GenreName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(FGenreStyles) to High(FGenreStyles) do
    if SameText(FGenreStyles[I].GenreName, LowerCase(GenreName)) then
    begin
      Result := I;
      Exit;
    end;
end;

function TPluginRegistry.FindDrummerIdx(const DrummerName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(FDrummerPrefs) to High(FDrummerPrefs) do
    if SameText(FDrummerPrefs[I].DrummerName, LowerCase(DrummerName)) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TPluginRegistry.FreeGenreStylesArray;
var
  I: Integer;
begin
  for I := Low(FGenreStyles) to High(FGenreStyles) do
  begin
    SetLength(FGenreStyles[I].Styles, 0);
    SetLength(FGenreStyles[I].PreferredDrummers, 0);
  end;
  SetLength(FGenreStyles, 0);
end;

procedure TPluginRegistry.FreeDrummerPrefsArray;
var
  I: Integer;
begin
  for I := Low(FDrummerPrefs) to High(FDrummerPrefs) do
    SetLength(FDrummerPrefs[I].PreferredGenres, 0);
  SetLength(FDrummerPrefs, 0);
end;

procedure TPluginRegistry.RegisterGenrePlugin(const AName: string; APugin: TObject; ASupportedStyles: TArray<string>;
                                              APrefDrummers: TArray<string>);
var
  GenreKey: string;
  ExistingIdx: Integer;
begin
  if not Assigned(APugin) then Exit;

  GenreKey := LowerCase(AName);

  // Remove old plugin if key already exists
  if FGenrePlugins.ContainsKey(GenreKey) then
  begin
    var OldPlugin := FGenrePlugins[GenreKey];
    if Assigned(OldPlugin) then OldPlugin.Free;
    FGenrePlugins.Remove(GenreKey);
  end;
  FGenrePlugins.AddOrSetValue(GenreKey, APugin);

  // Store parallel metadata
  ExistingIdx := FindGenreIdx(AName);

  if ExistingIdx >= 0 then
  begin
    // Update existing record
    SetLength(FGenreStyles[ExistingIdx].Styles, Length(ASupportedStyles));
    if Length(ASupportedStyles) > 0 then
      Move(ASupportedStyles[0], FGenreStyles[ExistingIdx].Styles[0], Length(ASupportedStyles) * SizeOf(string));

    SetLength(FGenreStyles[ExistingIdx].PreferredDrummers, Length(APrefDrummers));
    if Length(APrefDrummers) > 0 then
      Move(APrefDrummers[0], FGenreStyles[ExistingIdx].PreferredDrummers[0], Length(APrefDrummers) * SizeOf(string));
  end
  else
  begin
    // Append new record
    SetLength(FGenreStyles, Length(FGenreStyles) + 1);
    var NewIdx := High(FGenreStyles);
    FGenreStyles[NewIdx].GenreName := GenreKey;

    SetLength(FGenreStyles[NewIdx].Styles, Length(ASupportedStyles));
    if Length(ASupportedStyles) > 0 then
      Move(ASupportedStyles[0], FGenreStyles[NewIdx].Styles[0], Length(ASupportedStyles) * SizeOf(string));

    SetLength(FGenreStyles[NewIdx].PreferredDrummers, Length(APrefDrummers));
    if Length(APrefDrummers) > 0 then
      Move(APrefDrummers[0], FGenreStyles[NewIdx].PreferredDrummers[0], Length(APrefDrummers) * SizeOf(string));
  end;
end;

procedure TPluginRegistry.RegisterDrummerPlugin(const AName: string; APugin: TObject; APrefGenres: TArray<string>);
var
  DrummerKey: string;
  ExistingIdx: Integer;
begin
  if not Assigned(APugin) then Exit;

  DrummerKey := LowerCase(AName);

  // Remove old plugin if key already exists
  if FDrummerPlugins.ContainsKey(DrummerKey) then
  begin
    var OldPlugin := FDrummerPlugins[DrummerKey];
    if Assigned(OldPlugin) then OldPlugin.Free;
    FDrummerPlugins.Remove(DrummerKey);
  end;
  FDrummerPlugins.AddOrSetValue(DrummerKey, APugin);

  // Store parallel metadata
  ExistingIdx := FindDrummerIdx(AName);

  if ExistingIdx >= 0 then
  begin
    SetLength(FDrummerPrefs[ExistingIdx].PreferredGenres, Length(APrefGenres));
    if Length(APrefGenres) > 0 then
      Move(APrefGenres[0], FDrummerPrefs[ExistingIdx].PreferredGenres[0], Length(APrefGenres) * SizeOf(string));
  end
  else
  begin
    SetLength(FDrummerPrefs, Length(FDrummerPrefs) + 1);
    var NewIdx := High(FDrummerPrefs);
    FDrummerPrefs[NewIdx].DrummerName := DrummerKey;

    SetLength(FDrummerPrefs[NewIdx].PreferredGenres, Length(APrefGenres));
    if Length(APrefGenres) > 0 then
      Move(APrefGenres[0], FDrummerPrefs[NewIdx].PreferredGenres[0], Length(APrefGenres) * SizeOf(string));
  end;
end;

function TPluginRegistry.GetGenrePlugin(const Genre: string): TObject;
var
  Key: string;
begin
  if not Assigned(FGenrePlugins) then Exit(nil);

  Key := LowerCase(Genre);
  if FGenrePlugins.TryGetValue(Key, Result) then Exit;

  // Case-insensitive fallback scan
  for var Pair in FGenrePlugins do
    if SameText(Pair.Key, Key) then
    begin
      Result := Pair.Value;
      Exit;
    end;

  Result := nil;
end;

function TPluginRegistry.GetDrummerPlugin(const Drummer: string): TObject;
var
  Key: string;
begin
  if not Assigned(FDrummerPlugins) then Exit(nil);

  Key := LowerCase(Drummer);
  if FDrummerPlugins.TryGetValue(Key, Result) then Exit;

  // Case-insensitive fallback scan
  for var Pair in FDrummerPlugins do
    if SameText(Pair.Key, Key) then
    begin
      Result := Pair.Value;
      Exit;
    end;

  Result := nil;
end;

function TPluginRegistry.GetAvailableGenres: TArray<string>;
var
  I: Integer;
begin
  if not Assigned(FGenrePlugins) or (FGenrePlugins.Count = 0) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, FGenrePlugins.Count);
  I := 0;
  for var Key in FGenrePlugins.Keys do
  begin
    Result[I] := Key;
    Inc(I);
  end;
end;

function TPluginRegistry.GetAvailableDrummers: TArray<string>;
var
  I: Integer;
begin
  if not Assigned(FDrummerPlugins) or (FDrummerPlugins.Count = 0) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, FDrummerPlugins.Count);
  I := 0;
  for var Key in FDrummerPlugins.Keys do
  begin
    Result[I] := Key;
    Inc(I);
  end;
end;

function TPluginRegistry.GetStylesForGenre(const Genre: string): TArray<string>;
var
  GenreKey, Idx: Integer;
begin
  GenreKey := FindGenreIdx(Genre);

  if GenreKey >= 0 then
    Exit(FGenreStyles[GenreKey].Styles);

  // Not found — return empty array
  SetLength(Result, 0);
end;

function TPluginRegistry.GetPreferredDrummersForGenre(const Genre: string): TArray<string>;
var
  I, J: Integer;
begin
  Result := [];

  if not Assigned(FDrummerPrefs) then Exit;

  for I := Low(FDrummerPrefs) to High(FDrummerPrefs) do
    for J := Low(FDrummerPrefs[I].PreferredGenres) to High(FDrummerPrefs[I].PreferredGenres) do
      if SameText(FDrummerPrefs[I].PreferredGenres[J], Genre) then
      begin
        Result := Result + [FDrummerPrefs[I].DrummerName];
        Break;
      end;
end;

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TPluginDiscovery                                            }
{ ═══════════════════════════════════════════════════════════════ }

constructor TPluginDiscovery.Create(ARegistry: TPluginRegistry);
begin
  inherited Create;
  FRegistry := ARegistry;
end;

procedure TPluginDiscovery.Discover(APuginDirs: TArray<string>);
var
  Dir: string;
begin
  if Assigned(APuginDirs) then
    for Dir in APuginDirs do
      LoadPluginsFromDirectory(Dir);
end;

procedure TPluginDiscovery.LoadPluginsFromDirectory(const APuginDir: string);
var
  SearchRec: TSearchRec;
  FilePath: string;
begin
  if not DirectoryExists(APuginDir) then Exit;

  if FindFirst(APuginDir + '/*.pas', faAnyFile, SearchRec) = 0 then
  try
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        FilePath := APuginDir + '/' + SearchRec.Name;
    until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

{ ═══════════════════════════════════════════════════════════════ }
{ ═  TPluginManager                                              }
{ ═══════════════════════════════════════════════════════════════ }

constructor TPluginManager.Create;
begin
  inherited Create;
  Registry := TPluginRegistry.Create;
end;

destructor TPluginManager.Destroy;
begin
  Registry.Free;
  inherited Destroy;
end;

procedure TPluginManager.DiscoverPlugins(APuginDirs: TArray<string>);
var
  Discovery: TPluginDiscovery;
begin
  Discovery := TPluginDiscovery.Create(Registry);
  try
    Discovery.Discover(APuginDirs);
  finally
    Discovery.Free;
  end;
end;

procedure TPluginManager.LoadPluginsFromDirectory(const APuginDir: string);
var
  Discovery: TPluginDiscovery;
begin
  Discovery := TPluginDiscovery.Create(Registry);
  try
    Discovery.LoadPluginsFromDirectory(APuginDir);
  finally
    Discovery.Free;
  end;
end;

end.
