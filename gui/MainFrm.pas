unit MainFrm;

{$mode objfpc}{$H+}

{ ChameleonDrummer - graphical front end (CLI wrapper).

  Collects inputs from the UI and passes them to the standalone CLI executable
  (chameleondrummer.exe) via TProcess. All dropdown values are hardcoded so
  the GUI never depends on plugin discovery. }

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Spin,
  Dialogs, LCLType, ShellApi, process, StrUtils, menus;

type
  TIntDynArray = array of Integer;
  TStrDynArray = array of String;

  TMainForm = class(TForm)
    gbSong: TGroupBox;
    MainMenu: TMainMenu;
    mnuFile: TMenuItem;
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
    procedure mnuAboutClick(Sender: TObject);
  private
    FSectionNames: TStrDynArray;
    FSectionBars: TIntDynArray;
    procedure Log(const AText: String);
    procedure FillStyles;
    procedure ResetToDefaultStructure;
    procedure UpdateValueLabels;
    function SwingAmount: Double;
    function SelectedGenre: String;
    function SelectedStyle: String;
    function OutputBasePath: String;
    procedure OpenFolder(const APath: String);
    procedure BuildSectionControls;
    procedure SyncSectionArraysFromControls;
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
const
  Drummers: array[0..16] of String = (
    'bonham', 'porcaro', 'weckl', 'chambers', 'roeder',
    'dee', 'hoglan', 'peart', 'rich', 'copeland',
    'carey', 'smith', 'moon', 'watts', 'haake',
    'halpern', 'doomblues'
  );
var
  I: Integer;
begin
  { Keymaps }
  cbMapping.Items.Add('gm');
  cbMapping.Items.Add('ad2');
  cbMapping.Items.Add('ezd3');
  cbMapping.Items.Add('xg');
  cbMapping.ItemIndex := 0;

  { Genres - hardcoded from DrumGenerator.pas LoadPlugins() }
  cbGenre.Items.Add('metal');
  cbGenre.Items.Add('rock');
  cbGenre.Items.Add('jazz');
  cbGenre.Items.Add('funk');
  cbGenre.Items.Add('electronic');
  cbGenre.ItemIndex := 0;

  { Drummers - hardcoded from DrumGenerator.pas LoadPlugins() }
  for I := Low(Drummers) to High(Drummers) do
    cbDrummer.Items.Add(Drummers[I]);

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

  ResetToDefaultStructure;

  Log('Choose a genre and style, pick a drummer, then press Generate.');
  lblStatus.Caption := 'Ready';
end;

procedure TMainForm.FillStyles;
const
  MetalStyles: array[0..6] of String = ('heavy','death','power','progressive','thrash','doom','breakdown');
  RockStyles: array[0..6] of String = ('classic','blues','alternative','progressive','punk','hard','pop');
  JazzStyles: array[0..6] of String = ('swing','bebop','fusion','latin','ballad','hard_bop','contemporary');
  FunkStyles: array[0..6] of String = ('classic','pfunk','shuffle','new_orleans','fusion','minimal','heavy');
  ElectronicStyles: array[0..3] of String = ('house','techno','drum_and_bass','dubstep');
var
  I: Integer;
begin
  if rbPattern.Checked then Exit;
  cbStyle.Clear;
  if SameText(SelectedGenre, 'metal') then
    for I := Low(MetalStyles) to High(MetalStyles) do cbStyle.Items.Add(MetalStyles[I])
  else if SameText(SelectedGenre, 'rock') then
    for I := Low(RockStyles) to High(RockStyles) do cbStyle.Items.Add(RockStyles[I])
  else if SameText(SelectedGenre, 'jazz') then
    for I := Low(JazzStyles) to High(JazzStyles) do cbStyle.Items.Add(JazzStyles[I])
  else if SameText(SelectedGenre, 'funk') then
    for I := Low(FunkStyles) to High(FunkStyles) do cbStyle.Items.Add(FunkStyles[I])
  else if SameText(SelectedGenre, 'electronic') then
    for I := Low(ElectronicStyles) to High(ElectronicStyles) do cbStyle.Items.Add(ElectronicStyles[I]);

  if cbStyle.Items.Count > 0 then
    cbStyle.ItemIndex := 0;
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

