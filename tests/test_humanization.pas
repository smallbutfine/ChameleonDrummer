program test_humanization;

{$mode objfpc}{$H+}

uses
  SysUtils, Math, jsonparser, AdvancedHumanization, Pattern, Kit;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
  end;
end;

procedure CheckQuietHitVelocities;
var
  Source, Humanized: TPattern;
  Humanizer: TAdvancedHumanizer;
  Context: THumanizationContext;
  Kick, Snare, Crash, Tom: TDrumInstrument;
begin
  Kick := TInstrumentRegistry.Register('kick');
  Snare := TInstrumentRegistry.Register('snare_rimshot_open_hit');
  Crash := TInstrumentRegistry.Register('crash_1_hit');
  Tom := TInstrumentRegistry.Register('tom_1_open_hit');
  Source := TPattern.Create('quiet_hit_humanization_test');
  Humanizer := TAdvancedHumanizer.Create(0.015, 0.3);
  try
    Source.AddBeat(0.0, Kick, 17);
    Source.AddBeat(0.5, Snare, 28);
    Source.AddBeat(1.0, Crash, 14);
    Source.AddBeat(1.5, Tom, 8);
    Source.AddBeat(2.0, Snare, 0);
    Source.Beats[0].GhostNote := True;
    Source.Beats[1].GhostNote := True;

    Context.Genre := 'rock';
    Context.Style := 'classic';
    Context.Section := 'verse';
    Context.Complexity := 0.5;
    Context.Intensity := 1.0;
    Context.Humanization := 1.0;
    Context.Tempo := 120;

    RandSeed := 9876;
    Humanized := Humanizer.Apply(Source, Context);
    try
      Check((Humanized.Beats[0].Velocity > 0) and
        (Humanized.Beats[0].Velocity < 40),
        'humanization must not raise a quiet kick ghost note to a generic floor');
      Check((Humanized.Beats[1].Velocity > 0) and
        (Humanized.Beats[1].Velocity < 40),
        'snare velocity shaping must recognize real registry names without flattening ghosts');
      Check((Humanized.Beats[2].Velocity > 0) and
        (Humanized.Beats[2].Velocity < 40),
        'cymbal velocity shaping must preserve quiet crash levels');
      Check((Humanized.Beats[3].Velocity > 0) and
        (Humanized.Beats[3].Velocity < 40),
        'unmodified quiet instruments must retain their source velocities');
      Check(Humanized.Beats[4].Velocity = 0,
        'humanization must preserve zero-velocity source events');
      Check(Humanized.Beats[0].GhostNote and Humanized.Beats[1].GhostNote,
        'humanization must preserve ghost-note articulation');
      Check(Humanizer.GetHumanizedVelocity(12, Context) < 40,
        'standalone velocity humanization must not impose a core-drum floor');
      Check(Humanizer.GetHumanizedVelocity(0, Context) = 0,
        'standalone velocity humanization must preserve zero velocity');
    finally
      Humanized.Free;
    end;
  finally
    Humanizer.Free;
    Source.Free;
  end;
end;

var
  PatternToHumanize, Humanized: TPattern;
  Humanizer: TAdvancedHumanizer;
  Context: THumanizationContext;
  Instrument: TDrumInstrument;
  Beat, OriginalBeat: TBeat;
  I: Integer;
  PositionChanged: Boolean;
  MinSnareVelocity, MaxSnareVelocity: Integer;
begin
  Instrument := TInstrumentRegistry.Register('snare_rimshot_open_hit');
  PatternToHumanize := TPattern.Create('humanization_test');
  Humanizer := TAdvancedHumanizer.Create(0.015, 0.3);
  try
    for I := 0 to 15 do
      PatternToHumanize.AddBeat(I * 0.25 + 0.1, Instrument, 100);
    PatternToHumanize.Beats[0].GhostNote := True;
    PatternToHumanize.Beats[0].Accent := True;
    PatternToHumanize.Beats[0].Duration := 0.125;

    Context.Genre := 'rock';
    Context.Style := 'classic';
    Context.Section := 'verse';
    Context.Complexity := 0.5;
    Context.Intensity := 1.0;
    Context.Humanization := 0.0;
    Context.Tempo := 120;

    Humanized := Humanizer.Apply(PatternToHumanize, Context);
    try
      Check(Humanized <> PatternToHumanize,
        'humanization must return a copy, not mutate the source pattern');
      Check(Humanized.Beats.Count = PatternToHumanize.Beats.Count,
        'copy must retain every beat');
      for I := 0 to PatternToHumanize.Beats.Count - 1 do
      begin
        Beat := Humanized.Beats[I];
        OriginalBeat := PatternToHumanize.Beats[I];
        Check(Beat.Position = OriginalBeat.Position,
          'zero humanization must preserve timing');
        Check(Beat.Velocity = OriginalBeat.Velocity,
          'zero humanization must preserve velocity');
      end;
    finally
      Humanized.Free;
    end;

    Context.Humanization := 1.0;
    RandSeed := 12345;
    Humanized := Humanizer.Apply(PatternToHumanize, Context);
    try
      PositionChanged := False;
      MinSnareVelocity := 128;
      MaxSnareVelocity := 0;
      for I := 0 to Humanized.Beats.Count - 1 do
      begin
        Beat := Humanized.Beats[I];
        OriginalBeat := PatternToHumanize.Beats[I];
        Check((Beat.Velocity >= 88) and (Beat.Velocity <= 119),
          'humanized snare velocities must remain within the configured shaping bounds');
        MinSnareVelocity := Min(MinSnareVelocity, Beat.Velocity);
        MaxSnareVelocity := Max(MaxSnareVelocity, Beat.Velocity);
        Check(Abs(Beat.Position - OriginalBeat.Position) <= 0.015,
          'humanization timing jitter must remain within the configured bound');
        if Beat.Position <> OriginalBeat.Position then
          PositionChanged := True;
      end;
      Check(PositionChanged, 'humanization must apply timing jitter');
      Check(MaxSnareVelocity > MinSnareVelocity,
        'humanization must vary individual hit velocities');
      Check(PatternToHumanize.Beats[0].Position = 0.1,
        'humanization must not change source timing');
      Check(PatternToHumanize.Beats[0].Velocity = 100,
        'humanization must not change source velocity');
      Check(Humanized.Beats[0].GhostNote and Humanized.Beats[0].Accent,
        'humanization must preserve beat articulation metadata');
      Check(Humanized.Beats[0].Duration = 0.125,
        'humanization must preserve beat duration');
    finally
      Humanized.Free;
    end;
  finally
    Humanizer.Free;
    PatternToHumanize.Free;
  end;

  CheckQuietHitVelocities;
  WriteLn('PASS: timing/velocity humanization, zero-intensity pass-through, and source preservation');
end.
