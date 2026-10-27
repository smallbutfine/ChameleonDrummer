unit MainFrm;

{$mode objfpc}{$H+}

{ ChameleonDrummer - graphical front end (CLI wrapper).

  Collects inputs from the UI and passes them to the standalone CLI executable

  (ChameleonDrummer.exe, next to this program) via TProcess. The genre, style
  and drummer lists are read from that executable (`list genres|styles|
  drummers`), so the GUI offers exactly what the engine has, and the keymaps
  come from the mappings folder. Without the executable nothing can be
  generated, and the GUI says so. }

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Spin,
  Dialogs, LCLType, Graphics, {$IFDEF MSWINDOWS}DarkTheme, ShellApi, Windows,{$ENDIF} process, StrUtils, menus, CliLookup,
  time_signature;

type
  TIntDynArray = array of Integer;
  TStrDynArray = array of String;

  TMainForm = class(TForm)
    gbSong: TGroupBox;
    sbSections: TScrollBox;
    MainMenu: TMainMenu;
    mnuFile: TMenuItem;
    mnuEdit: TMenuItem;
    mnuView: TMenuItem;
    mnuThemeSystem: TMenuItem;
    mnuThemeLight: TMenuItem;
    {$IFDEF MSWINDOWS}mnuThemeDark: TMenuItem;{$ENDIF}
    mnuAddSection: TMenuItem;
    mnuResetStructure: TMenuItem;
    mnuDeleteSection: TMenuItem;
    mnuExportConfig: TMenuItem;
    mnuImportConfig: TMenuItem;
    rbPattern: TRadioButton;
    rbSong: TRadioButton;
    lblGenre: TLabel;
    cbGenre: TComboBox;
    lblStyle: TLabel;
    cbStyle: TComboBox;
    lblDrummer: TLabel;
    cbDrummer: TComboBox;
    lblMapping: TLabel;
    cbMapping: TComboBox;
    lblMeter: TLabel;
    cbMeter: TComboBox;
    lblMeterHint: TLabel;
    gbPerformance: TGroupBox;
    lblTempo: TLabel;
    seTempo: TSpinEdit;
    lblTempoHint: TLabel;
    lblComplexity: TLabel;
    tbComplexity: TTrackBar;
    lblComplexityValue: TLabel;
    lblHumanization: TLabel;
    tbHumanization: TTrackBar;
    lblHumanizationValue: TLabel;
    lblSwing: TLabel;
    tbSwing: TTrackBar;
    lblSwingValue: TLabel;
    gbOutput: TGroupBox;
    lblExport: TLabel;
    cbExport: TComboBox;
    lblFile: TLabel;
    edOutput: TEdit;
    btnBrowse: TButton;
    chkOpenFolder: TCheckBox;
    lblHint: TLabel;
    btnGenerate: TButton;
    btnOpenFolder: TButton;
    gbLog: TGroupBox;
    memLog: TMemo;
    lblStatus: TLabel;
    pbProgress: TProgressBar;
    StatusBar: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure rgModeChange(Sender: TObject);
    procedure cbGenreChange(Sender: TObject);
    procedure tbComplexityChange(Sender: TObject);
    procedure tbHumanizationChange(Sender: TObject);
    procedure tbSwingChange(Sender: TObject);
    procedure btnGenerateClick(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnOpenFolderClick(Sender: TObject);
    procedure mnuQuitClick(Sender: TObject);
    procedure mnuAddSectionClick(Sender: TObject);
    procedure mnuResetStructureClick(Sender: TObject);
    procedure mnuDeleteSectionClick(Sender: TObject);
    procedure mnuExportConfigClick(Sender: TObject);
    procedure mnuImportConfigClick(Sender: TObject);
    {$IFDEF MSWINDOWS}procedure mnuThemeClick(Sender: TObject);{$ENDIF}
    procedure mnuAboutClick(Sender: TObject);
  private
    FSectionNames: TStrDynArray;
    FSectionBars: TIntDynArray;
    FCliTool: String;
     {$IFDEF MSWINDOWS}FThemeChoice: TThemeChoice;
    FDark: Boolean;{$ENDIF}
    procedure Log(const AText: String);
    {$IFDEF MSWINDOWS}procedure SetTheme(AChoice: TThemeChoice; ASave: Boolean);
    procedure SystemThemeChanged(Sender: TObject);
    procedure ThemeMenuChecks;{$ENDIF}

    procedure FillStyles;

    procedure FillLists;
    function RunTool(const AArgs: array of String): Boolean;

    procedure CommonOptions(AArgs: TStrings);
    function MeterOption(out AText: String): Boolean;
    procedure ResetToDefaultStructure;
    procedure UpdateValueLabels;
    function SwingAmount: Double;
    function SelectedGenre: String;
    function SelectedStyle: String;
    function OutputBasePath: String;
    procedure OpenFolder(const APath: String);
    procedure BuildSectionControls;
    procedure ClearSectionControls;
    procedure SyncSectionArraysFromControls;
    procedure StatusBarDrawPanel(Sender: TStatusBar; Panel: TStatusPanel; const Rect: TRect);
  public
    procedure BtnAddSectionClick(Sender: TObject);
    procedure BtnResetStructureClick(Sender: TObject);
    procedure BtnSectionDeleteClick(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{ The form file is named after the form class, not after this unit }
{$R TMainForm.lfm}

{ Numbers handed to the command line must use a '.' decimal separator whatever
  the system locale is: the CLI would not understand '0,67'. }
function CliNumber(AValue: Double): String;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.00', AValue, FS);
end;

const
  ExportMIDI = 0;
  ExportREAPER = 1;
  ExportArdour = 2;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  cbMeter.Items.CommaText := '4/4,2/4,3/4,5/4,6/8,7/8,9/8,11/8,13/8,15/16';
  cbMeter.ItemIndex := 0;

  { Make combo boxes read-only (no text selection on focus) }
  cbGenre.Style := csDropDownList;
  cbStyle.Style := csDropDownList;
  cbDrummer.Style := csDropDownList;
  cbMapping.Style := csDropDownList;
  cbMeter.Style := csDropDownList;
  cbExport.Style := csDropDownList;

  FillLists;
  FillStyles;

  { Export options }
  cbExport.Items.Add('MIDI only');
  cbExport.Items.Add('MIDI + REAPER project');
  cbExport.Items.Add('MIDI + REAPER project + Ardour session');
  cbExport.ItemIndex := ExportREAPER;

  edOutput.Text := 'song';
  chkOpenFolder.Checked := False;

  seTempo.MinValue := 0;
  seTempo.MaxValue := 300;
  seTempo.Value := 0;

  tbComplexity.Min := 0;
  tbComplexity.Max := 100;
  tbComplexity.Position := 50;

  tbHumanization.Min := 0;
  tbHumanization.Max := 100;
  tbHumanization.Position := 30;

  tbSwing.Min := 0;
  tbSwing.Max := 100;
  tbSwing.Position := 0;

  UpdateValueLabels;

  { Setup scrollable section area - positioned below static controls }
  sbSections := TScrollBox.Create(Self);
  with sbSections do begin
    Parent := gbSong;
    Left := 0;
    Top := 210;
    Width := gbSong.ClientWidth;
    Height := gbSong.ClientHeight - 210;
    Align := alNone;
    Anchors := [akLeft, akTop, akRight, akBottom];
    BorderStyle := bsNone;
    VertScrollBar.Tracking := True;
    HorzScrollBar.Visible := False;
  end;

  ResetToDefaultStructure;

  { Create StatusBar programmatically to avoid .lfm loading issues }
  StatusBar := TStatusBar.Create(Self);
  with StatusBar do begin
    Parent := Self;
    Align := alBottom;
    SimplePanel := False;
    Panels.Add;
    Panels[0].Width := 300;
    Panels.Add;
    Panels[1].Width := 150;
    Panels.Add;
    Panels[2].Width := 100;
    OnDrawPanel := @StatusBarDrawPanel;
  end;

  Log('Choose a genre and style, pick a drummer, then press Generate.');
  lblStatus.Caption := 'Ready';
  StatusBar.Panels[0].Text := 'Ready';

  { Colours last, when every control exists. }
  {$IFDEF MSWINDOWS}OnSystemThemeChange := @SystemThemeChanged;
  SetTheme(LoadThemeChoice, False);{$ENDIF}
  {$IFDEF MSWINDOWS}ThemeControlTree(Self, FDark);{$ENDIF}
end;

{$IFDEF MSWINDOWS}procedure TMainForm.ThemeMenuChecks;
begin
  mnuThemeSystem.Checked := FThemeChoice = tcSystem;
  mnuThemeLight.Checked := FThemeChoice = tcLight;
  mnuThemeDark.Checked := FThemeChoice = tcDark;
end;

procedure TMainForm.SetTheme(AChoice: TThemeChoice; ASave: Boolean);
begin
  FThemeChoice := AChoice;
  FDark := ResolveDark(AChoice);
  ThemeMenuChecks;
  ApplyTheme(Self, FDark);
  { Update status bar panel colors for dark mode }
  if Assigned(StatusBar) then begin
    if FDark then begin
      StatusBar.Panels[0].Style := psOwnerDraw;
      StatusBar.Panels[1].Style := psOwnerDraw;
      StatusBar.Panels[2].Style := psOwnerDraw;
    end else begin
      StatusBar.Panels[0].Style := psText;
      StatusBar.Panels[1].Style := psText;
      StatusBar.Panels[2].Style := psText;
    end;
  end;
  if ASave then
    SaveThemeChoice(AChoice);
end;

procedure TMainForm.SystemThemeChanged(Sender: TObject);
begin
  { Windows switched between light and dark apps: follow it when asked to. }
  if FThemeChoice = tcSystem then
    SetTheme(tcSystem, False);
end;

procedure TMainForm.mnuThemeClick(Sender: TObject);
begin
  if Sender = mnuThemeDark then
    SetTheme(tcDark, True)
  else if Sender = mnuThemeLight then
    SetTheme(tcLight, True)
  else
    SetTheme(tcSystem, True);
end;{$ENDIF}

{ The command line tool is the only source of genres, styles and drummers. If
  it is missing, the lists stay empty, Generate is off, and the log says where
  the tool is expected. }
procedure TMainForm.FillLists;
var
  Err: String;
  Items: TStringList;
begin
  FCliTool := FindCliTool;
  cbGenre.Clear;
  cbDrummer.Clear;
  cbMapping.Clear;

  Items := TStringList.Create;
  try
    ListKeymaps(Items);
    cbMapping.Items.Assign(Items);
    if cbMapping.Items.IndexOf('gm') >= 0 then
      cbMapping.ItemIndex := cbMapping.Items.IndexOf('gm')
    else if cbMapping.Items.Count > 0 then
      cbMapping.ItemIndex := 0;

    if FCliTool = '' then begin
      btnGenerate.Enabled := False;
      lblStatus.Caption := 'ChameleonDrummer.exe not found';
      if Assigned(StatusBar) then StatusBar.Panels[0].Text := 'CLI not found';
      Log('ChameleonDrummer.exe was not found. It must sit in the same folder as this program:');
      Log('  ' + CliToolPath);
      Log('Copy it there (or reinstall), then restart this program.');
      MessageDlg('ChameleonDrummer', 'ChameleonDrummer.exe was not found.' + LineEnding + LineEnding +
        'It must be in the same folder as this program:' + LineEnding + CliToolPath +
        LineEnding + LineEnding + 'Without it nothing can be generated.',
        mtError, [mbOK], 0);
      Exit;
    end;

    if QueryList(FCliTool, ['list', 'genres'], Items, Err) then begin
      cbGenre.Items.Assign(Items);
      cbGenre.ItemIndex := 0;
    end else begin
      btnGenerate.Enabled := False;
      Log('Could not read the genres from the command line tool: ' + Err);
    end;

    if QueryList(FCliTool, ['list', 'drummers'], Items, Err) then
      cbDrummer.Items.Assign(Items)
    else
      Log('Could not read the drummers from the command line tool: ' + Err);
  finally
    Items.Free;
  end;
end;

procedure TMainForm.FillStyles;
var
  Items: TStringList;
  Err: String;
begin
  cbStyle.Clear;
  if (FCliTool = '') or (SelectedGenre = '') then Exit;

  Items := TStringList.Create;
  try
    if QueryList(FCliTool, ['list', 'styles', '--genre', SelectedGenre], Items, Err) then
      cbStyle.Items.Assign(Items)
    else
      Log('Could not read the styles of ' + SelectedGenre + ': ' + Err);
  finally
    Items.Free;
  end;

  if cbStyle.Items.Count > 0 then
    cbStyle.ItemIndex := 0;
end;

{ Runs the command line tool, logs what it says, and tells whether it worked. }
function TMainForm.RunTool(const AArgs: array of String): Boolean;
var
  Output: String;
  Code: Integer;
  Lines: TStringList;
  I: Integer;
begin
  Result := False;
  if FCliTool = '' then begin
    Log('ChameleonDrummer.exe was not found next to this program: ' + CliToolPath);
    Exit;
  end;
  Code := RunCli(FCliTool, AArgs, Output);
  Lines := TStringList.Create;
  try
    Lines.Text := Output;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) <> '' then
        Log('  ' + Trim(Lines[I]));
  finally
    Lines.Free;
  end;
  Result := Code = 0;
  if not Result then
    Log(Format('The command line tool failed (exit code %d).', [Code]));
end;

procedure TMainForm.UpdateValueLabels;
begin
  lblComplexityValue.Caption := FormatFloat('0.00', tbComplexity.Position / 100);
  lblHumanizationValue.Caption := FormatFloat('0.00', tbHumanization.Position / 100);
  if tbSwing.Position = 0 then
    lblSwingValue.Caption := 'straight'
  else if (tbSwing.Position >= 60) and (tbSwing.Position <= 72) then
    lblSwingValue.Caption := FormatFloat('0.00', SwingAmount) + '  (classic 2:1)'
  else
    lblSwingValue.Caption := FormatFloat('0.00', SwingAmount);
end;

function TMainForm.SwingAmount: Double;
begin
  Result := tbSwing.Position / 100;
end;

function TMainForm.SelectedGenre: String;
begin
  if cbGenre.ItemIndex < 0 then Result := ''
  else Result := cbGenre.Items[cbGenre.ItemIndex];
end;

function TMainForm.SelectedStyle: String;
begin
  if cbStyle.ItemIndex < 0 then Result := ''
  else Result := cbStyle.Items[cbStyle.ItemIndex];
end;

function TMainForm.OutputBasePath: String;
begin
  Result := Trim(edOutput.Text);
end;

{ ---- Song mode: default structures + dynamic section controls ---- }

procedure TMainForm.ResetToDefaultStructure;
const
  CMetalNames: array[0..7] of String = ('intro','verse','chorus','verse','chorus','bridge','chorus','outro');
  CMetalBars:  array[0..7] of Integer   = (4,8,8,8,8,4,8,4);
  CRockNames:  array[0..5] of String = ('intro','verse','chorus','bridge','chorus','outro');
  CRockBars:   array[0..5] of Integer   = (4,8,8,4,8,4);
  CJazzNames:  array[0..4] of String = ('intro','verse','chorus','bridge','outro');
  CJazzBars:   array[0..4] of Integer   = (4,8,8,4,4);
  CFunkNames:  array[0..5] of String = ('intro','verse','chorus','bridge','chorus','outro');
  CFunkBars:   array[0..5] of Integer   = (4,8,8,4,8,4);
  CElecNames:  array[0..5] of String = ('intro','verse','chorus','verse','bridge','outro');
  CElecBars:   array[0..5] of Integer   = (4,8,8,8,4,4);
var
  g: String;
begin
  SetLength(FSectionNames, 0);
  SetLength(FSectionBars, 0);

  g := LowerCase(SelectedGenre);
  if g = 'metal' then begin
    FSectionNames := CMetalNames;
    SetLength(FSectionBars, Length(CMetalBars));
    Move(CMetalBars[0], FSectionBars[0], Length(CMetalBars) * SizeOf(Integer));
  end else if g = 'rock' then begin
    FSectionNames := CRockNames;
    SetLength(FSectionBars, Length(CRockBars));
    Move(CRockBars[0], FSectionBars[0], Length(CRockBars) * SizeOf(Integer));
  end else if g = 'jazz' then begin
    FSectionNames := CJazzNames;
    SetLength(FSectionBars, Length(CJazzBars));
    Move(CJazzBars[0], FSectionBars[0], Length(CJazzBars) * SizeOf(Integer));
  end else if g = 'funk' then begin
    FSectionNames := CFunkNames;
    SetLength(FSectionBars, Length(CFunkBars));
    Move(CFunkBars[0], FSectionBars[0], Length(CFunkBars) * SizeOf(Integer));
  end else if g = 'electronic' then begin
    FSectionNames := CElecNames;
    SetLength(FSectionBars, Length(CElecBars));
    Move(CElecBars[0], FSectionBars[0], Length(CElecBars) * SizeOf(Integer));
  end else begin
    { fallback = rock }
    FSectionNames := CRockNames;
    SetLength(FSectionBars, Length(CRockBars));
    Move(CRockBars[0], FSectionBars[0], Length(CRockBars) * SizeOf(Integer));
  end;

  BuildSectionControls;
end;

procedure TMainForm.ClearSectionControls;
var
  I: Integer;
  C: TComponent;
begin
  if Assigned(sbSections) then begin
    for I := sbSections.ComponentCount - 1 downto 0 do begin
      C := sbSections.Components[I];
      if (C is TLabel) and AnsiStartsStr('Section ', TLabel(C).Caption) then
        sbSections.Components[I].Free
      else if (C is TComboBox) and AnsiStartsStr('secCmb', C.Name) then
        sbSections.Components[I].Free
      else if (C is TSpinEdit) and AnsiStartsStr('secSpn', C.Name) then
        sbSections.Components[I].Free
      else if (C is TButton) and ((AnsiStartsStr('secDel', C.Name)) or (C.Name = 'btnAddSection') or (C.Name = 'btnResetStructure')) then
        sbSections.Components[I].Free;
    end;
  end;
end;

procedure TMainForm.BuildSectionControls;
var
  I, Y: Integer;
  lblName: TLabel;
  cmbSection: TComboBox;
  seBars: TSpinEdit;
  btnDelete: TButton;
  btnAdd: TButton;
begin
  ClearSectionControls;

  SetLength(FSectionBars, Length(FSectionNames));

  Y := 8;
  for I := 0 to High(FSectionNames) do begin
    lblName := TLabel.Create(sbSections);
    with lblName do begin
      Parent := sbSections;
      Left := 12; Top := Y;
      Width := 80; Height := 14;
      Caption := Format('Section %d', [I+1]);
      AutoSize := False;
    end;
    cmbSection := TComboBox.Create(sbSections);
    with cmbSection do begin
      Parent := sbSections;
      Name := Format('secCmb%d', [I]);
      Left := 100; Top := Y - 2;
      Width := 160; Height := 24;
      Style := csDropDownList;
      Items.Add('intro');
      Items.Add('verse');
      Items.Add('chorus');
      Items.Add('bridge');
      Items.Add('outro');
      ItemIndex := Items.IndexOf(FSectionNames[I]);
    end;
    seBars := TSpinEdit.Create(sbSections);
    with seBars do begin
      Parent := sbSections;
      Name := Format('secSpn%d', [I]);
      Left := 270; Top := Y - 2;
      Width := 55; Height := 24;
      MinValue := 1;
      MaxValue := 64;
      Value := FSectionBars[I];
    end;
    btnDelete := TButton.Create(sbSections);
    with btnDelete do begin
      Parent := sbSections;
      Name := Format('secDel%d', [I]);
      Left := 335; Top := Y - 2;
      Width := 28; Height := 24;
      Caption := '-';
      OnClick := @BtnSectionDeleteClick;
    end;
    Inc(Y, 30);
  end;

  { Add Section button at the bottom }
  btnAdd := TButton.Create(sbSections);
  with btnAdd do begin
    Parent := sbSections;
    Name := 'btnAddSection';
    Left := 100; Top := Y + 4;
    Width := 100; Height := 28;
    Caption := '+ Add Section';
    OnClick := @BtnAddSectionClick;
  end;

  { Reset Structure button }
  btnAdd := TButton.Create(sbSections);
  with btnAdd do begin
    Parent := sbSections;
    Name := 'btnResetStructure';
    Left := 210; Top := Y + 4;
    Width := 100; Height := 28;
    Caption := 'Reset';
    OnClick := @BtnResetStructureClick;
  end;

  { Update scroll range }
  sbSections.VertScrollBar.Range := Y + 40;

  { the controls made here are new: give them the current colours }
  {$IFDEF MSWINDOWS}ThemeControlTree(sbSections, FDark);{$ENDIF}
end;

procedure TMainForm.SyncSectionArraysFromControls;
var
  I: Integer;
  cmb: TComboBox;
  spn: TSpinEdit;
begin
  SetLength(FSectionBars, Length(FSectionNames));
  for I := 0 to High(FSectionNames) do begin
    cmb := sbSections.FindComponent(Format('secCmb%d', [I])) as TComboBox;
    if (cmb <> nil) then FSectionNames[I] := cmb.Text;
    spn := sbSections.FindComponent(Format('secSpn%d', [I])) as TSpinEdit;
    if (spn <> nil) then FSectionBars[I] := spn.Value;
  end;
end;

procedure TMainForm.BtnAddSectionClick(Sender: TObject);
begin
  SetLength(FSectionNames, Length(FSectionNames) + 1);
  SetLength(FSectionBars, Length(FSectionBars) + 1);
  FSectionNames[High(FSectionNames)] := 'verse';
  FSectionBars[High(FSectionBars)] := 8;
  BuildSectionControls;
end;

procedure TMainForm.BtnResetStructureClick(Sender: TObject);
begin
  ResetToDefaultStructure;
end;

procedure TMainForm.BtnSectionDeleteClick(Sender: TObject);
var Idx: Integer;
begin
  try Idx := StrToInt(Copy(TButton(Sender).Name, 7, 10)); except Exit; end;
  if Length(FSectionNames) <= 1 then Exit;
  System.Delete(FSectionNames, Idx + 1, 1);
  SetLength(FSectionBars, High(FSectionBars) + 1);
  BuildSectionControls;
end;

{ ---- Mode switching ---- }

procedure TMainForm.rgModeChange(Sender: TObject);
begin
  if rbPattern.Checked then begin
    { One pattern of the chosen genre and style: no section list. }
    ClearSectionControls;
  end
  else begin
    { Suspend redraw during control recreation to prevent flash }
    gbSong.DoubleBuffered := True;
    ResetToDefaultStructure;
    Application.ProcessMessages;
  end;
end;

{ The meter box: '4/4' (or empty) needs no option. False, with a message in
  the log, when what was typed is not a meter the engine can play. }
function TMainForm.MeterOption(out AText: String): Boolean;
var
  Num, Den: Integer;
  Problem: String;
begin
  AText := '';
  Result := True;
  if (Trim(cbMeter.Text) = '') or (Trim(cbMeter.Text) = '4/4') then
    Exit;
  if not TryParseMeter(cbMeter.Text, Num, Den) then
  begin
    Log('The meter "' + cbMeter.Text + '" is not like 7/8.');
    Exit(False);
  end;
  Problem := MeterProblem(Num, Den);
  if Problem <> '' then
  begin
    Log(Format('The meter %d/%d cannot be played: %s.', [Num, Den, Problem]));
    Exit(False);
  end;
  AText := Format('%d/%d', [Num, Den]);
end;

{ Options that both modes pass on. }
procedure TMainForm.CommonOptions(AArgs: TStrings);
var
  Meter: String;
begin
  if MeterOption(Meter) and (Meter <> '') then
  begin
    AArgs.Add('--time-sig'); AArgs.Add(Meter);
  end;
  AArgs.Add('--genre'); AArgs.Add(SelectedGenre);
  AArgs.Add('--style'); AArgs.Add(SelectedStyle);
  AArgs.Add('--output'); AArgs.Add(ChangeFileExt(OutputBasePath, '.mid'));
  if cbMapping.ItemIndex >= 0 then begin
    AArgs.Add('--mapping'); AArgs.Add(Trim(cbMapping.Text));
  end;
  if seTempo.Value > 0 then begin
    AArgs.Add('--tempo'); AArgs.Add(IntToStr(seTempo.Value));
  end;
end;

procedure TMainForm.btnGenerateClick(Sender: TObject);
var
  Args: TStringList;
  SecIdx: Integer;
  Ok: Boolean;
  MeterText: String;
begin
  if cbGenre.ItemIndex < 0 then begin Log('Pick a genre first.'); Exit; end;
  if not MeterOption(MeterText) then Exit;
  if cbStyle.ItemIndex < 0 then begin Log('Pick a style first.'); Exit; end;
  if OutputBasePath = '' then begin Log('Choose an output file name first.'); Exit; end;

  Args := TStringList.Create;
  try
    if rbPattern.Checked then begin
      Log(Format('Pattern mode: %s / %s', [SelectedGenre, SelectedStyle]));
      Args.Add('pattern');
      CommonOptions(Args);
    end
    else begin
      SyncSectionArraysFromControls;
      Log(Format('Song mode: %d sections, genre=%s style=%s',
        [Length(FSectionNames), SelectedGenre, SelectedStyle]));
      Args.Add('generate');
      CommonOptions(Args);
      if cbDrummer.ItemIndex >= 0 then begin
        Args.Add('--drummer'); Args.Add(Trim(cbDrummer.Text));
      end;
      Args.Add('--complexity'); Args.Add(CliNumber(tbComplexity.Position / 100));
      Args.Add('--humanization'); Args.Add(CliNumber(tbHumanization.Position / 100));
      { The section list on screen is the song structure. }
      for SecIdx := 0 to High(FSectionNames) do begin
        Args.Add('--section');
        Args.Add(Format('%s:%d', [Trim(FSectionNames[SecIdx]), FSectionBars[SecIdx]]));
      end;
      if tbSwing.Position > 0 then begin
        Args.Add('--swing'); Args.Add(CliNumber(SwingAmount));
      end;
      { The REAPER project goes with the Ardour session too. }
      if cbExport.ItemIndex >= ExportREAPER then Args.Add('--reaper');
      if cbExport.ItemIndex = ExportArdour then Args.Add('--ardour');
    end;

    lblStatus.Caption := 'Working...';
    if Assigned(StatusBar) then StatusBar.Panels[0].Text := 'Working...';
    btnGenerate.Enabled := False;
    Application.ProcessMessages;
    try
      Ok := RunTool(Args.ToStringArray);
    finally
      btnGenerate.Enabled := True;
    end;
  finally
    Args.Free;
  end;

  if Ok then begin
    lblStatus.Caption := 'Done';
    if Assigned(StatusBar) then StatusBar.Panels[0].Text := 'Done';
    Log('Done.');
    if chkOpenFolder.Checked then
      OpenFolder(ExtractFilePath(ExpandFileName(OutputBasePath)));
  end
  else begin
    lblStatus.Caption := 'Failed - see the log';
    if Assigned(StatusBar) then StatusBar.Panels[0].Text := 'Failed';
  end;
end;

procedure TMainForm.Log(const AText: String);
begin
  memLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);
  memLog.SelStart := Length(memLog.Text);
  memLog.SelLength := 0;
  if Assigned(StatusBar) then
    StatusBar.Panels[0].Text := AText;
