unit Rich;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TRichPlugin = class(TDrummerPlugin)
  private
    FSpeedPrecision: TSpeedPrecision;
    FHeavyAccents: THeavyAccents;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TRichPlugin.Create;
begin
  inherited Create;
  FSpeedPrecision := TSpeedPrecision.Create(0.96);
  FHeavyAccents := THeavyAccents.Create(18);
end;

destructor TRichPlugin.Destroy;
begin
  FSpeedPrecision.Free;
  FHeavyAccents.Free;
  inherited Destroy;
end;

function TRichPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_rich';

  // Virtuosic speed and precision (Buddy Rich signature)
  Styled := FSpeedPrecision.Apply(Styled, 0.96);

  // Dramatic dynamic contrast
  Styled := FHeavyAccents.Apply(Styled, 0.9);

  Result := Styled;
end;

function TRichPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('rich_virtuoso_fill', 'Buddy Rich virtuoso fill') do
  begin
    Pattern := TTombFill.Create('ascending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TRichPlugin.GetDrummerName: String;
begin
  Result := 'rich';
end;

function TRichPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('jazz');
  Result.Add('rock');
  Result.Add('swing');
end;

end.
