unit ComposerTypes;

{$mode objfpc}{$H+}

interface

type
  TThreadedRandom = class
    function NextInt(AMax: Integer): Integer;
    function NextDouble: Double;
  end;

implementation

function TThreadedRandom.NextInt(AMax: Integer): Integer;
begin
  Result := Random(AMax);
end;

function TThreadedRandom.NextDouble: Double;
begin
  Result := Random;
end;

end.
