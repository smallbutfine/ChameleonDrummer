program test_cli_lookup;

{$mode objfpc}{$H+}

{ Checks the GUI's CLI lookup unit against the real command line tool: that it
  finds the tool, waits for it, reads its exit code, and gets the genre, style
  and drummer lists from it. Run from the project root after a build, so that
  ChameleonDrummer.exe and mappings\ sit next to the test program (the test
  runner copies the test there). }

uses
  SysUtils, Classes, CliLookup;

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
  Items: TStringList;
  Exe, Output, Err, OutFile: string;
  Code, I: Integer;
  Genres: TStringList;
begin
  Items := TStringList.Create;
  Genres := TStringList.Create;
  try
    { Parsing, without the tool. }
    ParseListOutput('Available genres:'#13#10'  - metal'#13#10'  - rock'#13#10 +
      '[Error] something'#13#10#13#10'-nothing'#13#10'  - '#13#10'  - jazz', Items);
    Check((Items.Count = 3) and (Items[0] = 'metal') and (Items[1] = 'rock') and
      (Items[2] = 'jazz'), 'only "- name" lines are taken: ' + Items.CommaText);
    Items.Clear;
    ParseListOutput('', Items);
    Check(Items.Count = 0, 'empty output has no items');

    { A program that is not there. }
    Code := RunCli(ExtractFilePath(ParamStr(0)) + 'no_such_tool.exe', [], Output);
    Check((Code = -1) and (Output <> ''), 'a missing tool gives -1 and a reason: ' + Output);
    Check(not QueryList(ExtractFilePath(ParamStr(0)) + 'no_such_tool.exe',
      ['list', 'genres'], Items, Err) and (Err <> ''), 'QueryList reports a missing tool');

    Exe := FindCliTool;
    Check(Exe <> '', 'the tool is found next to the test program: ' + CliToolPath);
    if Exe <> '' then
    begin
      Check(QueryList(Exe, ['list', 'genres'], Genres, Err), 'list genres: ' + Err);
      for I := 0 to 0 do
      begin
        Check(Genres.IndexOf('metal') >= 0, 'genre metal');
        Check(Genres.IndexOf('rock') >= 0, 'genre rock');
        Check(Genres.IndexOf('jazz') >= 0, 'genre jazz');
        Check(Genres.IndexOf('funk') >= 0, 'genre funk');
        Check(Genres.IndexOf('electronic') >= 0, 'genre electronic');
      end;

      { Every genre the tool lists has styles, and a style it lists is accepted. }
      for I := 0 to Genres.Count - 1 do
      begin
        Check(QueryList(Exe, ['list', 'styles', '--genre', Genres[I]], Items, Err) and
          (Items.Count > 0), 'styles of ' + Genres[I] + ': ' + Err);
      end;
      QueryList(Exe, ['list', 'styles', '--genre', 'rock'], Items, Err);
      Check(Items.IndexOf('classic') >= 0, 'rock has the style classic');

      Check(not QueryList(Exe, ['list', 'styles', '--genre', 'nosuchgenre'], Items, Err),
        'an unknown genre has no styles');
      Check(not QueryList(Exe, ['list', 'styles'], Items, Err) and (Err <> ''),
        'styles without a genre is an error with a message: ' + Err);

      Check(QueryList(Exe, ['list', 'drummers'], Items, Err), 'list drummers: ' + Err);
      Check(Items.IndexOf('bonham') >= 0, 'drummer bonham');
      Check(Items.IndexOf('weckl') >= 0, 'drummer weckl');
      Check(Items.Count >= 16, Format('at least 16 drummers, got %d', [Items.Count]));

      { Running waits for the tool and gives its exit code. }
      OutFile := GetTempDir + 'cd_cli_lookup.mid';
      if FileExists(OutFile) then
        DeleteFile(OutFile);
      Code := RunCli(Exe, ['generate', '--genre', 'rock', '--style', 'classic',
        '--section', 'verse:2', '--output', OutFile], Output);
      Check(Code = 0, Format('generate succeeds (exit %d): %s', [Code, Output]));
      Check(FileExists(OutFile), 'the file exists as soon as RunCli returns (it waited)');
      Check(Pos('Song generated', Output) > 0, 'its output is captured: ' + Output);
      if FileExists(OutFile) then
        DeleteFile(OutFile);

      Code := RunCli(Exe, ['generate', '--genre', 'rock', '--style', 'classic',
        '--section', 'verse:0', '--output', OutFile], Output);
      Check(Code <> 0, 'a rejected option gives a non-zero exit code');
      Check(Pos('verse:0', Output) > 0, 'and the reason is captured: ' + Output);
      Check(not FileExists(OutFile), 'and nothing is written');
    end;

    ListKeymaps(Items);
    Check(Items.IndexOf('gm') >= 0, 'keymap gm: ' + Items.CommaText);
    Check(Items.IndexOf('template') < 0, 'the template is not a keymap to pick');
  finally
    Items.Free;
    Genres.Free;
  end;

  if Failures = 0 then
    WriteLn('PASS: GUI CLI lookup')
  else
  begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
end.
