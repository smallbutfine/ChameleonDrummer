unit AutoScale;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Grids, LCLType, LCLIntf;

type
  TControlScaleInfo = record
    Control: TControl;
    Left, Top, Width, Height: Integer;
    FontSize: Integer;
    DefaultRowHeight: Integer;
    DefaultColWidth: Integer;
    ColWidths: array of Integer;
    RowHeights: array of Integer;
    Align: TAlign;
    Anchors: TAnchors;
    ScaleEnabled: Boolean;
  end;

  TWindowAutoScaler = class
  private
    FForm: TCustomForm;
    FBaseWidth, FBaseHeight: Integer;
    FInfos: array of TControlScaleInfo;
    FOldOnResize: TNotifyEvent;
    FEnabled: Boolean;
    procedure CollectControls(AControl: TControl);
    procedure ApplyScale(AControl: TControl; const AInfo: TControlScaleInfo; AScale: Double);
    procedure OnFormResize(Sender: TObject);
  public
    constructor Create(AForm: TCustomForm);
    destructor Destroy; override;
    procedure Rescale;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

implementation

constructor TWindowAutoScaler.Create(AForm: TCustomForm);
var
  i: Integer;
  Info: TControlScaleInfo;
  Grid: TCustomGrid;
begin
  FForm := AForm;
  FBaseWidth := FForm.ClientWidth;
  FBaseHeight := FForm.ClientHeight;
  FEnabled := True;

  FOldOnResize := FForm.OnResize;
  FForm.OnResize := OnFormResize;

  CollectControls(FForm);
end;

destructor TWindowAutoScaler.Destroy;
begin
  if Assigned(FForm) then
    FForm.OnResize := FOldOnResize;
  inherited Destroy;
end;

procedure TWindowAutoScaler.CollectControls(AControl: TControl);
var
  i: Integer;
  Info: TControlScaleInfo;
  Grid: TCustomGrid;
begin
  Info.Control := AControl;
  Info.Left := AControl.Left;
  Info.Top := AControl.Top;
  Info.Width := AControl.Width;
  Info.Height := AControl.Height;
  Info.FontSize := AControl.Font.Size;
  Info.Align := AControl.Align;
  Info.Anchors := AControl.Anchors;
  Info.ScaleEnabled := AControl.Tag = 0;

  if AControl is TCustomGrid then
  begin
    Grid := TCustomGrid(AControl);
    Info.DefaultRowHeight := Grid.DefaultRowHeight;
    Info.DefaultColWidth := Grid.DefaultColWidth;
    SetLength(Info.ColWidths, Grid.ColCount);
    SetLength(Info.RowHeights, Grid.RowCount);
    for i := 0 to Grid.ColCount - 1 do
      Info.ColWidths[i] := Grid.ColWidths[i];
    for i := 0 to Grid.RowCount - 1 do
      Info.RowHeights[i] := Grid.RowHeights[i];
  end
  else
  begin
    Info.DefaultRowHeight := 0;
    Info.DefaultColWidth := 0;
    SetLength(Info.ColWidths, 0);
    SetLength(Info.RowHeights, 0);
  end;

  SetLength(FInfos, Length(FInfos) + 1);
  FInfos[High(FInfos)] := Info;

  if AControl is TWinControl then
    for i := 0 to TWinControl(AControl).ControlCount - 1 do
      CollectControls(TWinControl(AControl).Controls[i]);
end;

procedure TWindowAutoScaler.ApplyScale(AControl: TControl; const AInfo: TControlScaleInfo; AScale: Double);
var
  Grid: TCustomGrid;
  i: Integer;
begin
  if not AInfo.ScaleEnabled then Exit;

  // Respect alignment: don't resize aligned controls, only move them
  if AInfo.Align <> alNone then
  begin
    if not (akLeft in AInfo.Anchors) then
      AControl.Left := Round(AInfo.Left * AScale);
    if not (akTop in AInfo.Anchors) then
      AControl.Top := Round(AInfo.Top * AScale);
    Exit;
  end;

  AControl.Left := Round(AInfo.Left * AScale);
  AControl.Top := Round(AInfo.Top * AScale);
  AControl.Width := Round(AInfo.Width * AScale);
  AControl.Height := Round(AInfo.Height * AScale);

  if AInfo.FontSize > 0 then
    AControl.Font.Size := Round(AInfo.FontSize * AScale);

  if AControl is TCustomGrid then
  begin
    Grid := TCustomGrid(AControl);
    Grid.DefaultRowHeight := Round(AInfo.DefaultRowHeight * AScale);
    Grid.DefaultColWidth := Round(AInfo.DefaultColWidth * AScale);
    for i := 0 to Grid.ColCount - 1 do
      if i < Length(AInfo.ColWidths) then
        Grid.ColWidths[i] := Round(AInfo.ColWidths[i] * AScale);
    for i := 0 to Grid.RowCount - 1 do
      if i < Length(AInfo.RowHeights) then
        Grid.RowHeights[i] := Round(AInfo.RowHeights[i] * AScale);
  end;
end;

procedure TWindowAutoScaler.Rescale;
var
  i: Integer;
  ScaleX, ScaleY, MinScale: Double;
begin
  if not FEnabled or not Assigned(FForm) then Exit;
  if (FBaseWidth = 0) or (FBaseHeight = 0) then Exit;

  ScaleX := FForm.ClientWidth / FBaseWidth;
  ScaleY := FForm.ClientHeight / FBaseHeight;

  if ScaleX < ScaleY then MinScale := ScaleX else MinScale := ScaleY;

  FForm.DisableAlign;
  try
    for i := 0 to High(FInfos) do
      if Assigned(FInfos[i].Control) then
        ApplyScale(FInfos[i].Control, FInfos[i], MinScale);
  finally
    FForm.EnableAlign;
  end;
end;

procedure TWindowAutoScaler.OnFormResize(Sender: TObject);
begin
  if FEnabled then
    Rescale;
  if Assigned(FOldOnResize) then
    FOldOnResize(Sender);
end;

end.
