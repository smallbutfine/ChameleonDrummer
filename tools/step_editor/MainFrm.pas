unit MainFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Dialogs,
  Grids, FileUtil, Process, Math, {$IFDEF MSWINDOWS}DarkTheme, Windows,{$ENDIF} Graphics,
  AutoScale;

type
  TStepChar = (scDot, scX, scAccent, scSoft, scGhost);

  TTabBar = record
    Steps: Integer;
    Meter: string;
    InstChars: array of record
      Abbr: string;
      Chars: array of Char;
    end;
  end;

  TTabBarArray = array of TTabBar;

  TTabBlock = record
    Header: string;
    Style, Kind: string;
    IntensityLow, IntensityHigh: Double;
    Meter: string;
    Bars: TTabBarArray;
    SourceFile: string;
    BlockIndex: Integer;
    LineStart, LineEnd: Integer;
    Modified: Boolean;
  end;

  TTabBlocks = array of TTabBlock;

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
    lblHeaderPreview: TLabel;

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
    procedure cbMappingChange(Sender: TObject);
    procedure chkFillChange(Sender: TObject);
    procedure rbModeChange(Sender: TObject);
    procedure cbMeterChange(Sender: TObject);
    procedure cbIntensityChange(Sender: TObject);
    procedure cbEnergyChange(Sender: TObject);
    procedure cbStyleChange(Sender: TObject);
    procedure cbKindChange(Sender: TObject);

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
    FAutoScaler: TWindowAutoScaler;
    FInThemeApply: Boolean;

    // Tab block management
    FTabBlocks: TTabBlocks;
    FSelectedBlock: Integer;
    FIsConfigFile: Boolean;
    FBlockModified: Boolean;

    // UI controls for block navigation
    cbTabSelector: TComboBox;
    btnTabPrev: TButton;
    btnTabNext: TButton;
    lblTabPosition: TLabel;
    edBlockStyle: TEdit;
    edBlockKind: TEdit;
    edIntensityLow: TEdit;
    edIntensityHigh: TEdit;
    btnSaveBlock: TButton;
    btnNewBlock: TButton;
    btnDeleteBlock: TButton;


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
    procedure UpdateControls;
    function BuildTabText: string;
    procedure LoadKindList;
    procedure LoadGrooveList;
    procedure LoadDrummerList;
    procedure UpdateHeaderPreview;
    {$IFDEF MSWINDOWS}procedure ApplyDarkTheme(ADark: Boolean);
    procedure ComboBoxDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);{$ENDIF}
    procedure ComboBoxDropDown(Sender: TObject);
    {$IFDEF MSWINDOWS}procedure SystemThemeChanged(Sender: TObject);{$ENDIF}
    {$IFDEF MSWINDOWS}procedure StatusBarDrawPanel(Sender: TStatusBar; Panel: TStatusPanel;
      const Rect: TRect);{$ENDIF}
    {$IFDEF MSWINDOWS}procedure sgTabDrawCell(Sender: TObject; ACol, ARow: Integer;
      ARect: TRect; AState: TGridDrawState);{$ENDIF}

    // Tab block methods (cross-platform)
    function IsConfigTabFile(const AFileName: string): Boolean;
    procedure ParseConfigTabFile(const AFileName: string);
    procedure ParseForeignTabFile(const AFileName: string);
    procedure ParseHeader(const ALine: string; var ABlock: TTabBlock);
    procedure AddInstrumentLineToBlock(const ALine: string; var ABlock: TTabBlock);
    function BuildBlockText(const ABlock: TTabBlock): string;
    procedure SetupBlockNavigationUI;
    procedure UpdateBlockNavigationUI;
    procedure UpdateHeaderFields;
    procedure cbTabSelectorChange(Sender: TObject);
    procedure btnTabPrevClick(Sender: TObject);
    procedure btnTabNextClick(Sender: TObject);
    procedure btnSaveBlockClick(Sender: TObject);
    procedure btnNewBlockClick(Sender: TObject);
    procedure btnDeleteBlockClick(Sender: TObject);
    procedure SurgicalSaveBlock;
    procedure MarkBlockModified(Sender: TObject);

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
  FOutputDir := ExtractFilePath(ParamStr(0))+ PathDelim + '..' + PathDelim +  'config';
  FTabData := '';
  FTabBars := nil;
  FTabBlocks := nil;
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
  sgTab.Options := sgTab.Options - [goRowSelect, goVertLine] + [goRangeSelect, goAlwaysShowEditor];
  sgTab.OnSelectCell := @sgTabSelectCell;
  sgTab.OnClick := @sgTabClick;
  {$IFDEF MSWINDOWS}sgTab.OnDrawCell := @sgTabDrawCell;{$ENDIF}
  sbStatus.SimplePanel := False;
  {$IFDEF MSWINDOWS}sbStatus.OnDrawPanel := @StatusBarDrawPanel;{$ENDIF}
  sbStatus.Panels[0].Style := psOwnerDraw;

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

  // Populate meter combobox with common time signatures (append T for triplet feel)
  cbMeter.Items.Clear;
  cbMeter.Items.CommaText := '4/4,4/4T,2/4,2/4T,3/4,3/4T,5/4,5/4T,6/8,6/8T,7/8,7/8T,9/8,9/8T,11/8,11/8T,13/8,13/8T,15/16,15/16T';
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
  {$IFDEF MSWINDOWS}ThemeControlTree(Self, FDark);{$ENDIF}
  sbStatus.Panels[0].Text := 'Ready';
  UpdateHeaderPreview;

  // Initialize export genre/drummer lists after output dir is set
  // (must run after ApplyDarkTheme, which sets cbStyle.Style and can clear items)
  if radGroove.Checked then
    LoadGrooveList
  else
    LoadDrummerList;

  FAutoScaler := TWindowAutoScaler.Create(Self);
  SetupBlockNavigationUI;
  {$IFDEF MSWINDOWS}ThemeControlTree(Self, FDark);{$ENDIF}
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FAutoScaler.Free;
  {$IFDEF MSWINDOWS}
  UnhookForm(Handle);
  {$ENDIF}
  FTabBars := nil;
  FTabBlocks := nil;
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

