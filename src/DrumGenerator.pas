unit DrumGenerator;

{$mode objfpc}{$H+}

{ Main drum generation engine and composition system.
  Entry point for all MIDI drum generation. Wraps ComposerV2 (bar-by-bar
  pattern evolution) with plugin discovery, genre plugins, drummer styles,
  and MIDI export. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song,
  time_signature, generation_parameters, ComposerV2, GenreDefaults, ConfigFiles,
  PluginRegistry, GenrePlugin, Metal, Rock, Jazz, Funk, Electronic, { genre plugins }
    Bonham, Porcaro, Weckl, Chambers, Roeder, Dee, Hoglan, Peart,
    Rich, Copeland, Carey, Smith, Moon, Watts, Haake, Halpern, doom_blues, { drummer plugins }
  MidiIO;
{ forward declarations for genres / drummers loaded at runtime }

{  Genre archetypes default song structures per genre. }

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
  // MIDIEngine replaced by DrumMidiLoader (MidiIO + MidiParser)
  FComposerEngine: string;

  FLastWarnings: TStringList;


  procedure LoadPlugins;
  procedure SetDrumKit(AValue: TDrumKit);
  function GetGenreDefaultStructure(const Genre: string): TSongStructureArray;
  function FitDefaultStructureToRadioLength(
    const AStructure: TSongStructureArray; ATempo: Integer;
    ABarQuarters: Double = 4.0): TSongStructureArray;


public
  constructor Create(AComposerEngine: string = 'v2'); { default = v2 (bar-by-bar, matches Python) }
  destructor Destroy; override;

  {  Public API. }

  { Create a complete song with bar-by-bar pattern evolution (V2 engine). }
  function CreateSongV2(const Genre, Style: string; ATempo: Integer = 0;
    const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
    ADrummer: string = ''; AComplexity: Double = 0.5; ADynamics: Double = 0.6;
    AHumanization: Double = 0.5; ASwing: Double = 0.0;
    AMeterNum: Integer = 4; AMeterDen: Integer = 4;
    AStrictMeter: Boolean = False): TSong;

  { Create a complete song — always uses V2 (bar-by-bar evolution). }
  function CreateSong(const Genre, Style: string; ATempo: Integer = 0;
    const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
    ADrummer: string = ''; AComplexity: Double = 0.5;
    ADynamics: Double = 0.6; AHumanization: Double = 0.5;
    ASwing: Double = 0.0; AMeterNum: Integer = 4; AMeterDen: Integer = 4;
    AStrictMeter: Boolean = False): TSong;

  { The default song structure of a genre as it is before it is fitted to a
    song length: config/sections/<genre>.json, else the built-in one. }
  function DefaultStructure(const Genre: string): specialize TArray<TStructureEntry>;

  { Export a Song to a MIDI file. }
  procedure SaveSongMidi(const ASong: TSong; const AOutputPath: string);

  { Export a single Pattern to a MIDI file. }
  procedure SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);

  { Generate a single pattern for a genre/section. }
  function GeneratePattern(const Genre, SectionName: string; const ADk: TDrumKit;
    const AStyle: string = ''; AMeterNum: Integer = 4; AMeterDen: Integer = 4;
    AStrictMeter: Boolean = False): TPattern;

  { Problems the pattern check found in the song made by the last CreateSong

    call, one line each (e.g. a beat beyond its pattern's length). Empty when
    the song is clean. }

  property LastWarnings: TStringList read FLastWarnings;
  property PluginManager: TPluginManager read FPluginManager;
  property DrumKit: TDrumKit read FDrumKit write SetDrumKit;
  property ComposerEngine: string read FComposerEngine write FComposerEngine;
end;

{  Genre-aware BPM defaults. }

function GetDefaultBpm(const Genre, Style: string): Integer;

{ The tempos compiled into the program, which config/defaults/<genre>.ini
  overrides. }
function BuiltInBpm(const Genre, Style: string): Integer;

procedure ApplyGrooveRestraints(Song: TSong);
{ Groove restraints - per-genre velocity adjustments. }

implementation


{  GetDefaultBpm  genre/style-aware default BPM. }

{ The tempos built into the program, used when config/defaults/<genre>.ini
  has no value for the style. }
function BuiltInBpm(const Genre, Style: string): Integer;
begin
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

function GetDefaultBpm(const Genre, Style: string): Integer;
begin
  Result := FileDefaultBpm(Genre, Style);
  if Result = 0 then
    Result := BuiltInBpm(Genre, Style);
end;

{  ApplyGrooveRestraints per-genre velocity adjustments for musicality. }

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

{ TDrumGenerator }

constructor TDrumGenerator.Create(AComposerEngine: string = 'v2');
begin
  inherited Create;
  FComposerEngine := AComposerEngine;

  FLastWarnings := TStringList.Create;
  FPluginManager := TPluginManager.Create();
  FDrumKit := TDrumKit.FromKeymapName('gm'); { Default GM keymap. }

  LoadPlugins;
end;

destructor TDrumGenerator.Destroy;
begin
  FDrumKit.Free;

  FPluginManager.Free;

  FLastWarnings.Free;

  inherited Destroy;
end;

procedure TDrumGenerator.SetDrumKit(AValue: TDrumKit);
begin
  if FDrumKit = AValue then
    Exit;
  FDrumKit.Free;
  FDrumKit := AValue;
end;

procedure TDrumGenerator.LoadPlugins;
var
  PD: specialize TArray<string>; { Pref Drummers }
  DG: specialize TArray<string>; { Drummer Genres }

  { The preferred drummers of a genre: config/defaults/<genre>.ini when it
    names some, else the built-in list. Names of drummers that do not exist
    are dropped and reported. }
  procedure RegisterGenre(const AName: string; APlugin: TGenrePlugin;
    const APreferred: array of string);
  var
    FromFile, Chosen: specialize TArray<string>;
    Name: string;
    I: Integer;
  begin
    FromFile := FilePreferredDrummers(AName);
    if Length(FromFile) = 0 then
    begin
      SetLength(Chosen, Length(APreferred));
      for I := 0 to High(APreferred) do
        Chosen[I] := APreferred[I];
    end
    else
    begin
      Chosen := nil;
      for Name in FromFile do
        if Assigned(FPluginManager.Registry.GetDrummerPlugin(Name)) then
        begin
          SetLength(Chosen, Length(Chosen) + 1);
          Chosen[High(Chosen)] := Name;
        end
        else
          AddConfigWarning(Format('%s.ini [drummers]: there is no drummer "%s" - ignored',
            [LowerCase(AName), Name]));
    end;
    FPluginManager.Registry.RegisterGenrePlugin(AName, APlugin,
      APlugin.GetSupportedStyles, Chosen);
  end;

begin
  {  Register drummer plugins first, so the genres can check their preferred
     drummers against them. }
  SetLength(DG, 0);

  { bonham  rock, metal, blues }
  SetLength(DG, 3); DG[0] := 'rock'; DG[1] := 'metal'; DG[2] := 'blues';
  FPluginManager.Registry.RegisterDrummerPlugin('bonham', TBonhamPlugin.Create, DG);

  { porcaro  rock, funk, pop }
  SetLength(DG, 0); SetLength(DG, 3); DG[0] := 'rock'; DG[1] := 'funk'; DG[2] := 'pop';
  FPluginManager.Registry.RegisterDrummerPlugin('porcaro', TPorcaroPlugin.Create, DG);

  { weckl  jazz, fusion, rock }
  SetLength(DG, 0); SetLength(DG, 3); DG[0] := 'jazz'; DG[1] := 'fusion'; DG[2] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('weckl', TWecklPlugin.Create, DG);

  { chambers  funk, rock }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'funk'; DG[1] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('chambers', TChambersPlugin.Create, DG);

  { roeder metal, doom }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'metal'; DG[1] := 'doom';
  FPluginManager.Registry.RegisterDrummerPlugin('roeder', TRoederPlugin.Create, DG);

  { dee metal, rock }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'metal'; DG[1] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('dee', TDeePlugin.Create, DG);

  { hoglan metal, progressive }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'metal'; DG[1] := 'progressive';
  FPluginManager.Registry.RegisterDrummerPlugin('hoglan', THoglanPlugin.Create, DG);

  { peart  progressive, metal }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'progressive'; DG[1] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('peart', TPeartPlugin.Create, DG);

  { rich  jazz, rock }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'jazz'; DG[1] := 'rock';
  FPluginManager.Registry.RegisterDrummerPlugin('rich', TRichPlugin.Create, DG);

  { copeland  rock, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('copeland', TCopelandPlugin.Create, DG);

  { carey metal, progressive }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'metal'; DG[1] := 'progressive';
  FPluginManager.Registry.RegisterDrummerPlugin('carey', TCareyPlugin.Create, DG);

  { smith  rock, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('smith', TSmithPlugin.Create, DG);

  { moon rock, funk }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'funk';
  FPluginManager.Registry.RegisterDrummerPlugin('moon', TMoonPlugin.Create, DG);

  { watts rock, metal }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'rock'; DG[1] := 'metal';
  FPluginManager.Registry.RegisterDrummerPlugin('watts', TWattsPlugin.Create, DG);

  { haake metal, progressive }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'metal'; DG[1] := 'progressive';
  FPluginManager.Registry.RegisterDrummerPlugin('haake', THaakePlugin.Create, DG);

  { halpern jazz, fusion }
  SetLength(DG, 0); SetLength(DG, 2); DG[0] := 'jazz'; DG[1] := 'fusion';
  FPluginManager.Registry.RegisterDrummerPlugin('halpern', THalpernPlugin.Create, DG);

  { doomblues metal, rock, blues }
  SetLength(DG, 0); SetLength(DG, 3); DG[0] := 'metal'; DG[1] := 'rock'; DG[2] := 'blues';
  FPluginManager.Registry.RegisterDrummerPlugin('doomblues', TDoomBluesPlugin.Create, DG);

  {  Register genre plugins. The styles come from the plugin itself, so a
     style that only a groove file defines is registered too. }
  PD := ['bonham', 'roeder', 'dee', 'hoglan', 'peart', 'carey', 'watts',
    'haake', 'doomblues'];
  RegisterGenre('metal', TMetalGenrePlugin.Create, PD);

  PD := ['bonham', 'porcaro', 'weckl', 'chambers', 'dee', 'rich', 'copeland',
    'smith', 'moon', 'watts', 'doomblues'];
  RegisterGenre('rock', TRockGenrePlugin.Create, PD);

  PD := ['weckl', 'chambers', 'rich', 'halpern'];
  RegisterGenre('jazz', TJazzGenrePlugin.Create, PD);

  PD := ['porcaro', 'chambers', 'copeland', 'smith', 'moon'];
  RegisterGenre('funk', TFunkGenrePlugin.Create, PD);

  { Electronic has no preferred drummers. }
  PD := [];
  RegisterGenre('electronic', TElectronicGenrePlugin.Create, PD);
end;

function TDrumGenerator.DefaultStructure(const Genre: string): specialize TArray<TStructureEntry>;
begin
  Result := GetGenreDefaultStructure(Genre);
end;

function TDrumGenerator.GetGenreDefaultStructure(const Genre: string): TSongStructureArray;
var
  I, J: Integer;
begin
  { config/sections/<genre>.json first. }
  Result := FileDefaultStructure(Genre);
  if Length(Result) > 0 then
    Exit;
  Result := nil;
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

function TDrumGenerator.FitDefaultStructureToRadioLength(
  const AStructure: TSongStructureArray; ATempo: Integer;
  ABarQuarters: Double): TSongStructureArray;
var
  BaseTotal, BarSeconds: Double;
  TargetSeconds: Integer;
  MaxBars, TargetBars, BarsPerUnit, TargetUnits, MaxUnits: Integer;
  RemainingUnits, AssignedUnits, I, BestIndex: Integer;
  RawUnits, BestRemainder: Double;
  Units: specialize TArray<Integer>;
  Remainders: specialize TArray<Double>;
begin
  SetLength(Result, Length(AStructure));
  if Length(AStructure) = 0 then
    Exit;

  BaseTotal := 0;
  for I := 0 to High(AStructure) do
  begin
    Result[I] := AStructure[I];
    BaseTotal := BaseTotal + Max(AStructure[I].Bars, 1);
  end;
  if (ATempo <= 0) or (BaseTotal <= 0) then
    Exit;

  { Vary the default arrangement between 3:00 and 3:45 before bar rounding. }
  TargetSeconds := 180 + Random(46);
  { A bar of ABarQuarters quarter notes lasts ABarQuarters * 60 / tempo seconds. }
  BarSeconds := ABarQuarters * 60.0 / ATempo;
  TargetBars := Max(Length(AStructure), Round(TargetSeconds / BarSeconds));
  MaxBars := Trunc(Floor(240.0 / BarSeconds));
  BarsPerUnit := 4;
  if (TargetBars < Length(AStructure) * BarsPerUnit) or
     (MaxBars < Length(AStructure) * BarsPerUnit) then
    BarsPerUnit := 1;

  TargetUnits := Max(Length(AStructure), Round(TargetBars / BarsPerUnit));
  MaxUnits := Max(Length(AStructure), MaxBars div BarsPerUnit);
  TargetUnits := Min(TargetUnits, MaxUnits);
  RemainingUnits := TargetUnits - Length(AStructure);
  SetLength(Units, Length(AStructure));
  SetLength(Remainders, Length(AStructure));
  AssignedUnits := 0;

  for I := 0 to High(AStructure) do
  begin
    RawUnits := RemainingUnits * Max(AStructure[I].Bars, 1) / BaseTotal;
    Units[I] := 1 + Trunc(Floor(RawUnits));
    Remainders[I] := RawUnits - Floor(RawUnits);
    Inc(AssignedUnits, Units[I]);
  end;

  while AssignedUnits < TargetUnits do
  begin
    BestIndex := 0;
    BestRemainder := -1.0;
    for I := 0 to High(Remainders) do
      if Remainders[I] > BestRemainder then
      begin
        BestIndex := I;
        BestRemainder := Remainders[I];
      end;
    Inc(Units[BestIndex]);
    Remainders[BestIndex] := -1.0;
    Inc(AssignedUnits);
  end;

  for I := 0 to High(Result) do
    Result[I].Bars := Units[I] * BarsPerUnit;
end;

function TDrumGenerator.CreateSongV2(const Genre, Style: string; ATempo: Integer = 0;
  const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
  ADrummer: string = ''; AComplexity: Double = 0.5; ADynamics: Double = 0.6;
  AHumanization: Double = 0.5; ASwing: Double = 0.0;
  AMeterNum: Integer = 4; AMeterDen: Integer = 4;
  AStrictMeter: Boolean = False): TSong;
{ Bar-by-bar pattern evolution (Engine V2). }
var
  Tempo: Integer;
  Structure: specialize TArray<TStructureEntry>;
  Composer: TComposerV2;
  GenrePlugin: TGenrePlugin;
  RideParams: TGenerationParameters;
  Section: TSection;
  NewPattern: TPattern;
  SectionIndex: Integer;
begin
  { Resolve tempo. }
  if ATempo = 0 then
    Tempo := GetDefaultBpm(Genre, Style)
  else
    Tempo := ATempo;

  { Update drum kit / MIDI engine if new kit provided. }
  if Assigned(ADrumKit) then
  begin
    SetDrumKit(ADrumKit);
  end;

  { Use default structure if none provided. }
  if (AStructure = nil) or (Length(AStructure) = 0) then
    Structure := FitDefaultStructureToRadioLength(
      GetGenreDefaultStructure(Genre), Tempo, AMeterNum * 4.0 / AMeterDen)
  else
    Structure := AStructure;

  { Compose with V2 engine. }
  Composer := TComposerV2.Create(FPluginManager, Random(MaxInt));
  try
    Result := Composer.CreateSong(Genre, Style, Tempo, Structure, ADrummer,
      AComplexity, ADynamics, AHumanization, ASwing, AMeterNum, AMeterDen);

    { Apply genre-aware hi-hat -> ride/crash promotion for high-energy
      sections (chorus / bridge / pre_chorus). This runs per section so the
      internal bar index is section-relative and the every-4th-bar bell accent
      can actually fire. }
    GenrePlugin := TGenrePlugin(FPluginManager.Registry.GetGenrePlugin(Genre));
    if Assigned(GenrePlugin) then
    begin
      RideParams := TGenerationParameters.Create(Genre, Style, ADrummer,
        AComplexity, ADynamics, AHumanization);
      try
        for SectionIndex := 0 to Result.Sections.Count - 1 do
        begin
          Section := Result.Sections[SectionIndex];
          if not Assigned(Section.Pattern) then
            Continue;
          { The ride switch looks at complexity, so it must see the
            section's own value when the structure gave one. }
          RideParams.MeterNum := AMeterNum;
          RideParams.MeterDen := AMeterDen;
          if (SectionIndex < Length(Structure)) and
             Structure[SectionIndex].HasComplexity then
            RideParams.Complexity := Structure[SectionIndex].Complexity
          else
            RideParams.Complexity := AComplexity;
          NewPattern := GenrePlugin.ApplyRideHihatLogic(Section.Pattern,
            Section.Name, RideParams);
          { The function returns the input unchanged when it does not apply. }
          if NewPattern <> Section.Pattern then
          begin
            Section.Pattern.Free;
            Section.Pattern := NewPattern;
          end;
        end;
      finally
        RideParams.Free;
      end;
    end;

    { Apply genre-aware groove restraints (snare/velocity). }
    ApplyGrooveRestraints(Result);


    { Report what is wrong with the patterns; nothing is changed or raised. }

    FLastWarnings.Clear;

    for SectionIndex := 0 to Result.Sections.Count - 1 do

    begin
      Section := Result.Sections[SectionIndex];
      if Assigned(Section.Pattern) then

        Section.Pattern.Validate(FLastWarnings);
    end;
  finally

    Composer.Free;

  end;

end;

function TDrumGenerator.CreateSong(const Genre, Style: string; ATempo: Integer = 0;
  const AStructure: specialize TArray<TStructureEntry> = nil; ADrumKit: TDrumKit = nil;
  ADrummer: string = ''; AComplexity: Double = 0.5;
  ADynamics: Double = 0.6; AHumanization: Double = 0.5;
  ASwing: Double = 0.0; AMeterNum: Integer = 4; AMeterDen: Integer = 4;
  AStrictMeter: Boolean = False): TSong;
begin
  Exit(CreateSongV2(Genre, Style, ATempo, AStructure, ADrumKit, ADrummer,
    AComplexity, ADynamics, AHumanization, ASwing, AMeterNum, AMeterDen,
    AStrictMeter));
end;

procedure TDrumGenerator.SaveSongMidi(const ASong: TSong; const AOutputPath: string);

{ Internal event record }
type
  TSongEvent = packed record
    Tick: Int64;
    Note: Byte;
    Velocity: Byte;
    Tempo: Integer;
    IsMeta: Boolean;
    IsTimeSignature: Boolean;
    TsNum: Byte;       { time signature numerator for meta events }
    TsDenLog: Byte;    { log2 of denominator for meta events }
  end;

var
  PPQ, _pbars, cycle_bar: Integer;
  LastTsNum, LastTsDen: Integer;
  BarDurationQuarters, FillOffsetQuarters: Double;
  TickOffset, AbsTick, PrevTick, GrooveOffsetTicks: Int64;
  GrooveOffsetMs: Double;
  I, J, I22, J22, FillBars, FillStartBar, FillNoteBar, FillTempo: Integer;
  Section: TSection;
  EffPattern: TPattern;
  Beat: TBeat;
  Fill: TFill;
  DupFound: Boolean;
  DurTicks, FillDurTicks: Integer;
  _max_pos: Double;
  Events: array of TSongEvent;
  FS: TFileStream;
  MicroSecs: Cardinal;
  b1, b2, b3, TsNumByte, logDen: Byte;
  MetaByte: Byte; { temp for literal byte writes }
  TrackStart: Int64;
  EffTs: TTimeSignature;
  EffTempo: Integer;
  InitialTempo, InitialTsNum, InitialTsDen: Integer;
  MidiNote: Integer;
  FirstSection: TSection;
  HeaderSize, FormatWord, TrackCount, PPQWord, DummySize, FinalSize: Cardinal;
  PrevBpm: Integer;
  TmpEvtRec: TSongEvent;
  BarStartIdx: array of Integer;
  GlobalBar, CutFromBar, FirstCutIdx, Src, Dst: Integer;
  FillMinTick: Int64;
  Pitch, PairCount, P, Q: Integer;
  PairOn: array of Integer;
  NextOnTick: Int64;

  { Sort key of an event: by tick, and at the same tick meta events first,
    then note-offs, then note-ons. A note-off that falls on the tick of the
    next hit of the same pitch must reach the player before that hit. }
  function EventKey(const E: TSongEvent): Int64;
  begin
    Result := E.Tick * 4;
    if E.IsMeta then
      { first at its tick }
    else if E.Velocity = 0 then
      Inc(Result)
    else
      Inc(Result, 2);
  end;

begin
  if not Assigned(ASong) or (ASong.Sections.Count = 0) then Exit;

  SetLength(Events, 0);
  SetLength(BarStartIdx, 0);
  GlobalBar := -1;
  TickOffset := 0;
  PPQ := 960;

  { MIDI PPQ is ticks per quarter note; pattern positions are quarter-note units. }
  FirstSection := ASong.Sections[0];
  EffTs := FirstSection.EffectiveTimeSignature(0, ASong.TimeSignature);
  LastTsNum := EffTs.Numerator;
  LastTsDen := EffTs.Denominator;
  PrevBpm := FirstSection.EffectiveTempo(0, ASong.Tempo);
  InitialTempo := PrevBpm;
  InitialTsNum := LastTsNum;
  InitialTsDen := LastTsDen;

  for Section in ASong.Sections do
  begin
    for I := 0 to Section.Bars - 1 do
    begin
      Inc(GlobalBar);
      SetLength(BarStartIdx, GlobalBar + 1);
      BarStartIdx[GlobalBar] := Length(Events);
      EffTs := Section.EffectiveTimeSignature(I, ASong.TimeSignature);
      EffTs.Validate;
      BarDurationQuarters := EffTs.BeatsPerBar;

      if (EffTs.Numerator <> LastTsNum) or (EffTs.Denominator <> LastTsDen) then
      begin
        if (EffTs.Numerator > 255) or (EffTs.Denominator > 128) then
          raise Exception.CreateFmt('MIDI time signature %d/%d is not representable',
            [EffTs.Numerator, EffTs.Denominator]);
        logDen := 0;
        J := EffTs.Denominator;
        while J > 1 do
        begin
          J := J div 2;
          Inc(logDen);
        end;
        SetLength(Events, Length(Events) + 1);
        with Events[High(Events)] do
        begin
          Tick := TickOffset;
          IsMeta := True;
          IsTimeSignature := True;
          TsNum := Byte(EffTs.Numerator);
          TsDenLog := logDen;
          Tempo := 0;
        end;
        LastTsNum := EffTs.Numerator;
        LastTsDen := EffTs.Denominator;
      end;

      { Write tempo change if needed }
      EffTempo := Section.EffectiveTempo(I, ASong.Tempo);
      if (EffTempo <> PrevBpm) then
      begin
        SetLength(Events, Length(Events) + 1);
        with Events[High(Events)] do
        begin
          Tick := TickOffset;
          IsMeta := True;
          IsTimeSignature := False;
          Tempo := EffTempo;
          TsNum := 0;
          TsDenLog := 0;
        end;
        PrevBpm := EffTempo;
      end;

      { Multi-bar pattern cycling — mirrors Python _song_to_bytes }
      EffPattern := Section.GetEffectivePattern(I);
      if Assigned(EffPattern) and (EffPattern.Beats.Count > 0) then
      begin
        _max_pos := -1.0;
        for Beat in EffPattern.Beats do
          if Beat.Position > _max_pos then _max_pos := Beat.Position;
        _pbars := Max(1, Trunc(_max_pos / BarDurationQuarters) + 1);
      end
      else begin
        _pbars := 1;
      end;

      cycle_bar := I mod _pbars;

      if Assigned(EffPattern) then
      for Beat in EffPattern.Beats do
      begin
        if not Assigned(Beat.Instrument) then
          Continue;
        if Trunc(Beat.Position / BarDurationQuarters) <> cycle_bar then
          Continue;

        GrooveOffsetTicks := 0;
        if I < Section.GrooveOffsetsMs.Count then
          GrooveOffsetTicks := Round(
            Section.GrooveOffsetsMs[I] * PPQ * EffTempo / 60000.0);
        AbsTick := TickOffset + Round(
          (Beat.Position - cycle_bar * BarDurationQuarters) * PPQ) +
          GrooveOffsetTicks;
        if AbsTick < 0 then
          AbsTick := 0;

        MidiNote := FDrumKit.GetMidiNote(Beat.Instrument.Name);
        if MidiNote <= 0 then Continue;

        { Deduplicate: skip if same note already at this tick }
        DupFound := False;
        for J := Low(Events) to High(Events) do
          if (Events[J].Tick = AbsTick) and not Events[J].IsMeta and
             (Events[J].Note = Byte(MidiNote)) and
             (Events[J].Velocity > 0) then
          begin
            DupFound := True;
            Break;
          end;
        if DupFound then Continue;

        { Add note_on event }
        SetLength(Events, Length(Events) + 1);
        with Events[High(Events)] do
        begin
          Tick := AbsTick;
          Note := Byte(MidiNote);
          Velocity := Byte(Min(Max(Beat.Velocity, 0), 127));
          IsMeta := False;
          IsTimeSignature := False;
        end;

        { Add note_off event }
        DurTicks := Max(Round(Min(Beat.Duration, 0.2) * PPQ), 1);
        SetLength(Events, Length(Events) + 1);
        with Events[High(Events)] do
        begin
          Tick := AbsTick + DurTicks;
          Note := Byte(MidiNote);
          Velocity := 0; { note-off velocity }
          IsMeta := False;
          IsTimeSignature := False;
        end;
      end;

      { Add a selected fill, positioned so its last bar reaches this boundary. }
      if Assigned(ASong.GlobalParameters) then
      begin
        Fill := Section.ShouldAddFill(I, ASong.GlobalParameters.FillFrequency);
        if Assigned(Fill) then
        begin
          FillBars := Ceil(Fill.Pattern.DurationBars);
          FillStartBar := I - FillBars + 1;
          FillOffsetQuarters := 0;
          for FillNoteBar := FillStartBar to I - 1 do
            FillOffsetQuarters :=
              FillOffsetQuarters -
              Section.EffectiveTimeSignature(FillNoteBar, ASong.TimeSignature).BeatsPerBar;

          { A drummer's hands leave the groove when the fill starts, so the
            groove is cut at the first fill hit instead of playing under it. }
          FillMinTick := High(Int64);
          for Beat in Fill.Pattern.Beats do
            if Assigned(Beat.Instrument) then
              FillMinTick := Min(FillMinTick, TickOffset + Round(
                (FillOffsetQuarters + Beat.Position) * PPQ));
          CutFromBar := Max(GlobalBar - (FillBars - 1), 0);
          if (FillMinTick < High(Int64)) and (CutFromBar <= GlobalBar) then
          begin
            { An earlier cut may have shortened the event list below the
              index recorded for this bar. }
            FirstCutIdx := Min(BarStartIdx[CutFromBar], Length(Events));
            Dst := FirstCutIdx;
            Src := FirstCutIdx;
            { Note-on and note-off are stored as adjacent pairs. }
            while Src <= High(Events) do
            begin
              if (not Events[Src].IsMeta) and (Events[Src].Velocity > 0) and
                 (Events[Src].Tick >= FillMinTick) and (Src < High(Events)) then
                Inc(Src, 2)
              else
              begin
                if Dst <> Src then
                  Events[Dst] := Events[Src];
                Inc(Dst);
                Inc(Src);
              end;
            end;
            SetLength(Events, Dst);
            for Src := CutFromBar + 1 to GlobalBar do
              BarStartIdx[Src] := Min(BarStartIdx[Src], Dst);
          end;

          for Beat in Fill.Pattern.Beats do
          begin
            FillNoteBar := FillStartBar + Trunc(
              Beat.Position / Fill.Pattern.TimeSignature.BeatsPerBar);
            GrooveOffsetMs := 0;
            FillTempo := Section.EffectiveTempo(FillNoteBar, ASong.Tempo);
            if (FillNoteBar >= 0) and
               (FillNoteBar < Section.GrooveOffsetsMs.Count) then
              GrooveOffsetMs := Section.GrooveOffsetsMs[FillNoteBar];
            GrooveOffsetTicks := Round(
              GrooveOffsetMs * PPQ * FillTempo / 60000.0);
            AbsTick := TickOffset + Round(
              (FillOffsetQuarters + Beat.Position) * PPQ) +
              GrooveOffsetTicks;
            if AbsTick < 0 then
              AbsTick := 0;
            DupFound := False;
              if not Assigned(Beat.Instrument) then
                Continue;
              MidiNote := FDrumKit.GetMidiNote(Beat.Instrument.Name);
              if MidiNote <= 0 then
                Continue;
              for J := Low(Events) to High(Events) do
                if (Events[J].Tick = AbsTick) and not Events[J].IsMeta and
                   (Events[J].Note = Byte(MidiNote)) and
                   (Events[J].Velocity > 0) then
              begin
                DupFound := True;
                Break;
              end;
              if DupFound then Continue;

              SetLength(Events, Length(Events) + 1);
              with Events[High(Events)] do
              begin
                Tick := AbsTick;
                Note := Byte(MidiNote);
              Velocity := Byte(Min(Max(Beat.Velocity, 0), 127));
              IsMeta := False;
                IsTimeSignature := False;
            end;

            FillDurTicks := Max(Round(Min(Beat.Duration, 0.2) * PPQ), 1);
            SetLength(Events, Length(Events) + 1);
            with Events[High(Events)] do
            begin
              Tick := AbsTick + FillDurTicks;
              Note := Byte(MidiNote);
              Velocity := 0;
              IsMeta := False;
              IsTimeSignature := False;
            end;
          end;
        end;
      end; { if GlobalParameters }

      Inc(TickOffset, Round(BarDurationQuarters * PPQ));
    end;
  end;

  { Drum-machine behaviour: a note rings until the next hit of the same pitch
    stops it, and the last hit of a pitch rings until the end of the song.
    There is no per-note length - a fast repeat (double bass on the one kick,
    a hi-hat roll) simply retriggers, and the note-off lands on the tick of
    the retrigger (sorted before the note-on). Every note-on is stored
    directly before its own note-off. }
  for Pitch := 0 to 127 do
  begin
    SetLength(PairOn, 0);
    PairCount := 0;
    for J := Low(Events) to High(Events) - 1 do
      if (not Events[J].IsMeta) and (Events[J].Velocity > 0) and
         (Events[J].Note = Pitch) and (not Events[J + 1].IsMeta) and
         (Events[J + 1].Velocity = 0) and (Events[J + 1].Note = Pitch) then
      begin
        SetLength(PairOn, PairCount + 1);
        PairOn[PairCount] := J;
        Inc(PairCount);
      end;
    for P := 0 to PairCount - 1 do
    begin
      NextOnTick := High(Int64);
      for Q := 0 to PairCount - 1 do
        if (Events[PairOn[Q]].Tick > Events[PairOn[P]].Tick) and
           (Events[PairOn[Q]].Tick < NextOnTick) then
          NextOnTick := Events[PairOn[Q]].Tick;
      if NextOnTick = High(Int64) then
        NextOnTick := Max(TickOffset, Events[PairOn[P]].Tick + 1);
      Events[PairOn[P] + 1].Tick := NextOnTick;
    end;
  end;

  { Sort all events (notes + meta) by absolute tick }
  if Length(Events) > 1 then
  begin
    for I22 := High(Events) downto Low(Events) do
      for J22 := Low(Events) to I22 - 1 do
        if EventKey(Events[J22]) > EventKey(Events[J22 + 1]) then
        begin
          TmpEvtRec := Events[J22];
          Events[J22] := Events[J22 + 1];
          Events[J22 + 1] := TmpEvtRec;
        end;
  end;

  { Write MIDI file directly — proper binary format }
  FS := TFileStream.Create(AOutputPath, fmCreate);
  try
    { MIDI Header: MThd }
    FS.WriteBuffer('MThd', 4);
    HeaderSize := Swap32(6);
    FS.WriteBuffer(HeaderSize, 4);
    FormatWord := Swap16(0); { Format 0 }
    FS.WriteBuffer(FormatWord, 2);
    TrackCount := Swap16(1); { 1 track }
    FS.WriteBuffer(TrackCount, 2);
    PPQWord := Swap16(Word(PPQ));
    FS.WriteBuffer(PPQWord, 2);

    { Track Header: MTrk }
    FS.WriteBuffer('MTrk', 4);
    TrackStart := FS.Position;
    DummySize := 0;
    FS.WriteBuffer(DummySize, 4);

    { Initial set_tempo meta-event at tick 0 }
    MicroSecs := 60000000 div InitialTempo;
    b1 := Byte(MicroSecs shr 16);
    b2 := Byte((MicroSecs shr 8) and $FF);
    b3 := Byte(MicroSecs and $FF);
    MetaByte := 0; FS.WriteBuffer(MetaByte, 1); { delta = 0 }
    MetaByte := $FF; FS.WriteBuffer(MetaByte, 1);
    MetaByte := $51; FS.WriteBuffer(MetaByte, 1); { set_tempo }
    MetaByte := 3; FS.WriteBuffer(MetaByte, 1); { length }
    FS.WriteBuffer(b1, 1); FS.WriteBuffer(b2, 1); FS.WriteBuffer(b3, 1);

    { Initial time_signature meta-event at tick 0 }
    if (InitialTsNum > 255) or (InitialTsDen > 128) then
      raise Exception.CreateFmt('MIDI time signature %d/%d is not representable',
        [InitialTsNum, InitialTsDen]);
    TsNumByte := Byte(InitialTsNum);
    logDen := 0;
    J := InitialTsDen;
    while J > 1 do
    begin
      J := J div 2;
      Inc(logDen);
    end;
    MetaByte := 0; FS.WriteBuffer(MetaByte, 1); { delta = 0 }
    MetaByte := $FF; FS.WriteBuffer(MetaByte, 1);
    MetaByte := $58; FS.WriteBuffer(MetaByte, 1); { time_signature }
    MetaByte := 4; FS.WriteBuffer(MetaByte, 1); { length }
    FS.WriteBuffer(TsNumByte, 1);
    FS.WriteBuffer(logDen, 1);
    MetaByte := 24; FS.WriteBuffer(MetaByte, 1); { clocks per metronome tick }
    MetaByte := 8; FS.WriteBuffer(MetaByte, 1); { normalized 32nd notes per quarter }

    { Write all sorted events with delta-time encoding }
    PrevTick := 0;
    for I := Low(Events) to High(Events) do
    begin
     WriteVLQ(FS, Events[I].Tick - PrevTick);
      if Events[I].IsMeta then
      begin
        MetaByte := $FF; FS.WriteBuffer(MetaByte, 1);
        if Events[I].IsTimeSignature then
        begin
          MetaByte := $58; FS.WriteBuffer(MetaByte, 1);
          MetaByte := 4; FS.WriteBuffer(MetaByte, 1);
          FS.WriteBuffer(Events[I].TsNum, 1);
          FS.WriteBuffer(Events[I].TsDenLog, 1);
          MetaByte := 24; FS.WriteBuffer(MetaByte, 1);
          MetaByte := 8; FS.WriteBuffer(MetaByte, 1);
        end
        else
        begin
          { Tempo change: FF 51 <3-byte microseconds-per-beat> }
          MicroSecs := 60000000 div Events[I].Tempo;
          MetaByte := $51; FS.WriteBuffer(MetaByte, 1);
          b1 := Byte(MicroSecs shr 16);
          b2 := Byte((MicroSecs shr 8) and $FF);
          b3 := Byte(MicroSecs and $FF);
          MetaByte := 3; FS.WriteBuffer(MetaByte, 1);
          FS.WriteBuffer(b1, 1); FS.WriteBuffer(b2, 1); FS.WriteBuffer(b3, 1);
        end;
      end
      else begin
        { Note event: note-on ($99) or note-off ($89) channel 10 }
        if Events[I].Velocity = 0 then
          MetaByte := $89
        else
          MetaByte := $99;
        FS.WriteBuffer(MetaByte, 1);
        FS.WriteBuffer(Events[I].Note, 1);
        FS.WriteBuffer(Events[I].Velocity, 1);
      end;
      PrevTick := Events[I].Tick;
    end;

    { End of Track marker }
    MetaByte := 0; FS.WriteBuffer(MetaByte, 1);
    MetaByte := $FF; FS.WriteBuffer(MetaByte, 1);
    MetaByte := $2F; FS.WriteBuffer(MetaByte, 1);
    MetaByte := 0; FS.WriteBuffer(MetaByte, 1);

    { Write track size (we stored dummy above) }
    FinalSize := Swap32(Cardinal(FS.Position - TrackStart - 4));
    FS.Position := TrackStart;
    FS.WriteBuffer(FinalSize, 4);

  finally
    FS.Free;
  end;
end;

procedure TDrumGenerator.SavePatternMidi(const APattern: TPattern; const AOutputPath: string; ATempo: Integer = 120);
{ A single pattern is exported as a one-section song, so it goes through the
  same exporter as a full song: 960 ticks per quarter note, the same note
  lengths and the same note-off handling. }
var
  PatternSong: TSong;
begin
  if not Assigned(APattern) then Exit;
  PatternSong := TSong.Create('pattern', 120);
  try
    if ATempo > 0 then
      PatternSong.Tempo := ATempo;
    PatternSong.TimeSignature.Free;
    PatternSong.TimeSignature := TTimeSignature.Create(
      APattern.TimeSignature.Numerator, APattern.TimeSignature.Denominator);
    { The section owns (and frees) its pattern, so it gets a copy. }
    PatternSong.AddSection(TSection.Create('pattern', APattern.Copy,
      Max(1, Ceil(APattern.DurationBars))));
    SaveSongMidi(PatternSong, AOutputPath);
  finally
    PatternSong.Free;
  end;
end;

{  V1 helpers  pattern generation, variations, fills. â”€â”€ }

function TDrumGenerator.GeneratePattern(const Genre, SectionName: string;
  const ADk: TDrumKit; const AStyle: string; AMeterNum, AMeterDen: Integer;
    AStrictMeter: Boolean = False): TPattern;
var
  GenrePlugin: TObject;
  Params: TGenerationParameters;
  EffectiveStyle: string;
  AvailableStyles: specialize TArray<string>;
begin
  Result := nil;

  if not Assigned(FPluginManager) then
    raise Exception.Create('Plugin manager is not initialized');

  GenrePlugin := FPluginManager.Registry.GetGenrePlugin(Genre);
  if not Assigned(GenrePlugin) then
    raise Exception.CreateFmt('Unsupported genre: %s', [Genre]);
  if not (GenrePlugin is TGenrePlugin) then
    raise Exception.CreateFmt('Invalid genre plugin registered for genre: %s', [Genre]);

  EffectiveStyle := AStyle;
  if EffectiveStyle = '' then
  begin
    AvailableStyles := FPluginManager.Registry.GetStylesForGenre(Genre);
    if Length(AvailableStyles) = 0 then
      raise Exception.CreateFmt('No styles are registered for genre: %s', [Genre]);
    EffectiveStyle := AvailableStyles[0];
  end;
  if not (GenrePlugin as TGenrePlugin).SupportsStyle(EffectiveStyle) then
    raise Exception.CreateFmt('Unsupported style "%s" for genre "%s".',
      [EffectiveStyle, (GenrePlugin as TGenrePlugin).GetGenreName]);

  if Assigned(ADk) then
    SetDrumKit(ADk);

  EffectiveStyle := LowerCase(EffectiveStyle);
  if MeterProblem(AMeterNum, AMeterDen) <> '' then
    raise Exception.CreateFmt('Time signature %d/%d: %s',
      [AMeterNum, AMeterDen, MeterProblem(AMeterNum, AMeterDen)]);
  Params := TGenerationParameters.Create(Genre, EffectiveStyle);
  try
    Params.MeterNum := AMeterNum;
    Params.MeterDen := AMeterDen;
    (GenrePlugin as TGenrePlugin).SetMeter(AMeterNum, AMeterDen);
    try
      Result := (GenrePlugin as TGenrePlugin).GeneratePattern(SectionName, Params);
    finally
      (GenrePlugin as TGenrePlugin).SetMeter(4, 4);
    end;
  finally
    Params.Free;
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
