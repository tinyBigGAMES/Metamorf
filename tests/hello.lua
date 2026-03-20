-- ---------------------------------------------------------------------------
-- hello.lua — Lua showcase for Metamorf
--
-- Lua is a lightweight, high-performance scripting language designed by
-- Roberto Ierusalimschy, Waldemar Celes, and Luiz Henrique de Figueiredo
-- at PUC-Rio in 1993. Known for its simplicity, embeddability, and speed,
-- Lua is widely used in game engines, embedded systems, and applications.
--
-- This demo exercises: function, local, if/then/elseif/else, while/do,
-- for/do, repeat/until, print, write, return, mod (%), and/or/not,
-- recursion, and nested expressions — all compiling to C++23 via
-- std::print/println.
-- ---------------------------------------------------------------------------

@platform win64
@optimize debug
@subsystem console

require mathutils

-- Mixed-mode: directly include C++ headers to call C++ functions
#include <cstdio>

function add(a: number, b: number): number
  return a + b
end

function factorial(n: number): number
  if n <= 1 then
    return 1
  else
    return n * factorial(n - 1)
  end
end

local sum: number = 0
local i: number = 0

-- Greeting
print("Hello from Lua!")

-- Arithmetic with function call
sum = add(10, 32)
print("add(10, 32) = {}", sum)

-- If/else branching
write("{} > 40: ", sum)
if sum > 40 then
  print("true")
else
  print("false")
end

write("{} > 50: ", sum)
if sum > 50 then
  print("true")
else
  print("false")
end

-- While loop — countdown
write("Countdown: ")
i = 5
while i >= 0 do
  write("{} ", i)
  i = i - 1
end
print()

-- For loop — factorials
print("Factorials:")
for i = 1, 5 do
  print("  {}! = {}", i, factorial(i))
end

-- Nested expression
print("factorial(add(2,3)) = {}", factorial(add(2, 3)))

-- FizzBuzz 1-15
print("FizzBuzz:")
for i = 1, 15 do
  if (i % 15) == 0 then
    print("  FizzBuzz")
  elseif (i % 3) == 0 then
    print("  Fizz")
  elseif (i % 5) == 0 then
    print("  Buzz")
  else
    print("  {}", i)
  end
end

-- Mixed-mode: call C++ directly
printf("C++ says: factorial(10) = %lld\n", (long long)(factorial(10)))

-- Module function calls
print("doubleVal(21) = {}", doubleVal(21))
print("triple(7) = {}", triple(7))

print("Done!")
