unit PhysicalConstraints;

{$mode objfpc}{$H+}

{ PhysicalConstraints — thin wrapper that delegates to LimbConstraints.
  This eliminates duplication while maintaining backward compatibility for
  any code that imports TPhysicalConstraintChecker. }

interface

uses
  Classes, SysUtils, Math,
  Pattern, LimbConstraints;

// ============================================================================
// TPhysicalConstraintResult — Result of physical playability validation
// (kept for backward compat; functionally identical to TLimbConstraintEngine)
// ============================================================================
type
  TPhysicalConstraintResult = record
    IsValid: Boolean;
    Violations: TArray<String>;
    MaxSimultaneousHits: Integer;
    MinLimbGap: Double;
  end;

// ============================================================================
// TPhysicalConstraintChecker — Thin wrapper over TLimbConstraintEngine.
// All logic is delegated to the canonical engine in limb_constraints.pas.
// ============================================================================
type
  TPhysicalConstraintChecker = class
  private
    FEngine: TLimbConstraintEngine;
  public
    constructor Create(A_MAX_SIM_HITS: Integer = 4; A_MIN_LIMB_GAP: Double = 0.01);
    destructor Destroy; override;

    function Validate(APattern: TPattern): TPhysicalConstraintResult;
    function FixViolations(APattern: TPattern): TPattern;
  end;

implementation

constructor TPhysicalConstraintChecker.Create(A_MAX_SIM_HITS: Integer; A_MIN_LIMB_GAP: Double);
begin
  FEngine := TLimbConstraintEngine.Create(A_MAX_SIM_HITS, A_MIN_LIMB_GAP);
end;

destructor TPhysicalConstraintChecker.Destroy;
begin
  FEngine.Free;
  inherited Destroy;
end;

function TPhysicalConstraintChecker.Validate(APattern: TPattern): TPhysicalConstraintResult;
var
  Violations: TArray<String>;
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  Result.IsValid := FEngine.IsValid(APattern);
  Violations := FEngine.GetViolations(APattern);

  SetLength(Result.Violations, Length(Violations));
  for I := Low(Violations) to High(Violations) do
    Result.Violations[I] := Violations[I];

  Result.MaxSimultaneousHits := FEngine.FMaxSimultaneousHits;
  Result.MinLimbGap := FEngine.FMinLimbGap;
end;

function TPhysicalConstraintChecker.FixViolations(APattern: TPattern): TPattern;
begin
  { Delegate to engine's pattern fixer. */
  Result := FEngine.FixPatterns(APattern);
end;

end.
