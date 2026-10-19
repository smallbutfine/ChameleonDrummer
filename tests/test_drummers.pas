program test_drummers;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Math, Generics.Collections, jsonparser, Pattern, Kit, Song,
  DrummerPlugin, DrummerMods, patterns_templates, Hoglan, Halpern, ComposerV2,
  DrumGenerator, Haake, Metal, generation_parameters;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
  end;
end;

procedure CheckPedalGrid(const PatternType: string; Subdivision: Integer;
  ExpectedHits: Integer; ExpectedStep: Double);
var
  Builder: TPatternBuilder;
  Pedal: TDoubleBassPedal;
  Kwargs: specialize TDictionary<string, string>;
  PatternResult: TPattern;
  I: Integer;
begin
  Builder := TPatternBuilder.Create('pedal_grid_test');
  Pedal := TDoubleBassPedal.Create(PatternType, Subdivision);
  Kwargs := specialize TDictionary<string, string>.Create;
  try
    PatternResult := Pedal.Generate(Builder, Kwargs).Build;
    try
      Check(PatternResult.Beats.Count = ExpectedHits,
        Format('%s at subdivision %d must have %d hits',
          [PatternType, Subdivision, ExpectedHits]));
      for I := 0 to PatternResult.Beats.Count - 1 do
        if ExpectedStep > 0 then
          Check(Abs(PatternResult.Beats[I].Position - I * ExpectedStep) < 0.000001,
            Format('%s at subdivision %d must use its requested grid',
              [PatternType, Subdivision]))
        else
          Check(Abs(PatternResult.Beats[I].Position * Subdivision / 4 -
            Round(PatternResult.Beats[I].Position * Subdivision / 4)) < 0.000001,
            Format('%s must remain aligned to the %d-note grid',
              [PatternType, Subdivision]));
    finally
      PatternResult.Free;
    end;
  finally
    Kwargs.Free;
    Pedal.Free;
    Builder.Free;
  end;
end;

procedure CheckMetalExternalPattern(const Style: string; ExpectedKickCount: Integer);
var
  Plugin: TMetalGenrePlugin;
  Parameters: TGenerationParameters;
  Source, Adapted: TPattern;
  Kick, Snare, HiHat: TDrumInstrument;
  Beat: TBeat;
  KickCount, SnareCount, HiHatCount: Integer;
begin
  Kick := TInstrumentRegistry.Get('kick');
  Snare := TInstrumentRegistry.Get('snare_rimshot_open_hit');
  HiHat := TInstrumentRegistry.Get('hihat_closed_1_tip_closed_1_hit');
  Check(Assigned(Kick) and Assigned(Snare) and Assigned(HiHat),
    'metal adaptation instruments must be registered');

  Source := TPattern.Create('external_metal_source');
  Source.Metadata.Add('phrase_bars', '2');
  Source.AddBeat(0.0, Kick, 80);
  Source.AddBeat(1.0, Snare, 90);
  Source.AddBeat(2.0, HiHat, 70);
  Parameters := TGenerationParameters.Create('metal', Style, '', 0.5, 0.6, 0.0);
  Plugin := TMetalGenrePlugin.Create;
  try
    Adapted := Plugin.AdaptExternalPattern(Source, Parameters);
    try
      KickCount := 0;
      SnareCount := 0;
      HiHatCount := 0;
      for Beat in Adapted.Beats do
      begin
        if not Assigned(Beat.Instrument) then
          Continue;
        if SameText(Beat.Instrument.Name, 'kick') then
          Inc(KickCount)
        else if SameText(Beat.Instrument.Name, Snare.Name) then
          Inc(SnareCount)
        else if SameText(Beat.Instrument.Name, HiHat.Name) then
          Inc(HiHatCount);
      end;
      Check(KickCount = ExpectedKickCount,
        Format('%s adaptation must produce %d kick hits over two bars, got %d',
          [Style, ExpectedKickCount, KickCount]));
      Check((SnareCount = 1) and (HiHatCount = 1),
        Format('%s adaptation must preserve source snare and hi-hat hits', [Style]));
      Check((Source.Beats.Count = 3) and
        (Abs(Source.Beats[0].Position) < 0.000001),
        Format('%s adaptation must leave its source pattern unchanged', [Style]));
    finally
      Adapted.Free;
    end;
  finally
    Plugin.Free;
    Parameters.Free;
    Source.Free;
  end;
