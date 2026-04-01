// ---------------------------------------------------------------------------
// hello2.pas -- Pascal2 showcase for Metamorf
//
// This is the test source for pascal2.mor, demonstrating all advanced
// features of the modular Pascal2 language definition. Where hello.pas
// tests the basic pascal.mor, hello2.pas exercises the full Pascal2
// feature set.
//
// Features exercised:
//   Source-level directives  @optimize, @subsystem, @platform, @exeicon,
//                            @vermajor through @copyright -- all configure
//                            the Zig/Clang build pipeline from source
//   Program/uses             program declaration with uses clause, which
//                            triggers compileModule() for mathlib.pas
//   Variables                var block with typed declarations
//   Procedures               procedure Greet(name: string) and an
//                            overloaded Greet(name: string, times: integer)
//   Overload detection       Two procedures named "Greet" with different
//                            parameter types. The semantics engine detects
//                            the overload via symbolExistsWithPrefix() and
//                            adjusts C linkage via demoteCLinkageForPrefix()
//   Function calls           Calls to doubleVal(), triple(), add() from
//                            the imported mathlib unit
//   WriteLn with format      WriteLn("x = {}", x) using format placeholders
//
// Expected output (with -r flag):
//   Hello, World!
//   Hello, World! (x3)
//   x = 42
//   doubleVal(21) = 42
//   triple(7) = 21
//   add(10, 32) = 42
//
// Compile with:  Metamorf -l pascal2.mor -s hello2.pas -r
// ---------------------------------------------------------------------------

@optimize debug
@subsystem console
@optimize releasesmall

@exeicon "res\assets\icons\metamorf.ico"
@vermajor 2
@verminor 0
@verpatch 0
@product "Hello2"
@description "Pascal2 test program compiled by Metamorf"
@filename "hello2.exe"
@company "tinyBigGAMES LLC"
@copyright "Copyright (c) 2025 tinyBigGAMES LLC"

program Hello2;

@platform win64

uses mathlib;

var
  x: integer;
  msg: string;

procedure Greet(name: string);
begin
  WriteLn("Hello, {}!", name);
end;

procedure Greet(name: string, times: integer);
var
  i: integer;
begin
  for i := 1 to times do
    WriteLn("Hello, {}!", name);
  end
end;

begin
  x := 42;
  msg := "World";
  Greet(msg);
  Greet(msg, 3);
  WriteLn("x = {}", x);
  WriteLn("doubleVal(21) = {}", doubleVal(21));
  WriteLn("triple(7) = {}", triple(7));
  WriteLn("add(10, 32) = {}", add(10, 32));
end.
