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
  APICli, Kit, PluginRegistry;

var
  CLI: TCLIInterface;
  ExitCode: Integer;
  ArgCount: Integer;
  Args: TArray<String>;
  I: Integer;

begin
  // Parse command-line arguments from program parameters
  ArgCount := ParamCount;
  SetLength(Args, ArgCount + 1);
  Args[0] := ParamStr(0); // Program name

  for I := 1 to ArgCount do
    Args[I] := ParamStr(I);

  // Create and run CLI interface
  CLI := TCLIInterface.Create;
  try
    ExitCode := CLI.Run(ArgCount, Args);
  finally
    CLI.Free;
  end;

  Halt(ExitCode);
end.
