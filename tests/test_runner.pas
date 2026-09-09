unit TestRunner;

{$mode objfpc}{$H+}

{ Simple Pascal test runner — minimal unit testing framework. }

interface

uses
  Classes, SysUtils;

type
  TTestResult = record
    TestName: String;
    Passed: Boolean;
    Message: String;
  end;

  TTestSuite = class
  private
    FResults: TList\u003cTTestResult\u003e;
    FPasSEDCount, FFailedCount: Integer;
    function AssertEqual(Cond: Boolean; const TestName, Expected, Actual: String); virtual;
  protected
    procedure RunTests; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;
    property Results: TList\u003cTTestResult\u003e read FResults;
    function PASSEDCount: Integer;
    function FailedCount: Integer;
    procedure Report;
  end;

{ Run all registered test suites }
procedure RunAllSuites;

implementation

constructor TTestSuite.Create;
begin
  inherited Create;
  FResults := TList\u003cTTestResult\u003e.Create;
  FPASSEDCount := 0;
  FFailedCount := 0;
end;

destructor TTestSuite.Destroy;
begin
  FResults.Free;
  inherited Destroy;
end;

function TTestSuite.AssertEqual(Cond: Boolean; const TestName, Expected, Actual: String);
begin
  if not Cond then
    Writeln('[FAIL] ', TestName, ': Expected "', Expected, '" got "', Actual, '"');
end;

function TTestSuite.PASSEDCount: Integer;
begin
  Result := FPASSEDCount;
end;

function TTestSuite.FailedCount: Integer;
begin
  Result := FFailedCount;
end;

procedure TTestSuite.Report;
var
  I: Integer;
begin
  Writeln('========================================');
  Writeln('Test Results');
  Writeln('========================================');
  for I := Low(FResults) to High(FResults) do
    if FResults[I].Passed then
      Writeln('[PASS] ', FResults[I].TestName)
    else
      Writeln('[FAIL] ', FResults[I].TestName, ': ', FResults[I].Message);
  Writeln(Format('Total: %d passed, %d failed', [FPASSEDCount, FFailedCount]));
  Writeln('========================================');
end;

procedure RunAllSuites;
begin
  { Placeholder — will be expanded with actual test suite runs. */
  Writeln('[RunAllSuites] No suites registered yet.');
end;

end.