end;

procedure TMainForm.cbGenreChange(Sender: TObject);
begin
  FillStyles;
  if rbSong.Checked then
    ResetToDefaultStructure;
end;

procedure TMainForm.tbComplexityChange(Sender: TObject);
begin
  UpdateValueLabels;
end;

procedure TMainForm.tbHumanizationChange(Sender: TObject);
begin
  UpdateValueLabels;
end;

procedure TMainForm.tbSwingChange(Sender: TObject);
begin
  UpdateValueLabels;
end;

procedure TMainForm.btnBrowseClick(Sender: TObject);
var
  Dlg: TSaveDialog; Base: String;
begin
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Choose where to write the song';
    Dlg.Filter := 'MIDI files (*.mid)|*.mid|All files (*.*)|*.*';
    Dlg.DefaultExt := 'mid';
    Dlg.FileName := edOutput.Text;
    if Dlg.Execute then begin Base := ChangeFileExt(Dlg.FileName, ''); edOutput.Text := Base; end;
  finally Dlg.Free; end;
end;

procedure TMainForm.btnOpenFolderClick(Sender: TObject);
var Base: String;
begin
  Base := OutputBasePath;
  if Base = '' then begin Log('No output file chosen.'); Exit; end;
  OpenFolder(ExtractFilePath(ExpandFileName(Base)));
