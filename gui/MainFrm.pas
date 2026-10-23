unit MainFrm;

{$mode objfpc}{$H+}

{ ChameleonDrummer - graphical front end (CLI wrapper).

  Collects inputs from the UI and passes them to the standalone CLI executable
  (chameleondrummer.exe) via TProcess. All dropdown values are hardcoded so
  the GUI never depends on plugin discovery. }

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Spin,
  Dialogs, LCLType, ShellApi, process;

type
  TMainForm = class(TForm)
    gbSong: TGroupBox;
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
    procedure cbGenreChange(Sender: TObject);
    procedure tbComplexityChange(Sender: TObject);
    procedure tbHumanizationChange(Sender: TObject);
    procedure btnGenerateClick(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnOpenFolderClick(Sender: TObject);
  private
    procedure Log(const AText: String);
    procedure FillStyles;
    procedure UpdateValueLabels;
    function SelectedGenre: String;
    function SelectedStyle: String;
    function OutputBasePath: String;
    procedure OpenFolder(const APath: String);
  end;

var
  MainForm: TMainForm;

implementation

{ The form file is named after the form class, not after this unit }
{$R TMainForm.lfm}

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

  FillStyles; { Populates styles for the selected genre }

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

  UpdateValueLabels;

  Log('ChameleonDrummer GUI ready.');
  Log('Choose a genre and style, pick a drummer, then press Generate.');
  lblStatus.Caption := 'Ready';
end;

procedure TMainForm.FillStyles;
var
  Styles: array of String;
  I: Integer;
begin
  cbStyle.Clear;

  if SameText(SelectedGenre, 'metal') then begin
    SetLength(Styles, 7); Styles[0] := 'heavy'; Styles[1] := 'death'; Styles[2] := 'power';
    Styles[3] := 'progressive'; Styles[4] := 'thrash'; Styles[5] := 'doom'; Styles[6] := 'breakdown';
  end else if SameText(SelectedGenre, 'rock') then begin
    SetLength(Styles, 7); Styles[0] := 'classic'; Styles[1] := 'blues'; Styles[2] := 'alternative';
    Styles[3] := 'progressive'; Styles[4] := 'punk'; Styles[5] := 'hard'; Styles[6] := 'pop';
  end else if SameText(SelectedGenre, 'jazz') then begin
    SetLength(Styles, 7); Styles[0] := 'swing'; Styles[1] := 'bebop'; Styles[2] := 'fusion';
    Styles[3] := 'latin'; Styles[4] := 'ballad'; Styles[5] := 'hard_bop'; Styles[6] := 'contemporary';
  end else if SameText(SelectedGenre, 'funk') then begin
    SetLength(Styles, 7); Styles[0] := 'classic'; Styles[1] := 'pfunk'; Styles[2] := 'shuffle';
    Styles[3] := 'new_orleans'; Styles[4] := 'fusion'; Styles[5] := 'minimal'; Styles[6] := 'heavy';
  end else if SameText(SelectedGenre, 'electronic') then begin
    SetLength(Styles, 4); Styles[0] := 'house'; Styles[1] := 'techno'; Styles[2] := 'drum_and_bass'; Styles[3] := 'dubstep';
  end;

  for I := Low(Styles) to High(Styles) do
    cbStyle.Items.Add(Styles[I]);

  if Length(Styles) > 0 then
    cbStyle.ItemIndex := 0;
end;

procedure TMainForm.UpdateValueLabels;
begin
  lblComplexityValue.Caption := FormatFloat('0.00', tbComplexity.Position / 100);
  lblHumanizationValue.Caption := FormatFloat('0.00', tbHumanization.Position / 100);
end;

function TMainForm.SelectedGenre: String;
begin
  if cbGenre.ItemIndex < 0 then
    Result := ''
  else
    Result := cbGenre.Items[cbGenre.ItemIndex];
end;

function TMainForm.SelectedStyle: String;
begin
  if cbStyle.ItemIndex < 0 then
    Result := ''
  else
    Result := cbStyle.Items[cbStyle.ItemIndex];
end;

function TMainForm.OutputBasePath: String;
begin
  Result := Trim(edOutput.Text);
end;

procedure TMainForm.Log(const AText: String);
begin
  memLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);
  { keep the newest line in view }
  memLog.SelStart := Length(memLog.Text);
  memLog.SelLength := 0;
end;

procedure TMainForm.cbGenreChange(Sender: TObject);
begin
  FillStyles;
end;

procedure TMainForm.tbComplexityChange(Sender: TObject);
begin
  UpdateValueLabels;
end;

procedure TMainForm.tbHumanizationChange(Sender: TObject);
begin
  UpdateValueLabels;
end;

procedure TMainForm.btnBrowseClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  Base: String;
begin
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Choose where to write the song';
    Dlg.Filter := 'MIDI files (*.mid)|*.mid|All files (*.*)|*.*';
    Dlg.DefaultExt := 'mid';
    Dlg.FileName := edOutput.Text;
    if Dlg.Execute then
    begin
      Base := ChangeFileExt(Dlg.FileName, '');
      edOutput.Text := Base;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.btnOpenFolderClick(Sender: TObject);
