unit CliLookup;

{$mode objfpc}{$H+}

{ How the GUI talks to the command line tool: find it, run it and wait for it,
  and read the genre, style and drummer lists from it, so the GUI always
  offers what the engine really has. No LCL here, so the unit can be tested
  with plain FPC (tests/test_cli_lookup.pas). }

interface

uses
  Classes, SysUtils, process;

{ Where the command line tool is expected: next to the running program. }
function CliToolPath: string;

{ CliToolPath if the file exists, otherwise ''. }
function FindCliTool: string;

{ Runs the tool, waits for it, and returns its exit code (0 = success).
  AOutput gets everything it wrote, errors included. A tool that cannot be
  started at all gives -1 and the reason in AOutput. }
function RunCli(const AExe: string; const AArgs: array of string;
  out AOutput: string): Integer;

{ Takes the "  - name" lines out of `list ...` output; header and error lines
  are skipped. }
procedure ParseListOutput(const AText: string; AItems: TStrings);

{ Runs `list ...` and puts the names in AItems. False, with the reason in
  AError, when the tool fails or lists nothing. }
function QueryList(const AExe: string; const AArgs: array of string;
  AItems: TStrings; out AError: string): Boolean;

{ The keymaps the tool can use: the .json files in the mappings folder next to
  the program, without the template. Sorted. }
procedure ListKeymaps(AItems: TStrings);

implementation

function CliToolPath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'ChameleonDrummer' +
    {$IFDEF MSWINDOWS}'.exe'{$ELSE}''{$ENDIF};
end;

function FindCliTool: string;
begin
  Result := CliToolPath;
  if not FileExists(Result) then
    Result := '';
end;

function RunCli(const AExe: string; const AArgs: array of string;
  out AOutput: string): Integer;
var
  P: TProcess;
  Buf: array[0..4095] of Byte;
  N, I: Integer;
  Chunk: string;
begin
  AOutput := '';
  Result := -1;
  P := TProcess.Create(nil);
  try
    P.Executable := AExe;
    for I := 0 to High(AArgs) do
      P.Parameters.Add(AArgs[I]);
    P.Options := [poUsePipes, poStderrToOutput, poNoConsole];
    try
      P.Execute;
    except
      on E: Exception do
      begin
        AOutput := 'Cannot start ' + AExe + ': ' + E.Message;
        Exit;
      end;
    end;
    { Reading until the pipe closes keeps the tool from blocking on a full pipe. }
    repeat
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then
      begin
        SetLength(Chunk, N);
        Move(Buf[0], Chunk[1], N);
        AOutput := AOutput + Chunk;
      end;
    until N <= 0;
    P.WaitOnExit;
    Result := P.ExitStatus;
  finally
    P.Free;
  end;
end;

procedure ParseListOutput(const AText: string; AItems: TStrings);
var
  Lines: TStringList;
  I: Integer;
  S: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    for I := 0 to Lines.Count - 1 do
    begin
      S := Trim(Lines[I]);
      if (Length(S) > 2) and (S[1] = '-') and (S[2] = ' ') then
        AItems.Add(Trim(Copy(S, 3, MaxInt)));
    end;
  finally
    Lines.Free;
  end;
end;

function QueryList(const AExe: string; const AArgs: array of string;
  AItems: TStrings; out AError: string): Boolean;
var
  Output: string;
  Code: Integer;
begin
  AError := '';
  AItems.Clear;
  Code := RunCli(AExe, AArgs, Output);
  if Code = 0 then
    ParseListOutput(Output, AItems);
  Result := (Code = 0) and (AItems.Count > 0);
  if not Result then
  begin
    AError := Trim(Output);
    if AError = '' then
      AError := Format('the tool returned nothing (exit code %d)', [Code]);
  end;
end;

procedure ListKeymaps(AItems: TStrings);
var
  Found: TSearchRec;
  Dir, Stem: string;
  List: TStringList;
begin
  AItems.Clear;
  Dir := ExtractFilePath(ParamStr(0)) + 'mappings' + PathDelim;
  List := TStringList.Create;
  try
    if FindFirst(Dir + '*.json', faAnyFile and not faDirectory, Found) = 0 then
    try
      repeat
        Stem := LowerCase(ChangeFileExt(Found.Name, ''));
        if Stem <> 'template' then
          List.Add(Stem);
      until FindNext(Found) <> 0;
    finally
      FindClose(Found);
    end;
    List.Sort;
    AItems.Assign(List);
  finally
    List.Free;
  end;
end;

end.
