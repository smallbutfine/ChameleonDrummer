unit MainFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Dialogs,
  Grids, FileUtil, Process, Math, {$IFDEF MSWINDOWS}DarkTheme,{$ENDIF} Windows, Graphics;

type
  TStepChar = (scDot, scX, scAccent, scSoft, scGhost);

  TTabBar = record
    Steps: Integer;
    InstChars: array of record
      Abbr: string;
      Chars: array of Char;
    end;
  end;

  TTabBarArray = array of TTabBar;

  { TMainForm }

  TMainForm = class(TForm)
    lblInput: TLabel;
    edInput: TEdit;
    btnBrowseInput: TButton;
    btnNewPattern: TButton;

    lblMapping: TLabel;
    cbMapping: TComboBox;
    lblStyle: TLabel;
    cbStyle: TComboBox;
    lblKind: TLabel;
    cbKind: TComboBox;
    lblIntensity: TLabel;
    cbIntensity: TComboBox;
    lblEnergy: TLabel;
    cbEnergy: TComboBox;
    lblResolution: TLabel;
    cbResolution: TComboBox;
    lblMeter: TLabel;
    cbMeter: TComboBox;
    radGroove: TRadioButton;
    radFill: TRadioButton;
    cbGrooveGenre: TComboBox;
    cbFillDrummer: TComboBox;

    sgTab: TStringGrid;
    lblZoom: TLabel;
    cbZoom: TComboBox;
    btnPrevPage: TButton;
    btnNextPage: TButton;
    lblPageInfo: TLabel;

    btnSavePatternAs: TButton;
    memStatus: TMemo;
    sbStatus: TStatusBar;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnBrowseInputClick(Sender: TObject);
    procedure btnNewPatternClick(Sender: TObject);
    procedure edInputChange(Sender: TObject);
    procedure btnSavePatternAsClick(Sender: TObject);
    procedure sgTabSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
    procedure sgTabClick(Sender: TObject);
    procedure cbZoomChange(Sender: TObject);
    procedure btnPrevPageClick(Sender: TObject);
    procedure btnNextPageClick(Sender: TObject);
    procedure cbMappingChange(Sender: TObject);
    procedure chkFillChange(Sender: TObject);
    procedure rbModeChange(Sender: TObject);

  private
    FInputPath: string;
    FOutputDir: string;
    FTabData: string;
    FTabBars: TTabBarArray;
    FStepsPerBar: Integer;
    FResolution: Integer;
    FCurPage: Integer;
    FPageSize: Integer;
    FTotalPages: Integer;
    FInstOrder: array of string;
    FInstColMap: array of Integer;
    {$IFDEF MSWINDOWS}FDark: Boolean;{$ENDIF}

    procedure LoadMidiAndConvert;
    procedure LoadTabFile(const AFileName: string);
    procedure ParseTabOutput(const ATabText: string; ASkipHeader: Boolean = True);
    function GetStyleNameFromItem(const AItem: string): string;
    procedure RefreshGrid;
    procedure RenderPage(APage: Integer);
    procedure ToggleCell(ACol, ARow: Integer);
    function CharToStepChar(C: Char): TStepChar;
    function StepCharToChar(SC: TStepChar): Char;
    procedure UpdateStatus(const AMsg: string);
    function RunMidiToTab(const AExe: string; const AArgs: array of string): string;
    procedure UpdatePageInfo;
    procedure UpdateControls;
    function BuildTabText: string;
    procedure LoadKindList;
    procedure LoadGrooveList;
    procedure LoadDrummerList;
    {$IFDEF MSWINDOWS}procedure ApplyDarkTheme(ADark: Boolean);
    procedure ComboBoxDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure ComboBoxDropDown(Sender: TObject);
    procedure SystemThemeChanged(Sender: TObject);{$ENDIF}

  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation
{$R *.lfm}

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInputPath := '';
  FOutputDir := ExtractFilePath(ParamStr(0)) + '..' + PathDelim +  'config';
  FTabData := '';
  FTabBars := nil;
  FStepsPerBar := 16;
  FResolution := 16;
  FCurPage := 0;
  FPageSize := 16;
  FTotalPages := 0;
  FInstOrder := nil;
  FInstColMap := nil;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  Files: TStringList;
  I: Integer;
  FName: string;
  Base: string;
