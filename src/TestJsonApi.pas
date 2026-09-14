program TestJsonApi;
{$mode objfpc}{$H+}
uses fpjson, fcl;

procedure CheckMethods;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    Writeln('Count:', O.Count);
    { Try GetElement }
    Writeln('Has GetElement');
  finally
    O.Free;
  end;
end;

begin
  CheckMethods;
end.
