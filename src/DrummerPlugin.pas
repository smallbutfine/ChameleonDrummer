unit DrummerPlugin;

{$mode objfpc}{$H+}

{ DrummerPlugin interface — abstract base class for drummer style modifiers.
  Each concrete drummer (Bonham, Porcaro, Weckl, etc.) extends this class
  to apply their characteristic techniques: behind-the-beat timing, ghost notes,
  linear coordination, shuffles, triplets, etc. }

interface

uses
  Classes, SysUtils, Generics.Collections, pattern, song;

type

{ DrummerPlugin — abstract base class for drummer style modifiers.
  Concrete implementations must:
  - Override drummer_name and preferred_genres properties
  - Implement apply_style() to transform patterns with characteristic techniques
  - Implement get_signature_fills() to return authentic fills }

TDrummerPlugin = abstract class(TObject)
private
  FStyleParameters: TDictionary<string, float>;

protected
  procedure SetStyleParameters(const Params: TDictionary<string, float>); virtual;

public
  constructor Create; virtual;
  destructor Destroy; override;

  { ── Abstract properties (must be overridden). */ }
  property DrummerName: string read GetDrummerName write SetDrummerName abstract;
  property PreferredGenres: TArray<string> read GetPreferredGenres write SetPreferredGenres abstract;

  { ── Style parameters — per-drummer parameter adjustments. */ }
  property StyleParameters: TDictionary<string, float> read FStyleParameters write SetStyleParameters;
  function GetStyleParameters: TDictionary<string, float>; virtual;

  { ── Core abstract method. */ }
  function ApplyStyle(const APattern: TPattern): TPattern; abstract;

  { ── Signature fills — characteristic fills of this drummer. */ }
  function GetSignatureFills: TObjectList<TFill>; abstract;

  { ── Helper methods. */ }
  function IsPreferredForGenre(const Genre: string): boolean;

protected
  { Virtual helpers for subclasses. */ }
  procedure ApplyTechnique(AAPattern: TPattern; const TechniqueName: string; Intensity: float); virtual;
end;

implementation

{ ── DrummerPlugin base class ────────────────────────────────────────────── }

constructor TDrummerPlugin.Create;
begin
  inherited Create;
  FStyleParameters := TDictionary<string, float>.Create;
end;

destructor TDrummerPlugin.Destroy;
begin
  FStyleParameters.Free;
  inherited Destroy;
end;

function TDrummerPlugin.GetDrummerName: string;
begin
  { Virtual method — abstract, must be overridden. */
  raise Exception.Create('GetDrummerName not implemented.');
end;

procedure TDrummerPlugin.SetDrummerName(const Value: string);
begin
  { Stub. */
end;

function TDrummerPlugin.GetPreferredGenres: TArray<string>;
begin
  Result := nil; { Abstract — must be overridden. */
end;

procedure TDrummerPlugin.SetPreferredGenres(const Value: TArray<string>);
begin
  { Stub. */
end;

function TDrummerPlugin.GetStyleParameters: TDictionary<string, float>;
begin
  Result := FStyleParameters;
end;

procedure TDrummerPlugin.SetStyleParameters(const Params: TDictionary<string, float>);
begin
  FStyleParameters := Params;
end;

function TDrummerPlugin.IsPreferredForGenre(const Genre: string): boolean;
{ Check if this genre is in the drummer's preferred list. */
begin
  for var GenreItem in PreferredGenres do
    if SameText(GenreItem, Genre) then
      Exit(true);
  Result := false;
end;

procedure TDrummerPlugin.ApplyTechnique(AAPattern: TPattern; const TechniqueName: string; Intensity: float);
{ Helper to apply a named technique at given intensity.
  Subclasses call this for common techniques (behind_beat, ghost_notes, etc.). */
begin
  { Virtual — subclasses override to implement specific technique application. */
end;

end.
