unit AdditiveRhythm;

{$mode objfpc}{$H+}

{ Additive rhythm generator for ChameleonDrummer.
  Converts box notation grouping strings (e.g., "3-3-3-3-2-2") into
  per-bar time signatures and generates matching drum patterns. }

interface

uses
  Classes, SysUtils, Generics.Collections, Pattern, Kit, time_signature;

type
  TAdditiveGroup = record
    Size: Integer;           // 2,3,4,5,6,7...
    IsExplicitBar: Boolean;  // terminated by '|'
  end;

  TAdditiveGroupDynArray = array of TAdditiveGroup;
  TTimeSignatureDynArray = array of TTimeSignature;

  { Parse a grouping string like "3-3-3-3-2-2" or "3-3-3|3-3-2" into groups.
    - Groups separated by '-' or '+'
    - '|' marks explicit bar boundary (heterogeneous bar)
    - Runs of identical sizes without '|' become one bar per group
    Returns array of groups with their sizes and explicit bar flags. }
function ParseAdditiveGrouping(const S: String; AGridResolution: Integer): TAdditiveGroupDynArray;

{ Resolve time signatures from additive groups.
  Each group becomes one bar with numerator = group size, denominator = grid resolution / 4.
  For example, grid=16 (16th notes), group size 3 -> 3/16 = 3/8 time signature. }
function ResolveTimeSignatures(const Groups: TAdditiveGroupDynArray; AGridResolution: Integer): TTimeSignatureDynArray;

{ Generate a drum pattern from additive rhythm groups.
  - Kick on first step of each group (downbeat of each additive cell)
  - Snare on backbeat positions (using MeterBackbeats)
  - Hi-hat continuous on grid resolution
  - Applies drummer styling if specified }
function GenerateAdditivePattern(
  const Groups: TAdditiveGroupDynArray;
  AGridResolution: Integer;
  ATempo: Integer;
  ADrummer: String = '';
  ADrummerIntensity: Double = 1.0
): TPattern;

implementation

uses Math, PluginRegistry, DrummerPlugin;

function ParseAdditiveGrouping(const S: String; AGridResolution: Integer): TAdditiveGroupDynArray;
var
  Parts: TStringList;
  Part: String;
  I, Size: Integer;
  ExplicitBar: Boolean;
  CleanPart: String;
begin
  Result := nil;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '-';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := StringReplace(S, '+', '-', [rfReplaceAll]);

    for I := 0 to Parts.Count - 1 do
    begin
      Part := Trim(Parts[I]);
      if Part = '' then Continue;

      ExplicitBar := False;
      CleanPart := Part;

      { Check for explicit bar marker '|' }
      if (Length(Part) > 0) and (Part[Length(Part)] = '|') then
      begin
        ExplicitBar := True;
        CleanPart := Copy(Part, 1, Length(Part) - 1);
      end;

      if not TryStrToInt(CleanPart, Size) then
        Continue;

      if (Size < 1) or (Size > 32) then
        Continue;

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].Size := Size;
      Result[High(Result)].IsExplicitBar := ExplicitBar;
    end;
  finally
    Parts.Free;
  end;
end;

function ResolveTimeSignatures(const Groups: TAdditiveGroupDynArray; AGridResolution: Integer): TTimeSignatureDynArray;
var
  I: Integer;
  Den: Integer;
  Num: Integer;
  TS: TTimeSignature;
begin
  Result := nil;
  Den := AGridResolution div 4;  // 16th grid -> 4 (8th), 8th grid -> 2 (4th), etc.
  if Den < 1 then Den := 1;

  for I := 0 to High(Groups) do
  begin
    Num := Groups[I].Size;
    TS := TTimeSignature.Create(Num, Den);
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := TS;
  end;
end;

function GenerateAdditivePattern(
  const Groups: TAdditiveGroupDynArray;
  AGridResolution: Integer;
  ATempo: Integer;
  ADrummer: String;
  ADrummerIntensity: Double
): TPattern;
var
  PluginReg: TPluginRegistry;
  DrummerPlugin: TDrummerPlugin;
  TimeSigs: TTimeSignatureDynArray;
  TotalBars: Integer;
  BarIndex: Integer;
  GroupIndex: Integer;
  StepsPerBar: Integer;
  StepIndex: Integer;
  KickPos, SnarePos, HatPos: Double;
  Backbeats: specialize TArray<Double>;
  BarStartQN: Double;
  KickInst, SnareInst, HatInst: TDrumInstrument;
  DrummerObj: TObject;
begin
  Result := TPattern.Create('AdditiveRhythm');
  Result.TimeSignature.Free;
  Result.TimeSignature := TTimeSignature.Create(4, 4);  // Will be overridden per bar
  Result.Subdivision := AGridResolution;

  { Get instrument objects from registry }
  KickInst := TInstrumentRegistry.Get('kick');
  SnareInst := TInstrumentRegistry.Get('snare');
  HatInst := TInstrumentRegistry.Get('hihat');

  TimeSigs := ResolveTimeSignatures(Groups, AGridResolution);
  TotalBars := Length(TimeSigs);

  { Get drummer plugin if specified }
  DrummerPlugin := nil;
  PluginReg := TPluginRegistry.Create;
  try
    if (ADrummer <> '') then
    begin
      DrummerObj := PluginReg.GetDrummerPlugin(ADrummer);
      if Assigned(DrummerObj) and (DrummerObj is TDrummerPlugin) then
        DrummerPlugin := TDrummerPlugin(DrummerObj);
    end;

    { Generate pattern bar by bar }
    BarStartQN := 0.0;
    GroupIndex := 0;

    for BarIndex := 0 to TotalBars - 1 do
    begin
      { Get time signature for this bar }
      Result.TimeSignature.Free;
      Result.TimeSignature := TTimeSignature.Create(TimeSigs[BarIndex].Numerator, TimeSigs[BarIndex].Denominator);

      StepsPerBar := TimeSigs[BarIndex].Numerator * (AGridResolution div 4);

      { Get backbeat positions for this meter }
      Backbeats := MeterBackbeats(TimeSigs[BarIndex].Numerator, TimeSigs[BarIndex].Denominator);

      { Kick on first step of each group (downbeat of each additive cell) }
      KickPos := BarStartQN;
      Result.AddBeat(KickPos, KickInst, 110);

      { Snare on backbeats }
      for SnarePos in Backbeats do
      begin
        Result.AddBeat(BarStartQN + SnarePos, SnareInst, 100);
      end;

      { Hi-hat continuous on grid }
      for StepIndex := 0 to StepsPerBar - 1 do
      begin
        HatPos := BarStartQN + StepIndex * (TimeSigs[BarIndex].BeatsPerBar / StepsPerBar);
        { Velocity variation for hi-hat }
        if (StepIndex mod 2 = 0) then
          Result.AddBeat(HatPos, HatInst, 80)
        else
          Result.AddBeat(HatPos, HatInst, 60);
      end;

      { Move to next bar }
      BarStartQN := BarStartQN + TimeSigs[BarIndex].BeatsPerBar;
      Inc(GroupIndex);
    end;

    { Apply drummer styling if specified }
    if Assigned(DrummerPlugin) and (ADrummerIntensity > 0) then
    begin
      Result := DrummerPlugin.ApplyStyle(Result);
    end;
  finally
    PluginReg.Free;
  end;
end;

end.