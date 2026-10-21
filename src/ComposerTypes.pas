unit ComposerTypes;

{$mode objfpc}{$H+}

interface

type
  { Deterministic, seedable pseudo-random generator.

    FPC's global Random() cannot be seeded per instance, which makes
    generation irreproducible when several generators are alive at once.
    This class keeps its own xorshift state so a given seed always
    produces the same sequence. }
  TThreadedRandom = class
  private
    FState: QWord;
    procedure EnsureSeeded;
  public
    constructor Create(ASeed: QWord = 0);
    destructor Destroy; override;

    property Seed: QWord read FState write FState;

    { Uniform integer in [0, AMax). }
    function NextInt(AMax: Integer): Integer;
    { Uniform double in [0.0, 1.0). }
    function NextDouble: Double;
    { Uniform integer in [0, AMax) — alias kept for call-site clarity. }
    function Random(AMax: Integer): Integer;
  end;

implementation

constructor TThreadedRandom.Create(ASeed: QWord);
begin
  inherited Create;
  FState := ASeed;
  if FState = 0 then
    FState := QWord($9E3779B97F4A7C15);
  EnsureSeeded;
end;

destructor TThreadedRandom.Destroy;
begin
  inherited Destroy;
end;

procedure TThreadedRandom.EnsureSeeded;
begin
  { xorshift64* must never be seeded with zero. }
  if FState = 0 then
    FState := QWord($9E3779B97F4A7C15);
end;

function TThreadedRandom.NextInt(AMax: Integer): Integer;
begin
  EnsureSeeded;
  if AMax <= 0 then
    Exit(0);
  { xorshift64* }
  FState := FState xor (FState shr 12);
  FState := FState xor (FState shl 25);
  FState := FState xor (FState shr 27);
  Result := Integer((FState * QWord(2685821657736338717)) shr 33 mod QWord(AMax));
end;

function TThreadedRandom.NextDouble: Double;
begin
  EnsureSeeded;
  { 53-bit mantissa in [0,1) }
  FState := FState xor (FState shr 12);
  FState := FState xor (FState shl 25);
  FState := FState xor (FState shr 27);
  Result := Double((FState * QWord(2685821657736338717)) shr 11) / 9007199254740992.0;
end;

function TThreadedRandom.Random(AMax: Integer): Integer;
begin
  Result := NextInt(AMax);
end;

end.
