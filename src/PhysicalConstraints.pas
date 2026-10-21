unit PhysicalConstraints;

{$mode objfpc}{$H+}

{ PhysicalConstraints — thin wrapper that delegates to LimbConstraints.
  This eliminates duplication while maintaining backward compatibility for
  any code that imports TPhysicalConstraintChecker.

  The wrapper only uses the public API of TLimbConstraintEngine — the
  thresholds are read and written through its properties, never through
  fields of another unit. }

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  Pattern, LimbConstraints, PatternFixer;

{ ============================================================================
  TPhysicalConstraintResult — Result of physical playability validation
  (kept for backward compat; functionally identical to TLimbConstraintEngine)
  ============================================================================ }
type
  TPhysicalConstraintResult = record
    IsValid: Boolean;
    Violations: specialize TArray<String>;
    MaxSimultaneousHits: Integer;
    MinLimbGap: Double;
  end;

{ ============================================================================
  TPhysicalConstraintChecker — Thin wrapper over TLimbConstraintEngine.
  All logic is delegated to the canonical engine in LimbConstraints.
  ============================================================================ }
type
  TPhysicalConstraintChecker = class
  private
    FEngine: TLimbConstraintEngine;
  public
    constructor Create(A_MAX_SIM_HITS: Integer = 3; A_MIN_LIMB_GAP: Double = 0.05);
    destructor Destroy; override;

    function Validate(APattern: TPattern): TPhysicalConstraintResult;
    function FixViolations(APattern: TPattern): TPattern;
  end;

implementation

constructor TPhysicalConstraintChecker.Create(A_MAX_SIM_HITS: Integer; A_MIN_LIMB_GAP: Double);
begin
  FEngine := TLimbConstraintEngine.Create;
  FEngine.MaxSimultaneousHits := A_MAX_SIM_HITS;
  FEngine.MinLimbGapBeats := A_MIN_LIMB_GAP;
end;

destructor TPhysicalConstraintChecker.Destroy;
begin
  FEngine.Free;
  inherited Destroy;
end;

function TPhysicalConstraintChecker.Validate(APattern: TPattern): TPhysicalConstraintResult;
var
  Violations: specialize TList<TLimbViolation>;
  I: Integer;
begin
  Result.IsValid := False;
  Result.MaxSimultaneousHits := 0;
  Result.MinLimbGap := 0.0;
  SetLength(Result.Violations, 0);

  Violations := FEngine.FindViolations(APattern);
  try
    Result.IsValid := Violations.Count = 0;

    SetLength(Result.Violations, Violations.Count);
    for I := 0 to Violations.Count - 1 do
      Result.Violations[I] := Format('%s @ %.3f: %s',
        [Violations[I].Kind, Violations[I].Position, Violations[I].Description]);
  finally
    for I := 0 to Violations.Count - 1 do
      Violations[I].Free;
    Violations.Free;
  end;

  Result.MaxSimultaneousHits := FEngine.MaxSimultaneousHits;
  Result.MinLimbGap := FEngine.MinLimbGapBeats;
end;

function TPhysicalConstraintChecker.FixViolations(APattern: TPattern): TPattern;
var
  Fixer: TPatternFixer;
begin
  { Delegate to the pattern fixer. The fixer owns its own engine, so the
    thresholds of this checker are copied over instead of sharing the
    instance. }
  Fixer := TPatternFixer.Create;
  try
    Fixer.Engine.MaxSimultaneousHits := FEngine.MaxSimultaneousHits;
    Fixer.Engine.MinLimbGapBeats := FEngine.MinLimbGapBeats;
    Fixer.Engine.MinFootGapBeats := FEngine.MinFootGapBeats;
    Result := Fixer.Fix(APattern);
  finally
    Fixer.Free;
  end;
end;

end.
