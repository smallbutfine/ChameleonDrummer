unit LimbConstraints;

{$mode objfpc}{$H+}

{ Physically-playable constraints for generated drum patterns.

  A drummer has two hands and two feet. This unit models that: every
  instrument is played by a specific limb (the kick by either foot), and a
  pattern is only playable if the hits at any one instant can be assigned to
  distinct limbs and no single limb has to repeat impossibly fast. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern;

type
  TLimb = (limbLeftHand, limbRightHand, limbLeftFoot, limbRightFoot);

  TLimbs = set of TLimb;

  { A single physical-playability violation. }
  TLimbViolation = class(TObject)
  public
    Kind: String;
    Position: Double;
    Description: String;
    constructor Create(const AKind, ADescription: String; APosition: Double);
    destructor Destroy; override;
  end;

  { Checks whether a pattern could actually be played by a human drummer. }
  TLimbConstraintEngine = class(TObject)
  private
    FMaxSimultaneousHits: Integer;
    FMinLimbGapBeats: Double;
    FMinFootGapBeats: Double;
    function LimbsFor(const AInstrumentName: String): TLimbs;
    function CanAssignDistinct(const AGroups: specialize TList<TLimbs>): Boolean;
    function AssignRecursive(const AGroups: specialize TList<TLimbs>;
      AIndex: Integer; AUsed: TLimbs): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property MaxSimultaneousHits: Integer read FMaxSimultaneousHits write FMaxSimultaneousHits;
    property MinLimbGapBeats: Double read FMinLimbGapBeats write FMinLimbGapBeats;
    property MinFootGapBeats: Double read FMinFootGapBeats write FMinFootGapBeats;

    function IsPlayable(const APattern: TPattern): Boolean;
    { Caller owns the returned list and must free the violations in it. }
    function FindViolations(const APattern: TPattern): specialize TList<TLimbViolation>;
    { For a simultaneous-hit group at APosition, returns True and sets
      RemoveIdx to the index of the beat that should be removed when there
      is a same-limb conflict.  Returns False when all hits can be assigned
      to distinct limbs (physically valid).  The indices are into the beat
      list of the caller's pattern. }
    function FindConflictHitToDiscard(const APattern: TPattern;
      APosition: Double; out RemoveIdx: Integer): Boolean;
  end;

implementation

const
  { Two hits closer than this many quarter-note beats count as simultaneous. }
  SIMULTANEOUS_TOLERANCE = 0.01;

  { A drummer has two hands and two feet. }
  LIMB_COUNT = 4;

type
  { A set of beats that are struck at the same instant. }
  TBeatGroup = class
  public
    Position: Double;
    Beats: specialize TList<TBeat>;
    constructor Create(APosition: Double);
    destructor Destroy; override;
  end;

  TBeatGroupList = specialize TList<TBeatGroup>;
  TBeatList = specialize TList<TBeat>;
  TLimbSetList = specialize TList<TLimbs>;

{ ── TBeatGroup ───────────────────────────────────────────────── }

constructor TBeatGroup.Create(APosition: Double);
begin
  inherited Create;
  Position := APosition;
  Beats := specialize TList<TBeat>.Create;
end;

destructor TBeatGroup.Destroy;
begin
  Beats.Free;
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

{ Number of limbs in a limb set. }
function LimbCount(const ALimbs: TLimbs): Integer;
var
  Limb: TLimb;
begin
  Result := 0;
  for Limb := Low(TLimb) to High(TLimb) do
    if Limb in ALimbs then
      Inc(Result);
end;

{ Splits the beats of a pattern into groups of simultaneous hits.
  Two beats are simultaneous when their positions differ by at most
  SIMULTANEUS_TOLERANCE beats. A group is seeded by its earliest beat and
  holds every beat within the tolerance of that seed. }
function BuildGroups(const APattern: TPattern): TBeatGroupList;
var
  Order: specialize TList<Integer>;
  Used: array of Boolean;
  Group: TBeatGroup;
  I, J, K: Integer;
  SeedPos: Double;
begin
  Result := TBeatGroupList.Create;
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
      Group := TBeatGroup.Create(SeedPos);
      for J := 0 to Order.Count - 1 do
        if (not Used[Order[J]]) and
           (Abs(APattern.Beats[Order[J]].Position - SeedPos) <= SIMULTANEOUS_TOLERANCE) then
        begin
          Used[Order[J]] := True;
          Group.Beats.Add(APattern.Beats[Order[J]]);
        end;
      Result.Add(Group);
    end;
  finally
    Order.Free;
  end;
end;

{ Frees a group list and the groups in it. }
procedure FreeGroups(const AGroups: TBeatGroupList);
var
  Group: TBeatGroup;
begin
  for Group in AGroups do
    Group.Free;
  AGroups.Free;
end;

{ ── TLimbViolation ───────────────────────────────────────────── }

constructor TLimbViolation.Create(const AKind, ADescription: String; APosition: Double);
begin
  inherited Create;
  Kind := AKind;
  Description := ADescription;
  Position := APosition;
end;

destructor TLimbViolation.Destroy;
begin
  inherited Destroy;
end;

{ ── TLimbConstraintEngine ────────────────────────────────────── }

constructor TLimbConstraintEngine.Create;
begin
  inherited Create;
  { Three simultaneous hits is what a drummer can comfortably manage
    (kick + snare + hi-hat). }
  FMaxSimultaneousHits := 3;
  { Smallest gap, in quarter-note beats, between two hits of the same hand.
    A 16th-note groove (0.25) and a 32nd-note groove (0.125) stay well
    clear of these limits, so ordinary material is never flagged. }
  FMinLimbGapBeats := 0.05;
  { The floor tom is played with a foot and needs a little more room. }
  FMinFootGapBeats := 0.08;
end;

destructor TLimbConstraintEngine.Destroy;
begin
  inherited Destroy;
end;

function TLimbConstraintEngine.LimbsFor(const AInstrumentName: String): TLimbs;
var
  LName: String;
begin
  LName := LowerCase(AInstrumentName);
  if Copy(LName, 1, 4) = 'kick' then
    { Either foot — a drummer plays the kick with heel or toe and it does
      not clash with a hand. }
    Result := [limbLeftFoot, limbRightFoot]
  else if Copy(LName, 1, 5) = 'snare' then
    Result := [limbRightHand]
  else if Copy(LName, 1, 5) = 'hihat' then
    Result := [limbLeftHand]
  else if Copy(LName, 1, 4) = 'ride' then
    Result := [limbLeftHand]
  else if Copy(LName, 1, 5) = 'tom_1' then
    Result := [limbRightHand]
  else if Copy(LName, 1, 5) = 'tom_2' then
    Result := [limbLeftHand]
  else if Copy(LName, 1, 5) = 'tom_3' then
    Result := [limbRightHand]
  else if Copy(LName, 1, 5) = 'tom_4' then
    Result := [limbRightFoot]
  else if Copy(LName, 1, 6) = 'cymbal' then
    Result := [limbRightHand]
  else
    { Unknown instrument — assume it can be taken by either hand. }
    Result := [limbLeftHand, limbRightHand];
end;

function TLimbConstraintEngine.CanAssignDistinct(const AGroups: specialize TList<TLimbs>): Boolean;
begin
  { More hits than limbs can never be assigned to distinct limbs. }
  if AGroups.Count > LIMB_COUNT then
    Exit(False);
  Result := AssignRecursive(AGroups, 0, []);
end;

function TLimbConstraintEngine.AssignRecursive(const AGroups: specialize TList<TLimbs>;
  AIndex: Integer; AUsed: TLimbs): Boolean;
var
  Limb: TLimb;
begin
  if AIndex >= AGroups.Count then
    Exit(True);
  for Limb := Low(TLimb) to High(TLimb) do
    if (Limb in AGroups[AIndex]) and not (Limb in AUsed) then
      if AssignRecursive(AGroups, AIndex + 1, AUsed + [Limb]) then
        Exit(True);
  Result := False;
end;

function TLimbConstraintEngine.IsPlayable(const APattern: TPattern): Boolean;
var
  Violations: specialize TList<TLimbViolation>;
  I: Integer;
begin
  Violations := FindViolations(APattern);
  try
    Result := Violations.Count = 0;
  finally
    for I := 0 to Violations.Count - 1 do
      Violations[I].Free;
    Violations.Free;
  end;
end;

{ True when beat A should be sacrificed before beat B: accents survive,
  ghost notes go before full hits, then lower velocity goes first. }
function IsLessImportant(A, B: TBeat): Boolean;
begin
  if A.Accent <> B.Accent then
    Result := not A.Accent
  else if A.GhostNote <> B.GhostNote then
    Result := A.GhostNote
  else
    Result := A.Velocity < B.Velocity;
end;

function TLimbConstraintEngine.FindConflictHitToDiscard(const APattern: TPattern;
  APosition: Double; out RemoveIdx: Integer): Boolean;
var
  Groups: TBeatGroupList;
  Group, Found: TBeatGroup;
  LimbSets: TLimbSetList;
  I, J: Integer;
  Best: TBeat;
  Resolves: Boolean;
begin
  Result := False;
  RemoveIdx := -1;
  Groups := BuildGroups(APattern);
  try
    Found := nil;
    for Group in Groups do
      if Abs(Group.Position - APosition) <= SIMULTANEOUS_TOLERANCE then
      begin
        Found := Group;
        Break;
      end;
    if (Found = nil) or (Found.Beats.Count < 2) then
      Exit;

    { Hits on distinct limbs and within the simultaneous limit are
      playable - nothing may be removed (this protects ghost notes). }
    LimbSets := TLimbSetList.Create;
    try
      for I := 0 to Found.Beats.Count - 1 do
        LimbSets.Add(LimbsFor(InstrumentNameOf(Found.Beats[I])));
      if (Found.Beats.Count <= FMaxSimultaneousHits) and CanAssignDistinct(LimbSets) then
        Exit;
    finally
      LimbSets.Free;
    end;

    { Conflict: pick the least important beat whose removal resolves it. }
    Best := nil;
    for I := 0 to Found.Beats.Count - 1 do
    begin
      LimbSets := TLimbSetList.Create;
      try
        for J := 0 to Found.Beats.Count - 1 do
          if J <> I then
            LimbSets.Add(LimbsFor(InstrumentNameOf(Found.Beats[J])));
        Resolves := (LimbSets.Count <= FMaxSimultaneousHits) and CanAssignDistinct(LimbSets);
      finally
        LimbSets.Free;
      end;
      if Resolves and ((Best = nil) or IsLessImportant(Found.Beats[I], Best)) then
        Best := Found.Beats[I];
    end;

    { No single removal resolves it: fall back to the least important hit. }
    if Best = nil then
      for I := 0 to Found.Beats.Count - 1 do
        if (Best = nil) or IsLessImportant(Found.Beats[I], Best) then
          Best := Found.Beats[I];

    for I := 0 to APattern.Beats.Count - 1 do
      if APattern.Beats[I] = Best then
      begin
        RemoveIdx := I;
        Result := True;
        Break;
      end;
  finally
    FreeGroups(Groups);
  end;
end;

function TLimbConstraintEngine.FindViolations(const APattern: TPattern): specialize TList<TLimbViolation>;
var
  Groups: TBeatGroupList;
  Group: TBeatGroup;
  LimbSets: TLimbSetList;
  Hits: TBeatList;
  InstNames: TStringList;
  Beat: TBeat;
  Name: String;
  Limbs: TLimbs;
  Gap, MinGap: Double;
  I, J, K: Integer;
begin
  Result := specialize TList<TLimbViolation>.Create;

  { ── Constraint 1 and 2 — per group of simultaneous hits ── }
  Groups := BuildGroups(APattern);
  try
    for Group in Groups do
    begin
      { Constraint 1 — too many hits at the same instant. }
      if Group.Beats.Count > FMaxSimultaneousHits then
        Result.Add(TLimbViolation.Create('simultaneous',
          Format('%d simultaneous hits at position %.3f - a drummer only has %d limbs',
            [Group.Beats.Count, Group.Position, FMaxSimultaneousHits]),
          Group.Position));

      { Constraint 2 — the hits cannot be taken by distinct limbs. }
      LimbSets := specialize TList<TLimbs>.Create;
      try
        for Beat in Group.Beats do
          LimbSets.Add(LimbsFor(InstrumentNameOf(Beat)));
        if not CanAssignDistinct(LimbSets) then
          Result.Add(TLimbViolation.Create('limb_conflict',
            Format('Hits at position %.3f cannot be assigned to distinct limbs',
              [Group.Position]),
            Group.Position));
      finally
        LimbSets.Free;
      end;
    end;
  finally
    FreeGroups(Groups);
  end;

  { ── Constraint 3 — repeat speed on single-limb instruments ── }
  InstNames := TStringList.Create;
  try
    InstNames.Sorted := True;
    InstNames.Duplicates := dupIgnore;
    for Beat in APattern.Beats do
      if LimbCount(LimbsFor(InstrumentNameOf(Beat))) = 1 then
        InstNames.Add(InstrumentNameOf(Beat));

    for I := 0 to InstNames.Count - 1 do
    begin
      Name := InstNames[I];
      Hits := specialize TList<TBeat>.Create;
      try
        for Beat in APattern.Beats do
          if SameText(InstrumentNameOf(Beat), Name) then
            Hits.Add(Beat);

        { Sort the hits of this instrument by position. }
        for J := 1 to Hits.Count - 1 do
        begin
          Beat := Hits[J];
          K := J - 1;
          while K >= 0 do
          begin
            if Hits[K].Position <= Beat.Position then
              Break;
            Hits[K + 1] := Hits[K];
            Dec(K);
          end;
          Hits[K + 1] := Beat;
        end;

        if Hits.Count > 0 then
        begin
          Limbs := LimbsFor(Name);
          if Limbs = [limbRightFoot] then
            MinGap := FMinFootGapBeats
          else
            MinGap := FMinLimbGapBeats;

          for J := 1 to Hits.Count - 1 do
          begin
            Gap := Hits[J].Position - Hits[J - 1].Position;
            if Gap < MinGap then
              Result.Add(TLimbViolation.Create('repeat_speed',
                Format('%s repeats at position %.3f, only %.3f beats after the previous hit (minimum %.3f)',
                  [Name, Hits[J].Position, Gap, MinGap]),
                Hits[J].Position));
          end;
        end;
      finally
        Hits.Free;
      end;
    end;
  finally
    InstNames.Free;
  end;
end;

end.
