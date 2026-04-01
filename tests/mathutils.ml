// ---------------------------------------------------------------------------
// mathutils.ml -- Math utility module for MyLang module compilation
//
// This file is a MyLang module imported by hello.ml via "use mathutils".
// When the MyLang semantic handler encounters the use statement, it
// calls compileModule("mathutils"), triggering the engine to lex, parse,
// and semantically analyze this file as a separate AST branch.
//
// MyLang uses mod/fn/let syntax -- a clean, modern design that shows
// Metamorf can define entirely original languages, not just replicate
// existing ones. The same module compilation mechanism works identically
// regardless of the surface syntax.
//
// Exports:
//   fn doubleVal(x: i64) -> i64    Returns x * 2
//   fn triple(x: i64) -> i64       Returns x * 3
//
// Compile with:  Metamorf -l mylang.mor -s hello.ml -r
//                (this file is compiled automatically via use)
// ---------------------------------------------------------------------------

mod mathutils;

fn doubleVal(x: i64) -> i64 {
  return x * 2;
}

fn triple(x: i64) -> i64 {
  return x * 3;
}
