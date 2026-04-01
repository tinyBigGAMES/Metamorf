-- ---------------------------------------------------------------------------
-- mathutils.lua -- Math utility module for Lua module compilation
--
-- This file is a Lua module imported by hello.lua via "require mathutils".
-- When the Lua semantic handler encounters the require statement, it
-- calls compileModule("mathutils"), triggering the engine to lex, parse,
-- and semantically analyze this file as a separate AST branch.
--
-- The module is compiled to its own .h/.cpp pair and linked into the
-- final binary. This demonstrates that Metamorf's module compilation
-- system works across different language definitions -- the same engine
-- mechanism (compileModule + setModuleExtension) is used by Pascal,
-- Lua, MyLang, Scheme, and BASIC.
--
-- Exports:
--   doubleVal(x: number): number   Returns x * 2
--   triple(x: number): number      Returns x * 3
--
-- Compile with:  Metamorf -l lua.mor -s hello.lua -r
--                (this file is compiled automatically via require)
-- ---------------------------------------------------------------------------

module mathutils

function doubleVal(x: number): number
  return x * 2
end

function triple(x: number): number
  return x * 3
end