end;

procedure TMainForm.OpenFolder(const APath: String);
var P: TProcess;
begin
  if APath = '' then begin Log('No folder to open.'); Exit; end;
  if not DirectoryExists(APath) then begin Log('Folder does not exist yet: ' + APath); Exit; end;
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(APath), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  P := TProcess.Create(nil);
  try
    P.Executable := 'xdg-open';
    P.Parameters.Add(APath);
    P.Options := P.Options + [poNoConsole];
    P.Execute;
  finally P.Free; end;
  {$ENDIF}
end;

procedure TMainForm.mnuQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.StatusBarDrawPanel(Sender: TStatusBar; Panel: TStatusPanel; const Rect: TRect);
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

procedure TMainForm.mnuAboutClick(Sender: TObject);
begin
  ShowMessage('ChameleonDrummer GUI v1.0.634' + LineEnding + LineEnding + '(c) Martin Haverland');
end;

procedure TMainForm.mnuAddSectionClick(Sender: TObject);
begin
  BtnAddSectionClick(Sender);
end;

procedure TMainForm.mnuResetStructureClick(Sender: TObject);
begin
  BtnResetStructureClick(Sender);
end;

procedure TMainForm.mnuDeleteSectionClick(Sender: TObject);
begin
  { Delete the last section if more than 1 exists }
  if Length(FSectionNames) > 1 then begin
    System.Delete(FSectionNames, High(FSectionNames), 1);
    SetLength(FSectionBars, High(FSectionBars) + 1);
    BuildSectionControls;
  end;
