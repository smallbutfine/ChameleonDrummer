unit Copeland;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TCopelandPlugin = class(TDrummerPlugin)
  private
    FBehindBeat: TBehindBeatTiming;
    FGhostNotes: TGhostNoteLayer;
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(APattern: TPattern): TPattern; override;
    function GetSignatureFills: TList<TFill>;
    function GetDrummerName: String; override;
    function GetCompatibleGenres: TStringList; override;
  end;

implementation

constructor TCopelandPlugin.Create;
begin
  inherited Create;
  FBehindBeat := TBehindBeatTiming.Create(20.0);
  FGhostNotes := TGhostNoteLayer.Create(0.4);
end;

destructor TCopelandPlugin.Destroy;
begin
  FBehindBeat.Free;
  FGhostNotes.Free;
  inherited Destroy;
end;

function TCopelandPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_copeland';

  // Slight behind-beat feel (reggae/ska influence)
  Styled := FBehindBeat.Apply(Styled, 0.6);

  // Ghost notes for off-beat emphasis
  Styled := FGhostNotes.Apply(Styled, 0.4);

  Result := Styled;
end;

function TCopelandPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('copeland_reggae_fill', 'Copeland reggae/ska fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TCopelandPlugin.GetDrummerName: String;
begin
  Result := 'copeland';
end;

function TCopelandPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('rock');
  Result.Add('funk');
  Result.Add('alternative');
end;

end.
