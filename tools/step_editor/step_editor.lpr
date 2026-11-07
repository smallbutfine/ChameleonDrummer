program step_editor;

{$mode objfpc}{$H+}

{ step_editor — Visual step editor for ChameleonDrummer .tab files.

  A GUI wrapper around midi_to_tab that:
    - Loads MIDI files and converts them to .tab grooves/fills
    - Displays a visual step editor grid for editing
    - Allows splitting long tabs into patterns
    - Exports to config/grooves/ and config/fills/

  Uses the midi_to_tab executable for conversion.
}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, Forms,
  MainFrm;
{$R *.res} // Standard Lazarus-Ressource (für das Icon)


begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.