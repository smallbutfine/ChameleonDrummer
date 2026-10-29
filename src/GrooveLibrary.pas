unit GrooveLibrary;

{$mode objfpc}{$H+}

{ Grooves from config/grooves/<genre>.tab, one file per genre.

      [heavy verse]                          style, then the section kind
      K  x... ..x. x... ..x. | x... ....     drum-tab lines (see TDrumTab)
      S  .... x... .... x... | .... x...

      [heavy verse intensity=0.4-0.8]        optional: when this groove suits
      [heavy verse 7/8]                      a groove for 7/8; without a meter it is 4/4

  A block is one groove. The blocks of one style and kind are its variants,
  lightest first; the composer picks among those whose intensity band fits the
  bar. Without intensity= the first three variants get the standard bands
  (GrooveBand) and any further one the heaviest band, so say intensity= for
  grooves you add.
  Kinds: verse, chorus, bridge (intro/outro/solo/... play verse or bridge
  grooves, see GrooveKindOfSection).

  Meters: any meter can have its own grooves (2/4, 3/4, 5/4, 7/8, 9/8, 11/8,
  13/8 ...). A song in 7/8 plays the 7/8 grooves of its style; when the style
  has none, the 7/8 grooves of any style of that genre; when the genre has
  none, a plain groove the engine builds (kick, snare on the group starts,
  hi-hat) and a warning that names the file to add one to.

  A file replaces the built-in grooves of the genre for the styles it has; a
  style it does not mention keeps the built-in grooves. A style the engine
  has never heard of simply becomes a new style of that genre (it is listed
  and can be chosen like any other). A genre itself needs its plugin; a file
  for a genre the engine does not have is not used.

  A file with a mistake is ignored as a whole and the mistake is reported
  (ConfigWarnings); the built-in grooves are used instead. }

interface

uses
  Classes, SysUtils, Math, Types, Generics.Collections, Pattern, patterns_templates,
  ConfigFiles, TabFiles;

type
  TGrooveVariant = record
    Lines: TTabLines;
    HasBand: Boolean;
    BandMin, BandMax: Double;
  end;

  TGrooveVariants = array of TGrooveVariant;

{ Names of all genres that have a groove file. }
procedure GrooveFileGenres(ANames: TStrings);

