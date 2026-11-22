program MyProject_gui;

{$mode objfpc}{$H+}

{$IFDEF MSWINDOWS}
{$R *.res}
{$ENDIF}

uses
  Interfaces,
  Forms,
  MyProjectUnit;

begin
  Application.Initialize;
  WriteLn('MyProject GUI — replace this with your actual LCL form.');
end.