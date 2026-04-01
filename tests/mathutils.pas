// ---------------------------------------------------------------------------
// mathutils.pas -- Math utility unit for Pascal module compilation
//
// This file is a Pascal unit imported by hello.pas via "uses mathutils".
// When the Pascal semantic handler encounters the uses statement, it
// calls compileModule("mathutils"), triggering the engine to lex, parse,
// and semantically analyze this file as a separate AST branch.
//
// The unit is compiled to its own .h/.cpp pair and linked into the
// final binary. This demonstrates Metamorf's module compilation system:
// a single .mor language definition can compile multi-file projects
// where each source file is a branch on the master AST.
//
// Exports:
//   doubleVal(x: integer): integer   Returns x * 2
//   triple(x: integer): integer      Returns x * 3
//
// Compile with:  Metamorf -l pascal.mor -s hello.pas -r
//                (this file is compiled automatically via uses)
// ---------------------------------------------------------------------------

unit mathutils;

function doubleVal(x: integer): integer;
  Result := x * 2;
end

function triple(x: integer): integer;
  Result := x * 3;
end
