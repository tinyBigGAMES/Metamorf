; ---------------------------------------------------------------------------
; hello.scm — Scheme showcase for Metamorf
;
; Scheme is a minimalist dialect of Lisp designed by Guy L. Steele and
; Gerald Jay Sussman at MIT in 1975. Known for its elegance, lexical
; scoping, and first-class continuations, Scheme strips Lisp down to
; its essential core. This dialect adds type annotations for compiled
; output.
;
; This demo exercises: define (functions and variables), if, cond,
; set, display, write, newline, arithmetic (+, -, *, /, %), comparison
; (=, <, >, <=, >=), and/or/not, recursion, and nested expressions —
; all compiling to C++23 via std::print/println.
; ---------------------------------------------------------------------------

@platform win64
@optimize debug
@subsystem console

(require mathutils)

; Mixed-mode: directly include C++ headers to call C++ functions
#include <cstdio>

(define (add (a : number) (b : number)) : number
  (+ a b))

(define (factorial (n : number)) : number
  (if (<= n 1)
    1
    (* n (factorial (- n 1)))))

(define sum : number 0)
(define i : number 0)

; Greeting
(display "Hello from Scheme!")

; Arithmetic with function call
(set sum (add 10 32))
(display "add(10, 32) = {}" sum)

; If/else branching
(write "{} > 40: " sum)
(if (> sum 40)
  (display "true")
  (display "false"))

(write "{} > 50: " sum)
(if (> sum 50)
  (display "true")
  (display "false"))

; While loop equivalent — countdown via recursion
(define (countdown (n : number)) : void
  (begin
    (write "{} " n)
    (if (> n 0)
      (countdown (- n 1)))))

(write "Countdown: ")
(countdown 5)
(newline)

; For loop equivalent — factorials via recursion
(define (printFactorials (i : number) (max : number)) : void
  (begin
    (display "  {}! = {}" i (factorial i))
    (if (< i max)
      (printFactorials (+ i 1) max))))

(display "Factorials:")
(printFactorials 1 5)

; Nested expression
(display "factorial(add(2,3)) = {}" (factorial (add 2 3)))

; FizzBuzz 1-15 via cond and recursion
(define (fizzBuzz (i : number) (max : number)) : void
  (begin
    (cond
      ((= (% i 15) 0) (display "  FizzBuzz"))
      ((= (% i 3) 0)  (display "  Fizz"))
      ((= (% i 5) 0)  (display "  Buzz"))
      (else            (display "  {}" i)))
    (if (< i max)
      (fizzBuzz (+ i 1) max))))

(display "FizzBuzz:")
(fizzBuzz 1 15)

; Mixed-mode: call C++ directly
printf("C++ says: factorial(10) = %lld\n", (long long)(factorial(10)))

; Module function calls
(display "doubleVal(21) = {}" (doubleVal 21))
(display "triple(7) = {}" (triple 7))

(display "Done!")