begin
  Caption := 'ChameleonDrummer — Step Editor';
  DefaultMonitor := dmMainForm;

  SetLength(FInstOrder, 17);
  FInstOrder[0] := 'K';
  FInstOrder[1] := 'S';
  FInstOrder[2] := 'RS';
  FInstOrder[3] := 'SS';
  FInstOrder[4] := 'H';
  FInstOrder[5] := 'HO';
  FInstOrder[6] := 'HP';
  FInstOrder[7] := 'R';
  FInstOrder[8] := 'RB';
  FInstOrder[9] := 'C';
  FInstOrder[10] := 'C2';
  FInstOrder[11] := 'CH';
  FInstOrder[12] := 'SP';
  FInstOrder[13] := 'T1';
  FInstOrder[14] := 'T2';
  FInstOrder[15] := 'T3';
  FInstOrder[16] := 'T4';

  sgTab.ColCount := 1;
  sgTab.RowCount := 1;
  sgTab.FixedCols := 1;
  sgTab.FixedRows := 1;
  sgTab.Options := sgTab.Options - [goRowSelect] + [goRangeSelect, goAlwaysShowEditor];
  sgTab.OnSelectCell := @sgTabSelectCell;
  sgTab.OnClick := @sgTabClick;

  cbResolution.Items.Clear;
  cbResolution.Items.Add('4');
  cbResolution.Items.Add('8');
  cbResolution.Items.Add('16');
  cbResolution.Items.Add('32');
  cbResolution.ItemIndex := 2;

  cbZoom.Items.Clear;
  cbZoom.Items.Add('8 steps');
  cbZoom.Items.Add('16 steps');
  cbZoom.Items.Add('32 steps');
  cbZoom.Items.Add('64 steps');
  cbZoom.ItemIndex := 1;
  FPageSize := 16;

  cbMapping.Items.Clear;
  cbMapping.Items.Add('(default GM)');
  cbMapping.ItemIndex := 0;

  // Populate meter combobox with common time signatures
  cbMeter.Items.Clear;
  cbMeter.Items.CommaText := '4/4,2/4,3/4,5/4,6/8,7/8,9/8,11/8,13/8,15/16';
  // Populate meter combobox with common time signatures
  cbMeter.Items.Clear;
  cbMeter.Items.CommaText := '4/4,2/4,3/4,5/4,6/8,7/8,9/8,11/8,13/8,15/16';
  cbMeter.ItemIndex := 0;

  // Populate intensity combobox with presets
  cbIntensity.Items.Clear;
  cbIntensity.Items.Add('0.1-0.3');  // soft
  cbIntensity.Items.Add('0.2-0.6');  // medium
  cbIntensity.Items.Add('0.4-0.8');  // heavy
  cbIntensity.Items.Add('0.6-1.0');  // intense
  cbIntensity.ItemIndex := 1;

  // Populate energy combobox with 0.1 steps from 0.1 to 1.0
  cbEnergy.Items.Clear;
  cbEnergy.Items.CommaText := '0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0';
  cbEnergy.ItemIndex := 4; // default to 0.5
  cbEnergy.Enabled := False; // disabled when Groove mode selected


  // Populate kind combobox with available kinds based on selected style
  LoadKindList;

  // Initialize export genre/drummer lists after output dir is set
  if radGroove.Checked then
    LoadGrooveList
  else
    LoadDrummerList;

  if DirectoryExists('mappings') then
  begin
    Files := TStringList.Create;
    try
      FindAllFiles(Files, 'mappings', '*.json', False);
      for I := 0 to Files.Count - 1 do
      begin
        FName := ExtractFileName(Files[I]);
        Base := ChangeFileExt(FName, '');
        cbMapping.Items.Add(Base);
      end;
    finally
      Files.Free;
    end;
  end;

  {$IFDEF MSWINDOWS}
  OnSystemThemeChange := @SystemThemeChanged;
  ApplyDarkTheme(ResolveDark(LoadThemeChoice)); // Use saved theme choice or system default
  {$ENDIF}

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FTabBars := nil;
  FInstOrder := nil;
  FInstColMap := nil;
end;

procedure TMainForm.btnBrowseInputClick(Sender: TObject);
var
  OD: TOpenDialog;
begin
  OD := TOpenDialog.Create(nil);
  try
    OD.Filter := 'MIDI and Tab files (*.mid;*.midi;*.tab)|*.mid;*.midi;*.tab|All files (*.*)|*.*';
    OD.DefaultExt := 'mid';
    if OD.Execute then
    begin
      edInput.Text := OD.FileName;
      FInputPath := OD.FileName;
      if SameText(ExtractFileExt(FInputPath), '.tab') then
        LoadTabFile(FInputPath)
      else
        LoadMidiAndConvert;
    end;
  finally
    OD.Free;
  end;
  end;

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

procedure TMainForm.edInputChange(Sender: TObject);
begin
  FInputPath := edInput.Text;
end;

