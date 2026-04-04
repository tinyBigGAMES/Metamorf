// ---------------------------------------------------------------------------
// hello.pas — Pascal showcase for Metamorf
//
// Pascal is a structured, imperative programming language designed by
// Niklaus Wirth in 1970. Known for its clean syntax and strong typing,
// Pascal was originally created as a language suitable for teaching
// programming as a systematic discipline. It influenced many later
// languages including Modula-2, Oberon, Ada, and Delphi.
//
// This demo exercises: program, var, function, procedure, if/then/else,
// while/do, for/to, write/writeln, mod, and/or/not, recursion, and
// nested expressions — all compiling to C++23 via std::print/println.
// ---------------------------------------------------------------------------

//@platform win64 | linux64
//@platform linux64

@optimize debug
@subsystem console
program Hello;

uses mathutils;

// Mixed-mode: directly include C++ headers to call C++ functions
#include <cstdio>

function add(a: integer, b: integer): integer;
begin
  Result := a + b;
end;

function factorial(n: integer): integer;
begin
  if n <= 1 then
    Result := 1;
  else
    Result := n * factorial(n - 1);
  end
end;

var
  sum: integer;
  i: integer;

begin
  // Greeting
  writeln("Hello from Pascal!");

  // Arithmetic with function call
  sum := add(10, 32);
  writeln("add(10, 32) = {}", sum);

  // If/else branching
  write("{} > 40: ", sum);
  if sum > 40 then
    writeln("true");
  else
    writeln("false");
  end

  write("{} > 50: ", sum);
  if sum > 50 then
    writeln("true");
  else
    writeln("false");
  end

  // While loop — countdown
  write("Countdown: ");
  i := 5;
  while i >= 0 do
    write("{} ", i);
    i := i - 1;
  end
  writeln();

  // For loop — factorials
  writeln("Factorials:");
  for i := 1 to 5 do
    writeln("  {}! = {}", i, factorial(i));
  end
  // Nested expression
  writeln("factorial(add(2,3)) = {}", factorial(add(2, 3)));

  // FizzBuzz 1-15
  writeln("FizzBuzz:");
  for i := 1 to 15 do
    if (i mod 15) = 0 then
      writeln("  FizzBuzz");
    else
      if (i mod 3) = 0 then
        writeln("  Fizz");
      else
        if (i mod 5) = 0 then
          writeln("  Buzz");
        else
          writeln("  {}", i);
        end
      end
    end
  end

  // Mixed-mode: call C++ directly
  printf("C++ says: factorial(10) = %lld\n", (long long)(factorial(10)));

  // Unit function calls
  writeln("doubleVal(21) = {}", doubleVal(21));
  writeln("triple(7) = {}", triple(7));

  writeln("Done!");
end.