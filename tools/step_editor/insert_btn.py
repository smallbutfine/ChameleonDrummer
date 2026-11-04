with open('B:/dev/github/ChameleonDrummer/tools/step_editor/MainFrm.pas', 'r') as f:
    content = f.read()

insert_code = '''

procedure TMainForm.btnNewPatternClick(Sender: TObject);
var
  I, K: Integer;
begin
  FTabBars := nil;
  SetLength(FTabBars, 1);
  FTabBars[0].Steps := FResolution;
  SetLength(FTabBars[0].InstChars, Length(FInstOrder));
  for I := 0 to High(FInstOrder) do
  begin
    FTabBars[0].InstChars[I].Abbr := FInstOrder[I];
    SetLength(FTabBars[0].InstChars[I].Chars, FResolution);
    for K := 0 to FResolution - 1 do
      FTabBars[0].InstChars[I].Chars[K] := '.';
  end;
  FStepsPerBar := FResolution;
  RefreshGrid;
  UpdateStatus('New empty pattern created: ' + IntToStr(FResolution) + ' steps/bar, ' + IntToStr(Length(FInstOrder)) + ' instruments.');
end;

'''

marker = '  end;\n\nprocedure TMainForm.edInputChange(Sender: TObject);'
if marker in content:
    content = content.replace(marker, '  end;\n' + insert_code + 'procedure TMainForm.edInputChange(Sender: TObject);', 1)
    with open('B:/dev/github/ChameleonDrummer/tools/step_editor/MainFrm.pas', 'w') as f:
        f.write(content)
    print('SUCCESS: Inserted btnNewPatternClick')
else:
    print('FAILED: Could not find marker')
    lines = content.split('\n')
    for i in range(276, 282):
        if i < len(lines):
            print(f'{i+1}: {repr(lines[i])}')
