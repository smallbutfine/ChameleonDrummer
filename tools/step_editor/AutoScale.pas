unit AutoScale;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Grids;

type
  // Struktur für die Geometrie der Komponenten beim Programmstart
  TControlGeometry = record
    Left, Top, Width, Height, FontSize: Integer;
  end;

  // Die Scaler-Klasse, die die Arbeit übernimmt
  TWindowAutoScaler = class
  private
    FForm: TForm;
    FBaseWidth, FBaseHeight: Integer;
    FGeometries: array of TControlGeometry;
  public
    constructor Create(AForm: TForm);
    procedure Rescale;
  end;

implementation

constructor TWindowAutoScaler.Create(AForm: TForm);
var
  i: Integer;
begin
  FForm := AForm;
  FBaseWidth := FForm.ClientWidth;
  FBaseHeight := FForm.ClientHeight;
  
  // Maße aller Komponenten auf der ersten Ebene des Fensters sichern
  SetLength(FGeometries, FForm.ControlCount);
  for i := 0 to FForm.ControlCount - 1 do
  begin
    FGeometries[i].Left := FForm.Controls[i].Left;
    FGeometries[i].Top := FForm.Controls[i].Top;
    FGeometries[i].Width := FForm.Controls[i].Width;
    FGeometries[i].Height := FForm.Controls[i].Height;
    
    // Pixel-Berechnung für Schriften erzwingen
    FForm.Controls[i].Font.PixelsPerInch := FForm.PixelsPerInch;
    FGeometries[i].FontSize := FForm.Controls[i].Font.Height;
  end;
end;

procedure TWindowAutoScaler.Rescale;
var
  i: Integer;
  ScaleX, ScaleY, MinScale: Double;
begin
  if (FBaseWidth = 0) or (FBaseHeight = 0) then Exit;

  // Aktuelle Faktoren berechnen
  ScaleX := FForm.ClientWidth / FBaseWidth;
  ScaleY := FForm.ClientHeight / FBaseHeight;

  // Den kleineren Faktor wählen (verzerrungsfrei)
  if ScaleX < ScaleY then MinScale := ScaleX else MinScale := ScaleY;

  FForm.DisableAlign;
  try
    for i := 0 to FForm.ControlCount - 1 do
    begin
      FForm.Controls[i].Left := Round(FGeometries[i].Left * MinScale);
      FForm.Controls[i].Top := Round(FGeometries[i].Top * MinScale);
      FForm.Controls[i].Width := Round(FGeometries[i].Width * MinScale);
      FForm.Controls[i].Height := Round(FGeometries[i].Height * MinScale);
      
      // Schriftart in Pixeln mitskalieren
      FForm.Controls[i].Font.Height := Round(FGeometries[i].FontSize * MinScale);
      FForm.Controls[i].Font.Quality := fqAntialiased;

      // Spezialfall Grids abfangen
      if FForm.Controls[i] is TStringGrid then
      begin
        with TStringGrid(FForm.Controls[i]) do
        begin
          DefaultRowHeight := Round(24 * MinScale);
          DefaultColWidth := Round(64 * MinScale);
        end;
      end;
    end;
  finally
    FForm.EnableAlign;
  end;
end;

end.