procedure TMainForm.LoadMidiAndConvert;
var
  Args: array of string;
  I: Integer;
  ResultStr: string;
  MidiToTab: string;
begin
  if FInputPath = '' then
  begin
    UpdateStatus('Please select a MIDI input file.');
    Exit;
  end;

  if not FileExists(FInputPath) then
  begin
    UpdateStatus('MIDI file not found: ' + FInputPath);
    Exit;
  end;

  Args := nil;
  SetLength(Args, 1);
  Args[0] := FInputPath;

  // No output file — we read tab data from stdout

  if cbMapping.ItemIndex > 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--mapping';
    Args[High(Args)] := 'mappings/' + cbMapping.Items[cbMapping.ItemIndex] + '.json';
  end;

  if cbStyle.ItemIndex >= 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--style';
    Args[High(Args)] := GetStyleNameFromItem(cbStyle.Items[cbStyle.ItemIndex]);
  end;

  if cbKind.ItemIndex >= 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--kind';
    Args[High(Args)] := cbKind.Items[cbKind.ItemIndex];
  end;

  if cbIntensity.ItemIndex >= 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--intensity';
    Args[High(Args)] := cbIntensity.Items[cbIntensity.ItemIndex];
  end;

  if cbEnergy.ItemIndex >= 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--energy';
    Args[High(Args)] := cbEnergy.Items[cbEnergy.ItemIndex];
  end;

  if cbResolution.ItemIndex >= 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--resolution';
    Args[High(Args)] := cbResolution.Items[cbResolution.ItemIndex];
    FResolution := StrToIntDef(cbResolution.Items[cbResolution.ItemIndex], 16);
  end;

  if cbMeter.ItemIndex >= 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--meter';
    Args[High(Args)] := cbMeter.Items[cbMeter.ItemIndex];
  end;

  if radFill.Checked then
  begin
    SetLength(Args, Length(Args) + 1);
    Args[High(Args)] := '--fill';
  end;

  // Always resolve midi_to_tab.exe relative to this exe's parent directory
  MidiToTab := ExtractFilePath(ParamStr(0)) + 'midi_to_tab.exe';

  if not FileExists(MidiToTab) then
  begin
    UpdateStatus('midi_to_tab.exe not found at: ' + MidiToTab);
    Exit;
  end;

  ResultStr := RunMidiToTab(MidiToTab, Args);

  // Show raw output in memo for debugging
  memStatus.Lines.Add('--- RAW OUTPUT (' + IntToStr(Length(ResultStr)) + ' bytes) ---');
  if Length(ResultStr) > 500 then
    memStatus.Lines.Add(Copy(ResultStr, 1, 500) + '...')
  else
    memStatus.Lines.Add(ResultStr);
  memStatus.Lines.Add('--- END OUTPUT ---');

  FTabData := ResultStr;
  ParseTabOutput(FTabData);
  RefreshGrid;
  UpdateStatus('Converted: ' + IntToStr(Length(FTabBars)) + ' bars, ' +
    IntToStr(FStepsPerBar) + ' steps/bar, ' + IntToStr(FResolution) + ' resolution.');
  end;
procedure TMainForm.LoadTabFile(const AFileName: string);
var
  SL: TStringList;
  I: Integer;
  Line: string;
  TabText: string;
begin
  if not FileExists(AFileName) then
  begin
    UpdateStatus('Tab file not found: ' + AFileName);
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(AFileName);

    TabText := '';
    for I := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[I]);
      if (Line = '') then Continue;
      if Line[1] = '#' then Continue;
      if Line[1] = '[' then Continue;
      TabText := TabText + Line + #13#10;
    end;

    if TabText = '' then
    begin
      UpdateStatus('No data found in tab file: ' + AFileName);
      Exit;
    end;

    ParseTabOutput(TabText, False);
    RefreshGrid;
    UpdateStatus('Loaded tab: ' + ExtractFileName(AFileName) +
      ', ' + IntToStr(Length(FTabBars)) + ' bars, ' +
      IntToStr(FStepsPerBar) + ' steps/bar.');
  finally
    SL.Free;
  end;
end;

function TMainForm.RunMidiToTab(const AExe: string; const AArgs: array of string): string;
var
  P: TProcess;
  Buf: array[0..4095] of Byte;
  N, I: Integer;
  Chunk: string;