{ Styles the genre's file defines (in file order); empty without a file. }
procedure GrooveFileStyles(const AGenre: string; AStyles: TStrings);

{ The variants of a style and kind from the file; empty when the file does not
  have them. }
function FileGrooveVariants(const AGenre, AStyle, AKind: string;
  AMeterNum: Integer = 4; AMeterDen: Integer = 4): TGrooveVariants;

{ How many variants a style has for a kind and meter: from the file when it
  has them, else ABuiltIn for 4/4 and 1 (the plain groove) for any other
  meter. A kind the file lacks counts as 'verse'. }
function GrooveVariantCount(const AGenre, AStyle, AKind: string;
  ABuiltIn: Integer = 3; AMeterNum: Integer = 4; AMeterDen: Integer = 4): Integer;

{ Builds variant AVariant (counted modulo the variant count) as a tagged
  groove. ABuiltIn are the lines of the compiled-in 4/4 groove, used when the
  file has none for this style. For another meter without a groove in any file
  the plain meter groove is built and ConfigWarnings says which block to add. }
function BuildGroove(const AGenre, AStyle, AKind: string; AVariant: Integer;
  AComplexity: Double; const ABuiltIn: TTabLines;
  AMeterNum: Integer = 4; AMeterDen: Integer = 4): TPattern;

{ The styles of a genre: the built-in ones, then those only the file has. }
function WithFileStyles(const AGenre: string;
  const ABuiltIn: array of string): TStringDynArray;

{ Reads the files again now (after they were edited, or to find mistakes in
  them early: they end up in ConfigWarnings). }
procedure ReloadGrooveLibrary;

{ Parses one groove file's blocks; raises with file and line on a mistake.
  Exposed for tests and for tools that check a file. }
procedure CheckGrooveBlocks(const ABlocks: TTabBlocks; const AFileName: string);

implementation

type
  TStyleKinds = specialize TDictionary<string, TGrooveVariants>;

  TGenreGrooves = class
    Styles: TStringList;       { styles in file order }
    Kinds: TStyleKinds;        { 'style|kind' -> variants }
    constructor Create;
    destructor Destroy; override;
  end;

var
  GGenres: specialize TDictionary<string, TGenreGrooves> = nil;
  GFileGenres: TStringList = nil;
  GLoaded: Boolean = False;

constructor TGenreGrooves.Create;
begin
  inherited Create;
  Styles := TStringList.Create;
  Kinds := TStyleKinds.Create;
end;

destructor TGenreGrooves.Destroy;
begin
  Kinds.Free;
  Styles.Free;
  inherited Destroy;
end;

function IsName(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in ['a'..'z', '0'..'9', '_']) then
      Exit(False);
end;

{ "0.4-0.8" -> 0.4, 0.8 }
function ParseBand(const AText: string; out AMin, AMax: Double): Boolean;
var
  FS: TFormatSettings;
  P: Integer;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  P := Pos('-', AText);
  Result := (P > 1) and TryStrToFloat(Copy(AText, 1, P - 1), AMin, FS) and
    TryStrToFloat(Copy(AText, P + 1, MaxInt), AMax, FS) and
    (AMin >= 0) and (AMax <= 1) and (AMin < AMax);
end;

procedure CheckGrooveBlocks(const ABlocks: TTabBlocks; const AFileName: string);
var
  B: TTabBlock;
  Value: string;
  Lo, Hi: Double;
  Pattern: TPattern;
begin
  for B in ABlocks do
  begin
    if Length(B.Words) <> 2 then
      raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
        'the header needs a style and a kind, like [heavy verse]'));
    if not IsName(B.Words[0]) then
      raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
        Format('"%s" is not a style name (lower case letters, digits and _)', [B.Words[0]])));
    if (B.Words[1] <> 'verse') and (B.Words[1] <> 'chorus') and (B.Words[1] <> 'bridge') then
      raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
        Format('the kind must be verse, chorus or bridge, not "%s"', [B.Words[1]])));
    if (Length(B.KeyNames) > 1) or
       ((Length(B.KeyNames) = 1) and (B.KeyNames[0] <> 'intensity')) then
      raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
        'only intensity=0.2-0.6 is allowed after the style and kind'));
    if BlockKey(B, 'intensity', Value) and not ParseBand(Value, Lo, Hi) then
      raise Exception.Create(TabMessage(AFileName, B.HeaderLine,
        Format('intensity must look like 0.2-0.6 (between 0 and 1, low first), not "%s"', [Value])));
    { Meter from header (if any) is passed to BuildDrumTabPattern }
    try
      Pattern := BuildDrumTabPattern('check', B.Lines, 1.0, 2, B.Meters);
      Pattern.Free;
    except
      on E: Exception do
        AddConfigWarning(TabMessage(AFileName, B.HeaderLine,
          Format('[%s %s]: %s - this groove is skipped', [B.Words[0], B.Words[1], E.Message])));
    end;
  end;
end;

{ 'num/den', a header without a meter is 4/4. }
function MeterKey(ANum, ADen: Integer): string;
begin
  if ANum = 0 then
    Result := '4/4'
  else
    Result := IntToStr(ANum) + '/' + IntToStr(ADen);
end;

procedure AddBlocks(AGenre: TGenreGrooves; const ABlocks: TTabBlocks);
var
  B: TTabBlock;
  V: TGrooveVariant;
  List: TGrooveVariants;
  Key, Value: string;
  I: Integer;
begin
  for B in ABlocks do
  begin
    if AGenre.Styles.IndexOf(B.Words[0]) < 0 then
      AGenre.Styles.Add(B.Words[0]);
    V := Default(TGrooveVariant);
    SetLength(V.Lines, Length(B.Lines));
    for I := 0 to High(B.Lines) do
      V.Lines[I] := B.Lines[I];
    V.HasBand := BlockKey(B, 'intensity', Value);
    if V.HasBand then
      ParseBand(Value, V.BandMin, V.BandMax);
    if Length(B.Meters) = 0 then
      Key := B.Words[0] + '|' + B.Words[1]
    else
    begin
      Key := B.Words[0] + '|' + B.Words[1];
      for I := 0 to High(B.Meters) do
        Key := Key + '|' + IntToStr(B.Meters[I].Num) + '/' + IntToStr(B.Meters[I].Den);
    end;
    if not AGenre.Kinds.TryGetValue(Key, List) then
      List := nil;
    SetLength(List, Length(List) + 1);
    List[High(List)] := V;
    if AGenre.Kinds.ContainsKey(Key) then
      AGenre.Kinds.Remove(Key);
    AGenre.Kinds.Add(Key, List);
  end;
