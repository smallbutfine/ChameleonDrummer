content = open('tools/step_editor/MainFrm.pas').read()

# Find and replace the broken section
old = """  if not FileExists(MidiToTab) then
  begin
    UpdateStatus('midi_to_tab.exe not found. Searched: """

new = """  if not FileExists(MidiToTab) then
  begin
    UpdateStatus('midi_to_tab.exe not found. Searched: ' + GetCurrentDir + PathDelim + 'midi_to_tab.exe');
    Exit;
  end;"""

content = content.replace(old, new)
open('tools/step_editor/MainFrm.pas', 'w').write(content)
print('Done')
