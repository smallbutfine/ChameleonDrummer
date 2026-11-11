program ChameleonDrummerGUI;

{$mode objfpc}{$H+}

{ ChameleonDrummer - graphical front end.

  Wraps the Engine V2 generator that the command line tool drives: pick a
  genre, style, drummer and keymap, set the tempo and the two performance
  parameters, and write a MIDI file - optionally with a REAPER project and
  an Ardour session next to it.

  Build with:
      lazbuild gui\chameleondrummer_gui.lpi
}

uses
  Interfaces, Forms, MainFrm;
{$IFDEF WINDOWS}
{$R *.res}
{$ENDIF}
begin
  Application.Title:='';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