end;

procedure Clear;
var
  G: TGenreGrooves;
begin
  if GGenres <> nil then
  begin
    for G in GGenres.Values do
      G.Free;
    GGenres.Free;
    GGenres := nil;
  end;
  GFileGenres.Free;
  GFileGenres := nil;
  GLoaded := False;
end;

procedure EnsureLoaded;
var
  Names: TStringList;
  Name, Path: string;
  Blocks: TTabBlocks;
  Genre: TGenreGrooves;
begin
  if GLoaded then
    Exit;
  GLoaded := True;
  GGenres := specialize TDictionary<string, TGenreGrooves>.Create;
  GFileGenres := TStringList.Create;
  Names := TStringList.Create;
  try
    ListConfigNames('grooves', '.tab', Names);
    for Name in Names do
    begin
      Path := FindConfigFile('grooves', Name + '.tab');
      if Path = '' then
        Continue;
      try
        Blocks := ParseTabFile(Path);
        CheckGrooveBlocks(Blocks, Path);
      except
        on E: Exception do
        begin
          AddConfigWarning(E.Message + ' - the file is ignored');
          Continue;
        end;
      end;
      Genre := TGenreGrooves.Create;
      AddBlocks(Genre, Blocks);
      GGenres.Add(Name, Genre);
      GFileGenres.Add(Name);
    end;
  finally
    Names.Free;
  end;
end;

procedure ReloadGrooveLibrary;
begin
  Clear;
  EnsureLoaded;
end;

function WithFileStyles(const AGenre: string;
  const ABuiltIn: array of string): TStringDynArray;
var
  Styles, FromFile: TStringList;
  I: Integer;
begin
  Styles := TStringList.Create;
  FromFile := TStringList.Create;
  try
    for I := 0 to High(ABuiltIn) do
      Styles.Add(ABuiltIn[I]);
    GrooveFileStyles(AGenre, FromFile);
    for I := 0 to FromFile.Count - 1 do
      if Styles.IndexOf(FromFile[I]) < 0 then
        Styles.Add(FromFile[I]);
    SetLength(Result, Styles.Count);
    for I := 0 to Styles.Count - 1 do
      Result[I] := Styles[I];
  finally
    FromFile.Free;
    Styles.Free;
  end;
end;

procedure GrooveFileGenres(ANames: TStrings);
begin
  EnsureLoaded;
  ANames.Clear;
  ANames.AddStrings(GFileGenres);
end;

procedure GrooveFileStyles(const AGenre: string; AStyles: TStrings);
var
  G: TGenreGrooves;
begin
  EnsureLoaded;
  AStyles.Clear;
  if GGenres.TryGetValue(LowerCase(AGenre), G) then
    AStyles.AddStrings(G.Styles);
end;

function FileGrooveVariants(const AGenre, AStyle, AKind: string;
  AMeterNum, AMeterDen: Integer): TGrooveVariants;
var
  G: TGenreGrooves;
  MeterKeyStr, Style: string;
  I: Integer;

  { The grooves of one style for the kind, else its verse grooves. }
  function OfStyle(const AStyleName: string; out AVariants: TGrooveVariants): Boolean;
  var
    KeyNoMeter, KeyWithMeter: string;
  begin
    KeyNoMeter := AStyleName + '|' + AKind;
    KeyWithMeter := KeyNoMeter;
    if AMeterNum <> 0 then
      KeyWithMeter := KeyWithMeter + '|' + IntToStr(AMeterNum) + '/' + IntToStr(AMeterDen);
    Result := G.Kinds.TryGetValue(KeyWithMeter, AVariants) or
      G.Kinds.TryGetValue(KeyNoMeter, AVariants) or
      G.Kinds.TryGetValue(AStyleName + '|verse|' + KeyWithMeter, AVariants) or
      G.Kinds.TryGetValue(AStyleName + '|verse', AVariants);
  end;

