unit MainFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Dialogs,
  Grids, FileUtil, Process, Math;

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
    pnlTop: TPanel;
    lblInput: TLabel;
    edInput: TEdit;
    btnBrowseInput: TButton;
    lblOutputDir: TLabel;
    edOutputDir: TEdit;
    btnBrowseOutput: TButton;

    pnlParams: TPanel;
    lblMapping: TLabel;
    cbMapping: TComboBox;
    lblStyle: TLabel;
    edStyle: TEdit;
    lblKind: TLabel;
    edKind: TEdit;
    lblIntensity: TLabel;
    edIntensity: TEdit;
    lblResolution: TLabel;
    cbResolution: TComboBox;
    lblMeter: TLabel;
    edMeter: TEdit;
    chkFill: TCheckBox;
    edFillName: TEdit;
    edFillEnergy: TEdit;
    chkAddGroove: TCheckBox;
    edGrooveGenre: TEdit;
    chkAddFill: TCheckBox;
    edFillDrummer: TEdit;

    pnlEditor: TPanel;
    lblEditor: TLabel;
    sgTab: TStringGrid;
    pnlGridControls: TPanel;
    lblZoom: TLabel;
    cbZoom: TComboBox;
    btnPrevPage: TButton;
    btnNextPage: TButton;
    lblPageInfo: TLabel;

    pnlBottom: TPanel;
    btnConvert: TButton;
    btnExportGroove: TButton;
    btnExportFill: TButton;
    btnSplitPattern: TButton;
    memStatus: TMemo;
    sbStatus: TStatusBar;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnBrowseInputClick(Sender: TObject);
    procedure btnBrowseOutputClick(Sender: TObject);
    procedure edInputChange(Sender: TObject);
    procedure btnConvertClick(Sender: TObject);
    procedure btnExportGrooveClick(Sender: TObject);
    procedure btnExportFillClick(Sender: TObject);
    procedure btnSplitPatternClick(Sender: TObject);
    procedure sgTabSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
    procedure sgTabClick(Sender: TObject);
    procedure cbZoomChange(Sender: TObject);
    procedure btnPrevPageClick(Sender: TObject);
    procedure btnNextPageClick(Sender: TObject);
    procedure cbMappingChange(Sender: TObject);
    procedure chkFillChange(Sender: TObject);
    procedure chkAddGrooveChange(Sender: TObject);
    procedure chkAddFillChange(Sender: TObject);

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

    procedure LoadMidiAndConvert;
    procedure ParseTabOutput(const ATabText: string);
    procedure RefreshGrid;
    procedure RenderPage(APage: Integer);
    procedure ToggleCell(ACol, ARow: Integer);
    function CharToStepChar(C: Char): TStepChar;
    function StepCharToChar(SC: TStepChar): Char;
    procedure UpdateStatus(const AMsg: string);
    function RunMidiToTab(const AArgs: array of string): string;
    procedure UpdatePageInfo;
    procedure UpdateControls;
    function BuildTabText: string;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInputPath := '';
  FOutputDir := '';
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
  sgTab.FixedRows := 0;
  sgTab.Options := sgTab.Options + [goRowSelect];
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

  edOutputDir.Text := GetCurrentDir + PathDelim + 'config';
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
    OD.Filter := 'MIDI files (*.mid;*.midi)|*.mid;*.midi|All files (*.*)|*.*';
    OD.DefaultExt := 'mid';
    if OD.Execute then
    begin
      edInput.Text := OD.FileName;
      FInputPath := OD.FileName;
    end;
  finally
    OD.Free;
  end;
end;

procedure TMainForm.btnBrowseOutputClick(Sender: TObject);
var
  SD: TSelectDirectoryDialog;