function MeterToSteps(const AMeter: string; AResolution: Integer): Integer;
var
  P: Integer;
  Num, Den: Integer;
  ATriplet: Boolean;
  AMeterBase: string;
begin
  ATriplet := False;
  AMeterBase := AMeter;
  if (Length(AMeter) > 0) and (AMeter[Length(AMeter)] = 'T') then
  begin
    ATriplet := True;
    AMeterBase := Copy(AMeter, 1, Length(AMeter) - 1);
  end;
  P := Pos('/', AMeterBase);
  if P > 0 then
  begin
    Num := StrToIntDef(Trim(Copy(AMeterBase, 1, P - 1)), 0);
    Den := StrToIntDef(Trim(Copy(AMeterBase, P + 1, MaxInt)), 0);
    if Den > 0 then
    begin
      Result := Num * AResolution div Den;
      if ATriplet then
        Result := Result * 3 div 2;
    end
    else
      Result := AResolution;
  end
  else
    Result := AResolution;
end;

procedure TMainForm.btnNewPatternClick(Sender: TObject);
var
  I, K, OldCount, ASteps: Integer;
begin
  OldCount := Length(FTabBars);
  ASteps := MeterToSteps(cbMeter.Text, FResolution);
  SetLength(FTabBars, OldCount + 1);
  FTabBars[OldCount].Steps := ASteps;
  FTabBars[OldCount].Meter := cbMeter.Text;
  SetLength(FTabBars[OldCount].InstChars, Length(FInstOrder));
  for I := 0 to High(FInstOrder) do
  begin
    FTabBars[OldCount].InstChars[I].Abbr := FInstOrder[I];
    SetLength(FTabBars[OldCount].InstChars[I].Chars, ASteps);
    for K := 0 to ASteps - 1 do
      FTabBars[OldCount].InstChars[I].Chars[K] := '.';
  end;
  FStepsPerBar := ASteps;
  RefreshGrid;
  UpdateStatus('Pattern added: ' + IntToStr(ASteps) + ' steps/bar (' + cbMeter.Text + '), ' + IntToStr(Length(FInstOrder)) + ' instruments. Total bars: ' + IntToStr(Length(FTabBars)));
  UpdateHeaderPreview;
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

procedure TMainForm.ParseHeader(const ALine: string; var ABlock: TTabBlock);
var
  Content: string;
  Parts: TStringList;
  IntensityPart: string;
  P: Integer;
begin
  Content := Trim(ALine);
  if (Length(Content) < 3) or (Content[1] <> '[') or (Content[Length(Content)] <> ']') then Exit;
  Content := Copy(Content, 2, Length(Content) - 2);

  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ' ';
    Parts.DelimitedText := Content;

    if Parts.Count >= 2 then begin
      ABlock.Style := Parts[0];
      ABlock.Kind := Parts[1];
    end;

    for P := 2 to Parts.Count - 1 do begin
      if Pos('intensity=', Parts[P]) = 1 then begin
        IntensityPart := Copy(Parts[P], 11, MaxInt);
        Parts.Delimiter := '-';
        Parts.StrictDelimiter := True;
        Parts.DelimitedText := IntensityPart;
        if Parts.Count >= 2 then begin
          ABlock.IntensityLow := StrToFloatDef(Parts[0], 0.0);
          ABlock.IntensityHigh := StrToFloatDef(Parts[1], 1.0);
        end;
        Break;
      end;
    end;
  finally
    Parts.Free;
  end;
end;

procedure TMainForm.AddInstrumentLineToBlock(const ALine: string; var ABlock: TTabBlock);
var
  Lines: TStringList;
  Bars: TStringList;
  I, J, K, BarIdx, CharIdx, MaxSteps: Integer;
  Line: string;
  Inst: string;
  GridStr: string;
  BarStr: string;