begin
  Result := '';
  P := TProcess.Create(nil);
  try
    P.Executable := AExe;
    for I := 0 to High(AArgs) do
      P.Parameters.Add(AArgs[I]);
    P.Options := [poUsePipes, poStderrToOutput, poNoConsole];
    try
      P.Execute;
    except
      on E: Exception do
      begin
        UpdateStatus('Cannot start ' + AExe + ': ' + E.Message);
        Exit;
      end;
    end;
    { Reading until the pipe closes keeps the tool from blocking on a full pipe. }
    repeat
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then
      begin
        SetLength(Chunk, N);
        Move(Buf[0], Chunk[1], N);
        Result := Result + Chunk;
      end;
    until N <= 0;
    P.WaitOnExit;
  finally
    P.Free;
  end;
end;

procedure TMainForm.ParseTabOutput(const ATabText: string; ASkipHeader: Boolean = True);
var
  Lines: TStringList;
  Bars: TStringList;
  I, J, K, BarIdx, CharIdx, MaxSteps: Integer;
  Line: string;
  Inst: string;
  GridStr: string;
  BarStr: string;
begin
  FTabBars := nil;
  MaxSteps := 0;
  Lines := TStringList.Create;
  Bars := TStringList.Create;
  try
    if ATabText = '' then
      Exit;

    Lines.Text := ATabText;

    I := 0;
    if ASkipHeader and (Lines.Count > 0) then
      I := 1; // Skip header line [midi ...]

    while I < Lines.Count do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then
      begin
        Inc(I);
        Continue;
      end;

      // Try to detect instrument abbreviation (first 3-4 non-space chars)
      Inst := Copy(Line, 1, MaxInt);
      J := 1;
      while (J <= Length(Inst)) and (Inst[J] = ' ') do Inc(J);
      K := J;
      while (K <= Length(Inst)) and (Inst[K] <> ' ') do Inc(K);
      Inst := Copy(Inst, J, K - J); // e.g. "K" or "HH"

      // GridStr starts after the first whitespace block
      GridStr := Trim(Copy(Line, K + 1, MaxInt));

      if GridStr = '' then
      begin
        Inc(I);
        Continue;
      end;

      Bars.Clear;
      // Handle both pipe-delimited and space-delimited bars (fallback)
      if Pos('|', GridStr) > 0 then
      begin
        Bars.StrictDelimiter := True;
        Bars.Delimiter := '|';
        Bars.DelimitedText := GridStr;
      end
      else
      begin
        // If no pipes, treat the whole string as one bar's raw steps
        // OR split by multiple spaces if it looks like fixed width.
        // For now, fallback to treating it as 1 bar if valid chars exist.
        Bars.Add(GridStr);
      end;

      while Length(FTabBars) < Bars.Count do
      begin
        J := Length(FTabBars);
        SetLength(FTabBars, J + 1);
        FTabBars[J].Steps := 0;
        FTabBars[J].InstChars := nil;
      end;

      for BarIdx := 0 to Bars.Count - 1 do
      begin
        BarStr := Trim(Bars[BarIdx]);
        CharIdx := 0;
        for K := 1 to Length(BarStr) do
          if BarStr[K] <> ' ' then
            Inc(CharIdx);

        J := -1;
        for K := 0 to High(FTabBars[BarIdx].InstChars) do
          if FTabBars[BarIdx].InstChars[K].Abbr = Inst then
          begin
            J := K;
            Break;
          end;

        if J = -1 then
        begin
          J := Length(FTabBars[BarIdx].InstChars);
          SetLength(FTabBars[BarIdx].InstChars, J + 1);
          FTabBars[BarIdx].InstChars[J].Abbr := Inst;
          SetLength(FTabBars[BarIdx].InstChars[J].Chars, CharIdx);
          FillChar(FTabBars[BarIdx].InstChars[J].Chars[0], CharIdx, '.');
        end;

        CharIdx := 0;
        for K := 1 to Length(BarStr) do
          if BarStr[K] <> ' ' then
          begin
            if CharIdx < Length(FTabBars[BarIdx].InstChars[J].Chars) then
              FTabBars[BarIdx].InstChars[J].Chars[CharIdx] := BarStr[K];
            Inc(CharIdx);
          end;

        FTabBars[BarIdx].Steps := CharIdx;
        if CharIdx > MaxSteps then MaxSteps := CharIdx;
      end;

      Inc(I);
    end;

    if Length(FTabBars) > 0 then
      FStepsPerBar := MaxSteps // Use max found steps per bar
    else
      FStepsPerBar := FResolution;

  finally
    Lines.Free;
    Bars.Free;
  end;
end;

procedure TMainForm.RefreshGrid;
begin
  FCurPage := 0;
  FTotalPages := Max(1, (Length(FTabBars) + FPageSize - 1) div FPageSize);
  RenderPage(FCurPage);
  UpdatePageInfo;
  UpdateControls;
end;

procedure TMainForm.RenderPage(APage: Integer);
var
  StartBar, EndBar, BarIdx, ColIdx, RowIdx, K, BSteps, J: Integer;
  Found: Boolean;
