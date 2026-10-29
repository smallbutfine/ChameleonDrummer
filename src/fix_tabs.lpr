program fix_tabs;

{$mode objfpc}{$H+}

{ Standalone tool that scans config/grooves and config/fills .tab files,
  finds bars whose step count does not match the declared meter, and tries
  to repair them:

  * too few steps  -> pad with '.' (rests) at the end of the bar
  * too many steps -> strip trailing '.' (rests) from the end of the bar,
                      never remove actual hits (x, X, o, g)

  Files are only rewritten when at least one bar was changed.  A report is
  printed to stdout listing every file, block, line and the fix applied.
}

uses
  Classes, SysUtils, StrUtils, math;

const
  CONFIG_DIR = 'config';
  GROOVE_DIR = CONFIG_DIR + PathDelim + 'grooves';
  FILL_DIR   = CONFIG_DIR + PathDelim + 'fills';

  VALID_PER_UNIT: array[0..5] of Integer = (1, 2, 3, 4, 6, 8);
  VALID_DENOMINATORS: array[0..3] of Integer = (2, 4, 8, 16);

  MIN_NUMERATOR = 2;
  MAX_NUMERATOR = 32;

type
  TIssueKind = (ikNone, ikTooFew, ikTooMany, ikUnfixable);

  TBarFix = record
    BarIndex: Integer;
    Original: string;
    Fixed: string;
    Kind: TIssueKind;
    TargetSteps: Integer;
  end;

  TLineFix = record
    LineNumber: Integer;
    Instrument: string;
    OriginalLine: string;
    FixedLine: string;
    FixCount: Integer;
  end;

  TBlockFix = record
    HeaderLine: Integer;
    Header: string;
    MeterNum: Integer;
    MeterDen: Integer;
    LineFixes: array of TLineFix;
  end;

  TFileFix = record
    FileName: string;
    IsGroove: Boolean;
    Blocks: array of TBlockFix;
    Changed: Boolean;
  end;

{ ------------------------------------------------------------------------- }
{ Helpers                                                                   }
{ ------------------------------------------------------------------------- }

function CountSteps(const Bar: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(Bar) do
    if Bar[I] <> ' ' then
      Inc(Result);
end;

function IsValidStepCount(Steps, MeterNum: Integer): Boolean;
var
  PerUnit: Integer;
begin
  if Steps mod MeterNum <> 0 then
    Exit(False);
  PerUnit := Steps div MeterNum;
  Result := (PerUnit = 1) or (PerUnit = 2) or (PerUnit = 3) or
            (PerUnit = 4) or (PerUnit = 6) or (PerUnit = 8);
end;

function ParseMeter(const Word: string; out Num, Den: Integer): Boolean;
var
  P: Integer;
  A, B, Normalized: string;
begin
  Num := 0;
  Den := 0;
  Result := False;

  { Normalize _6_8_ -> 6/8 }
  Normalized := StringReplace(Word, '_', '/', [rfReplaceAll]);

  P := Pos('/', Normalized);
  if P < 2 then
    Exit;
  A := Trim(Copy(Normalized, 1, P - 1));
  B := Trim(Copy(Normalized, P + 1, MaxInt));
  if (Length(A) > 4) or (Length(B) > 4) then
    Exit;
  if not TryStrToInt(A, Num) or not TryStrToInt(B, Den) then
    Exit;
  Result := True;
end;

{ ------------------------------------------------------------------------- }
{ Bar-level fixing                                                          }
{ ------------------------------------------------------------------------- }

function FixBar(const Bar: string; MeterNum: Integer; out FixedBar: string;
  out TargetSteps: Integer; out Kind: TIssueKind): Boolean;
var
  Steps: Integer;
  ValidList: array[0..5] of Integer;
  I, Closest, Diff, BestDiff: Integer;
  TrailingDots: Integer;
  P: Integer;
  Ch: Char;
  RemoveCount: Integer;
begin
  Result := False;
  FixedBar := Bar;
  TargetSteps := 0;
  Kind := ikNone;

  if MeterNum = 0 then
    MeterNum := 4;

  Steps := CountSteps(Bar);

  if IsValidStepCount(Steps, MeterNum) then
    Exit(False);

  for I := 0 to 5 do
    ValidList[I] := MeterNum * VALID_PER_UNIT[I];

  BestDiff := MaxInt;
  Closest := 0;
  for I := 0 to 5 do
  begin
    Diff := Abs(ValidList[I] - Steps);
    if Diff < BestDiff then
    begin
      BestDiff := Diff;
      Closest := ValidList[I];
    end;
  end;

  TargetSteps := Closest;

  if Steps < Closest then
  begin
    FixedBar := Bar + StringOfChar('.', Closest - Steps);
    Kind := ikTooFew;
    Result := True;
    Exit;
  end;

  { Steps > Closest: try to strip trailing dots only }
  TrailingDots := 0;
  for P := Length(Bar) downto 1 do
  begin
    Ch := Bar[P];
    if Ch = '.' then
      Inc(TrailingDots)
    else if Ch <> ' ' then
      Break;
  end;

  RemoveCount := Steps - Closest;
  if TrailingDots >= RemoveCount then
  begin
    FixedBar := '';
    for P := Length(Bar) downto 1 do
    begin
      Ch := Bar[P];
      if (Ch = '.') and (RemoveCount > 0) then
      begin
        Dec(RemoveCount);
        Continue;
      end;
      FixedBar := Ch + FixedBar;
    end;
    Kind := ikTooMany;
    Result := True;
    Exit;
  end;

  Kind := ikUnfixable;
  Result := False;
end;

{ ------------------------------------------------------------------------- }
{ Line-level fixing                                                         }
{ ------------------------------------------------------------------------- }

function IsInstrumentToken(const Token: string): Boolean;
const
  Valid: array[0..16] of string = (
    'K', 'S', 'RS', 'SS', 'H', 'HO', 'HP', 'R', 'RB', 'C', 'C2', 'CH', 'SP',
    'T1', 'T2', 'T3', 'T4');
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Valid) do
    if UpperCase(Token) = Valid[I] then
    begin
      Result := True;
      Exit;
    end;