end;

procedure CheckDrummerContextBehavior;
var
  Source, Modified: TPattern;
  Kick, Snare: TDrumInstrument;
  Beat: TBeat;
  Haake: THaakePlugin;
  Halpern: THalpernPlugin;
  KickCount, GhostCount: Integer;
begin
  Kick := TInstrumentRegistry.Get('kick');
  Snare := TInstrumentRegistry.Get('snare_rimshot_open_hit');
  Source := TPattern.Create('drummer_context_test');
  Source.Metadata.Add('phrase_bars', '2');
  Source.AddBeat(0.0, Kick, 90);
  Source.AddBeat(1.0, Snare, 95);
  Haake := THaakePlugin.Create;
  Halpern := THalpernPlugin.Create;
  try
    Modified := Haake.ApplyStyleForContext(Source, 'metal', 'heavy', 120);
    try
      KickCount := 0;
      for Beat in Modified.Beats do
        if Assigned(Beat.Instrument) and SameText(Beat.Instrument.Name, 'kick') then
          Inc(KickCount);
      Check(KickCount = 32,
        'Haake metal heavy context must add continuous 16th-note double bass');
      Check(Source.Beats.Count = 2,
        'Haake context styling must not mutate the source pattern');
    finally
      Modified.Free;
    end;

    Modified := Haake.ApplyStyleForContext(Source, 'metal', 'doom', 70);
    try
      KickCount := 0;
      for Beat in Modified.Beats do
        if Assigned(Beat.Instrument) and SameText(Beat.Instrument.Name, 'kick') then
          Inc(KickCount);
      Check(KickCount = 1,
        'Haake metal doom context must preserve sparse source kicks');
    finally
      Modified.Free;
    end;

    Modified := Haake.ApplyStyleForContext(Source, 'rock', 'classic', 120);
    try
      KickCount := 0;
      for Beat in Modified.Beats do
        if Assigned(Beat.Instrument) and SameText(Beat.Instrument.Name, 'kick') then
          Inc(KickCount);
      Check(KickCount = 1,
        'Haake must not inject metal double bass into non-metal hybrids');
    finally
      Modified.Free;
    end;

    Modified := Halpern.ApplyStyleForContext(Source, 'metal', 'death', 180);
    try
      KickCount := 0;
      GhostCount := 0;
      for Beat in Modified.Beats do
      begin
        if Assigned(Beat.Instrument) and SameText(Beat.Instrument.Name, 'kick') then
          Inc(KickCount);
        if Beat.GhostNote then
          Inc(GhostCount);
      end;
      Check((KickCount = 1) and (GhostCount > 0),
        'Halpern metal hybrid must retain its source groove and ghost-note character');
    finally
      Modified.Free;
    end;
  finally
    Halpern.Free;
    Haake.Free;
    Source.Free;
  end;
end;

function SongsHaveSamePatterns(const LeftSong, RightSong: TSong): Boolean;
var
  SectionIndex, BeatIndex: Integer;
  LeftSection, RightSection: TSection;
  LeftBeat, RightBeat: TBeat;
  LeftInstrument, RightInstrument: string;
