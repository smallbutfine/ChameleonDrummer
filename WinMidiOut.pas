unit WinMidiOut;

{$mode objfpc}{$H+}

interface

uses 
  Windows, 
  mmsystem, 
  SysUtils;

type
  TWinMidiOut = class
  private
    FHandle: HMIDIOUT;
    
    { Interne Methode zum sicheren Senden von Roh-Daten }
    procedure SendRaw(Status, Data1, Data2: Byte);
  public
    { Konstruktor öffnet das Gerät basierend auf der Device-ID }
    constructor Create(DeviceID: Integer);
    
    { Destruktor schließt das Handle sauber }
    destructor Destroy; override;
    
    { Standard MIDI-Befehle }
    procedure SendNoteOn(Chan, Note, Vel: Byte);
    procedure SendNoteOff(Chan, Note: Byte);
    
    { Panic-Funktion: Stoppt alle Töne und setzt Controller zurück }
    procedure SendPanic;
    
    property Handle: HMIDIOUT read FHandle;
  end;

implementation

{ --- KONSTRUKTOR --- }
constructor TWinMidiOut.Create(DeviceID: Integer);
var
  Res: MMRESULT;
begin
  inherited Create;
  FHandle := 0;
  
  { 
    Wichtig für 64-Bit: Die DeviceID muss explizit als UINT_PTR 
    gecastet werden, um Speicherfehler in der Windows-API zu vermeiden. 
  }
  Res := midiOutOpen(@FHandle, UINT_PTR(DeviceID), 0, 0, CALLBACK_NULL);
  
  if Res <> MMSYSERR_NOERROR then
  begin
    FHandle := 0;
    raise Exception.Create('MIDI Error: Device konnte nicht geöffnet werden. Code: ' + IntToStr(Res));
  end;
end;

{ --- DESTRUKTOR --- }
destructor TWinMidiOut.Destroy;
begin
  if FHandle <> 0 then
  begin
    { Laufende Noten vor dem Schließen hart stoppen }
    midiOutReset(FHandle);
    midiOutClose(FHandle);
  end;
  inherited Destroy;
end;

{ --- ROH-DATEN SENDEN --- }
procedure TWinMidiOut.SendRaw(Status, Data1, Data2: Byte);
var 
  Msg: DWORD; 
begin 
  { Nur senden, wenn das Handle valide ist }
  if FHandle = 0 then 
  begin
    Exit;
  end;
  
  { 
    MIDI-Daten für Windows in ein 32-Bit Double-Word packen:
    Byte 0: Status (NoteOn/Off etc.)
    Byte 1: Data 1 (Note)
    Byte 2: Data 2 (Velocity/Value)
    Byte 3: 0
  }
  Msg := Status or (Data1 shl 8) or (Data2 shl 16); 
  midiOutShortMsg(FHandle, Msg); 
end;

{ --- NOTE ON --- }
procedure TWinMidiOut.SendNoteOn(Chan, Note, Vel: Byte); 
begin 
  { Status $90 = Note On, Kanäle 0-15 }
  SendRaw($90 or (Chan and $0F), Note, Vel); 
end;

{ --- NOTE OFF --- }
procedure TWinMidiOut.SendNoteOff(Chan, Note: Byte);
begin
  { Status $80 = Note Off }
  SendRaw($80 or (Chan and $0F), Note, 0);
end;

{ --- PANIC RESET --- }
procedure TWinMidiOut.SendPanic;
var 
  i: Integer; 
begin 
  if FHandle = 0 then 
  begin
    Exit;
  end;
  
  { Loop über alle 16 Kanäle }
  for i := 0 to 15 do 
  begin
    { CC 123: All Notes Off }
    SendRaw($B0 or i, 123, 0); 
    
    { CC 120: All Sound Off (härterer Reset) }
    SendRaw($B0 or i, 120, 0); 
    
    { CC 121: Reset All Controllers }
    SendRaw($B0 or i, 121, 0); 
  end;
end;

end.
