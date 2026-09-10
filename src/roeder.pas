unit Roeder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TRoederPlugin = class(TDrummerPlugin)
  private
    FMinimalCreativity: TMinimalCreativity;
    FBehindBeat: TBehindBeatTiming;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TRoederPlugin.Create;
begin
  inherited Create;
  FMinimalCreativity := TMinimalCreativity.Create;
  FBehindBeat := TBehindBeatTiming.Create(30.0);
end;

destructor TRoederPlugin.Destroy;
begin
  FMinimalCreativity.Free;
  FBehindBeat.Free;
  inherited Destroy;
end;

function TRoederPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_roeder';

  // Minimal creativity (atmospheric sludge approach)
  Styled := FMinimalCreativity.Apply(Styled, 0.8);

  // Heavy behind-beat timing
  Styled := FBehindBeat.Apply(Styled, 0.8);

  Result := Styled;
end;

function TRoederPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('roeder_atmospheric_fill', 'Roeder atmospheric fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TRoederPlugin.GetDrummerName: String;
begin
  Result := 'roeder';
end;

function TRoederPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('metal');
  Result.Add('doom');
  Result.Add('sludge');
end;

end.
