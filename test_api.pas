program testfpjson;
{$mode objfpc}{$H+}
uses fpjson;

procedure CheckMethods;
var
  J: TJSONData;
  O: TJSONObject;
begin
  O := TJSONObject.Create(nil);
  try
    { Try to find methods available }
    Writeln('TJSONObject methods:');
    { This won't compile if GetValue doesn't exist }
    // Just a compile check
  finally
    O.Free;
  end;
end;

begin
  CheckMethods;
end.
