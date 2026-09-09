unit Bonham;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  core_models_pattern, core_models_song,
  modifications_drummer_mods,
  plugins_interfaces_drummer_plugin;

type
  TBonhamPlugin = class(TDrummerPlugin)
  private
    FBehindBeat: TBehindBeatTiming;
    FTripletVocab: TTripeltVocabulary;
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

constructor TBonhamPlugin.Create;
begin
  inherited Create;
  FBehindBeat := TBehindBeatTiming.Create(25.0);
  FTripletVocab := TTripeltVocabulary.Create(0.4);
  FHeavyAccents := THeavyAccents.Create(15);
end;

destructor TBonhamPlugin.Destroy;
begin
  FBehindBeat.Free;
  FTripletVocab.Free;
  FHeavyAccents.Free;
  inherited Destroy;
end;

function TBonhamPlugin.ApplyStyle(APattern: TPattern): TPattern;
var
  Styled: TPattern;
begin
  Styled := APattern.Copy;
  Styled.Name := APattern.Name + '_bonham';

  // Apply behind-beat timing (Bonham signature)
  Styled := FBehindBeat.Apply(Styled, 0.7);

  // Add triplet vocabulary
  Styled := FTripletVocab.Apply(Styled, 0.8);

  // Heavy accents for rock/metal power
  Styled := FHeavyAccents.Apply(Styled, 0.9);

  Result := Styled;
end;

function TBonhamPlugin.GetSignatureFills: TList<TFill>;
var
  FillList: TList<TFill>;
begin
  FillList := TList<TFill>.Create;

  with TFill.Create('bonham_moby_dick_fill', 'Moby Dick solo fill') do
  begin
    Pattern := TTombFill.Create('descending');
    FillList.Add(Self);
  end;

  with TFill.Create('bonham_triplet_fill', 'Bonham triplet fill') do
  begin
    Pattern := TBlastBeat.Create('traditional', 0.8);
    FillList.Add(Self);
  end;

  Result := FillList;
end;

function TBonhamPlugin.GetDrummerName: String;
begin
  Result := 'bonham';
end;

function TBonhamPlugin.GetCompatibleGenres: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('rock');
  Result.Add('metal');
  Result.Add('blues');
end;

end.
