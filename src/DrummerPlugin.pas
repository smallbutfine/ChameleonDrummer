unit DrummerPlugin;

{$mode objfpc}{$H+}

{ DrummerPlugin interface â€” abstract base class for drummer style modifiers.
  Each concrete drummer (Bonham, Porcaro, Weckl, etc.) extends this class
  to apply their characteristic techniques: behind-the-beat timing, ghost notes,
  linear coordination, shuffles, triplets, etc. }

interface

uses
  Classes, SysUtils, Generics.Collections, pattern, song;

type

{ DrummerPlugin â€” abstract base class for drummer style modifiers.
  Concrete implementations must:
  - Override drummer_name and preferred_genres properties
  - Implement apply_style() to transform patterns with characteristic techniques
  - Implement get_signature_fills() to return authentic fills }

TDrummerPlugin = abstract class(TObject)
private
  FStyleParameters: specialize TDictionary<string, float>;

protected
  procedure SetStyleParameters(const Params: specialize TDictionary<string, float>); virtual;

public
  constructor Create; virtual;
  destructor Destroy; override;

  { â”€â”€ Abstract properties (must be overridden). */ }
  property DrummerName: string read GetDrummerName write SetDrummerName abstract;
  property PreferredGenres: TArray<string> read GetPreferredGenres write SetPreferredGenres abstract;

  { â”€â”€ Style parameters â€” per-drummer parameter adjustments. */ }
  property StyleParameters: specialize TDictionary<string, float> read FStyleParameters write SetStyleParameters;
  function GetStyleParameters: specialize TDictionary<string, float>; virtual;

  { â”€â”€ Core abstract method. */ }
  function ApplyStyle(const APattern: TPattern): TPattern; abstract;

  { â”€â”€ Signature fills â€” characteristic fills of this drummer. */ }
  function GetSignatureFills: TObjecspecialize TList<TFill>; abstract;

  { â”€â”€ Helper methods. */ }
  function IsPreferredForGenre(const Genre: string): boolean;

protected
  { Virtual helpers for subclasses. */ }
  procedure ApplyTechnique(AAPattern: TPattern; const TechniqueName: string; Intensity: float); virtual;
end;

implementation

{ â”€â”€ DrummerPlugin base class â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ }

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
  { Virtual method â€” abstract, must be overridden. */
  raise Exception.Create('GetDrummerName not implemented.');
end;

procedure TDrummerPlugin.SetDrummerName(const Value: string);
begin
  { Stub. */
end;

function TDrummerPlugin.GetPreferredGenres: TArray<string>;
begin
  Result := nil; { Abstract â€” must be overridden. */
end;

procedure TDrummerPlugin.SetPreferredGenres(const Value: TArray<string>);
begin
  { Stub. */
end;

function TDrummerPlugin.GetStyleParameters: specialize TDictionary<string, float>;
begin
  Result := FStyleParameters;
end;

procedure TDrummerPlugin.SetStyleParameters(const Params: specialize TDictionary<string, float>);
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
  { Virtual â€” subclasses override to implement specific technique application. */
end;

end.
