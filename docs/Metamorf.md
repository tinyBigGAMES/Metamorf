<div align="center">

![Metamorf](../media/logo.png)

</div>

## 📖 Table of Contents

1. [Overview](#-overview)
2. [Getting Started](#-getting-started)
3. [Architecture](#-architecture)
4. [File Structure](#-file-structure)
5. [Tokens Block](#-tokens-block)
6. [Types Block](#-types-block)
7. [Grammar Block](#-grammar-block)
8. [Semantics Block](#-semantics-block)
9. [Emitters Block](#-emitters-block)
10. [The Imperative Language](#-the-imperative-language)
11. [Routines and Constants](#-routines-and-constants)
12. [Fragments, Imports, and Includes](#-fragments-imports-and-includes)
13. [Built-in Functions Reference](#-built-in-functions-reference)
14. [C++ Passthrough](#-c-passthrough)
15. [Embedding Metamorf](#-embedding-metamorf)
16. [Formal Grammar (EBNF)](#-formal-grammar-ebnf)
17. [Design Principles](#-design-principles)
18. [System Requirements](#-system-requirements)
19. [Building from Source](#-building-from-source)
20. [Contributing, Support, and License](#-contributing-support-and-license)


## 🌟 Overview

Metamorf is a compiler construction meta-language. You describe a complete programming language - its tokens, types, grammar rules, semantic analysis, and C++23 code generation - in a single `.mor` file. Metamorf reads that file, builds a fully configured compiler in memory, and immediately uses it to compile source files to native Win64/Linux64 binaries via Zig/Clang.

**Who is this manual for?** You are a developer who wants to define a programming language using Metamorf. You know what a lexer, parser, and AST are. You do not need to be a compiler expert - this manual will teach you the rest - but you should be comfortable reading code and thinking about how source text becomes structured data.

**From Grammar to Native Binary.** One file defines your language. One command compiles your program:

```bash
Metamorf -s pascal.mor hello.pas
```

Most language definition tools (YACC, ANTLR, traditional BNF grammars) give you a declarative grammar and then punt to a host language for anything non-trivial. Metamorf is a **complete, unified compiler-construction language**. It has variables, assignment, unbounded loops, conditionals, arithmetic, string operations, and user-defined routines with recursion — all first-class constructs alongside declarative grammar rules and token definitions. Every aspect of your language — from complex parsing logic to multi-pass code generation — is expressible entirely within the `.mor` file itself. The `.mor` language is itself built using the same `TMetamorf` API it exposes to embedders — it dogfoods its own engine every time it runs.

No host language glue code. No build system integration. No escape hatch to C, Java, or Python. A single `.mor` file is a complete, portable, standalone language specification that produces native binaries.

**What Metamorf provides:**

- **Single-file language definitions** covering the entire pipeline: lexer tokens, Pratt parser grammar, semantic analysis, and C++23 code generation
- **Turing complete language** — variables, loops, conditionals, recursion, and string operations are first-class constructs, not a bolt-on scripting layer. Every handler body uses the same unified language
- **Pratt parser grammar rules** with declarative prefix/infix/statement patterns and full imperative constructs for complex parsing — both are part of one language, neither is primary or fallback
- **Multi-pass semantic analysis** with scope management, symbol declaration, forward reference resolution, and overload detection
- **IR builder code generation** producing structured C++23 through `func()`, `declVar()`, `ifStmt()`, and similar typed builders - not raw string concatenation
- **Automatic C++ passthrough** so your language can interoperate with C/C++ without any `.mor` configuration
- **Native binary output** for Win64 and Linux64 via Zig/Clang, with cross-compilation through WSL2


## 🚀 Getting Started

### Using Metamorf

Metamorf ships as a self-contained release with everything included. No separate toolchain download, no configuration.

1. Download the latest release from [GitHub Releases](https://github.com/tinyBigGAMES/Metamorf/releases)
2. Extract the archive to any directory
3. Write a `.mor` language definition and a source file, then compile:

```bash
Metamorf -s pascal.mor hello.pas
```

The `-s` flag tells Metamorf to compile the source file using the specified language definition. The resulting native binary is placed in the output directory and can be run immediately.

### Cross-Compilation via WSL2

To target Linux from Windows, install WSL2 with Ubuntu:

```bash
wsl --install -d Ubuntu
```

Then set the target platform in your source file using a directive (if your language definition supports it):

```
@platform linux64
```

### Getting the Source (Developers)

Clone the repository to get the full source for Metamorf and all sub-projects:

```bash
git clone https://github.com/tinyBigGAMES/Metamorf.git
```

The repository is organized as:

```
Metamorf/repo/
  src/                          <- Metamorf core sources
  tests/                        <- Test files including pascal.mor
  docs/                         <- Reference documentation
  bin/                          <- Executables run from here
```

## ⚙️ Architecture

Metamorf operates in two sequential phases. Think of it like writing a recipe that tells a kitchen how to cook. Phase 1 reads your recipe (the `.mor` file) and configures all the kitchen equipment. Phase 2 uses that equipment to actually cook the meal (compile your source code to a binary). Understanding this two-phase architecture is essential for writing correct `.mor` files, because it determines when your code runs and what it has access to.

```
                        PHASE 1: Bootstrap
                        ==================
mylang.mor  ──► Metamorf bootstrap ──► TMetamorfLangInterpreter.Execute()
                (TMetamorf instance)              │
                                       Walks .mor AST, calls
                                       TLangConfig API to
                                       configure a blank TMetamorf
                                             │
                                       Configured TMetamorf
                                       (your language)
                                             │
                        PHASE 2: Compilation │
                        ==================== │
myprogram.src ──────────────────────────────►│──► TMetamorf.Compile()
                                                     │
                                               Lex ► Parse ► Semantics ► C++23 ► Zig/Clang
                                                     │
                                               native binary (Win64/Linux64)
```

### Phase 1: Bootstrap Compilation

The `.mor` file is compiled by the Metamorf bootstrap parser - itself a `TMetamorf` instance pre-configured with Metamorf's own lexer, grammar, and semantics. The bootstrap parser produces an AST which is then walked by `TMetamorfLangInterpreter`. The interpreter executes your `.mor` file: it reads token declarations, grammar rules, semantic handlers, and emitter handlers, and configures a new blank `TMetamorf` instance by calling `TLangConfig` API methods. All closures registered during this phase capture references to AST nodes from the bootstrap instance.

### Phase 2: Source Compilation

The configured `TMetamorf` instance compiles your source file through the full pipeline: lexing, parsing, semantic analysis, C++23 code generation, Zig/Clang compilation, and optional auto-run. The bootstrap instance and interpreter must remain alive for the entire duration of Phase 2 because the registered closures reference their AST nodes.

### Lifetime Rules

The two-phase architecture creates a dependency chain that you need to understand:

- The bootstrap `TMetamorf` instance owns the Phase 1 AST
- The interpreter's closures reference Phase 1 AST nodes
- Phase 2 closures (grammar handlers, semantic rules, emitters) fire during `TMetamorf.Compile()`
- All three objects (bootstrap, interpreter, custom TMetamorf) must remain alive until Phase 2 completes
- `TMetamorf` manages this automatically - `FreeInstances()` frees them in correct order

If the bootstrap instance were freed before Phase 2 completes, every closure would reference dead AST nodes - and your compiler would crash with access violations that are nearly impossible to debug. Metamorf handles this lifetime management for you, but if you are embedding Metamorf in your own application (see [Section 15](#-embedding-metamorf)), you need to keep all three objects alive until compilation finishes.

### The Closure Bridge

Every handler you write in a `.mor` file - every grammar rule body, every semantic handler, every emitter - becomes a Delphi closure that captures the AST node where the handler was defined. When Phase 2 fires a grammar rule, it does not re-parse your `.mor` file. Instead, it executes the interpreter against the captured AST node from Phase 1. This closure bridge is the mechanism that connects your meta-language code to the compiler engine. Your `.mor` code runs at compile time of the user's source, not at definition time.



## 📁 File Structure

A `.mor` file begins with a `language` declaration and contains top-level blocks that describe each aspect of your language. Comments use `//` (line) and `/* ... */` (block). Here is the overall shape:

```mor
language MyLang version "1.0";

// Optional: fragments must appear before they are included
fragment common_types {
  type int32 = "type.int32";
  type int64 = "type.int64";
}

// Optional: imports load other .mor files
import "common_tokens.mor";

tokens {
  // Keywords, operators, delimiters, comments, strings, directives, config
}

types {
  // Type keywords, type mappings, literal types, compatibility rules
  include common_types;
}

grammar {
  // Prefix, infix, and statement rules
}

semantics {
  // Semantic analysis handlers (scope, declare, visit)
}

emitters {
  // Code generation handlers (IR builders, emit statements)
}

// Reusable helper routines (callable from any handler)
routine resolveType(typeText: string) -> string {
  if typeText == "integer" { return "int64_t"; }
  return typeText;
}

// Named constants
const {
  MAX_PARAMS = 255;
  DEFAULT_ALIGN = 8;
}

// Enums (members become integer constants: exe=0, dll=1, lib=2)
enum BuildKind { exe, dll, lib }
```

### Language Declaration

Every `.mor` file starts with a language name and version. These are stored as internal variables `__language_name` and `__language_version`, accessible from handler logic if you need them.

```mor
language Pascal version "1.0";
```

### Top-Level Declarations

You can place blocks in any order, and blocks of the same kind can appear more than once (for example, two separate `tokens {}` blocks). The interpreter processes them sequentially from top to bottom. The one constraint is that fragments must be defined before they are included, and imports are resolved when encountered. A common convention is: tokens first, then types, grammar, semantics, emitters, and finally helper routines and constants - but this is a readability choice, not a requirement.

| Declaration | Description |
|-------------|-------------|
| `language Name version "X.Y";` | Language name and version (required, must be first) |
| `tokens { ... }` | Lexer configuration: keywords, operators, strings, directives, structural settings |
| `types { ... }` | Type system: type keywords, type-to-C++ mappings, compatibility rules |
| `grammar { ... }` | Pratt parser rules: prefix, infix, and statement rules |
| `semantics { ... }` | Semantic analysis: scope management, symbol declaration, child visitation |
| `emitters { ... }` | Code generation: IR builders, emit statements, section management |
| `routine name(...) { ... }` | Reusable helper function callable from any handler |
| `const { ... }` | Named constants available in all handler contexts |
| `enum Name { ... }` | Enumeration: members become sequential integer constants (0, 1, 2, ...) |
| `fragment Name { ... }` | Reusable block of declarations, expanded by `include Name;` |
| `import "path.mor";` | Import another `.mor` definition file |
| `include Name;` | Expand a previously defined fragment in place |

Blocks can appear in any order and can appear more than once. The interpreter processes them sequentially. With the file structure in place, the first block most language definitions need is the tokens block - it teaches Metamorf's lexer how to break source code into meaningful pieces.


## 🔧 Tokens Block

The `tokens {}` block teaches Metamorf's lexer how to break your source code into meaningful pieces. Before the parser can understand structure, the lexer needs to know what a keyword looks like, what operators your language uses, how strings are delimited, and how comments are formatted. Every `token` entry follows the pattern:

```mor
token category.name = "text" [flags];
```

The `category` prefix determines how the token is registered with the engine. This is not decorative naming - the category controls which engine API gets called:

| Category | Engine API | Description |
|----------|-----------|-------------|
| `keyword.*` | `AddKeyword(text, kind)` | Reserved word |
| `op.*` | `AddOperator(text, kind)` | Operator |
| `delimiter.*` | `AddOperator(text, kind)` | Punctuation/delimiter |
| `comment.line` | `AddLineComment(text)` | Line comment prefix |
| `comment.block_open` | (paired with `block_close`) | Block comment open |
| `comment.block_close` | `AddBlockComment(open, close)` | Block comment close |
| `string.*` | `AddStringStyle(open, close, kind, escape)` | String literal style |
| `directive.*` | `AddDirective(name, kind, role)` | Named directive |

### Keywords

Keywords are reserved words in your language. Once declared, the lexer will recognize them and emit the specified token kind instead of `identifier`. This means these words can never be used as variable or function names in your language - they are permanently reserved. If the user tries to name a variable `begin`, the parser will see `keyword.begin` instead of `identifier`, and the parse will fail in a way that produces a clear error.

```mor
tokens {
  token keyword.program   = "program";
  token keyword.begin     = "begin";
  token keyword.end       = "end";
  token keyword.var       = "var";
  token keyword.if        = "if";
  token keyword.then      = "then";
  token keyword.else      = "else";
  token keyword.while     = "while";
  token keyword.do        = "do";
  token keyword.for       = "for";
  token keyword.to        = "to";
  token keyword.downto    = "downto";
  token keyword.true      = "true";
  token keyword.false     = "false";
  token keyword.nil       = "nil";
  token keyword.and       = "and";
  token keyword.or        = "or";
  token keyword.not       = "not";
}
```

### Operators and Delimiters

Operators and delimiters are the punctuation of your language - the symbols that express operations and structure. The engine sorts operators by length internally to ensure longest-match behavior (so `:=` is matched before `:` when both are registered), but declaring multi-character operators before shorter ones in your `.mor` file serves as documentation of your intent.

```mor
tokens {
  // Multi-character operators first
  token op.assign       = ":=";
  token op.neq          = "<>";
  token op.lte          = "<=";
  token op.gte          = ">=";

  // Single-character operators
  token op.plus         = "+";
  token op.minus        = "-";
  token op.star         = "*";
  token op.slash        = "/";
  token op.eq           = "=";
  token op.lt           = "<";
  token op.gt           = ">";

  // Delimiters
  token delimiter.lparen    = "(";
  token delimiter.rparen    = ")";
  token delimiter.lbracket  = "[";
  token delimiter.rbracket  = "]";
  token delimiter.comma     = ",";
  token delimiter.colon     = ":";
  token delimiter.semicolon = ";";
  token delimiter.dot       = ".";
}
```

### Comments

Line comments use `comment.line`. Block comments require a `comment.block_open` / `comment.block_close` pair - declare both and the engine pairs them automatically. You can declare multiple comment styles if your language supports them (for example, both `//` and `--` as line comments).

```mor
tokens {
  token comment.line        = "//";
  token comment.block_open  = "/*";
  token comment.block_close = "*/";
}
```

Multiple comment styles can be declared:

```mor
tokens {
  token comment.line        = "//";
  token comment.line        = "--";       // two line-comment styles
  token comment.block_open  = "(*";
  token comment.block_close = "*)";
}
```

### String Styles

Every language handles strings differently. C uses `"hello\n"` with backslash escapes. Pascal uses `'hello'` where `''` is a literal quote - no backslashes at all. Metamorf's `string.*` tokens let you define exactly how your language's strings work.

The **default behavior** (no flags) processes backslash escape sequences (`\n`, `\t`, `\\`, etc.) and uses the pattern text as both the opening and closing delimiter. If your language uses C-style strings, the default is what you want.

If your language does not use backslash escapes, add `[noescape]`. The lexer will then treat two consecutive close delimiters as one literal character - this is the Pascal `''` convention. Watch out: if you forget `[noescape]` on a Pascal-style string, every backslash in user source code will be interpreted as an escape sequence. Your users will get mysterious parse errors on Windows file paths like `'C:\Users\...'`.

If your string's opening delimiter differs from its closing delimiter (like a wide string `w"hello"`), use `[close "\""]` to tell the lexer what ends the string.

```mor
tokens {
  // C-style escaped string: "hello\n"
  token string.cstring = "\"";

  // Pascal-style unescaped string: 'hello' ('' = literal ')
  token string.pascal  = "'" [noescape];

  // Wide string with different open/close: w"hello"
  token string.wstring = "w\"" [close "\""];
}
```

**String flags:**

| Flag | Description |
|------|-------------|
| `noescape` | Disable backslash escape processing. Content is literal. Two consecutive close delimiters represent one literal close delimiter (Pascal convention). |
| `close "X"` | Use `X` as the closing delimiter instead of the opening pattern. Useful when the open pattern differs from the close (e.g., `w"` opens, `"` closes). |

### Directives

Directives are a two-tier system. Some directives are handled entirely by the lexer at lex time - these are conditional compilation directives like `@ifdef` and `@endif` that include or exclude blocks of source code before the parser ever sees them. Other directives are passed through to the parser as regular tokens, where you handle them with grammar rules, semantic handlers, and emitters.

First set the directive prefix, then declare each directive. Conditional compilation flags (`[define]`, `[ifdef]`, etc.) tell the lexer to handle the directive itself. Directives without these flags pass through to the parser.

```mor
tokens {
  directive_prefix = "@";

  // Conditional compilation directives (handled by lexer)
  token directive.define  = "define"  [define];
  token directive.undef   = "undef"   [undef];
  token directive.ifdef   = "ifdef"   [ifdef];
  token directive.ifndef  = "ifndef"  [ifndef];
  token directive.elseif  = "elseif"  [elseif];
  token directive.else    = "else"    [else];
  token directive.endif   = "endif"   [endif];

  // Regular directives (passed to parser as tokens)
  token directive.platform  = "platform";
  token directive.optimize  = "optimize";
  token directive.subsystem = "subsystem";
}
```

**Conditional compilation flags** tell the lexer to handle the directive at lex time, enabling `@ifdef`/`@endif` blocks to include or exclude source code before parsing:

| Flag | Role | Description |
|------|------|-------------|
| `define` | `crDefine` | Define a symbol |
| `undef` | `crUndef` | Undefine a symbol |
| `ifdef` | `crIfDef` | Include block if symbol is defined |
| `ifndef` | `crIfNDef` | Include block if symbol is NOT defined |
| `elseif` | `crElseIf` | Else-if branch of conditional |
| `else` | `crElse` | Else branch of conditional |
| `endif` | `crEndIf` | End conditional block |

Directives without conditional flags are passed through to the parser as regular tokens. You handle them with grammar rules and semantic/emitter handlers.

### Structural Configuration

Key-value assignments in the `tokens {}` block configure the parser engine's behavior for your language. These settings adapt the lexer and parser to your language's conventions. If your language is case-insensitive like Pascal, set `casesensitive = false` - then `BEGIN`, `Begin`, and `begin` all match the `keyword.begin` token. If your language uses `$` for hex literals instead of `0x`, set `hex_prefix = "$";`. If your language uses braces instead of begin/end, set `block_open` and `block_close` to the appropriate delimiter token kinds.

```mor
tokens {
  // Case sensitivity for keyword matching (default: false)
  casesensitive = true;

  // Custom identifier character classes (override defaults)
  identifier_start = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
  identifier_part  = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789";

  // Statement terminator token kind
  terminator = delimiter.semicolon;

  // Block delimiters (token kinds, not text)
  block_open  = keyword.begin;
  block_close = keyword.end;

  // Number literal prefixes (can declare multiple)
  hex_prefix    = "0x";
  hex_prefix    = "0X";
  binary_prefix = "0b";
}
```

| Setting | API Call | Description |
|---------|----------|-------------|
| `casesensitive = true/false;` | `CaseSensitiveKeywords(bool)` | Keyword matching case sensitivity |
| `identifier_start = "chars";` | `IdentifierStart(chars)` | Characters that can start an identifier |
| `identifier_part = "chars";` | `IdentifierPart(chars)` | Characters that can continue an identifier |
| `terminator = kind;` | `SetStatementTerminator(kind)` | Statement terminator token kind |
| `block_open = kind;` | `SetBlockOpen(kind)` | Block-open token kind |
| `block_close = kind;` | `SetBlockClose(kind)` | Block-close token kind |
| `directive_prefix = "text";` | `SetDirectivePrefix(text, "")` | Directive prefix character(s) |
| `hex_prefix = "text";` | `SetHexPrefix(text, "literal.hex")` | Hex literal prefix |
| `binary_prefix = "text";` | `SetBinaryPrefix(text, "literal.binary")` | Binary literal prefix |

### Number Literal Prefixes

Number literal prefixes let the lexer recognize hex and binary integer literals in your source code. When you declare a prefix, the engine automatically creates the corresponding token kind (`literal.hex` or `literal.binary`). You can declare multiple prefixes for the same kind if your language accepts both `0x` and `0X`, for example.

```mor
tokens {
  hex_prefix    = "0x";
  hex_prefix    = "0X";
  binary_prefix = "0b";
  binary_prefix = "0B";
}
```

After the tokens block is processed, the engine calls `RegisterLiteralPrefixes()` to set up prefix handlers for all registered literal kinds (integer, real, hex, binary, string, char). This is automatic - language definitions do not need to handle it.

### Token Flags Summary

Flags appear inside `[...]` after the pattern string. Multiple flags are comma-separated.

| Flag | Applies To | Description |
|------|-----------|-------------|
| `noescape` | `string.*` | Disable backslash escape processing |
| `close "X"` | `string.*` | Use different closing delimiter |
| `define` | `directive.*` | Conditional compilation: `@define` |
| `undef` | `directive.*` | Conditional compilation: `@undef` |
| `ifdef` | `directive.*` | Conditional compilation: `@ifdef` |
| `ifndef` | `directive.*` | Conditional compilation: `@ifndef` |
| `elseif` | `directive.*` | Conditional compilation: `@elseif` |
| `else` | `directive.*` | Conditional compilation: `@else` |
| `endif` | `directive.*` | Conditional compilation: `@endif` |

### Complete Tokens Example (from pascal.mor)

```mor
tokens {
  token keyword.program   = "program";
  token keyword.begin     = "begin";
  token keyword.end       = "end";
  token keyword.var       = "var";
  token keyword.const     = "const";
  token keyword.function  = "function";
  token keyword.procedure = "procedure";
  token keyword.if        = "if";
  token keyword.then      = "then";
  token keyword.else      = "else";
  token keyword.while     = "while";
  token keyword.do        = "do";
  token keyword.for       = "for";
  token keyword.to        = "to";
  token keyword.downto    = "downto";
  token keyword.repeat    = "repeat";
  token keyword.until     = "until";
  token keyword.writeln   = "writeln";
  token keyword.not       = "not";
  token keyword.and       = "and";
  token keyword.or        = "or";
  token keyword.div       = "div";
  token keyword.mod       = "mod";
  token keyword.true      = "true";
  token keyword.false     = "false";
  token keyword.nil       = "nil";
  token keyword.write     = "write";
  token keyword.unit      = "unit";
  token keyword.uses      = "uses";
  token op.assign         = ":=";
  token op.neq            = "<>";
  token op.lte            = "<=";
  token op.gte            = ">=";
  token op.plus           = "+";
  token op.minus          = "-";
  token op.star           = "*";
  token op.slash          = "/";
  token op.eq             = "=";
  token op.lt             = "<";
  token op.gt             = ">";
  token delimiter.lparen    = "(";
  token delimiter.rparen    = ")";
  token delimiter.lbracket  = "[";
  token delimiter.rbracket  = "]";
  token delimiter.comma     = ",";
  token delimiter.colon     = ":";
  token delimiter.semicolon = ";";
  token delimiter.dot       = ".";
  token comment.line        = "//";
  token comment.block_open  = "/*";
  token comment.block_close = "*/";
  token string.cstring      = "\"";
  directive_prefix = "@";
  token directive.platform  = "platform";
  token directive.optimize  = "optimize";
  token directive.subsystem = "subsystem";
}
```

With your tokens defined, Metamorf's lexer can break any source file in your language into a stream of typed tokens. Next, the types block tells the engine how to connect your language's type names to the type system and to C++ output types.


## 🧩 Types Block

The `types {}` block connects three worlds: your language's type names (what the user writes in source code), Metamorf's internal type kinds (how the engine tracks and compares types), and C++ types (what gets generated in the output). When a user writes `var x: integer;`, the types block is what tells the engine that `integer` maps to the internal kind `type.int32`, and that `type.int32` maps to the C++ type `int32_t`.

### Type Keywords

Type keywords are the type names that users write in your language's source code. Each entry maps a type text to a type kind string. The engine uses these for type resolution during semantic analysis - when it encounters a type annotation, it calls `TypeTextToKind()` to find the internal kind.

```mor
types {
  type int8     = "type.int8";
  type int16    = "type.int16";
  type int32    = "type.int32";
  type int64    = "type.int64";
  type uint8    = "type.uint8";
  type uint16   = "type.uint16";
  type uint32   = "type.uint32";
  type uint64   = "type.uint64";
  type float32  = "type.float32";
  type float64  = "type.float64";
  type boolean  = "type.boolean";
  type char     = "type.char";
  type wchar    = "type.wchar";
  type string   = "type.string";
  type wstring  = "type.wstring";
  type pointer  = "type.pointer";
}
```

**API:** `AddTypeKeyword(text, typeKind)` registers the text as a type keyword that resolves to the given type kind string via `TypeTextToKind()`.

### Type Mappings

Type mappings close the loop from internal type kinds to C++ output types. When the code generator needs to emit a C++ type declaration, it calls `TypeToIR()` to convert the internal kind to a C++ type string. The three-layer flow is: `integer` (source text) -> `type.int32` (internal kind via type keywords) -> `int32_t` (C++ output via type mappings).

```mor
types {
  map "type.int8"    -> "int8_t";
  map "type.int16"   -> "int16_t";
  map "type.int32"   -> "int32_t";
  map "type.int64"   -> "int64_t";
  map "type.uint8"   -> "uint8_t";
  map "type.uint16"  -> "uint16_t";
  map "type.uint32"  -> "uint32_t";
  map "type.uint64"  -> "uint64_t";
  map "type.float32" -> "float";
  map "type.float64" -> "double";
  map "type.boolean" -> "bool";
  map "type.char"    -> "char";
  map "type.wchar"   -> "wchar_t";
  map "type.string"  -> "std::string";
  map "type.wstring" -> "std::wstring";
  map "type.pointer" -> "void*";
}
```

**API:** `AddTypeMapping(sourceKind, targetCpp)`.

### Literal Type Mappings

When the semantic engine encounters a literal value like `42` or `"hello"`, it needs to know what type that literal represents. Literal type mappings connect AST node kinds (what the parser produces) to type kinds (what the type system understands). Without these, the engine cannot infer types for expressions that contain literals.

```mor
types {
  literal "expr.integer" = "type.int32";
  literal "expr.float"   = "type.float64";
  literal "expr.string"  = "type.string";
  literal "expr.cstring" = "type.cstring";
  literal "expr.wstring" = "type.wstring";
  literal "expr.bool"    = "type.boolean";
}
```

**API:** `AddLiteralType(nodeKind, typeKind)`.

### Type Compatibility

When a user writes `myInt + myFloat`, the engine needs to know whether these types can be combined and what the result type should be. Compatibility rules define type widening and coercion. Each `compatible` entry specifies a source type, target type, and the resulting coercion type. The engine uses a callback that checks exact match first, then iterates registered pairs in both directions.

```mor
types {
  // Integer widening
  compatible "type.int8",  "type.int16" -> "type.int16";
  compatible "type.int8",  "type.int32" -> "type.int32";
  compatible "type.int8",  "type.int64" -> "type.int64";
  compatible "type.int16", "type.int32" -> "type.int32";
  compatible "type.int16", "type.int64" -> "type.int64";
  compatible "type.int32", "type.int64" -> "type.int64";

  // Float widening
  compatible "type.float32", "type.float64" -> "type.float64";

  // Integer to float promotion
  compatible "type.int32", "type.float64" -> "type.float64";
}
```

When the `->` coerce_to is omitted, it defaults to the target type:

```mor
types {
  compatible "type.int8", "type.int16";  // coerces to type.int16
}
```

**API:** `RegisterTypeCompat(callback)` - the interpreter collects all pairs and registers a single callback that checks them.

### Declaration and Call Kinds

The semantic engine needs to know which AST node kinds represent declarations and which represent calls, so it can perform overload resolution and forward reference checking. Without these registrations, the engine cannot distinguish a variable declaration from a function call in the AST.

```mor
types {
  decl_kind "stmt.var_decl";
  call_kind "expr.call";
  call_name_attr = "call.name";
}
```

| Entry | API | Description |
|-------|-----|-------------|
| `decl_kind "kind";` | `AddDeclKind(kind)` | Register a declaration node kind |
| `call_kind "kind";` | `AddCallKind(kind)` | Register a call node kind |
| `call_name_attr = "attr";` | `SetCallNameAttr(attr)` | Attribute name holding callee name on call nodes |
| `name_mangler = funcRef;` | `SetNameMangler(func)` | Custom name mangling function |



## 📐 Grammar Block

The `grammar {}` block defines how your language's token stream is parsed into an AST (abstract syntax tree). Metamorf uses a Pratt parser - a top-down technique where each token can trigger a **prefix** handler (at the start of an expression) or an **infix** handler (between two expressions). If you have never used a Pratt parser, think of it this way: prefix rules say "I start something" and infix rules say "I connect two things." Statement rules are a third category - they fire when their trigger token appears at statement position and do not participate in expression precedence.

The interpreter walks the grammar block and registers each rule as a closure on `TMetamorf.Config()`. The rule's trigger token(s) are inferred from the first `expect` or `consume` statement in the rule body - you do not need to declare them separately.

### Rule Kind Routing

The node kind prefix determines how the rule is registered:

| Prefix | Registration | Trigger |
|--------|-------------|---------|
| `expr.*` (no precedence) | `RegisterPrefix` | First `expect`/`consume` token |
| `expr.*` + `precedence left N` | `RegisterInfixLeft` | First `expect`/`consume` token |
| `expr.*` + `precedence right N` | `RegisterInfixRight` | First `expect`/`consume` token |
| `stmt.*` | `RegisterStatement` | First `expect`/`consume` token, or `identifier` if none found |

### Prefix Rules

A prefix rule fires when the parser sees a matching token at expression-start position - the beginning of an expression, after an operator, or after an opening parenthesis. It has no `precedence` clause. Prefix rules handle literals, identifiers, unary operators, and grouped expressions.

```mor
grammar {
  // Simple literal: consume token, capture its text
  rule expr.ident {
    consume identifier -> @name;
  }

  // String literal
  rule expr.cstring {
    consume string.cstring -> @value;
  }

  // Keyword literals (no attribute capture needed)
  rule expr.bool_true {
    expect keyword.true;
  }

  rule expr.bool_false {
    expect keyword.false;
  }

  rule expr.nil {
    expect keyword.nil;
  }

  // Grouped expression with sub-expression parsing
  rule expr.grouped {
    expect delimiter.lparen;
    parse expr -> @inner;
    expect delimiter.rparen;
  }

  // Unary operators
  rule expr.negate {
    expect op.minus;
    parse expr -> @operand;
  }

  rule expr.not {
    expect keyword.not;
    parse expr -> @operand;
  }
}
```

The trigger token is the first `expect` or `consume` target. For `expr.ident`, the trigger is `identifier`. For `expr.negate`, the trigger is `op.minus`.

### Infix Rules

An infix rule fires when the trigger token appears after an already-parsed left expression. The left operand is available implicitly as child 0 of the result node. You specify `precedence left N` or `precedence right N` to control associativity and binding power.

Binding power determines how tightly an operator holds its operands. When the parser sees `2 + 3 * 4`, the multiplication rule (power 30) binds tighter than addition (power 20), so it groups as `2 + (3 * 4)`. Right-associative means `a = b = c` groups as `a = (b = c)` - the right side binds first.

```mor
grammar {
  // Standard binary operators
  rule expr.add precedence left 20 {
    consume [op.plus, op.minus] -> @operator;
    parse expr -> @right;
  }

  rule expr.mul precedence left 30 {
    consume [op.star, op.slash] -> @operator;
    parse expr -> @right;
  }

  rule expr.compare precedence left 10 {
    consume [op.eq, op.neq, op.lt, op.gt, op.lte, op.gte] -> @operator;
    parse expr -> @right;
  }

  // Keyword binary operators
  rule expr.div_mod precedence left 30 {
    consume [keyword.div, keyword.mod] -> @operator;
    parse expr -> @right;
  }

  rule expr.and precedence left 5 {
    expect keyword.and;
    parse expr -> @right;
  }

  rule expr.or precedence left 3 {
    expect keyword.or;
    parse expr -> @right;
  }

  // Function call (high precedence)
  rule expr.call precedence left 80 {
    expect delimiter.lparen;
    let nd = getResultNode();
    if not checkToken("delimiter.rparen") {
      addChild(nd, parseExpr(0));
      while matchToken("delimiter.comma") {
        addChild(nd, parseExpr(0));
      }
    }
    expect delimiter.rparen;
  }
}
```

### Conventional Binding Power Scale

The following table shows the conventional binding power values used in pascal.mor. These are not mandatory - you can use any positive integers you want - but following this scale makes your grammar easier for others to read and keeps consistent spacing between levels for future additions.

| Power | Category |
|-------|----------|
| 2 | Assignment (right-associative) |
| 3 | Logical OR |
| 5 | Logical AND |
| 8 | Bitwise XOR |
| 10 | Comparison (`=`, `<>`, `<`, `>`, `<=`, `>=`) |
| 20 | Addition/subtraction |
| 25 | Bitwise shift (`shl`, `shr`) |
| 30 | Multiplication/division/modulo |
| 35 | Unary prefix (not, minus, address-of) |
| 40-45 | Call, index, field access |
| 50 | Dereference |
| 80 | Call (common convention for tightest infix) |

### Statement Rules

Statement rules are fundamentally different from expression rules. They do not participate in precedence - they fire when their trigger token appears at statement position (the start of a line or after a statement terminator). Statement rules handle language constructs like `if`, `while`, `for`, variable declarations, and function definitions - things that are structurally different from expressions.

```mor
grammar {
  // Simple: keyword + value + terminator
  rule stmt.program {
    expect keyword.program;
    consume identifier -> @name;
    expect delimiter.semicolon;
  }

  // Block with body
  rule stmt.while {
    expect keyword.while;
    parse expr -> @condition;
    expect keyword.do;
    parse many stmt until keyword.end -> @body;
    expect keyword.end;
  }

  // If/else with optional branch
  rule stmt.if {
    expect keyword.if;
    parse expr -> @condition;
    expect keyword.then;
    parse many stmt until [keyword.else, keyword.end] -> @then_body;
    optional {
      expect keyword.else;
      parse many stmt until keyword.end -> @else_body;
    }
    expect keyword.end;
  }

  // For loop with direction
  rule stmt.for {
    expect keyword.for;
    consume identifier -> @var;
    expect op.assign;
    parse expr -> @start;
    consume [keyword.to, keyword.downto] -> @dir;
    parse expr -> @finish;
    expect keyword.do;
    parse many stmt until keyword.end -> @body;
    expect keyword.end;
  }

  // Repeat/until
  rule stmt.repeat {
    expect keyword.repeat;
    parse many stmt until keyword.until -> @body;
    expect keyword.until;
    parse expr -> @condition;
    expect delimiter.semicolon;
  }

  // Directive statements
  rule stmt.directive_platform {
    expect directive.platform;
    consume identifier -> @value;
  }
}
```

### Grammar Declarative Reference

The grammar declarative constructs are deliberately small. Five verbs - `expect`, `consume`, `parse`, `optional`, and `sync` - cover most parsing needs. Here is the complete reference:

| Syntax | Description |
|--------|-------------|
| `expect TOKEN_KIND;` | Assert current token matches kind, consume it. Error if mismatch. |
| `consume TOKEN_KIND -> @attr;` | Consume token, store its text as attribute `attr` on result node. |
| `consume [K1, K2, ...] -> @attr;` | Consume if current token is any of listed kinds, store text. |
| `consume identifier -> @attr;` | Special: consume an identifier token, store text. |
| `parse expr -> @attr;` | Parse a sub-expression (power 0), add as child named `attr`. |
| `parse many stmt until KIND -> @attr;` | Parse statements until `KIND`, collect into block child `attr`. |
| `parse many stmt until [K1, K2] -> @attr;` | Parse until any of the listed kinds. |
| `optional { ... }` | Execute block only if the next token allows it. |
| `sync TOKEN_KIND;` | Declare error recovery point. On parse failure, skip to this token and continue. |

The `parse many ... until` construct loops, parsing sub-expressions or sub-statements until a terminating token is seen. The terminating token is NOT consumed - the caller is responsible for consuming it with `expect`. The `until` clause accepts a single token kind or a bracketed list.

### How Declarative Constructs Map to the Engine

- `expect K;` calls `AParser.Expect('K')`
- `consume K -> @attr;` consumes the token and calls `SetAttr(attr, token.Text)`
- `parse expr -> @attr;` calls `AParser.ParseExpression(0)` and adds the result as a child
- `parse many stmt until K -> @attr;` loops `ParseStatement()` until `Check('K')`

### Declarative and Imperative Constructs

Grammar rule bodies use two sets of constructs from the same language. Declarative constructs (`expect`, `consume`, `parse`) handle regular structure concisely. Imperative constructs (`checkToken`, `advance`, `createNode`, `addChild`, `while`, `if`) handle irregular structure with full control. Both are first-class — neither is primary and neither is a fallback. The `stmt.var_decl` example below uses both naturally: it starts with `expect keyword.var;` and then uses token-by-token parsing with `checkToken`, `advance`, `createNode`, and `addChild` for the irregular variable list. Most real languages mix both freely for constructs like variable declaration blocks, function parameter lists, and import statements.

```mor
grammar {
  // Declarative constructs for simple rules
  rule expr.nil {
    expect keyword.nil;
  }

  // Imperative constructs for complex manual parsing
  rule stmt.var_decl {
    expect keyword.var;
    let nd = getResultNode();
    let more = true;
    while more {
      if not checkToken("identifier") { more = false; }
      if checkToken("keyword.begin") { more = false; }
      if checkToken("keyword.end") { more = false; }

      if more {
        let v = createNode("stmt.single_var");
        setAttr(v, "vname", currentText());
        advance();
        requireToken("delimiter.colon");
        setAttr(v, "vtype", currentText());
        advance();
        if checkToken("op.assign") {
          advance();
          let init = parseExpr(0);
          addChild(v, init);
        }
        requireToken("delimiter.semicolon");
        addChild(nd, v);
      }
    }
  }

  // Function call with manual argument parsing
  rule expr.call precedence left 80 {
    expect delimiter.lparen;
    let nd = getResultNode();
    if not checkToken("delimiter.rparen") {
      addChild(nd, parseExpr(0));
      while matchToken("delimiter.comma") {
        addChild(nd, parseExpr(0));
      }
    }
    expect delimiter.rparen;
  }

  // Function declaration with manual parameter parsing
  rule stmt.func_decl {
    expect keyword.function;
    consume identifier -> @func_name;
    expect delimiter.lparen;
    let nd = getResultNode();
    while not checkToken("delimiter.rparen") {
      let p = createNode("stmt.param");
      setAttr(p, "param.name", currentText());
      advance();
      requireToken("delimiter.colon");
      setAttr(p, "param.type_text", currentText());
      advance();
      addChild(nd, p);
      matchToken("delimiter.comma");
    }
    expect delimiter.rparen;
    expect delimiter.colon;
    consume identifier -> @return_type;
    expect delimiter.semicolon;
    parse many stmt until keyword.end -> @func_body;
    expect keyword.end;
  }
}
```

### Error Recovery (sync)

Without sync points, one parse error cascades into dozens of false errors as the parser tries to make sense of the remaining tokens from a confused position. With `sync`, the parser skips to the next occurrence of the sync token and continues, giving your users useful multi-error feedback instead of one real error followed by pages of noise.

```mor
grammar {
  rule stmt.var_decl {
    expect keyword.var;
    consume identifier -> @name;
    expect delimiter.colon;
    consume identifier -> @type_name;
    expect delimiter.semicolon;
    sync delimiter.semicolon;
  }
}
```

At this point, Metamorf has an AST - a tree of typed nodes with attributes. The grammar block told the parser how to build that tree. The semantics block walks this tree to check that the program makes sense: does every variable have a declaration? Does every function call match a defined function? Are the types compatible?


## 🧠 Semantics Block

The `semantics {}` block answers the question: is this syntactically valid program also meaningful? A program can parse correctly and still be nonsense - a call to a function that does not exist, a variable used before it is declared, or an assignment of a string to an integer. Semantic handlers walk the AST, manage scopes, declare and look up symbols, and report errors when the program violates the language's rules.

### Basic Handlers

Each `on` handler fires when a node of the matching kind is visited during semantic analysis. The most common operations are pushing/popping scopes, declaring symbols, and visiting children to continue the walk.

```mor
semantics {
  // Scope management: push a named scope, visit children, pop scope
  on program.root {
    scope "global" {
      visit children;
    }
  }

  // Symbol declaration and scoping for routines
  on stmt.func_decl {
    declare @func_name as routine;
    scope @func_name {
      visit children;
    }
  }

  // Simple visit-through (ensure children are walked)
  on stmt.var_decl {
    visit children;
  }

  // Variable declaration
  on stmt.single_var {
    declare @vname as variable;
    visit children;
  }

  // No-op handler (prevents auto-visit, explicit empty)
  on stmt.directive_platform { }

  // Module compilation trigger
  on stmt.uses {
    setModuleExtension("pas");
    visit children;
  }

  on stmt.uses_item {
    compileModule(getAttr(node, "unit.name"));
  }

  // Expression handlers
  on expr.call { visit children; }
  on expr.ident { }
}
```

### Semantics Declarative Reference

Scopes work like nested boxes. `scope "global"` opens the outermost box. `scope @func_name` opens a box inside it, named after the function. Symbols declared in an inner box are visible there and in deeper boxes, but not in outer ones. When the scope block ends, the box closes and its local symbols become invisible to subsequent code at the outer level.

The `visit` statement controls which children the engine walks. Use `visit children` when you want the engine to walk all children automatically. Use `visit @attr` when you need to control which specific child gets visited. If a node kind has no semantic handler at all, its children are auto-visited by default - but once you register a handler, you take control of the walk and must explicitly visit children or they will be skipped.

| Syntax | Description |
|--------|-------------|
| `scope "name" { ... }` | Push named scope, execute body, pop scope |
| `scope @attr { ... }` | Push scope named by attribute value on current node |
| `declare @attr as variable;` | Declare symbol from attribute as a variable |
| `declare @attr as routine;` | Declare symbol from attribute as a routine |
| `declare @attr as type;` | Declare symbol from attribute as a type |
| `declare @attr as constant;` | Declare symbol from attribute as a constant |
| `declare @attr as parameter;` | Declare symbol from attribute as a parameter |
| `visit children;` | Visit all children of current node |
| `visit @attr;` | Visit the child stored in the named attribute |
| `visit child[N];` | Visit child at index N |

### Rich Symbol Declarations

The `declare` statement supports optional `typed` and `where` clauses for attaching metadata to a symbol. This is useful when your language needs to track more than a name and a category - for example, a variable's type, visibility, or mutability.

```mor
semantics {
  on stmt.var_decl {
    declare @name as variable typed @type_name where {
      visibility = @visibility;
      mutable = not @is_const;
    };
    visit children;
  }
}
```

### Lookup Statement

The `lookup` statement retrieves a previously declared symbol from the scope tree. It searches from the current scope outward through parent scopes. It comes in two forms - one for when you need the symbol object, and one for when you need to handle the "not found" case.

**Binding form** - binds the found symbol to a variable:

```mor
semantics {
  on expr.ident {
    lookup @name -> let sym;
    if sym != nil {
      let symType = getAttr(sym, "type_name");
    }
  }
}
```

**Error form** - executes a block when lookup fails:

```mor
semantics {
  on expr.ident {
    lookup @name or {
      error "undefined identifier '{@name}'";
    };
  }
}
```

### Imperative Constructs in Semantic Handlers

When declarative constructs are insufficient, `on` handlers can use full imperative logic with semantic-context builtins. This is common for overload detection and complex symbol management. The example below shows how pascal.mor might handle routine declarations with overloaded signatures - building a signature string from parameter types and using `symbolExistsWithPrefix` to detect overloads.

```mor
semantics {
  on stmt.routine_decl {
    let name = getAttr(node, "decl.name");

    // Build overload signature
    let sig = name + "(";
    let first = true;
    let i = 0;
    while i < child_count() {
      let ch = getChild(node, i);
      if nodeKind(ch) == "stmt.param_decl" {
        if not first { sig = sig + ","; }
        sig = sig + getAttr(ch, "param.type_text");
        first = false;
      }
      i = i + 1;
    }
    sig = sig + ")";

    // Overload detection
    if symbolExistsWithPrefix(name + "(") {
      demoteCLinkageForPrefix(name + "(");
    }

    // Declare with signature key
    declare sig as routine;
    scope name {
      visit children;
    }
  }
}
```

### Multi-Pass Semantics

Without multi-pass, every identifier must be declared before its first use - no forward references. With two passes, pass 1 walks the entire AST registering declarations, and pass 2 walks it again resolving references. The key insight is that the scope tree persists between passes - symbols declared in pass 1 are visible to pass 2 lookups - but the scope stack resets to the root between passes so each pass starts traversal from global scope.

For languages requiring forward declarations before usage, use `pass` blocks:

```mor
semantics {
  pass 1 "declarations" {
    on stmt.routine_decl {
      declare @name as routine;
    }
    on stmt.var_decl {
      visit children;
    }
    on stmt.single_var {
      declare @vname as variable;
    }
  }

  pass 2 "analysis" {
    on stmt.routine_decl {
      scope @name {
        visit children;
      }
    }
    on expr.ident {
      lookup @name or {
        error "undefined identifier '{@name}'";
      };
    }
    on expr.call {
      visit children;
    }
  }
}
```

Each pass walks the full AST with only that pass's handlers active. The scope tree persists across passes - symbols declared in pass 1 are visible to pass 2 lookups. The scope stack resets to the root between passes so each pass starts traversal from global scope. If a node kind has no handler in the current pass, its children are auto-visited.

With semantic analysis complete, the AST has been validated - every symbol is declared, every reference resolves, and the types are consistent. The emitters block walks this validated AST one more time to produce C++23 output.


## 🔨 Emitters Block

The `emitters {}` block is where Metamorf produces output. Each `on` handler fires during code generation when a node of the matching kind is walked. There are two fundamentally different kinds of emitter handlers: **statement emitters** call IR builder procedures (`func()`, `declVar()`, `ifStmt()`) to produce C++ statements, and **expression emitters** produce C++ expression strings that can be composed recursively via `exprToString()`.

### Statement Emitters

Statement emitters are the workhorses of code generation. They call IR builder functions to produce structured C++23 output - function definitions, variable declarations, control flow statements. The IR builders handle indentation, braces, and formatting automatically, so you describe the structure rather than concatenating strings.

```mor
emitters {
  on stmt.program {
    setBuildMode("exe");
  }

  on stmt.directive_platform {
    setPlatform(getAttr(node, "value"));
  }

  on stmt.directive_optimize {
    setOptimize(getAttr(node, "value"));
  }

  on stmt.directive_subsystem {
    setSubsystem(getAttr(node, "value"));
  }

  on stmt.var_decl {
    let i = 0;
    let n = child_count();
    while i < n {
      let v = getChild(node, i);
      let ctype = resolveType(getAttr(v, "vtype"));
      let vname = getAttr(v, "vname");
      if childCount(v) > 0 {
        declVar(vname, ctype, exprToString(getChild(v, 0)));
      } else {
        declVar(vname, ctype);
      }
      i = i + 1;
    }
  }

  on stmt.if {
    let cond = exprToString(getChild(node, 0));
    ifStmt(cond);
    emitBlock(getChild(node, 1));
    if child_count() > 2 {
      elseStmt();
      emitBlock(getChild(node, 2));
    }
    endIf();
  }

  on stmt.while {
    let cond = exprToString(getChild(node, 0));
    whileStmt(cond);
    emitBlock(getChild(node, 1));
    endWhile();
  }

  on stmt.for {
    let varName = getAttr(node, "var");
    let startExpr = exprToString(getChild(node, 0));
    let finishExpr = exprToString(getChild(node, 1));
    let dir = getAttr(node, "dir");
    if dir == "to" {
      forStmt(varName, startExpr, varName + " <= " + finishExpr, varName + "++");
    } else {
      forStmt(varName, startExpr, varName + " >= " + finishExpr, varName + "--");
    }
    emitBlock(getChild(node, 2));
    endFor();
  }

  on stmt.repeat {
    emitLine("do {");
    indentIn();
    emitBlock(getChild(node, 0));
    indentOut();
    let cond = exprToString(getChild(node, 1));
    emitLine("} while (!(" + cond + "));");
  }

  on stmt.ident_stmt {
    if getAttr(node, "is_assign") == "true" {
      let target = exprToString(getChild(node, 0));
      let val = exprToString(getChild(node, 1));
      assign(target, val);
    } else {
      stmt(exprToString(getChild(node, 0)) + ";");
    }
  }
}
```

### Expression Emitters

Expression emitters produce C++ expression text rather than complete statements. They work through the `exprToString()` function - when you call `exprToString(someNode)`, the engine runs the emitter handler for that node's kind in string-capture mode and returns the accumulated text. This is how expression emitters compose recursively: the emitter for `expr.add` calls `exprToString()` on its left and right children, which in turn run their own emitters.

```mor
emitters {
  on expr.ident {
    emit @name;
  }

  on expr.cstring {
    emit @value;
  }

  on expr.bool_true {
    emit "true";
  }

  on expr.bool_false {
    emit "false";
  }

  on expr.nil {
    emit "nullptr";
  }

  on expr.call {
    let fname = exprToString(getChild(node, 0));
    let args = "";
    let i = 1;
    while i < child_count() {
      if i > 1 { args = args + ", "; }
      args = args + exprToString(getChild(node, i));
      i = i + 1;
    }
    emit fname + "(" + args + ")";
  }

  on expr.grouped {
    emit "(" + exprToString(getChild(node, 0)) + ")";
  }

  on expr.negate {
    emit "-" + exprToString(getChild(node, 0));
  }

  on expr.not {
    emit "!(" + exprToString(getChild(node, 0)) + ")";
  }

  on expr.compare {
    let lhs = exprToString(getChild(node, 0));
    let rhs = exprToString(getChild(node, 1));
    let op = getAttr(node, "operator");
    if op == "=" {
      emit lhs + " == " + rhs;
    } else {
      if op == "<>" {
        emit lhs + " != " + rhs;
      } else {
        emit lhs + " " + op + " " + rhs;
      }
    }
  }

  on expr.and {
    emit exprToString(getChild(node, 0)) + " && " + exprToString(getChild(node, 1));
  }

  on expr.or {
    emit exprToString(getChild(node, 0)) + " || " + exprToString(getChild(node, 1));
  }
}
```

The `emit` keyword in emitter context appends text to the current output buffer. In string-capture mode (via `exprToString()`), it appends to the capture buffer instead of the IR output.

### The `emit` Statement

The `emit` keyword is the core output primitive in emitter handlers. In statement context, `emit` appends text to the current output section. In expression context (inside a handler invoked by `exprToString()`), it appends to a capture buffer that becomes the return value. This dual behavior is what allows expression emitters to compose - each one uses `emit` to build its piece of the expression string, and the caller receives the assembled result.

- `emit "text";` - emit text to the current/default section
- `emit @attr;` - emit the value of an attribute from the current node
- `emit to header: "text";` - emit to a named section
- `emit to body: "int {@name} = {@value};";` - with inline attribute interpolation

### Multi-Pass Emission

Most real languages cannot emit code in a single top-to-bottom pass. Forward declarations, includes, and function definitions need to appear in the right order in the C++ output, even if they appear in a different order in the source. The typical pattern is for the `program.root` emitter to walk its children multiple times, emitting different node kinds in each pass. The example below from pascal.mor shows this: pass 0 handles directives and declarations, pass 1 emits functions and procedures, and pass 2 wraps global variables and the main block inside `main()`.

```mor
emitters {
  on program.root {
    // Language-required headers
    emitLine("#include <cstdint>");
    emitLine("#include <print>");

    let isUnit = false;
    let i = 0;
    let n = child_count();

    // Detect unit mode
    while i < n {
      let ch = getChild(node, i);
      if nodeKind(ch) == "stmt.unit" { isUnit = true; }
      i = i + 1;
    }

    // Pass 0: directives, preprocessor, program/unit declaration, uses
    i = 0;
    while i < n {
      let ch = getChild(node, i);
      if nodeKind(ch) == "stmt.directive_platform"  { emitNode(ch); }
      if nodeKind(ch) == "stmt.directive_optimize"   { emitNode(ch); }
      if nodeKind(ch) == "stmt.directive_subsystem"  { emitNode(ch); }
      if nodeKind(ch) == "stmt.preprocessor"         { emitNode(ch); }
      if nodeKind(ch) == "stmt.program"              { emitNode(ch); }
      if nodeKind(ch) == "stmt.unit"                 { emitNode(ch); }
      if nodeKind(ch) == "stmt.uses"                 { emitNode(ch); }
      i = i + 1;
    }

    // Pass 1: functions and procedures
    i = 0;
    while i < n {
      let ch = getChild(node, i);
      if nodeKind(ch) == "stmt.func_decl" { emitNode(ch); }
      if nodeKind(ch) == "stmt.proc_decl" { emitNode(ch); }
      i = i + 1;
    }

    // Pass 2: main (program mode only)
    if not isUnit {
      func("main", "int");
      i = 0;
      while i < n {
        let ch = getChild(node, i);
        if nodeKind(ch) == "stmt.var_decl" { emitNode(ch); }
        i = i + 1;
      }
      i = 0;
      while i < n {
        let ch = getChild(node, i);
        if nodeKind(ch) == "stmt.main_block" { emitChildren(ch); }
        i = i + 1;
      }
      returnVal("0");
      endFunc();
    }
  }
}
```

### Header vs Source Emission

When compiling a unit or module (not a program), you often need both a `.h` and a `.cpp` file. By default, `emitLine()` writes to the source file. Pass `"header"` as a second argument to write to the generated header file instead. This keeps your emitters straightforward - the same handler can emit to both files without needing separate passes.

```mor
emitters {
  on stmt.unit {
    setBuildMode("lib");
    emitLine("#pragma once", "header");
    emitLine("#include <cstdint>", "header");
  }

  on stmt.uses {
    let i = 0;
    let n = child_count();
    while i < n {
      let ch = getChild(node, i);
      let uname = getAttr(ch, "unit.name");
      emitLine("#include \"" + uname + ".h\"");
      i = i + 1;
    }
  }
}
```

### Named Sections

For more fine-grained control over output organization, emitters can declare named output sections. Each section accumulates its own output independently, and sections are emitted in the order they were declared. The `emit to target:` syntax directs output to a named section. Without a `to` clause, `emit` writes to the default (source) section.

```mor
emitters {
  section header indent "  ";
  section body indent "  ";

  on program.root {
    emit to header: "#include <cstdint>";
    emit to body: "int main() {";
    indent {
      visit children;
      emit to body: "return 0;";
    }
    emit to body: "}";
  }
}
```

The `emit to target:` syntax directs output to a named section. Without a `to` clause, `emit` writes to the default (source) section.

### Before/After Blocks

If every compiled file needs the same boilerplate - standard includes, pragmas, a copyright comment - use `before` and `after` blocks. The `before` block runs before the first node is emitted, and `after` runs after the last. This keeps boilerplate out of your per-node handlers.

```mor
emitters {
  before {
    emitLine("// Auto-generated by Metamorf");
    include("<cstdint>");
    blankLine();
  }

  after {
    emitLine("// End of generated code");
  }

  on stmt.var_decl { ... }
}
```

### Indent Blocks

The `indent { }` block increases indentation for all emission within, then restores it when the block ends. This is equivalent to calling `indentIn()` / `indentOut()` manually, but with guaranteed cleanup - if an error occurs inside the block, the indentation level is still restored.

```mor
emitters {
  on stmt.if {
    emitLine("if (" + exprToString(getChild(node, 0)) + ") {");
    indent {
      emitChildren(getChild(node, 1));
    }
    emitLine("}");
  }
}
```



## 💡 The Imperative Language

The `.mor` language is Turing complete. Every handler body — grammar rules, semantic handlers, emitters — has access to variables, unbounded loops, conditionals, recursion, and string/arithmetic operations as first-class constructs. These are not a separate scripting layer bolted onto a declarative core; they are part of one unified language. When your grammar rule needs custom parsing logic, or your emitter needs 100 lines of conditional code generation, you write it in the same language as everything else. No escape hatch to a host language, no build system integration, no glue code. A `.mor` file is self-contained.

### Why Turing Complete Matters

Most language definition tools are deliberately not Turing complete - they give you a declarative grammar and then punt to a host language (C, Java, Python) for anything complex. The `.mor` language has variables, unbounded loops, conditionals, recursion, and string/arithmetic operations as first-class constructs alongside its declarative grammar rules. When your grammar rule needs custom parsing logic, or your emitter needs 100 lines of conditional code generation, you write it in the same language as everything else. No escape hatch to a host language, no build system integration, no glue code. A `.mor` file is self-contained.

### Variables and Assignment

Variables are declared with `let` and assigned with `=`. Variables are block-scoped - a `let` inside a `while` body is destroyed when the loop iteration ends. The interpreter uses a stack of scope frames, so inner blocks can shadow variables from outer blocks.

```mor
let x = 42;
let name = "hello";
let ok = true;
let n = createNode("my_node");
x = x + 1;
name = upper(name);
```

Variables are scoped to the enclosing block. The interpreter uses a stack of scope frames.

### Control Flow

**if / else if / else**

```mor
if x > 10 {
  emitLine("big");
} else if x > 5 {
  emitLine("medium");
} else {
  emitLine("small");
}
```

**while**

```mor
let i = 0;
while i < child_count() {
  emitNode(getChild(node, i));
  i = i + 1;
}
```

**for**

```mor
for i in child_count() {
  emitNode(getChild(node, i));
}
```

`for X in N` iterates from 0 to N-1. The loop variable is automatically declared. This is an integer range loop, not a collection iterator - to iterate children, use `while i < child_count()`.

**return**

```mor
routine max(a: int, b: int) -> int {
  if a > b { return a; }
  return b;
}
```

**match**

Pattern-based branching with `=>` syntax. Arms support `|` for alternatives. Patterns compare against literal values - string literals, integer literals, or boolean literals. You cannot match against variables or computed values. The `else` arm catches unmatched values. Match works in all handler contexts.

```mor
match getAttr(node, "kind") {
  "exe" => {
    setBuildMode("exe");
    setSubsystem("console");
  }
  "dll" | "lib" => {
    setBuildMode(getAttr(node, "kind"));
  }
  else => {
    error "unknown module kind";
  }
}
```

**guard**

The `guard` statement executes its body only if the condition is true. A lightweight alternative to `if` for simple conditional blocks.

```mor
emitters {
  on stmt.var_decl {
    guard getAttr(node, "has_init") == "true" {
      emit " = ";
      emitNode(getChild(node, 0));
    }
    emit ";";
  }
}
```

### Expressions and Operators

| Category | Operators |
|----------|-----------|
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Logical | `and`, `or`, `not` |
| String concatenation | `+` (overloaded) |
| Grouping | `(expr)` |
| Function call | `name(args)` |
| Attribute access | `@name` (on current node) |

All boolean operators short-circuit.

### Operator Precedence (`.mor` Expressions)

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 1 (highest) | `not`, `-` (unary) | Right |
| 2 | `*`, `/`, `%` | Left |
| 3 | `+`, `-` | Left |
| 4 | `==`, `!=`, `<`, `>`, `<=`, `>=` | Left |
| 5 | `and` | Left (short-circuit) |
| 6 (lowest) | `or` | Left (short-circuit) |

### Attribute Access

The `@name` syntax accesses attributes on the current result/context node.

**In grammar rules:** `@name` reads/writes attributes on the result node being constructed.

```mor
grammar {
  rule stmt.program {
    expect keyword.program;
    consume identifier -> @name;  // sets @name attribute
    expect delimiter.semicolon;
  }
}
```

**In emitter/semantic handlers:** `@name` reads attributes on the current `node`.

```mor
emitters {
  on stmt.program {
    // @name reads getAttr(node, "name")
    emitLine("// Program: " + @name);
  }
}
```

### String Interpolation

Strings in handler bodies support two forms of inline interpolation:

- `{@attr}` - reads an attribute from the current node and inserts its string value
- `{expr}` - evaluates an arbitrary expression and inserts its string value

Interpolation is available inside double-quoted strings in all handler contexts. Use `\{` to emit a literal `{` - forgetting this escape is a common source of confusion when your output contains braces (like C++ code).

```mor
emitters {
  on stmt.var_decl {
    emit "int64_t {@name} = {init_value};";
  }
}

semantics {
  on expr.ident {
    lookup @name or {
      error "undefined identifier '{@name}'";
    };
  }
}
```

Interpolation works in the same way inside `error`, `warning`, and other diagnostic messages.

### Triple-Quoted Strings

Triple-quoted strings use `'''` for multi-line text. Leading whitespace is trimmed to the minimum common indent. They do not process escape sequences - all content is literal.

```mor
emitters {
  on program.root {
    emit to header: '''
      #pragma once
      #include <cstdint>
      #include <string>
      #include <vector>
    ''';
  }
}
```

### Try/Recover

Graceful error handling in handler bodies. If any statement in `try` fails - a missing attribute, a nil node dereference, a failed `requireToken` inside a handler, or an out-of-bounds child access - execution jumps to `recover`. This prevents one malformed AST node from crashing your entire compilation.

```mor
emitters {
  on expr.binary {
    try {
      let lhs = exprToString(getChild(node, 0));
      let op = getAttr(node, "operator");
      let rhs = exprToString(getChild(node, 1));
      emit lhs + " " + op + " " + rhs;
    } recover {
      error "malformed binary expression";
      emit "/* ERROR */";
    }
  }
}
```

### Implicit Variables by Context

| Context | Variable | Type | Description |
|---------|----------|------|-------------|
| Grammar rule body | `node` | node | Result node (via `getResultNode()`) |
| Semantic handler | `node` | node | AST node being analyzed |
| Emitter handler | `node` | node | AST node being emitted |
| All contexts | `true`, `false` | bool | Boolean literals |
| All contexts | `nil` | nil | Null value |

### Diagnostics

Five severity levels available in semantic and emitter handlers:

| Builtin | Severity | Description |
|---------|----------|-------------|
| `error "message";` | Error | Compilation stops after semantic pass |
| `warning "message";` | Warning | Compilation continues |
| `hint "message";` | Hint | Suggestion for improvement |
| `note "message";` | Note | Informational attachment to previous diagnostic |
| `info "message";` | Info | General compiler information |

All diagnostics automatically carry source location from the current node. Interpolation is supported: `error "undefined '{@name}'";`



## 🔁 Routines and Constants

### User-Defined Routines

You will find yourself writing the same type resolution logic in multiple emitters, or the same child-walking pattern in several handlers. Routines let you write it once and call it from any grammar, semantic, or emitter handler. They are defined at the top level, outside any block.

```mor
routine resolveType(typeText: string) -> string {
  if typeText == "integer" { return "int64_t"; }
  if typeText == "string" { return "std::string"; }
  if typeText == "boolean" { return "bool"; }
  if typeText == "single" { return "float"; }
  if typeText == "double" { return "double"; }
  if typeText == "void" { return "void"; }
  return typeText;
}

routine emitBlock(blk: node) {
  let i = 0;
  while i < child_count(blk) {
    emitNode(getChild(blk, i));
    i = i + 1;
  }
}
```

**Syntax:**

```mor
routine name(param1: type, param2: type) -> returnType {
  // body
  return value;
}
```

**Parameter types:** `string`, `int`, `bool`, `node`, `list`.

**Return type:** If `-> type` is specified, the caller receives the return value. If omitted, the routine is void.

Routines are stored globally and callable from any handler context by name. When called from an emitter context, they inherit the emitter's IR builder (`FIR`) and can call IR builder functions like `emitLine()`, `declVar()`, `func()`, etc. - they write to the same output as the calling emitter. This is how the `emitBlock` routine in pascal.mor works: it is called from statement emitters and emits children to the same output stream.

```mor
emitters {
  on stmt.var_decl {
    let ctype = resolveType(getAttr(node, "vtype"));
    declVar(getAttr(node, "vname"), ctype);
  }
}
```

Using `match` for cleaner type resolution:

```mor
routine resolveType(typeText: string) -> string {
  match typeText {
    "integer" => { return "int64_t"; }
    "string"  => { return "std::string"; }
    "boolean" => { return "bool"; }
    "single"  => { return "float"; }
    "double"  => { return "double"; }
    else      => { return typeText; }
  }
}
```

### Constants

The `const {}` block defines named constants available in all handler contexts. Constants are evaluated at definition time and stored as global variables. They are useful for configuration values, magic numbers, and feature flags (see [Section 12](#-fragments-imports-and-includes) for guarded feature inclusion).

```mor
const {
  MAX_PARAMS = 255;
  DEFAULT_ALIGN = 8;
  VERSION_STRING = "1.0.0";
  PI = 3.14159;
}
```

### Enums

The `enum` declaration creates sequential integer constants starting from 0. Members are declared as global variables with their integer index value. Enum members are global constants, not scoped to the enum name - you reference `exe`, not `BuildKind.exe`.

```mor
enum BuildKind { exe, dll, lib }
// exe = 0, dll = 1, lib = 2
```


## 📦 Fragments, Imports, and Includes

As your `.mor` file grows, you will want to split it into manageable pieces. Metamorf offers three mechanisms for this, each serving a different purpose.

### Fragments

A `fragment` defines a reusable block of top-level declarations that can be expanded later with `include`. Fragments are defined and expanded within the same file - they are organizational tools for keeping related declarations together and reusing them in multiple blocks.

```mor
fragment common_operators {
  token op.plus  = "+";
  token op.minus = "-";
  token op.star  = "*";
  token op.slash = "/";
}

tokens {
  token keyword.var = "var";
  include common_operators;
}
```

Fragments must be defined before they are included. Fragment expansion is recursive - included fragments can themselves contain includes.

### Imports

Imports load external `.mor` files - they are for sharing definitions across multiple languages. Unlike fragments (which are local to a single file), imports bring in declarations from separate files. The `import` statement loads another `.mor` file and processes its top-level declarations as if they were part of the current file.

```mor
import "common_tokens.mor";
import "common_types.mor";

tokens {
  // Additional tokens specific to this language
  token keyword.module = "module";
}
```

**Resolution:** Import paths are resolved relative to the directory of the importing `.mor` file.

**Deduplication:** Each import path is processed only once, even if imported from multiple files.

**Lifetime:** Imported `.mor` files have their own ASTs that must stay alive for the duration of compilation - their closures are referenced during Phase 2. Metamorf handles this automatically via `TMetamorfLang.FImportedInstances`, so you do not need to manage it yourself.

### Includes

The `include` statement expands a previously defined fragment in place.

```mor
fragment myra_types {
  type int32 = "type.int32";
  type int64 = "type.int64";
}

types {
  include myra_types;
  type boolean = "type.boolean";
}
```

### Top-Level Guards (Conditional Feature Inclusion)

Guards let you conditionally include or exclude features from your language definition. Set a constant to `false` and all the guarded tokens, types, and rules are skipped during registration. This is useful for developing a language incrementally - you can define features ahead of time but keep them disabled until they are ready.

```mor
const {
  FEATURE_CPP_PASSTHROUGH = true;
  FEATURE_GENERICS = false;
}

tokens {
  token keyword.routine = "routine";

  guard FEATURE_CPP_PASSTHROUGH {
    token cpp.keyword.class  = "class";
    token cpp.keyword.struct = "struct";
  }
}
```



## 📚 Built-in Functions Reference

This section is a complete reference for all built-in functions available in the `.mor` language. Functions are grouped by the context where they are available - some work everywhere, while others are specific to grammar rules, semantic handlers, or emitter handlers.

### Common: All Contexts

These functions are available in every handler block - grammar rules, semantic handlers, emitter handlers, and routines. They form the foundation of all AST manipulation and string processing.

**Node operations:**

Note that `child_count()` has three overloads: no argument (current context node), a node argument, or a string argument (attribute name). This is easy to miss when reading other people's `.mor` files.

| Function | Returns | Description |
|----------|---------|-------------|
| `nodeKind(node)` | string | Get the kind string of a node |
| `getAttr(node, key)` | string | Read a string attribute from a node |
| `getAttr(key)` | string | Read attribute from current context node |
| `setAttr(node, key, value)` | - | Write an attribute onto a node |
| `setAttr(key, value)` | - | Write attribute on current context node |
| `getChild(node, index)` | node | Get child node at zero-based index |
| `childCount(node)` | int | Number of children of specified node |
| `child_count()` | int | Number of children of current context node |
| `child_count(node)` | int | Number of children of specified node |
| `child_count(attr)` | int | Number of children of node in attribute |
| `has_attr(name)` | bool | True if current node has this attribute |
| `createNode("kind")` | node | Create new AST node with given kind |
| `addChild(parent, child)` | - | Append child to parent node |
| `getResultNode()` | node | Get the result node (grammar context) |

**String operations:**

| Function | Returns | Description |
|----------|---------|-------------|
| `concat(a, b, ...)` | string | Concatenate strings (also: `a + b`) |
| `upper(s)` | string | Convert to upper case |
| `lower(s)` | string | Convert to lower case |
| `trim(s)` | string | Strip leading/trailing whitespace |
| `replace(s, find, repl)` | string | Replace all occurrences |
| `len(s)` | int | String length |
| `substr(s, start, len)` | string | Substring (0-based start) |
| `startsWith(s, prefix)` | bool | True if s starts with prefix |
| `endsWith(s, suffix)` | bool | True if s ends with suffix |
| `contains(s, sub)` | bool | True if s contains sub |
| `intToStr(n)` | string | Integer to string |
| `strToInt(s)` | int | String to integer (0 on failure) |

### Parse Context

These functions are available inside `grammar { rule ... { } }` bodies for manual token manipulation. When `expect`/`consume`/`parse` cannot express your parsing logic, these imperative constructs give you full control. See [Section 7](#-grammar-block) for examples of combining declarative and imperative constructs.

| Function | Returns | Description |
|----------|---------|-------------|
| `checkToken("kind")` | bool | True if current token is `kind` (no consume) |
| `matchToken("kind")` | bool | If current is `kind`, consume and return true |
| `advance()` | string | Consume current token, return its text |
| `requireToken("kind")` | - | Assert current is `kind` and consume (error if not) |
| `currentText()` | string | Text of current token |
| `currentKind()` | string | Kind string of current token |
| `peekKind()` | string | Kind of next token (1-token lookahead) |
| `parseExpr(power)` | node | Parse expression with minimum binding power |
| `parseStmt()` | node | Parse next statement |

### Semantic Context

These functions are available inside `semantics { on ... { } }` handlers for symbol management and module compilation. They supplement the declarative constructs (`declare`, `lookup`, `scope`, `visit`) described in [Section 8](#-semantics-block).

| Function | Returns | Description |
|----------|---------|-------------|
| `symbolExistsWithPrefix(prefix)` | bool | True if any symbol starts with prefix |
| `demoteCLinkageForPrefix(prefix)` | int | Strip `"C"` linkage from matching symbols, return count |
| `compileModule(name)` | bool | Trigger compilation of module `name` |
| `setModuleExtension(ext)` | - | Set file extension for module file resolution |

Plus the declarative constructs: `declare`, `lookup`, `scope`, `visit` (see Semantics Block section).

### Emit Context: Low-Level Output

These functions are available inside `emitters { on ... { } }` handlers for direct output control. Most of the time you will use the higher-level IR builders (function builder, statement builder) instead, but low-level output is essential for constructs that do not map cleanly to C++ control structures - like `repeat/until` loops or custom preprocessor directives.

| Function | Description |
|----------|-------------|
| `emitLine(text)` | Emit indented line with newline to source file |
| `emitLine(text, "header")` | Emit to header file instead |
| `emit text;` | Declarative: emit text verbatim (expression emitter shorthand) |
| `emit @attr;` | Declarative: emit attribute value from current node |
| `indentIn()` | Increase indentation level |
| `indentOut()` | Decrease indentation level |
| `blankLine()` | Emit a blank line |
| `include(path)` | Emit `#include <path>` or `#include "path"` |

### Emit Context: Function Builder

These functions build C++ function definitions step by step. Call them in sequence: `func()` opens the function, `param()` adds parameters, then emit the body, and `endFunc()` closes it. The builder handles the signature formatting, braces, and indentation automatically.

| Function | C++ Output |
|----------|------------|
| `func(name, returnType)` | Opens: `returnType name(` ... `) {` |
| `param(name, type)` | Adds parameter to current function signature |
| `endFunc()` | Closes: `}` |

Example:

```mor
func("main", "int");
  declVar("x", "int32_t", "0");
  returnVal("0");
endFunc();
```

Produces:

```cpp
int main() {
    int32_t x = 0;
    return 0;
}
```

### Emit Context: Declarations

| Function | C++ Output |
|----------|------------|
| `declVar(name, type)` | `type name;` |
| `declVar(name, type, init)` | `type name = init;` |

### Emit Context: Statements

| Function | C++ Output |
|----------|------------|
| `assign(lhs, rhs)` | `lhs = rhs;` |
| `stmt(text)` | `text` (verbatim statement) |
| `returnVal(expr)` | `return expr;` |
| `returnVoid()` | `return;` |
| `ifStmt(cond)` | `if (cond) {` |
| `elseIfStmt(cond)` | `} else if (cond) {` |
| `elseStmt()` | `} else {` |
| `endIf()` | `}` |
| `whileStmt(cond)` | `while (cond) {` |
| `endWhile()` | `}` |
| `forStmt(var, init, cond, step)` | `for (auto var = init; cond; step) {` |
| `endFor()` | `}` |
| `breakStmt()` | `break;` |
| `continueStmt()` | `continue;` |

### Emit Context: Expression Builders

These return C++ expression strings for use in composition. They are less commonly used than `exprToString()` but useful when you need to construct expressions programmatically rather than walking the AST.

| Function | Returns |
|----------|---------|
| `invoke(func, arg1, ...)` | `func(arg1, ...)` |
| `get(name)` | Variable reference `name` |
| `neg(expr)` | `-expr` |
| `nullLit()` | `nullptr` |

### Emit Context: Type Resolution

These functions bridge the type system and code generation. `typeTextToKind()` converts what the user wrote (e.g., `"integer"`) to an internal type kind (e.g., `"type.int32"`). `typeToIR()` converts that kind to a C++ type string (e.g., `"int32_t"`). `exprToString()` is the recursive expression renderer described in [Section 9](#-emitters-block).

| Function | Returns | Description |
|----------|---------|-------------|
| `typeTextToKind(text)` | string | Resolve type text to type kind (e.g., `"integer"` to `"type.integer"`) |
| `typeToIR(kind)` | string | Resolve type kind to C++ type (e.g., `"type.int32"` to `"int32_t"`) |
| `exprToString(node)` | string | Render an expression node tree to a C++ expression string |

**`exprToString` behavior:**

1. If an emitter handler is registered for the node's kind, it runs in string-capture mode
2. Otherwise, if the node has 2 children and an `@operator` attribute, it produces `left op right`
3. Otherwise, falls back to the engine's default `ExprToString()` method

### Emit Context: Node Walking

These two functions control how the emitter traverses the AST. `emitNode()` dispatches the registered emitter handler for a single node. `emitChildren()` is a convenience that emits all children of a node in sequence - equivalent to looping over children and calling `emitNode()` on each one.

| Function | Description |
|----------|-------------|
| `emitNode(node)` | Dispatch the emitter handler for a node |
| `emitChildren(node)` | Emit all children of a node sequentially |


### Pipeline Configuration Builtins

These builtins configure the Zig/Clang build pipeline. They are typically called from emitter handlers that process build-configuration statements or directives. The pattern is: define a directive in your tokens block, parse it in a grammar rule, and wire the emitter to call the appropriate pipeline builtin. This lets users configure their build inline in their source code.

**Build Configuration:**

| Function | Values | Description |
|----------|--------|-------------|
| `setPlatform(p)` | `"win64"`, `"linux64"` | Target platform |
| `setBuildMode(m)` | `"exe"`, `"lib"`, `"dll"` | Output type |
| `setOptimize(o)` | `"debug"`, `"releasesafe"`, `"releasefast"`, `"releasesmall"` | Optimization level |
| `setSubsystem(s)` | `"console"`, `"gui"` | Windows subsystem |

**Version Info:**

| Function | Description |
|----------|-------------|
| `setAddVerInfo(v)` | Enable version resource: `"on"` / `"off"` |
| `setExeIcon(path)` | Embed icon into executable |
| `setVersionMajor(v)` | Version major number (string) |
| `setVersionMinor(v)` | Version minor number (string) |
| `setVersionPatch(v)` | Version patch number (string) |
| `setProductName(v)` | Product name in version resource |
| `setDescription(v)` | File description in version resource |
| `setFilename(v)` | Original filename in version resource |
| `setCompanyName(v)` | Company name in version resource |
| `setCopyright(v)` | Copyright string in version resource |

**Paths and Libraries:**

| Function | Description |
|----------|-------------|
| `addIncludePath(path)` | Add C++ include search path |
| `addLibraryPath(path)` | Add library search path |
| `addLinkLibrary(name)` | Add library to link |
| `addCopyDLL(path)` | Copy DLL to output directory |
| `addSourceFile(path)` | Add additional source file to build |
| `setModuleExtension(ext)` | Set file extension for module resolution (e.g., `"pas"`, `"myra"`) |

**Wiring Source-Level Configuration:**

Here is the complete pattern for connecting a source-level directive to a pipeline builtin, from token declaration through grammar rule to emitter handler. This is how pascal.mor allows `@platform linux64` in source code to set the build target:

```mor
tokens {
  directive_prefix = "@";
  token directive.platform  = "platform";
  token directive.optimize  = "optimize";
  token directive.subsystem = "subsystem";
}

grammar {
  rule stmt.directive_platform {
    expect directive.platform;
    consume identifier -> @value;
  }
  rule stmt.directive_optimize {
    expect directive.optimize;
    consume identifier -> @value;
  }
  rule stmt.directive_subsystem {
    expect directive.subsystem;
    consume identifier -> @value;
  }
}

semantics {
  on stmt.directive_platform  { }
  on stmt.directive_optimize  { }
  on stmt.directive_subsystem { }
}

emitters {
  on stmt.directive_platform {
    setPlatform(getAttr(node, "value"));
  }
  on stmt.directive_optimize {
    setOptimize(getAttr(node, "value"));
  }
  on stmt.directive_subsystem {
    setSubsystem(getAttr(node, "value"));
  }
}
```

A program in that language then configures its build inline:

```
@platform linux64
@optimize debug
@subsystem console
```

With the built-in function reference covered, the next section explains how Metamorf automatically handles C++ interop so your `.mor` file does not have to.


## 🔗 C++ Passthrough

Metamorf generates C++ 23 code. But what if the user writes C++ directly in their source? Instead of making every `.mor` file handle every C++ keyword and operator, `ConfigCpp()` does it automatically. This is NOT defined in the `.mor` file - it is registered automatically by `TMetamorf` after the interpreter configures the custom `TMetamorf` instance.

### What ConfigCpp Provides Automatically

**Tokens:** All C++ keyword tokens (`cpp.keyword.class`, `cpp.keyword.struct`, `cpp.keyword.void`, etc.), C++ operators (`::`, `->`, `++`, `--`, `==`, `!=`, `&&`, `||`, `!`, `~`, `%`), C++ braces (`{`, `}`), preprocessor hash (`#`).

**Grammar:** Statement passthrough for `cpp.keyword.*` tokens, expression prefix handlers for C++ keywords, `::` scope resolution, `->` arrow access, C-style cast detection via `delimiter.lparen` wrapping, `#include`/`#define` preprocessor handlers.

**Codegen:** Verbatim passthrough emitters for all C++ AST nodes.

### What This Means for Language Authors

Your `.mor` file defines ONLY your custom language's constructs. When the user writes `#include <cstdio>` or `printf("hello")` in their source, ConfigCpp captures and emits them verbatim. No `.mor` configuration is needed for C++ interop.

This is why pascal.mor does not declare `class`, `struct`, or `void` as keywords - they come from C++ automatically. If C++ has the keyword, your `.mor` file does not need to declare it. ConfigCpp handles it. Bare identifiers that are not custom-language keywords (like `printf`) are parsed by your expression/statement handlers - they appear as `expr.ident` nodes and pass through to C++ output via `exprToString()`.

### Registration Order

Your `.mor` definitions run FIRST. ConfigCpp wraps AFTER. This means your custom keywords take priority over C++ keywords. The order is:

```
1. Bootstrap: parse .mor file -> AST
2. Interpreter: walk AST -> configure custom TMetamorf
3. ConfigCpp: wrap custom TMetamorf with C++ passthrough  (automatic)
4. Phase 2: custom TMetamorf compiles user source
```

`ConfigCpp` is called AFTER the interpreter so it can wrap the custom language's `delimiter.lparen` prefix handler for C-style cast detection.

### The Design Rule

If C++ has the keyword, your `.mor` file does not need it. Your `.mor` file owns the custom language surface. C++ owns everything else. There is no conflict because `ConfigCpp` runs after your definitions and handles the remainder. This separation is what makes Metamorf languages interoperate with C++ seamlessly - your language adds new syntax on top of C++, and ConfigCpp ensures the C++ substrate is always there.



## 🔌 Embedding Metamorf

Metamorf has two embedding surfaces. Both are Delphi classes that you use in your own applications. The relationship between them is the architectural insight that makes the whole project cohere: `TMetamorfLang` uses `TMetamorf` internally, and the `.mor` language itself is built using `TMetamorf` — it dogfoods its own engine every time it runs.

| Surface | Unit | Purpose |
|---------|------|---------|
| **`TMetamorf`** | `Metamorf.API` | Core compiler-construction API. Define a language entirely in Delphi code by calling `Config().AddKeyword(...)`, `Config().RegisterStatement(...)`, etc. This is the foundational surface — everything else is built on it. |
| **`TMetamorfLang`** | `Metamorf.Lang` | Convenience wrapper. Give it a `.mor` file and a source file, call `Compile()`. Handles the two-phase bootstrap internally using `TMetamorf` under the hood. |

If you just want to compile programs written in a `.mor`-defined language, use `TMetamorfLang`. If you want to define a language programmatically in Delphi — or understand how the `.mor` language itself works — use `TMetamorf` directly.


### Surface 1: TMetamorfLang (The .mor File Loader)

`TMetamorfLang` is the high-level surface. You give it a `.mor` language definition file and a source file, and it handles everything: parsing the `.mor` file, configuring a `TMetamorf` instance, and compiling the source to a native binary.

```delphi
uses
  Metamorf.Lang;

var
  LLang: TMetamorfLang;
begin
  LLang := TMetamorfLang.Create();
  try
    LLang.SetLangFile('pascal.mor');
    LLang.SetSourceFile('hello.pas');
    LLang.SetOutputPath('output');

    LLang.SetStatusCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        WriteLn(ALine);
      end);

    if LLang.Compile(True, False) then
      LLang.Run()
    else
      WriteLn('Compilation failed');
  finally
    LLang.Free();
  end;
end;
```

**TMetamorfLang API:**

| Method | Description |
|--------|-------------|
| `SetLangFile(filename)` | Path to the `.mor` language definition file |
| `SetSourceFile(filename)` | Path to the source file to compile |
| `SetOutputPath(path)` | Output directory for generated files and binary |
| `SetLineDirectives(enabled)` | Emit `#line` directives in generated C++ |
| `SetStatusCallback(cb, data)` | Callback for status/progress messages |
| `SetOutputCallback(cb, data)` | Callback for program output capture |
| `Compile(build, autoRun)` | Run Phase 1 + Phase 2; returns True on success |
| `Run()` | Run the last successfully compiled binary |
| `GetLastExitCode()` | Exit code from last `Run()` |
| `HasErrors()` | True if last `Compile()` produced errors |
| `GetErrors()` | Error collection from last phase |
| `GetVersionStr()` | Metamorf version string |


### Surface 2: TMetamorf (The Core Delphi API)

`TMetamorf` is the foundational surface. Every language built on Metamorf — including the `.mor` meta-language itself — is defined by calling methods on `TMetamorf` and its `TLangConfig` object. The `Metamorf.Lang.Lexer.pas`, `Metamorf.Lang.Grammar.pas`, and `Metamorf.Lang.Semantics.pas` units use exactly this API to build the `.mor` language's own lexer, grammar, and semantics. When a `.mor` file runs, `TMetamorfLangInterpreter` walks the AST and calls the same `TLangConfig` methods on a fresh `TMetamorf` instance.

A single `TMetamorf` object drives every stage. There is no language knowledge hardcoded anywhere in the toolkit. The config is the language.

```
Source Text
    │
    ▼
┌─────────┐  token stream   ┌─────────┐   AST        ┌───────────┐
│  Lexer  │ ──────────────► │ Parser  │ ───────────► │ Semantics │
└─────────┘                 └─────────┘              └───────────┘
                                                           │
                                              enriched AST (ATTR_*)
                                                           │
                                                           ▼
                                                    ┌───────────┐
                                                    │  CodeGen  │ ──► .h + .cpp
                                                    └───────────┘          │
                                                                           ▼
                                                                      ┌──────────┐
                                                                      │   Zig    │ ──► native binary
                                                                      └──────────┘
```


#### The Configuration Surfaces

`TMetamorf.Config()` returns a `TLangConfig` object with four configuration surfaces. Every method returns `TLangConfig` for fluent chaining:

| Surface | What it controls | Who reads it |
|---------|------------------|--------------|
| **Lexer** | What tokens exist: keywords, operators, string styles, comments, number formats | `TLexer` |
| **Grammar** | How tokens combine into AST nodes: prefix/infix/statement handlers | `TParser` |
| **Semantic** | Scope analysis, symbol resolution, type checking | `TSemantics` |
| **Emit** | How AST nodes become C++23 text | `TCodeGen` |

```delphi
LMeta.Config()
  .AddKeyword(...)        // lexer surface
  .AddOperator(...)       // lexer surface
  .RegisterStatement(...) // grammar surface
  .RegisterEmitter(...)   // emit surface
  .RegisterSemanticRule(...)  // semantic surface
```


#### Token Kinds: The Contract String

The single most important concept is the **token kind string** — a plain string like `'keyword.if'` or `'op.plus'` that connects every stage. The lexer assigns kind strings to tokens. The parser dispatches handlers based on kind strings. The semantic engine and codegen dispatch based on AST node kind strings. You invent the kind strings. There is no required naming convention, but the convention used throughout the examples is `category.name` (e.g. `keyword.if`, `expr.binary`, `stmt.while`, `type.integer`).


#### Lexer Surface

```delphi
LMeta.Config()
  // Case sensitivity
  .CaseSensitiveKeywords(False)

  // Character classes for identifiers
  .IdentifierStart('a-zA-Z_')
  .IdentifierPart('a-zA-Z0-9_')

  // Keywords
  .AddKeyword('if',    'keyword.if')
  .AddKeyword('while', 'keyword.while')
  .AddKeyword('begin', 'keyword.begin')
  .AddKeyword('end',   'keyword.end')

  // Operators (auto-sorted longest-first internally)
  .AddOperator(':=', 'op.assign')
  .AddOperator('+',  'op.plus')
  .AddOperator(';',  'delimiter.semicolon')

  // String literal styles
  .AddStringStyle(, , KIND_STRING, False)  // Pascal: no escapes

  // Comments
  .AddLineComment('//')
  .AddBlockComment('{', '}')

  // Number prefixes
  .SetHexPrefix('$', 'literal.integer')      // Pascal hex
  .SetBinaryPrefix('0b', 'literal.integer')

  // Directive prefix
  .SetDirectivePrefix('$', 'directive')

  // Structural tokens
  .SetStatementTerminator('delimiter.semicolon')
  .SetBlockOpen('keyword.begin')
  .SetBlockClose('keyword.end');
```


#### Grammar Surface (Pratt Parsing)

The grammar surface uses Pratt parsing. Every token has a potential prefix meaning (starts an expression) and/or infix meaning (continues an expression). You register handlers for each role.

**Handler types:**

| Registration | When it fires | Handler signature |
|-------------|---------------|-------------------|
| `RegisterPrefix(kind, nodeKind, handler)` | Token at expression-start position | `function(AParser: TParserBase): TASTNodeBase` |
| `RegisterInfixLeft(kind, power, nodeKind, handler)` | Token after a left expression (left-assoc) | `function(AParser: TParserBase; ALeft: TASTNodeBase): TASTNodeBase` |
| `RegisterInfixRight(kind, power, nodeKind, handler)` | Token after a left expression (right-assoc) | `function(AParser: TParserBase; ALeft: TASTNodeBase): TASTNodeBase` |
| `RegisterStatement(kind, nodeKind, handler)` | Token at statement position | `function(AParser: TParserBase): TASTNodeBase` |

**Building a node inside a handler:**

1. `AParser.CreateNode()` — kind from dispatch context, token = current
2. `AParser.CreateNode(ANodeKind)` — explicit kind, token = current
3. `AParser.CreateNode(ANodeKind, AToken)` — explicit kind and token
4. `LNode.SetAttr(key, TValue.From<string>(value))` — store data on the node
5. `LNode.AddChild(TASTNode(AParser.ParseExpression(0)))` — parse and attach sub-expression
6. `AParser.Expect(kind)` — consume token or record error
7. `AParser.Consume()` — consume current token and advance

**Convenience:** `RegisterBinaryOp('op.plus', 20, '+')` creates a left-associative `expr.binary` node with `op` attribute. `RegisterLiteralPrefixes()` registers prefix handlers for identifier, integer, real, and string.

**Example — binary operator:**

```delphi
LMeta.Config().RegisterInfixLeft('op.plus', 20, 'expr.binary',
  function(AParser: TParserBase;
    ALeft: TASTNodeBase): TASTNodeBase
  var
    LNode: TASTNode;
  begin
    LNode := AParser.CreateNode();
    LNode.SetAttr('op', TValue.From<string>('+'));
    AParser.Consume();
    LNode.AddChild(TASTNode(ALeft));
    LNode.AddChild(TASTNode(
      AParser.ParseExpression(AParser.CurrentInfixPower())));
    Result := LNode;
  end);
```

**Example — statement handler (while):**

```delphi
LMeta.Config().RegisterStatement('keyword.while', 'stmt.while',
  function(AParser: TParserBase): TASTNodeBase
  var
    LNode: TASTNode;
  begin
    LNode := AParser.CreateNode();
    AParser.Consume();
    LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
    AParser.Expect('keyword.do');
    LNode.AddChild(TASTNode(AParser.ParseStatement()));
    Result := LNode;
  end);
```


#### Semantic Surface

The semantic stage walks the AST after parsing, resolves symbols, checks types, and writes enrichment attributes onto nodes. Register a handler for each node kind that needs semantic processing:

```delphi
LMeta.Config().RegisterSemanticRule('stmt.var_decl',
  procedure(ANode: TASTNodeBase; ASem: TSemanticBase)
  var
    LName: TValue;
  begin
    ANode.GetAttr('decl.name', LName);
    if not ASem.DeclareSymbol(LName.AsString, ANode) then
      ASem.AddSemanticError(ANode, 'S100', 'Duplicate: ' + LName.AsString);
    if ASem.IsInsideRoutine() then
      TASTNode(ANode).SetAttr(ATTR_STORAGE_CLASS,
        TValue.From<string>('local'))
    else
      TASTNode(ANode).SetAttr(ATTR_STORAGE_CLASS,
        TValue.From<string>('global'));
    ASem.VisitChildren(ANode);
  end);
```

**Key semantic operations:**

| Method | Description |
|--------|-------------|
| `ASem.PushScope(name, openToken)` | Enter a named scope |
| `ASem.PopScope(closeToken)` | Leave current scope |
| `ASem.DeclareSymbol(name, node)` | Declare symbol; returns False if duplicate |
| `ASem.LookupSymbol(name, outNode)` | Search current + parent scopes |
| `ASem.VisitChildren(node)` | Walk all children of the node |

**Standard attributes written by the semantic pass:**

| Constant | Value | Meaning |
|----------|-------|---------|
| `ATTR_TYPE_KIND` | `'sem.type'` | Resolved type kind |
| `ATTR_RESOLVED_SYMBOL` | `'sem.symbol'` | Declared name this identifier resolves to |
| `ATTR_DECL_NODE` | `'sem.decl_node'` | Pointer to declaring AST node |
| `ATTR_STORAGE_CLASS` | `'sem.storage'` | `'local'`, `'global'`, `'param'`, `'const'`, `'routine'` |
| `ATTR_SCOPE_NAME` | `'sem.scope'` | Fully-qualified scope name |
| `ATTR_CALL_RESOLVED` | `'sem.call_symbol'` | Resolved overload symbol name |
| `ATTR_COERCE_TO` | `'sem.coerce'` | Target type for implicit coercion |

**Type compatibility:** Register with `RegisterTypeCompat(func)` to control assignment/argument compatibility and implicit coercion.


#### Emit Surface (IR Builders)

The emit surface turns AST nodes into C++23 text. Register an emitter for each node kind:

```delphi
LMeta.Config().RegisterEmitter('stmt.while',
  procedure(ANode: TASTNodeBase; AGen: TIRBase)
  var
    LCondStr: string;
  begin
    LCondStr := LMeta.Config().ExprToString(ANode.GetChild(0));
    AGen.WhileStmt(LCondStr);
    AGen.EmitNode(ANode.GetChild(1));
    AGen.EndWhile();
  end);
```

`AGen.EmitNode(child)` dispatches the child through the emitter registry. `AGen.EmitChildren(node)` does this for all children.

**IR builder methods (selected):**

| Category | Methods |
|----------|---------|
| **Functions** | `Func(name, returnType)`, `Param(name, type)`, `EndFunc()` |
| **Variables** | `DeclVar(name, type)`, `DeclVar(name, type, init)`, `Assign(lhs, expr)` |
| **Control** | `IfStmt(cond)`, `ElseStmt()`, `EndIf()`, `WhileStmt(cond)`, `EndWhile()`, `ForStmt(var, init, cond, step)`, `EndFor()` |
| **Output** | `Stmt(text)`, `Call(func, args)`, `Return(expr)`, `EmitLine(text)` |
| **Top-level** | `Include(header)`, `Global(name, type, init)`, `DeclConst(name, type, val)`, `Using(alias, original)` |
| **Expressions** | `Lit(val)`, `Str(val)`, `Bool(val)`, `Get(var)`, `Invoke(func, args)`, `Add(l, r)`, `Eq(l, r)`, `Cast(type, expr)` |
| **Context** | `SetContext(key, val)`, `GetContext(key, default)` — shared state across emit handlers |

**ExprToString:** `LMeta.Config().ExprToString(node)` recursively converts an expression AST node to a C++ string. It handles built-in kinds (`expr.identifier`, `expr.binary`, `expr.call`, etc.) automatically. Register `RegisterExprOverride(nodeKind, handler)` for custom rendering.


#### Type Inference Surface

For dynamically-typed languages where types are inferred from literals and call sites:

```delphi
LMeta.Config()
  .AddLiteralType('expr.integer', 'type.integer')
  .AddLiteralType('expr.real', 'type.double')
  .AddLiteralType('expr.string', 'type.string')
  .AddDeclKind('stmt.local_decl')
  .AddCallKind('expr.call')
  .SetCallNameAttr('call.name')
  .AddTypeKeyword('integer', 'type.integer')
  .AddTypeKeyword('string', 'type.string');
```

Call `LMeta.Config().ScanAll(root)` in your semantic handler to populate the type maps. Then `GetDeclTypes()` returns variable → type kind, and `GetCallArgTypes()` returns function → argument types.


#### Name Mangling and TypeToIR

```delphi
// Name mangling: source identifiers → safe C++ identifiers
LMeta.Config().SetNameMangler(
  function(const AName: string): string
  begin
    Result := 'np_' + AName;
  end);

// Type-to-IR: internal type kind → C++ type
LMeta.Config().SetTypeToIR(
  function(const ATypeKind: string): string
  begin
    if ATypeKind = 'type.integer' then Result := 'int32_t'
    else if ATypeKind = 'type.double' then Result := 'double'
    else if ATypeKind = 'type.string' then Result := 'std::string'
    else if ATypeKind = 'type.boolean' then Result := 'bool'
    else if ATypeKind = 'type.void' then Result := 'void'
    else Result := 'auto';
  end);
```

`MangleName(name)` applies the mangler (or returns unchanged if nil). `TypeToIR(typeKind)` maps type kind to C++ type. `TypeTextToKind(text)` maps a source type keyword to its type kind using the `AddTypeKeyword` table.


#### Running the Pipeline

```delphi
uses
  Metamorf.API;

var
  LMeta: TMetamorf;
begin
  LMeta := TMetamorf.Create();
  try
    // Configure your language on LMeta.Config() ...

    LMeta.SetSourceFile('myprogram.src');
    LMeta.SetOutputPath('output');
    LMeta.SetTargetPlatform(tpWin64);
    LMeta.SetBuildMode(bmExe);
    LMeta.SetOptimizeLevel(olDebug);

    LMeta.SetStatusCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        WriteLn(ALine);
      end);

    if LMeta.Compile(True, True) then  // build + auto-run
      WriteLn('Success')
    else
      LMeta.ShowErrors();
  finally
    LMeta.Free();
  end;
end;
```

`Compile()` runs: Tokenize → Parse → Semantics → CodeGen → Zig/Clang → (optional) execute.


#### A Complete Minimal Language

The smallest language that can print a string. Source: `print("hello")`.

```delphi
var
  LMeta: TMetamorf;
begin
  LMeta := TMetamorf.Create();
  try
    LMeta.Config()
      .CaseSensitiveKeywords(True)
      .AddKeyword('print', 'keyword.print')
      .AddOperator('(', 'delimiter.lparen')
      .AddOperator(')', 'delimiter.rparen')
      .AddStringStyle('"', '"', KIND_STRING, True)
      .SetStatementTerminator('');

    LMeta.Config().RegisterLiteralPrefixes();

    LMeta.Config().RegisterStatement('keyword.print', 'stmt.print',
      function(AParser: TParserBase): TASTNodeBase
      var
        LNode: TASTNode;
      begin
        LNode := AParser.CreateNode();
        AParser.Consume();
        AParser.Expect('delimiter.lparen');
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        AParser.Expect('delimiter.rparen');
        Result := LNode;
      end);

    LMeta.Config().RegisterEmitter('stmt.print',
      procedure(ANode: TASTNodeBase; AGen: TIRBase)
      begin
        AGen.Include('iostream');
        AGen.Stmt('std::cout << ' +
          LMeta.Config().ExprToString(ANode.GetChild(0)) +
          ' << std::endl;');
      end);

    LMeta.SetSourceFile('hello.mylang');
    LMeta.SetOutputPath('output');
    LMeta.SetTargetPlatform(tpWin64);
    LMeta.SetBuildMode(bmExe);
    LMeta.SetOptimizeLevel(olDebug);

    LMeta.SetStatusCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        WriteLn(ALine);
      end);

    if LMeta.Compile(True) then
      WriteLn('Done.')
    else
      WriteLn('Failed.');
  finally
    LMeta.Free();
  end;
end;
```

The emitter turns `print("hello")` into:

```cpp
#include <iostream>
int main() {
    std::cout << "hello" << std::endl;
}
```

Every language in the toolkit — including the `.mor` meta-language — is this pattern scaled up. The same four surfaces, the same handler types, the same AST building blocks.


### Constants

| Category | Values |
|----------|--------|
| **Platform** | `tpWin64`, `tpLinux64` |
| **Build mode** | `bmExe`, `bmLib`, `bmDll` |
| **Optimize level** | `olDebug`, `olReleaseSafe`, `olReleaseFast`, `olReleaseSmall` |
| **Subsystem** | `stConsole`, `stGUI` |
| **Associativity** | `aoLeft`, `aoRight` |
| **Source file** | `sfHeader`, `sfSource` |
| **Error severity** | `esHint`, `esWarning`, `esError`, `esFatal` |


### Type Aliases (from Metamorf.API)

All types a consumer needs are aliased in `Metamorf.API`. Nobody touches internal units directly:

| Alias | Source | Description |
|-------|--------|-------------|
| `TMetamorf` | `Metamorf.API` | Core compiler object |
| `TLangConfig` | `Metamorf.LangConfig` | Language configuration (returned by `Config()`) |
| `TASTNodeBase` | `Metamorf.Common` | Abstract AST node base |
| `TASTNode` | `Metamorf.Common` | Concrete AST node |
| `TParserBase` | `Metamorf.Common` | Parser base (received by grammar handlers) |
| `TIRBase` | `Metamorf.Common` | IR builder base (received by emit handlers) |
| `TSemanticBase` | `Metamorf.Common` | Semantic engine base (received by semantic handlers) |
| `TToken` | `Metamorf.Common` | Token record (kind, text, file, line, column) |
| `TStatementHandler` | `Metamorf.Common` | `function(AParser: TParserBase): TASTNodeBase` |
| `TPrefixHandler` | `Metamorf.Common` | `function(AParser: TParserBase): TASTNodeBase` |
| `TInfixHandler` | `Metamorf.Common` | `function(AParser: TParserBase; ALeft: TASTNodeBase): TASTNodeBase` |
| `TEmitHandler` | `Metamorf.Common` | `procedure(ANode: TASTNodeBase; AGen: TIRBase)` |
| `TSemanticHandler` | `Metamorf.Common` | `procedure(ANode: TASTNodeBase; ASem: TSemanticBase)` |




## 📜 Formal Grammar (EBNF)

This section provides the complete EBNF grammar for the Metamorf meta-language. EBNF notation is used: brackets `[` and `]` denote optionality, braces `{` and `}` denote repetition (zero or more), parentheses `(` and `)` group alternatives, and the vertical bar `|` separates alternatives.

### Lexical Elements

```ebnf
letter       = "A" | ... | "Z" | "a" | ... | "z" | "_" .
digit        = "0" | ... | "9" .
ident        = letter { letter | digit } .
integer      = digit { digit } .
string       = '"' { character | escapeSeq } '"' .
tripleString = "'''" { character } "'''" .
escapeSeq    = "\" ( "n" | "t" | "r" | "0" | "\" | '"' ) .
comment      = "//" { character } newline .
blockComment = "/*" { character } "*/" .
```

### Reserved Words

The meta-language is **case-sensitive** for all keywords and identifiers.

| Category | Words |
|----------|-------|
| Structure | `language`, `version`, `tokens`, `grammar`, `semantics`, `emitters`, `section` |
| Rules | `rule`, `on`, `token`, `optional`, `expect`, `consume`, `parse`, `many`, `until`, `sync` |
| Declarations | `let`, `const`, `routine`, `fragment`, `types`, `import`, `include` |
| Control flow | `if`, `else`, `while`, `for`, `in`, `return`, `match`, `guard`, `try`, `recover` |
| Semantics | `declare`, `lookup`, `scope`, `visit`, `children`, `child`, `parent`, `as`, `where`, `pass` |
| Emission | `emit`, `to`, `indent`, `before`, `after`, `node` |
| Diagnostics | `error`, `warning`, `hint`, `note`, `info` |
| Literals | `true`, `false`, `nil` |
| Logic | `and`, `or`, `not` |
| Types | `typeof`, `set`, `get` |

### Built-in Types

```
string   - text values (attribute values, token patterns, emission content)
int      - integer values (precedence, indices, counts)
bool     - boolean values (flags, conditions)
node     - an AST node reference
list     - ordered collection (children, token lists)
```

### Operators and Delimiters

```
+    -    *    /    %
==   !=   <    >    <=   >=
=    ;    ,    .    :    @
(    )    [    ]    {    }
->   =>   |
```

### Top-Level Structure

```ebnf
SourceFile     = LanguageDecl { TopLevelBlock } .

LanguageDecl   = "language" ident "version" string ";" .

TopLevelBlock  = TokenBlock | GrammarBlock | SemanticsBlock
               | EmitterBlock | TypesBlock | ConstBlock
               | EnumDecl | RoutineDecl | FragmentDecl
               | ImportStmt | IncludeStmt | GuardBlock .
```

### Token Declarations

```ebnf
TokenBlock     = "tokens" "{" { TokenDecl | TokenConfig | GuardBlock | IncludeStmt } "}" .

TokenDecl      = "token" TokenKind "=" string [ TokenFlags ] ";" .
TokenKind      = ident "." ident .
TokenFlags     = "[" TokenFlag { "," TokenFlag } "]" .
TokenFlag      = "noescape" | "close" string
               | "define" | "undef" | "ifdef" | "ifndef"
               | "elseif" | "else" | "endif" .

TokenConfig    = CaseSensitiveDecl | IdentStartDecl | IdentPartDecl
               | StructuralDecl | HexPrefixDecl | BinaryPrefixDecl
               | DirectivePrefixDecl .

CaseSensitiveDecl  = "casesensitive" "=" ( "true" | "false" ) ";" .
IdentStartDecl     = "identifier_start" "=" string ";" .
IdentPartDecl      = "identifier_part" "=" string ";" .

StructuralDecl     = ( "terminator" | "block_open" | "block_close" ) "=" TokenKind ";" .

HexPrefixDecl      = "hex_prefix" "=" string ";" .
BinaryPrefixDecl   = "binary_prefix" "=" string ";" .
DirectivePrefixDecl = "directive_prefix" "=" string ";" .
```

### Grammar Rule Declarations

```ebnf
GrammarBlock   = "grammar" "{" { RuleDecl } "}" .

RuleDecl       = "rule" NodeKind [ RuleModifiers ] "{" { RuleStmt } "}" .
RuleModifiers  = "precedence" ( "left" | "right" ) integer .
NodeKind       = ident "." ident .

RuleStmt       = ExpectStmt | ConsumeStmt | ParseStmt | SetAttrStmt
               | OptionalBlock | SyncDecl | HandlerStmt .

ExpectStmt     = "expect" TokenRef ";" .
ConsumeStmt    = "consume" TokenRef "->" "@" ident ";" .
ParseStmt      = "parse" ( "expr" | "stmt" ) "->" "@" ident ";"
               | "parse" "many" ( "expr" | "stmt" )
                 [ "until" UntilSpec ] "->" "@" ident ";" .
UntilSpec      = TokenKind | "[" TokenKind { "," TokenKind } "]" .
SetAttrStmt    = "set" "@" ident "=" Expression ";" .
OptionalBlock  = "optional" "{" { RuleStmt } "}" .
SyncDecl       = "sync" TokenKind ";" .
TokenRef       = TokenKind | "[" TokenKind { "," TokenKind } "]"
               | "identifier" .
```

### Semantic Handler Declarations

```ebnf
SemanticsBlock = "semantics" "{" { SemanticDecl | PassBlock } "}" .

PassBlock      = "pass" integer string "{" { SemanticDecl } "}" .

SemanticDecl   = "on" NodeKind "{" { SemanticStmt } "}" .

SemanticStmt   = VisitStmt | DeclareStmt | LookupStmt | ScopeBlock
               | HandlerStmt .

VisitStmt      = "visit" VisitTarget ";" .
VisitTarget    = "children" | "@" ident | "child" "[" Expression "]" .

DeclareStmt    = "declare" "@" ident "as" SymbolKind
                 [ "typed" Expression ] [ WhereBlock ] ";" .
SymbolKind     = "variable" | "routine" | "type" | "constant" | "parameter" .
WhereBlock     = "where" "{" { ident "=" Expression ";" } "}" .

LookupStmt     = "lookup" "@" ident
                 ( "->" "let" ident | "or" "{" { SemanticStmt } "}" ) ";" .

ScopeBlock     = "scope" Expression "{" { SemanticStmt } "}" .
```

### Emitter Handler Declarations

```ebnf
EmitterBlock   = "emitters" "{" { SectionDecl | EmitDecl | BeforeBlock | AfterBlock } "}" .

SectionDecl    = "section" ident [ "indent" string ] ";" .

EmitDecl       = "on" NodeKind "{" { EmitStmt } "}" .

BeforeBlock    = "before" "{" { EmitStmt } "}" .
AfterBlock     = "after" "{" { EmitStmt } "}" .

EmitStmt       = EmitToStmt | VisitStmt | IndentBlock | HandlerStmt .

EmitToStmt     = "emit" [ "to" ident ":" ] Expression ";" .

IndentBlock    = "indent" "{" { EmitStmt } "}" .
```

### Expressions

```ebnf
Expression     = OrExpr .
OrExpr         = AndExpr { "or" AndExpr } .
AndExpr        = NotExpr { "and" NotExpr } .
NotExpr        = [ "not" ] Comparison .
Comparison     = Addition [ ( "==" | "!=" | "<" | ">" | "<=" | ">=" ) Addition ] .
Addition       = Term { ( "+" | "-" ) Term } .
Term           = Factor { ( "*" | "/" | "%" ) Factor } .
Factor         = AttrAccess | Ident | StringLiteral | IntLiteral
               | BoolLiteral | "nil" | "(" Expression ")"
               | FuncCall | InterpolatedString | TripleString .

AttrAccess     = "@" ident .
FuncCall       = ident "(" [ Expression { "," Expression } ] ")" .

InterpolatedString = '"' { character | "{@" ident "}" | "{" Expression "}" } '"' .
TripleString       = "'''" { character } "'''" .
```

### Handler Body Logic

Handler bodies (inside `on` blocks and `routine` declarations) support full imperative logic.

```ebnf
HandlerStmt    = LetStmt | AssignStmt | IfStmt | WhileStmt | ForStmt
               | MatchStmt | GuardStmt | ReturnStmt | TryRecover
               | ErrorStmt | WarningStmt | HintStmt | NoteStmt | InfoStmt
               | FuncCallStmt | SetAttrStmt .

LetStmt        = "let" ident "=" Expression ";" .
AssignStmt     = ident "=" Expression ";" .

IfStmt         = "if" Expression "{" { HandlerStmt } "}"
                 { "else" "if" Expression "{" { HandlerStmt } "}" }
                 [ "else" "{" { HandlerStmt } "}" ] .

WhileStmt      = "while" Expression "{" { HandlerStmt } "}" .
ForStmt        = "for" ident "in" Expression "{" { HandlerStmt } "}" .

MatchStmt      = "match" Expression "{" { MatchArm } [ DefaultArm ] "}" .
MatchArm       = Pattern "=>" "{" { HandlerStmt } "}" .
DefaultArm     = "else" "=>" "{" { HandlerStmt } "}" .
Pattern        = ( StringLiteral | IntLiteral | BoolLiteral )
                 { "|" ( StringLiteral | IntLiteral | BoolLiteral ) } .

GuardStmt      = "guard" Expression "{" { HandlerStmt } "}" .

ReturnStmt     = "return" [ Expression ] ";" .

TryRecover     = "try" "{" { HandlerStmt } "}" "recover" "{" { HandlerStmt } "}" .

DiagStmt       = ( "error" | "warning" | "hint" | "note" | "info" ) Expression ";" .

FuncCallStmt   = ident "(" [ Expression { "," Expression } ] ")" ";" .
```

### Type Declarations

```ebnf
TypesBlock     = "types" "{" { TypeDecl | IncludeStmt | GuardBlock } "}" .

TypeDecl       = TypeKeywordDecl | TypeMappingDecl | LiteralTypeDecl
               | TypeCompatDecl | DeclKindDecl | CallKindDecl
               | CallNameAttrDecl | NameManglerDecl .

TypeKeywordDecl    = "type" ident "=" string ";" .
TypeMappingDecl    = "map" string "->" string ";" .
LiteralTypeDecl    = "literal" string "=" string ";" .
TypeCompatDecl     = "compatible" string "," string [ "->" string ] ";" .
DeclKindDecl       = "decl_kind" string ";" .
CallKindDecl       = "call_kind" string ";" .
CallNameAttrDecl   = "call_name_attr" "=" string ";" .
NameManglerDecl    = "name_mangler" "=" ident ";" .
```

### Routines, Constants, Fragments, Imports

```ebnf
RoutineDecl    = "routine" ident "(" [ ParamList ] ")" [ "->" TypeName ]
                 "{" { HandlerStmt } "}" .
ParamList      = Param { "," Param } .
Param          = ident ":" TypeName .
TypeName       = "string" | "int" | "bool" | "node" | "list" .

ConstBlock     = "const" "{" { ConstDecl } "}" .
ConstDecl      = ident "=" Expression ";" .

EnumDecl       = "enum" ident "{" ident { "," ident } "}" .

FragmentDecl   = "fragment" ident "{" { TopLevelBlock } "}" .
ImportStmt     = "import" string ";" .
IncludeStmt    = "include" ident ";" .
GuardBlock     = "guard" Expression "{" { TopLevelBlock | TokenDecl | TypeDecl } "}" .
```


### Complete TLangConfig API Coverage

Every public `TLangConfig` method mapped to its Metamorf construct:

| TLangConfig Method | Metamorf Construct |
|-------------------|-------------------|
| `CaseSensitiveKeywords(bool)` | `tokens { casesensitive = true; }` |
| `IdentifierStart(chars)` | `tokens { identifier_start = "chars"; }` |
| `IdentifierPart(chars)` | `tokens { identifier_part = "chars"; }` |
| `AddKeyword(text, kind)` | `token keyword.name = "text";` |
| `AddOperator(text, kind)` | `token op.name = "text";` or `token delimiter.name = "text";` |
| `AddLineComment(prefix)` | `token comment.line = "prefix";` |
| `AddBlockComment(open, close)` | `token comment.block_open` + `token comment.block_close` pair |
| `AddStringStyle(open, close, kind, esc)` | `token string.kind = "open" [noescape, close "close"];` |
| `SetHexPrefix(prefix, kind)` | `tokens { hex_prefix = "prefix"; }` |
| `SetBinaryPrefix(prefix, kind)` | `tokens { binary_prefix = "prefix"; }` |
| `SetDirectivePrefix(prefix, kind)` | `tokens { directive_prefix = "prefix"; }` |
| `AddDirective(name, kind, role)` | `token directive.kind = "name" [role];` |
| `SetStatementTerminator(kind)` | `tokens { terminator = kind; }` |
| `SetBlockOpen(kind)` | `tokens { block_open = kind; }` |
| `SetBlockClose(kind)` | `tokens { block_close = kind; }` |
| `RegisterLiteralPrefixes()` | Automatic after token block |
| `RegisterStatement(kind, node, handler)` | `grammar { rule stmt.name { ... } }` |
| `RegisterPrefix(kind, node, handler)` | `grammar { rule expr.name { ... } }` |
| `RegisterInfixLeft(kind, power, node, handler)` | `grammar { rule expr.name precedence left N { ... } }` |
| `RegisterInfixRight(kind, power, node, handler)` | `grammar { rule expr.name precedence right N { ... } }` |
| `RegisterBinaryOp(kind, power, op)` | Infix rule + `consume -> @operator` pattern |
| `RegisterSemanticRule(nodeKind, handler)` | `semantics { on nodeKind { ... } }` |
| `RegisterEmitter(nodeKind, handler)` | `emitters { on nodeKind { ... } }` |
| `RegisterTypeCompat(func)` | `types { compatible "from", "to" -> "coerce"; }` |
| `AddTypeKeyword(text, typeKind)` | `types { type text = "typeKind"; }` |
| `AddTypeMapping(source, target)` | `types { map "source" -> "target"; }` |
| `AddLiteralType(nodeKind, typeKind)` | `types { literal "nodeKind" = "typeKind"; }` |
| `AddDeclKind(nodeKind)` | `types { decl_kind "nodeKind"; }` |
| `AddCallKind(nodeKind)` | `types { call_kind "nodeKind"; }` |
| `SetCallNameAttr(attr)` | `types { call_name_attr = "attr"; }` |
| `SetNameMangler(func)` | `types { name_mangler = funcRef; }` |
| `RegisterExprOverride(nodeKind, handler)` | Expression emitter `on nodeKind { emit ...; }` |
| `SetTypeToIR(func)` | Automatic from `types { map ... }` entries |
| `SetModuleExtension(ext)` | `setModuleExtension("ext")` builtin |

### Token Kind Naming Conventions

| Category | Examples |
|----------|---------|
| `keyword.*` | `keyword.if`, `keyword.while`, `keyword.var`, `keyword.true` |
| `op.*` | `op.plus`, `op.assign`, `op.neq`, `op.deref` |
| `delimiter.*` | `delimiter.lparen`, `delimiter.semicolon`, `delimiter.dot` |
| `literal.*` | `literal.integer`, `literal.real`, `literal.hex`, `literal.binary` |
| `string.*` | `string.cstring`, `string.pascal`, `string.wstring` |
| `comment.*` | `comment.line`, `comment.block_open`, `comment.block_close` |
| `directive.*` | `directive.define`, `directive.ifdef`, `directive.optimize` |
| `type.*` | `type.int32`, `type.string`, `type.boolean` |
| `identifier` | (bare, no dot) |
| `eof` | (bare, no dot) |

### Node Kind Naming Conventions

| Category | Examples |
|----------|---------|
| `program.*` | `program.root` |
| `stmt.*` | `stmt.if`, `stmt.var_decl`, `stmt.routine_decl`, `stmt.module` |
| `expr.*` | `expr.ident`, `expr.call`, `expr.binary`, `expr.grouped` |
| `meta.*` | `meta.tokens_block`, `meta.grammar_block`, `meta.on_handler` |

The engine uses `program.root` as the root node kind. All other node kinds are yours to define.


## 🧭 Design Principles

These principles guide Metamorf's architecture and explain the reasoning behind its design decisions.

1. **Every construct maps to a `TLangConfig` API call.** The meta-language is a thin, readable surface over the engine's configuration API. There is no magic - everything Metamorf does is expressible as Delphi code. The `.mor` syntax exists for readability and productivity, not because it can do things the API cannot.

2. **Node-centric handlers.** Handlers always have an implicit current node in scope. Attribute access (`@name`) is the most common operation and gets the shortest syntax. This keeps handler bodies focused on logic rather than boilerplate.

3. **Two-phase architecture.** Phase 1: the bootstrap `TMetamorf` instance parses the `.mor` file. Phase 2: the configured `TMetamorf` instance compiles user source. Closures bridge the two phases. This separation is what makes `.mor` files self-contained - the meta-language and the target language never share a parser.

4. **C++ passthrough is automatic.** `ConfigCpp` handles all C++ tokens, grammar, and codegen. The `.mor` file never touches C++. This is why every Metamorf language gets C++ interop for free.

5. **Declarative and imperative in one language.** Grammar rule bodies combine declarative constructs (`expect`, `consume`, `parse`) with imperative constructs (`checkToken`, `advance`, `createNode`, loops, conditionals). Both are part of the same language — use whichever fits the structure you are parsing.

6. **IR builders for structured emission.** Emitter handlers use `func()`, `declVar()`, `ifStmt()`, etc. for type-safe C++ generation, not raw string concatenation. This produces consistently formatted output and eliminates an entire class of bracket-matching and indentation bugs.

7. **Routines for shared logic.** User-defined `routine` declarations avoid duplication across handlers. A type resolution routine written once can be called from every emitter that needs it.

8. **The meta-language is the blank canvas.** Metamorf has no built-in concept of "function", "variable", "class", or "module". It knows about tokens, grammar rules, scopes, symbols, and IR builders. Every language concept - from Pascal's `program/begin/end` to a hypothetical language with actors and channels - is defined entirely by the `.mor` file author. The engine provides the mechanics; you provide the meaning.

9. **Metamorf is CASE-SENSITIVE.** All keywords, identifiers, and attribute names are case-sensitive. This matches C/C++ and avoids ambiguity. `keyword.Begin` and `keyword.begin` are different token kinds.

10. **Turing complete by design.** Most language definition tools are deliberately not Turing complete — they give you a declarative grammar and then punt to a host language for anything complex. The `.mor` language has variables, unbounded loops, conditionals, recursion, and string/arithmetic operations as first-class constructs alongside declarative grammar rules. Every handler body uses the same unified language. No escape hatch to a host language, no build system integration, no glue code. A `.mor` file is self-contained.


## 💻 System Requirements

| | Requirement |
|---|---|
| **Host OS** | Windows 10/11 x64 |
| **Linux target** | WSL2 + Ubuntu (`wsl --install -d Ubuntu`) |
| **Building from source** | Delphi 12 Athens or later |


## 🛠️ Building from Source

1. Download the latest release from [GitHub Releases](https://github.com/tinyBigGAMES/Metamorf/releases) and extract it
2. Get the source - either clone or [download](https://github.com/tinyBigGAMES/Metamorf/archive/refs/heads/main.zip) the ZIP from the repo page:
   ```bash
   git clone https://github.com/tinyBigGAMES/Metamorf.git
   ```
3. Extract the source into the root of the release directory - this places the Delphi source alongside the build tools at their expected relative paths
4. Open `src\Metamorf - Language Engineering Platform.groupproj` in Delphi 12 Athens - this loads Metamorf and all sub-projects together
5. Build all projects in the group


## 🤝 Contributing, Support, and License

### Contributing

Metamorf is an open project. Whether you are fixing a bug, improving documentation, adding a new showcase language, or proposing a framework feature, contributions are welcome.

- **Report bugs**: Open an issue with a minimal reproduction. The smaller the example, the faster the fix.
- **Suggest features**: Describe the use case first, then the API shape you have in mind. Features that emerge from real problems get traction fastest.
- **Submit pull requests**: Bug fixes, documentation improvements, new language examples, and well-scoped features are all welcome. Keep changes focused.

Join the [Discord](https://discord.gg/Wb6z8Wam7p) to discuss development, ask questions, and share what you are building.

### Support the Project

Metamorf is built in the open. If it saves you time or sparks something useful:

- ⭐ **Star the repo**: it costs nothing and helps others find the project
- 🗣️ **Spread the word**: write a post, mention it in a community you are part of
- 💬 **[Join us on Discord](https://discord.gg/Wb6z8Wam7p)**: share what you are building and help shape what comes next
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)**: sponsorship directly funds time spent on Metamorf, documentation, and sub-projects
- 🦋 **[Follow on Bluesky](https://bsky.app/profile/tinybiggames.com)**: stay in the loop on releases and development

### License

Metamorf is licensed under the **Apache License 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/Metamorf/tree/main?tab=License-1-ov-file#readme) for details.

Apache 2.0 is a permissive open source license that lets you use, modify, and distribute Metamorf freely in both open source and commercial projects. You are not required to release your own source code. You can embed Metamorf into a proprietary product, ship it as part of a commercial tool, or build a closed-source language on top of it without restriction. The license includes an explicit patent grant. Attribution is required - keep the copyright notice and license file in place.

### Links

- [metamorf.dev](https://metamorf.dev)
- [Discord](https://discord.gg/Wb6z8Wam7p)
- [Bluesky](https://bsky.app/profile/tinybiggames.com)
- [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**Metamorf™** - Define It. Compile It. Ship It.

Copyright &copy; 2025-present tinyBigGAMES™ LLC<br/>All Rights Reserved.

</div>

