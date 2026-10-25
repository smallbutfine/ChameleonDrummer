unit TabFiles;

{$mode objfpc}{$H+}

{ Reader for the plain-text drum-tab files in config/grooves and config/fills.

      # a comment (so is a line starting with ;)
      [heavy verse]                       a block starts with a header in [ ]
      K  x... ..x. x... ..x. | ....       followed by drum-tab lines
      S  .... x... .... x... | ....

  The header holds words and key=value pairs in any order:
      [heavy verse intensity=0.2-0.6]
      [short energy=0.3]
  What the words and keys mean is up to the caller (grooves, fills). This unit
  only splits the file; the tab lines themselves are checked by the caller
  with the drum-tab engine.

  Errors name the file and the line:  metal.tab (12): ... }

interface

uses
  Classes, SysUtils, ConfigFiles;

type
  TTabWords = array of string;

  TTabBlock = record
    Words: TTabWords;      { header words, lower case }
    KeyNames: TTabWords;   { header keys, lower case }
    KeyValues: TTabWords;
    Lines: array of string;
    HeaderLine: Integer;   { line number of the header, for messages }
  end;

  TTabBlocks = array of TTabBlock;

{ Splits the lines of a file into blocks. AFileName is only used in messages.
  Raises an Exception on a tab line before the first header, an unclosed
  header, an empty header, or a block without tab lines. }
function ParseTabLines(ALines: TStrings; const AFileName: string): TTabBlocks;

{ Reads and splits a file. }
function ParseTabFile(const APath: string): TTabBlocks;

{ Value of a header key; False if the block does not have it. }
function BlockKey(const ABlock: TTabBlock; const AKey: string; out AValue: string): Boolean;

{ "name(line): text" - the shape of every message about a file. }
function TabMessage(const AFileName: string; ALine: Integer; const AText: string): string;

implementation

function TabMessage(const AFileName: string; ALine: Integer; const AText: string): string;
begin
  Result := Format('%s (%d): %s', [ExtractFileName(AFileName), ALine, AText]);
end;

function BlockKey(const ABlock: TTabBlock; const AKey: string; out AValue: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  AValue := '';
  for I := 0 to High(ABlock.KeyNames) do
    if ABlock.KeyNames[I] = LowerCase(AKey) then
    begin
      AValue := ABlock.KeyValues[I];
      Exit(True);
    end;
end;

function ParseTabLines(ALines: TStrings; const AFileName: string): TTabBlocks;
var
  I, P, N: Integer;
  Line, Head, Word: string;
  Parts: TStringList;
  Open: Boolean;
  Cur: TTabBlock;

  procedure CloseBlock;
  begin
    if not Open then
      Exit;
    if Length(Cur.Lines) = 0 then
      raise Exception.Create(TabMessage(AFileName, Cur.HeaderLine,
        'the block has no drum-tab lines'));
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Cur;
    Open := False;
  end;

begin
  Result := nil;
  Open := False;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ' ';
    Parts.StrictDelimiter := True;
    for I := 0 to ALines.Count - 1 do
    begin
      Line := Trim(ALines[I]);
      if (Line = '') or (Line[1] = '#') or (Line[1] = ';') then
        Continue;

      if Line[1] = '[' then
      begin
        CloseBlock;
        if Line[Length(Line)] <> ']' then
          raise Exception.Create(TabMessage(AFileName, I + 1,
            'the header must end with ], like [heavy verse]'));
        Head := Trim(Copy(Line, 2, Length(Line) - 2));
        if Head = '' then
          raise Exception.Create(TabMessage(AFileName, I + 1, 'the header is empty'));

        Cur := Default(TTabBlock);
        Cur.HeaderLine := I + 1;
        Parts.DelimitedText := StringReplace(StringReplace(Head, #9, ' ', [rfReplaceAll]),
          '  ', ' ', [rfReplaceAll]);
        for Word in Parts do
        begin
          if Word = '' then
            Continue;
          P := Pos('=', Word);
          if P > 0 then
          begin
            N := Length(Cur.KeyNames);
            SetLength(Cur.KeyNames, N + 1);
            SetLength(Cur.KeyValues, N + 1);
            Cur.KeyNames[N] := LowerCase(Copy(Word, 1, P - 1));
            Cur.KeyValues[N] := Trim(Copy(Word, P + 1, MaxInt));
          end
          else
          begin
            N := Length(Cur.Words);
            SetLength(Cur.Words, N + 1);
            Cur.Words[N] := LowerCase(Word);
          end;
        end;
        Open := True;
        Continue;
      end;

      if not Open then
        raise Exception.Create(TabMessage(AFileName, I + 1,
          'a drum-tab line before the first [header]: ' + Line));
      N := Length(Cur.Lines);
      SetLength(Cur.Lines, N + 1);
      Cur.Lines[N] := Line;
    end;
    CloseBlock;
  finally
    Parts.Free;
  end;
end;

function ParseTabFile(const APath: string): TTabBlocks;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    ReadConfigLines(APath, Lines);
    Result := ParseTabLines(Lines, APath);
  finally
    Lines.Free;
  end;
end;

end.
