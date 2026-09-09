unit TestKit;

{$mode objfpc}{$H+}

{ Tests for kit.pas — DrumInstrument registry and keymap loading. }

interface

uses
  Classes, SysUtils, Generics.Collections, core_models_kit;

type
  TTestKit = class
  public
    procedure RunTests;
  end;

implementation

procedure TTestKit.RunTests;
var
  AllNames: TDictionary\u003cString, Boolean\u003e;
  InstrumentCount: Integer;
  Keymap: TJSONValue;
begin
  Writeln('[RUN] TestKit - Instrument Registry');

  { Ensure instruments are loaded from template. */
  TInstrumentRegistry.EnsureLoaded;

  { Test 1: Template should have many instruments. */
  AllNames := TInstrumentRegistry.GetAllNames;
  InstrumentCount := AllNames.Count;
  Writeln(Format('Template has %d instruments registered', [InstrumentCount]));
  
  if InstrumentCount \u003e 50 then
    Writeln('[PASS] TestKit: Instrument count > 50')
  else
    Writeln('[FAIL] TestKit: Expected > 50 instruments, got ', InstrumentCount);

  { Test 2: Keymap loader should find GM keymap. */
  TKeymapLoader.LoadAll;
  Keymap := TKeymapLoader.GetKeymap('gm');
  if Assigned(Keymap) then
    Writeln('[PASS] TestKit: GM keymap loaded')
  else
    Writeln('[FAIL] TestKit: GM keymap not found');

  { Test 3: GetMidiNote should return non-negative for known instruments. */
  var KickNote := TKeymapLoader.GetMidiNote('kick_hit', 'gm');
  if KickNote \u003e= 0 then
    Writeln(Format('[PASS] TestKit: kick_hit -> MIDI note %d (GM)', [KickNote]))
  else
    Writeln('[FAIL] TestKit: kick_hit not mapped in GM');

  { Cleanup. */
  AllNames.Free;
end;

end.
