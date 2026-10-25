program fill_audit;

{$mode objfpc}{$H+}

{ Reports where TFillPicker places fills.

  For every genre and a set of section lengths it runs the picker many times
  with different random seeds and prints, per bar, how often a fill was
  placed. It also counts the musically wrong cases:
    adjacent  - two fills in consecutive bars
    bar0      - a fill in the first bar of a section longer than one bar
    short     - a fill in a section of one bar
  Run from the project root (needs the mappings folder). }

uses
  SysUtils, Classes, Generics.Collections, Math, jsonparser,
  Kit, Pattern, Song, generation_parameters, ComposerV2,
  LimbConstraints, DrummerPlugin, PluginRegistry, DrumGenerator;

const
  RUNS = 400;
  Genres: array[0..4] of String = ('rock', 'metal', 'jazz', 'funk', 'electronic');
  Lengths: array[0..5] of Integer = (1, 2, 4, 8, 9, 16);

procedure Audit(const AGenre, ASection: String; ABars: Integer; AIntensity: Double);
var
  Picker: TFillPicker;
  Params: TGenerationParameters;
  Fills: specialize TList<TFill>;
  Indices: specialize TArray<Integer>;
  Values: specialize TArray<Double>;
  Hits: array of Integer;
  Run, I, J, Adjacent, Bar0, Short: Integer;
  Line: String;
begin
  SetLength(Hits, ABars);
  SetLength(Values, ABars);
  for I := 0 to ABars - 1 do
    Values[I] := AIntensity;
  Adjacent := 0; Bar0 := 0; Short := 0;
  Picker := TFillPicker.Create;
  Params := TGenerationParameters.Create(AGenre, 'x');
  try
    for Run := 1 to RUNS do
    begin
      RandSeed := Run * 7919;
      Indices := nil;
      Fills := Picker.PickFillsForSection(AGenre, Params, ABars, ASection, Indices, Values);
      for I := 0 to Length(Indices) - 1 do
      begin
        Inc(Hits[Indices[I]]);
        if (I > 0) and (Indices[I] - Indices[I - 1] = 1) then
          Inc(Adjacent);
      end;
      for I := 0 to Length(Indices) - 1 do
      begin
        if (Indices[I] = 0) and (ABars > 1) then Inc(Bar0);
        if ABars = 1 then Inc(Short);
      end;
      for J := Fills.Count - 1 downto 0 do
        Fills[J].Free;
      Fills.Free;
    end;
  finally
    Params.Free;
    Picker.Free;
  end;
  Line := '';
  for I := 0 to ABars - 1 do
    Line := Line + Format('%3d ', [Round(100.0 * Hits[I] / RUNS)]);
  WriteLn(Format('%-10s %-7s i=%.2f bars=%2d  adjacent=%-4d bar0=%-4d short=%-4d | %s',
    [AGenre, ASection, AIntensity, ABars, Adjacent, Bar0, Short, Line]));
end;

{ Every fill a drummer plugin offers must be one bar, non-empty and playable
  by one drummer. }
procedure AuditVocabulary;
var
  Generator: TDrumGenerator;
  Names: TStringArray;
  D: String;
  Plugin: TObject;
  Fills: specialize TList<TFill>;
  Fill: TFill;
  J, Bad, Total, Drummers, Short: Integer;
  Engine: TLimbConstraintEngine;
  V: specialize TList<TLimbViolation>;
  MaxPos: Double;
  B: TBeat;
begin
  Generator := TDrumGenerator.Create;
  Engine := TLimbConstraintEngine.Create;
  Bad := 0; Total := 0; Drummers := 0; Short := 0;
  Names := Generator.PluginManager.Registry.GetAvailableDrummers;
  for D in Names do
  begin
    Plugin := Generator.PluginManager.Registry.GetDrummerPlugin(D);
    if not (Plugin is TDrummerPlugin) then
      Continue;
    Inc(Drummers);
    Fills := (Plugin as TDrummerPlugin).GetSignatureFills;
    if Fills.Count < 3 then
    begin
      WriteLn('FEW fills: ', D, ' has ', Fills.Count);
      Inc(Short);
    end;
    for Fill in Fills do
    begin
      Inc(Total);
      MaxPos := 0;
      for B in Fill.Pattern.Beats do
        if B.Position > MaxPos then MaxPos := B.Position;
      V := Engine.FindViolations(Fill.Pattern);
      if (V.Count > 0) or (Fill.Pattern.Beats.Count = 0) or (MaxPos >= 4.0) or
         (Fill.Pattern.DurationBars > 1.0) then
      begin
        WriteLn(Format('BAD fill %s %s: beats=%d violations=%d maxpos=%.2f',
          [D, Fill.Pattern.Name, Fill.Pattern.Beats.Count, V.Count, MaxPos]));
        for J := 0 to V.Count - 1 do
          WriteLn('    ', V[J].Description);
        Inc(Bad);
      end;
      for J := 0 to V.Count - 1 do V[J].Free;
      V.Free;
    end;
    for J := Fills.Count - 1 downto 0 do
      Fills[J].Free;
    Fills.Free;
  end;
  Engine.Free;
  Generator.Free;
  WriteLn(Format('drummer vocabulary: %d drummers, %d fills checked, %d bad, %d drummers with fewer than 3 fills',
    [Drummers, Total, Bad, Short]));
end;

var
  G: String;
  L: Integer;
begin
  AuditVocabulary;
  WriteLn('percent of ', RUNS, ' runs with a fill, per bar index');
  for G in Genres do
  begin
    for L in Lengths do
      Audit(G, 'verse', L, 0.85);
    Audit(G, 'verse', 8, 0.50);
    Audit(G, 'outro', 8, 0.85);
  end;
end.