begin
  SD := TSelectDirectoryDialog.Create(nil);
  try
    SD.Title := 'Select output directory';
    SD.InitialDir := edOutputDir.Text;
    if SD.Execute then
      edOutputDir.Text := SD.FileName;
  finally
    SD.Free;
  end;
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
  OutPath: string;
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

  OutPath := FOutputDir + PathDelim + 'temp_convert.tab';
  SetLength(Args, Length(Args) + 1);
  Args[High(Args)] := OutPath;

  if cbMapping.ItemIndex > 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--mapping';
    Args[High(Args)] := 'mappings/' + cbMapping.Items[cbMapping.ItemIndex] + '.json';
  end;

  if edStyle.Text <> '' then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--style';
    Args[High(Args)] := edStyle.Text;
  end;

  if edKind.Text <> '' then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--kind';
    Args[High(Args)] := edKind.Text;
  end;

  if edIntensity.Text <> '' then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--intensity';
    Args[High(Args)] := edIntensity.Text;
  end;

  if cbResolution.ItemIndex >= 0 then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--resolution';
    Args[High(Args)] := cbResolution.Items[cbResolution.ItemIndex];
    FResolution := StrToIntDef(cbResolution.Items[cbResolution.ItemIndex], 16);
  end;

  if edMeter.Text <> '' then
  begin
    SetLength(Args, Length(Args) + 2);
    Args[High(Args) - 1] := '--meter';
    Args[High(Args)] := edMeter.Text;
  end;

  if chkFill.Checked then
  begin
    SetLength(Args, Length(Args) + 1);
    Args[High(Args)] := '--fill';
    if edFillName.Text <> '' then
    begin
      SetLength(Args, Length(Args) + 2);
      Args[High(Args) - 1] := '--name';
      Args[High(Args)] := edFillName.Text;
    end;
    if edFillEnergy.Text <> '' then
    begin
      SetLength(Args, Length(Args) + 2);
      Args[High(Args) - 1] := '--energy';
      Args[High(Args)] := edFillEnergy.Text;
    end;
  end;

  MidiToTab := GetCurrentDir + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
    MidiToTab := GetCurrentDir + PathDelim + '..' + PathDelim + 'midi_to_tab.exe';
  if not FileExists(MidiToTab) then
  begin
    UpdateStatus('midi_to_tab.exe not found. Build it first.');
    Exit;
  end;

  SetLength(Args, Length(Args) + 1);
  for I := High(Args) downto 1 do
    Args[I] := Args[I - 1];
  Args[0] := MidiToTab;
  ResultStr := RunMidiToTab(Args);
  if ResultStr = '' then
  begin
    UpdateStatus('Conversion failed.');
    Exit;
  end;

  FTabData := ResultStr;
  ParseTabOutput(FTabData);
  RefreshGrid;
  UpdateStatus('Converted: ' + IntToStr(Length(FTabBars)) + ' bars, ' +
    IntToStr(FStepsPerBar) + ' steps/bar, ' + IntToStr(FResolution) + ' resolution.');
end;

function TMainForm.RunMidiToTab(const AArgs: array of string): string;
var
  Proc: TProcess;
  SL: TStringList;
  I: Integer;
begin
  Result := '';
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AArgs[0];
    for I := 1 to High(AArgs) do
      Proc.Parameters.Add(AArgs[I]);
    Proc.Options := Proc.Options + [poWaitOnExit, poUsePipes];
    Proc.Execute;

    SL := TStringList.Create;
    try
      SL.LoadFromStream(Proc.Output);
      Result := SL.Text;
    finally
      SL.Free;
    end;
  finally
    Proc.Free;
  end;
end;

procedure TMainForm.ParseTabOutput(const ATabText: string);
var
  Lines: TStringList;
  Bars: TStringList;
  I, J, K, BarIdx, CharIdx: Integer;
  Line: string;
  Inst: string;
  GridStr: string;
  BarStr: string;
begin
  FTabBars := nil;
  Lines := TStringList.Create;
  Bars := TStringList.Create;
  try
    Lines.Text := ATabText;

    I := 0;
    if Lines.Count > 0 then
      I := 1;

    while I < Lines.Count do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then
      begin
        Inc(I);
        Continue;
      end;

      Inst := Trim(Copy(Line, 1, 4));
      GridStr := Trim(Copy(Line, 6, MaxInt));

      Bars.Clear;
      Bars.StrictDelimiter := True;
      Bars.Delimiter := '|';
      Bars.DelimitedText := GridStr;

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
          for K := 0 to CharIdx - 1 do
            FTabBars[BarIdx].InstChars[J].Chars[K] := '.';
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
      end;

      Inc(I);
    end;

    if Length(FTabBars) > 0 then
      FStepsPerBar := FTabBars[0].Steps
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

  sgTab.ColCount := ColIdx;
  sgTab.RowCount := Length(FInstOrder);

  for RowIdx := 0 to High(FInstOrder) do
    sgTab.Cells[0, RowIdx] := FInstOrder[RowIdx];

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
            sgTab.Cells[ColIdx, RowIdx] := FTabBars[BarIdx].InstChars[J].Chars[K];
            Found := True;
            Break;
          end;
        if not Found then
          sgTab.Cells[ColIdx, RowIdx] := '.';
      end;
      Inc(ColIdx);
    end;
  end;

  sgTab.ColWidths[0] := 40;
  for ColIdx := 1 to sgTab.ColCount - 1 do
    sgTab.ColWidths[ColIdx] := 20;
end;

procedure TMainForm.ToggleCell(ACol, ARow: Integer);
var
  C: Char;
  SC: TStepChar;
begin
  if (ACol < 1) or (ARow < 0) or (ACol >= sgTab.ColCount) or (ARow >= sgTab.RowCount) then
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
  if C = '.' then Result := scDot
  else if C = 'x' then Result := scX
  else if C = 'X' then Result := scAccent
  else if C = 'o' then Result := scSoft
  else if C = 'g' then Result := scGhost
  else Result := scDot;
end;

function TMainForm.StepCharToChar(SC: TStepChar): Char;
begin
  if SC = scDot then Result := '.'
  else if SC = scX then Result := 'x'
  else if SC = scAccent then Result := 'X'
  else if SC = scSoft then Result := 'o'
  else if SC = scGhost then Result := 'g'
  else Result := '.';
