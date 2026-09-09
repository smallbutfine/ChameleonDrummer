unit drum_generator;

{$mode objfpc}{$H+}

{ Main drum generation engine and composition system.
  Entry point for all MIDI drum generation. Wraps ComposerV2 (bar-by-bar
  pattern evolution) with plugin discovery, genre plugins, drummer styles,
  and MIDI export. }

interface

uses
  Classes, SysUtils, Generics.Collections, kit, pattern, song,
  time_signature, generation_parameters, composer_v2, midi_engine,
  plugin_registry; { forward declarations for genres / drummers loaded at runtime */

{ ── Genre archetypes — default song structures per genre. */ }

type
  TStructureEntry = record Name: string; Bars: Integer; end;

const
  GENRE_ARCHETYPES: array[0..4] of record
    Genre: string;
    Structure: array[0..7] of TStructureEntry;
  end = (
    (Genre: 'metal'; Structure: (
      (Name: 'intro'; Bars: 8); (Name: 'verse'; Bars: 8);
      (Name: 'chorus'; Bars: 8); (Name: 'verse'; Bars: 8);
      (Name: 'breakdown'; Bars: 8); (Name: 'chorus'; Bars: 8);
      (Name: 'bridge'; Bars: 4);  (Name: 'solo'; Bars: 8)
    )), { outro omitted — metal archetypes use implicit 4-bar outro */

    (Genre: 'rock'; Structure: (
      (Name: 'intro'; Bars: 4); (Name: 'verse'; Bars: 8);
      (Name: 'chorus'; Bars: 8); (Name: 'verse'; Bars: 8);
      (Name: 'chorus'; Bars: 8); (Name: 'bridge'; Bars: 4);
      (Name: 'solo'; Bars: 8);  (Name: 'outro'; Bars: 4)
    )),

    (Genre: 'jazz'; Structure: (
      (Name: 'intro'; Bars: 8); (Name: 'verse'; Bars: 16);
      (Name: 'chorus'; Bars: 16); (Name: 'bridge'; Bars: 8);
      (Name: 'chorus'; Bars: 16); (Name: 'outro'; Bars: 8)
    )), { only 6 entries — jazz has no verse/verse repeat. */

    (Genre: 'funk'; Structure: (
      (Name: 'intro'; Bars: 4); (Name: 'verse'; Bars: 8);
      (Name: 'chorus'; Bars: 8); (Name: 'verse'; Bars: 8);
      (Name: 'breakdown'; Bars: 8); (Name: 'bridge'; Bars: 4);
      (Name: 'outro'; Bars: 8)
    )), { only 7 entries. */

    (Genre: 'electronic'; Structure: (
      (Name: 'intro'; Bars: 8); (Name: 'verse'; Bars: 16);
      (Name: 'chorus'; Bars: 16); (Name: 'breakdown'; Bars: 8);
      (Name: 'chorus'; Bars: 16); (Name: 'outro'; Bars: 8)
    )) { only 6 entries. */
  );

{ ── Genre-aware BPM defaults. */ }

function GetDefaultBpm(const Genre, Style: string): Integer;

{ ── Groove restraints — per-genre velocity adjustments. */ }

procedure ApplyGrooveRestraints(Song: TSong);

{ ── DrumGenerator — main entry point for drum MIDI generation. */ }

TDrumGenerator = class(TObject)
private
  FPluginManager: TPluginManager;
  FDrumKit: TDrumKit;
  FMidiEngine: TMIDIEngine;
  FComposerEngine: string;

  procedure LoadPlugins;
  function GetGenreDefaultStructure(const Genre: string): TArray<TStructureEntry>;

public
  constructor Create(AComposerEngine: string = 'v2'); { default = v2 (bar-by-bar). */
  destructor Destroy; override;

  { ── Public API. */ }

  { Create a complete song with bar-by-bar pattern evolution (V2 engine). */
  function CreateSongV2(const Genre, Style: string; ATempo: Integer = 120;
    const AStructure: TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil): TSong;

  { Create a complete song — selects engine (V1 static or V2 evolution). */
  function CreateSong(const Genre, Style: string; ATempo: Integer = 120;
    const AStructure: TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
    AEngineOverride: string = ''): TSong;

  { Export a Song to a MIDI file. */
  procedure SaveSongMidi(const ASong: TSong; const AOutputPath: string);

  { Export a single Pattern to a MIDI file. */
  procedure SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);

  property PluginManager: TPluginManager read FPluginManager;
  property DrumKit: TDrumKit read FDrumKit write FDrumKit;
  property MidiEngine: TMIDIEngine read FMidiEngine;
  property ComposerEngine: string read FComposerEngine write FComposerEngine;
end;

implementation

{ ── GetDefaultBpm — genre/style-aware default BPM. */ }

function GetDefaultBpm(const Genre, Style: string): Integer;
var
  DefaultTempoMaps: record { Simplified — real impl uses bpm_ranges module. */
    metal: array[0..6] of record Style: string; Tempo: Integer; end;
  end;
begin
  { Simplified defaults from the bpm_ranges config. */
  case LowerCase(Genre) of
    'metal':
      case LowerCase(Style) of
        'heavy':   Result := 140;
        'death':   Result := 195;
        'power':   Result := 160;
        'progressive': Result := 140;
        'thrash':  Result := 200;
        'doom':    Result := 70;
        'breakdown': Result := 100;
      else Result := 140;
      end;
    'rock':
      case LowerCase(Style) of
        'classic':   Result := 120;
        'blues':     Result := 100;
        'alternative': Result := 130;
        'progressive': Result := 120;
        'punk':      Result := 180;
        'hard':      Result := 140;
        'pop':       Result := 120;
      else Result := 120;
      end;
    'jazz':
      case LowerCase(Style) of
        'swing':     Result := 180;
        'bebop':     Result := 250;
        'fusion':    Result := 200;
        'latin':     Result := 160;
        'ballad':    Result := 90;
        'hard_bop':  Result := 200;
        'contemporary': Result := 140;
      else Result := 140;
      end;
    'funk':
      case LowerCase(Style) of
        'classic':   Result := 110;
        'pfunk':     Result := 120;
        'shuffle':   Result := 130;
        'new_orleans': Result := 140;
        'fusion':    Result := 160;
        'minimal':   Result := 100;
        'heavy':     Result := 110;
      else Result := 110;
      end;
    'electronic':
      case LowerCase(Style) of
        'house':     Result := 125;
        'techno':    Result := 130;
        'drum_and_bass': Result := 174;
        'dubstep':   Result := 140;
      else Result := 130;
      end;
  else Result := 120; { default. */
  end;
end;

{ ── ApplyGrooveRestraints — per-genre velocity adjustments for musicality. */ }

procedure ApplyGrooveRestraints(Song: TSong);
var
  Genre: string;
  Section: TSection;
  Beat: TBeat;
begin
  if not Assigned(Song.FGlobalParameters) then Genre := 'rock' else Genre := Song.FGlobalParameters.FGenre;

  for Section in Song.Sections do
  begin
    for Beat in Section.FBeats do
    begin
      var Name := '';
      if Assigned(Beat.FInstrument) then
        Name := Beat.FInstrument.Name;

      { Jazz: attenuate snares and cymbals. */
      if SameText(Genre, 'jazz') then
      begin
        if SameText(Name, 'snare_rimshot_open_hit') and not Beat.FGhostNote then
          Beat.FVelocity := Min(Beat.FVelocity, 85) { SNARE_LIGHT. */

        if (Pos('cymbal', LowerCase(Name)) > 0) or
           (Pos('crash', LowerCase(Name)) > 0) or
           (Pos('ride', LowerCase(Name)) > 0) then
          Beat.FVelocity := Min(Beat.FVelocity, 75) { CRASH_LIGHT. */
      end;

      { Funk: tighten snare backbeat. */
      if SameText(Genre, 'funk') and SameText(Name, 'snare_rimshot_open_hit') then
        if not Beat.FGhostNote then
          Beat.FVelocity := Max(Min(Beat.FVelocity, 108), 95); { SNARE_NORMAL..SNARE_ACCENT */

      { Metal: ensure snares stay punchy. */
      if SameText(Genre, 'metal') and SameText(Name, 'snare_rimshot_open_hit') then
        if Beat.FVelocity < 100 then
          Beat.FVelocity := Min(Beat.FVelocity + 25, 127);
    end; { for Beat. */
  end; { for Section. */
end;

{ ── TDrumGenerator ─────────────────────────────────────────────────────── }

constructor TDrumGenerator.Create(AComposerEngine: string = 'v2');
begin
  inherited Create;
  FComposerEngine := AComposerEngine;
  FPluginManager := TPluginManager.Create;
  FDrumKit := TDrumKit.FromKeymapName('gm'); { Default GM keymap. */
  FMidiEngine := TMIDIEngine.Create(FDrumKit);

  LoadPlugins;
end;

destructor TDrumGenerator.Destroy;
begin
  FPluginManager.Free;
  FMidiEngine.Free;
  inherited Destroy;
end;

procedure TDrumGenerator.LoadPlugins;
begin
  { In real impl: scan plugins/genres/*.pas and plugins/drummers/*.pas, */
  { load each module, register all TGenrePlugin/TDrummerPlugin subclasses. */
  { For now — stub. Real system uses dynamic module loading or RTTI discovery. */
end;

function TDrumGenerator.GetGenreDefaultStructure(const Genre: string): TArray<TStructureEntry>;
var
  I: Integer;
begin
  for I := Low(GENRE_ARCHETYPES) to High(GENRE_ARCHETYPES) do
    if SameText(GENRE_ARCHETYPES[I].Genre, LowerCase(Genre)) then
    begin
      { Copy the array of TStructureEntry into result. */
      { In Pascal this requires explicit copy since arrays aren't assignable. */
      SetLength(Result, Length(GENRE_ARCHETYPES[I].Structure));
      for var J := 0 to Length(GENRE_ARCHETYPES[I].Structure) - 1 do
      begin
        Result[J] := GENRE_ARCHETYPES[I].Structure[J];
      end;
      Exit;
    end;

  { Default: verse-chorus pop structure. */
  SetLength(Result, 7);
  Result[0] := (Name: 'intro'; Bars: 4);
  Result[1] := (Name: 'verse'; Bars: 8);
  Result[2] := (Name: 'chorus'; Bars: 8);
  Result[3] := (Name: 'verse'; Bars: 8);
  Result[4] := (Name: 'chorus'; Bars: 8);
  Result[5] := (Name: 'bridge'; Bars: 4);
  Result[6] := (Name: 'outro'; Bars: 8);
end;

function TDrumGenerator.CreateSongV2(const Genre, Style: string; ATempo: Integer = 120;
  const AStructure: TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil): TSong;
{ Bar-by-bar pattern evolution (Engine V2). */
var
  Tempo: Integer;
  Structure: TArray<TStructureEntry>;
  Composer: TComposerV2;
begin
  { Resolve tempo. */
  if ATempo = 0 then
    Tempo := GetDefaultBpm(Genre, Style)
  else
    Tempo := ATempo;

  { Update drum kit / MIDI engine if new kit provided. */
  if Assigned(ADrumKit) then
  begin
    FDrumKit := ADrumKit;
    FMidiEngine := TMIDIEngine.Create(FDrumKit);
  end;

  { Use default structure if none provided. */
  if (AStructure = nil) or (Length(AStructure) = 0) then
    Structure := GetGenreDefaultStructure(Genre)
  else
    Structure := AStructure;

  { Compose with V2 engine. */
  Composer := TComposerV2.Create(FPluginManager, Random(MaxInt));
  try
    Result := Composer.CreateSong(Genre, Style, Tempo, Structure);

    { Apply genre-aware groove restraints (snare/velocity). */
    ApplyGrooveRestraints(Result);
  finally
    Composer.Free;
  end;
end;

function TDrumGenerator.CreateSong(const Genre, Style: string; ATempo: Integer = 120;
  const AStructure: TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
  AEngineOverride: string = ''): TSong;
{ Public entry — selects V1 (static) or V2 (bar-by-bar). */
var
  Engine: string;
begin
  { Resolve engine. */
  Engine := AEngineOverride;
  if Engine = '' then
    Engine := FComposerEngine;

  { Resolve tempo. */
  var Tempo: Integer := ATempo;
  if Tempo = 0 then
    Tempo := GetDefaultBpm(Genre, Style);

  { Update drum kit / MIDI engine. */
  if Assigned(ADrumKit) then
  begin
    FDrumKit := ADrumKit;
    FMidiEngine := TMIDIEngine.Create(FDrumKit);
  end;

  { V2: bar-by-bar evolution (recommended). */
  if Engine = 'v2' then
    Exit(CreateSongV2(Genre, Style, Tempo, AStructure, ADrumKit));

  { V1: static pattern reuse (original behavior — stub for now). */
  { This mirrors the original create_song_v1() that reused one pattern for all bars. */
  var Params := TGenerationParameters.Create(Genre, Style);
  var SongName := Genre + '_' + Style + '_song';
  Result := TSong.Create(SongName, Tempo);
  Result.FGlobalParameters := Params;

  { Stub: create one section with a placeholder pattern. */
  { Full V1 impl would query the genre plugin for its single pattern and repeat. */
  var Section := TSection.Create('full', TPattern.Create(Genre + '_' + Style), Length(AStructure));
  Result.Sections.Add(Section);
end;

procedure TDrumGenerator.SaveSongMidi(const ASong: TSong; const AOutputPath: string);
begin
  if not Assigned(FMidiEngine) then Exit;
  FMidiEngine.SaveSongMidi(ASong, AOutputPath);
end;

procedure TDrumGenerator.SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);
begin
  if not Assigned(FMidiEngine) then Exit;
  FMidiEngine.SavePatternMidi(APattern, AOutputPath, ATempo);
end;

end.
