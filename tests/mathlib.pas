// ---------------------------------------------------------------------------
// mathlib.pas — Math utility unit for Pascal2
// ---------------------------------------------------------------------------

unit mathlib;

function doubleVal(x: integer): integer;
begin
  Result := x * 2;
end;

function triple(x: integer): integer;
begin
  Result := x * 3;
end;

function add(a: integer, b: integer): integer;
begin
  Result := a + b;
end;