end;

function FixLine(const Line: string; MeterNum: Integer;
  out FixedLine: string; out FixCount: Integer): Boolean;
var
  P: Integer;
  Token, Content, Rest: string;
  PipePos: Integer;
  Bar: string;
  FixedBar: string;
  TargetSteps: Integer;
  Kind: TIssueKind;
  NewContent: string;
  Changed: Boolean;
  First: Boolean;
begin
  Result := False;
  FixedLine := Line;
  FixCount := 0;
  Changed := False;

  P := Pos(' ', Line);
  if P = 0 then
    Exit;

  Token := Copy(Line, 1, P - 1);
  Content := Copy(Line, P + 1, MaxInt);

  { Process each bar separated by |, consuming Content from left to right }
  NewContent := '';
  First := True;
  Rest := Content;
  while Rest <> '' do
  begin
    PipePos := Pos('|', Rest);
    if PipePos = 0 then
    begin
      { Last bar }
      Bar := Trim(Rest);
      Rest := '';
    end
    else
    begin
      Bar := Trim(Copy(Rest, 1, PipePos - 1));
      Rest := Copy(Rest, PipePos + 1, MaxInt);
    end;

    if Bar <> '' then
    begin
      if FixBar(Bar, MeterNum, FixedBar, TargetSteps, Kind) then
      begin
        Changed := True;
        Inc(FixCount);
        if not First then
          NewContent := NewContent + '|';
        NewContent := NewContent + FixedBar;
      end
      else
      begin
        if not First then
          NewContent := NewContent + '|';
        NewContent := NewContent + Bar;
      end;
      First := False;
    end
    else if not First then
    begin
      { Empty bar between || }
      NewContent := NewContent + '|';
    end;
  end;

  if Changed then
    FixedLine := Token + ' ' + NewContent;
  Result := Changed;
end;

{ ------------------------------------------------------------------------- }
{ File processing                                                           }
{ ------------------------------------------------------------------------- }

function ProcessFile(const FileName: string; IsGroove: Boolean): TFileFix;
var
  Lines: TStringList;
  I: Integer;
  Line: string;
  InBlock: Boolean;
  BlockStart: Integer;
  BlockHeader: string;
  BlockLines: TStringList;
  MeterNum, MeterDen: Integer;
  BlockFix: TBlockFix;
  LineFix: TLineFix;
  FixedLine: string;
  FixCount: Integer;
  J: Integer;
  P, P2: Integer;
  TokenCheck: string;
  Word: string;
  Parts: TStringList;
  EqPos: Integer;