begin
  if Length(FTabBars) = 0 then
    Exit;

  StartBar := APage * FPageSize;
  EndBar := Min(StartBar + FPageSize, Length(FTabBars));

  ColIdx := 1;
  for BarIdx := StartBar to EndBar - 1 do
    ColIdx := ColIdx + FTabBars[BarIdx].Steps;

  sgTab.ColCount := ColIdx + 1;
  sgTab.RowCount := Length(FInstOrder) + 1;

  for RowIdx := 0 to High(FInstOrder) do
    sgTab.Cells[0, RowIdx + 1] := FInstOrder[RowIdx];

  ColIdx := 1;
  for BarIdx := StartBar to EndBar - 1 do
  begin
    BSteps := FTabBars[BarIdx].Steps;
    for K := 0 to BSteps - 1 do
    begin
      sgTab.Cells[ColIdx, 0] := IntToStr(K + 1);
      for RowIdx := 0 to High(FInstOrder) do
      begin
        Found := False;
        for J := 0 to High(FTabBars[BarIdx].InstChars) do
          if FTabBars[BarIdx].InstChars[J].Abbr = FInstOrder[RowIdx] then
          begin
            sgTab.Cells[ColIdx, RowIdx + 1] := FTabBars[BarIdx].InstChars[J].Chars[K];
            Found := True;
            Break;
          end;
        if not Found then
          sgTab.Cells[ColIdx, RowIdx + 1] := '.';
      end;
      Inc(ColIdx);
    end;
  end;

  sgTab.ColWidths[0] := 40;
  for ColIdx := 1 to sgTab.ColCount - 1 do
    sgTab.ColWidths[ColIdx] := 20;

  sgTab.RowHeights[0] := 16;
  for RowIdx := 0 to High(FInstOrder) do
    sgTab.RowHeights[RowIdx + 1] := 14;
end;

procedure TMainForm.ToggleCell(ACol, ARow: Integer);
var
  C: Char;
  SC: TStepChar;
begin
  if (ACol < 1) or (ARow < 1) or (ACol >= sgTab.ColCount) or (ARow >= sgTab.RowCount) then
    Exit;

  C := sgTab.Cells[ACol, ARow][1];
  SC := CharToStepChar(C);

  case SC of
    scDot: SC := scX;
    scX: SC := scAccent;
    scAccent: SC := scSoft;
    scSoft: SC := scGhost;
    scGhost: SC := scDot;
  end;

  sgTab.Cells[ACol, ARow] := StepCharToChar(SC);
end;

function TMainForm.CharToStepChar(C: Char): TStepChar;
begin
  if Ord(C) = 46 then Result := scDot
  else if Ord(C) = 120 then Result := scX
  else if Ord(C) = 88 then Result := scAccent
  else if Ord(C) = 111 then Result := scSoft
  else if Ord(C) = 103 then Result := scGhost
  else Result := scDot;
end;

function TMainForm.StepCharToChar(SC: TStepChar): Char;
begin
  if SC = scDot then Result := Chr(46)
  else if SC = scX then Result := Chr(120)
  else if SC = scAccent then Result := Chr(88)
  else if SC = scSoft then Result := Chr(111)
  else if SC = scGhost then Result := Chr(103)
  else Result := Chr(46);
end;

procedure TMainForm.sgTabSelectCell(Sender: TObject; aCol, aRow: Integer;
  var CanSelect: Boolean);
begin
  CanSelect := (aCol > 0) and (aRow > 0);
end;

procedure TMainForm.sgTabClick(Sender: TObject);
var
  Col, Row: Integer;
begin
  Col := sgTab.Col;
  Row := sgTab.Row;
  if Col > 0 then
    ToggleCell(Col, Row);
end;

procedure TMainForm.cbZoomChange(Sender: TObject);
begin
  if cbZoom.ItemIndex = 0 then FPageSize := 8
  else if cbZoom.ItemIndex = 1 then FPageSize := 16
  else if cbZoom.ItemIndex = 2 then FPageSize := 32
  else if cbZoom.ItemIndex = 3 then FPageSize := 64;
  FTotalPages := Max(1, (Length(FTabBars) + FPageSize - 1) div FPageSize);
  if FCurPage >= FTotalPages then FCurPage := FTotalPages - 1;
  RenderPage(FCurPage);
  UpdatePageInfo;
end;

procedure TMainForm.btnPrevPageClick(Sender: TObject);
begin
  if FCurPage > 0 then
  begin
    Dec(FCurPage);
    RenderPage(FCurPage);
    UpdateControls;
    UpdatePageInfo;
  end;
