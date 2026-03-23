<div align="center">

![Metamorf](../media/logo.png)

# DelphiFmt

**Delphi Source Code Formatter**

</div>

## 📖 Table of Contents

1. [Overview](#-overview)
2. [Getting Started](#-getting-started)
3. [Architecture](#-architecture)
4. [Formatting Options](#-formatting-options)
5. [API Reference](#-api-reference)
6. [Format Result](#-format-result)
7. [Examples](#-examples)
8. [Version Constants](#-version-constants)
9. [System Requirements](#-system-requirements)


## 🌟 Overview

DelphiFmt is a source code formatter for Delphi. It parses `.pas`, `.dpr`, `.dpk`, and `.inc` files into an abstract syntax tree using the Metamorf engine, then reconstructs the source from that tree using a configurable set of formatting rules. The result is consistently styled code with no manual effort.

**Who is this for?** You are a Delphi developer who wants automated, repeatable formatting across your codebase. You might be enforcing a team style guide, cleaning up legacy code, or integrating formatting into a build pipeline. DelphiFmt gives you fine-grained control over indentation, spacing, line breaks, capitalization, and alignment, all through a single options record.

**What you get:**

- Format source strings in memory, individual files on disk, or entire folder trees in one call
- Over 75 configurable formatting options organized into five logical groups: indentation, spacing, line breaks, capitalization, and alignment
- Sensible Castalia-style defaults that work out of the box
- Encoding-aware file handling that preserves UTF-8, UTF-16 LE, and ANSI encodings
- Idempotent formatting: running the formatter on already-formatted source produces identical output
- Optional `.bak` backup creation before overwriting files


## 🚀 Getting Started

The simplest way to use DelphiFmt is to create an instance, grab the default options, and call one of the three formatting methods.

### Format a source string in memory

```delphi
var
  LFmt: TDelphiFmt;
  LOptions: TDelphiFmtOptions;
  LFormatted: string;
begin
  LFmt := TDelphiFmt.Create();
  try
    LOptions := LFmt.DefaultOptions();
    LFormatted := LFmt.FormatSource(MySourceCode, LOptions);
    // LFormatted now contains the formatted version
  finally
    LFmt.Free();
  end;
end;
```

### Format a single file on disk

```delphi
var
  LFmt: TDelphiFmt;
  LOptions: TDelphiFmtOptions;
  LResult: TDelphiFmtFormatResult;
begin
  LFmt := TDelphiFmt.Create();
  try
    LOptions := LFmt.DefaultOptions();
    LResult := LFmt.FormatFile('C:\MyProject\MyUnit.pas', LOptions);
    if not LResult.Success then
      Writeln('Error: ', LResult.ErrorMsg)
    else if LResult.Changed then
      Writeln('File was reformatted.')
    else
      Writeln('File was already correctly formatted.');
  finally
    LFmt.Free();
  end;
end;
```

### Format an entire folder

```delphi
var
  LFmt: TDelphiFmt;
  LOptions: TDelphiFmtOptions;
  LResults: TArray<TDelphiFmtFormatResult>;
  LR: TDelphiFmtFormatResult;
begin
  LFmt := TDelphiFmt.Create();
  try
    LOptions := LFmt.DefaultOptions();
    LResults := LFmt.FormatFolder('C:\MyProject\src', LOptions);
    for LR in LResults do
    begin
      if not LR.Success then
        Writeln('FAIL: ', LR.FilePath, ' - ', LR.ErrorMsg)
      else if LR.Changed then
        Writeln('Changed: ', LR.FilePath);
    end;
  finally
    LFmt.Free();
  end;
end;
```


## ⚙️ Architecture

DelphiFmt is built on top of Metamorf's lexer and parser infrastructure. When you call any formatting method, the following pipeline executes:

```
Source text
    │
    ▼
ConfigLexer(TMetamorf)     ← Configure Delphi token definitions
ConfigGrammar(TMetamorf)   ← Configure Delphi grammar rules
    │
    ▼
TLexer.Tokenize()          ← Break source into tokens
    │
    ▼
TParser.ParseTokens()      ← Build abstract syntax tree
    │
    ▼
TDelphiFmtEmitter.FormatTree()  ← Walk AST, emit formatted source
    │                              using TDelphiFmtOptions
    ▼
Formatted source text
```

The formatter creates a fresh `TMetamorf` instance for each call, configures it with Delphi-specific lexer and grammar rules, tokenizes the input, parses it into an AST, then walks that AST through a formatting emitter that applies your options record. If parsing fails (for example, the source has syntax errors), the original source is returned unchanged.

File-level operations add encoding detection on top of this pipeline. `FormatFile` reads the raw bytes, detects whether the file is UTF-8, UTF-16 LE, UTF-16 BE, or ANSI, strips any BOM, runs the formatting pipeline, then writes back using the original encoding.


## 🎛️ Formatting Options

All formatting behavior is controlled through `TDelphiFmtOptions`, a record that groups five sub-records: `Indentation`, `Spacing`, `LineBreaks`, `Capitalization`, and `Alignment`. Call `TDelphiFmt.DefaultOptions()` to get a pre-populated baseline using Castalia-style defaults, then adjust individual fields before passing the record to a formatting method.

### Option Enums

Before diving into the option records, here are the enum types used throughout.

**TDelphiFmtSpacingOption** controls spacing around a syntactic element (colon, comma, semicolon, operator): `spNone` (no space), `spBeforeOnly`, `spAfterOnly`, `spBeforeAndAfter`.

**TDelphiFmtSpacingOptionEx** extends the above with a fifth value: `spxNone`, `spxBeforeOnly`, `spxAfterOnly`, `spxBeforeAndAfter`, `spxInnerAndOuter` (adds space both inside and outside the element, such as within parentheses and around them).

**TDelphiFmtYesNoOption** is a simple toggle: `ynoYes` (enabled), `ynoNo` (disabled).

**TDelphiFmtYesNoAsIsOption** adds a preserve mode: `ynaYes` (enabled), `ynaNo` (disabled), `ynaAsIs` (keep whatever the source already has).

**TDelphiFmtCapitalizationOption** controls casing: `capUpperCase`, `capLowerCase`, `capAsIs` (preserve), `capAsFirstOccurrence` (normalize to match the first occurrence in the file).

**TDelphiFmtLabelIndentOption** controls label indentation: `liDecreaseOneIndent` (one level less than surrounding code), `liNoIndent` (flush left), `liNormalIndent` (same level as surrounding code).

**TDelphiFmtLineBreakCharsOption** controls line endings: `lbcSystem` (OS default), `lbcCRLF` (Windows), `lbcLF` (Unix/macOS), `lbcCR` (legacy Mac).

**TDelphiFmtSpacingConflictOption** resolves contradictory spacing rules at the same position: `scSpace` (insert a space), `scNoSpace` (insert nothing).

### Indentation Options (`TDelphiFmtIndentationOptions`)

These options control how code blocks, keywords, and constructs are indented in the formatted output.

| Field | Type | Default | Description |
|---|---|---|---|
| `ContinuationIndent` | `Integer` | `2` | Extra spaces for continuation lines that wrap from a previous logical line. |
| `DoNotIndentAfterPosition` | `Integer` | `40` | Column position beyond which automatic indentation is not applied. |
| `IndentAssemblySections` | `Boolean` | `True` | Indent contents of ASM blocks relative to the `asm` keyword. |
| `IndentBeginEndKeywords` | `Boolean` | `False` | Indent `begin`/`end` keywords to the same level as enclosed statements. |
| `IndentBlocksBetweenBeginEnd` | `Boolean` | `True` | Indent statements between `begin` and `end` one level deeper. |
| `IndentClassDefinitionBodies` | `Boolean` | `False` | Indent class body (fields, methods, properties) relative to the `class` keyword. |
| `IndentComments` | `Boolean` | `True` | Indent comments to match the surrounding code level. |
| `IndentCompilerDirectives` | `Boolean` | `False` | Indent `{$IFDEF}`, `{$ENDIF}`, etc. to match the surrounding code level. |
| `IndentFunctionBodies` | `Boolean` | `False` | Indent function/procedure body relative to the routine header. |
| `IndentInnerFunctions` | `Boolean` | `True` | Indent nested routines relative to their enclosing routine. |
| `IndentInterfaceImplementationSections` | `Boolean` | `True` | Indent contents of `interface` and `implementation` sections. |
| `IndentNestedBracketsParentheses` | `Boolean` | `False` | Indent expressions inside nested brackets/parentheses. |
| `IndentCaseContents` | `Boolean` | `True` | Indent statements inside each arm of a `case` statement. |
| `IndentCaseLabels` | `Boolean` | `True` | Indent `case` labels one level relative to the `case` keyword. |
| `IndentElseInCase` | `Boolean` | `False` | Indent the `else` branch of a `case` to the same level as `case` labels. |
| `IndentLabels` | `TDelphiFmtLabelIndentOption` | `liDecreaseOneIndent` | How label declarations are indented relative to surrounding code. |

### Spacing Options (`TDelphiFmtSpacingOptions`)

These options control how spaces are inserted around operators, delimiters, brackets, and comments.

| Field | Type | Default | Description |
|---|---|---|---|
| `AroundColons` | `TDelphiFmtSpacingOption` | `spAfterOnly` | Spacing around colons in type/variable/parameter declarations. |
| `AroundColonsInFormat` | `TDelphiFmtSpacingOption` | `spNone` | Spacing around colons in format expressions (e.g. `Width:Decimals`). |
| `AroundCommas` | `TDelphiFmtSpacingOption` | `spAfterOnly` | Spacing around commas in parameter lists, arrays, and uses clauses. |
| `AroundSemicolons` | `TDelphiFmtSpacingOption` | `spAfterOnly` | Spacing around semicolons between statements. |
| `BeforeParenthesisInFunctions` | `Boolean` | `False` | Insert a space between a routine name and its opening parenthesis. |
| `ForLineComments` | `TDelphiFmtSpacingOption` | `spBeforeAndAfter` | Spacing before/after single-line `//` comments relative to preceding code. |
| `ForBlockComments` | `TDelphiFmtSpacingOptionEx` | `spxInnerAndOuter` | Spacing around `{ }` and `(* *)` block comments, including inner padding. |
| `AroundAssignmentOperators` | `TDelphiFmtSpacingOption` | `spBeforeAndAfter` | Spacing around `:=` assignment operators. |
| `AroundBinaryOperators` | `TDelphiFmtSpacingOption` | `spBeforeAndAfter` | Spacing around `+`, `-`, `*`, `/`, `div`, `mod`, `and`, `or`, comparisons. |
| `AroundUnaryPrefixOperators` | `TDelphiFmtSpacingOption` | `spNone` | Spacing between a unary prefix operator (`not`, `-`) and its operand. |
| `ForParentheses` | `Boolean` | `False` | Insert a space inside opening/closing parentheses. |
| `ForSquareBrackets` | `Boolean` | `False` | Insert a space inside opening/closing square brackets. |
| `InsideAngleBrackets` | `Boolean` | `False` | Insert a space inside opening/closing angle brackets (generics). |
| `ResolveConflictsAs` | `TDelphiFmtSpacingConflictOption` | `scSpace` | How contradictory spacing rules are resolved at the same position. |

### Line Break Options (`TDelphiFmtLineBreakOptions`)

These options control where line breaks are inserted, removed, or preserved, and how blank lines are managed.

| Field | Type | Default | Description |
|---|---|---|---|
| `KeepUserLineBreaks` | `Boolean` | `False` | Preserve existing line breaks rather than adding or removing them. |
| `LineBreakCharacters` | `TDelphiFmtLineBreakCharsOption` | `lbcSystem` | Line ending sequence for formatted output. |
| `RightMargin` | `Integer` | `80` | Maximum column width before the formatter considers wrapping a line. |
| `TrimSource` | `Boolean` | `True` | Trim leading/trailing whitespace on each line. |
| `AfterLabel` | `Boolean` | `True` | Insert a line break after each label declaration. |
| `InsideElseIf` | `Boolean` | `False` | Keep `else` and `if` of an else-if chain on the same line. |
| `AfterSemicolons` | `Boolean` | `True` | Insert a line break after each semicolon that terminates a statement. |
| `AfterUsesKeywords` | `TDelphiFmtYesNoAsIsOption` | `ynaYes` | Insert a line break after the `uses` keyword. |
| `BeforeThen` | `Boolean` | `False` | Insert a line break before the `then` keyword. |
| `InAnonymousFunctionAssignments` | `Boolean` | `False` | Insert line breaks around anonymous function bodies in assignments. |
| `InAnonymousFunctionUsage` | `Boolean` | `True` | Insert line breaks around anonymous function bodies used as parameters. |
| `InArrayInitializations` | `TDelphiFmtYesNoOption` | `ynoYes` | Place array initialization elements on separate lines. |
| `InInheritanceLists` | `TDelphiFmtYesNoOption` | `ynoNo` | Place class inheritance list entries on separate lines. |
| `InLabelExportRequiresContains` | `TDelphiFmtYesNoAsIsOption` | `ynaAsIs` | Line breaks in label, exports, requires, and contains clauses. |
| `InPropertyDeclarations` | `Boolean` | `False` | Place each property directive (`read`, `write`, `default`) on its own line. |
| `InUsesClauses` | `TDelphiFmtYesNoAsIsOption` | `ynaYes` | Place each uses clause entry on its own line. |
| `InVarConstSections` | `TDelphiFmtYesNoOption` | `ynoYes` | Place each var/const declaration on its own line. |
| `RemoveInsideEndElseBegin` | `Boolean` | `False` | Remove line breaks between `end`, `else`, and `begin`, collapsing them. |
| `RemoveInsideEndElseIf` | `Boolean` | `False` | Remove line breaks between `end`, `else`, and `if`, collapsing them. |
| `AfterBegin` | `Boolean` | `True` | Insert a line break after every `begin` keyword. |
| `AfterBeginInControlStatements` | `Boolean` | `True` | Insert a line break after `begin` in `if`/`while`/`for`/`repeat`. |
| `AfterBeginInMethodDefinitions` | `Boolean` | `True` | Insert a line break after `begin` that opens a routine body. |
| `BeforeBeginInControlStatements` | `Boolean` | `True` | Insert a line break before `begin` in control flow statements. |
| `BeforeSingleInstructionsInControlStatements` | `Boolean` | `True` | Insert a line break before a single-statement body in `if`/`while`/`for`. |
| `BeforeSingleInstructionsInTryExcept` | `Boolean` | `True` | Insert a line break before a single-statement body in try/except/finally. |
| `NewLineForReturnType` | `Boolean` | `False` | Place the return type on a new line after the parameter list. |
| `OneParameterPerLineInCalls` | `Boolean` | `False` | Place each argument in a routine call on its own line. |
| `OneParameterPerLineInDefinitions` | `Boolean` | `False` | Place each parameter in a routine declaration on its own line. |
| `MaxAdjacentEmptyLines` | `Integer` | `1` | Maximum consecutive empty lines allowed. Extra blank lines are removed. |
| `EmptyLinesAroundCompilerDirectives` | `Integer` | `0` | Empty lines inserted before/after `{$IFDEF}`, `{$ENDIF}`, etc. |
| `EmptyLinesAroundSectionKeywords` | `Integer` | `1` | Empty lines around `interface`, `implementation`, `initialization`, `finalization`. |
| `EmptyLinesSeparatorInImplementation` | `Integer` | `1` | Empty lines between declarations in the `implementation` section. |
| `EmptyLinesSeparatorInInterface` | `Integer` | `1` | Empty lines between declarations in the `interface` section. |
| `EmptyLinesBeforeSubsections` | `Integer` | `1` | Empty lines before subsections within a declaration block. |
| `EmptyLinesBeforeTypeKeyword` | `Integer` | `1` | Empty lines before the `type` keyword opening a type declaration block. |
| `EmptyLinesBeforeVisibilityModifiers` | `Integer` | `0` | Empty lines before `private`, `protected`, `public`, `published`. |

### Capitalization Options (`TDelphiFmtCapitalizationOptions`)

These options control how keywords, directives, identifiers, and numeric literals are cased.

| Field | Type | Default | Description |
|---|---|---|---|
| `CompilerDirectives` | `TDelphiFmtCapitalizationOption` | `capUpperCase` | Casing for `{$IFDEF}`, `{$DEFINE}`, etc. |
| `Numbers` | `TDelphiFmtCapitalizationOption` | `capUpperCase` | Casing for numeric literals including hex digits (`$FF` vs `$ff`). |
| `OtherWords` | `TDelphiFmtCapitalizationOption` | `capAsFirstOccurrence` | Casing for identifiers not covered by more specific options. |
| `ReservedWordsAndDirectives` | `TDelphiFmtCapitalizationOption` | `capLowerCase` | Casing for `begin`, `end`, `if`, `then`, `procedure`, `function`, etc. |

### Alignment Options (`TDelphiFmtAlignmentOptions`)

These options control vertical alignment of declarations, operators, and comments across adjacent lines. All alignment options default to `False` in v1.

| Field | Type | Default | Description |
|---|---|---|---|
| `EqualsInConstants` | `Boolean` | `False` | Vertically align `=` signs in `const` blocks. |
| `EqualsInInitializations` | `Boolean` | `False` | Vertically align `=` signs in typed constant assignments. |
| `EqualsInTypeDeclarations` | `Boolean` | `False` | Vertically align `=` signs in `type` blocks. |
| `AssignmentOperators` | `Boolean` | `False` | Vertically align `:=` in consecutive assignment statements. |
| `EndOfLineComments` | `Boolean` | `False` | Vertically align `//` comments on consecutive lines. |
| `FieldsInProperties` | `Boolean` | `False` | Vertically align property directives (`read`, `write`, `default`). |
| `TypeNames` | `Boolean` | `False` | Vertically align type names in variable/field declarations. |
| `TypesOfParameters` | `Boolean` | `False` | Vertically align type annotations across routine parameters. |
| `ColonBeforeTypeNames` | `Boolean` | `False` | Include the colon in the vertical alignment calculation. |
| `MaximumColumn` | `Integer` | `60` | Maximum column beyond which alignment is not extended. |
| `MaximumUnalignedLines` | `Integer` | `0` | Maximum unaligned lines before the formatter abandons alignment for that group. |


## 📚 API Reference

### TDelphiFmt

The main entry point. Create an instance, get default options, customize them, then call one of the formatting methods.

#### `constructor Create()`

Creates a new `TDelphiFmt` instance. The instance holds no state between formatting calls, so a single instance can be reused for multiple operations.

#### `destructor Destroy()`

Destroys the instance and releases all associated resources.

#### `function DefaultOptions(): TDelphiFmtOptions`

Returns a `TDelphiFmtOptions` record pre-populated with Castalia-style default values. This gives you a sensible baseline. Customize individual fields as needed before passing the record to a formatting method.

#### `function FormatSource(const ASource: string; const AOptions: TDelphiFmtOptions): string`

Formats a Delphi source string in memory and returns the formatted result. If the source cannot be parsed (syntax errors, incomplete code), the original `ASource` is returned unchanged.

**Parameters:**
- `ASource`: The raw Delphi source code string to format.
- `AOptions`: The formatting rules to apply.

**Returns:** The formatted source code string.

#### `function FormatFile(const AFilePath: string; const AOptions: TDelphiFmtOptions; const ACreateBackup: Boolean = True): TDelphiFmtFormatResult`

Formats a single Delphi source file in place. Reads the file, detects its encoding (UTF-8, UTF-16 LE, or ANSI), formats the content, and overwrites the file using the original encoding. Optionally creates a `.bak` backup before writing.

**Parameters:**
- `AFilePath`: Full path to the source file (`.pas`, `.dpr`, `.dpk`, `.inc`).
- `AOptions`: The formatting rules to apply.
- `ACreateBackup`: When `True` (default), a backup is created at `AFilePath + '.bak'` before changes are written.

**Returns:** A `TDelphiFmtFormatResult` record with the outcome.

#### `function FormatFolder(const AFolderPath: string; const AOptions: TDelphiFmtOptions; const ARecurse: Boolean = True; const ACreateBackup: Boolean = True): TArray<TDelphiFmtFormatResult>`

Formats all Delphi source files in a folder. Scans for `.pas`, `.dpr`, `.dpk`, and `.inc` files, optionally recursing into subdirectories. Each file is formatted in place with optional backup.

**Parameters:**
- `AFolderPath`: Full path to the folder to process.
- `AOptions`: The formatting rules to apply.
- `ARecurse`: When `True` (default), subdirectories are processed recursively.
- `ACreateBackup`: When `True` (default), a `.bak` backup is created for each file before changes.

**Returns:** An array of `TDelphiFmtFormatResult` records, one per file processed.


## 📋 Format Result

`TDelphiFmtFormatResult` is the record returned by `FormatFile` and each element in the array returned by `FormatFolder`. It tells you what happened with each file.

| Field | Type | Description |
|---|---|---|
| `FilePath` | `string` | The full path to the file that was processed. |
| `Changed` | `Boolean` | `True` if the file was rewritten because the formatted output differed from the original. |
| `Success` | `Boolean` | `True` if the formatting operation completed without error. |
| `ErrorMsg` | `string` | The error description if `Success` is `False`. Empty when `Success` is `True`. |


## 💡 Examples

### Custom options: uppercase keywords, no backup

```delphi
var
  LFmt: TDelphiFmt;
  LOptions: TDelphiFmtOptions;
  LResult: TDelphiFmtFormatResult;
begin
  LFmt := TDelphiFmt.Create();
  try
    LOptions := LFmt.DefaultOptions();

    // Uppercase all reserved words (BEGIN, END, IF, THEN, ...)
    LOptions.Capitalization.ReservedWordsAndDirectives := capUpperCase;

    // Use Unix line endings
    LOptions.LineBreaks.LineBreakCharacters := lbcLF;

    // Align assignment operators vertically
    LOptions.Alignment.AssignmentOperators := True;

    LResult := LFmt.FormatFile('C:\MyProject\MyUnit.pas', LOptions, False);
    if not LResult.Success then
      Writeln('Error: ', LResult.ErrorMsg);
  finally
    LFmt.Free();
  end;
end;
```

### Batch format with error reporting

```delphi
var
  LFmt: TDelphiFmt;
  LOptions: TDelphiFmtOptions;
  LResults: TArray<TDelphiFmtFormatResult>;
  LR: TDelphiFmtFormatResult;
  LChanged, LFailed: Integer;
begin
  LFmt := TDelphiFmt.Create();
  try
    LOptions := LFmt.DefaultOptions();
    LResults := LFmt.FormatFolder('C:\MyProject\src', LOptions, True, True);

    LChanged := 0;
    LFailed := 0;
    for LR in LResults do
    begin
      if not LR.Success then
      begin
        Inc(LFailed);
        Writeln('FAIL: ', LR.FilePath, ' - ', LR.ErrorMsg);
      end
      else if LR.Changed then
        Inc(LChanged);
    end;

    Writeln(Format('Done: %d files processed, %d changed, %d failed.',
      [Length(LResults), LChanged, LFailed]));
  finally
    LFmt.Free();
  end;
end;
```


## 🔢 Version Constants

| Constant | Value | Description |
|---|---|---|
| `DELPHIFMT_MAJOR_VERSION` | `0` | Major version. Incremented on breaking API changes. |
| `DELPHIFMT_MINOR_VERSION` | `1` | Minor version. Incremented on backwards-compatible feature additions. |
| `DELPHIFMT_PATCH_VERSION` | `0` | Patch version. Incremented on backwards-compatible bug fixes. |
| `DELPHIFMT_VERSION` | `100` | Combined integer version: `(Major * 10000) + (Minor * 100) + Patch`. |
| `DELPHIFMT_VERSION_STR` | `'0.1.0'` | Human-readable version string. |


## 🖥️ System Requirements

| | Requirement |
|---|---|
| **Host OS** | Windows 10/11 x64 |
| **Building from source** | Delphi 12 Athens or later |

DelphiFmt requires the Metamorf core libraries (`Metamorf.API`, `Metamorf.Common`, `Metamorf.Lexer`, `Metamorf.Parser`) and its own internal units (`DelphiFmt.Lexer`, `DelphiFmt.Grammar`, `DelphiFmt.Emitter`). All dependencies are included in the Metamorf repository.

<div align="center">

**Metamorf™** - Define It. Compile It. Ship It.

Copyright &copy; 2025-present tinyBigGAMES™ LLC<br/>All Rights Reserved.

</div>
