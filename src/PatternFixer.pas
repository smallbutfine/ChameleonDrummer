unit PatternFixer;

{$mode objfpc}{$H+}

{ Repairs patterns that a human drummer could not physically play, by
  removing the hits that conflict, keeping the accented ones. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, LimbConstraints;

type
  TPatternFixer = class(TObject)
  private
    FEngine: TLimbConstraintEngine;
  public
    constructor Create;
    destructor Destroy; override;

    property Engine: TLimbConstraintEngine read FEngine write FEngine;

    { Repairs the pattern.
      CONTRACT: the returned pattern is the SAME object as the input when no
      repair was necessary, and a NEW object when beats were removed. The
      input is never modified and never freed by this method. }
    function Fix(const APattern: TPattern): TPattern;

    function NeedsFix(const APattern: TPattern): Boolean;
  end;

implementation

const
  { Two hits closer than this many quarter-note beats count as simultaneous. }
  SIMULTANEOUS_TOLERANCE = 0.01;

  { Used when a hit has no predecessor to compare against. }
  UNLIMITED_GAP = 1.0E+30;

type
  { A group of simultaneously struck beats, stored as indices into the
    beat list of a pattern. }
  TIndexGroup = class
  public
    Position: Double;
    Indices: specialize TList<Integer>;
    constructor Create(APosition: Double);
    destructor Destroy; override;
  end;

  TIndexGroupList = specialize TList<TIndexGroup>;

{ ── TIndexGroup ──────────────────────────────────────────────── }

constructor TIndexGroup.Create(APosition: Double);
begin
  inherited Create;
  Position := APosition;
  Indices := specialize TList<Integer>.Create;
end;

destructor TIndexGroup.Destroy;
begin
  Indices.Free;
  inherited Destroy;
end;

{ ── helpers ──────────────────────────────────────────────────── }

{ Name of the instrument a beat is played on ('' when it has none). }
function InstrumentNameOf(const ABeat: TBeat): String;
begin
  Result := '';
  if ABeat = nil then
    Exit;
  if not Assigned(ABeat.Instrument) then
    Exit;
  Result := ABeat.Instrument.Name;
end;

{ Splits the beats of a pattern into groups of simultaneous hits.
  This mirrors the grouping used by TLimbConstraintEngine so that the
  fixer removes beats from exactly the group the engine complained about. }
function BuildIndexGroups(const APattern: TPattern): TIndexGroupList;
var
  Order: specialize TList<Integer>;
  Used: array of Boolean;
  Group: TIndexGroup;
  I, J, K: Integer;
  SeedPos: Double;
begin
  Result := TIndexGroupList.Create;
  Order := specialize TList<Integer>.Create;
  try
    for I := 0 to APattern.Beats.Count - 1 do
      Order.Add(I);

    { Insertion sort the beat indices by position. }
    for I := 1 to Order.Count - 1 do
    begin
      J := Order[I];
      K := I - 1;
      while K >= 0 do
      begin
        if APattern.Beats[Order[K]].Position <= APattern.Beats[J].Position then
          Break;
        Order[K + 1] := Order[K];
        Dec(K);
      end;
      Order[K + 1] := J;
    end;

    SetLength(Used, APattern.Beats.Count);
    for I := 0 to High(Used) do
      Used[I] := False;

    for I := 0 to Order.Count - 1 do
    begin
      if Used[Order[I]] then
        Continue;
      SeedPos := APattern.Beats[Order[I]].Position;
      Group := TIndexGroup.Create(SeedPos);
      for J := 0 to Order.Count - 1 do
        if (not Used[Order[J]]) and
           (Abs(APattern.Beats[Order[J]].Position - SeedPos) <= SIMULTANEOUS_TOLERANCE) then
        begin
          Used[Order[J]] := True;
          Group.Indices.Add(Order[J]);
        end;
      Result.Add(Group);
    end;
  finally
    Order.Free;
  end;
end;

{ Frees a group list and the groups in it. }
procedure FreeIndexGroups(const AGroups: TIndexGroupList);
var
  Group: TIndexGroup;
begin
  for Group in AGroups do
    Group.Free;
  AGroups.Free;
end;

{ Finds the group that was seeded at the given position. }
function FindGroupAt(const AGroups: TIndexGroupList; APosition: Double): TIndexGroup;
var
  Group: TIndexGroup;
  Best: TIndexGroup;
  BestDistance: Double;
  Distance: Double;
begin
  Result := nil;
  Best := nil;
  BestDistance := UNLIMITED_GAP;
  for Group in AGroups do
  begin
    if Abs(Group.Position - APosition) < 0.000001 then
      Exit(Group);
    Distance := Abs(Group.Position - APosition);
    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      Best := Group;
    end;
  end;
  { Fall back to the closest group when the exact seed is gone. }
  if (Best <> nil) and (BestDistance <= SIMULTANEOUS_TOLERANCE) then
    Result := Best;
end;

{ True when A is the weaker hit of the two and should be removed first.
  Accented hits survive, ghost notes go before full-velocity hits and
  lower velocity goes first. }
function WeakerThan(A, B: TBeat): Boolean;
begin
  if A.Accent <> B.Accent then
    Result := not A.Accent
  else if A.GhostNote <> B.GhostNote then
    Result := A.GhostNote
  else
    Result := A.Velocity < B.Velocity;
end;

{ Removes a beat from the pattern: the beat object is freed and taken out
  of the beat list. }
procedure RemoveBeat(APattern: TPattern; ABeat: TBeat);
var
  I: Integer;
begin
  for I := APattern.Beats.Count - 1 downto 0 do
    if APattern.Beats[I] = ABeat then
    begin
      ABeat.Free;
      APattern.Beats.Delete(I);
      Exit;
    end;
end;

{ Distance in beats to the closest earlier hit of the same instrument.
  UNLIMITED_GAP when the instrument was not played before. }
function GapToPrevious(APattern: TPattern; ABeat: TBeat): Double;
var
  BestPos: Double;
  Found: Boolean;
  B: TBeat;
begin
  Result := UNLIMITED_GAP;
  Found := False;
  BestPos := 0;
  for B in APattern.Beats do
    if (B <> ABeat) and (B.Position < ABeat.Position) and
       SameText(InstrumentNameOf(B), InstrumentNameOf(ABeat)) then
    begin
      if (not Found) or (B.Position > BestPos) then
      begin
        BestPos := B.Position;
        Found := True;
      end;
    end;
  if Found then
    Result := ABeat.Position - BestPos;
end;

{ Removes the weakest hit of the group of simultaneous hits that sits at
  the given position. Returns True when a beat was removed. }
function RemoveWeakestInGroup(APattern: TPattern; APosition: Double): Boolean;
var
  Groups: TIndexGroupList;
  Group: TIndexGroup;
  Weakest: Integer;
  I: Integer;
begin
  Result := False;
  Groups := BuildIndexGroups(APattern);
  try
    Group := FindGroupAt(Groups, APosition);
    if Group = nil then
      Exit(False);
    if Group.Indices.Count = 0 then
      Exit(False);

    Weakest := -1;
    for I := 0 to Group.Indices.Count - 1 do
    begin
      if Weakest < 0 then
        Weakest := Group.Indices[I]
      else if WeakerThan(APattern.Beats[Group.Indices[I]],
                         APattern.Beats[Weakest]) then
        Weakest := Group.Indices[I];
    end;

    if Weakest < 0 then
      Exit(False);

    RemoveBeat(APattern, APattern.Beats[Weakest]);
    Result := True;
  finally
    FreeIndexGroups(Groups);
  end;
end;

{ Removes the later of the two hits that repeat too quickly on one limb.
  Returns True when a beat was removed. }
function RemoveLaterHit(AEngine: TLimbConstraintEngine; APattern: TPattern;
  APosition: Double): Boolean;
var
  Candidates: specialize TList<TBeat>;
  Best: TBeat;
  BestGap, Gap, MaxGap: Double;
  I: Integer;
begin
  Result := False;
  Candidates := APattern.GetBeatsAtPosition(APosition, SIMULTANEOUS_TOLERANCE);
  try
    { Only hits that repeat faster than the loosest limit can be the
      offending ones. }
    MaxGap := Max(AEngine.MinLimbGapBeats, AEngine.MinFootGapBeats);
    Best := nil;
    BestGap := UNLIMITED_GAP;
    for I := 0 to Candidates.Count - 1 do
    begin
      Gap := GapToPrevious(APattern, Candidates[I]);
      if (Gap < MaxGap) and ((Best = nil) or (Gap < BestGap)) then
      begin
        Best := Candidates[I];
        BestGap := Gap;
      end;
    end;

    if Best = nil then
    begin
      { Nothing to compare against - fall back to the latest hit here. }
      if Candidates.Count = 0 then
        Exit(False);
      Best := Candidates[Candidates.Count - 1];
    end;

    RemoveBeat(APattern, Best);
    Result := True;
  finally
    Candidates.Free;
  end;
end;

{ Applies the repair that belongs to one violation. Returns True when a
  beat was removed. }
function RemoveViolation(AEngine: TLimbConstraintEngine; APattern: TPattern;
  const AViolation: TLimbViolation): Boolean;
begin
  if AViolation.Kind = 'repeat_speed' then
    Result := RemoveLaterHit(AEngine, APattern, AViolation.Position)
  else
    Result := RemoveWeakestInGroup(APattern, AViolation.Position);
end;

{ ── TPatternFixer ────────────────────────────────────────────── }

constructor TPatternFixer.Create;
begin
  inherited Create;
  FEngine := TLimbConstraintEngine.Create;
end;

destructor TPatternFixer.Destroy;
begin
  FEngine.Free;
  inherited Destroy;
end;

function TPatternFixer.NeedsFix(const APattern: TPattern): Boolean;
var
  Violations: specialize TList<TLimbViolation>;
  I: Integer;
begin
  Violations := FEngine.FindViolations(APattern);
  try
    Result := Violations.Count > 0;
  finally
    for I := 0 to Violations.Count - 1 do
      Violations[I].Free;
    Violations.Free;
  end;
end;

function TPatternFixer.Fix(const APattern: TPattern): TPattern;
var
  Violations: specialize TList<TLimbViolation>;
  Progress: Boolean;
  I: Integer;
begin
  { Nothing to repair - hand the very same pattern back to the caller. }
  if not NeedsFix(APattern) then
    Exit(APattern);

  Result := APattern.Copy;
  try
    repeat
      Violations := FEngine.FindViolations(Result);
      try
        Progress := False;
        for I := 0 to Violations.Count - 1 do
          if RemoveViolation(FEngine, Result, Violations[I]) then
          begin
            Progress := True;
            Break;
          end;
      finally
        for I := 0 to Violations.Count - 1 do
          Violations[I].Free;
        Violations.Free;
      end;
    until not Progress;
  except
    Result.Free;
    raise;
  end;
end;

end.