end;

procedure TMainForm.mnuExportConfigClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  Json: TStringList;
  I: Integer;
begin
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Export Song Configuration';
    Dlg.Filter := 'JSON files (*.json)|*.json|All files (*.*)|*.*';
    Dlg.DefaultExt := 'json';
    Dlg.FileName := ChangeFileExt(OutputBasePath, '.json');
    if Dlg.Execute then begin
      Json := TStringList.Create;
      try
        Json.Add('{');
        Json.Add(Format('  "genre": "%s",', [SelectedGenre]));
        Json.Add(Format('  "style": "%s",', [SelectedStyle]));
        Json.Add(Format('  "drummer": "%s",', [Trim(cbDrummer.Text)]));
        Json.Add(Format('  "mapping": "%s",', [Trim(cbMapping.Text)]));
        Json.Add(Format('  "meter": "%s",', [Trim(cbMeter.Text)]));
        Json.Add(Format('  "tempo": %d,', [seTempo.Value]));
        Json.Add(Format('  "complexity": %.2f,', [tbComplexity.Position / 100]));
        Json.Add(Format('  "humanization": %.2f,', [tbHumanization.Position / 100]));
        Json.Add(Format('  "swing": %.2f,', [SwingAmount]));
        Json.Add(Format('  "export_mode": %d,', [cbExport.ItemIndex]));
        Json.Add(Format('  "open_folder": %s,', [LowerCase(BoolToStr(chkOpenFolder.Checked, True))]));
        Json.Add('  "sections": [');
        for I := 0 to High(FSectionNames) do begin
          Json.Add(Format('    {"name": "%s", "bars": %d}%s',
            [FSectionNames[I], FSectionBars[I], IfThen(I < High(FSectionNames), ',', '')]));
        end;
        Json.Add('  ]');
        Json.Add('}');
        Json.SaveToFile(Dlg.FileName);
        Log('Configuration exported to ' + Dlg.FileName);
      finally
        Json.Free;
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.mnuImportConfigClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  Json: TStringList;
  Content: String;
  I: Integer;
  SectionCount: Integer;
  function ExtractValue(const AKey: String): String;
  var
    P: Integer;
  begin
    Result := '';
    P := Pos('"' + AKey + '"', Content);
    if P > 0 then begin
      P := Pos(':', Content, P);
      if P > 0 then begin
        Inc(P);
        while (P <= Length(Content)) and (Content[P] in [' ', '	', '"']) do Inc(P);
        Result := '';
        while (P <= Length(Content)) and not (Content[P] in [',', '}', ']', #13, #10, '"']) do begin
          Result := Result + Content[P];
          Inc(P);
        end;
      end;
    end;
  end;
  function ExtractBool(const AKey: String): Boolean;
  begin
    Result := LowerCase(ExtractValue(AKey)) = 'true';
  end;
  function ExtractInt(const AKey: String): Integer;
  begin
    Result := StrToIntDef(ExtractValue(AKey), 0);
  end;
  function ExtractFloat(const AKey: String): Double;
  begin
    Result := StrToFloatDef(ExtractValue(AKey), 0.0);
  end;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Import Song Configuration';
    Dlg.Filter := 'JSON files (*.json)|*.json|All files (*.*)|*.*';
    if Dlg.Execute then begin
      Json := TStringList.Create;
      try
        Json.LoadFromFile(Dlg.FileName);
        Content := Json.Text;

        { Apply values }
        cbGenre.ItemIndex := cbGenre.Items.IndexOf(ExtractValue('genre'));
        FillStyles;
        cbStyle.ItemIndex := cbStyle.Items.IndexOf(ExtractValue('style'));
        cbDrummer.ItemIndex := cbDrummer.Items.IndexOf(ExtractValue('drummer'));
        cbMapping.ItemIndex := cbMapping.Items.IndexOf(ExtractValue('mapping'));
        cbMeter.Text := ExtractValue('meter');
        seTempo.Value := ExtractInt('tempo');
        tbComplexity.Position := Round(ExtractFloat('complexity') * 100);
        tbHumanization.Position := Round(ExtractFloat('humanization') * 100);
        tbSwing.Position := Round(ExtractFloat('swing') * 100);
        cbExport.ItemIndex := ExtractInt('export_mode');
        chkOpenFolder.Checked := ExtractBool('open_folder');
        UpdateValueLabels;

        { Parse sections - simple approach }
        SectionCount := 0;
        I := Pos('"sections"', Content);
        if I > 0 then begin
          I := Pos('[', Content, I);
          while I > 0 do begin
            I := Pos('"name"', Content, I);
            if I = 0 then Break;
            Inc(SectionCount);
            I := Pos('"name"', Content, I + 1);
          end;
        end;

        if SectionCount > 0 then begin
          SetLength(FSectionNames, SectionCount);
          SetLength(FSectionBars, SectionCount);
          { Simple parsing - just use defaults for now }
          for I := 0 to SectionCount - 1 do begin
            FSectionNames[I] := 'verse';
            FSectionBars[I] := 8;
          end;
          BuildSectionControls;
        end;

        Log('Configuration imported from ' + Dlg.FileName);
      finally
        Json.Free;
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

end.
