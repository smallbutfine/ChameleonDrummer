program export_grooves;

{$mode objfpc}{$H+}

{ Writes the compiled-in grooves as config/grooves/<genre>.tab, the format
  GrooveLibrary reads. Run from the project root:

      export_grooves [output folder]        (default: config\grooves)

  The files it writes play exactly what the engine plays without them. After
  that the .tab files are the place to edit and extend. }

uses
  SysUtils, Classes, jsonparser, patterns_templates,
  MetalGrooves, RockGrooves, JazzGrooves, FunkGrooves, ElectronicGrooves;

type
  TLinesFn = function(const AStyle, AKind: string; AVariant: Integer): TTabLines;

const
  Kinds: array[0..2] of string = ('verse', 'chorus', 'bridge');

var
  OutDir: string;

function Num(X: Double): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.00', X, FS);
end;

procedure WriteGenre(const AGenre, ADescription: string;
  const AStyles: array of string; AFn: TLinesFn);
var
  Out: TStringList;
  Style, Kind, L: string;
  V, I: Integer;
  Lo, Hi: Double;
  Lines: TTabLines;
begin
  Out := TStringList.Create;
  try
    Out.Add('# ' + ADescription);
    Out.Add('#');
    Out.Add('# One block per groove:  [style kind intensity=low-high]');
    Out.Add('#   kind       verse, chorus or bridge (intro/outro play verse, solo/breakdown bridge)');
    Out.Add('#   intensity  the bar intensities (0-1) this groove suits; neighbours overlap on purpose');
    Out.Add('# Then one line per instrument:  <instrument>[@min complexity] <bar 1> | <bar 2> ...');
    Out.Add('#   instruments  K S RS SS H HO HP R RB C C2 CH SP T1 T2 T3 T4');
    Out.Add('#   steps        . rest   x hit   X accent   o soft   g ghost');
    Out.Add('#   a bar has 4, 8, 12, 16, 24 or 32 steps; spaces inside a bar are ignored');
    Out.Add('# Add a block to add a groove; the blocks of a style and kind are its variants,');
    Out.Add('# lightest first. A new style name makes a new style of this genre.');
    Out.Add('# Playable by one drummer: snare, crash and toms 1/3 right hand; hi-hat, ride,');
    Out.Add('# tom 2 left hand; kick and hi-hat pedal feet; at most 3 hits on one step.');
    for Style in AStyles do
      for Kind in Kinds do
        for V := 0 to 2 do
        begin
          GrooveBand(Kind, V, Lo, Hi);
          Lines := AFn(Style, Kind, V);
          Out.Add('');
          Out.Add(Format('[%s %s intensity=%s-%s]', [Style, Kind, Num(Lo), Num(Hi)]));
          for I := 0 to High(Lines) do
          begin
            L := Lines[I];
            Out.Add(L);
          end;
        end;
    Out.SaveToFile(IncludeTrailingPathDelimiter(OutDir) + AGenre + '.tab');
    WriteLn('wrote ', AGenre, '.tab  (', Length(AStyles), ' styles)');
  finally
    Out.Free;
  end;
end;

begin
  if ParamCount >= 1 then
    OutDir := ParamStr(1)
  else
    OutDir := 'config' + PathDelim + 'grooves';
  ForceDirectories(OutDir);

  WriteGenre('metal', 'Metal grooves.',
    ['heavy', 'death', 'power', 'progressive', 'thrash', 'doom', 'breakdown'],
    @MetalGrooveLines);
  WriteGenre('rock', 'Rock grooves.',
    ['classic', 'blues', 'alternative', 'progressive', 'punk', 'hard', 'pop'],
    @RockGrooveLines);
  WriteGenre('jazz', 'Jazz grooves.',
    ['swing', 'bebop', 'fusion', 'latin', 'ballad', 'hard_bop', 'contemporary'],
    @JazzGrooveLines);
  WriteGenre('funk', 'Funk grooves.',
    ['classic', 'pfunk', 'shuffle', 'new_orleans', 'fusion', 'minimal', 'heavy'],
    @FunkGrooveLines);
  WriteGenre('electronic', 'Electronic grooves (the rimshot stands in for the clap).',
    ['house', 'techno', 'drum_and_bass', 'dubstep'],
    @ElectronicGrooveLines);
end.
