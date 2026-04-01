// ---------------------------------------------------------------------------
// mathlib.pas -- Math utility unit for Pascal2 module compilation
//
// This file is a Pascal2 unit (not a program). It is imported by
// hello2.pas via the "uses mathlib" statement. When the Pascal2 semantic
// handler encounters stmt.uses_item, it calls compileModule("mathlib"),
// which triggers the engine to find mathlib.pas (using the module
// extension "pas" set by setModuleExtension), lex it, parse it, and
// run semantic analysis on it.
//
// The unit keyword (instead of program) causes the emitter to call
// setBuildMode("lib") and emit function signatures to the .h header
// file (the "Pass 1.5: header forward declarations" pattern in
// pascal2_emitters.mor). This allows hello2.pas to #include the
// generated header and call these functions.
//
// Exports:
//   doubleVal(x: integer): integer    Returns x * 2
//   triple(x: integer): integer       Returns x * 3
//   add(a, b: integer): integer       Returns a + b
//
// Compile with:  Metamorf -l pascal2.mor -s hello2.pas -r
//                (this file is compiled automatically via uses)
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