begin
  Result.FileName := FileName;
  Result.IsGroove := IsGroove;
  Result.Changed := False;
  SetLength(Result.Blocks, 0);

  Lines := TStringList.Create;
  BlockLines := TStringList.Create;
  Parts := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);

    InBlock := False;
    BlockStart := 0;
    BlockHeader := '';
    MeterNum := 4;
    MeterDen := 4;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);

      if (Line = '') or (Line[1] = '#') or (Line[1] = ';') then
        Continue;

      if Line[1] = '[' then
      begin
        { Flush previous block }
        if InBlock and (BlockLines.Count > 0) then
        begin
          BlockFix.HeaderLine := BlockStart;
          BlockFix.Header := BlockHeader;
          BlockFix.MeterNum := MeterNum;
          BlockFix.MeterDen := MeterDen;
          SetLength(BlockFix.LineFixes, 0);

          for J := 0 to BlockLines.Count - 1 do
          begin
            Line := BlockLines[J];
            P := Pos(':', Line);
            if P = 0 then
              Continue;
            LineFix.LineNumber := StrToIntDef(Copy(Line, 1, P - 1), 0);
            LineFix.OriginalLine := Copy(Line, P + 1, MaxInt);
            LineFix.FixedLine := LineFix.OriginalLine;
            LineFix.FixCount := 0;

            { Extract instrument token }
            TokenCheck := LineFix.OriginalLine;
            P2 := Pos(' ', TokenCheck);
            if P2 > 0 then
              TokenCheck := Copy(TokenCheck, 1, P2 - 1);
            if Pos('@', TokenCheck) > 0 then
              TokenCheck := Copy(TokenCheck, 1, Pos('@', TokenCheck) - 1);

            if not IsInstrumentToken(TokenCheck) then
              Continue;

            LineFix.Instrument := TokenCheck;

            if FixLine(LineFix.OriginalLine, MeterNum, FixedLine, FixCount) then
            begin
              LineFix.FixedLine := FixedLine;
              LineFix.FixCount := FixCount;

              SetLength(BlockFix.LineFixes, Length(BlockFix.LineFixes) + 1);
              BlockFix.LineFixes[High(BlockFix.LineFixes)] := LineFix;
              Result.Changed := True;
            end;
          end;

          if Length(BlockFix.LineFixes) > 0 then
          begin
            SetLength(Result.Blocks, Length(Result.Blocks) + 1);
            Result.Blocks[High(Result.Blocks)] := BlockFix;
          end;
        end;

        { Start new block }
        InBlock := True;
        BlockStart := I + 1;
        { Re-read the header line since Line was overwritten in the flush loop }
        Line := Trim(Lines[I]);
        BlockHeader := Trim(Copy(Line, 2, Length(Line) - 2));
        BlockLines.Clear;

        MeterNum := 4;
        MeterDen := 4;

        Parts.Clear;
        Parts.Delimiter := ' ';
        Parts.StrictDelimiter := True;
        Parts.DelimitedText := BlockHeader;

        for Word in Parts do
        begin
          if Word = '' then
            Continue;
          EqPos := Pos('=', Word);
          if EqPos > 0 then
            Continue;

          if ParseMeter(Word, MeterNum, MeterDen) then
            Continue;
        end;

        Continue;
      end;

      if InBlock then
      begin
        BlockLines.Add(IntToStr(I + 1) + ':' + Line);
      end;
    end;

    { Flush last block }
    if InBlock and (BlockLines.Count > 0) then
    begin
      BlockFix.HeaderLine := BlockStart;
      BlockFix.Header := BlockHeader;
      BlockFix.MeterNum := MeterNum;
      BlockFix.MeterDen := MeterDen;
      SetLength(BlockFix.LineFixes, 0);

      for J := 0 to BlockLines.Count - 1 do
      begin
        Line := BlockLines[J];
        P := Pos(':', Line);
        if P = 0 then
          Continue;
        LineFix.LineNumber := StrToIntDef(Copy(Line, 1, P - 1), 0);
        LineFix.OriginalLine := Copy(Line, P + 1, MaxInt);
        LineFix.FixedLine := LineFix.OriginalLine;
        LineFix.FixCount := 0;

        TokenCheck := LineFix.OriginalLine;
        P2 := Pos(' ', TokenCheck);
        if P2 > 0 then
          TokenCheck := Copy(TokenCheck, 1, P2 - 1);
        if Pos('@', TokenCheck) > 0 then
          TokenCheck := Copy(TokenCheck, 1, Pos('@', TokenCheck) - 1);

        if not IsInstrumentToken(TokenCheck) then
          Continue;

        LineFix.Instrument := TokenCheck;

        if FixLine(LineFix.OriginalLine, MeterNum, FixedLine, FixCount) then
        begin
          LineFix.FixedLine := FixedLine;
          LineFix.FixCount := FixCount;

          SetLength(BlockFix.LineFixes, Length(BlockFix.LineFixes) + 1);
          BlockFix.LineFixes[High(BlockFix.LineFixes)] := LineFix;
          Result.Changed := True;
        end;
      end;

      if Length(BlockFix.LineFixes) > 0 then
      begin
        SetLength(Result.Blocks, Length(Result.Blocks) + 1);
        Result.Blocks[High(Result.Blocks)] := BlockFix;
      end;
    end;

  finally
    Lines.Free;
    BlockLines.Free;
    Parts.Free;
  end;