end;

procedure TMainForm.sgTabSelectCell(Sender: TObject; aCol, aRow: Integer;
  var CanSelect: Boolean);
begin
  CanSelect := (aCol > 0) and (aRow >= 0);
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
    UpdatePageInfo;
  end;
end;

procedure TMainForm.btnNextPageClick(Sender: TObject);
begin
  if FCurPage < FTotalPages - 1 then
  begin
    Inc(FCurPage);
    RenderPage(FCurPage);
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
  btnNextPage.Enabled := FCurPage < FTotalPages - 1;
  btnExportGroove.Enabled := Length(FTabBars) > 0;
  btnExportFill.Enabled := Length(FTabBars) > 0;
  btnSplitPattern.Enabled := Length(FTabBars) > 0;
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
  edFillName.Enabled := chkFill.Checked;
  edFillEnergy.Enabled := chkFill.Checked;
end;

procedure TMainForm.chkAddGrooveChange(Sender: TObject);
begin
  edGrooveGenre.Enabled := chkAddGroove.Checked;
end;

procedure TMainForm.chkAddFillChange(Sender: TObject);
begin
  edFillDrummer.Enabled := chkAddFill.Checked;
end;

procedure TMainForm.btnConvertClick(Sender: TObject);
begin
  LoadMidiAndConvert;
end;

procedure TMainForm.btnExportGrooveClick(Sender: TObject);
var
  Genre: string;
  OutPath: string;
  SL: TStringList;
begin
  if Length(FTabBars) = 0 then
  begin
    UpdateStatus('No tab data to export.');
    Exit;
  end;

  Genre := edGrooveGenre.Text;
  if Genre = '' then
  begin
    UpdateStatus('Please enter a genre name.');
    Exit;
  end;

  OutPath := FOutputDir + PathDelim + 'grooves' + PathDelim + Genre + '.tab';
  if not DirectoryExists(FOutputDir + PathDelim + 'grooves') then
    CreateDir(FOutputDir + PathDelim + 'grooves');

  SL := TStringList.Create;
  try
    SL.Text := BuildTabText;
    if FileExists(OutPath) then
      SL.LoadFromFile(OutPath);
    SL.Add('');
    SL.Add(BuildTabText);
    SL.SaveToFile(OutPath);
  finally
    SL.Free;
  end;
  UpdateStatus('Exported groove to: ' + OutPath);
end;

procedure TMainForm.btnExportFillClick(Sender: TObject);
var
  Drummer: string;
  OutPath: string;
  SL: TStringList;
begin
  if Length(FTabBars) = 0 then
  begin
    UpdateStatus('No tab data to export.');
    Exit;
  end;

  Drummer := edFillDrummer.Text;
  if Drummer = '' then
  begin
    UpdateStatus('Please enter a drummer name.');
    Exit;
  end;

  OutPath := FOutputDir + PathDelim + 'fills' + PathDelim + Drummer + '.tab';
  if not DirectoryExists(FOutputDir + PathDelim + 'fills') then
    CreateDir(FOutputDir + PathDelim + 'fills');

  SL := TStringList.Create;
  try
    SL.Text := BuildTabText;
    if FileExists(OutPath) then
      SL.LoadFromFile(OutPath);
    SL.Add('');
    SL.Add(BuildTabText);
    SL.SaveToFile(OutPath);
  finally
    SL.Free;
  end;
  UpdateStatus('Exported fill to: ' + OutPath);
end;

function TMainForm.BuildTabText: string;
var
  SL: TStringList;
  I, J, K, K2: Integer;
  Header: string;
  Style: string;
  Kind: string;
  Line: string;
  Found: Boolean;
begin
  SL := TStringList.Create;
  try
    if chkFill.Checked then
      Header := Format('[%s energy=%s]', [edFillName.Text, edFillEnergy.Text])
    else
    begin
      Style := edStyle.Text;
      Kind := edKind.Text;
      if Style = '' then Style := 'midi';
      if Kind = '' then Kind := 'verse';
      Header := Format('[%s %s intensity=0.2-0.6]', [Style, Kind]);
    end;
    SL.Add(Header);

    for I := 0 to High(FInstOrder) do
    begin
      Line := FInstOrder[I];
      for K2 := 1 to 4 - Length(FInstOrder[I]) do Line := Line + '.';
      if Length(Line) < 4 then Line := Line + ' ';
      Line := Line + '  ';

      for J := 0 to High(FTabBars) do
      begin
        if J > 0 then Line := Line + ' | ';
        Found := False;
        for K := 0 to High(FTabBars[J].InstChars) do
          if FTabBars[J].InstChars[K].Abbr = FInstOrder[I] then
          begin
            for K2 := 0 to High(FTabBars[J].InstChars[K].Chars) do Line := Line + FTabBars[J].InstChars[K].Chars[K2];
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

procedure TMainForm.btnSplitPatternClick(Sender: TObject);
begin
  UpdateStatus('Pattern splitting not yet implemented.');
end;

end.