procedure TMainForm.BuildSectionControls;
var
  I, Y: Integer;
  C: TComponent;
  lblName: TLabel;
  cmbSection: TComboBox;
  seBars: TSpinEdit;
  btnDelete: TButton;
begin
  { Remove old dynamic controls }
  for I := gbSong.ComponentCount - 1 downto 0 do begin
    C := gbSong.Components[I];
    if (C is TLabel) and AnsiStartsStr('Section ', TLabel(C).Caption) then
      gbSong.Components[I].Free
    else if (C is TComboBox) and AnsiStartsStr('secCmb', C.Name) then
      gbSong.Components[I].Free
    else if (C is TSpinEdit) and AnsiStartsStr('secSpn', C.Name) then
      gbSong.Components[I].Free
    else if (C is TButton) and ((AnsiStartsStr('secDel', C.Name)) or (C.Name = 'btnAddSection') or (C.Name = 'btnResetStructure')) then
      gbSong.Components[I].Free;
  end;

  SetLength(FSectionBars, Length(FSectionNames));

  Y := 200; for I := 0 to High(FSectionNames) do begin
    lblName := TLabel.Create(gbSong); with lblName do begin Parent := gbSong; Left := 12; Top := Y; Width := 70; Height := 14; Caption := Format('Section %d', [I+1]); end;
    cmbSection := TComboBox.Create(gbSong); with cmbSection do begin Parent := gbSong; Name := Format('secCmb%d', [I]); Left := 80; Top := Y; Width := 180; Height := 24; Items.Add('intro'); Items.Add('verse'); Items.Add('chorus'); Items.Add('bridge'); Items.Add('outro'); ItemIndex := Items.IndexOf(FSectionNames[I]); end;
    seBars := TSpinEdit.Create(gbSong); with seBars do begin Parent := gbSong; Name := Format('secSpn%d', [I]); Left := 270; Top := Y; Width := 60; Height := 24; MinValue := 1; MaxValue := 64; Value := FSectionBars[I]; end;
    btnDelete := TButton.Create(gbSong); with btnDelete do begin Parent := gbSong; Name := Format('secDel%d', [I]); Left := 340; Top := Y; Width := 28; Height := 24; Caption := '-'; OnClick := @BtnSectionDeleteClick; end;
    Inc(Y, 28); end;
end;

procedure TMainForm.SyncSectionArraysFromControls;
var
  I: Integer;
  cmb: TComboBox;
  spn: TSpinEdit;
begin
  SetLength(FSectionBars, Length(FSectionNames));
  for I := 0 to High(FSectionNames) do begin
    cmb := gbSong.FindComponent(Format('secCmb%d', [I])) as TComboBox;
    if (cmb <> nil) then FSectionNames[I] := cmb.Text;
    spn := gbSong.FindComponent(Format('secSpn%d', [I])) as TSpinEdit;
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
var
  I: Integer;
  C: TComponent;
begin
  if rbPattern.Checked then begin
    lblStyle.Caption := 'Pattern';
    cbStyle.Items.Clear;
    cbStyle.Items.Add('BasicGroove');
    cbStyle.Items.Add('DoubleBassPedal');
    cbStyle.Items.Add('BlastBeat');
    cbStyle.Items.Add('JazzRidePattern');
    cbStyle.Items.Add('FunkGhostNotes');
    cbStyle.Items.Add('CrashAccents');
    cbStyle.Items.Add('TomFill');
    cbStyle.ItemIndex := 0;
    { Hide dynamic section controls }
    for I := gbSong.ComponentCount - 1 downto 0 do begin
      C := gbSong.Components[I];
      if (C is TLabel) or (C is TComboBox) or (C is TSpinEdit) or ((C is TButton) and AnsiStartsStr('secDel', C.Name)) then
        (C as TControl).Visible := False;
    end;
  end
  else begin
    lblStyle.Caption := 'Style';
    FillStyles;
    { Suspend redraw during control recreation to prevent flash }
    gbSong.DoubleBuffered := True;
    ResetToDefaultStructure;
    Application.ProcessMessages;
  end;
