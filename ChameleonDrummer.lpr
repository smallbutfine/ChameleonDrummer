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
  Randomize;
  WriteLn('CHAMELEONDRUMMER: starting...');
  Flush(Output);

  // Parse command-line arguments from program parameters
  ArgCount := ParamCount;
  SetLength(Args, ArgCount + 1);
  Args[0] := ParamStr(0); // Program name

  for I := 1 to ArgCount do
    Args[I] := ParamStr(I);

  WriteLn(Format('CHAMELEONDRUMMER: args=%d', [ArgCount]));
  Flush(Output);

  // Create and run CLI interface
  WriteLn('CHAMELEONDRUMMER: creating CLI interface...');
  Flush(Output);
  CLI := TCLIInterface.Create;
  WriteLn('CHAMELEONDRUMMER: CLI interface created.');
  Flush(Output);
  try
    WriteLn('CHAMELEONDRUMMER: calling CLI.Run...');
    Flush(Output);
    ExitCode := CLI.Run(ArgCount, Args);
    WriteLn(Format('CHAMELEONDRUMMER: CLI.Run exit code=%d', [ExitCode]));
    Flush(Output);
  finally
    CLI.Free;
  end;

  Halt(ExitCode);
end.
