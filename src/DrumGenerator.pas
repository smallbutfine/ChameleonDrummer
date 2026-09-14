unit DrumGenerator;

{$mode objfpc}{$H+}

{ Main drum generation engine and composition system.
  Entry point for all MIDI drum generation. Wraps ComposerV2 (bar-by-bar
  pattern evolution) with plugin discovery, genre plugins, drummer styles,
  and MIDI export. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song,
  time_signature, generation_parameters, ComposerV2, midi_engine,
  PluginRegistry, GenrePlugin, Metal, Rock, Jazz, Funk, Electronic, { genre plugins }
    Bonham, Porcaro, Weckl, Chambers, Roeder, Dee, Hoglan, Peart,
    Rich, Copeland, Carey, Smith, Moon, Watts, Haake, Halpern, doom_blues;{ drummer plugins }
{ forward declarations for genres / drummers loaded at runtime }

{ â”€â”€ Genre archetypes â€” default song structures per genre. }

type
  { Use ComposerV2's TSectionDef everywhere for compatibility }
  TStructureEntry = ComposerV2.TSectionDef;
  TSongStructureArray = array of TSectionDef;
  TArchetype = record Genre: string; Structure: TSongStructureArray; end;

var
  GENRE_ARCHETYPES: array of TArchetype;

type
TDrumGenerator = class(TObject)
private
  FPluginManager: TPluginManager;
  FDrumKit: TDrumKit;
  FMidiEngine: TMIDIEngine;
  FComposerEngine: string;

  procedure LoadPlugins;
  function GetGenreDefaultStructure(const Genre: string): TSongStructureArray;

  { --- Private helpers for V1 engine. --- }
  procedure _GenerateVariations(const APattern: TPattern; out AResult: specialize TList<TPatternVariation>; const AParams: TGenerationParameters);
  procedure _GenerateFills(const Genre: string; out AResult: specialize TList<TFill>; const AParams: TGenerationParameters);

public
  constructor Create(AComposerEngine: string = 'v2'); { default = v2 (bar-by-bar). }
  destructor Destroy; override;

  { â”€â”€ Public API. }

  { Create a complete song with bar-by-bar pattern evolution (V2 engine). }
  function CreateSongV2(const Genre, Style: string; ATempo: Integer = 120;
    const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil): TSong;

  { Create a complete song â€” selects engine (V1 static or V2 evolution). }
  function CreateSong(const Genre, Style: string; ATempo: Integer = 120;
    const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
    AEngineOverride: string = ''): TSong;

  { Export a Song to a MIDI file. }
  procedure SaveSongMidi(const ASong: TSong; const AOutputPath: string);

  { Export a single Pattern to a MIDI file. }
  procedure SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);

  { Generate a single pattern for a genre/section. }
  function GeneratePattern(const Genre, SectionName: string; const ADk: TDrumKit): TPattern;

  property PluginManager: TPluginManager read FPluginManager;
  property DrumKit: TDrumKit read FDrumKit write FDrumKit;
  property MidiEngine: TMIDIEngine read FMidiEngine;
  property ComposerEngine: string read FComposerEngine write FComposerEngine;
end;

{ â”€â”€ Genre-aware BPM defaults. }

function GetDefaultBpm(const Genre, Style: string): Integer;

procedure ApplyGrooveRestraints(Song: TSong);
{ Groove restraints - per-genre velocity adjustments. }

implementation


{ â”€â”€ GetDefaultBpm â€” genre/style-aware default BPM. }

function GetDefaultBpm(const Genre, Style: string): Integer;
var
  DefaultTempoMaps: record { Simplified â€” real impl uses bpm_ranges module. }
    metal: array[0..6] of record Style: string; Tempo: Integer; end;
  end;
begin
  { Simplified defaults from the bpm_ranges config. }
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
  else Result := 120; { default. }
  end;
end;

{ â”€â”€ ApplyGrooveRestraints â€” per-genre velocity adjustments for musicality. }

procedure ApplyGrooveRestraints(Song: TSong);
var
  Genre: string;
  Section: TSection;
  Beat: TBeat;
  InstrumentName: string;
begin
  if not Assigned(Song.GlobalParameters) then
    Genre := 'rock'
  else
    Genre := Song.GlobalParameters.Genre;

  for Section in Song.Sections do
  begin
    if Assigned(Section.Pattern) then
    begin
      for Beat in Section.Pattern.Beats do
      begin
        InstrumentName := '';
        if Assigned(Beat.Instrument) then
          InstrumentName := Beat.Instrument.Name;

        { Jazz: attenuate snares and cymbals. }
        if SameText(Genre, 'jazz') then
        begin
          if SameText(InstrumentName, 'snare_rimshot_open_hit') and not Beat.GhostNote then
            Beat.Velocity := Min(Beat.Velocity, 85);

          if (Pos('cymbal', LowerCase(InstrumentName)) > 0) or
             (Pos('crash', LowerCase(InstrumentName)) > 0) or
             (Pos('ride', LowerCase(InstrumentName)) > 0) then
            Beat.Velocity := Min(Beat.Velocity, 75);
        end;

        { Funk: tighten snare backbeat. }
        if SameText(Genre, 'funk') and SameText(InstrumentName, 'snare_rimshot_open_hit') then
          if not Beat.GhostNote then
            Beat.Velocity := Max(Min(Beat.Velocity, 108), 95);

        { Metal: ensure snares stay punchy. }
        if SameText(Genre, 'metal') and SameText(InstrumentName, 'snare_rimshot_open_hit') then
          if Beat.Velocity < 100 then
            Beat.Velocity := Min(Beat.Velocity + 25, 127);
      end;
    end;
  end;
end;

{ â”€â”€ TDrumGenerator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

constructor TDrumGenerator.Create(AComposerEngine: string = 'v2');
begin
  inherited Create;
  FComposerEngine := AComposerEngine;
  FPluginManager := TPluginManager.Create;
  FDrumKit := TDrumKit.FromKeymapName('gm'); { Default GM keymap. }
  FMidiEngine := TMIDIEngine.Create(480, FDrumKit);

  LoadPlugins;
end;

destructor TDrumGenerator.Destroy;
begin
  FPluginManager.Free;
  FMidiEngine.Free;
  inherited Destroy;
end;

procedure TDrumGenerator.LoadPlugins;
var
  GS: specialize TArray<string>; { Genre Styles }
  PD: specialize TArray<string>; { Pref Drummers }
  DG: specialize TArray<string>; { Drummer Genres }
begin
  { â”€â”€ Register genre plugins â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€}

  { Metal â€” 7 styles, drummers: hoglan, peart, dee, rich, haake }
  SetLength(GS, 7); GS[0] := 'heavy'; GS[1] := 'death'; GS[2] := 'power';
  GS[3] := 'progressive'; GS[4] := 'thrash'; GS[5] := 'doom'; GS[6] := 'breakdown';
  SetLength(PD, 5); PD[0] := 'hoglan'; PD[1] := 'peart'; PD[2] := 'dee';
  PD[3] := 'rich'; PD[4] := 'haake';
  FPluginManager.Registry.RegisterGenrePlugin('metal', TMetalGenrePlugin.Create, GS, PD);

  { Rock â€” 7 styles, drummers: bonham, porcaro, copeland }
  SetLength(GS, 0); SetLength(GS, 7); GS[0] := 'classic'; GS[1] := 'blues';
  GS[2] := 'alternative'; GS[3] := 'progressive'; GS[4] := 'punk';
  GS[5] := 'hard'; GS[6] := 'pop';
  SetLength(PD, 0); SetLength(PD, 3); PD[0] := 'bonham';
  PD[1] := 'porcaro'; PD[2] := 'copeland';
  FPluginManager.Registry.RegisterGenrePlugin('rock', TRockGenrePlugin.Create, GS, PD);

  { Jazz â€” 7 styles, drummers: weckl, halpern }
  SetLength(GS, 0); SetLength(GS, 7); GS[0] := 'swing'; GS[1] := 'bebop';
  GS[2] := 'fusion'; GS[3] := 'latin'; GS[4] := 'ballad';
  GS[5] := 'hard_bop'; GS[6] := 'contemporary';
  SetLength(PD, 0); SetLength(PD, 2); PD[0] := 'weckl'; PD[1] := 'halpern';
  FPluginManager.Registry.RegisterGenrePlugin('jazz', TJazzGenrePlugin.Create, GS, PD);

  { Funk â€” 7 styles, drummers: chambers, porcaro }
  SetLength(GS, 0); SetLength(GS, 7); GS[0] := 'classic'; GS[1] := 'pfunk';
  GS[2] := 'shuffle'; GS[3] := 'new_orleans'; GS[4] := 'fusion';
  GS[5] := 'minimal'; GS[6] := 'heavy';
  SetLength(PD, 0); SetLength(PD, 2); PD[0] := 'chambers'; PD[1] := 'porcaro';
  FPluginManager.Registry.RegisterGenrePlugin('funk', TFunkGenrePlugin.Create, GS, PD);

  { Electronic â€” 4 styles, no preferred drummers }
  SetLength(GS, 0); SetLength(GS, 4); GS[0] := 'house'; GS[1] := 'techno';
  GS[2] := 'drum_and_bass'; GS[3] := 'dubstep';
  FPluginManager.Registry.RegisterGenrePlugin('electronic', TElectronicGenrePlugin.Create, GS, []);

  { â”€â”€ Register drummer plugins â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€}
  SetLength(DG, 0);

  { bonham â€” rock, metal, blues }
  SetLength(DG, 3); DG[0] := 'rock'; DG[1] := 'metal'; DG[2] := 'blues';
  FPluginManager.Registry.RegisterDrummerPlugin('bonham', TBonhamPlugin.Create, DG);

  { porcaro â€” rock, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('porcaro', TPorcaroPlugin.Create, DG);

  { weckl â€” jazz, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'jazz'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('weckl', TWecklPlugin.Create, DG);

  { chambers â€” funk, rock }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'funk'; DG[1] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('chambers', TChambersPlugin.Create, DG);

  { roeder â€” metal }
  SetLength(DG, 0); SetLength(DG, 1); DG[0] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('roeder', TRoederPlugin.Create, DG);

  { dee â€” metal, rock }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'metal'; DG[1] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('dee', TDeePlugin.Create, DG);

  { hoglan â€” metal }
  SetLength(DG, 0); SetLength(DG, 1); DG[0] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('hoglan', THoglanPlugin.Create, DG);

  { peart â€” metal, rock }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'metal'; DG[1] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('peart', TPeartPlugin.Create, DG);

  { rich â€” jazz, rock }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'jazz'; DG[1] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('rich', TRichPlugin.Create, DG);

  { copeland â€” rock, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('copeland', TCopelandPlugin.Create, DG);

  { carey â€” metal }
  SetLength(DG, 0); SetLength(DG, 1); DG[0] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('carey', TCareyPlugin.Create, DG);

  { smith â€” rock, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('smith', TSmithPlugin.Create, DG);

  { moon â€” metal }
  SetLength(DG, 0); SetLength(DG, 1); DG[0] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('moon', TMoonPlugin.Create, DG);

  { watts â€” rock, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('watts', TWattsPlugin.Create, DG);

  { haake â€” metal }
  SetLength(DG, 0); SetLength(DG, 1); DG[0] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('haake', THaakePlugin.Create, DG);

  { halpern â€” jazz, metal }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'jazz'; DG[1] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('halpern', THalpernPlugin.Create, DG);

  { doomblues â€” metal }
  SetLength(DG, 0); SetLength(DG, 1); DG[0] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('doomblues', TDoomBluesPlugin.Create, DG);
end;

function TDrumGenerator.GetGenreDefaultStructure(const Genre: string): TSongStructureArray;
var
  I, J: Integer;
begin
  for I := Low(GENRE_ARCHETYPES) to High(GENRE_ARCHETYPES) do
    if SameText(GENRE_ARCHETYPES[I].Genre, LowerCase(Genre)) then
    begin
      { Copy the array of TStructureEntry into result. }
      { In Pascal this requires explicit copy since arrays aren't assignable. }
      SetLength(Result, Length(GENRE_ARCHETYPES[I].Structure));
      for J := 0 to Length(GENRE_ARCHETYPES[I].Structure) - 1 do
      begin
        Result[J] := GENRE_ARCHETYPES[I].Structure[J];
      end;
      Exit;
    end;

  { Default: verse-chorus pop structure. }
  SetLength(Result, 7);
  Result[0].Name := 'intro';
  Result[0].Bars := 4;
  Result[1].Name := 'verse';
  Result[1].Bars := 8;
  Result[2].Name := 'chorus';
  Result[2].Bars := 8;
  Result[3].Name := 'verse';
  Result[3].Bars := 8;
  Result[4].Name := 'chorus';
  Result[4].Bars := 8;
  Result[5].Name := 'bridge';
  Result[5].Bars := 4;
  Result[6].Name := 'outro';
  Result[6].Bars := 8;
end;

function TDrumGenerator.CreateSongV2(const Genre, Style: string; ATempo: Integer = 120;
  const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil): TSong;
{ Bar-by-bar pattern evolution (Engine V2). }
var
  Tempo: Integer;
  Structure: specialize TArray<TStructureEntry>;
  Composer: TComposerV2;
begin
  { Resolve tempo. }
  if ATempo = 0 then
    Tempo := GetDefaultBpm(Genre, Style)
  else
    Tempo := ATempo;

  { Update drum kit / MIDI engine if new kit provided. }
  if Assigned(ADrumKit) then
  begin
    FDrumKit := ADrumKit;
    FMidiEngine := TMIDIEngine.Create(480, FDrumKit);
  end;

  { Use default structure if none provided. }
  if (AStructure = nil) or (Length(AStructure) = 0) then
    Structure := GetGenreDefaultStructure(Genre)
  else
    Structure := AStructure;

  { Compose with V2 engine. }
  Composer := TComposerV2.Create(FPluginManager, Random(MaxInt));
  try
    Result := Composer.CreateSong(Genre, Style, Tempo, Structure);

    { Apply genre-aware groove restraints (snare/velocity). }
    ApplyGrooveRestraints(Result);
  finally
    Composer.Free;
  end;
end;

function TDrumGenerator.CreateSong(const Genre, Style: string; ATempo: Integer = 120;
  const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
  AEngineOverride: string = ''): TSong;
{ Public entry â€” selects V1 (static) or V2 (bar-by-bar). }
var
  Engine: string;
  Tempo: Integer;
  Structure: specialize TArray<TStructureEntry>;
  Params: TGenerationParameters;
  SongName: String;
  SectionName: String;
  Bars: Integer;
  Pattern: TPattern;
  Section: TSection;
  SecIdx: Integer;
  Variations: specialize TList<TPatternVariation>;
  Fills: specialize TList<TFill>;
begin
  { Resolve engine. }
  Engine := AEngineOverride;
  if Engine = '' then
    Engine := FComposerEngine;

  { Resolve tempo â€” use genre-aware default when zero. }
  Tempo := ATempo;
  if Tempo = 0 then
    Tempo := GetDefaultBpm(Genre, Style);

  { Update drum kit / MIDI engine if new kit provided. }
  if Assigned(ADrumKit) then
  begin
    FDrumKit := ADrumKit;
    FMidiEngine := TMIDIEngine.Create(480, FDrumKit);
  end;

  { V2: bar-by-bar evolution (recommended). }
  if Engine = 'v2' then
    Exit(CreateSongV2(Genre, Style, Tempo, AStructure, ADrumKit));

  { â”€â”€ Engine V1: Static pattern reuse â€” per-section pattern generation. â”€â”€ }
  Params := TGenerationParameters.Create(Genre, Style);
  SongName := Genre + '_' + Style + '_song';
  Result := TSong.Create(SongName, Tempo);
  Result.GlobalParameters := Params;

  { Use default structure if none provided. }
  if (AStructure = nil) or (Length(AStructure) = 0) then
    Structure := GetGenreDefaultStructure(Genre)
  else
    Structure := AStructure;

  for SecIdx := Low(Structure) to High(Structure) do
  begin
    SectionName := Structure[SecIdx].Name;
    Bars := Structure[SecIdx].Bars;

    { Generate pattern for this section. }
    Pattern := GeneratePattern(Genre, SectionName, TDrumKit.Create('gm', 10));
    try
      if Assigned(Pattern) then
      begin
        Section := TSection.Create(SectionName, Pattern, Bars);
        Result.Sections.Add(Section);

        { Add variations for high complexity. }
        if Params.Complexity > 0.5 then
        begin
          Variations := specialize TList<TPatternVariation>.Create;
          try
            _GenerateVariations(Pattern, Variations, Params);
            Section.Variations.AddRange(Variations);
          finally
            Variations.Free;
          end;
        end;

        { Add fills for this section. }
        Fills := specialize TList<TFill>.Create;
        try
          _GenerateFills(Genre, Fills, Params);
          Section.Fills.AddRange(Fills);
        finally
          Fills.Free;
        end;
      end
      else
      begin
        { Pattern generation failed â€” create empty section. }
        Section := TSection.Create(SectionName, TPattern.Create(''), Bars);
        Result.Sections.Add(Section);
      end;
    except
      on E: Exception do
        Writeln('[Warning] Failed to generate section "' + SectionName + '": ', E.Message);
        { Continue with next section. }
    end;
  end;
end;

procedure TDrumGenerator.SaveSongMidi(const ASong: TSong; const AOutputPath: string);
begin
  if not Assigned(FMidiEngine) then Exit;
  FMidiEngine.SaveSong(ASong, AOutputPath, FDrumKit);
end;

procedure TDrumGenerator.SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);
begin
  if not Assigned(FMidiEngine) then Exit;
  FMidiEngine.SavePattern(APattern, AOutputPath, FDrumKit);
end;

{ â”€â”€ V1 helpers â€” pattern generation, variations, fills. â”€â”€ }

function TDrumGenerator.GeneratePattern(const Genre, SectionName: string; const ADk: TDrumKit): TPattern;
var
  GenrePlugin: TObject;
  Params: TGenerationParameters;
begin
  Result := nil;

  try
    if not Assigned(FPluginManager) then Exit;

    { Query genre plugin by name. }
    GenrePlugin := FPluginManager.Registry.GetGenrePlugin(Genre);
    if not Assigned(GenrePlugin) then Exit;

    { Delegate to genre plugin's pattern generator. }
    Params := TGenerationParameters.Create(Genre, 'default');
    try
      Result := (GenrePlugin as TGenrePlugin).GeneratePattern(SectionName, Params);
    finally
      Params.Free;
    end;
  except
    on E: Exception do
      Writeln('[Warning] GeneratePattern failed: ', E.Message);
  end;
end;

procedure TDrumGenerator._GenerateVariations(const APattern: TPattern; out AResult: specialize TList<TPatternVariation>; const AParams: TGenerationParameters);
var
  VarName: string;
begin
  { V1 variations â€” simple pattern copy. }
  AResult := specialize TList<TPatternVariation>.Create;

  if not Assigned(APattern) then Exit;

  VarName := APattern.Name + '_variation';
  AResult.Add(TPatternVariation.Create(APattern));
end;

procedure TDrumGenerator._GenerateFills(const Genre: string; out AResult: specialize TList<TFill>; const AParams: TGenerationParameters);
var
  GenrePlugin: TObject;
  CommonFills: specialize TList<TFill>;
begin
  { V1 fills â€” get common fills from genre plugin. }
  AResult := specialize TList<TFill>.Create;

  try
    GenrePlugin := FPluginManager.Registry.GetGenrePlugin(Genre);
    if not Assigned(GenrePlugin) then Exit;

    { Get common fills from genre plugin. }
    CommonFills := (GenrePlugin as TGenrePlugin).GetCommonFills;
    if Assigned(CommonFills) and (CommonFills.Count > 0) then
      AResult.AddRange(CommonFills);
  except
    on E: Exception do
      Writeln('[Warning] _GenerateFills failed: ', E.Message);
  end;
end;

initialization
  SetLength(GENRE_ARCHETYPES, 5);
  GENRE_ARCHETYPES[0].Genre := 'metal';
  SetLength(GENRE_ARCHETYPES[0].Structure, 8);
  GENRE_ARCHETYPES[0].Structure[0].Name := 'intro';
  GENRE_ARCHETYPES[0].Structure[0].Bars := 4;
  GENRE_ARCHETYPES[0].Structure[1].Name := 'verse';
  GENRE_ARCHETYPES[0].Structure[1].Bars := 8;
  GENRE_ARCHETYPES[0].Structure[2].Name := 'chorus';
  GENRE_ARCHETYPES[0].Structure[2].Bars := 8;
  GENRE_ARCHETYPES[0].Structure[3].Name := 'verse';
  GENRE_ARCHETYPES[0].Structure[3].Bars := 8;
  GENRE_ARCHETYPES[0].Structure[4].Name := 'chorus';
  GENRE_ARCHETYPES[0].Structure[4].Bars := 8;
  GENRE_ARCHETYPES[0].Structure[5].Name := 'bridge';
  GENRE_ARCHETYPES[0].Structure[5].Bars := 4;
  GENRE_ARCHETYPES[0].Structure[6].Name := 'chorus';
  GENRE_ARCHETYPES[0].Structure[6].Bars := 8;
  GENRE_ARCHETYPES[0].Structure[7].Name := 'outro';
  GENRE_ARCHETYPES[0].Structure[7].Bars := 4;

  GENRE_ARCHETYPES[1].Genre := 'rock';
  SetLength(GENRE_ARCHETYPES[1].Structure, 8);
  GENRE_ARCHETYPES[1].Structure[0].Name := 'intro';
  GENRE_ARCHETYPES[1].Structure[0].Bars := 4;
  GENRE_ARCHETYPES[1].Structure[1].Name := 'verse';
  GENRE_ARCHETYPES[1].Structure[1].Bars := 8;
  GENRE_ARCHETYPES[1].Structure[2].Name := 'chorus';
  GENRE_ARCHETYPES[1].Structure[2].Bars := 8;
  GENRE_ARCHETYPES[1].Structure[3].Name := 'verse';
  GENRE_ARCHETYPES[1].Structure[3].Bars := 8;
  GENRE_ARCHETYPES[1].Structure[4].Name := 'chorus';
  GENRE_ARCHETYPES[1].Structure[4].Bars := 8;
  GENRE_ARCHETYPES[1].Structure[5].Name := 'bridge';
  GENRE_ARCHETYPES[1].Structure[5].Bars := 4;
  GENRE_ARCHETYPES[1].Structure[6].Name := 'chorus';
  GENRE_ARCHETYPES[1].Structure[6].Bars := 8;
  GENRE_ARCHETYPES[1].Structure[7].Name := 'outro';
  GENRE_ARCHETYPES[1].Structure[7].Bars := 4;

  GENRE_ARCHETYPES[2].Genre := 'jazz';
  SetLength(GENRE_ARCHETYPES[2].Structure, 6);
  GENRE_ARCHETYPES[2].Structure[0].Name := 'intro';
  GENRE_ARCHETYPES[2].Structure[0].Bars := 4;
  GENRE_ARCHETYPES[2].Structure[1].Name := 'verse';
  GENRE_ARCHETYPES[2].Structure[1].Bars := 8;
  GENRE_ARCHETYPES[2].Structure[2].Name := 'chorus';
  GENRE_ARCHETYPES[2].Structure[2].Bars := 8;
  GENRE_ARCHETYPES[2].Structure[3].Name := 'verse';
  GENRE_ARCHETYPES[2].Structure[3].Bars := 8;
  GENRE_ARCHETYPES[2].Structure[4].Name := 'chorus';
  GENRE_ARCHETYPES[2].Structure[4].Bars := 8;
  GENRE_ARCHETYPES[2].Structure[5].Name := 'outro';
  GENRE_ARCHETYPES[2].Structure[5].Bars := 4;

  GENRE_ARCHETYPES[3].Genre := 'funk';
  SetLength(GENRE_ARCHETYPES[3].Structure, 8);
  GENRE_ARCHETYPES[3].Structure[0].Name := 'intro';
  GENRE_ARCHETYPES[3].Structure[0].Bars := 4;
  GENRE_ARCHETYPES[3].Structure[1].Name := 'verse';
  GENRE_ARCHETYPES[3].Structure[1].Bars := 8;
  GENRE_ARCHETYPES[3].Structure[2].Name := 'chorus';
  GENRE_ARCHETYPES[3].Structure[2].Bars := 8;
  GENRE_ARCHETYPES[3].Structure[3].Name := 'verse';
  GENRE_ARCHETYPES[3].Structure[3].Bars := 8;
  GENRE_ARCHETYPES[3].Structure[4].Name := 'chorus';
  GENRE_ARCHETYPES[3].Structure[4].Bars := 8;
  GENRE_ARCHETYPES[3].Structure[5].Name := 'bridge';
  GENRE_ARCHETYPES[3].Structure[5].Bars := 4;
  GENRE_ARCHETYPES[3].Structure[6].Name := 'chorus';
  GENRE_ARCHETYPES[3].Structure[6].Bars := 8;
  GENRE_ARCHETYPES[3].Structure[7].Name := 'outro';
  GENRE_ARCHETYPES[3].Structure[7].Bars := 4;

  GENRE_ARCHETYPES[4].Genre := 'electronic';
  SetLength(GENRE_ARCHETYPES[4].Structure, 6);
  GENRE_ARCHETYPES[4].Structure[0].Name := 'intro';
  GENRE_ARCHETYPES[4].Structure[0].Bars := 8;
  GENRE_ARCHETYPES[4].Structure[1].Name := 'verse';
  GENRE_ARCHETYPES[4].Structure[1].Bars := 8;
  GENRE_ARCHETYPES[4].Structure[2].Name := 'chorus';
  GENRE_ARCHETYPES[4].Structure[2].Bars := 8;
  GENRE_ARCHETYPES[4].Structure[3].Name := 'verse';
  GENRE_ARCHETYPES[4].Structure[3].Bars := 8;
  GENRE_ARCHETYPES[4].Structure[4].Name := 'chorus';
  GENRE_ARCHETYPES[4].Structure[4].Bars := 8;
  GENRE_ARCHETYPES[4].Structure[5].Name := 'outro';
  GENRE_ARCHETYPES[4].Structure[5].Bars := 8;

end.