end;

procedure TMainForm.btnNextPageClick(Sender: TObject);
begin
  if FCurPage < FTotalPages - 1 then
  begin
    Inc(FCurPage);
    RenderPage(FCurPage);
    UpdateControls;
    UpdatePageInfo;
  end;
end;

procedure TMainForm.UpdatePageInfo;
begin
  lblPageInfo.Caption := Format('Page %d of %d (%d bars)', [FCurPage + 1, FTotalPages, Length(FTabBars)]);
end;

procedure TMainForm.UpdateControls;
begin
  btnPrevPage.Enabled := FCurPage > 0;
  btnSavePatternAs.Enabled := Length(FTabBars) > 0;
end;

procedure TMainForm.UpdateStatus(const AMsg: string);
begin
  memStatus.Lines.Add(AMsg);
  memStatus.SelStart := Length(memStatus.Text);
  sbStatus.SimpleText := AMsg;
end;

procedure TMainForm.cbMappingChange(Sender: TObject);
begin
end;

procedure TMainForm.chkFillChange(Sender: TObject);
begin
  // Placeholder for future fill preset selection
end;

procedure TMainForm.rbModeChange(Sender: TObject);
begin
  if radGroove.Checked then
  begin
    cbIntensity.Enabled := True;
    cbEnergy.Enabled := False;
    LoadGrooveList;
  end
  else
  begin
    cbIntensity.Enabled := False;
    cbEnergy.Enabled := True;
    LoadDrummerList;
  end;
end;
function TMainForm.BuildTabText: string;
var
  SL: TStringList;
  I, J, K, K2: Integer;
  Header, StyleName, KindName: string;
  Line: string;
  Found: Boolean;
begin
  SL := TStringList.Create;
  try
    if radFill.Checked then
      Header := Format('[%s energy=%s]', ['custom', cbEnergy.Items[cbEnergy.ItemIndex]])
    else
    begin
      StyleName := 'midi';
      KindName := 'verse';
      if cbStyle.ItemIndex >= 0 then
        StyleName := GetStyleNameFromItem(cbStyle.Items[cbStyle.ItemIndex]);
      if cbKind.ItemIndex >= 0 then
        KindName := cbKind.Items[cbKind.ItemIndex];
      Header := Format('[%s %s intensity=0.2-0.6]', [StyleName, KindName]);
    end;
    SL.Add(Header);

    for I := 0 to High(FInstOrder) do
    begin
      Line := FInstOrder[I];
      for K := 1 to 4 - Length(FInstOrder[I]) do
        Line := Line + ' ';
      if Length(Line) < 4 then Line := Line + ' ';
      Line := Line + '  ';

      for J := 0 to High(FTabBars) do
      begin
        if J > 0 then Line := Line + ' | ';
        Found := False;
        for K := 0 to High(FTabBars[J].InstChars) do
          if FTabBars[J].InstChars[K].Abbr = FInstOrder[I] then
          begin
            for K2 := 0 to High(FTabBars[J].InstChars[K].Chars) do
              Line := Line + FTabBars[J].InstChars[K].Chars[K2];
            Found := True;
            Break;
          end;
        if not Found then
          for K := 1 to FTabBars[J].Steps do
            Line := Line + '.';
      end;
      SL.Add(Line);
    end;

    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TMainForm.btnSavePatternAsClick(Sender: TObject);
var
  SelLeft, SelRight, SelTop, SelBottom, J, K, BarIdx, StepInBar:
    Integer;
  SL: TStringList;
  Header, Line, StyleName, KindName: string;
  InstAbbr: string;
  Col, Row: Integer;
  CumSteps: Integer;
  OutFile: string;
  Valid: Boolean;