begin
  MaxSteps := 0;
  Lines := TStringList.Create;
  Bars := TStringList.Create;
  try
    Line := Trim(ALine);
    if Line = '' then Exit;

    Inst := Copy(Line, 1, MaxInt);
    J := 1;
    while (J <= Length(Inst)) and (Inst[J] = ' ') do Inc(J);
    K := J;
    while (K <= Length(Inst)) and (Inst[K] <> ' ') do Inc(K);
    Inst := Copy(Inst, J, K - J);

    GridStr := Trim(Copy(Line, K + 1, MaxInt));
    if GridStr = '' then Exit;

    Bars.Clear;
    if Pos('|', GridStr) > 0 then
    begin
      Bars.StrictDelimiter := True;
      Bars.Delimiter := '|';
      Bars.DelimitedText := GridStr;
    end
    else
    begin
      Bars.Add(GridStr);
    end;

    while Length(ABlock.Bars) < Bars.Count do
    begin
      J := Length(ABlock.Bars);
      SetLength(ABlock.Bars, J + 1);
      ABlock.Bars[J].Steps := 0;
      ABlock.Bars[J].Meter := ABlock.Meter;
      ABlock.Bars[J].InstChars := nil;
    end;

    for BarIdx := 0 to Bars.Count - 1 do
    begin
      BarStr := Trim(Bars[BarIdx]);
      CharIdx := 0;
      for K := 1 to Length(BarStr) do
        if BarStr[K] <> ' ' then
          Inc(CharIdx);

      J := -1;
      for K := 0 to High(ABlock.Bars[BarIdx].InstChars) do
        if ABlock.Bars[BarIdx].InstChars[K].Abbr = Inst then
        begin
          J := K;
          Break;
        end;

      if J = -1 then
      begin
        J := Length(ABlock.Bars[BarIdx].InstChars);
        SetLength(ABlock.Bars[BarIdx].InstChars, J + 1);
        ABlock.Bars[BarIdx].InstChars[J].Abbr := Inst;
        SetLength(ABlock.Bars[BarIdx].InstChars[J].Chars, CharIdx);
        FillChar(ABlock.Bars[BarIdx].InstChars[J].Chars[0], CharIdx, '.');
      end;

      CharIdx := 0;
      for K := 1 to Length(BarStr) do
        if BarStr[K] <> ' ' then
        begin
          if CharIdx < Length(ABlock.Bars[BarIdx].InstChars[J].Chars) then
            ABlock.Bars[BarIdx].InstChars[J].Chars[CharIdx] := BarStr[K];
          Inc(CharIdx);
        end;

      ABlock.Bars[BarIdx].Steps := CharIdx;
      if CharIdx > MaxSteps then MaxSteps := CharIdx;
    end;

    if Length(ABlock.Bars) > 0 then
      FStepsPerBar := MaxSteps
    else
      FStepsPerBar := FResolution;

  finally
    Lines.Free;
    Bars.Free;
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
  FTabBlocks := nil;
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
        FTabBars[J].Meter := cbMeter.Text;
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
  if FIsConfigFile then
    FTotalPages := Max(1, (Length(FTabBlocks[FSelectedBlock].Bars) + FPageSize - 1) div FPageSize)
  else
    FTotalPages := Max(1, (Length(FTabBars) + FPageSize - 1) div FPageSize);
  RenderPage(FCurPage);
  UpdateControls;
end;

procedure TMainForm.RenderPage(APage: Integer);
var
  StartBar, EndBar, BarIdx, ColIdx, RowIdx, K, BSteps, J: Integer;
  Found: Boolean;
  Bars: TTabBarArray;
begin
  if FIsConfigFile then begin
    if (FSelectedBlock < 0) or (FSelectedBlock >= Length(FTabBlocks)) then Exit;
    Bars := FTabBlocks[FSelectedBlock].Bars;
  end else begin
    if Length(FTabBars) = 0 then Exit;
    Bars := FTabBars;
  end;

  StartBar := APage * FPageSize;
  EndBar := Min(StartBar + FPageSize, Length(Bars));

  ColIdx := 1;
  for BarIdx := StartBar to EndBar - 1 do
    ColIdx := ColIdx + Bars[BarIdx].Steps;

  sgTab.ColCount := ColIdx;
  sgTab.RowCount := Length(FInstOrder) + 1;

  for RowIdx := 0 to High(FInstOrder) do
    sgTab.Cells[0, RowIdx + 1] := FInstOrder[RowIdx];

  ColIdx := 1;
  for BarIdx := StartBar to EndBar - 1 do
  begin
    BSteps := Bars[BarIdx].Steps;
    for K := 0 to BSteps - 1 do
    begin
      sgTab.Cells[ColIdx, 0] := IntToStr(K + 1);
      for RowIdx := 0 to High(FInstOrder) do
      begin
        Found := False;
        for J := 0 to High(Bars[BarIdx].InstChars) do
          if Bars[BarIdx].InstChars[J].Abbr = FInstOrder[RowIdx] then
          begin
            sgTab.Cells[ColIdx, RowIdx + 1] := Bars[BarIdx].InstChars[J].Chars[K];
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

  UpdateHeaderPreview;
end;