begin
  Result := False;
  if not Assigned(LeftSong) or not Assigned(RightSong) or
     (LeftSong.Sections.Count <> RightSong.Sections.Count) then
    Exit;

  for SectionIndex := 0 to LeftSong.Sections.Count - 1 do
  begin
    LeftSection := LeftSong.Sections[SectionIndex];
    RightSection := RightSong.Sections[SectionIndex];
    if not Assigned(LeftSection.Pattern) or not Assigned(RightSection.Pattern) or
       (LeftSection.Pattern.Beats.Count <> RightSection.Pattern.Beats.Count) then
      Exit;
    for BeatIndex := 0 to LeftSection.Pattern.Beats.Count - 1 do
    begin
      LeftBeat := LeftSection.Pattern.Beats[BeatIndex];
      RightBeat := RightSection.Pattern.Beats[BeatIndex];
      LeftInstrument := '';
      RightInstrument := '';
      if Assigned(LeftBeat.Instrument) then
        LeftInstrument := LeftBeat.Instrument.Name;
      if Assigned(RightBeat.Instrument) then
        RightInstrument := RightBeat.Instrument.Name;
      if (Abs(LeftBeat.Position - RightBeat.Position) > 0.000001) or
         (LeftBeat.Velocity <> RightBeat.Velocity) or
         not SameText(LeftInstrument, RightInstrument) or
         (LeftBeat.GhostNote <> RightBeat.GhostNote) or
         (LeftBeat.Accent <> RightBeat.Accent) then
        Exit;
    end;
  end;
  Result := True;
end;

procedure CheckSeededComposition;
var
  Generator: TDrumGenerator;
  FirstComposer, SecondComposer: TComposerV2;
  FirstSong, SecondSong: TSong;
  Structure: TSongStructureArray;
begin
  SetLength(Structure, 1);
  Structure[0].Name := 'verse';
  Structure[0].Bars := 4;
  Generator := TDrumGenerator.Create;
  FirstComposer := nil;
  SecondComposer := nil;
  FirstSong := nil;
  SecondSong := nil;
  try
    FirstComposer := TComposerV2.Create(Generator.PluginManager, 424242);
    FirstSong := FirstComposer.CreateSong(
      'metal', 'heavy', 140, Structure, 'haake', 0.6, 0.7, 0.5);
    SecondComposer := TComposerV2.Create(Generator.PluginManager, 424242);
    SecondSong := SecondComposer.CreateSong(
      'metal', 'heavy', 140, Structure, 'haake', 0.6, 0.7, 0.5);
    Check(SongsHaveSamePatterns(FirstSong, SecondSong),
      'the same composer seed must reproduce identical patterns and humanization');
  finally
    SecondSong.Free;
    FirstSong.Free;
    SecondComposer.Free;
    FirstComposer.Free;
    Generator.Free;
  end;
end;

procedure CheckComposedMetalKickDensity(const Style: string;
  MinimumKickCount, MaximumKickPerBar: Integer);
var
  Generator: TDrumGenerator;
  GeneratedSong: TSong;
  Structure: TSongStructureArray;
  Kick: TDrumInstrument;
  Beat: TBeat;
  KicksPerBar: array[0..3] of Integer;
  BarIndex, TotalKicks: Integer;
begin
  FillChar(KicksPerBar, SizeOf(KicksPerBar), 0);
  SetLength(Structure, 1);
  Structure[0].Name := 'verse';
  Structure[0].Bars := 4;
  Generator := TDrumGenerator.Create;
  try
    RandSeed := 424242;
    GeneratedSong := Generator.CreateSong(
      'metal', Style, GetDefaultBpm('metal', Style), Structure, nil,
      'haake', 0.5, 0.6, 0.0);
    try
      Kick := TInstrumentRegistry.Get('kick');
      TotalKicks := 0;
      for Beat in GeneratedSong.Sections[0].Pattern.Beats do
        if Assigned(Beat.Instrument) and (Beat.Instrument = Kick) then
        begin
          BarIndex := Trunc(Beat.Position / 4.0);
          if (BarIndex >= 0) and (BarIndex < Length(KicksPerBar)) then
          begin
            Inc(KicksPerBar[BarIndex]);
            Inc(TotalKicks);
          end;
        end;
      Check(TotalKicks >= MinimumKickCount,
        Format('composed metal %s with Haake must have at least %d kick hits, got %d',
          [Style, MinimumKickCount, TotalKicks]));
      if MaximumKickPerBar > 0 then
        for BarIndex := Low(KicksPerBar) to High(KicksPerBar) do
          Check(KicksPerBar[BarIndex] <= MaximumKickPerBar,
            Format('composed metal %s must stay at or below %d kicks per bar',
              [Style, MaximumKickPerBar]));
    finally
      GeneratedSong.Free;
    end;
  finally
    Generator.Free;
  end;
