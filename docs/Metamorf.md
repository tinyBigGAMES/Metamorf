![Metamorf](../media/logo.png)

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Architecture](#architecture)
4. [File Structure](#file-structure)
5. [Tokens Block](#tokens-block)
6. [Types Block](#types-block)
7. [Grammar Block](#grammar-block)
8. [Semantics Block](#semantics-block)
9. [Emitters Block](#emitters-block)
10. [The Imperative Language](#the-imperative-language)
11. [Routines and Constants](#routines-and-constants)
12. [Fragments, Imports, and Includes](#fragments-imports-and-includes)
13. [Built-in Functions Reference](#built-in-functions-reference)
14. [C++ Passthrough](#c-passthrough)
15. [Formal Grammar (EBNF)](#formal-grammar-ebnf)
16. [Design Principles](#design-principles)
17. [System Requirements](#system-requirements)
18. [Building from Source](#building-from-source)
19. [Contributing, Support, and License](#contributing-support-and-license)


## Overview

Metamorf is a language engineering platform. You describe a complete programming language in a `.mor` file, then compile source files written in that language to native Win64/Linux64 binaries. One file defines your language. One command compiles your program:

```bash
Metamorf -l pascal.mor -s hello.pas -r
```

A `.mor` file covers the full compiler pipeline: lexer tokens, Pratt parser grammar, multi-pass semantic analysis, and C++23 code generation. The result is a native binary built via Zig/Clang.

**Who is this manual for?** You are a developer who wants to define a programming language using Metamorf. You know what a lexer, parser, and AST are. You do not need to be a compiler expert, but you should be comfortable reading code and thinking about how source text becomes structured data.

**Turing complete by design.** Most language definition tools (YACC, ANTLR, traditional BNF grammars) give you a declarative grammar and then punt to a host language for anything non-trivial. Metamorf is a complete, unified compiler-construction language. It has variables, assignment, unbounded loops, conditionals, arithmetic, string operations, and user-defined routines with recursion. All of these are first-class constructs alongside declarative grammar rules and token definitions. Every handler body uses the same unified language.

No host language glue code. No build system integration. No escape hatch to C, Java, or Python. A single `.mor` file is a complete, portable, standalone language specification that produces native binaries.

**What Metamorf provides:**

- **Single-file language definitions** covering the entire pipeline: lexer tokens, Pratt parser grammar, semantic analysis, and C++23 code generation
- **Turing complete language** with variables, loops, conditionals, recursion, and string operations as first-class constructs
- **Pratt parser grammar rules** with declarative prefix/infix/statement patterns and full imperative constructs for complex parsing
- **Multi-pass semantic analysis** with scope management, symbol declaration, forward reference resolution, and overload detection
- **IR builder code generation** producing structured C++23 through `func()`, `declVar()`, `ifStmt()`, and similar typed builders
- **Automatic C++ passthrough** so your language can interoperate with C/C++ without any `.mor` configuration
- **Modular language definitions** via `import` statements, `fragment` blocks, and `include` directives
- **Source-level build configuration** through directives (platform, optimization, version info, icon embedding)
- **Native binary output** for Win64 and Linux64 via Zig/Clang, with cross-compilation through WSL2


## Getting Started

### Using Metamorf

Metamorf ships as a self-contained release with everything included. No separate toolchain download, no configuration.

1. Download the latest release from [GitHub Releases](https://github.com/tinyBigGAMES/Metamorf/releases)
2. Extract the archive to any directory
3. Write a `.mor` language definition and a source file, then compile:

```bash
Metamorf -l pascal.mor -s hello.pas
```

The `-l` flag specifies the language definition file. The `-s` flag specifies the source file to compile. The resulting native binary is placed in the output directory.

### CLI Reference

```
Metamorf [options] -l <file> -s <file> [options]

REQUIRED:
  -l, --lang    <file>   Language definition file (.mor)
  -s, --source  <file>   Source file to compile

OPTIONS:
  -o, --output  <path>   Output path (default: output)
  -r, --autorun          Build and run the compiled binary
  -h, --help             Display help message
```

**Examples:**

```bash
Metamorf -l mylang.mor -s hello.src
Metamorf -l mylang.mor -s hello.src -o build
Metamorf -l mylang.mor -s hello.src -r
```

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

Clone the repository:

```bash
git clone https://github.com/tinyBigGAMES/Metamorf.git
```

The repository is organized as:

```
Metamorf/repo/
  src/                          <- Metamorf compiler sources
  tests/                        <- Test .mor files and source files
  docs/                         <- Reference documentation
  bin/                          <- Executables run from here
```


## Architecture

Metamorf compiles your language in a single pass through a table-driven pipeline. The `.mor` file is parsed first, and its contents populate a set of dispatch tables (token registrations, grammar rules, semantic handlers, emitters). These tables then drive the compilation of your user source files.

```
  SETUP
  ┌─────────────┐    ┌────────────┐    ┌────────────┐    ┌─────────┐
  │ mylang.mor  │───►│ .mor Lexer │───►│.mor Parser │───►│.mor AST │
  └─────────────┘    └────────────┘    └────────────┘    └────┬────┘
                                                              │
                                               ┌──────────────┴───────────┐
                                               │  Interpreter walks       │
                                               │  AST and populates:      │
                                               │                          │
                                               │  · Token registers       │
                                               │  · Grammar rules         │
                                               │  · Semantic handlers     │
                                               │  · Emitter handlers      │
                                               │  · Routines/consts       │
                                               └──────────────┬───────────┘
                                                              │
                                               ┌──────────────┴───────────┐
                                               │  C++ passthrough         │
                                               │  registered              │
                                               └──────────────┬───────────┘
                                                              │
  COMPILATION                                                 │
                                                              │
                                                              ▼
  ┌─────────────────┐    ┌───────────────┐    ┌───────────────────┐
  │ myprogram.src   │───►│ Generic Lexer │───►│  Generic Parser   │
  └─────────────────┘    │ (table-driven)│    │ (Pratt dispatch)  │
                         └───────────────┘    └─────────┬─────────┘
                                                        │
                                              ┌─────────┴─────────┐
                                              │ Semantic Analysis │
                                              │ (multi-pass,      │
                                              │  scopes, symbols) │
                                              └─────────┬─────────┘
                                                        │
                                              ┌─────────┴─────────┐
                                              │ Code Generation   │
                                              │ (emitters ► C++23)│
                                              └─────────┬─────────┘
                                                        │
                                              ┌─────────┴─────────┐
                                              │  .h + .cpp files  │
                                              └─────────┬─────────┘
                                                        │
                                              ┌─────────┴─────────┐
                                              │ Zig/Clang build   │
                                              └─────────┬─────────┘
                                                        │
                                              ┌─────────┴─────────┐
                                              │  Native binary    │
                                              │ (Win64/Linux64)   │
                                              └───────────────────┘
```

### Setup Phase

The `.mor` file is tokenized and parsed by a dedicated .mor lexer and parser (hard-coded, not table-driven). The resulting AST is walked by the interpreter, which populates dispatch tables: keywords, operators, string styles, comment markers, directives, grammar rules (prefix, infix, statement), semantic handlers, emitter handlers, user-defined routines, constants, enum values, and fragments.

After the .mor setup completes, C++ passthrough tokens, grammar handlers, and emit handlers are registered automatically. This is why every Metamorf language gets C++ interop for free without any `.mor` configuration.

### Compilation Phase

With dispatch tables populated, the engine compiles user source files:

1. **Generic Lexer** tokenizes user source using the registered keywords, operators, string styles, comments, and directives. This lexer is entirely table-driven; it reads its configuration from the interpreter's dispatch tables.

2. **Generic Parser** is a Pratt parser that dispatches to grammar rules registered during setup. Prefix rules handle tokens that start an expression (identifiers, literals, unary operators). Infix rules handle binary operators with precedence and associativity. Statement rules handle language constructs (if, while, declarations). Each grammar rule is an AST node from the `.mor` file that the interpreter executes on demand.

3. **Semantic Analysis** walks the user AST and executes semantic handlers. Handlers manage scopes, declare symbols, resolve references, and check types. Multi-pass semantics are supported for forward reference resolution.

4. **Code Generation** executes emitter handlers for each AST node. Emitters produce structured C++23 through IR builder functions (`func()`, `declVar()`, `ifStmt()`, etc.) into separate header and source buffers. Output is written to `.h` and `.cpp` files.

5. **Build** generates a `build.zig` file and invokes Zig/Clang to produce a native binary.

### Module Compilation

When a semantic handler calls `compileModule(name)`, the engine resolves the module file (using the extension set by `setModuleExtension()`), lexes and parses it into a new AST branch, attaches that branch to the master root, and runs semantic analysis on it. This can trigger further module compilations recursively.

The master AST has a single `master.root` node with one branch per source file. The main program is always branch 0; imported modules are branches 1, 2, etc. Emitters process module branches first, then the main program branch, so that the main program's build settings (exe mode) take effect last.

### .mor Imports

The `.mor` language supports modular language definitions via `import "file.mor"`. When the interpreter encounters an import, the engine lexes and parses the imported `.mor` file, adds its AST to a .mor master root (for lifetime management), and continues setup. Imported `.mor` files can contain any top-level block: tokens, types, grammar, semantics, emitters, routines, constants, or fragments. This enables splitting large language definitions across multiple files.


## File Structure

A `.mor` file begins with a `language` declaration and contains top-level blocks that describe each aspect of your language. Comments use `//` (line) and `/* ... */` (block). Here is the overall shape:

```mor
language MyLang version "1.0";

// Optional: constants must appear before they are referenced
const {
  ENABLE_FEATURE = true;
}

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
  // Optional: multi-pass with pass N "name" { ... } blocks
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
  MAX_PARAMS = 16;
}

// Enum declarations
enum BuildMode { exe, lib, dll }
```

### Source Unit Map

The Metamorf compiler is built from these Delphi source units:

| Unit | Purpose |
|------|---------|
| `Metamorf.Engine.pas` | `TMorEngine`: single entry point, orchestrates the full compilation pipeline |
| `Metamorf.CLI.pas` | `TMorCLI`: command-line interface (`-l`, `-s`, `-o`, `-r` flags) |
| `Metamorf.Lexer.pas` | `TMorLexer`: tokenizes `.mor` source files |
| `Metamorf.Parser.pas` | `TMorParser`: parses `.mor` source into an AST |
| `Metamorf.Interpreter.pas` | `TMorInterpreter`: walks `.mor` AST, populates dispatch tables, executes grammar/semantic/emit handlers at compile time |
| `Metamorf.GenericLexer.pas` | `TGenericLexer`: table-driven lexer for user source files |
| `Metamorf.GenericParser.pas` | `TGenericParser`: Pratt parser for user source, dispatches to `.mor` grammar rules |
| `Metamorf.CodeGen.pas` | `TCodeOutput`: C++ code generation with header/source buffers, indentation, and capture mode |
| `Metamorf.Scopes.pas` | `TScopeManager`, `TScope`, `TSymbol`: symbol table for user-language semantic analysis |
| `Metamorf.AST.pas` | `TASTNode`, `TToken`: universal AST nodes with string attributes and named children |
| `Metamorf.Environment.pas` | `TEnvironment`: variable scope stack for `.mor` interpreter runtime |
| `Metamorf.Cpp.pas` | `ConfigCpp()`: registers C++ passthrough tokens, grammar, and emitters after `.mor` setup |
| `Metamorf.Build.pas` | `TBuild`: generates `build.zig`, invokes Zig/Clang, handles version info and post-build resources |
| `Metamorf.Common.pas` | `ReportNodeError()`: helper for positioned error reporting |
| `Metamorf.Utils.pas` | `TBaseObject`, `TErrorsObject`, `TErrors`, `TUtils`: base class hierarchy and utilities |
| `Metamorf.Resources.pas` | Resource strings for all user-facing messages |
| `Metamorf.Config.pas` | Configuration constants |
| `Metamorf.TOML.pas` | TOML parser for build configuration files |
| `UMetamorf.pas` | Main testbed/entry point unit |


## Tokens Block

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


## Types Block

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


## Grammar Block

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

Grammar rule bodies use two sets of constructs from the same language. Declarative constructs (`expect`, `consume`, `parse`) handle regular structure concisely. Imperative constructs (`checkToken`, `advance`, `createNode`, `addChild`, `while`, `if`) handle irregular structure with full control. Both are first-class  --  neither is primary and neither is a fallback. The `stmt.var_decl` example below uses both naturally: it starts with `expect keyword.var;` and then uses token-by-token parsing with `checkToken`, `advance`, `createNode`, and `addChild` for the irregular variable list. Most real languages mix both freely for constructs like variable declaration blocks, function parameter lists, and import statements.

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


### Required: Number Literal Grammar Rules

The generic lexer automatically produces `literal.integer` and `literal.float` tokens for numeric values in user source files. However, the generic parser requires explicit prefix grammar rules to consume these tokens. Without them, any expression containing a number literal (e.g., `if n <= 1`) fails with `Error UP002: Unexpected token in expression`.

Every `.mor` language definition that uses numeric literals MUST include these grammar rules and emitter handlers:

```mor
grammar {
  rule expr.integer {
    consume literal.integer -> @value;
  }
  rule expr.float {
    consume literal.float -> @value;
  }
}

emitters {
  on expr.integer {
    emit @value;
  }
  on expr.float {
    emit @value;
  }
}
```

These are not optional. The generic lexer produces the tokens automatically; the grammar must declare how to consume them and the emitters must declare how to output them.

If you also use a type system, register the literal types:

```mor
types {
  literal "expr.integer" = "type.integer";
  literal "expr.float"   = "type.single";
}
```


## Semantics Block

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


### Multi-Pass Semantics and C++ Forward Declarations

Multi-pass semantics solve forward references at the Metamorf level: pass 1 declares all symbols, and pass 2 can look them up regardless of source order. However, the generated C++ still emits functions in source order, and C++ has its own forward reference rules. Without explicit C++ forward declarations, forward references will pass semantic analysis but fail C++ compilation.

The correct pattern requires both pieces:

1. **Semantic passes** (described above): `pass 1` declares, `pass 2` resolves. Scope trees persist across passes; the scope stack resets to the root between passes.

2. **Emitter forward declarations**: The emitter's root handler must emit C++ forward declarations for all functions BEFORE emitting their full definitions.

Here is the complete pattern from `testbed.mor`, which enables function A to call function B even when B is declared after A:

```mor
semantics {
  pass 1 "declarations" {
    on program.root {
      scope "global" { visit children; }
    }
    on stmt.func_decl {
      declare @func_name as routine;
    }
    on stmt.var_decl { visit children; }
    on stmt.single_var { declare @vname as variable; }
  }

  pass 2 "analysis" {
    on program.root {
      scope "global" { visit children; }
    }
    on stmt.func_decl {
      scope @func_name { visit children; }
    }
    on stmt.ident_stmt { visit children; }
    on expr.call { visit children; }
    on expr.ident { }
  }
}

emitters {
  on program.root {
    emitLine("#include <cstdint>");
    emitLine("#include <print>");

    // Forward declarations (enables C++ forward refs)
    let i = 0;
    let n = child_count();
    while i < n {
      let ch = getChild(node, i);
      if nodeKind(ch) == "stmt.func_decl" {
        let retType = typeToIR(typeTextToKind(getAttr(ch, "return_type")));
        let fname = getAttr(ch, "func_name");
        let sig = retType + " " + fname + "(";
        let pi = 0;
        let pc = childCount(ch) - 2;
        while pi < pc {
          let p = getChild(ch, pi);
          if pi > 0 { sig = sig + ", "; }
          sig = sig + typeToIR(typeTextToKind(getAttr(p, "param.type_text")))
                + " " + getAttr(p, "param.name");
          pi = pi + 1;
        }
        sig = sig + ");";
        emitLine(sig);
      }
      i = i + 1;
    }

    // Then emit full function definitions
    i = 0;
    while i < n {
      let ch = getChild(node, i);
      if nodeKind(ch) == "stmt.func_decl" {
        emitNode(ch);
      }
      i = i + 1;
    }

    // ... emit main block, etc.
  }
}
```

The test source (`testbed.pas`) demonstrates this:

```pascal
program Testbed;

function A(x: integer): integer;
begin
  Result := B(x + 1);   // B is declared AFTER A
end;

function B(x: integer): integer;
begin
  Result := x * 2;
end;

begin
  WriteLn("A(5) = {}", A(5));
end.
```

Without multipass semantics, the compiler would report "undefined identifier 'B'" when analyzing function A. Without the C++ forward declarations in the emitter, the C++ compiler would fail because `B` is not yet declared when `A`'s body references it. Both pieces are required.

For a more advanced example with unit-mode header forward declarations, see `pascal2_emitters.mor` (the "Pass 1.5: header forward declarations" pattern).


## Emitters Block

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


## The Imperative Language

The `.mor` language is Turing complete. Every handler body  --  grammar rules, semantic handlers, emitters  --  has access to variables, unbounded loops, conditionals, recursion, and string/arithmetic operations as first-class constructs. These are not a separate scripting layer bolted onto a declarative core; they are part of one unified language. When your grammar rule needs custom parsing logic, or your emitter needs 100 lines of conditional code generation, you write it in the same language as everything else. No escape hatch to a host language, no build system integration, no glue code. A `.mor` file is self-contained.

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


## Routines and Constants

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


## Fragments, Imports, and Includes

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


## Built-in Functions Reference

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


## C++ Passthrough

Every language defined in Metamorf automatically gets C++ interoperability. After the `.mor` setup phase completes, the engine registers C++ keywords, operators, delimiters, grammar handlers, and emit handlers into the dispatch tables. These registrations happen after your custom language rules, so your keywords always take priority over C++ ones.

The passthrough uses raw token collection with brace-depth tracking. When the parser encounters a C++ construct (a `#include` directive, a C++ function definition, a `using` declaration, etc.), the registered handlers vacuum up tokens until the construct is balanced. The collected text is emitted verbatim into the generated C++ output.

This means your language can freely intermix with C++ without any `.mor` configuration. Users can write C++ `#include` directives, define C++ functions, use C++ types, and call C++ library functions directly in their source files. The passthrough handles all of this transparently.

**What gets registered automatically:**

- All 62 C++ keywords (`auto`, `bool`, `break`, `class`, `const`, `if`, `int`, `namespace`, `return`, `struct`, `template`, `void`, `while`, etc.) as `cpp.keyword.*` token kinds, but only for keywords not already claimed by your language
- C++ operators: `::` (`cpp.op.scope`), `->` (`cpp.op.arrow`), `++` (`cpp.op.increment`), `--` (`cpp.op.decrement`), `<<` (`cpp.op.shl`), `>>` (`cpp.op.shr`), `&&` (`cpp.op.logand`), `||` (`cpp.op.logor`), `==` (`cpp.op.eq`), `!=` (`cpp.op.neq`), `%` (`cpp.op.modulo`), `~` (`cpp.op.bitnot`), `&` (`cpp.op.bitand`), `|` (`cpp.op.bitor`), `^` (`cpp.op.bitxor`), `!` (`cpp.op.lognot`), `#` (`cpp.op.hash`)
- C++ delimiters: `{` (`delimiter.lbrace`), `}` (`delimiter.rbrace`), `[` (`delimiter.lbracket`), `]` (`delimiter.rbracket`)
- Grammar handlers for C++ statements (preprocessor directives, extern blocks, namespace blocks, class/struct definitions, etc.)
- Emit handlers that output collected C++ text verbatim

All C++ operators and delimiters are registered unconditionally. C++ keywords are registered only if the custom language has not already claimed them. The operator list is re-sorted longest-first after registration, so multi-character operators like `::` and `->` always match before their single-character components.

### The Golden Rule: Do Not Redeclare C++ Tokens

C++ passthrough works because ConfigCpp owns all C++ tokens. Your custom language must not re-register them. This is the single most important rule for C++ passthrough, and violating it produces confusing errors.

**What happens if you break this rule:**

If your `.mor` file declares `token op.percent = "%"` and ConfigCpp also registers `%` as `cpp.op.modulo`, both entries end up in the operator list. After the longest-first sort, the order among same-length operators is unpredictable. Your grammar rule that expects `op.percent` may receive `cpp.op.modulo` instead, causing parser errors like `Expected op.percent but found '%'` or `Expected delimiter.rparen but found '%'`.

**The correct pattern:** If your language needs `%` for modulo, do not register it as a token. Instead, reference ConfigCpp's kind directly in your grammar rule:

```mor
// WRONG: re-registers % with a conflicting kind
tokens {
  token op.percent = "%";    // <-- DO NOT DO THIS
}
grammar {
  rule expr.mul precedence left 30 {
    consume [op.star, op.slash, op.percent] -> @operator;
    parse expr -> @right;
  }
}

// CORRECT: use the cpp.op.* kind that ConfigCpp provides
grammar {
  rule expr.mul precedence left 30 {
    consume [op.star, op.slash, cpp.op.modulo] -> @operator;
    parse expr -> @right;
  }
}
```

This applies to all C++ operators: `==` is `cpp.op.eq`, `!=` is `cpp.op.neq`, `%` is `cpp.op.modulo`, `->` is `cpp.op.arrow`, and so on. See the full list in the "What gets registered" section above.

### Do Not Use C++ Keywords as Type Names

C++ keywords like `int`, `bool`, `float`, `void`, `double`, `char`, `long`, `short`, `signed`, `unsigned` are registered by ConfigCpp as `cpp.keyword.*` token kinds. If your language uses these words as type names (e.g., `fn add(x: int) -> int`), the lexer will tokenize `int` as `cpp.keyword.int` instead of `identifier`, and grammar rules that expect an identifier will fail with errors like `expected identifier, got cpp.keyword.int`.

**The fix:** Use non-conflicting type names. For example, MyLang uses `i64` instead of `int`, `boolean` instead of `bool`, and `f64` instead of `float`:

```mor
// WRONG: int is a C++ keyword, will be tokenized as cpp.keyword.int
fn add(x: int) -> int { ... }

// CORRECT: i64 is not a C++ keyword, tokenizes as identifier
fn add(x: i64) -> i64 { ... }
```

Your `resolveType()` routine maps these custom names to C++ types in the emitter:

```mor
routine resolveType(typeText: string) -> string {
  if typeText == "i64"     { return "int64_t"; }
  if typeText == "boolean" { return "bool"; }
  if typeText == "f64"     { return "double"; }
  if typeText == "string"  { return "std::string"; }
  return typeText;
}
```

Note: If your language explicitly registers a C++ keyword as its own keyword (e.g., `token keyword.int = "int"`), ConfigCpp will not override it. The conflict only occurs when the word is used as an identifier without being registered as a keyword.

### Block Comments and Brace Conflicts

The generic lexer processes comments before operators. If your language uses `{ }` as block comment delimiters (as traditional Pascal does), the lexer will consume every `{` as a comment opener before the operator table ever sees it. This means C++ brace-delimited constructs (function bodies, struct definitions, initializer lists) will not parse in passthrough mode.

**The fix:** Use `//` for line comments and `/* */` for block comments:

```mor
tokens {
  token comment.line        = "//";
  token comment.block_open  = "/*";     // NOT "{"
  token comment.block_close = "*/";     // NOT "}"
}
```

This is why `pascal.mor` uses `/* */` instead of `{ }` for block comments, even though standard Pascal supports both.

### Brace-Delimited Languages

Languages that use `{ }` for code blocks (like C-family languages) do not need to register braces as tokens. ConfigCpp provides them automatically as `delimiter.lbrace` and `delimiter.rbrace`. Reference these kinds directly in your grammar rules:

```mor
grammar {
  rule stmt.if {
    expect keyword.if;
    parse expr -> @condition;
    expect delimiter.lbrace;             // from ConfigCpp
    parse many stmt until delimiter.rbrace -> @body;
    expect delimiter.rbrace;             // from ConfigCpp
  }
}
```

See `mylang.mor` for a complete example of a brace-delimited language using ConfigCpp's delimiter kinds.

### Comment Delimiters That Overlap C++ Operators

Some languages use tokens that are also C++ operators as comment delimiters. For example, Lua uses `--` for line comments, but `--` is also the C++ decrement operator. This is acceptable: the lexer processes comments before operators, so `--` at the start of a line will always be consumed as a comment. The tradeoff is that C++ `x--` decrement will not work in Lua passthrough mode. This is usually acceptable because the custom language does not use `--` as an operator.

### S-Expression Languages

For languages with fundamentally different syntax (like Scheme), where `(` starts both language forms and C++ constructs, the standard grouped-expression pattern does not work for passthrough. These languages use `collectRaw()` with depth tracking instead. See `scheme.mor` for this approach.

### Quick Reference: Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Unexpected character: '{'` | `{ }` not registered as tokens | ConfigCpp provides them; do not use `{ }` as block comments |
| `Unexpected character: '%'` | `%` not registered as a token | Use `cpp.op.modulo` in grammar rules, do not re-register |
| `Expected identifier, got cpp.keyword.int` | C++ keyword used as type name | Use non-conflicting names (`i64`, `boolean`, `f64`) |
| `Expected op.percent but found '%'` | `%` registered with conflicting kind | Remove your token declaration, use `cpp.op.modulo` |
| `Expected delimiter.rparen but found '%'` | Parser sees `cpp.op.modulo`, no infix rule for it | Add infix rule for `cpp.op.modulo` |


## Formal Grammar (EBNF)

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


## Design Principles

These principles guide Metamorf's architecture and explain the reasoning behind its design decisions.

1. **The .mor file is the program.** A `.mor` file is not a configuration script or a settings file. It is a complete, self-contained program that defines a compiler. The interpreter executes it, populating dispatch tables that drive the compilation of user source files.

2. **Node-centric handlers.** Handlers always have an implicit current node in scope. Attribute access (`@name`) is the most common operation and gets the shortest syntax. This keeps handler bodies focused on logic rather than boilerplate.

3. **Table-driven compilation.** The `.mor` interpreter populates dispatch tables during setup. The generic lexer, parser, semantic engine, and emitter all read from these tables. This separation means the `.mor` language and the target language never share a parser.

4. **C++ passthrough is automatic.** `ConfigCpp` handles all C++ tokens, grammar, and codegen after `.mor` setup. The `.mor` file never touches C++. This is why every Metamorf language gets C++ interop for free.

5. **Declarative and imperative in one language.** Grammar rule bodies combine declarative constructs (`expect`, `consume`, `parse`) with imperative constructs (`checkToken`, `advance`, `createNode`, loops, conditionals). Both are part of the same language. Use whichever fits the structure you are parsing.

6. **IR builders for structured emission.** Emitter handlers use `func()`, `declVar()`, `ifStmt()`, etc. for type-safe C++ generation, not raw string concatenation. This produces consistently formatted output and eliminates an entire class of bracket-matching and indentation bugs.

7. **Routines for shared logic.** User-defined `routine` declarations avoid duplication across handlers. A type resolution routine written once can be called from every emitter that needs it.

8. **The meta-language is the blank canvas.** Metamorf has no built-in concept of "function", "variable", "class", or "module". It knows about tokens, grammar rules, scopes, symbols, and IR builders. Every language concept is defined entirely by the `.mor` file author. The engine provides the mechanics; you provide the meaning.

9. **Metamorf is CASE-SENSITIVE.** All keywords, identifiers, and attribute names in the `.mor` language are case-sensitive. This matches C/C++ and avoids ambiguity. `keyword.Begin` and `keyword.begin` are different token kinds.

10. **Turing complete by design.** The `.mor` language has variables, unbounded loops, conditionals, recursion, and string/arithmetic operations as first-class constructs alongside declarative grammar rules. Every handler body uses the same unified language. No escape hatch to a host language, no build system integration, no glue code. A `.mor` file is self-contained.


## System Requirements

| | Requirement |
|---|---|
| **Host OS** | Windows 10/11 x64 |
| **Linux target** | WSL2 + Ubuntu (`wsl --install -d Ubuntu`) |
| **Building from source** | Delphi 12 or higher |


## Building from Source

Each release includes the full source alongside the binaries. No separate download required.

1. Download the latest release from [GitHub Releases](https://github.com/tinyBigGAMES/Metamorf/releases) and extract it
2. Open `src\Metamorf - Language Engineering Platform.groupproj` in Delphi 12 or higher
3. Build the project


## Contributing, Support, and License

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
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)**: sponsorship directly funds time spent on Metamorf and its documentation
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

