unit Moon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TMoonPlugin = class(TDrummerPlugin)
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

constructor TMoonPlugin.Create;
begin
  inherited Create;
  FMinimalCreativity := TMinimalCreativity.Create;
  FBehindBeat := TBehindBeatTiming.Create(20.0);
end;

destructor TMoonPlugin.Destroy;
begin
  FMinimalCreativity.Free;
  FBehindBeat.Free;
  inherited Destroy;
end;

function TMoonPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_moon';

  // Minimal creativity (atmospheric approach)
  Styled := FMinimalCreativity.Apply(Styled, 0.7);

  // Behind-beat timing
  Styled := FBehindBeat.Apply(Styled, 0.6);

  Result := Styled;
end;

function TMoonPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
begin
  FillList := specialize TList<TFill>.Create;

  with TFill.Create('moon_atmospheric_fill', 'Moon atmospheric fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TMoonPlugin.GetDrummerName: String;
begin
  Result := 'moon';
end;

function TMoonPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('metal');
  Result.Add('doom');
  Result.Add('sludge');
end;

end.
