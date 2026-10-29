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
      [heavy verse 7/8 intensity=0.2-0.6]     a groove for 7/8
  A word like 7/8 is a meter: it is taken out of the words and returned in
  MeterNum/MeterDen (0/0 when there is none, which means 4/4). What the other
  words and keys mean is up to the caller (grooves, fills). This unit only
  splits the file; the tab lines themselves are checked by the caller with the
  drum-tab engine.

  Errors name the file and the line:  metal.tab (12): ... }

interface

uses
  Classes, SysUtils, ConfigFiles, time_signature;

type
  TTabWords = array of string;

  { A single time signature from a header, e.g. 7/8 or _6_8_. }
  TMeterPair = record
    Num, Den: Integer;
  end;

  TTabBlock = record
    Words: TTabWords;      { header words, lower case, without the meters }
    Meters: array of TMeterPair;  { meters from header, empty = infer from tab }
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

{ Returns the meter for bar index ABarIndex. Cycles through header meters.
  Returns False when the header has no meters (infer from tab). }
function BlockMeter(const ABlock: TTabBlock; ABarIndex: Integer; out AMeterNum, AMeterDen: Integer): Boolean;

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

{ Returns the meter for bar index ABarIndex. Cycles through header meters.
  Returns Num=0, Den=0 when the header has no meters (infer from tab). }
function BlockMeter(const ABlock: TTabBlock; ABarIndex: Integer; out AMeterNum, AMeterDen: Integer): Boolean;
begin
  AMeterNum := 0;
  AMeterDen := 0;
  if Length(ABlock.Meters) = 0 then
    Exit(False);
  AMeterNum := ABlock.Meters[ABarIndex mod Length(ABlock.Meters)].Num;
  AMeterDen := ABlock.Meters[ABarIndex mod Length(ABlock.Meters)].Den;
  Exit(True);
end;

function ParseTabLines(ALines: TStrings; const AFileName: string): TTabBlocks;
var
  I, P, N, MN, MD: Integer;
  Line, Head, Word, NormalizedWord, Problem: string;
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
          else if Pos('/', Word) > 0 then
          begin
            { Collect meter words like 7/8 from the header. }
            { Underscore notation like _6_8_ is NOT accepted - only proper N/D. }
            if TryParseMeter(Word, MN, MD) then
            begin
              Problem := MeterProblem(MN, MD);
              if Problem <> '' then
              begin
                { Invalid meter - treat as regular word }
                N := Length(Cur.Words);
                SetLength(Cur.Words, N + 1);
                Cur.Words[N] := LowerCase(Word);
              end
              else
              begin
                N := Length(Cur.Meters);
                SetLength(Cur.Meters, N + 1);
                Cur.Meters[N].Num := MN;
                Cur.Meters[N].Den := MD;
              end;
            end
            else
            begin
              { Not a valid meter - treat as regular word }
              N := Length(Cur.Words);
              SetLength(Cur.Words, N + 1);
              Cur.Words[N] := LowerCase(Word);
            end;
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