procedure TMainForm.ToggleCell(ACol, ARow: Integer);
var
  C: Char;
  SC: TStepChar;
  BarIdx, StepInBar, CumSteps, RowIdx, J: Integer;
  Bars: TTabBarArray;
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

  // Update underlying data model
  if FIsConfigFile then begin
    if (FSelectedBlock < 0) or (FSelectedBlock >= Length(FTabBlocks)) then Exit;
    Bars := FTabBlocks[FSelectedBlock].Bars;
  end else begin
    Bars := FTabBars;
  end;

  // Find which bar and step this column corresponds to
  CumSteps := 0;
  for BarIdx := FCurPage * FPageSize to Min(FCurPage * FPageSize + FPageSize, Length(Bars)) - 1 do begin
    if (ACol > CumSteps) and (ACol <= CumSteps + Bars[BarIdx].Steps) then begin
      StepInBar := ACol - CumSteps - 1;
      RowIdx := ARow - 1;
      if (RowIdx >= 0) and (RowIdx <= High(FInstOrder)) then begin
        for J := 0 to High(Bars[BarIdx].InstChars) do
          if Bars[BarIdx].InstChars[J].Abbr = FInstOrder[RowIdx] then begin
            if (StepInBar >= 0) and (StepInBar < Length(Bars[BarIdx].InstChars[J].Chars)) then
              Bars[BarIdx].InstChars[J].Chars[StepInBar] := StepCharToChar(SC);
            Break;
          end;
      end;
      MarkBlockModified(Self);
      Break;
    end;
    CumSteps := CumSteps + Bars[BarIdx].Steps;
  end;
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
  if cbZoom.ItemIndex = 0 then FResolution := 8
  else if cbZoom.ItemIndex = 1 then FResolution := 16
  else if cbZoom.ItemIndex = 2 then FResolution := 32
  else if cbZoom.ItemIndex = 3 then FResolution := 64;
  FPageSize := 16;
  FTotalPages := Max(1, (Length(FTabBars) + FPageSize - 1) div FPageSize);
  if FCurPage >= FTotalPages then FCurPage := FTotalPages - 1;
  RenderPage(FCurPage);
end;

procedure TMainForm.UpdateHeaderPreview;
var
  StyleName, KindName, Meters: string;
  I: Integer;
  MeterList: TStringList;
begin
  if radFill.Checked then
    lblHeaderPreview.Caption := Format('[%s energy=%s]', ['custom', cbEnergy.Items[cbEnergy.ItemIndex]])
  else
  begin
    StyleName := 'midi';
    KindName := 'verse';
    if cbStyle.ItemIndex >= 0 then
      StyleName := GetStyleNameFromItem(cbStyle.Items[cbStyle.ItemIndex]);
    if cbKind.ItemIndex >= 0 then
      KindName := cbKind.Items[cbKind.ItemIndex];
    MeterList := TStringList.Create;
    try
      for I := 0 to High(FTabBars) do
        if MeterList.IndexOf(FTabBars[I].Meter) < 0 then
          MeterList.Add(FTabBars[I].Meter);
      Meters := MeterList.CommaText;
    finally
      MeterList.Free;
    end;
    lblHeaderPreview.Caption := Format('[%s %s meter=%s intensity=0.2-0.6]', [StyleName, KindName, Meters]);
  end;
end;

procedure TMainForm.UpdateControls;
begin
  btnSavePatternAs.Enabled := Length(FTabBars) > 0;
  if FIsConfigFile and Assigned(btnTabPrev) then begin
    btnTabPrev.Enabled := FSelectedBlock > 0;
    btnTabNext.Enabled := FSelectedBlock < Length(FTabBlocks) - 1;
    btnDeleteBlock.Enabled := Length(FTabBlocks) > 1;
  end;
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

procedure TMainForm.cbMeterChange(Sender: TObject);
begin
  UpdateHeaderPreview;
end;

procedure TMainForm.cbIntensityChange(Sender: TObject);
begin
  UpdateHeaderPreview;
end;

procedure TMainForm.cbEnergyChange(Sender: TObject);
begin
  UpdateHeaderPreview;
end;

procedure TMainForm.cbStyleChange(Sender: TObject);
begin
  UpdateHeaderPreview;
end;

procedure TMainForm.cbKindChange(Sender: TObject);
begin
  UpdateHeaderPreview;
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
  StyleFile := IncludeTrailingPathDelimiter(FOutputDir) + 'styles.txt';
  UpdateStatus('Style file: ' + StyleFile);
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
  if FInThemeApply then Exit;
  FInThemeApply := True;
  try
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
    {$IFDEF MSWINDOWS}cbMapping.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
    cbStyle.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
    cbKind.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
    cbResolution.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
    cbMeter.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
    cbIntensity.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
    cbEnergy.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);
    cbZoom.OnDrawItem := TDrawItemEvent(@ComboBoxDrawItem);{$ENDIF}
    cbMapping.OnDropDown := @ComboBoxDropDown;
    cbStyle.OnDropDown := @ComboBoxDropDown;
    cbKind.OnDropDown := @ComboBoxDropDown;
    cbResolution.OnDropDown := @ComboBoxDropDown;
    cbMeter.OnDropDown := @ComboBoxDropDown;
    cbIntensity.OnDropDown := @ComboBoxDropDown;
    cbEnergy.OnDropDown := @ComboBoxDropDown;
    cbZoom.OnDropDown := @ComboBoxDropDown;
    {$IFDEF MSWINDOWS}
    // Update status bar panel colors for dark mode - avoid paint race
    sbStatus.OnDrawPanel := nil;
    try
      if FDark then begin
        sbStatus.Panels[0].Style := psOwnerDraw;
      end else begin
        sbStatus.Panels[0].Style := psText;
      end;
    finally
      sbStatus.OnDrawPanel := @StatusBarDrawPanel;
    end;
    // Grid fixed cells (instrument labels + step numbers)
    if FDark then
      sgTab.FixedColor := DARK_PANEL
    else
      sgTab.FixedColor := clBtnFace;
    // Grid cell text color
    if FDark then
      sgTab.Font.Color := DARK_TEXT
    else
      sgTab.Font.Color := clWindowText;
    {$ENDIF}
  finally
    FInThemeApply := False;
  end;
