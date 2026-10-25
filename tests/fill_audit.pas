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
  Kit, Pattern, Song, generation_parameters, ComposerV2;

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

var
  G: String;
  L: Integer;
begin
  WriteLn('percent of ', RUNS, ' runs with a fill, per bar index');
  for G in Genres do
  begin
    for L in Lengths do
      Audit(G, 'verse', L, 0.85);
    Audit(G, 'verse', 8, 0.50);
    Audit(G, 'outro', 8, 0.85);
  end;
end.
