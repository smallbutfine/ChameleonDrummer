program ChameleonDrummer;

{$mode objfpc}{$H+}

{ MIDI drums generator — Pascal Translation
  Main entry point. Equivalent to midi_drums/__main__.py in Python.

  Usage: chameleondrummer <command> [options]
    Commands: generate, pattern, list, info

  Options are passed through to the CLI interface.
}

uses
  SysUtils, Classes,
  jsonparser,
  CLIInterface, Kit, PluginRegistry;
{$R *.res} // Standard Lazarus-Ressource (für das Icon)

var
  CLI: TCLIInterface;
  ExitCode: Integer;
  ArgCount: Integer;
  Args: specialize TArray<String>;
  I: Integer;

begin
  try
    if (ParamCount < 1) then
    begin
      Writeln('Usage: chameleondrummer <command> [options]');
      Halt(0);
    end;

    SetLength(Args, ParamCount + 1);
    Args[0] := ParamStr(0); // Program name
    for I := 1 to ParamCount do
      Args[I] := ParamStr(I);

    CLI := TCLIInterface.Create;
    try
      ExitCode := CLI.Run(ParamCount, Args);
    finally
      CLI.Free;
    end;
  finally
    Halt(ExitCode);
  end;
end.
