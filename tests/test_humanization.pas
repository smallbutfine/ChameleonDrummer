program test_humanization;

{$mode objfpc}{$H+}

uses
  SysUtils, jsonparser, AdvancedHumanization, Pattern, Kit;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
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
begin
  Instrument := TInstrumentRegistry.Register('snare_1_hit');
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
      for I := 0 to Humanized.Beats.Count - 1 do
      begin
        Beat := Humanized.Beats[I];
        OriginalBeat := PatternToHumanize.Beats[I];
        Check(Beat.Velocity = 103,
          'humanization must apply the instrument-specific snare velocity curve');
        if Beat.Position <> OriginalBeat.Position then
          PositionChanged := True;
      end;
      Check(PositionChanged, 'humanization must apply timing jitter');
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

  WriteLn('PASS: timing/velocity humanization, zero-intensity pass-through, and source preservation');
end.
