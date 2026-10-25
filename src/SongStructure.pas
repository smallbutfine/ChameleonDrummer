unit SongStructure;

{$mode objfpc}{$H+}

{ Song structure given by the user: parsing of the --section command-line
  syntax into the section list the composer works from.

      --section name:bars          a section of that many bars
      --section name:bars@tempo    the same, at its own tempo in BPM

  The name is any identifier (letters, digits, '_' and '-', starting with a
  letter). The composer treats these names specially: intro, verse, pre_chorus,
  chorus, bridge, breakdown, solo, outro. Any other name plays like a verse. }

interface

uses
  SysUtils, ComposerV2;

const
  MAX_SECTION_BARS = 256;
  MIN_SECTION_TEMPO = 60;
  MAX_SECTION_TEMPO = 300;

{ Parses one --section value. Raises an Exception that names the offending
  text and shows the expected syntax when the value is not valid. }
function ParseSectionSpec(const ASpec: string): TSectionDef;

{ The structure as one readable line, e.g. "intro:4 verse:8@120 chorus:8". }
function DescribeStructure(const AStructure: array of TSectionDef): string;

implementation

const
  SYNTAX_HELP = 'expected name:bars or name:bars@tempo, e.g. verse:8 or chorus:8@140';

function IsNameChar(C: Char; AFirst: Boolean): Boolean;
begin
  if AFirst then
    Result := C in ['a'..'z', 'A'..'Z']
  else
    Result := C in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-'];
end;

function ParseSectionSpec(const ASpec: string): TSectionDef;
var
  Text, NamePart, BarsPart, TempoPart: string;
  ColonPos, AtPos, I: Integer;
begin
  Text := Trim(ASpec);
  Result.Name := '';
  Result.Bars := 0;
  Result.Tempo := 0;

  ColonPos := Pos(':', Text);
  if ColonPos < 2 then
    raise Exception.CreateFmt('Invalid --section "%s": %s', [ASpec, SYNTAX_HELP]);

  NamePart := Copy(Text, 1, ColonPos - 1);
  BarsPart := Copy(Text, ColonPos + 1, MaxInt);
  TempoPart := '';
  AtPos := Pos('@', BarsPart);
  if AtPos > 0 then
  begin
    TempoPart := Copy(BarsPart, AtPos + 1, MaxInt);
    BarsPart := Copy(BarsPart, 1, AtPos - 1);
  end;

  for I := 1 to Length(NamePart) do
    if not IsNameChar(NamePart[I], I = 1) then
      raise Exception.CreateFmt(
        'Invalid --section "%s": the name must start with a letter and contain only letters, digits, _ and -',
        [ASpec]);

  if not TryStrToInt(BarsPart, Result.Bars) then
    raise Exception.CreateFmt('Invalid --section "%s": "%s" is not a bar count (%s)',
      [ASpec, BarsPart, SYNTAX_HELP]);
  if (Result.Bars < 1) or (Result.Bars > MAX_SECTION_BARS) then
    raise Exception.CreateFmt('Invalid --section "%s": bars must be between 1 and %d',
      [ASpec, MAX_SECTION_BARS]);

  if AtPos > 0 then
  begin
    if not TryStrToInt(TempoPart, Result.Tempo) then
      raise Exception.CreateFmt('Invalid --section "%s": "%s" is not a tempo (%s)',
        [ASpec, TempoPart, SYNTAX_HELP]);
    if (Result.Tempo < MIN_SECTION_TEMPO) or (Result.Tempo > MAX_SECTION_TEMPO) then
      raise Exception.CreateFmt('Invalid --section "%s": tempo must be between %d and %d BPM',
        [ASpec, MIN_SECTION_TEMPO, MAX_SECTION_TEMPO]);
  end;

  Result.Name := LowerCase(NamePart);
end;

function DescribeStructure(const AStructure: array of TSectionDef): string;
var
  I: Integer;
  Part: string;
begin
  Result := '';
  for I := 0 to High(AStructure) do
  begin
    Part := Format('%s:%d', [AStructure[I].Name, AStructure[I].Bars]);
    if AStructure[I].Tempo > 0 then
      Part := Part + '@' + IntToStr(AStructure[I].Tempo);
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + Part;
  end;
end;

end.