end;
{$ENDIF}


{$IFDEF MSWINDOWS}
procedure TMainForm.StatusBarDrawPanel(Sender: TStatusBar; Panel: TStatusPanel;
  const Rect: TRect);
var
  Flags: Longint;
  R: TRect;
begin
  R := Rect;
  with Sender.Canvas do begin
    if FDark then begin
      Brush.Color := $2D2D2D;
      Font.Color := clWhite;
    end else begin
      Brush.Color := clBtnFace;
      Font.Color := clWindowText;
    end;
    FillRect(R);
    Flags := DT_LEFT or DT_VCENTER or DT_SINGLELINE;
    DrawText(Handle, PChar(Panel.Text), -1, R, Flags);
  end;
end;

procedure TMainForm.sgTabDrawCell(Sender: TObject; ACol, ARow: Integer;
  ARect: TRect; AState: TGridDrawState);
var
  Grid: TStringGrid;
  I, CumSteps: Integer;
  IsBarStart: Boolean;
begin
  Grid := Sender as TStringGrid;
  with Grid.Canvas do begin
    if FDark then begin
      Brush.Color := DARK_PANEL;
      Font.Color := DARK_TEXT;
    end else begin
      Brush.Color := clWindow;
      Font.Color := clWindowText;
    end;
    FillRect(ARect);
    DrawText(Handle, PChar(Grid.Cells[ACol, ARow]), -1, ARect,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE);

    // Draw vertical line at left edge of every cell (replaces goVertLine)
    Pen.Width := 1;
    if FDark then
      Pen.Color := DARK_BORDER
    else
      Pen.Color := clSilver;
    MoveTo(ARect.Left, ARect.Top);
    LineTo(ARect.Left, ARect.Bottom - 1);

    // Draw thicker vertical line at bar boundaries
    IsBarStart := False;
    CumSteps := 0;
    for I := 0 to High(FTabBars) - 1 do begin
      CumSteps := CumSteps + FTabBars[I].Steps;
      if ACol = CumSteps + 1 then begin
        IsBarStart := True;
        Break;
      end;
    end;

    if IsBarStart then begin
      Pen.Width := 3;
      if FDark then
        Pen.Color := DARK_BORDER
      else
        Pen.Color := clBlack;
      MoveTo(ARect.Left, ARect.Top);
      LineTo(ARect.Left, ARect.Bottom - 1);
    end;

    // Draw right edge of last column
    if ACol = Grid.ColCount - 1 then begin
      Pen.Width := 1;
      if FDark then
        Pen.Color := DARK_BORDER
      else
        Pen.Color := clSilver;
      MoveTo(ARect.Right - 1, ARect.Top);
      LineTo(ARect.Right - 1, ARect.Bottom - 1);
    end;
  end;
end;
{$ENDIF}

{$IFDEF MSWINDOWS}
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
{$ENDIF}

procedure TMainForm.ComboBoxDropDown(Sender: TObject);
begin
  { Dropdown theming is handled by Windows dark mode API via SetAppDarkMode.
    The previous handle-hack (FindWindowEx + SendMessage) was unsafe:
    internal LCL listbox handles can be destroyed between OnDropDown and here,
    causing CTD on SendMessage/InvalidateRect to dead handles. }
end;
{$IFDEF MSWINDOWS}
procedure TMainForm.SystemThemeChanged(Sender: TObject);
begin
  { Windows switched between light and dark apps: follow it when asked to. }
  ApplyDarkTheme(ResolveDark(LoadThemeChoice));
end;
{$ENDIF}

// ============================================================================
// TAB BLOCK MANAGEMENT IMPLEMENTATION
// ============================================================================

function TMainForm.IsConfigTabFile(const AFileName: string): Boolean;
var
  LowerName: string;
begin
  LowerName := LowerCase(AFileName);
  LowerName := StringReplace(LowerName, '/', PathDelim, [rfReplaceAll]);
  Result := (Pos('config' + PathDelim + 'grooves', LowerName) > 0) or
            (Pos('config' + PathDelim + 'fills', LowerName) > 0);
end;

procedure TMainForm.ParseConfigTabFile(const AFileName: string);
var
  SL: TStringList;
  I, BlockIdx: Integer;
  Line: string;
begin
  FTabBlocks := nil;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(AFileName);
    BlockIdx := -1;
    
    for I := 0 to SL.Count - 1 do
    begin
      Line := SL[I];
      if (Line <> '') and (Line[1] = '[') then begin
        if BlockIdx >= 0 then begin
          FTabBlocks[BlockIdx].LineEnd := I - 1;
        end;
        Inc(BlockIdx);
        SetLength(FTabBlocks, BlockIdx + 1);
        FTabBlocks[BlockIdx].Header := Line;
        FTabBlocks[BlockIdx].SourceFile := AFileName;
        FTabBlocks[BlockIdx].BlockIndex := BlockIdx;
        FTabBlocks[BlockIdx].LineStart := I;
        FTabBlocks[BlockIdx].LineEnd := SL.Count - 1;
        FTabBlocks[BlockIdx].Bars := nil;
        FTabBlocks[BlockIdx].Modified := False;
        ParseHeader(Line, FTabBlocks[BlockIdx]);
      end
      else if (Line <> '') and (Line[1] <> '#') and (BlockIdx >= 0) then begin
        AddInstrumentLineToBlock(Line, FTabBlocks[BlockIdx]);
      end;
    end;
    if BlockIdx >= 0 then
      FTabBlocks[BlockIdx].LineEnd := SL.Count - 1;
    
    cbTabSelector.Items.Clear;
    for I := 0 to High(FTabBlocks) do
      cbTabSelector.Items.Add(Format('%s %s (%.2f-%.2f)', 
        [FTabBlocks[I].Style, FTabBlocks[I].Kind, 
         FTabBlocks[I].IntensityLow, FTabBlocks[I].IntensityHigh]));
    
    if cbTabSelector.Items.Count > 0 then begin
      cbTabSelector.ItemIndex := 0;
      FSelectedBlock := 0;
      UpdateHeaderFields;
      RenderPage(0);
    end;
  finally
    SL.Free;
  end;
