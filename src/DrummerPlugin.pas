unit DrummerPlugin;

{$mode objfpc}{$H+}

{ DrummerPlugin interface — base class for drummer style modifiers.
  Each concrete drummer (Bonham, Porcaro, Weckl, etc.) extends this class
  to apply their characteristic techniques: behind-the-beat timing, ghost notes,
  linear coordination, shuffles, triplets, etc. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, pattern, song;

type

  TDrummerTechnique = procedure(APattern: TPattern; Intensity: Double) of object;

{ DrummerPlugin — base class for drummer style modifiers.
  Concrete implementations must:
  - Override get_drummer_name and get_preferred_genres methods
  - Implement apply_style to transform patterns with characteristic techniques
  - Implement get_signature_fills to return authentic fills }

TDrummerPlugin = class(TObject)
private
  FStyleParameters: specialize TDictionary<string, Double>;
protected
  procedure SetStyleParameters(const Params: specialize TDictionary<string, Double>); virtual;

public
  constructor Create; virtual;
  destructor Destroy; override;

  { Methods (must be overridden). }
  function GetDrummerName: string; virtual;
  function GetPreferredGenres: TStringArray; virtual;

  { Style parameters — per-drummer parameter adjustments. }
  property StyleParameters: specialize TDictionary<string, Double> read FStyleParameters write SetStyleParameters;
  function GetStyleParameters: specialize TDictionary<string, Double>; virtual;

  { Core method (override in subclass). }
  function ApplyStyle(const APattern: TPattern): TPattern; virtual;

  { Signature fills — characteristic fills of this drummer. }
  function GetSignatureFills: specialize TList<TFill>; virtual;

  { Helper methods. }
  function IsPreferredForGenre(const Genre: string): boolean; virtual;

protected
  { Virtual helpers for subclasses. }
  procedure ApplyTechnique(APattern: TPattern; const TechniqueName: string; Intensity: Double); virtual;
end;

implementation

{ DrummerPlugin base class }

constructor TDrummerPlugin.Create;
begin
  inherited Create;
  FStyleParameters := specialize TDictionary<string, Double>.Create;
  { Default: neutral parameters. }
  FStyleParameters.Add('behind_beat', 0.0);
  FStyleParameters.Add('ghost_notes', 0.0);
  FStyleParameters.Add('triplet_feel', 0.0);
  FStyleParameters.Add('shuffle', 0.0);
end;

destructor TDrummerPlugin.Destroy;
begin
  FStyleParameters.Free;
  inherited Destroy;
end;

function TDrummerPlugin.GetDrummerName: string;
begin
  raise Exception.Create('GetDrummerName not implemented.');
end;

function TDrummerPlugin.GetPreferredGenres: TStringArray;
begin
  Result := nil;
end;

procedure TDrummerPlugin.SetStyleParameters(const Params: specialize TDictionary<string, Double>);
begin
  FStyleParameters := Params;
end;

function TDrummerPlugin.GetStyleParameters: specialize TDictionary<string, Double>;
begin
  Result := FStyleParameters;
end;

function TDrummerPlugin.ApplyStyle(const APattern: TPattern): TPattern;
begin
  Result := APattern.Copy; { Default: no modification }
end;

function TDrummerPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  Result := specialize TList<TFill>.Create;
end;

function TDrummerPlugin.IsPreferredForGenre(const Genre: string): boolean;
var
  Genres: TStringArray;
  I: Integer;
begin
  Genres := GetPreferredGenres;
  Result := False;
  for I := Low(Genres) to High(Genres) do
    if SameText(Genres[I], Genre) then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TDrummerPlugin.ApplyTechnique(APattern: TPattern; const TechniqueName: string; Intensity: Double);
begin
  { Default: no-op. Subclasses override to apply specific techniques. }
  case LowerCase(TechniqueName) of
    'behind_beat':
      begin
        { Apply behind-the-beat timing shift }
      end;
    'ghost_notes':
      begin
        { Add ghost notes }
      end;
    'triplet_feel':
      begin
        { Apply triplet vocabulary }
      end;
    'shuffle':
      begin
        { Apply shuffle feel }
      end;
  end;
end;

end.