end;

procedure CheckRepeatedBarsAndDuplicateKicks;
var
  Composer: TTemplateComposer;
  PatternResult: TPattern;
  Beat: TBeat;
  KickCount: Integer;
begin
  Composer := TTemplateComposer.Create('two_bar_double_bass_test');
  Composer.Add(TBasicGroove.Create(nil, nil, 0.5));
  Composer.Add(TDoubleBassPedal.Create('continuous', 8));
  try
    PatternResult := Composer.Build(2, 0.5);
    try
      KickCount := 0;
      for Beat in PatternResult.Beats do
        if Assigned(Beat.Instrument) and SameText(Beat.Instrument.Name, 'kick') then
          Inc(KickCount);
      Check(KickCount = 16,
        'overlapping basic-groove and pedal kicks must be consolidated per bar');
      Check(PatternResult.DurationBars = 2,
        'template composer must emit both requested bars');
    finally
      PatternResult.Free;
    end;
  finally
    Composer.Free;
  end;
end;

procedure CheckFillScheduling;
var
  BasePattern, MultiBarFillPattern: TPattern;
  Section: TSection;
  Fill: TFill;
begin
  BasePattern := TPattern.Create('fill_schedule_base');
  MultiBarFillPattern := TPattern.Create('two_bar_fill');
  MultiBarFillPattern.AddBeat(0.0,
    TInstrumentRegistry.Get('tom_4_open_hit'), 90);
  MultiBarFillPattern.Metadata.Add('phrase_bars', '2');
  Section := TSection.Create('fill_schedule_test', BasePattern, 4);
  Section.SetFillBars([2]);
  Fill := TFill.Create(MultiBarFillPattern);
  Section.Fills.Add(Fill);
  try
    Check(Section.ShouldAddFill(0, 1.0) = nil,
      'multi-bar fill cannot be placed before its phrase fits');
    Check(Section.ShouldAddFill(1, 1.0) = nil,
      'fill picker must not place a fill on an unscheduled bar');
    Check(Section.ShouldAddFill(2, 1.0) = Fill,
      'scheduled fill must be selectable once its phrase fits');
    Check(Section.ShouldAddFill(3, 1.0) = nil,
      'scheduled fill must not be selected on another bar');
  finally
    Section.Free;
  end;
end;

procedure CheckGrooveOffsetUnits;
var
  GrooveEngine: TGrooveEngine;
  BonhamOffset, HoglanOffset: Single;
begin
  GrooveEngine := TGrooveEngine.Create;
  try
    BonhamOffset := GrooveEngine.GetBarOffsetMs(
      0, 120, 0.5, 'verse', 'rock', 'bonham');
    HoglanOffset := GrooveEngine.GetBarOffsetMs(
      0, 120, 0.5, 'verse', 'metal', 'hoglan');
    Check((Abs(BonhamOffset - 12.5) < 0.001) and
      (Abs(HoglanOffset + 3.5) < 0.001),
      'drummer groove profiles must resolve to bounded millisecond offsets');
    Check(GrooveEngine.GetBarOffsetMs(
      0, 0, 0.5, 'verse', 'metal', 'hoglan') = 0,
      'invalid tempo must not produce an invalid groove offset');
  finally
    GrooveEngine.Free;
  end;
end;

procedure CheckIntensityAndDynamicsModulation;
var
  Selector: TBarSelector;
  Source, Baseline, HighIntensity, LowIntensity, LowComplexity,
    HighComplexity, HighDynamics, MaximumParameters: TPattern;
  PreviousBars: specialize TList<TPattern>;
  Kick, Snare: TDrumInstrument;