end;

procedure TMainForm.ParseForeignTabFile(const AFileName: string);
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

procedure TMainForm.LoadTabFile(const AFileName: string);
begin
  FIsConfigFile := IsConfigTabFile(AFileName);
  FTabBlocks := nil;
  FTabBars := nil;
  FSelectedBlock := -1;
  FBlockModified := False;

  if FIsConfigFile then
    ParseConfigTabFile(AFileName)
  else
    ParseForeignTabFile(AFileName);

  UpdateBlockNavigationUI;
end;

function TMainForm.BuildBlockText(const ABlock: TTabBlock): string;
var
  SL: TStringList;
  I, J, K, K2: Integer;
  Line: string;
  Found: Boolean;
begin
  SL := TStringList.Create;
  try
    SL.Add(Format('[%s %s intensity=%.2f-%.2f]', 
      [ABlock.Style, ABlock.Kind, ABlock.IntensityLow, ABlock.IntensityHigh]));

    for I := 0 to High(FInstOrder) do
    begin
      Line := FInstOrder[I];
      for K := 1 to 4 - Length(FInstOrder[I]) do
        Line := Line + ' ';
      if Length(Line) < 4 then Line := Line + ' ';
      Line := Line + '  ';

      for J := 0 to High(ABlock.Bars) do
      begin
        if J > 0 then Line := Line + ' | ';
        Found := False;
        for K := 0 to High(ABlock.Bars[J].InstChars) do
          if ABlock.Bars[J].InstChars[K].Abbr = FInstOrder[I] then
          begin
            for K2 := 0 to High(ABlock.Bars[J].InstChars[K].Chars) do
              Line := Line + ABlock.Bars[J].InstChars[K].Chars[K2];
            Found := True;
            Break;
          end;
        if not Found then
          for K := 1 to ABlock.Bars[J].Steps do
            Line := Line + '.';
      end;
      SL.Add(Line);
    end;

    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TMainForm.SetupBlockNavigationUI;
var
  Y: Integer;
begin
  Y := sbStatus.Top - 150;
  
  cbTabSelector := TComboBox.Create(Self);
  with cbTabSelector do begin
    Parent := Self;
    Name := 'cbTabSelector';
    Left := 12; Top := Y;
    Width := 300; Height := 24;
    Style := csDropDownList;
    OnChange := @cbTabSelectorChange;
    Visible := False;
  end;
  
  btnTabPrev := TButton.Create(Self);
  with btnTabPrev do begin
    Parent := Self;
    Name := 'btnTabPrev';
    Left := 320; Top := Y;
    Width := 30; Height := 24;
    Caption := '◀';
    OnClick := @btnTabPrevClick;
    Visible := False;
  end;
  
  btnTabNext := TButton.Create(Self);
  with btnTabNext do begin
    Parent := Self;
    Name := 'btnTabNext';
    Left := 355; Top := Y;
    Width := 30; Height := 24;
    Caption := '▶';
    OnClick := @btnTabNextClick;
    Visible := False;
  end;
  
  lblTabPosition := TLabel.Create(Self);
  with lblTabPosition do begin
    Parent := Self;
    Name := 'lblTabPosition';
    Left := 390; Top := Y + 4;
    Width := 80; Height := 16;
    Caption := '';
    Visible := False;
  end;
  
  Y := Y + 30;
  edBlockStyle := TEdit.Create(Self);
  with edBlockStyle do begin
    Parent := Self;
    Name := 'edBlockStyle';
    Left := 12; Top := Y;
    Width := 120; Height := 24;
    Text := '';
    Visible := False;
  end;
  
  edBlockKind := TEdit.Create(Self);
  with edBlockKind do begin
    Parent := Self;
    Name := 'edBlockKind';
    Left := 140; Top := Y;
    Width := 100; Height := 24;
    Text := '';
    Visible := False;
  end;
  
  edIntensityLow := TEdit.Create(Self);
  with edIntensityLow do begin
    Parent := Self;
    Name := 'edIntensityLow';
    Left := 248; Top := Y;
    Width := 60; Height := 24;
    Text := '0.20';
    Visible := False;
  end;
  
  edIntensityHigh := TEdit.Create(Self);
  with edIntensityHigh do begin
    Parent := Self;
    Name := 'edIntensityHigh';
    Left := 315; Top := Y;
    Width := 60; Height := 24;
    Text := '0.60';
    Visible := False;
  end;
  
  Y := Y + 30;
  btnSaveBlock := TButton.Create(Self);
  with btnSaveBlock do begin
    Parent := Self;
    Name := 'btnSaveBlock';
    Left := 12; Top := Y;
    Width := 80; Height := 28;
    Caption := 'Save Block';
    OnClick := @btnSaveBlockClick;
    Visible := False;
  end;
  
  btnNewBlock := TButton.Create(Self);
  with btnNewBlock do begin
    Parent := Self;
    Name := 'btnNewBlock';
    Left := 100; Top := Y;
    Width := 80; Height := 28;
    Caption := 'New Block';
    OnClick := @btnNewBlockClick;
    Visible := False;
  end;
  
  btnDeleteBlock := TButton.Create(Self);
  with btnDeleteBlock do begin
    Parent := Self;
    Name := 'btnDeleteBlock';
    Left := 188; Top := Y;
    Width := 80; Height := 28;
    Caption := 'Delete';
    OnClick := @btnDeleteBlockClick;
    Visible := False;
  end;
  
  edBlockStyle.OnChange := @MarkBlockModified;
  edBlockKind.OnChange := @MarkBlockModified;
  edIntensityLow.OnChange := @MarkBlockModified;
  edIntensityHigh.OnChange := @MarkBlockModified;
