unit MainFrm;

{$mode objfpc}{$H+}

{ ChameleonDrummer - graphical front end.

  Wraps the Engine V2 generator that the command line tool drives. The GUI
  links the engine directly rather than shelling out to the executable, so
  the log can be updated live and the parameters come from the widgets
  instead of an argument vector. }

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Spin,
  Dialogs, FileCtrl, LCLType, Math, Windows,
  DrumGenerator, PluginRegistry, Kit, Song, ReaperAPI, ArdourAPI;

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
    FGenerator: TDrumGenerator;
    procedure Log(const AText: String);
    procedure FillGenres;
    procedure FillStyles;
    procedure FillDrummers;
    procedure UpdateValueLabels;
    function SelectedGenre: String;
    function SelectedStyle: String;
    function SelectedDrummer: String;
    function SelectedMapping: String;
    function OutputBasePath: String;
    procedure OpenFolder(const APath: String);
  end;

var
  MainForm: TMainForm;

implementation

const
  ExportMIDI = 0;
  ExportREAPER = 1;
  ExportArdour = 2;

procedure TMainForm.FormCreate(Sender: TObject);
var
  Mappings: array[0..3] of String;
  I: Integer;
begin
  FGenerator := TDrumGenerator.Create;

  FillGenres;

  Mappings[0] := 'gm';
  Mappings[1] := 'ad2';
  Mappings[2] := 'ezd3';
  Mappings[3] := 'xg';
  for I := Low(Mappings) to High(Mappings) do
    cbMapping.Items.Add(Mappings[I]);
  cbMapping.ItemIndex := 0;

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

procedure TMainForm.FillGenres;
var
  Genres: TStringArray;
  I: Integer;
begin
  Genres := FGenerator.PluginManager.Registry.GetAvailableGenres;
  cbGenre.Clear;
  for I := 0 to High(Genres) do
    cbGenre.Items.Add(Genres[I]);
  if cbGenre.Items.Count > 0 then
    cbGenre.ItemIndex := 0;
  FillStyles;
  FillDrummers;
end;

procedure TMainForm.FillStyles;
var
  Styles: TStringArray;
  I: Integer;
begin
  Styles := FGenerator.PluginManager.Registry.GetStylesForGenre(SelectedGenre);
  cbStyle.Clear;
  for I := 0 to High(Styles) do
    cbStyle.Items.Add(Styles[I]);
  if cbStyle.Items.Count > 0 then
    cbStyle.ItemIndex := 0;
end;

procedure TMainForm.FillDrummers;
var
  Drummers: TStringArray;
  I: Integer;
begin
  Drummers := FGenerator.PluginManager.Registry.GetAvailableDrummers;
  cbDrummer.Clear;
  for I := 0 to High(Drummers) do
    cbDrummer.Items.Add(Drummers[I]);
  if cbDrummer.Items.Count > 0 then
    cbDrummer.ItemIndex := 0;
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

function TMainForm.SelectedDrummer: String;
begin
  if cbDrummer.ItemIndex < 0 then
    Result := ''
  else
    Result := cbDrummer.Items[cbDrummer.ItemIndex];
end;

function TMainForm.SelectedMapping: String;
begin
  if cbMapping.ItemIndex < 0 then
    Result := 'gm'
  else
    Result := cbMapping.Items[cbMapping.ItemIndex];
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
  Log('Genre: ' + SelectedGenre);
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

procedure TMainForm.btnGenerateClick(Sender: TObject);
var
  Song: TSong;
  DrumKit: TDrumKit;
  Bridge: TReaperBridge;
  ArdourBridge: TArdourBridge;
  Base, MidiFile, RppFile, SessionDir: String;
  Started: TDateTime;
  Elapsed: Double;
begin
  if SelectedGenre = '' then
  begin
    Log('Pick a genre first.');
    Exit;
  end;
  if SelectedStyle = '' then
  begin
    Log('Pick a style first.');
    Exit;
  end;

  Base := OutputBasePath;
  if Base = '' then
  begin
    Log('Choose an output file name first.');
    Exit;
  end;

  Log('--- generating ' + SelectedGenre + '/' + SelectedStyle + ' with ' +
    SelectedDrummer + ' ---');
  lblStatus.Caption := 'Generating...';
  pbProgress.Style := pbstMarquee;
  pbProgress.Visible := True;
  Application.ProcessMessages;

  Started := Now;
  try
    DrumKit := TDrumKit.FromKeymapName(SelectedMapping);
    try
      Song := FGenerator.CreateSong(SelectedGenre, SelectedStyle, seTempo.Value,
        nil, DrumKit, SelectedDrummer, tbComplexity.Position / 100, 0.6,
        tbHumanization.Position / 100);
    finally
      DrumKit.Free;
    end;
    try
      MidiFile := ChangeFileExt(Base, '.mid');
      FGenerator.SaveSongMidi(Song, MidiFile);
      Log('MIDI written: ' + MidiFile);

      if cbExport.ItemIndex >= ExportREAPER then
      begin
        RppFile := ChangeFileExt(MidiFile, '.rpp');
        Bridge := TReaperBridge.Create;
        try
          if Bridge.CreateFromSong(Song, MidiFile) then
            Log('REAPER project written: ' + RppFile)
          else
            Log('[Warning] REAPER export failed.');
        finally
          Bridge.Free;
        end;
      end;

      if cbExport.ItemIndex >= ExportArdour then
      begin
        SessionDir := ChangeFileExt(Base, '.ardour');
        ArdourBridge := TArdourBridge.Create;
        try
          if ArdourBridge.CreateFromSong(Song, MidiFile, SessionDir) then
            Log('Ardour session written: ' + SessionDir)
          else
            Log('[Warning] Ardour export failed.');
        finally
          ArdourBridge.Free;
        end;
      end;
    finally
      Song.Free;
    end;

    Elapsed := Now - Started;
    Log(Format('Done in %.2f seconds.', [Elapsed]));
    lblStatus.Caption := Format('Done in %.2f seconds.', [Elapsed]);
  except
    on E: Exception do
    begin
      Log('[Error] ' + E.ClassName + ': ' + E.Message);
      lblStatus.Caption := 'Failed';
    end;
  end;
  pbProgress.Visible := False;

  if chkOpenFolder.Checked then
    OpenFolder(ExtractFilePath(ExpandFileName(Base)));
end;

end.