begin
  if Length(FTabBars) = 0 then
  begin
    UpdateStatus('No MIDI data loaded. Load a file first.');
    Exit;
  end;

  SelLeft := sgTab.Selection.Left;
  SelRight := sgTab.Selection.Right;
  SelTop := sgTab.Selection.Top;
  SelBottom := sgTab.Selection.Bottom;

  if SelLeft > SelRight then J := SelLeft else J := SelRight;
  SelLeft := Min(SelLeft, SelRight);
  SelRight := Max(J, SelLeft);

  if SelTop > SelBottom then J := SelTop else J := SelBottom;
  SelTop := Min(SelTop, SelBottom);
  SelBottom := Max(J, SelTop);

  if SelRight < 1 then
  begin
    UpdateStatus('Please select grid cells (data columns only).');
    Exit;
  end;

  if radFill.Checked then
    Header := Format('[%s energy=%s]', ['custom', cbEnergy.Items[cbEnergy.ItemIndex]])
  else
  begin
    StyleName := 'midi';
    KindName := 'verse';
    if cbStyle.ItemIndex >= 0 then
      StyleName := GetStyleNameFromItem(cbStyle.Items[cbStyle.ItemIndex]);
    if cbKind.ItemIndex >= 0 then
      KindName := cbKind.Items[cbKind.ItemIndex];
    Header := Format('[%s %s intensity=0.2-0.6]', [StyleName, KindName]);
  end;

  SL := TStringList.Create;
  try
    SL.Add(Header);

    for Row := SelTop to SelBottom do
    begin
      InstAbbr := FInstOrder[Row];
      if InstAbbr = '' then Continue;

      Line := InstAbbr;
      for K := 1 to 4 - Length(InstAbbr) do Line := Line + ' ';
      if Length(Line) < 4 then Line := Line + ' ';
      Line := Line + '  ';

      CumSteps := 0;
      for BarIdx := FCurPage * FPageSize to Min(FCurPage * FPageSize + FPageSize,
        Length(FTabBars)) - 1 do
      begin
        if BarIdx > 0 then Line := Line + ' | ';
        for Col := SelLeft to SelRight do
        begin
          if (Col >= 1) and (Col <= CumSteps + FTabBars[BarIdx].Steps) then
          begin
            StepInBar := Col - CumSteps - 1;
            for K := 0 to High(FTabBars[BarIdx].InstChars) do
              if FTabBars[BarIdx].InstChars[K].Abbr = InstAbbr then
              begin
                if (StepInBar >= 0) and
                   (StepInBar < Length(
                    FTabBars[BarIdx].InstChars[K].Chars)) then
                  Line := Line +
                    FTabBars[BarIdx].InstChars[K].Chars[StepInBar]
                else
                  Line := Line + '.';
                Break;
              end;
          end
          else
            Line := Line + '.';
        end;
        CumSteps := CumSteps + FTabBars[BarIdx].Steps;
      end;
      SL.Add(Line);
    end;

  if radFill.Checked then
    OutFile := IncludeTrailingPathDelimiter(FOutputDir) + 'fills' +
      IncludeTrailingPathDelimiter(GetStyleNameFromItem(cbStyle.Items[cbStyle.ItemIndex])) + '.tab'
  else if radGroove.Checked then
    OutFile := IncludeTrailingPathDelimiter(FOutputDir) + 'grooves' +
      IncludeTrailingPathDelimiter(GetStyleNameFromItem(cbStyle.Items[cbStyle.ItemIndex])) + '.tab'
  else
  begin
    UpdateStatus('Please select Groove or Fill mode.');
    Exit;
  end;

    Valid := True;
    if not DirectoryExists(OutFile) then
      Valid := CreateDir(OutFile);

    if Valid then
    begin
      OutFile := IncludeTrailingPathDelimiter(OutFile) + 'custom.tab';
      SL.SaveToFile(OutFile, TEncoding.UTF8);
      UpdateStatus('Pattern saved to: ' + OutFile);
    end
    else
      UpdateStatus('Failed to create directory: ' + OutFile);
  finally
    SL.Free;
  end;
end;

procedure TMainForm.LoadGrooveList;
var
  SL: TStringList;
  I: Integer;
  Line: string;
  StyleFile: string;
begin
  cbStyle.Items.Clear;
  StyleFile := ExpandFileName(IncludeTrailingPathDelimiter(FOutputDir) + 'styles.txt');
  if not FileExists(StyleFile) then
  begin
    cbStyle.Items.Add('(none yet)');
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(StyleFile);
    for I := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[I]);
      if (Line = '') or (Line[1] = '#') then Continue;
      cbStyle.Items.Add(Line);
    end;
  finally
    SL.Free;
  end;

  if cbStyle.Items.Count = 0 then
    cbStyle.Items.Add('(none yet)');
  if cbStyle.ItemIndex < 0 then
    cbStyle.ItemIndex := 0;
end;



function TMainForm.GetStyleNameFromItem(const AItem: string): string;
var
  P: Integer;
begin
  Result := AItem;
  P := Pos(' ', AItem);
  if P > 0 then
    Result := Copy(AItem, P + 1, MaxInt);
end;

procedure TMainForm.LoadDrummerList;
var
  Files: TStringList;
  I: Integer;
  FName, Base: string;
  FillDir: string;
