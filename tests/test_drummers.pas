program test_drummers;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Math, Generics.Collections, jsonparser, Pattern, Kit, Song,
  DrummerPlugin, DrummerMods, patterns_templates, Hoglan, ComposerV2;

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

begin
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
  WriteLn('PASS: double-bass subdivisions, multi-bar templates, drummer dynamics, and signature fills');
end.
