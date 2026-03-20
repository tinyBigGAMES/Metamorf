; ---------------------------------------------------------------------------
; mathutils.scm — Module test file for Scheme require/module support
; ---------------------------------------------------------------------------

(module mathutils)

(define (doubleVal (x : number)) : number
  (* x 2))

(define (triple (x : number)) : number
  (* x 3))
