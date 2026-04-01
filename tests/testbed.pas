// Testbed for multipass forward references
// Function A calls B, but B is declared AFTER A.
// Without multipass: "undefined identifier 'B'" error
// With multipass: pass 1 declares B, pass 2 resolves A's call to B

program Testbed;

var
  result: integer;

function A(x: integer): integer;
begin
  Result := B(x + 1);
end;

function B(x: integer): integer;
begin
  Result := x * 2;
end;

begin
  WriteLn("B(5) = {}", B(5));
  WriteLn("A(5) = {}", A(5));
  result := A(10);
  WriteLn("A(10) = {}", result);
end.
