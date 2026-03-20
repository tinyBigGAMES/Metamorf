// ---------------------------------------------------------------------------
// hello.ml — MyLang showcase for Metamorf
//
// MyLang is a custom language created to demonstrate that Metamorf
// can define entirely new programming languages, not just replicate
// existing ones. It features a clean, modern syntax with fn, let,
// brace-delimited blocks, and -> return type annotations.
//
// This demo exercises: fn, let, if/else if/else, while, for/to,
// loop/until, print, write, return, %, and/or/not, recursion, and
// nested expressions — all compiling to C++23 via std::print/println.
// ---------------------------------------------------------------------------

@platform win64
@optimize debug
@subsystem console

use mathutils;

// Mixed-mode: directly include C++ headers to call C++ functions
#include <cstdio>

fn add(a: int, b: int) -> int {
  return a + b;
}

fn factorial(n: int) -> int {
  if n <= 1 {
    return 1;
  } else {
    return n * factorial(n - 1);
  }
}

let sum: int = 0;
let i: int = 0;

// Greeting
print("Hello from MyLang!");

// Arithmetic with function call
sum = add(10, 32);
print("add(10, 32) = {}", sum);

// If/else branching
write("{} > 40: ", sum);
if sum > 40 {
  print("true");
} else {
  print("false");
}

write("{} > 50: ", sum);
if sum > 50 {
  print("true");
} else {
  print("false");
}

// While loop — countdown
write("Countdown: ");
i = 5;
while i >= 0 {
  write("{} ", i);
  i = i - 1;
}
print();

// For loop — factorials
print("Factorials:");
for i = 1 to 5 {
  print("  {}! = {}", i, factorial(i));
}

// Nested expression
print("factorial(add(2,3)) = {}", factorial(add(2, 3)));

// FizzBuzz 1-15
print("FizzBuzz:");
for i = 1 to 15 {
  if (i % 15) == 0 {
    print("  FizzBuzz");
  } else if (i % 3) == 0 {
    print("  Fizz");
  } else if (i % 5) == 0 {
    print("  Buzz");
  } else {
    print("  {}", i);
  }
}

// Mixed-mode: call C++ directly
printf("C++ says: factorial(10) = %lld\n", (long long)(factorial(10)));

// Module function calls
print("doubleVal(21) = {}", doubleVal(21));
print("triple(7) = {}", triple(7));

print("Done!");
