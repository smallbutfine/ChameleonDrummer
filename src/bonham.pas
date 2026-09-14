unit Bonham;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Pattern, Song,
  DrummerPlugin, patterns_templates;

type
  TBonhamPlugin = class(TDrummerPlugin)
  public
    constructor Create; override;
    destructor Destroy; override;

    function ApplyStyle(const APattern: TPattern): TPattern; override;
    function GetSignatureFills: specialize TList<TFill>; override;
    function GetDrummerName: String; override;
    function GetPreferredGenres: TStringArray; override;
  end;

implementation

constructor TBonhamPlugin.Create;
begin
  inherited Create;
end;

destructor TBonhamPlugin.Destroy;
begin
  inherited Destroy;
end;

function TBonhamPlugin.ApplyStyle(const APattern: TPattern): TPattern;
var
  Composer: TTemplateComposer;
begin
  Composer := TTemplateComposer.Create(APattern.Name + '_bonham');
  Composer.Add(TBasicGroove.Create);
  Result := Composer.Build(2, 0.7);
end;

function TBonhamPlugin.GetSignatureFills: specialize TList<TFill>;
var
  FillList: specialize TList<TFill>;
  LFill1, LFill2: TFill;
begin
  FillList := specialize TList<TFill>.Create;

  LFill1 := TFill.Create('bonham_moby_dick_fill', 'Moby Dick solo fill');
  LFill1.Pattern := TPattern.Create('tom_fill');
  FillList.Add(LFill1);

  LFill2 := TFill.Create('bonham_triplet_fill', 'Bonham triplet fill');
  LFill2.Pattern := TPattern.Create('blast_beat');
  FillList.Add(LFill2);

  Result := FillList;
end;

function TBonhamPlugin.GetDrummerName: String;
begin
  Result := 'bonham';
end;

function TBonhamPlugin.GetPreferredGenres: TStringArray;
begin
  SetLength(Result, 3);
  Result[0] := 'rock';
  Result[1] := 'metal';
  Result[2] := 'blues';
end;

end.