begin
  EnsureLoaded;
  Result := nil;
  if not GGenres.TryGetValue(LowerCase(AGenre), G) then
    Exit;
  Style := LowerCase(AStyle);
  if G.Styles.IndexOf(Style) >= 0 then
    if OfStyle(Style, Result) then
      Exit;
  { For a meter other than 4/4 the genre may have grooves for it in another
    style: that is closer than a plain groove. 4/4 keeps the built-ins. }
  if AMeterNum <> 0 then
    for I := 0 to G.Styles.Count - 1 do
      if OfStyle(G.Styles[I], Result) then
        Exit;
  Result := nil;
end;

function GrooveVariantCount(const AGenre, AStyle, AKind: string;
  ABuiltIn: Integer; AMeterNum, AMeterDen: Integer): Integer;
var
  V: TGrooveVariants;
begin
  V := FileGrooveVariants(AGenre, AStyle, AKind, AMeterNum, AMeterDen);
  if Length(V) > 0 then
    Result := Length(V)
  else if MeterKey(AMeterNum, AMeterDen) = '4/4' then
    Result := ABuiltIn
  else
    Result := 1;
end;

function BuildGroove(const AGenre, AStyle, AKind: string; AVariant: Integer;
  AComplexity: Double; const ABuiltIn: TTabLines;
  AMeterNum, AMeterDen: Integer): TPattern;
var
  V: TGrooveVariants;
  Item: TGrooveVariant;
  Lo, Hi: Double;
  Kind: string;
  Index: Integer;
  ItemMeters: array of TMeterPair;
begin
  V := FileGrooveVariants(AGenre, AStyle, AKind, AMeterNum, AMeterDen);
  if Length(V) = 0 then
  begin
    if MeterKey(AMeterNum, AMeterDen) = '4/4' then
    begin
      Result := BuildTaggedGroove(
        Format('%s_%s_%s_v%d', [AGenre, AStyle, AKind, AVariant]), AKind, AVariant,
        ABuiltIn, AComplexity);
      Exit;
    end;
    { No groove for this meter in any file: a plain one keeps the song
      going, and the warning says where to add a real one. }
    AddConfigWarning(Format(
      'no %d/%d groove for %s %s (%s): a plain groove is played. Add a block like [%s %s %d/%d] to config\grooves\%s.tab',
      [AMeterNum, AMeterDen, AGenre, AStyle, AKind, AStyle, AKind, AMeterNum, AMeterDen,
       AGenre]));
    Result := BuildMeterFallbackGroove(
      Format('%s_%s_%s_%d_%d_plain', [AGenre, AStyle, AKind, AMeterNum, AMeterDen]),
      AMeterNum, AMeterDen, AComplexity);
    Exit;
  end;
  Index := AVariant mod Length(V);
  if Index < 0 then
    Index := 0;
  Item := V[Index];
  Kind := AKind;
  { Build meters array from single meter }
  SetLength(ItemMeters, 0);
  if AMeterNum <> 0 then
  begin
    SetLength(ItemMeters, 1);
    ItemMeters[0].Num := AMeterNum;
    ItemMeters[0].Den := AMeterDen;
  end;
  try
    Result := BuildDrumTabPattern(
      Format('%s_%s_%s_v%d', [AGenre, AStyle, AKind, Index]), Item.Lines,
      AComplexity, 2, ItemMeters);
  except
    on E: Exception do
    begin
      AddConfigWarning(Format(
        'groove %s %s (%d/%d) variant %d: %s - falling back to built-in',
        [AGenre, AStyle, AMeterNum, AMeterDen, Index, E.Message]));
      if MeterKey(AMeterNum, AMeterDen) = '4/4' then
      begin
        Result := BuildTaggedGroove(
          Format('%s_%s_%s_v%d', [AGenre, AStyle, AKind, AVariant]), AKind, AVariant,
          ABuiltIn, AComplexity);
        Exit;
      end
      else
      begin
        Result := BuildMeterFallbackGroove(
          Format('%s_%s_%s_%d_%d_plain', [AGenre, AStyle, AKind, AMeterNum, AMeterDen]),
          AMeterNum, AMeterDen, AComplexity);
        Exit;
      end;
    end;
  end;
  if Item.HasBand then
    TagIntensityBand(Result, Item.BandMin, Item.BandMax)
  else
  begin
    GrooveBand(Kind, Min(Index, 2), Lo, Hi);
    TagIntensityBand(Result, Lo, Hi);
  end;
end;

finalization
  Clear;
end.
