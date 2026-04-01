' ---------------------------------------------------------------------------
' mathutils.inc -- Math utility module for BASIC INCLUDE support
'
' This file is a BASIC module imported by hello.bas via "INCLUDE mathutils".
' When the BASIC semantic handler encounters the INCLUDE statement, it
' calls compileModule("mathutils"), triggering the engine to lex, parse,
' and semantically analyze this file as a separate AST branch.
'
' BASIC uses MODULE/FUNCTION/END FUNCTION syntax with AS type annotations.
' Despite the very different syntax from Pascal or Scheme, the module
' compilation mechanism is identical -- compileModule() and
' setModuleExtension() work the same way in every .mor definition.
'
' Exports:
'   FUNCTION doubleVal(x AS Integer) AS Integer   Returns x * 2
'   FUNCTION triple(x AS Integer) AS Integer       Returns x * 3
'
' Compile with:  Metamorf -l basic.mor -s hello.bas -r
'                (this file is compiled automatically via INCLUDE)
' ---------------------------------------------------------------------------

MODULE mathutils

FUNCTION doubleVal(x AS Integer) AS Integer
  RETURN x * 2
END FUNCTION

FUNCTION triple(x AS Integer) AS Integer
  RETURN x * 3
END FUNCTION