var
  Base: String;
begin
  Base := OutputBasePath;
  if Base = '' then
  begin
    Log('No output file chosen.');
    Exit;
  end;
  OpenFolder(ExtractFilePath(ExpandFileName(Base)));
end;

procedure TMainForm.OpenFolder(const APath: String);
begin
  if APath = '' then
  begin
    Log('No folder to open.');
    Exit;
  end;
  if not DirectoryExists(APath) then
  begin
    Log('Folder does not exist yet: ' + APath);
    Exit;
  end;
  ShellExecute(0, 'open', PChar(APath), nil, nil, SW_SHOWNORMAL);
end;

{ --- CLI WRAPPER IMPLEMENTATION --- }

procedure TMainForm.btnGenerateClick(Sender: TObject);
var
  OutputFile: String;
  Proc: TProcess;
  Buffer: array[0..4095] of AnsiChar;
  BytesRead: LongInt;
begin
  { Validation }
  if cbGenre.ItemIndex < 0 then begin Log('Pick a genre first.'); Exit; end;
  if cbStyle.ItemIndex < 0 then begin Log('Pick a style first.'); Exit; end;

  OutputFile := ChangeFileExt(OutputBasePath, '.mid');

  Log('--- initiating CLI generation: ' + SelectedGenre + '/' + SelectedStyle + ' ---');
  lblStatus.Caption := 'Building command...';
  Application.ProcessMessages;

  Proc := TProcess.Create(nil);
  try
    { Configure Process for execution and piping }
    Proc.Executable := 'chameleondrummer.exe'; { Assumes CLI is in PATH or working dir }
    Proc.Options := [poUsePipes, poStderrToOutput, poNoConsole]; { Capture stdout/stderr, hide console window }

    { Add arguments to the process (avoids shell escaping issues) }
    Proc.Parameters.Add('--song');
    Proc.Parameters.Add('--genre');
    Proc.Parameters.Add(SelectedGenre);
    Proc.Parameters.Add('--style');
    Proc.Parameters.Add(SelectedStyle);

    if cbDrummer.ItemIndex >= 0 then begin
      Proc.Parameters.Add('--drummer');
      Proc.Parameters.Add(cbDrummer.Items[cbDrummer.ItemIndex]);
    end;

    { Mapping }
    if cbMapping.ItemIndex >= 0 then
    begin
      Proc.Parameters.Add('--mapping');
      Proc.Parameters.Add(Trim(cbMapping.Text));
    end;

    { Tempo (if user set it manually) }
    if seTempo.Value > 0 then
    begin
      Proc.Parameters.Add('--tempo');
      Proc.Parameters.Add(IntToStr(seTempo.Value));
    end;

    { Complexity and Humanization (as decimals matching CLIInterface.pas defaults) }
    Proc.Parameters.Add('--complexity');
    Proc.Parameters.Add(FloatToStr(tbComplexity.Position / 100));

    Proc.Parameters.Add('--humanization');
    Proc.Parameters.Add(FloatToStr(tbHumanization.Position / 100));

    { Output file }
    Proc.Parameters.Add('--output');
    Proc.Parameters.Add(OutputFile);

    { Export Flags based on UI selection }
    case cbExport.ItemIndex of
      ExportREAPER: Proc.Parameters.Add('--reaper');
      ExportArdour: Proc.Parameters.Add('--ardour');
    end;

    { Execute }
    Log('Executing CLI...');
    lblStatus.Caption := 'Running CLI...';
    Application.ProcessMessages;

    Proc.Execute;
    Application.ProcessMessages;

    { Pipe Output Loop - Real-time logging }
    pbProgress.Style := pbstMarquee;
    pbProgress.Visible := True;

    { Read output line by line }
    while Proc.Running and (Proc.Output.NumBytesAvailable > 0) do
    begin
      BytesRead := Proc.Output.Read(Buffer[0], SizeOf(Buffer));
      if BytesRead > 0 then
        Log(Copy(AnsiString(Buffer), 1, BytesRead));

      Application.ProcessMessages; { Keep UI responsive }
      Sleep(50); { Prevent CPU spinning }
    end;

    { Read any remaining output }
    while Proc.Output.NumBytesAvailable > 0 do
    begin
      BytesRead := Proc.Output.Read(Buffer[0], SizeOf(Buffer));
      if BytesRead > 0 then
        Log(Copy(AnsiString(Buffer), 1, BytesRead));
    end;

    pbProgress.Visible := False;

    if Proc.ExitCode = 0 then
      Log('CLI finished successfully.')
    else
      Log('[Error] CLI exited with code: ' + IntToStr(Proc.ExitCode));

    lblStatus.Caption := 'Ready';

  finally
    Proc.Free;
  end;

  { Post-generation tasks }
  if chkOpenFolder.Checked and FileExists(OutputFile) then
    OpenFolder(ExtractFilePath(OutputFile));
end;

end.
