content = open('tools/step_editor/MainFrm.pas').read()

old = """  MidiToTab := GetCurrentDir + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
    MidiToTab := GetCurrentDir + PathDelim + '..' + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
  begin
    UpdateStatus('midi_to_tab.exe not found. Build it first.');
    Exit;
  end;"""

new = """  MidiToTab := GetCurrentDir + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
    MidiToTab := GetCurrentDir + PathDelim + '..' + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
    MidiToTab := ExtractFileDir(ParamStr(0)) + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
    MidiToTab := ExtractFileDir(ParamStr(0)) + PathDelim + '..' + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
  begin
    UpdateStatus('midi_to_tab.exe not found. Searched: ' + GetCurrentDir + PathDelim + 'midi_to_tab.exe');
    Exit;
  end;"""

content = content.replace(old, new)
open('tools/step_editor/MainFrm.pas', 'w').write(content)
print('Done')