end;

procedure TMainForm.btnGenerateClick(Sender: TObject);
var
  Mode, Genre, Style, OutputFile: String;
  TempoVal, SecIdx: Integer;
begin
  if cbGenre.ItemIndex < 0 then begin Log('Pick a genre first.'); Exit; end;
  if cbStyle.ItemIndex < 0 then begin Log('Pick a style/first.'); Exit; end;

  Mode := 'Pattern (single pattern)';
  Genre := SelectedGenre;
  Style := SelectedStyle;

  OutputFile := ChangeFileExt(OutputBasePath, '.mid');
  TempoVal := seTempo.Value;

  Log(Format('--- initiating generation: mode=%s genre=%s style=%s ---', [Mode, Genre, Style]));

  if rbPattern.Checked then begin
    { Pattern mode }
    Log(Format('Pattern mode: %s / %s', [Genre, Style]));
    with TProcess.Create(nil) do try
      Executable := ExtractFilePath(ParamStr(0)) + 'chameleondrummer.exe';
      Options := [poUsePipes, poStderrToOutput, poNoConsole];
      Parameters.Add('pattern');
      Parameters.Add('--genre'); Parameters.Add(Genre);
      Parameters.Add('--style'); Parameters.Add(Style);
      Parameters.Add('--output'); Parameters.Add(OutputFile);
      if TempoVal > 0 then begin Parameters.Add('--tempo'); Parameters.Add(IntToStr(TempoVal)); end;
      Execute;
    finally Free; end;
    Log('Pattern generated.');
  end
  else
  begin
    { Song mode }
    SyncSectionArraysFromControls;
    Log(Format('Song mode: %d sections, genre=%s style=%s', [Length(FSectionNames), Genre, Style]));

    with TProcess.Create(nil) do try
      Executable := ExtractFilePath(ParamStr(0)) + 'chameleondrummer.exe';
      Options := [poUsePipes, poStderrToOutput, poNoConsole];
      Parameters.Add('generate');
      Parameters.Add('--genre'); Parameters.Add(Genre);
      Parameters.Add('--style'); Parameters.Add(Style);
      Parameters.Add('--output'); Parameters.Add(OutputFile);
      if cbDrummer.ItemIndex >= 0 then begin
        Parameters.Add('--drummer'); Parameters.Add(Trim(cbDrummer.Text));
      end;
      if cbMapping.ItemIndex >= 0 then begin
        Parameters.Add('--mapping'); Parameters.Add(Trim(cbMapping.Text));
      end;
      if TempoVal > 0 then begin
        Parameters.Add('--tempo'); Parameters.Add(IntToStr(TempoVal));
      end;
      Parameters.Add('--complexity'); Parameters.Add(CliNumber(tbComplexity.Position / 100));
      Parameters.Add('--humanization'); Parameters.Add(CliNumber(tbHumanization.Position / 100));
      { The section list on screen is the song structure. }
      for SecIdx := 0 to High(FSectionNames) do begin
        Parameters.Add('--section');
        Parameters.Add(Format('%s:%d', [Trim(FSectionNames[SecIdx]), FSectionBars[SecIdx]]));
      end;
      if tbSwing.Position > 0 then begin
        Parameters.Add('--swing'); Parameters.Add(CliNumber(SwingAmount));
      end;
      case cbExport.ItemIndex of
        ExportREAPER: Parameters.Add('--reaper');
        ExportArdour: Parameters.Add('--ardour');
      end;
      Execute;
    finally Free; end;
    Log('Song generated.');
  end;
end;

procedure TMainForm.Log(const AText: String);
begin
  memLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);
  memLog.SelStart := Length(memLog.Text);
  memLog.SelLength := 0;
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
begin
  if APath = '' then begin Log('No folder to open.'); Exit; end;
  if not DirectoryExists(APath) then begin Log('Folder does not exist yet: ' + APath); Exit; end;
  ShellExecute(0, 'open', PChar(APath), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.mnuQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.mnuAboutClick(Sender: TObject);
begin
  ShowMessage('ChameleonDrummer GUI v1.0.634' + LineEnding + LineEnding + '(c) Martin Haverland');
end;

end.