begin
  Kick := TInstrumentRegistry.Get('kick');
  Snare := TInstrumentRegistry.Get('snare_rimshot_open_hit');
  Check(Assigned(Kick) and Assigned(Snare),
    'kick and snare instruments must be registered for parameter modulation');
  Source := TPattern.Create('parameter_modulation_test');
  Source.AddBeat(0.0, Kick, 70);
  Source.AddBeat(1.0, Snare, 24);
  Source.Beats[1].GhostNote := True;
  Source.Beats[1].Accent := True;
  Source.Beats[1].Duration := 0.125;
  Source.AddBeat(2.0, Kick, 0);
  Selector := TBarSelector.Create;
  PreviousBars := specialize TList<TPattern>.Create;
  try
    Baseline := Selector.GenerateForBar(
      Source, 0, 4, 0.5, 0.5, 0.6, '', PreviousBars);
    try
      Check((Baseline.Beats[0].Velocity = 70) and
        (Baseline.Beats[1].Velocity = 24),
        'default dynamics and midpoint intensity must preserve source velocities');
      Check(Baseline.Beats[1].GhostNote and Baseline.Beats[1].Accent and
        (Baseline.Beats[1].Duration = 0.125),
        'bar modulation must preserve ghost, accent, and duration metadata');
      Check(Baseline.Beats[2].Velocity = 0,
        'bar modulation must preserve silent source hits');
    finally
      Baseline.Free;
    end;

    HighIntensity := Selector.GenerateForBar(
      Source, 3, 4, 0.9, 0.5, 0.6, '', PreviousBars);
    LowIntensity := Selector.GenerateForBar(
      Source, 0, 4, 0.0, 1.0, 0.6, '', PreviousBars);
    LowComplexity := Selector.GenerateForBar(
      Source, 3, 4, 0.9, 0.0, 0.6, '', PreviousBars);
    HighComplexity := Selector.GenerateForBar(
      Source, 3, 4, 0.9, 1.0, 0.6, '', PreviousBars);
    HighDynamics := Selector.GenerateForBar(
      Source, 0, 4, 0.5, 0.5, 1.0, '', PreviousBars);
    MaximumParameters := Selector.GenerateForBar(
      Source, 3, 4, 1.0, 1.0, 1.0, '', PreviousBars);
    try
      Check((HighIntensity.Beats[0].Velocity = 78) and
        (HighIntensity.Beats[1].Velocity = 32),
        'higher intensity must lift velocities without flattening ghost notes');
      Check((LowComplexity.Beats[0].Velocity = 74) and
        (HighComplexity.Beats[0].Velocity = 82),
        'complexity must scale intensity-driven velocity variation');
      Check((LowIntensity.Beats[0].Velocity = 55) and
        (LowIntensity.Beats[1].Velocity = 9),
        'minimum intensity must reduce velocity without imposing a loudness floor');
      Check((HighDynamics.Beats[0].Velocity = 117) and
        (HighDynamics.Beats[1].Velocity = 40),
        'dynamics must scale all hits relative to the default dynamics level');
      Check((MaximumParameters.Beats[0].Velocity = 127) and
        (MaximumParameters.Beats[1].Velocity = 65),
        'maximum parameter values must remain within the MIDI velocity range');
      Check(HighIntensity.Beats[1].GhostNote and HighIntensity.Beats[1].Accent,
        'complexity and intensity must preserve beat articulation metadata');
    finally
      HighIntensity.Free;
      LowIntensity.Free;
      LowComplexity.Free;
      HighComplexity.Free;
      HighDynamics.Free;
      MaximumParameters.Free;
    end;
    Check((Source.Beats[0].Velocity = 70) and (Source.Beats[1].Velocity = 24),
      'parameter modulation must not mutate the source pattern');
  finally
    PreviousBars.Free;
    Selector.Free;
    Source.Free;
  end;
end;

procedure CheckDrummerDynamicsAndFills;
var
  Source, Precise: TPattern;
  FillPattern: TPattern;
  Plugin: THoglanPlugin;
  Fills: specialize TList<TFill>;
  Fill: TFill;
