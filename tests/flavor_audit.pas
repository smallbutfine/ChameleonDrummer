program flavor_audit;

{$mode objfpc}{$H+}

{ Lists the flavors every genre plugin offers per section, with their
  intensity tags, and counts how many of them are really different. }

uses
  SysUtils, Classes, Generics.Collections, Math, jsonparser,
  Kit, Pattern, generation_parameters, GenrePlugin,
  rock, metal, jazz, funk, electronic;

{ Order-independent text form of a pattern's content. }
function Content(P: TPattern; WithVelocity: Boolean): String;
var
  B: TBeat;
  Items: TStringList;
  S: String;
begin
  Items := TStringList.Create;
  try
    Items.Sorted := True;
    Items.Duplicates := dupAccept;
    for B in P.Beats do
    begin
      S := Format('%.3f/%s', [B.Position, B.Instrument.Name]);
      if WithVelocity then
        S := S + '/' + IntToStr(B.Velocity);
      Items.Add(S);
    end;
    Items.Delimiter := ';';
    Items.StrictDelimiter := True;
    Result := Items.DelimitedText;
  finally
    Items.Free;
  end;
end;

function Short(const S: String): String;
var
  H: Cardinal;
  I: Integer;
begin
  H := 2166136261;
  for I := 1 to Length(S) do
    H := (H xor Ord(S[I])) * 16777619;
  Result := IntToHex(H, 8);
end;

procedure Audit(const AGenre: String; APlugin: TGenrePlugin; const AStyles: array of String);
const
  Sections: array[0..2] of String = ('verse', 'chorus', 'bridge');
var
  Style, Section: String;
  Params: TGenerationParameters;
  L: specialize TList<TPattern>;
  I: Integer;
  PMin, PMax: Double;
  Rhythm, WithVel: TStringList;
begin
  for Style in AStyles do
    for Section in Sections do
    begin
      Params := TGenerationParameters.Create(AGenre, Style, '', 0.5, 0.6, 0.0);
      L := APlugin.GetSectionFlavors(Section, Params);
      Rhythm := TStringList.Create;
      WithVel := TStringList.Create;
      Rhythm.Sorted := True; Rhythm.Duplicates := dupIgnore;
      WithVel.Sorted := True; WithVel.Duplicates := dupIgnore;
      Write(Format('%-10s %-12s %-7s n=%d ', [AGenre, Style, Section, L.Count]));
      for I := 0 to L.Count - 1 do
      begin
        Rhythm.Add(Content(L[I], False));
        WithVel.Add(Content(L[I], True));
        TryGetIntensityRange(L[I], PMin, PMax);
        Write(Format('[%s beats=%d %.2f-%.2f] ',
          [Short(Content(L[I], False)), L[I].Beats.Count, PMin, PMax]));
      end;
      WriteLn;
      WriteLn(Format('    distinct by rhythm=%d, by rhythm+velocity=%d',
        [Rhythm.Count, WithVel.Count]));
      for I := 0 to L.Count - 1 do
        L[I].Free;
      L.Free; Rhythm.Free; WithVel.Free; Params.Free;
    end;
end;

begin
  Randomize;
  Audit('rock', TRockGenrePlugin.Create, ['classic', 'blues', 'hard', 'punk']);
  Audit('metal', TMetalGenrePlugin.Create, ['heavy', 'thrash', 'doom']);
  Audit('jazz', TJazzGenrePlugin.Create, ['swing', 'bebop']);
  Audit('funk', TFunkGenrePlugin.Create, ['classic']);
  Audit('electronic', TElectronicGenrePlugin.Create, ['house']);
end.