begin
  cbStyle.Items.Clear;
  FillDir := IncludeTrailingPathDelimiter(FOutputDir) + 'fills';
  if not DirectoryExists(FillDir) then
  begin
    CreateDir(FillDir);
    cbStyle.Items.Add('(none yet)');
    Exit;
  end;

  Files := TStringList.Create;
  try
    FindAllFiles(Files, FillDir, '*.tab', False);
    for I := 0 to Files.Count - 1 do
    begin
      FName := ExtractFileName(Files[I]);
      Base := ChangeFileExt(FName, '');
      cbStyle.Items.Add(Base);
    end;
  finally
    Files.Free;
  end;

  if cbStyle.Items.Count = 0 then
    cbStyle.Items.Add('(none yet)');
  if cbStyle.ItemIndex < 0 then
    cbStyle.ItemIndex := 0;
end;

procedure TMainForm.LoadKindList;
begin
  cbKind.Items.Clear;
  cbKind.Items.Add('verse');
  cbKind.Items.Add('chorus');
  cbKind.Items.Add('bridge');
  cbKind.Items.Add('intro');
  cbKind.Items.Add('outro');
  cbKind.Items.Add('fill');

  if cbKind.ItemIndex < 0 then
    cbKind.ItemIndex := 0;
end;

{$IFDEF MSWINDOWS}
procedure TMainForm.ApplyDarkTheme(ADark: Boolean);
begin
  FDark := ADark;
  ApplyTheme(Self, FDark);
  ThemeControlTree(Self, FDark);
  // Update combo boxes for owner-draw
  cbMapping.Style := csOwnerDrawFixed;
  cbStyle.Style := csOwnerDrawFixed;
  cbKind.Style := csOwnerDrawFixed;
  cbResolution.Style := csOwnerDrawFixed;
  cbMeter.Style := csOwnerDrawFixed;
  cbIntensity.Style := csOwnerDrawFixed;
  cbEnergy.Style := csOwnerDrawFixed;
  cbZoom.Style := csOwnerDrawFixed;
  cbMapping.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbStyle.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbKind.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbResolution.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbMeter.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbIntensity.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbEnergy.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbZoom.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
  cbMapping.OnDropDown := @ComboBoxDropDown;
  cbStyle.OnDropDown := @ComboBoxDropDown;
  cbKind.OnDropDown := @ComboBoxDropDown;
  cbResolution.OnDropDown := @ComboBoxDropDown;
  cbMeter.OnDropDown := @ComboBoxDropDown;
  cbIntensity.OnDropDown := @ComboBoxDropDown;
  cbEnergy.OnDropDown := @ComboBoxDropDown;
  cbZoom.OnDropDown := @ComboBoxDropDown;
end;

procedure TMainForm.ComboBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  CB: TComboBox;
  S: string;
begin
  CB := Control as TComboBox;
  with CB.Canvas do
  begin
    if FDark then
    begin
      if odSelected in State then
      begin
        Brush.Color := $404040;
        Font.Color := clWhite;
      end
      else
      begin
        Brush.Color := $2D2D2D;
        Font.Color := clWhite;
      end;
    end
    else
    begin
      if odSelected in State then
      begin
        Brush.Color := clHighlight;
        Font.Color := clHighlightText;
      end
      else
      begin
        Brush.Color := clWindow;
        Font.Color := clWindowText;
      end;
    end;
    FillRect(ARect);
    if Index >= 0 then
    begin
      S := CB.Items[Index];
      TextOut(ARect.Left + 2, ARect.Top + 1, S);
    end;
  end;
end;

procedure TMainForm.ComboBoxDropDown(Sender: TObject);
var
  CB: TComboBox;
  ListHandle: HWND;
begin
  if not FDark then Exit;
  CB := Sender as TComboBox;
  ListHandle := FindWindowEx(CB.Handle, 0, 'LCLLISTBOX', nil);
  if ListHandle = 0 then
    ListHandle := FindWindowEx(CB.Handle, 0, 'TListBox', nil);
  if ListHandle = 0 then
    ListHandle := GetWindow(CB.Handle, GW_CHILD);
  if ListHandle <> 0 then
  begin
    SetWindowLong(ListHandle, GWL_STYLE, GetWindowLong(ListHandle, GWL_STYLE) or WS_BORDER);
    SetWindowPos(ListHandle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_FRAMECHANGED);
    SendMessage(ListHandle, WM_ERASEBKGND, 0, 0);
    InvalidateRect(ListHandle, nil, True);
    SendMessage(ListHandle, LB_SETITEMHEIGHT, 0, 20);
  end;
end;
{$ENDIF}
{$IFDEF MSWINDOWS}
procedure TMainForm.SystemThemeChanged(Sender: TObject);
begin
  { Windows switched between light and dark apps: follow it when asked to. }
  ApplyDarkTheme(ResolveDark(LoadThemeChoice));
end;
{$ENDIF}

end.