end;

procedure TMainForm.UpdateBlockNavigationUI;
var
  UIEnabled: Boolean;
begin
  UIEnabled := FIsConfigFile and (Length(FTabBlocks) > 0);

  if Assigned(cbTabSelector) then cbTabSelector.Visible := UIEnabled;
  if Assigned(btnTabPrev) then btnTabPrev.Visible := UIEnabled;
  if Assigned(btnTabNext) then btnTabNext.Visible := UIEnabled;
  if Assigned(lblTabPosition) then lblTabPosition.Visible := UIEnabled;
  if Assigned(edBlockStyle) then edBlockStyle.Visible := UIEnabled;
  if Assigned(edBlockKind) then edBlockKind.Visible := UIEnabled;
  if Assigned(edIntensityLow) then edIntensityLow.Visible := UIEnabled;
  if Assigned(edIntensityHigh) then edIntensityHigh.Visible := UIEnabled;
  if Assigned(btnSaveBlock) then btnSaveBlock.Visible := UIEnabled;
  if Assigned(btnNewBlock) then btnNewBlock.Visible := UIEnabled;
  if Assigned(btnDeleteBlock) then btnDeleteBlock.Visible := UIEnabled;
  
  if UIEnabled then begin
    UpdateHeaderFields;
    lblTabPosition.Caption := Format('%d of %d', [FSelectedBlock + 1, Length(FTabBlocks)]);
    btnTabPrev.Enabled := FSelectedBlock > 0;
    btnTabNext.Enabled := FSelectedBlock < Length(FTabBlocks) - 1;
    btnDeleteBlock.Enabled := Length(FTabBlocks) > 1;
  end;
end;

procedure TMainForm.UpdateHeaderFields;
begin
  if (FSelectedBlock >= 0) and (FSelectedBlock < Length(FTabBlocks)) then begin
    edBlockStyle.Text := FTabBlocks[FSelectedBlock].Style;
    edBlockKind.Text := FTabBlocks[FSelectedBlock].Kind;
    edIntensityLow.Text := FormatFloat('0.00', FTabBlocks[FSelectedBlock].IntensityLow);
    edIntensityHigh.Text := FormatFloat('0.00', FTabBlocks[FSelectedBlock].IntensityHigh);
    FBlockModified := False;
  end;
end;

procedure TMainForm.MarkBlockModified(Sender: TObject);
begin
  if (FSelectedBlock >= 0) and (FSelectedBlock < Length(FTabBlocks)) then begin
    FTabBlocks[FSelectedBlock].Modified := True;
    FBlockModified := True;
    if Assigned(cbTabSelector) and (cbTabSelector.Items.Count > FSelectedBlock) then begin
      if Pos('*', cbTabSelector.Items[FSelectedBlock]) = 0 then
        cbTabSelector.Items[FSelectedBlock] := cbTabSelector.Items[FSelectedBlock] + ' *';
    end;
  end;
end;

procedure TMainForm.cbTabSelectorChange(Sender: TObject);
begin
  if cbTabSelector.ItemIndex >= 0 then begin
    FSelectedBlock := cbTabSelector.ItemIndex;
    UpdateHeaderFields;
    RenderPage(0);
    UpdateBlockNavigationUI;
  end;
end;

procedure TMainForm.btnTabPrevClick(Sender: TObject);
begin
  if FSelectedBlock > 0 then begin
    Dec(FSelectedBlock);
    cbTabSelector.ItemIndex := FSelectedBlock;
    UpdateHeaderFields;
    RenderPage(0);
    UpdateBlockNavigationUI;
  end;
end;

procedure TMainForm.btnTabNextClick(Sender: TObject);
begin
  if (FSelectedBlock >= 0) and (FSelectedBlock < Length(FTabBlocks) - 1) then begin
    Inc(FSelectedBlock);
    cbTabSelector.ItemIndex := FSelectedBlock;
    UpdateHeaderFields;
    RenderPage(0);
    UpdateBlockNavigationUI;
  end;
end;

procedure TMainForm.btnSaveBlockClick(Sender: TObject);
begin
  SurgicalSaveBlock;
end;