begin
  Source := TPattern.Create('dynamics_test');
  Source.AddBeat(0.13, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 28);
  try
    Precise := TMechanicalPrecision.Create.Apply(Source, 1.0);
    try
      Check(Precise.Beats[0].Velocity = 28,
        'mechanical precision must retain the source accent velocity');
      Check(Abs(Precise.Beats[0].Position - 0.125) < 0.000001,
        'mechanical precision must quantize timing to its 32nd grid');
    finally
      Precise.Free;
    end;
  finally
    Source.Free;
  end;

  FillPattern := CreateSignatureFillPattern('tom_fill');
  try
    Check(FillPattern.Beats.Count > 0,
      'signature tom fill patterns must contain playable drum events');
  finally
    FillPattern.Free;
  end;

  Plugin := THoglanPlugin.Create;
  try
    Fills := Plugin.GetSignatureFills;
    try
      Check(Fills.Count > 0, 'drummer must provide its signature fill choices');
      for Fill in Fills do
        Check(Assigned(Fill.Pattern) and (Fill.Pattern.Beats.Count > 0),
          'drummer signature fills must not be empty placeholders');
    finally
      for Fill in Fills do
        Fill.Free;
      Fills.Free;
    end;
  finally
    Plugin.Free;
  end;
end;

procedure CheckGhostNotesOnGeneratedSnareVariants;
var
  Source, Modified: TPattern;
  Beat: TBeat;
  OpenSnare, RimshotSnare: TDrumInstrument;
  GhostCount: Integer;
begin
  OpenSnare := TInstrumentRegistry.Get('snare_open_hit_open_lateral_hit');
  RimshotSnare := TInstrumentRegistry.Get('snare_rimshot_open_hit');
  Check(Assigned(OpenSnare) and Assigned(RimshotSnare),
    'canonical generated snare instruments must be registered');

  Source := TPattern.Create('ghost_note_snare_variants');
  Source.AddBeat(0.0, OpenSnare, 90);
  Source.AddBeat(1.0, RimshotSnare, 95);
  try
    Modified := ApplyAndFreeModifier(TGhostNoteLayer.Create(0.5), Source, 0.8);
    try
      GhostCount := 0;
      for Beat in Modified.Beats do
        if Beat.GhostNote then
          Inc(GhostCount);
      Check((Modified.Beats.Count = 4) and (GhostCount = 2),
        'ghost-note layer must handle both generated snare variants once');
      Check((Source.Beats.Count = 2) and
        not Source.Beats[0].GhostNote and not Source.Beats[1].GhostNote,
        'ghost-note layer must not mutate its source pattern');
    finally
      Modified.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure CheckBehindBeatTempoConversion;
var
  Source, AtSlowTempo, AtFastTempo: TPattern;
  Kick: TDrumInstrument;
  Modifier: TBehindBeatTiming;
  SlowDelay, FastDelay: Double;
  Plugin: THalpernPlugin;
  PluginResult: TPattern;
begin
  Kick := TInstrumentRegistry.Get('kick');
  Check(Assigned(Kick), 'kick must be registered for behind-beat testing');
  Source := TPattern.Create('behind_beat_tempo_test');
  Source.AddBeat(0.0, Kick, 90);
  Modifier := TBehindBeatTiming.Create(15.0);
  try
    AtSlowTempo := Modifier.ApplyAtTempo(Source, 1.0, 60);
    try
      AtFastTempo := Modifier.ApplyAtTempo(Source, 1.0, 120);
      try
        SlowDelay := AtSlowTempo.Beats[0].Position;
        FastDelay := AtFastTempo.Beats[0].Position;
        Check((SlowDelay >= 0.0075) and (SlowDelay <= 0.015),
          'behind-beat timing must convert milliseconds to quarter-note position at 60 BPM');
        Check((FastDelay >= 0.015) and (FastDelay <= 0.03),
          'behind-beat timing must convert milliseconds to quarter-note position at 120 BPM');
      finally
        AtFastTempo.Free;
      end;
    finally
      AtSlowTempo.Free;
    end;
  finally
    Modifier.Free;
    Source.Free;
  end;

  Plugin := THalpernPlugin.Create;
  Source := TPattern.Create('halpern_tempo_test');
  Source.AddBeat(0.0, Kick, 90);
  try
    PluginResult := Plugin.ApplyStyleAtTempo(Source, 120);
    try
      Check((PluginResult.Beats[0].Position >= 0.006) and
        (PluginResult.Beats[0].Position <= 0.012),
        'Halpern drummer must apply its configured timing delay in beat units');
    finally
      PluginResult.Free;
    end;
  finally
    Source.Free;
    Plugin.Free;
  end;
