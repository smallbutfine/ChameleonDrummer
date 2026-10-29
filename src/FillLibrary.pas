unit FillLibrary;

{$mode objfpc}{$H+}

{ A drummer's fills from config/fills/<drummer>.tab, one file per drummer,
  named like the drummer is named on the command line (--drummer weckl ->
  weckl.tab).

      [weckl_fill_short energy=0.3]          a name, and when it suits
      S .... .... .... x.x.                  drum-tab lines (see TDrumTab)
      K .... .... .... .x.x

      [weckl_fill_79 energy=0.5 7/8]         a fill for 7/8 (no meter = 4/4)
      S ..... ..... ..x.x

  energy is the bar intensity (0-1) the fill suits best: a short fill about
  0.3, a big one about 0.9. Without it the fill suits every bar. A fill is
  usually one bar; with several bars in its lines it is that long.

  A file replaces the built-in fills of that drummer. A drummer without a file
  keeps the built-in ones. A file with a mistake is ignored as a whole and the
  mistake goes to ConfigWarnings. A file for a drummer the engine does not have
  is not used (a drummer needs its plugin). }

interface

uses
  Classes, SysUtils, Generics.Collections, Pattern, Song, patterns_templates,
  ConfigFiles, TabFiles;

{ The fills of the drummer's file for a meter, or nil when it has none (or a
  broken one). The caller owns the list and the fills. }
function FileFills(const ADrummer: string;
  AMeterNum: Integer = 4; AMeterDen: Integer = 4): specialize TList<TFill>;

{ Names of all drummers that have a fill file. }
procedure FillFileDrummers(ANames: TStrings);

{ Checks the blocks of a fill file; raises with file and line on a mistake. }
procedure CheckFillBlocks(const ABlocks: TTabBlocks; const AFileName: string);

implementation

function EnergyOf(const ABlock: TTabBlock): Double;
var
  FS: TFormatSettings;
  Value: string;
begin
  Result := -1;
  if BlockKey(ABlock, 'energy', Value) then
  begin
    FS := DefaultFormatSettings;
    FS.DecimalSeparator := '.';
    Result := StrToFloatDef(Value, -1, FS);
  end;
end;

procedure CheckFillBlocks(const ABlocks: TTabBlocks; const AFileName: string);
var
  B: TTabBlock;
  Value: string;
  Energy: Double;
  FS: TFormatSettings;
  Pattern: TPattern;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  for B in ABlocks do
  begin
    if Length(B.Words) <> 1 then
      raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
        'the header needs one name, like [weckl_fill_short energy=0.3]'));
    if (Length(B.KeyNames) > 1) or
       ((Length(B.KeyNames) = 1) and (B.KeyNames[0] <> 'energy')) then
      raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
        'only energy=0.3 is allowed after the name'));
    if BlockKey(B, 'energy', Value) then
      if not TryStrToFloat(Value, Energy, FS) or (Energy < 0) or (Energy > 1) then
        raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
          Format('energy must be a number from 0 to 1, not "%s"', [Value])));
    try
      if B.MeterNum = 0 then
        Pattern := BuildDrumTabPattern(B.Words[0], B.Lines, 1.0, 1)
      else
        Pattern := BuildDrumTabPattern(B.Words[0], B.Lines, 1.0, 1, B.MeterNum, B.MeterDen);
      Pattern.Free;
    except
      on E: Exception do
        AddConfigWarning(TabMessage(AFileName, B.HeaderLine,
          Format('[%s]: %s - this fill is skipped', [B.Words[0], E.Message])));
    end;
  end;
end;

function FileFills(const ADrummer: string;
  AMeterNum, AMeterDen: Integer): specialize TList<TFill>;
var
  Path: string;
  Blocks: TTabBlocks;
  B: TTabBlock;
  Fill: TFill;
  Num, Den: Integer;
begin
  Result := nil;
  if ADrummer = '' then
    Exit;
  Path := FindConfigFile('fills', LowerCase(ADrummer) + '.tab');
  if Path = '' then
    Exit;
  try
    Blocks := ParseTabFile(Path);
    CheckFillBlocks(Blocks, Path);
  except
    on E: Exception do
    begin
      AddConfigWarning(E.Message + ' - the file is ignored');
      Exit;
    end;
  end;
  Result := specialize TList<TFill>.Create;
  for B in Blocks do
  begin
    Num := B.MeterNum;
    Den := B.MeterDen;
    if Num = 0 then
    begin
      Num := 4;
      Den := 4;
    end;
    if (Num <> AMeterNum) or (Den <> AMeterDen) then
      Continue;
    try
      Fill := TFill.Create(BuildDrumTabPattern(B.Words[0], B.Lines, 1.0, 1, Num, Den));
      Fill.Energy := EnergyOf(B);
      Result.Add(Fill);
    except
      on E: Exception do
        AddConfigWarning(TabMessage(Path, B.HeaderLine,
          Format('[%s]: %s - this fill is skipped', [B.Words[0], E.Message])));
    end;
  end;
end;

procedure FillFileDrummers(ANames: TStrings);
begin
  ListConfigNames('fills', '.tab', ANames);
end;

end.
