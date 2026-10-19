program test_drummers;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Math, Generics.Collections, jsonparser, Pattern, Kit, Song,
  DrummerPlugin, DrummerMods, patterns_templates, Hoglan;

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

begin
  CheckPedalGrid('continuous', 8, 8, 0.5);
  CheckPedalGrid('continuous', 16, 16, 0.25);
  CheckPedalGrid('gallop', 16, 12, 0);
  CheckPedalGrid('burst', 16, 4, 0.25);
  CheckPedalGrid('burst', 32, 8, 0.125);
  CheckRepeatedBarsAndDuplicateKicks;
  CheckDrummerDynamicsAndFills;
  WriteLn('PASS: double-bass subdivisions, multi-bar templates, drummer dynamics, and signature fills');
end.