end;

procedure CheckTripletVocabulary;
var
  Source, Modified: TPattern;
  Kick: TDrumInstrument;
begin
  Kick := TInstrumentRegistry.Get('kick');
  Check(Assigned(Kick), 'kick must be registered for triplet testing');
  Source := TPattern.Create('triplet_vocabulary_test');
  Source.AddBeat(0.0, Kick, 90);
  Source.AddBeat(0.5, Kick, 80);
  Source.AddBeat(1.0, Kick, 85);
  Source.AddBeat(1.5, Kick, 75);
  try
    Modified := ApplyAndFreeModifier(TTripletVocabulary.Create(1.0),
      Source, 1.0);
    try
      Check(Modified.Beats.Count = Source.Beats.Count,
        'triplet feel must reposition existing hits instead of adding phantom instruments');
      Check((Abs(Modified.Beats[0].Position - 0.0) < 0.000001) and
        (Abs(Modified.Beats[1].Position - (2.0 / 3.0)) < 0.000001) and
        (Abs(Modified.Beats[2].Position - 1.0) < 0.000001) and
        (Abs(Modified.Beats[3].Position - (5.0 / 3.0)) < 0.000001),
        'triplet feel must move eighth-note offbeats onto the triplet grid');
      Check((Source.Beats[1].Position = 0.5) and
        (Source.Beats[3].Position = 1.5),
        'triplet feel must leave the source pattern unchanged');
    finally
      Modified.Free;
    end;
  finally
    Source.Free;
  end;
end;

begin
  CheckMetalExternalPattern('heavy', 16);
  CheckMetalExternalPattern('death', 32);
  CheckMetalExternalPattern('power', 24);
  CheckMetalExternalPattern('progressive', 16);
  CheckMetalExternalPattern('thrash', 32);
  CheckMetalExternalPattern('doom', 1);
  CheckMetalExternalPattern('breakdown', 16);
  CheckDrummerContextBehavior;
  CheckSeededComposition;
  CheckComposedMetalKickDensity('heavy', 64, 0);
  CheckComposedMetalKickDensity('death', 64, 0);
  CheckComposedMetalKickDensity('power', 48, 0);
  CheckComposedMetalKickDensity('progressive', 64, 0);
  CheckComposedMetalKickDensity('thrash', 64, 0);
  CheckComposedMetalKickDensity('doom', 0, 8);
  CheckComposedMetalKickDensity('breakdown', 32, 0);
  CheckPedalGrid('continuous', 8, 8, 0.5);
  CheckPedalGrid('continuous', 16, 16, 0.25);
  CheckPedalGrid('gallop', 16, 12, 0);
  CheckPedalGrid('burst', 16, 4, 0.25);
  CheckPedalGrid('burst', 32, 8, 0.125);
  CheckRepeatedBarsAndDuplicateKicks;
  CheckFillScheduling;
  CheckGrooveOffsetUnits;
  CheckIntensityAndDynamicsModulation;
  CheckDrummerDynamicsAndFills;
  CheckGhostNotesOnGeneratedSnareVariants;
  CheckBehindBeatTempoConversion;
  CheckTripletVocabulary;
  WriteLn('PASS: double-bass subdivisions, multi-bar templates, drummer dynamics, and signature fills');
end.
