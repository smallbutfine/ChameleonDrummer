content = open('tools/step_editor/MainFrm.pas').read()

# Fix CharToStepChar - replace C = . with C = '.'
content = content.replace("if C = . then Result := scDot", "if C = '.' then Result := scDot")
content = content.replace("else if C = 'x' then Result := scX", "else if C = 'x' then Result := scX")
content = content.replace("else if C = 'X' then Result := scAccent", "else if C = 'X' then Result := scAccent")
content = content.replace("else if C = 'o' then Result := scSoft", "else if C = 'o' then Result := scSoft")
content = content.replace("else if C = 'g' then Result := scGhost", "else if C = 'g' then Result := scGhost")

# Fix StepCharToChar - replace Result := . with Result := '.'
content = content.replace("Result := .", "Result := '.'")
content = content.replace("Result := 'x'", "Result := 'x'")
content = content.replace("Result := 'X'", "Result := 'X'")
content = content.replace("Result := 'o'", "Result := 'o'")
content = content.replace("Result := 'g'", "Result := 'g'")

open('tools/step_editor/MainFrm.pas', 'w').write(content)
print('Done')