end;

{ ------------------------------------------------------------------------- }
{ Apply fixes to files                                                      }
{ ------------------------------------------------------------------------- }

function ApplyFixes(const FileName: string; const FileFix: TFileFix): Integer;
var
  Lines: TStringList;
  I, J: Integer;
  LineNo: Integer;
  FixedLine: string;
  Applied: Integer;
begin
  Applied := 0;
  if not FileFix.Changed then
    Exit(0);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);

    for I := 0 to High(FileFix.Blocks) do
    begin
      for J := 0 to High(FileFix.Blocks[I].LineFixes) do
      begin
        LineNo := FileFix.Blocks[I].LineFixes[J].LineNumber;
        if (LineNo >= 1) and (LineNo <= Lines.Count) then
        begin
          FixedLine := FileFix.Blocks[I].LineFixes[J].FixedLine;
          if Lines[LineNo - 1] <> FixedLine then
          begin
            Lines[LineNo - 1] := FixedLine;
            Inc(Applied);
          end;
        end;
      end;
    end;

    if Applied > 0 then
      Lines.SaveToFile(FileName);
  finally
    Lines.Free;
  end;

  Result := Applied;
end;

{ ------------------------------------------------------------------------- }
{ Reporting                                                                 }
{ ------------------------------------------------------------------------- }

procedure PrintReport(const FileFix: TFileFix; Applied: Integer);
var
  I, J: Integer;
begin
  if not FileFix.Changed then
    Exit;

  if FileFix.IsGroove then
      WriteLn('=== ', FileFix.FileName, ' (groove) ===')
    else
      WriteLn('=== ', FileFix.FileName, ' (fill) ===');
  for I := 0 to High(FileFix.Blocks) do
  begin
    WriteLn('  [', FileFix.Blocks[I].Header, '] line ', FileFix.Blocks[I].HeaderLine,
      ' meter ', FileFix.Blocks[I].MeterNum, '/', FileFix.Blocks[I].MeterDen);
    for J := 0 to High(FileFix.Blocks[I].LineFixes) do
    begin
      WriteLn('    line ', FileFix.Blocks[I].LineFixes[J].LineNumber,
        ' (', FileFix.Blocks[I].LineFixes[J].Instrument, '):');
      WriteLn('      ', FileFix.Blocks[I].LineFixes[J].OriginalLine,
        ' -> ', FileFix.Blocks[I].LineFixes[J].FixedLine);
    end;
  end;
end;

procedure ScanTabFiles(const ADir: string; AList: TStringList);
var
  SR: TSearchRec;
begin
  if FindFirst(ADir + PathDelim + '*.tab', faAnyFile, SR) = 0 then
  begin
    repeat
      AList.Add(ADir + PathDelim + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ ------------------------------------------------------------------------- }
{ Main                                                                      }
{ ------------------------------------------------------------------------- }

var
  GDir, FDir: string;
  GFiles, FFiles: TStringList;
  I: Integer;
  FileFix: TFileFix;
  Applied: Integer;
  TotalFixed, TotalFiles: Integer;
begin
  TotalFixed := 0;
  TotalFiles := 0;

  GDir := GROOVE_DIR;
  FDir := FILL_DIR;

  WriteLn('ChameleonDrummer .tab fixer');
  WriteLn('============================');
  WriteLn;

  if DirectoryExists(GDir) then
  begin
    GFiles := TStringList.Create;
    try
      ScanTabFiles(GDir, GFiles);
      for I := 0 to GFiles.Count - 1 do
      begin
        FileFix := ProcessFile(GFiles[I], True);
        if FileFix.Changed then
        begin
          Applied := ApplyFixes(GFiles[I], FileFix);
          PrintReport(FileFix, Applied);
          Inc(TotalFixed, Applied);
          Inc(TotalFiles);
        end;
      end;
    finally
      GFiles.Free;
    end;
  end;

  if DirectoryExists(FDir) then
  begin
    FFiles := TStringList.Create;
    try
      ScanTabFiles(FDir, FFiles);
      for I := 0 to FFiles.Count - 1 do
      begin
        FileFix := ProcessFile(FFiles[I], False);
        if FileFix.Changed then
        begin
          Applied := ApplyFixes(FFiles[I], FileFix);
          PrintReport(FileFix, Applied);
          Inc(TotalFixed, Applied);
          Inc(TotalFiles);
        end;
      end;
    finally
      FFiles.Free;
    end;
  end;

  WriteLn('============================');
  WriteLn('Files changed: ', TotalFiles);
  WriteLn('Total fixes applied: ', TotalFixed);
end.
