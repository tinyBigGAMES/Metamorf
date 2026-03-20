' ---------------------------------------------------------------------------
' hello.bas — BASIC showcase for Metamorf
'
' BASIC (Beginners' All-purpose Symbolic Instruction Code) was designed by
' John Kemeny and Thomas Kurtz at Dartmouth College in 1964. Originally
' intended as an easy-to-learn language for non-science students, BASIC
' became one of the most widely used programming languages through the
' personal computer era. This dialect is inspired by FreeBASIC/QBasic.
'
' This demo exercises: DIM, FUNCTION, SUB, IF/THEN/ELSEIF/ELSE/END IF,
' WHILE/WEND, FOR/TO/NEXT, DO/LOOP UNTIL, PRINT, WRITE, MOD, AND/OR/NOT,
' recursion, and nested expressions — all compiling to C++23 via
' std::print/println.
' ---------------------------------------------------------------------------

@platform win64
@optimize debug
@subsystem console

INCLUDE mathutils

' Mixed-mode: directly include C++ headers to call C++ functions
#include <cstdio>

FUNCTION add(a AS Integer, b AS Integer) AS Integer
  RETURN a + b
END FUNCTION

FUNCTION factorial(n AS Integer) AS Integer
  IF n <= 1 THEN
    RETURN 1
  ELSE
    RETURN n * factorial(n - 1)
  END IF
END FUNCTION

DIM sum AS Integer = 0
DIM i AS Integer = 0

' Greeting
PRINT("Hello from BASIC!")

' Arithmetic with function call
sum = add(10, 32)
PRINT("add(10, 32) = {}", sum)

' If/else branching
WRITE("{} > 40: ", sum)
IF sum > 40 THEN
  PRINT("true")
ELSE
  PRINT("false")
END IF

WRITE("{} > 50: ", sum)
IF sum > 50 THEN
  PRINT("true")
ELSE
  PRINT("false")
END IF

' While loop — countdown
WRITE("Countdown: ")
i = 5
WHILE i >= 0
  WRITE("{} ", i)
  i = i - 1
WEND
PRINT()

' For loop — factorials
PRINT("Factorials:")
FOR i = 1 TO 5
  PRINT("  {}! = {}", i, factorial(i))
NEXT

' Nested expression
PRINT("factorial(add(2,3)) = {}", factorial(add(2, 3)))

' FizzBuzz 1-15
PRINT("FizzBuzz:")
FOR i = 1 TO 15
  IF (i MOD 15) = 0 THEN
    PRINT("  FizzBuzz")
  ELSEIF (i MOD 3) = 0 THEN
    PRINT("  Fizz")
  ELSEIF (i MOD 5) = 0 THEN
    PRINT("  Buzz")
  ELSE
    PRINT("  {}", i)
  END IF
NEXT

' Mixed-mode: call C++ directly
printf("C++ says: factorial(10) = %lld\n", (long long)(factorial(10)))

' Module function calls
PRINT("doubleVal(21) = {}", doubleVal(21))
PRINT("triple(7) = {}", triple(7))

PRINT("Done!")
