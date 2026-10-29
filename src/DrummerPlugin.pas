unit DrummerPlugin;

{$mode objfpc}{$H+}

{ DrummerPlugin interface — base class for drummer style modifiers.
  Each concrete drummer (Bonham, Porcaro, Weckl, etc.) extends this class
  to apply their characteristic techniques: behind-the-beat timing, ghost notes,
  linear coordination, shuffles, triplets, etc. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, pattern, song, Kit;

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
  function ApplyStyleAtTempo(const APattern: TPattern; ATempo: Integer): TPattern; virtual;
  function ApplyStyleForContext(const APattern: TPattern; const AGenre,
    AStyle: string; ATempo: Integer): TPattern; virtual;

  { Signature fills — characteristic fills of this drummer, as built into the
    drummer's unit. }
  function GetSignatureFills: specialize TList<TFill>; virtual;

  { The fills the composer uses: config/fills/<AKey>.tab when that file exists
    and is valid, else GetSignatureFills. AKey is the name the drummer is
    registered under (--drummer). For a meter other than 4/4 only the fills the
    file has for that meter are used (the built-in fills are 4/4); without any
    the list is empty and ConfigWarnings says which block to add. The caller
    owns the list and the fills. }
  function GetFillVocabulary(const AKey: string;
    AMeterNum: Integer = 4; AMeterDen: Integer = 4): specialize TList<TFill>;

  { Helper methods. }
  function IsPreferredForGenre(const Genre: string): boolean; virtual;

protected
  { Virtual helpers for subclasses. }
  procedure ApplyTechnique(APattern: TPattern; const TechniqueName: string; Intensity: Double); virtual;

  { Builds a one-bar fill from drum-tab lines (see TDrumTab in
    patterns_templates) for GetSignatureFills. AEnergy is the bar intensity
    (0..1) the fill suits best: a short fill ~0.3, a big one ~0.9. }
  function MakeTabFill(const AName: string; AEnergy: Double;
    const ALines: array of string): TFill;
end;

function CreateSignatureFillPattern(const AFillName: string): TPattern;

implementation

uses
  patterns_templates, FillLibrary, ConfigFiles;

{ DrummerPlugin base class }

function TDrummerPlugin.MakeTabFill(const AName: string; AEnergy: Double;
  const ALines: array of string): TFill;
begin
  { Complexity 1.0 so no line is gated away; a fill is exactly one bar. }
  Result := TFill.Create(BuildDrumTabPattern(AName, ALines, 1.0, 1, []));
  Result.Energy := AEnergy;
end;

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
  Result := '';
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

function TDrummerPlugin.ApplyStyleAtTempo(const APattern: TPattern;
  ATempo: Integer): TPattern;
begin
  Result := ApplyStyle(APattern);
end;

function TDrummerPlugin.ApplyStyleForContext(const APattern: TPattern;
  const AGenre, AStyle: string; ATempo: Integer): TPattern;
begin
  Result := ApplyStyleAtTempo(APattern, ATempo);
end;

function TDrummerPlugin.GetSignatureFills: specialize TList<TFill>;
begin
  Result := specialize TList<TFill>.Create;
end;

function TDrummerPlugin.GetFillVocabulary(const AKey: string;
  AMeterNum, AMeterDen: Integer): specialize TList<TFill>;
begin
  if (AMeterNum <> 4) or (AMeterDen <> 4) then
  begin
    Result := FileFills(AKey, AMeterNum, AMeterDen);
    if Result = nil then
      Result := specialize TList<TFill>.Create;
    if Result.Count = 0 then
      AddConfigWarning(Format(
        'no %d/%d fill for %s: the engine plays a simple tom fill. Add a block like [%s_fill energy=0.5 %d/%d] to config\fills\%s.tab',
        [AMeterNum, AMeterDen, AKey, AKey, AMeterNum, AMeterDen, AKey]));
    Exit;
  end;
  Result := FileFills(AKey);
  if Result = nil then
    Result := GetSignatureFills;
end;

function CreateSignatureFillPattern(const AFillName: string): TPattern;
var
  I: Integer;
  TomNumber: Integer;
begin
  Result := TPattern.Create('signature_' + AFillName);
  if Pos('blast', LowerCase(AFillName)) > 0 then
  begin
    for I := 0 to 15 do
      if (I mod 2) = 0 then
        Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('snare_rimshot_open_hit'), 105)
      else
        Result.AddBeat(I * 0.25, TInstrumentRegistry.Get('kick'), 100);
    Exit;
  end;

  for I := 0 to 7 do
  begin
    TomNumber := 4 - (I div 2);
    Result.AddBeat(I * 0.5,
      TInstrumentRegistry.Get('tom_' + IntToStr(TomNumber) + '_open_hit'),
      88 + I * 4);
  end;
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
