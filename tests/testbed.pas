// ---------------------------------------------------------------------------
// testbed.pas -- Forward reference test for multi-pass semantics
//
// This source file tests that Metamorf's multi-pass semantic analysis
// correctly resolves forward references. Function A calls function B,
// but B is declared AFTER A in the source. Without multi-pass semantics,
// the compiler would report "undefined identifier 'B'" when analyzing A.
//
// With the testbed.mor language definition:
//   Pass 1 ("declarations") declares both A and B into the symbol table
//   Pass 2 ("analysis") resolves A's reference to B successfully
//
// The emitter also demonstrates C++ forward declarations: it emits
// function signatures before their full definitions so the C++ compiler
// can resolve the same forward references.
//
// Expected output:
//   B(5) = 10
//   A(5) = 12
//   A(10) = 22
//
// Compile with:  Metamorf -l testbed.mor -s testbed.pas -r
// ---------------------------------------------------------------------------

@platform win64
@optimize debug
@subsystem console

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
