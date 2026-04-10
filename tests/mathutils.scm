// ---------------------------------------------------------------------------
// mathutils.scm -- Math utility module for Scheme module compilation
//
// This file is a Scheme module imported by hello.scm via (require mathutils).
// When the Scheme semantic handler encounters the require form, it
// calls compileModule("mathutils"), triggering the engine to lex, parse,
// and semantically analyze this file as a separate AST branch.
//
// Scheme's S-expression syntax is fundamentally different from the
// Algol-family languages (Pascal, Lua, MyLang). This file demonstrates
// that Metamorf's module compilation works regardless of the source
// language's syntactic family -- the engine mechanism is the same.
//
// Exports:
//   (define (doubleVal (x : number)) : number ...)   Returns (* x 2)
//   (define (triple (x : number)) : number ...)      Returns (* x 3)
//
// Compile with:  Metamorf -l scheme.mor -s hello.scm -r
//                (this file is compiled automatically via require)
// ---------------------------------------------------------------------------

(module mathutils)

(define (doubleVal (x : number)) : number
  (* x 2))

(define (triple (x : number)) : number
  (* x 3))