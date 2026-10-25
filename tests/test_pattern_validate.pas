program test_pattern_validate;

{$mode objfpc}{$H+}

{ Checks TPattern.Validate (beats beyond the declared length, beats without an
  instrument) and that the songs the generator makes for every genre and style
  come out without such problems. Run from the project root (needs the
  mappings folder). }

uses
  SysUtils, Classes, Generics.Collections, jsonparser, Kit, time_signature, Pattern, Song,
  ComposerV2, DrumGenerator, PluginRegistry;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AText: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AText);
    Inc(Failures);
  end;
end;

var
  P: TPattern;
  W: TStringList;
  Gen: TDrumGenerator;
  S: TSong;
  St, GenreName: string;
  Songs, SongsWithWarnings, Sections, Declared: Integer;
  Sec: TSection;
  Dummy: string;
  I, J: Integer;
  Names, StyleNames: TStringArray;
begin
  W := TStringList.Create;
  try
    { Clean patterns. }
    P := TPattern.Create('clean');
    P.AddBeat(0.0, TInstrumentRegistry.Get('kick'), 100);
    P.AddBeat(3.75, TInstrumentRegistry.Get('kick'), 100);
    Check(P.Validate(W) = 0, 'no declared length: nothing to compare with');
    P.Metadata.AddOrSetValue('phrase_bars', '1');
    Check(P.Validate(W) = 0, 'a beat on the last 16th of the declared bar is fine');
    Check(W.Count = 0, 'a clean pattern adds no lines');
    P.Free;

    P := TPattern.Create('empty');
    P.Metadata.AddOrSetValue('phrase_bars', '2');
    Check(P.Validate(W) = 0, 'an empty pattern is not a validation problem');
    P.Free;

    { Beat beyond the declared length. }
    P := TPattern.Create('too long');
    P.Metadata.AddOrSetValue('phrase_bars', '1');
    P.AddBeat(0.0, TInstrumentRegistry.Get('kick'), 100);
    P.AddBeat(4.0, TInstrumentRegistry.Get('kick'), 100);
    P.AddBeat(5.5, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 100);
    Check(P.Validate(W) = 1, 'two late beats are one problem');
    Check(W.Count = 1, 'one line was added');
    Check((Pos('too long', W.Text) > 0) and (Pos('2 beat', W.Text) > 0) and
      (Pos('4' + DefaultFormatSettings.DecimalSeparator + '000', W.Text) > 0), 'the line names the pattern, the count and the first late beat: ' + W.Text);
    Check(P.Beats.Count = 3, 'the pattern is not changed');
    Check(P.Validate(nil) = 1, 'it also works without a list');
    P.Free;

    { 6/8 is 3 quarter notes per bar. }
    W.Clear;
    P := TPattern.Create('six eight');
    P.TimeSignature := TTimeSignature.Create(6, 8);
    P.Metadata.AddOrSetValue('phrase_bars', '2');
    P.AddBeat(5.9, TInstrumentRegistry.Get('kick'), 100);
    Check(P.Validate(W) = 0, 'two 6/8 bars are 6 quarters; 5.9 fits');
    P.AddBeat(6.0, TInstrumentRegistry.Get('kick'), 100);
    Check(P.Validate(W) = 1, '6.0 is the first beat past two 6/8 bars');
    P.Free;

    { Beat without instrument. }
    W.Clear;
    P := TPattern.Create('anonymous');
    P.AddBeat(0.0, nil, 100);
    Check(P.Validate(W) = 1, 'a beat without an instrument is reported');
    Check(Pos('no instrument', W.Text) > 0, 'the line says so: ' + W.Text);
    P.Free;
  finally
    W.Free;
  end;

  { Everything the generator makes, for every genre and style, 3 songs each. }
  Gen := TDrumGenerator.Create;
  Songs := 0;
  SongsWithWarnings := 0;
  Sections := 0;
  Declared := 0;
  try
    Names := Gen.PluginManager.Registry.GetAvailableGenres;
    for I := 0 to High(Names) do
    begin
      GenreName := Names[I];
      StyleNames := Gen.PluginManager.Registry.GetStylesForGenre(GenreName);
      for St in StyleNames do
        for J := 1 to 3 do
        begin
          S := Gen.CreateSong(GenreName, St, 0, nil, TDrumKit.FromKeymapName('gm'),
            '', 0.3 + 0.3 * (J - 1), 0.6, 0.0);
          Inc(Songs);
          for Sec in S.Sections do
          begin
            Inc(Sections);
            if Sec.Pattern.Metadata.TryGetValue('phrase_bars', Dummy) then
              Inc(Declared);
          end;
          if Gen.LastWarnings.Count > 0 then
          begin
            Inc(SongsWithWarnings);
            WriteLn('  ', GenreName, '/', St, ': ', Gen.LastWarnings[0]);
          end;
          S.Free;
        end;
    end;
  finally
    Gen.Free;
  end;
  Check(Songs > 0, 'some songs were generated');
  Check(Declared = Sections,
    Format('every section pattern declares its length, else the check compares nothing (%d of %d do)',
      [Declared, Sections]));
  Check(SongsWithWarnings = 0,
    Format('%d of %d generated songs have pattern warnings', [SongsWithWarnings, Songs]));

  if Failures = 0 then
    WriteLn('PASS: pattern validation (', Songs, ' generated songs, ', Sections,
      ' section patterns checked)')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
