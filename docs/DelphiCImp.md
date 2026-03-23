<div align="center">

![Metamorf](../media/logo.png)

# DelphiCImp

**C Header to Delphi Import Unit Generator**

</div>

## 📖 Table of Contents

1. [Overview](#-overview)
2. [Getting Started](#-getting-started)
3. [Architecture](#-architecture)
4. [Configuration](#-configuration)
5. [Type Mapping](#-type-mapping)
6. [Post-Processing](#-post-processing)
7. [API Reference](#-api-reference)
8. [Supporting Types](#-supporting-types)
9. [Generated Output Structure](#-generated-output-structure)
10. [Examples](#-examples)
11. [System Requirements](#-system-requirements)


## 🌟 Overview

DelphiCImp is a C header to Delphi import unit generator. It reads a C header file, preprocesses it using `zig cc` to resolve macros and includes, parses the resulting declarations, and generates a complete Delphi unit with type declarations, constants, and external function bindings. The output is a ready-to-compile `.pas` file that lets you call any C library from Delphi without hand-writing import declarations.

**Who is this for?** You are a Delphi developer who needs to use a C library (raylib, SDL, libcurl, or any other C API). Instead of manually translating hundreds of struct definitions, enum values, and function signatures, you point DelphiCImp at the header file and get a Delphi unit in seconds.

**What you get:**

- Automatic preprocessing of C headers via `zig cc`, resolving all macros, includes, and conditional compilation
- Parsing of structs, unions, enums, typedefs, function pointer types, external functions, and `#define` constants
- Intelligent C-to-Delphi type mapping covering primitive types, stdint.h types, pointer types, and user-defined types
- Platform-conditional DLL name constants for Win64 and Linux64
- Optional delayed loading support via the Delphi `delayed` directive
- Post-generation text insertions and replacements for fine-tuning output without manual editing
- TOML configuration files for reproducible, scriptable builds
- Post-copy file operations to deploy native DLLs alongside generated units


## 🚀 Getting Started

There are two ways to configure DelphiCImp: through the Delphi API directly, or through a TOML configuration file.

### Manual API configuration

```delphi
var
  LImp: TDelphCImp;
begin
  LImp := TDelphCImp.Create();
  try
    LImp.SetHeader('include/raylib.h');
    LImp.SetModuleName('raylib');
    LImp.SetDllName('raylib');
    LImp.SetUnitName('URaylibImport');
    LImp.AddIncludePath('include');
    LImp.AddSourcePath('include');
    LImp.SetOutputPath('output');
    if not LImp.Process() then
      Writeln('Error: ', LImp.GetLastError());
  finally
    LImp.Free();
  end;
end;
```

### TOML configuration file

```delphi
var
  LImp: TDelphCImp;
begin
  LImp := TDelphCImp.Create();
  try
    if LImp.LoadFromConfig('raylib.toml') then
    begin
      if not LImp.Process() then
        Writeln('Error: ', LImp.GetLastError());
    end
    else
      Writeln('Config error: ', LImp.GetLastError());
  finally
    LImp.Free();
  end;
end;
```

The TOML approach is ideal for projects where the import configuration is checked into version control and rebuilt as part of a CI pipeline. See the [Configuration](#-configuration) section for the full TOML key reference.


## ⚙️ Architecture

When you call `Process()`, DelphiCImp executes the following pipeline:

```
SetHeader('mylib.h')
    │
    ▼
PreprocessHeader (zig cc -E)     ← Resolve macros, includes, conditionals
    │
    ▼
ParseDefines()                   ← Extract #define constants from preprocessor output
    │
    ▼
TCLexer.Tokenize()               ← Break preprocessed C source into tokens
    │
    ▼
ParseTopLevel()                  ← Parse structs, unions, enums, typedefs, functions
    │
    ▼
GenerateDelphiUnit()             ← Map C types to Delphi, emit .pas unit
    │
    ▼
ProcessInsertions()              ← Apply registered text insertions and replacements
    │
    ▼
Write output file                ← Save to OutputPath/UnitName.pas
    │
    ▼
DoPostCopyFile()                 ← Copy platform-matched DLLs to destination
```

The preprocessing step is critical. Raw C headers are full of macros, conditional compilation blocks, and `#include` chains that would be extremely difficult to parse directly. By running `zig cc -E` first, DelphiCImp gets a fully expanded, flat C source with all macros resolved and all includes inlined. The preprocessor also emits line markers (`# linenum "filename"`) that let DelphiCImp track which declarations came from which header file, enabling the source path filtering feature.

After preprocessing, `ParseDefines()` extracts `#define` constants by scanning the original (non-preprocessed) source for simple value macros. These become Delphi constants in the generated output.

The tokenizer and parser then walk the preprocessed C source, extracting structs (with fields), unions, enums (with values), typedefs (including function pointer typedefs), and external function declarations. Each declaration is stored in a typed info record (`TCStructInfo`, `TCEnumInfo`, etc.) for later code generation.

The code generator maps each C declaration to its Delphi equivalent, handles pointer types, array fields, bitfields, and variadic functions, then emits a complete Delphi unit with properly ordered type blocks, constants, and `external` function declarations.


## 🔧 Configuration

### Manual API Configuration

All configuration is done through method calls on `TDelphCImp` before calling `Process()`.

**Required settings:**
- `SetHeader()`: The C header file to process. This is the only strictly required setting; everything else has sensible defaults.

**Naming:**
- `SetModuleName()`: Identifies the library (e.g. `'raylib'`). Used as the fallback DLL name and base name for the preprocessed output file. Defaults to the header filename without extension.
- `SetUnitName()`: The Delphi unit name for the generated file (e.g. `'URaylibImport'`). Defaults to `'U' + ModuleName + 'Import'`.
- `SetDllName()`: The base library name for external function declarations (e.g. `'raylib'`). Platform-appropriate extensions (`.dll`, `.so`) and prefixes (`lib`) are added automatically.
- `SetDllName(APlatform, ADllName)`: Override the library name for a specific platform (Win64 or Linux64).

**Paths:**
- `AddIncludePath()`: Adds a directory to the include search paths passed to `zig cc`. Optionally accepts a module name to mark types from that path as external (they are recorded but not emitted in the output).
- `AddSourcePath()`: Adds a directory to the source filter. When source paths are set, only declarations from headers under those paths appear in the output. If no source paths are added, include paths are used as the filter.
- `SetOutputPath()`: The directory where the generated `.pas` file is written. Defaults to the header file's directory.

**Filtering:**
- `AddExcludedType()`: Excludes a C type name from the output. Typedefs and functions that reference excluded types are also omitted.
- `AddExcludedFunction()`: Excludes a specific C function from the generated external declarations.

**Flags:**
- `SetSavePreprocessed(True)`: Saves the preprocessed C source as `ModuleName_pp.c` in the output directory for inspection and debugging.
- `EnableDelayLoad(True)`: Emits external function declarations with the `delayed` directive, deferring DLL loading until first call.

### TOML Configuration Reference

All settings from the manual API have TOML equivalents. Load a TOML file with `LoadFromConfig()` and save the current configuration with `SaveToConfig()`.

```toml
[cimporter]
header = "include/raylib.h"
module_name = "raylib"
dll_name = "raylib"
unit_name = "URaylibImport"
output_path = "output"
save_preprocessed = false
delay_load = false
source_paths = ["include"]
excluded_types = ["__va_list_tag"]
excluded_functions = ["rl_internal_helper"]
```

Include paths are specified as an array of tables, each with a `path` and an optional `module` for external type association:

```toml
[[cimporter.include_paths]]
path = "include"

[[cimporter.include_paths]]
path = "deps/sdl/include"
module = "SDL3"
```

Insertions let you inject text or file contents into the generated output at specific locations:

```toml
[[cimporter.insertions]]
target = "type"
content = "  TMyCustomType = record\n    Value: Integer;\n  end;\n"
position = "after"
occurrence = 1

[[cimporter.insertions]]
target = "implementation"
file = "extra_helpers.inc"
position = "after"
```

Replacements perform find-and-replace on the final output:

```toml
[[cimporter.replacements]]
old_text = "PAnsiChar"
new_text = "PUTF8Char"
occurrence = 0  # 0 = replace all occurrences
```

Post-copy files deploy native libraries after generation:

```toml
[[cimporter.post_copy_files]]
platform = "win64"
source = "lib/raylib.dll"
dest_dir = "output"

[[cimporter.post_copy_files]]
platform = "linux64"
source = "lib/libraylib.so"
dest_dir = "output"
```


## 🔄 Type Mapping

DelphiCImp maps C types to Delphi types using the following rules. The mapping handles primitive types, stdint.h exact-width types, pointer types, and user-defined types.

### Primitive Types

| C Type | Delphi Type |
|---|---|
| `void` | *(no type)* |
| `_Bool` | `Boolean` |
| `char` | `AnsiChar` |
| `signed char` | `Int8` |
| `unsigned char` | `Byte` |
| `wchar_t` | `WideChar` |
| `short` | `Int16` |
| `unsigned short` | `UInt16` |
| `int` | `Int32` |
| `unsigned int` | `UInt32` |
| `long` | `Int32` |
| `unsigned long` | `UInt32` |
| `long long` | `Int64` |
| `unsigned long long` | `UInt64` |
| `float` | `Single` |
| `double` | `Double` |
| `long double` | `Double` |

### C99 stdint.h Types

| C Type | Delphi Type |
|---|---|
| `int8_t` | `Int8` |
| `int16_t` | `Int16` |
| `int32_t` | `Int32` |
| `int64_t` | `Int64` |
| `uint8_t` | `UInt8` |
| `uint16_t` | `UInt16` |
| `uint32_t` | `UInt32` |
| `uint64_t` | `UInt64` |
| `size_t` | `NativeUInt` |
| `ssize_t` | `NativeInt` |
| `ptrdiff_t` | `NativeInt` |
| `intptr_t` | `NativeInt` |
| `uintptr_t` | `NativeUInt` |
| `intmax_t` | `Int64` |
| `uintmax_t` | `UInt64` |

### SDL-Specific Integer Types

| C Type | Delphi Type |
|---|---|
| `Sint8` / `Sint16` / `Sint32` / `Sint64` | `Int8` / `Int16` / `Int32` / `Int64` |
| `Uint8` / `Uint16` / `Uint32` / `Uint64` | `UInt8` / `UInt16` / `UInt32` / `UInt64` |

### Pointer Type Rules

Pointer types follow a consistent set of rules:

- `void*` maps to `Pointer`
- `char*` and `const char*` map to `PAnsiChar`
- `wchar_t*` maps to `PWideChar`
- `unsigned char*` maps to `PByte`
- Pointers to user-defined types (structs, enums) use a `P` prefix on the sanitized type name (e.g. `Vector3*` becomes `PVector3`)
- Pointers to builtin types (e.g. `int*`, `float*`) map to `Pointer` since Delphi does not have `PInt32` or `PSingle` in the standard library
- Double pointers and higher (`**`, `***`) always map to `Pointer`

### Other Special Types

| C Type | Delphi Type |
|---|---|
| `va_list` | `Pointer` |
| `__va_list_tag` | `Pointer` |

User-defined types (structs, enums, typedefs) that are not in the mapping table are converted using `DelphifyTypeName`, which strips common C prefixes and applies Delphi naming conventions.


## ✏️ Post-Processing

After code generation completes, DelphiCImp applies three kinds of post-processing operations in order: insertions, replacements, and file copies.

### Insertions

Insertions let you inject text or file contents into the generated output at specific locations. This is how you add custom type declarations, helper routines, or additional uses clause entries without modifying the generated output by hand.

Each insertion targets a specific line in the output (matched by trimmed, case-insensitive content) and inserts text either before or after that line. You can target a specific occurrence if the line appears multiple times.

```delphi
// Insert a custom type after the "type" keyword
LImp.InsertTextAfter('type', '  TMyHelper = record' + sLineBreak +
  '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak);

// Insert contents of a file before the implementation section
LImp.InsertFileBefore('implementation', 'extra_types.inc');
```

### Replacements

Replacements perform case-sensitive find-and-replace on the final output string after all insertions have been applied. Use them to fix up type names, adjust constant values, or patch any generated text that needs tweaking.

```delphi
// Replace all occurrences of PAnsiChar with PUTF8Char
LImp.ReplaceText('PAnsiChar', 'PUTF8Char', 0);  // 0 = all occurrences

// Replace only the first occurrence
LImp.ReplaceText('OldTypeName', 'NewTypeName', 1);
```

### Post-Copy Files

Post-copy operations copy platform-matched native libraries to a destination directory after the import unit has been generated. Only files matching the current compilation platform are copied.

```delphi
LImp.AddPostCopyFile(tpWin64, 'lib\raylib.dll', 'output');
LImp.AddPostCopyFile(tpLinux64, 'lib\libraylib.so', 'output');
```

The destination directory is created automatically if it does not exist.


## 📚 API Reference

### TDelphCImp

The main entry point class. Extends `TStatusObject`. Create an instance, configure it, call `Process()`, then check the result.

#### `constructor Create()`

Creates a new `TDelphCImp` instance and initializes all internal collections, the C lexer, and the output buffer. All fields start at their default values (empty strings, False flags, empty lists).

#### `destructor Destroy()`

Destroys the instance and releases all associated resources including the lexer, parsed declaration lists, and configuration collections.

#### `procedure Clear()`

Resets the instance to its initial state, clearing all configuration settings, parsed declarations, output buffers, and error state. After calling `Clear()`, the instance can be reconfigured and reused for a different header without creating a new object.

#### `procedure SetHeader(const AFilename: string)`

Sets the C header file to process. This is the primary input file that will be preprocessed and parsed. Forward and back slashes are normalized internally.

#### `procedure SetModuleName(const AName: string)`

Sets the module name identifying the library being imported (e.g. `'raylib'`, `'SDL3'`). Used as the fallback DLL name and as the base name for the preprocessed output file. Defaults to the header filename without extension.

#### `procedure SetUnitName(const AName: string)`

Sets the Delphi unit name for the generated output. Determines both the `unit` identifier and the output filename (`UnitName.pas`). Defaults to `'U' + ModuleName + 'Import'`.

#### `procedure SetDllName(const ADllName: string)`

Sets the default DLL/shared library name for external function declarations. Platform-appropriate extensions (`.dll`, `.so`) and prefixes (`lib`) are added automatically during generation.

#### `procedure SetDllName(const APlatform: TTargetPlatform; const ADllName: string)`

Sets a platform-specific library name override. When generating the `CLibName` constant, this name is used for the specified platform instead of the default.

#### `procedure SetOutputPath(const APath: string)`

Sets the output directory for the generated unit file and optional preprocessed source. Defaults to the header file's directory.

#### `procedure AddIncludePath(const APath: string; const AModuleName: string = '')`

Adds a directory to the include paths passed to `zig cc`. When `AModuleName` is provided, types discovered under that path are recorded as external to that module and excluded from the generated output.

#### `procedure AddSourcePath(const APath: string)`

Adds a directory to the source path filter. When source paths are specified, only declarations from headers under those paths appear in the output. If no source paths are added, include paths serve as the filter.

#### `procedure AddExcludedType(const ATypeName: string)`

Adds a type name to the exclusion list. The named type and any typedefs or functions referencing it are omitted from the output. Also used to exclude specific `#define` constant names.

#### `procedure AddExcludedFunction(const AFuncName: string)`

Adds a function name to the exclusion list. The named function is omitted from the generated external declarations regardless of whether its types are valid.

#### `procedure SetSavePreprocessed(const AValue: Boolean)`

When enabled, saves the preprocessed C source as `ModuleName_pp.c` in the output directory. Useful for debugging preprocessing issues.

#### `procedure EnableDelayLoad(const AValue: Boolean)`

When enabled, generated external function declarations include the `delayed` directive, deferring DLL loading until the function is first called at runtime.

#### `procedure InsertTextAfter(const ATargetLine: string; const AText: string; const AOccurrence: Integer = 1)`

Registers a text insertion after a target line in the generated output. Matching is trimmed, case-insensitive. `AOccurrence` selects which occurrence to target (default: first).

#### `procedure InsertFileAfter(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer = 1)`

Like `InsertTextAfter`, but reads the insertion content from a UTF-8 text file. If the file does not exist, the insertion is silently skipped.

#### `procedure InsertTextBefore(const ATargetLine: string; const AText: string; const AOccurrence: Integer = 1)`

Registers a text insertion before a target line. Same matching rules as `InsertTextAfter`.

#### `procedure InsertFileBefore(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer = 1)`

Like `InsertTextBefore`, but reads the insertion content from a file.

#### `procedure ReplaceText(const AOldText: string; const ANewText: string; const AOccurrence: Integer = 0)`

Registers a case-sensitive text replacement applied after all insertions. `AOccurrence = 0` replaces all occurrences; a positive value replaces only that specific occurrence.

#### `procedure AddPostCopyFile(const APlatform: TTargetPlatform; const ASourceFile: string; const ADestDir: string)`

Registers a file copy to be performed after the unit is generated. Only executes when running on the matching platform (`tpWin64` on Windows, `tpLinux64` on Linux). The destination directory is created if needed.

#### `function Process(): Boolean`

Executes the complete C-to-Delphi import generation pipeline: preprocesses the header, parses all declarations, generates the Delphi unit, applies insertions and replacements, writes the output file, and performs post-copy operations. Returns `True` on success. On failure, call `GetLastError()` for the error description.

#### `function LoadFromConfig(const AFilename: string): Boolean`

Loads all configuration settings from a TOML file. Returns `True` on success. On failure (file not found, missing required keys), call `GetLastError()` for the error.

#### `function SaveToConfig(const AFilename: string): Boolean`

Saves the current configuration to a TOML file. Creates the file if it does not exist, overwrites if it does. Returns `True` on success.

#### `function GetLastError(): string`

Returns the error message from the most recent failed operation (`Process`, `LoadFromConfig`, `SaveToConfig`, or preprocessing). Returns an empty string when no error has occurred.


## 🧩 Supporting Types

The `DelphiCImp.Common` unit defines the data structures used internally by the parser and exposed for advanced use cases. You do not need these types for normal usage, but they are documented here for completeness.

### TCTokenKind

The token kinds recognized by the C lexer: `ctkEOF`, `ctkError`, `ctkIdentifier`, `ctkIntLiteral`, `ctkFloatLiteral`, `ctkStringLiteral`, `ctkTypedef`, `ctkStruct`, `ctkUnion`, `ctkEnum`, `ctkConst`, `ctkVoid`, `ctkChar`, `ctkShort`, `ctkInt`, `ctkLong`, `ctkFloat`, `ctkDouble`, `ctkSigned`, `ctkUnsigned`, `ctkBool`, `ctkExtern`, `ctkStatic`, `ctkInline`, `ctkRestrict`, `ctkVolatile`, `ctkAtomic`, `ctkBuiltin`, `ctkLBrace`, `ctkRBrace`, `ctkLParen`, `ctkRParen`, `ctkLBracket`, `ctkRBracket`, `ctkSemicolon`, `ctkComma`, `ctkStar`, `ctkEquals`, `ctkColon`, `ctkEllipsis`, `ctkDot`, `ctkHash`, `ctkLineMarker`.

### TCToken

A single token produced by the C lexer.

| Field | Type | Description |
|---|---|---|
| `Kind` | `TCTokenKind` | The token kind. |
| `Lexeme` | `string` | The raw text of the token. |
| `IntValue` | `Int64` | Parsed integer value (for integer literals). |
| `FloatValue` | `Double` | Parsed float value (for float literals). |
| `Line` | `Integer` | Source line number. |
| `Column` | `Integer` | Source column number. |

### TCFieldInfo

Represents a single field within a C struct or union.

| Field | Type | Description |
|---|---|---|
| `FieldName` | `string` | The field name. |
| `TypeName` | `string` | The C type name. |
| `IsPointer` | `Boolean` | Whether the field is a pointer type. |
| `PointerDepth` | `Integer` | Number of pointer indirections (`*` count). |
| `ArraySize` | `Integer` | Fixed array size, or 0 for non-array fields. |
| `BitWidth` | `Integer` | Bit-field width, or 0 for non-bitfield fields. |

### TCStructInfo

Represents a parsed C struct or union declaration.

| Field | Type | Description |
|---|---|---|
| `StructName` | `string` | The struct or union name. |
| `IsUnion` | `Boolean` | `True` for unions, `False` for structs. |
| `Fields` | `TArray<TCFieldInfo>` | The fields in declaration order. |

### TCEnumValue

Represents a single value within a C enum.

| Field | Type | Description |
|---|---|---|
| `ValueName` | `string` | The enum constant name. |
| `Value` | `Int64` | The numeric value. |
| `HasExplicitValue` | `Boolean` | Whether the value was explicitly assigned in the source. |

### TCEnumInfo

Represents a parsed C enum declaration.

| Field | Type | Description |
|---|---|---|
| `EnumName` | `string` | The enum name. |
| `Values` | `TArray<TCEnumValue>` | The enum values in declaration order. |

### TCDefineInfo

Represents a parsed `#define` constant.

| Field | Type | Description |
|---|---|---|
| `DefineName` | `string` | The macro name. |
| `DefineValue` | `string` | The raw value string. |
| `IsInteger` | `Boolean` | Whether the value is an integer constant. |
| `IntValue` | `Int64` | The parsed integer value (when `IsInteger` is `True`). |
| `IsFloat` | `Boolean` | Whether the value is a floating-point constant. |
| `FloatValue` | `Double` | The parsed float value (when `IsFloat` is `True`). |
| `IsString` | `Boolean` | Whether the value is a string constant. |
| `StringValue` | `string` | The parsed string value (when `IsString` is `True`). |
| `IsTypedConstant` | `Boolean` | Whether the define represents a typed constant (e.g. compound initializer). |
| `TypedConstType` | `string` | The type name for typed constants. |
| `TypedConstValues` | `string` | The initializer values for typed constants. |

### TCParamInfo

Represents a single parameter of a C function.

| Field | Type | Description |
|---|---|---|
| `ParamName` | `string` | The parameter name. |
| `TypeName` | `string` | The C type name. |
| `IsPointer` | `Boolean` | Whether the parameter is a pointer type. |
| `PointerDepth` | `Integer` | Number of pointer indirections. |
| `IsConst` | `Boolean` | Whether the parameter is declared `const`. |
| `IsConstTarget` | `Boolean` | Whether the pointer target is `const` (e.g. `const char*`). |

### TCFunctionInfo

Represents a parsed C function declaration.

| Field | Type | Description |
|---|---|---|
| `FuncName` | `string` | The function name. |
| `ReturnType` | `string` | The C return type name. |
| `ReturnIsPointer` | `Boolean` | Whether the return type is a pointer. |
| `ReturnPointerDepth` | `Integer` | Pointer indirection depth of the return type. |
| `Params` | `TArray<TCParamInfo>` | The function parameters in declaration order. |
| `IsVariadic` | `Boolean` | Whether the function accepts variadic arguments (`...`). |

### TCTypedefInfo

Represents a parsed C typedef declaration.

| Field | Type | Description |
|---|---|---|
| `AliasName` | `string` | The new type alias name. |
| `TargetType` | `string` | The underlying type being aliased. |
| `IsPointer` | `Boolean` | Whether the alias is a pointer type. |
| `PointerDepth` | `Integer` | Pointer indirection depth. |
| `IsFunctionPointer` | `Boolean` | Whether this is a function pointer typedef. |
| `FuncInfo` | `TCFunctionInfo` | The function signature (when `IsFunctionPointer` is `True`). |

### TInsertionInfo

Represents a registered text insertion operation.

| Field | Type | Description |
|---|---|---|
| `TargetLine` | `string` | The line content to match against. |
| `Content` | `string` | The text or file contents to insert. |
| `InsertBefore` | `Boolean` | `True` to insert before the target line, `False` for after. |
| `Occurrence` | `Integer` | Which occurrence of the target line to match. |

### TReplacementInfo

Represents a registered text replacement operation.

| Field | Type | Description |
|---|---|---|
| `OldText` | `string` | The text to search for. |
| `NewText` | `string` | The replacement text. |
| `Occurrence` | `Integer` | Which occurrence to replace (0 = all). |

### TPostCopyInfo

Represents a registered post-generation file copy operation.

| Field | Type | Description |
|---|---|---|
| `Platform` | `TTargetPlatform` | The target platform (`tpWin64` or `tpLinux64`). |
| `SourceFile` | `string` | Full path to the source file. |
| `DestDir` | `string` | Destination directory. |


## 📄 Generated Output Structure

The generated Delphi unit follows a consistent structure. Here is what a typical output looks like:

```delphi
unit URaylibImport;

interface

uses
  WinApi.Windows;

const
  {$IF Defined(WIN64)}
  CLibName = 'raylib.dll';
  {$ELSEIF Defined(LINUX64)}
  CLibName = 'libraylib.so';
  {$ENDIF}

  // Simple #define constants
  MAX_TOUCH_POINTS = 10;
  PI = 3.14159265358979;

type
  // Forward declarations (pointer types)
  PVector2 = ^Vector2;
  PVector3 = ^Vector3;

  // Enum types
  KeyboardKey = Integer;
  const
    KEY_NULL = 0;
    KEY_SPACE = 32;
    // ...
```delphi
type
  // Struct types (records)
  Vector2 = record
    x: Single;
    y: Single;
  end;

  Vector3 = record
    x: Single;
    y: Single;
    z: Single;
  end;

  // Function pointer typedefs
  TraceLogCallback = procedure(
    logLevel: Integer;
    text: PAnsiChar;
    args: Pointer
  ); cdecl;

// External function declarations
procedure InitWindow(
  width: Integer;
  height: Integer;
  title: PAnsiChar
); cdecl; external CLibName;

function IsWindowReady(): Boolean; cdecl; external CLibName;

implementation

end.
```

The generator emits declarations in the following order: platform-conditional DLL name constants, simple `#define` constants (integers, floats, strings), forward pointer type declarations, enum types with their values as Delphi constants, struct and union record types, function pointer typedefs as procedural types, and finally external function declarations with `cdecl` calling convention. Typed constants (compound initializers) are emitted in a separate `const` section after the type declarations.

When delay loading is enabled, each external function declaration includes the `delayed` directive:

```delphi
procedure InitWindow(
  width: Integer;
  height: Integer;
  title: PAnsiChar
); cdecl; external CLibName delayed;
```


## 💡 Examples

### Multi-module import with external types

When importing a library that depends on types from another library (e.g. a physics engine that uses your math library's vector types), use the `AModuleName` parameter on `AddIncludePath` to mark those types as external:

```delphi
var
  LImp: TDelphCImp;
begin
  LImp := TDelphCImp.Create();
  try
    LImp.SetHeader('include/physics.h');
    LImp.SetModuleName('physics');
    LImp.SetDllName('physics');
    LImp.SetUnitName('UPhysicsImport');

    // Types from mathlib headers are recorded but not emitted
    LImp.AddIncludePath('deps/mathlib/include', 'mathlib');

    // Types from physics headers are emitted
    LImp.AddIncludePath('include');
    LImp.AddSourcePath('include');

    LImp.SetOutputPath('output');
    LImp.Process();
  finally
    LImp.Free();
  end;
end;
```

### Filtering unwanted declarations

Some C headers expose internal types or helper functions that you do not want in your Delphi import. Use the exclusion lists to filter them out:

```delphi
LImp.AddExcludedType('__va_list_tag');
LImp.AddExcludedType('InternalHelperStruct');
LImp.AddExcludedFunction('rl_internal_init');
LImp.AddExcludedFunction('rl_debug_dump');
```

Any typedef or function that references an excluded type is automatically excluded as well.

### Saving and reloading configuration

After configuring an import manually, save it as TOML for future use:

```delphi
var
  LImp: TDelphCImp;
begin
  LImp := TDelphCImp.Create();
  try
    // Configure manually
    LImp.SetHeader('include/mylib.h');
    LImp.SetModuleName('mylib');
    LImp.SetDllName('mylib');
    LImp.SetUnitName('UMyLibImport');
    LImp.AddIncludePath('include');
    LImp.AddSourcePath('include');
    LImp.SetOutputPath('output');
    LImp.EnableDelayLoad(True);

    // Save for later
    LImp.SaveToConfig('mylib.toml');

    // Process
    LImp.Process();
  finally
    LImp.Free();
  end;
end;
```

Next time, just load and run:

```delphi
var
  LImp: TDelphCImp;
begin
  LImp := TDelphCImp.Create();
  try
    if LImp.LoadFromConfig('mylib.toml') then
      LImp.Process();
  finally
    LImp.Free();
  end;
end;
```


## 🖥️ System Requirements

| | Requirement |
|---|---|
| **Host OS** | Windows 10/11 x64 |
| **Preprocessor** | Clang C preprocessor via `zig cc` (bundled at `res/zig/zig.exe` in the release) |
| **Target platforms** | Win64 and Linux64 (for generated DLL name constants) |
| **Building from source** | Delphi 12 Athens or later |

DelphiCImp requires the Metamorf core libraries (`Metamorf.Utils`, `Metamorf.Build`, `Metamorf.Config`) and its own common unit (`DelphiCImp.Common`). The `zig.exe` preprocessor is bundled with the Metamorf release and does not need to be installed separately.

<div align="center">

**Metamorf™** - Define It. Compile It. Ship It.

Copyright &copy; 2025-present tinyBigGAMES™ LLC<br/>All Rights Reserved.

</div>