procedure TMainForm.SurgicalSaveBlock;
var
  SL: TStringList;
  Block: TTabBlock;
  I: Integer;
begin
  if (FSelectedBlock < 0) or (FSelectedBlock >= Length(FTabBlocks)) then Exit;
  
  Block := FTabBlocks[FSelectedBlock];
  Block.Style := edBlockStyle.Text;
  Block.Kind := edBlockKind.Text;
  Block.IntensityLow := StrToFloatDef(edIntensityLow.Text, 0.0);
  Block.IntensityHigh := StrToFloatDef(edIntensityHigh.Text, 1.0);
  FTabBlocks[FSelectedBlock] := Block;
  
  SL := TStringList.Create;
  try
    SL.LoadFromFile(Block.SourceFile);
    for I := Block.LineStart to Block.LineEnd do
      SL.Delete(Block.LineStart);
    SL.Insert(Block.LineStart, BuildBlockText(Block));
    SL.SaveToFile(Block.SourceFile, TEncoding.UTF8);
    
    FTabBlocks[FSelectedBlock].Modified := False;
    FBlockModified := False;
    if Assigned(cbTabSelector) and (cbTabSelector.Items.Count > FSelectedBlock) then begin
      cbTabSelector.Items[FSelectedBlock] := Format('%s %s (%.2f-%.2f)',
        [Block.Style, Block.Kind, Block.IntensityLow, Block.IntensityHigh]);
    end;
    UpdateStatus('Saved block to: ' + ExtractFileName(Block.SourceFile));
  finally
    SL.Free;
  end;
end;

procedure TMainForm.btnNewBlockClick(Sender: TObject);
var
  NewBlock: TTabBlock;
  SL: TStringList;
  I, J, K: Integer;
begin
  if not FIsConfigFile then Exit;
  
  NewBlock.Header := '[new verse intensity=0.20-0.60]';
  NewBlock.Style := 'new';
  NewBlock.Kind := 'verse';
  NewBlock.IntensityLow := 0.20;
  NewBlock.IntensityHigh := 0.60;
  NewBlock.Meter := cbMeter.Text;
  NewBlock.SourceFile := FTabBlocks[0].SourceFile;
  NewBlock.BlockIndex := Length(FTabBlocks);
  NewBlock.LineStart := 0;
  NewBlock.LineEnd := 0;
  NewBlock.Bars := nil;
  NewBlock.Modified := True;
  
  SetLength(NewBlock.Bars, FPageSize);
  for I := 0 to High(NewBlock.Bars) do begin
    NewBlock.Bars[I].Steps := FStepsPerBar;
    NewBlock.Bars[I].Meter := cbMeter.Text;
    NewBlock.Bars[I].InstChars := nil;
    for J := 0 to High(FInstOrder) do begin
      K := Length(NewBlock.Bars[I].InstChars);
      SetLength(NewBlock.Bars[I].InstChars, K + 1);
      NewBlock.Bars[I].InstChars[K].Abbr := FInstOrder[J];
      SetLength(NewBlock.Bars[I].InstChars[K].Chars, FStepsPerBar);
      FillChar(NewBlock.Bars[I].InstChars[K].Chars[0], FStepsPerBar, '.');
    end;
  end;
  
  SL := TStringList.Create;
  try
    SL.LoadFromFile(NewBlock.SourceFile);
    SL.Add('');
    SL.Add(BuildBlockText(NewBlock));
    SL.SaveToFile(NewBlock.SourceFile, TEncoding.UTF8);
  finally
    SL.Free;
  end;
  
  ParseConfigTabFile(NewBlock.SourceFile);
  cbTabSelector.ItemIndex := Length(FTabBlocks) - 1;
  FSelectedBlock := Length(FTabBlocks) - 1;
  UpdateHeaderFields;
  RenderPage(0);
  UpdateBlockNavigationUI;
end;

procedure TMainForm.btnDeleteBlockClick(Sender: TObject);
var
  SL: TStringList;
  I: Integer;
  SourceFile: string;
begin
  if not FIsConfigFile then Exit;
  if Length(FTabBlocks) <= 1 then begin
    UpdateStatus('Cannot delete the only block');
    Exit;
  end;
  
  if MessageDlg('Delete Block', 'Delete this block from the file?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  
  SourceFile := FTabBlocks[FSelectedBlock].SourceFile;
  
  SL := TStringList.Create;
  try
    SL.LoadFromFile(SourceFile);
    for I := FTabBlocks[FSelectedBlock].LineStart to FTabBlocks[FSelectedBlock].LineEnd do
      SL.Delete(FTabBlocks[FSelectedBlock].LineStart);
    if (FTabBlocks[FSelectedBlock].LineStart > 0) and (Trim(SL[FTabBlocks[FSelectedBlock].LineStart - 1]) = '') then
      SL.Delete(FTabBlocks[FSelectedBlock].LineStart - 1);
    SL.SaveToFile(SourceFile, TEncoding.UTF8);
  finally
    SL.Free;
  end;
  
  ParseConfigTabFile(SourceFile);
  if FSelectedBlock >= Length(FTabBlocks) then
    FSelectedBlock := Length(FTabBlocks) - 1;
  cbTabSelector.ItemIndex := FSelectedBlock;
  UpdateHeaderFields;
  RenderPage(0);
  UpdateBlockNavigationUI;
end;

end.
