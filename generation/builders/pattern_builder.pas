unit pattern_builder;

{$mode objfpc}{$H+}

{ Pattern builder - fluent construction API for Pattern. }

interface

uses
  Classes, SysUtils, Generics.Collections, kit, pattern, time_signature;

type

{ TPatternBuilder — builder pattern for creating drum patterns. }
TPatternBuilder = class(TObject)
private
  FP pattern: TPattern;
public
  constructor Create(const AName: string; ATimeSignature: TTimeSignature = nil); overload;
  destructor Destroy; override;

  { Core instruments (convenience methods) }
  function Kick(APosition: float; AVelocity: Integer = 100): TPatternBuilder;
  function Snare(APosition: float; AVelocity: Integer = 100): TPatternBuilder;
  function HiHat(APosition: float; AVelocity: Integer = 80; AOpen: boolean = false): TPatternBuilder;
  function Ride(APosition: float; AVelocity: Integer = 80): TPatternBuilder;
  function HiHatFoot(APosition: float; AVelocity: Integer = 80): TPatternBuilder;

  { Snare articulations }
  function SnareShallow(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
  function SnareRimshot(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
  function SnareSideStick(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
  function BrushSweep(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;
  function SnareSweep(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;

  { Tom articulations }
  function Tom(APosition: float; const AVariant: string = '2'; AVelocity: Integer = -1): TPatternBuilder;
  function TomEdge(APosition: float; const AVariant: string = '2'; AVelocity: Integer = -1): TPatternBuilder;

  { Cymbal articulations }
  function Crash(APosition: float; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;
  function CrashChoked(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;
  function RideBell(APosition: float; AVelocity: Integer = 80): TPatternBuilder;
  function RideShaft(APosition: float; AVelocity: Integer = 80): TPatternBuilder;
  function CymbalOpen(APosition: float; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;

  { Hi-hat variants }
  function HiHatClosedShaft(APosition: float; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;
  function HiHatClosedBell(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
  function OpenHiHat(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;
  function HiHatPedalOpen(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
  function TightHH(APosition: float; AOpen: boolean = false; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;

  { Generic helper }
  function AddHit(AInstrument: TDrumInstrument; APosition: float; AVelocity: Integer = 100): TPatternBuilder;

  { Build and return the pattern. }
  function Build: TPattern;

  property Pattern: TPattern read FP pattern write FPattern;
end;

implementation

{ ── PatternBuilder ────────────────────────────────────────────────────────── }

constructor TPatternBuilder.Create(const AName: string; ATimeSignature: TTimeSignature);
begin
  inherited Create;
  if Assigned(ATimeSignature) then
    FP pattern := TPattern.Create(AName, ATimeSignature)
  else
    FP pattern := TPattern.Create(AName, TimeSignature.Create(4, 4));
end;

destructor TPatternBuilder.Destroy;
begin
  FPattern.Free;
  inherited Destroy;
end;

function TPatternBuilder.Kick(APosition: float; AVelocity: Integer = 100): TPatternBuilder;
begin
  var Inst := TInstrumentRegistry.Get('kick');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, AVelocity);
  Result := Self;
end;

function TPatternBuilder.Snare(APosition: float; AVelocity: Integer = 100): TPatternBuilder;
{ Weighted random selection across ALL non-brush snare variants. }
var
  Variants: TArray<string>;
  Weights: TArray<Integer>;
  I: Integer;
begin
  SetLength(Variants, 8);
  SetLength(Weights, 8);

  Variants[0] := 'snare_rimshot_open_hit';
  Variants[1] := 'snare_rimshot_dbl_closed_hit';
  Variants[2] := 'snare_open_hit_open_lateral_hit';
  Variants[3] := 'snare_open_hit_dbl_closed_lateral_hit';
  Variants[4] := 'snare_shallow_rimshot_open_shallow_hit';
  Variants[5] := 'snare_sticks';
  Variants[6] := 'snare_side_stick';
  Variants[7] := 'snare_rimclick_sweep_short_1_dbl';

  Weights[0] := 25;  { rimshot }
  Weights[1] := 10;  { dbl/closed rimshot }
  Weights[2] := 10;  { open lateral hit }
  Weights[3] := 5;   { dbl open/closed lateral }
  Weights[4] := 5;   { shallow rimshot }
  Weights[5] := 1;   { sticks (rare) }
  Weights[6] := 4;   { side stick (cross-stick) }
  Weights[7] := 1;   { rimclick/ratchet/click (rare) }

  { Weighted random selection }
  var TotalWeight := 0;
  for I := Low(Weights) to High(Weights) do
    TotalWeight := TotalWeight + Weights[I];

  var RandVal := Random(TotalWeight);
  var Cumulative := 0;
  var SelectedIndex := 0;
  for I := Low(Weights) to High(Weights) do
  begin
    Inc(Cumulative, Weights[I]);
    if RandVal < Cumulative then
    begin
      SelectedIndex := I;
      Break;
    end;
  end;

  var Inst := TInstrumentRegistry.Get(Variants[SelectedIndex]);
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, AVelocity);
  Result := Self;
end;

function TPatternBuilder.HiHat(APosition: float; AVelocity: Integer = 80; AOpen: boolean = false): TPatternBuilder;
begin
  var InstName := 'hihat_closed_1_tip_closed_1_hit';
  if AOpen then
    InstName := 'hihat_open_a';
  var Inst := TInstrumentRegistry.Get(InstName);
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, AVelocity);
  Result := Self;
end;

function TPatternBuilder.Ride(APosition: float; AVelocity: Integer = 80): TPatternBuilder;
begin
  var Inst := TInstrumentRegistry.Get('ride_1_tip_hit_softer');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, AVelocity);
  Result := Self;
end;

function TPatternBuilder.HiHatFoot(APosition: float; AVelocity: Integer = 80): TPatternBuilder;
begin
  var Inst := TInstrumentRegistry.Get('hihat_pedal_closed');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, AVelocity);
  Result := Self;
end;

function TPatternBuilder.SnareShallow(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
begin
  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 70; { SNARE_GHOST }
  var Inst := TInstrumentRegistry.Get('snare_shallow_hit_closed_shallow_hit');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.SnareRimshot(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
begin
  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 110; { SNARE_RIMSHOT }
  var Inst := TInstrumentRegistry.Get('snare_rimshot_open_hit');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.SnareSideStick(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
begin
  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 70; { SNARE_GHOST }
  var Inst := TInstrumentRegistry.Get('snare_side_stick');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.BrushSweep(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;
begin
  { Alias for snare_sweep }
  Result := SnareSweep(APosition, AVariant, AVelocity);
end;

function TPatternBuilder.SnareSweep(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;
{ Variant maps to AD2 brush sweep presets (A-F). }
var
  SweepMap: array[0..5] of record Key: string; Value: string; end;
begin
  SweepMap[0].Key := 'A'; SweepMap[0].Value := 'snare_brushes_only_sweep_fast_bright_accent';
  SweepMap[1].Key := 'B'; SweepMap[1].Value := 'snare_brushes_only_sweep_slow_bright_accent';
  SweepMap[2].Key := 'C'; SweepMap[2].Value := 'snare_brushes_only_sweep_fast_dark_accent';
  SweepMap[3].Key := 'D'; SweepMap[3].Value := 'snare_brushes_only_sweep_slow_dark_accent';
  SweepMap[4].Key := 'E'; SweepMap[4].Value := 'snare_brushes_only_sweep_fast_bright_accent';
  SweepMap[5].Key := 'F'; SweepMap[5].Value := 'snare_brushes_only_sweep_no_accent';

  var InstName := SweepMap[0].Value; { default A }
  for var I := Low(SweepMap) to High(SweepMap) do
    if SameText(SweepMap[I].Key, AVariant) then
    begin
      InstName := SweepMap[I].Value;
      Break;
    end;

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 95; { BRUSH_NORMAL }

  var Inst := TInstrumentRegistry.Get(InstName);
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.Tom(APosition: float; const AVariant: string = '2'; AVelocity: Integer = -1): TPatternBuilder;
{ variant accepts numbers ("1"-"4") or aliases. }
var
  TomMap: array[0..3] of record Key: string; Value: string; end;
  AliasMap: array[0..3] of record Key: string; Value: string; end;
begin
  TomMap[0].Key := '1'; TomMap[0].Value := 'tom_1_open_hit';
  TomMap[1].Key := '2'; TomMap[1].Value := 'tom_2_open_hit';
  TomMap[2].Key := '3'; TomMap[2].Value := 'tom_3_open_hit';
  TomMap[3].Key := '4'; TomMap[3].Value := 'tom_4_open_hit';

  AliasMap[0].Key := 'HIGH'; AliasMap[0].Value := '1';
  AliasMap[1].Key := 'MID'; AliasMap[1].Value := '2';
  AliasMap[2].Key := 'LOW'; AliasMap[2].Value := '3';
  AliasMap[3].Key := 'FLOOR'; AliasMap[3].Value := '4';

  var Numeric := AVariant;
  for var I := Low(AliasMap) to High(AliasMap) do
    if SameText(AliasMap[I].Key, AVariant) then
    begin
      Numeric := AliasMap[I].Value;
      Break;
    end;

  var KeyName := TomMap[1].Value; { default MID }
  for var I := Low(TomMap) to High(TomMap) do
    if SameText(TomMap[I].Key, Numeric) then
    begin
      KeyName := TomMap[I].Value;
      Break;
    end;

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 100; { TOM_NORMAL }

  var Inst := TInstrumentRegistry.Get(KeyName);
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.TomEdge(APosition: float; const AVariant: string = '2'; AVelocity: Integer = -1): TPatternBuilder;
{ Same variant aliases as .tom() (HIGH, MID, LOW, FLOOR or 1-4). }
var
  EdgeMap: array[0..3] of record Key: string; Value: string; end;
  AliasMap: array[0..3] of record Key: string; Value: string; end;
begin
  EdgeMap[0].Key := '1'; EdgeMap[0].Value := 'tom_1_rimshot_open_hit_dbl';
  EdgeMap[1].Key := '2'; EdgeMap[1].Value := 'tom_2_rimshot_open_hit_dbl';
  EdgeMap[2].Key := '3'; EdgeMap[2].Value := 'tom_3_rimshot_open_hit_dbl';
  EdgeMap[3].Key := '4'; EdgeMap[3].Value := 'tom_4_rimshot_open_hit_dbl';

  AliasMap[0].Key := 'HIGH'; AliasMap[0].Value := '1';
  AliasMap[1].Key := 'MID'; AliasMap[1].Value := '2';
  AliasMap[2].Key := 'LOW'; AliasMap[2].Value := '3';
  AliasMap[3].Key := 'FLOOR'; AliasMap[3].Value := '4';

  var Numeric := AVariant;
  for var I := Low(AliasMap) to High(AliasMap) do
    if SameText(AliasMap[I].Key, AVariant) then
    begin
      Numeric := AliasMap[I].Value;
      Break;
    end;

  var KeyName := EdgeMap[1].Value; { default MID }
  for var I := Low(EdgeMap) to High(EdgeMap) do
    if SameText(EdgeMap[I].Key, Numeric) then
    begin
      KeyName := EdgeMap[I].Value;
      Break;
    end;

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 110; { TOM_HEAVY }

  var Inst := TInstrumentRegistry.Get(KeyName);
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.Crash(APosition: float; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;
{ variant accepts numbers ("1"-"6") to select which crash. }
var
  InstName: string;
begin
  InstName := Format('cymbal_%s_hit', [AVariant]);

  var Inst := TInstrumentRegistry.Get(InstName);
  if not Assigned(Inst) then
    Inst := TInstrumentRegistry.Get('cymbal_1_hit'); { fallback }

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 100; { CRASH_ACCENT }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.CrashChoked(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;
{ variant accepts numbers ("1"-"6") or letters (A-F). }
var
  ChokeMap: array[0..5] of record Key: string; Value: string; end;
begin
  ChokeMap[0].Key := 'A'; ChokeMap[0].Value := '1';
  ChokeMap[1].Key := 'B'; ChokeMap[1].Value := '2';
  ChokeMap[2].Key := 'C'; ChokeMap[2].Value := '3';
  ChokeMap[3].Key := 'D'; ChokeMap[3].Value := '4';
  ChokeMap[4].Key := 'E'; ChokeMap[4].Value := '5';
  ChokeMap[5].Key := 'F'; ChokeMap[5].Value := '6';

  var Num := AVariant;
  for var I := Low(ChokeMap) to High(ChokeMap) do
    if SameText(ChokeMap[I].Key, AVariant) then
    begin
      Num := ChokeMap[I].Value;
      Break;
    end;

  var InstName := Format('cymbal_%s_choke', [Num]);
  var Inst := TInstrumentRegistry.Get(InstName);
  if not Assigned(Inst) then
    Inst := TInstrumentRegistry.Get('cymbal_1_choke'); { fallback }

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 100; { CRASH_ACCENT }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.RideBell(APosition: float; AVelocity: Integer = 80): TPatternBuilder;
begin
  var Inst := TInstrumentRegistry.Get('ride_1_bell');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, AVelocity);
  Result := Self;
end;

function TPatternBuilder.RideShaft(APosition: float; AVelocity: Integer = 80): TPatternBuilder;
begin
  var Inst := TInstrumentRegistry.Get('ride_1_shaft_hit_stronger');
  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, AVelocity);
  Result := Self;
end;

function TPatternBuilder.CymbalOpen(APosition: float; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;
{ Accepts variant numbers 1-6. Also accepts short aliases: A=cymbal_1, B=cymbal_2, etc. }
var
  AliasMap: array[0..5] of record Key: string; Value: string; end;
begin
  AliasMap[0].Key := 'A'; AliasMap[0].Value := '1';
  AliasMap[1].Key := 'B'; AliasMap[1].Value := '2';
  AliasMap[2].Key := 'C'; AliasMap[2].Value := '3';
  AliasMap[3].Key := 'D'; AliasMap[3].Value := '4';
  AliasMap[4].Key := 'E'; AliasMap[4].Value := '5';
  AliasMap[5].Key := 'F'; AliasMap[5].Value := '6';

  var Num := AVariant;
  for var I := Low(AliasMap) to High(AliasMap) do
    if SameText(AliasMap[I].Key, AVariant) then
    begin
      Num := AliasMap[I].Value;
      Break;
    end;

  var InstName := Format('cymbal_%s_hit', [Num]);
  var Inst := TInstrumentRegistry.Get(InstName);
  if not Assigned(Inst) then
    Inst := TInstrumentRegistry.Get('cymbal_1_hit');

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 100; { CRASH_ACCENT }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.HiHatClosedShaft(APosition: float; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;
{ variant "1" or "2". }
var
  ShaftMap: array[0..1] of record Key: string; Value: string; end;
begin
  ShaftMap[0].Key := '1'; ShaftMap[0].Value := 'hihat_closed_1_shaft_closed_1_hit_dbl';
  ShaftMap[1].Key := '2'; ShaftMap[1].Value := 'hihat_closed_2_shaft_closed_2_hit_dbl';

  var KeyName := ShaftMap[0].Value; { default 1 }
  for var I := Low(ShaftMap) to High(ShaftMap) do
    if SameText(ShaftMap[I].Key, AVariant) then
    begin
      KeyName := ShaftMap[I].Value;
      Break;
    end;

  var Inst := TInstrumentRegistry.Get(KeyName);

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 80; { HIHAT_NORMAL }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.HiHatClosedBell(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
begin
  var Inst := TInstrumentRegistry.Get('hihat_closed_bell');

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 90; { HIHAT_ACCENT }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.OpenHiHat(APosition: float; const AVariant: string = 'A'; AVelocity: Integer = -1): TPatternBuilder;
{ Variants (AD2 mapping): A,B,C,D → open variants; BELL/Bell → open_bell. }
var
  OpenMap: array[0..4] of record Key: string; Value: string; end;
begin
  OpenMap[0].Key := 'A'; OpenMap[0].Value := 'hihat_open_a';
  OpenMap[1].Key := 'B'; OpenMap[1].Value := 'hihat_open_b';
  OpenMap[2].Key := 'C'; OpenMap[2].Value := 'hihat_open_c';
  OpenMap[3].Key := 'D'; OpenMap[3].Value := 'hihat_open_d';
  OpenMap[4].Key := 'BELL'; OpenMap[4].Value := 'hihat_open_bell';

  var KeyName := OpenMap[0].Value; { default A }
  for var I := Low(OpenMap) to High(OpenMap) do
    if SameText(OpenMap[I].Key, AVariant) then
    begin
      KeyName := OpenMap[I].Value;
      Break;
    end;

  var Inst := TInstrumentRegistry.Get(KeyName);

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 95; { HIHAT_OPEN }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.HiHatPedalOpen(APosition: float; AVelocity: Integer = -1): TPatternBuilder;
begin
  var Inst := TInstrumentRegistry.Get('hihat_pedal_open');

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 95; { HIHAT_OPEN }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.TightHH(APosition: float; AOpen: boolean = false; const AVariant: string = '1'; AVelocity: Integer = -1): TPatternBuilder;
{ variant selects the closed 2 family. }
var
  InstName: string;
begin
  if AOpen then
    InstName := 'hihat_closed_2_tip_closed_2_hit'
  else if SameText(AVariant, '2') then
    InstName := 'hihat_closed_2_tip_closed_2_hit'
  else
    InstName := 'hihat_closed_1_tip_closed_1_hit';

  var Inst := TInstrumentRegistry.Get(InstName);

  var Vel := AVelocity;
  if Vel = -1 then
    Vel := 80; { HIHAT_NORMAL }

  if Assigned(Inst) then
    Pattern.AddBeat(APosition, Inst, Vel);
  Result := Self;
end;

function TPatternBuilder.AddHit(AInstrument: TDrumInstrument; APosition: float; AVelocity: Integer = 100): TPatternBuilder;
begin
  if Assigned(AInstrument) then
    Pattern.AddBeat(APosition, AInstrument, AVelocity);
  Result := Self;
end;

function TPatternBuilder.Build: TPattern;
begin
  Result := FP pattern;
end;

end.
