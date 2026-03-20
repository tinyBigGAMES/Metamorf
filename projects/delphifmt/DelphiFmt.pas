{===============================================================================
  DelphiFmt™ - Delphi Source Code Formatter

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

/// <summary>
///   Provides the public API for the DelphiFmt Delphi source code formatter.
///   Declares all formatting option types, option records, the format result
///   record, and the TDelphiFmt class which is the main entry point for all
///   formatting operations.
/// </summary>
/// <remarks>
///   To format Delphi source code, create an instance of TDelphiFmt, obtain
///   a TDelphiFmtOptions record via TDelphiFmt.DefaultOptions, customise the
///   options as needed, then call FormatSource, FormatFile, or FormatFolder.
///   <para>
///   The formatter supports the following Delphi source file types:
///   .pas, .dpr, .dpk, and .inc.
///   </para>
///   <para>
///   All formatting operations are idempotent — running the formatter on
///   already-formatted source produces identical output.
///   </para>
/// </remarks>
unit DelphiFmt;

{$I DelphiFmt.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections;

const
  /// <summary>
  ///   The major version number of the DelphiFmt library.
  ///   Incremented when breaking API changes are introduced.
  /// </summary>
  DELPHIFMT_MAJOR_VERSION = 0;

  /// <summary>
  ///   The minor version number of the DelphiFmt library.
  ///   Incremented when new features are added in a backwards-compatible manner.
  /// </summary>
  DELPHIFMT_MINOR_VERSION = 1;

  /// <summary>
  ///   The patch version number of the DelphiFmt library.
  ///   Incremented when backwards-compatible bug fixes are made.
  /// </summary>
  DELPHIFMT_PATCH_VERSION = 0;

  /// <summary>
  ///   The combined integer version of the DelphiFmt library, encoded as
  ///   (Major * 10000) + (Minor * 100) + Patch. Useful for programmatic
  ///   version comparisons.
  /// </summary>
  DELPHIFMT_VERSION = (DELPHIFMT_MAJOR_VERSION * 10000) + (DELPHIFMT_MINOR_VERSION * 100) + DELPHIFMT_PATCH_VERSION;

  /// <summary>
  ///   The human-readable version string of the DelphiFmt library
  ///   in Major.Minor.Patch format.
  /// </summary>
  DELPHIFMT_VERSION_STR = '0.1.0';

type

  /// <summary>
  ///   Specifies how spacing is applied around a syntactic element such as a
  ///   colon, comma, or semicolon.
  /// </summary>
  TDelphiFmtSpacingOption = (

    /// <summary>
    ///   No space is inserted before or after the element.
    /// </summary>
    spNone,

    /// <summary>
    ///   A single space is inserted before the element only.
    /// </summary>
    spBeforeOnly,

    /// <summary>
    ///   A single space is inserted after the element only.
    /// </summary>
    spAfterOnly,

    /// <summary>
    ///   A single space is inserted both before and after the element.
    /// </summary>
    spBeforeAndAfter
  );

  /// <summary>
  ///   Specifies how spacing is applied around a syntactic element, extending
  ///   TDelphiFmtSpacingOption with an additional inner and outer spacing mode.
  /// </summary>
  TDelphiFmtSpacingOptionEx = (
    /// <summary>
    ///   No space is inserted before or after the element.
    /// </summary>
    spxNone,
    /// <summary>
    ///   A single space is inserted before the element only.
    /// </summary>
    spxBeforeOnly,
    /// <summary>
    ///   A single space is inserted after the element only.
    /// </summary>
    spxAfterOnly,
    /// <summary>
    ///   A single space is inserted both before and after the element.
    /// </summary>
    spxBeforeAndAfter,
    /// <summary>
    ///   A single space is inserted both inside and outside the element,
    ///   such as within parentheses as well as around them.
    /// </summary>
    spxInnerAndOuter
  );

  /// <summary>
  ///   Specifies a simple yes or no formatting option.
  /// </summary>
  TDelphiFmtYesNoOption = (
    /// <summary>
    ///   The formatting option is enabled.
    /// </summary>
    ynoYes,
    /// <summary>
    ///   The formatting option is disabled.
    /// </summary>
    ynoNo
  );

  /// <summary>
  ///   Specifies a yes, no, or preserve-as-is formatting option.
  /// </summary>
  TDelphiFmtYesNoAsIsOption = (
    /// <summary>
    ///   The formatting option is enabled.
    /// </summary>
    ynaYes,
    /// <summary>
    ///   The formatting option is disabled.
    /// </summary>
    ynaNo,
    /// <summary>
    ///   The existing formatting is preserved exactly as found in the source,
    ///   with no changes applied.
    /// </summary>
    ynaAsIs
  );

  /// <summary>
  ///   Specifies how keyword or identifier capitalisation is applied during formatting.
  /// </summary>
  TDelphiFmtCapitalizationOption = (
    /// <summary>
    ///   The token is converted to all upper case (e.g. BEGIN, END, IF).
    /// </summary>
    capUpperCase,
    /// <summary>
    ///   The token is converted to all lower case (e.g. begin, end, if).
    /// </summary>
    capLowerCase,
    /// <summary>
    ///   The existing capitalisation is preserved exactly as found in the source,
    ///   with no changes applied.
    /// </summary>
    capAsIs,
    /// <summary>
    ///   The capitalisation of the token is normalised to match the casing of its
    ///   first occurrence in the source file.
    /// </summary>
    capAsFirstOccurrence
  );

  /// <summary>
  ///   Specifies how label declarations and their associated statements are
  ///   indented relative to the surrounding code block.
  /// </summary>
  TDelphiFmtLabelIndentOption = (
    /// <summary>
    ///   The label is indented one level less than the surrounding code block,
    ///   making it visually stand out from the statements around it.
    /// </summary>
    liDecreaseOneIndent,
    /// <summary>
    ///   The label is placed at the leftmost column with no indentation,
    ///   regardless of the current nesting level.
    /// </summary>
    liNoIndent,
    /// <summary>
    ///   The label is indented at the same level as the surrounding code block,
    ///   treating it like any other statement.
    /// </summary>
    liNormalIndent
  );

  /// <summary>
  ///   Specifies the line break character sequence used when writing formatted output.
  /// </summary>
  TDelphiFmtLineBreakCharsOption = (
    /// <summary>
    ///   Uses the line break sequence of the current operating system
    ///   (CRLF on Windows, LF on Linux and macOS).
    /// </summary>
    lbcSystem,
    /// <summary>
    ///   Uses a carriage return followed by a line feed (CRLF, #13#10),
    ///   the standard Windows line ending.
    /// </summary>
    lbcCRLF,
    /// <summary>
    ///   Uses a line feed only (LF, #10), the standard Unix and macOS line ending.
    /// </summary>
    lbcLF,
    /// <summary>
    ///   Uses a carriage return only (CR, #13), the legacy macOS line ending.
    /// </summary>
    lbcCR
  );

  /// <summary>
  ///   Specifies how conflicting spacing rules are resolved when two formatting
  ///   rules produce contradictory spacing requirements at the same position.
  /// </summary>
  TDelphiFmtSpacingConflictOption = (
    /// <summary>
    ///   When a spacing conflict occurs, a space is inserted.
    /// </summary>
    scSpace,
    /// <summary>
    ///   When a spacing conflict occurs, no space is inserted.
    /// </summary>
    scNoSpace
  );

  /// <summary>
  ///   Contains all indentation-related formatting options that control how
  ///   code blocks, keywords, and constructs are indented in the formatted output.
  /// </summary>
  TDelphiFmtIndentationOptions = record
    /// <summary>
    ///   The number of additional spaces used to indent continuation lines,
    ///   i.e. lines that wrap from a previous logical line.
    /// </summary>
    ContinuationIndent                    : Integer;
    /// <summary>
    ///   Column position beyond which automatic indentation is not applied.
    ///   Lines whose content starts at or after this position are left as-is.
    /// </summary>
    DoNotIndentAfterPosition              : Integer;
    /// <summary>
    ///   When True, the contents of ASM blocks are indented relative to the
    ///   asm keyword.
    /// </summary>
    IndentAssemblySections                : Boolean;
    /// <summary>
    ///   When True, the begin and end keywords themselves are indented to the
    ///   same level as the statements they enclose.
    /// </summary>
    IndentBeginEndKeywords                : Boolean;
    /// <summary>
    ///   When True, statements between begin and end are indented one level
    ///   deeper than the begin and end keywords.
    /// </summary>
    IndentBlocksBetweenBeginEnd           : Boolean;
    /// <summary>
    ///   When True, the body of a class definition (fields, methods, properties)
    ///   is indented relative to the class keyword.
    /// </summary>
    IndentClassDefinitionBodies           : Boolean;
    /// <summary>
    ///   When True, comment lines are indented to match the indentation level
    ///   of the surrounding code.
    /// </summary>
    IndentComments                        : Boolean;
    /// <summary>
    ///   When True, compiler directives such as {$IFDEF} and {$ENDIF} are
    ///   indented to match the surrounding code level.
    /// </summary>
    IndentCompilerDirectives              : Boolean;
    /// <summary>
    ///   When True, the body of function and procedure implementations is
    ///   indented relative to the routine header.
    /// </summary>
    IndentFunctionBodies                  : Boolean;
    /// <summary>
    ///   When True, locally declared functions and procedures nested inside
    ///   another routine are indented relative to their enclosing routine.
    /// </summary>
    IndentInnerFunctions                  : Boolean;
    /// <summary>
    ///   When True, the contents of the interface and implementation sections
    ///   of a unit are indented relative to their section keyword.
    /// </summary>
    IndentInterfaceImplementationSections : Boolean;
    /// <summary>
    ///   When True, expressions inside nested brackets or parentheses are
    ///   indented relative to the opening bracket or parenthesis.
    /// </summary>
    IndentNestedBracketsParentheses       : Boolean;
    /// <summary>
    ///   When True, the statements inside each arm of a case statement are
    ///   indented relative to the case label.
    /// </summary>
    IndentCaseContents                    : Boolean;
    /// <summary>
    ///   When True, the labels within a case statement are indented one level
    ///   relative to the case keyword.
    /// </summary>
    IndentCaseLabels                      : Boolean;
    /// <summary>
    ///   When True, the else branch of a case statement is indented to the
    ///   same level as the case labels rather than the case keyword.
    /// </summary>
    IndentElseInCase                      : Boolean;
    /// <summary>
    ///   Controls how label declarations and their associated goto targets are
    ///   indented relative to the surrounding code block.
    ///   See TDelphiFmtLabelIndentOption for available values.
    /// </summary>
    IndentLabels                          : TDelphiFmtLabelIndentOption;
  end;

  /// <summary>
  ///   Contains all spacing-related formatting options that control how spaces
  ///   are inserted around operators, delimiters, brackets, and comments.
  /// </summary>
  TDelphiFmtSpacingOptions = record
    /// <summary>
    ///   Controls spacing around colon characters used in type declarations,
    ///   variable declarations, and parameter lists.
    /// </summary>
    AroundColons                  : TDelphiFmtSpacingOption;
    /// <summary>
    ///   Controls spacing around colon characters used inside format expressions
    ///   such as Width:Decimals specifiers in Writeln calls.
    /// </summary>
    AroundColonsInFormat          : TDelphiFmtSpacingOption;
    /// <summary>
    ///   Controls spacing around comma delimiters in parameter lists,
    ///   array literals, and uses clauses.
    /// </summary>
    AroundCommas                  : TDelphiFmtSpacingOption;
    /// <summary>
    ///   Controls spacing around semicolon delimiters between statements
    ///   and declarations.
    /// </summary>
    AroundSemicolons              : TDelphiFmtSpacingOption;
    /// <summary>
    ///   When True, a space is inserted between a function or procedure name
    ///   and its opening parenthesis in call expressions.
    /// </summary>
    BeforeParenthesisInFunctions  : Boolean;
    /// <summary>
    ///   Controls spacing before and after single-line (//) comments relative
    ///   to the preceding code on the same line.
    /// </summary>
    ForLineComments               : TDelphiFmtSpacingOption;
    /// <summary>
    ///   Controls spacing around block comments ({ } and (* *)), including
    ///   optional inner padding within the comment delimiters.
    /// </summary>
    ForBlockComments              : TDelphiFmtSpacingOptionEx;
    /// <summary>
    ///   Controls spacing around assignment operators (:=) in statements.
    /// </summary>
    AroundAssignmentOperators     : TDelphiFmtSpacingOption;
    /// <summary>
    ///   Controls spacing around binary operators such as +, -, *, /, div,
    ///   mod, and, or, xor, and comparison operators.
    /// </summary>
    AroundBinaryOperators         : TDelphiFmtSpacingOption;
    /// <summary>
    ///   Controls spacing between a unary prefix operator (e.g. not, -) and
    ///   the operand that follows it.
    /// </summary>
    AroundUnaryPrefixOperators    : TDelphiFmtSpacingOption;
    /// <summary>
    ///   When True, a space is inserted immediately inside opening and closing
    ///   parentheses surrounding expressions.
    /// </summary>
    ForParentheses                : Boolean;
    /// <summary>
    ///   When True, a space is inserted immediately inside opening and closing
    ///   square brackets surrounding array index expressions.
    /// </summary>
    ForSquareBrackets             : Boolean;
    /// <summary>
    ///   When True, a space is inserted immediately inside opening and closing
    ///   angle brackets surrounding generic type parameters.
    /// </summary>
    InsideAngleBrackets           : Boolean;
    /// <summary>
    ///   Determines how to resolve situations where two spacing rules produce
    ///   contradictory requirements at the same position in the output.
    ///   See TDelphiFmtSpacingConflictOption for available values.
    /// </summary>
    ResolveConflictsAs            : TDelphiFmtSpacingConflictOption;
  end;

  /// <summary>
  ///   Contains all line break and blank line formatting options that control
  ///   where line breaks are inserted, removed, or preserved in the formatted output.
  /// </summary>
  TDelphiFmtLineBreakOptions = record
    /// <summary>
    ///   When True, existing line breaks in the source are preserved rather than
    ///   being added or removed by the formatter.
    /// </summary>
    KeepUserLineBreaks                          : Boolean;
    /// <summary>
    ///   Specifies the line ending character sequence written to the formatted output.
    ///   See TDelphiFmtLineBreakCharsOption for available values.
    /// </summary>
    LineBreakCharacters                         : TDelphiFmtLineBreakCharsOption;
    /// <summary>
    ///   The maximum column width before the formatter considers wrapping a line.
    ///   Lines exceeding this margin may be broken at appropriate positions.
    /// </summary>
    RightMargin                                 : Integer;
    /// <summary>
    ///   When True, leading and trailing whitespace on each line is trimmed
    ///   before the formatted output is written.
    /// </summary>
    TrimSource                                  : Boolean;
    /// <summary>
    ///   When True, a line break is inserted after each label declaration.
    /// </summary>
    AfterLabel                                  : Boolean;
    /// <summary>
    ///   When True, the else and if keywords of an else-if chain are kept on
    ///   the same line rather than placing if on a new line.
    /// </summary>
    InsideElseIf                                : Boolean;
    /// <summary>
    ///   When True, a line break is inserted after each semicolon that terminates
    ///   a statement, ensuring each statement occupies its own line.
    /// </summary>
    AfterSemicolons                             : Boolean;
    /// <summary>
    ///   Controls whether a line break is inserted after the uses keyword in
    ///   uses clauses, or whether the existing style is preserved.
    ///   See TDelphiFmtYesNoAsIsOption for available values.
    /// </summary>
    AfterUsesKeywords                           : TDelphiFmtYesNoAsIsOption;
    /// <summary>
    ///   When True, a line break is inserted before the then keyword in
    ///   if statements, placing it on its own line.
    /// </summary>
    BeforeThen                                  : Boolean;
    /// <summary>
    ///   When True, a line break is inserted around anonymous function bodies
    ///   used in assignment expressions.
    /// </summary>
    InAnonymousFunctionAssignments              : Boolean;
    /// <summary>
    ///   When True, a line break is inserted around anonymous function bodies
    ///   used as parameters in call expressions.
    /// </summary>
    InAnonymousFunctionUsage                    : Boolean;
    /// <summary>
    ///   Controls whether elements of array initialization expressions are
    ///   placed on separate lines.
    ///   See TDelphiFmtYesNoOption for available values.
    /// </summary>
    InArrayInitializations                      : TDelphiFmtYesNoOption;
    /// <summary>
    ///   Controls whether entries in class inheritance lists are placed on
    ///   separate lines.
    ///   See TDelphiFmtYesNoOption for available values.
    /// </summary>
    InInheritanceLists                          : TDelphiFmtYesNoOption;
    /// <summary>
    ///   Controls whether line breaks are added, removed, or preserved in
    ///   label, exports, requires, and contains clauses.
    ///   See TDelphiFmtYesNoAsIsOption for available values.
    /// </summary>
    InLabelExportRequiresContains               : TDelphiFmtYesNoAsIsOption;
    /// <summary>
    ///   When True, each directive in a property declaration (read, write,
    ///   default, etc.) is placed on its own line.
    /// </summary>
    InPropertyDeclarations                      : Boolean;
    /// <summary>
    ///   Controls whether each entry in a uses clause is placed on its own line,
    ///   or whether the existing layout is preserved.
    ///   See TDelphiFmtYesNoAsIsOption for available values.
    /// </summary>
    InUsesClauses                               : TDelphiFmtYesNoAsIsOption;
    /// <summary>
    ///   Controls whether each declaration in a var or const section is placed
    ///   on its own line.
    ///   See TDelphiFmtYesNoOption for available values.
    /// </summary>
    InVarConstSections                          : TDelphiFmtYesNoOption;
    /// <summary>
    ///   When True, unnecessary line breaks between end, else, and begin
    ///   keywords are removed, collapsing them onto a single line.
    /// </summary>
    RemoveInsideEndElseBegin                    : Boolean;
    /// <summary>
    ///   When True, unnecessary line breaks between end, else, and if
    ///   keywords are removed, collapsing them onto a single line.
    /// </summary>
    RemoveInsideEndElseIf                       : Boolean;
    /// <summary>
    ///   When True, a line break is inserted after every begin keyword.
    /// </summary>
    AfterBegin                                  : Boolean;
    /// <summary>
    ///   When True, a line break is inserted after the begin keyword in
    ///   control flow statements such as if, while, for, and repeat.
    /// </summary>
    AfterBeginInControlStatements               : Boolean;
    /// <summary>
    ///   When True, a line break is inserted after the begin keyword that
    ///   opens a method or routine body.
    /// </summary>
    AfterBeginInMethodDefinitions               : Boolean;
    /// <summary>
    ///   When True, a line break is inserted before the begin keyword in
    ///   control flow statements.
    /// </summary>
    BeforeBeginInControlStatements              : Boolean;
    /// <summary>
    ///   When True, a line break is inserted before a single-statement body
    ///   in control flow constructs such as if, while, and for.
    /// </summary>
    BeforeSingleInstructionsInControlStatements : Boolean;
    /// <summary>
    ///   When True, a line break is inserted before a single-statement body
    ///   inside try, except, and finally blocks.
    /// </summary>
    BeforeSingleInstructionsInTryExcept         : Boolean;
    /// <summary>
    ///   When True, the return type of a function declaration is placed on a
    ///   new line rather than following the closing parenthesis of the parameter list.
    /// </summary>
    NewLineForReturnType                        : Boolean;
    /// <summary>
    ///   When True, each argument in a routine call expression is placed on
    ///   its own line.
    /// </summary>
    OneParameterPerLineInCalls                  : Boolean;
    /// <summary>
    ///   When True, each parameter in a routine declaration is placed on
    ///   its own line.
    /// </summary>
    OneParameterPerLineInDefinitions            : Boolean;
    /// <summary>
    ///   The maximum number of consecutive empty lines permitted in the
    ///   formatted output. Additional blank lines beyond this limit are removed.
    /// </summary>
    MaxAdjacentEmptyLines                       : Integer;
    /// <summary>
    ///   The number of empty lines inserted before and after compiler directives
    ///   such as {$IFDEF} and {$ENDIF}.
    /// </summary>
    EmptyLinesAroundCompilerDirectives          : Integer;
    /// <summary>
    ///   The number of empty lines inserted before and after section keywords
    ///   such as interface, implementation, initialization, and finalization.
    /// </summary>
    EmptyLinesAroundSectionKeywords             : Integer;
    /// <summary>
    ///   The number of empty lines inserted between declarations in the
    ///   implementation section of a unit.
    /// </summary>
    EmptyLinesSeparatorInImplementation         : Integer;
    /// <summary>
    ///   The number of empty lines inserted between declarations in the
    ///   interface section of a unit.
    /// </summary>
    EmptyLinesSeparatorInInterface              : Integer;
    /// <summary>
    ///   The number of empty lines inserted before subsections within a
    ///   declaration block.
    /// </summary>
    EmptyLinesBeforeSubsections                 : Integer;
    /// <summary>
    ///   The number of empty lines inserted before the type keyword that
    ///   opens a type declaration block.
    /// </summary>
    EmptyLinesBeforeTypeKeyword                 : Integer;
    /// <summary>
    ///   The number of empty lines inserted before visibility modifiers such
    ///   as private, protected, public, and published in class definitions.
    /// </summary>
    EmptyLinesBeforeVisibilityModifiers         : Integer;
  end;

  /// <summary>
  ///   Contains all capitalisation formatting options that control how keywords,
  ///   directives, numbers, and other tokens are cased in the formatted output.
  /// </summary>
  TDelphiFmtCapitalizationOptions = record
    /// <summary>
    ///   Controls the capitalisation of compiler directives such as
    ///   {$IFDEF}, {$DEFINE}, and {$I}.
    ///   See TDelphiFmtCapitalizationOption for available values.
    /// </summary>
    CompilerDirectives         : TDelphiFmtCapitalizationOption;
    /// <summary>
    ///   Controls the capitalisation of numeric literals, including hexadecimal
    ///   prefixes and digits such as $FF or $ff.
    ///   See TDelphiFmtCapitalizationOption for available values.
    /// </summary>
    Numbers                    : TDelphiFmtCapitalizationOption;
    /// <summary>
    ///   Controls the capitalisation of all other identifiers and tokens not
    ///   covered by the more specific capitalisation options.
    ///   See TDelphiFmtCapitalizationOption for available values.
    /// </summary>
    OtherWords                 : TDelphiFmtCapitalizationOption;
    /// <summary>
    ///   Controls the capitalisation of Delphi reserved words and directives
    ///   such as begin, end, if, then, procedure, and function.
    ///   See TDelphiFmtCapitalizationOption for available values.
    /// </summary>
    ReservedWordsAndDirectives : TDelphiFmtCapitalizationOption;
  end;

  /// <summary>
  ///   Contains all alignment formatting options that control how declarations,
  ///   operators, and comments are vertically aligned across adjacent lines.
  /// </summary>
  TDelphiFmtAlignmentOptions = record
    /// <summary>
    ///   When True, the equals signs in constant declarations within a const
    ///   block are vertically aligned across adjacent declarations.
    /// </summary>
    EqualsInConstants        : Boolean;
    /// <summary>
    ///   When True, the equals signs in initialization expressions such as
    ///   typed constant assignments are vertically aligned.
    /// </summary>
    EqualsInInitializations  : Boolean;
    /// <summary>
    ///   When True, the equals signs in type declarations within a type
    ///   block are vertically aligned across adjacent declarations.
    /// </summary>
    EqualsInTypeDeclarations : Boolean;
    /// <summary>
    ///   When True, assignment operators (:=) in consecutive assignment
    ///   statements are vertically aligned.
    /// </summary>
    AssignmentOperators      : Boolean;
    /// <summary>
    ///   When True, end-of-line comments (//) on consecutive lines are
    ///   vertically aligned to the same column.
    /// </summary>
    EndOfLineComments        : Boolean;
    /// <summary>
    ///   When True, field names and their associated directives in property
    ///   declarations (read, write, default) are vertically aligned.
    /// </summary>
    FieldsInProperties       : Boolean;
    /// <summary>
    ///   When True, type names in variable and field declarations are
    ///   vertically aligned across adjacent declarations.
    /// </summary>
    TypeNames                : Boolean;
    /// <summary>
    ///   When True, the type annotations of parameters in routine declarations
    ///   are vertically aligned across adjacent parameters.
    /// </summary>
    TypesOfParameters        : Boolean;
    /// <summary>
    ///   When True, the colon preceding the type name in declarations is
    ///   included in the vertical alignment calculation.
    /// </summary>
    ColonBeforeTypeNames     : Boolean;
    /// <summary>
    ///   The maximum column beyond which vertical alignment is not extended.
    ///   Declarations requiring alignment past this column are left unaligned.
    /// </summary>
    MaximumColumn            : Integer;
    /// <summary>
    ///   The maximum number of consecutive lines that may remain unaligned
    ///   before the formatter abandons alignment for that group.
    /// </summary>
    MaximumUnalignedLines    : Integer;
  end;

  /// <summary>
  ///   The top-level formatting options record passed to all TDelphiFmt formatting
  ///   methods. Groups all formatting rules into logical sub-records covering
  ///   indentation, spacing, line breaks, capitalisation, and alignment.
  ///   Use TDelphiFmt.DefaultOptions to obtain a pre-populated instance based
  ///   on Castalia-style defaults, then customise individual fields as needed.
  /// </summary>
  TDelphiFmtOptions = record
    /// <summary>
    ///   Options controlling how code blocks, keywords, and constructs are
    ///   indented in the formatted output.
    /// </summary>
    Indentation    : TDelphiFmtIndentationOptions;
    /// <summary>
    ///   Options controlling how spaces are inserted around operators,
    ///   delimiters, brackets, and comments.
    /// </summary>
    Spacing        : TDelphiFmtSpacingOptions;
    /// <summary>
    ///   Options controlling where line breaks are inserted, removed, or
    ///   preserved, and how blank lines are managed throughout the output.
    /// </summary>
    LineBreaks     : TDelphiFmtLineBreakOptions;
    /// <summary>
    ///   Options controlling how keywords, directives, identifiers, and
    ///   numeric literals are capitalised in the formatted output.
    /// </summary>
    Capitalization : TDelphiFmtCapitalizationOptions;
    /// <summary>
    ///   Options controlling vertical alignment of declarations, operators,
    ///   and comments across adjacent lines.
    /// </summary>
    Alignment      : TDelphiFmtAlignmentOptions;
  end;

  /// <summary>
  ///   Represents the result of a single file formatting operation performed
  ///   by TDelphiFmt.FormatFile or TDelphiFmt.FormatFolder. Contains the outcome
  ///   status, change indicator, and any error information for the processed file.
  /// </summary>
  TDelphiFmtFormatResult = record
    /// <summary>
    ///   The full path to the file that was processed by the formatting operation.
    /// </summary>
    FilePath : string;
    /// <summary>
    ///   True if the formatted output differs from the original source and the
    ///   file was rewritten. False if the source was already correctly formatted
    ///   and no changes were necessary.
    /// </summary>
    Changed  : Boolean;
    /// <summary>
    ///   True if the formatting operation completed without error. False if an
    ///   exception occurred or the file could not be processed, in which case
    ///   ErrorMsg contains the reason for the failure.
    /// </summary>
    Success  : Boolean;
    /// <summary>
    ///   Contains the error message if Success is False, describing the reason
    ///   the formatting operation failed. Empty when Success is True.
    /// </summary>
    ErrorMsg : string;
  end;

  /// <summary>
  ///   The main entry point for formatting Delphi source code. Provides methods
  ///   to format source text in memory, format individual files on disk, and
  ///   batch-format entire folders of Delphi source files.
  /// </summary>
  /// <remarks>
  ///   TDelphiFmt operates by parsing the source into an abstract syntax tree
  ///   using a configurable lexer and grammar, then reconstructing the source
  ///   from the AST using an emitter driven entirely by TDelphiFmtOptions.
  ///   The formatting process is idempotent — formatting an already-formatted
  ///   file produces identical output.
  ///   <para>
  ///   Typical usage:
  ///   </para>
  ///   <code>
  ///   var
  ///     LFmt: TDelphiFmt;
  ///     LOptions: TDelphiFmtOptions;
  ///     LResult: TDelphiFmtFormatResult;
  ///   begin
  ///     LFmt := TDelphiFmt.Create();
  ///     try
  ///       LOptions := LFmt.DefaultOptions();
  ///       LResult := LFmt.FormatFile('C:\MyProject\MyUnit.pas', LOptions);
  ///       if not LResult.Success then
  ///         Writeln('Error: ', LResult.ErrorMsg);
  ///     finally
  ///       LFmt.Free();
  ///     end;
  ///   end;
  ///   </code>
  /// </remarks>
  TDelphiFmt = class
  private
    function DoFormatSource(const ASource: string;
      const AOptions: TDelphiFmtOptions; out AErrorMsg: string): string;
    {$HINTS OFF}
    function GetLineBreakStr(
      const AOption: TDelphiFmtLineBreakCharsOption): string;
    {$HINTS ON}
    function DetectEncoding(const ABytes: TBytes): TEncoding;
  public
    /// <summary>
    ///   Creates a new instance of TDelphiFmt.
    /// </summary>
    constructor Create();

    /// <summary>
    ///   Destroys the TDelphiFmt instance and releases all associated resources.
    /// </summary>
    destructor Destroy(); override;


    /// <summary>
    ///   Formats a Delphi source string in memory and returns the formatted result.
    ///   The original source is returned unchanged if parsing fails.
    /// </summary>
    /// <param name="ASource">
    ///   The raw Delphi source code string to format.
    /// </param>
    /// <param name="AOptions">
    ///   A TDelphiFmtOptions record specifying all formatting rules, including
    ///   indentation, spacing, capitalisation, blank lines, and line break style.
    /// </param>
    /// <returns>
    ///   The formatted source code as a string. If the source cannot be parsed,
    ///   the original ASource is returned unmodified.
    /// </returns>
    function FormatSource(const ASource: string;
      const AOptions: TDelphiFmtOptions): string;

    /// <summary>
    ///   Formats a single Delphi source file in place, overwriting it with the
    ///   formatted result. Preserves the original file encoding (UTF-8, UTF-16 LE,
    ///   or ANSI). Optionally creates a .bak backup before writing.
    /// </summary>
    /// <param name="AFilePath">
    ///   The full path to the Delphi source file to format (.pas, .dpr, .dpk, .inc).
    /// </param>
    /// <param name="AOptions">
    ///   A TDelphiFmtOptions record specifying all formatting rules.
    /// </param>
    /// <param name="ACreateBackup">
    ///   When True (default), a backup copy of the original file is created at
    ///   AFilePath + '.bak' before any changes are written.
    /// </param>
    /// <returns>
    ///   A TDelphiFmtFormatResult record containing the file path, whether the file
    ///   was changed, whether the operation succeeded, and any error message.
    /// </returns>
    function FormatFile(const AFilePath: string;
      const AOptions: TDelphiFmtOptions;
      const ACreateBackup: Boolean = True): TDelphiFmtFormatResult;

    /// <summary>
    ///   Formats all Delphi source files found in the specified folder, optionally
    ///   recursing into subdirectories. Processes files with extensions .pas, .dpr,
    ///   .dpk, and .inc. Each file is formatted in place with optional backup.
    /// </summary>
    /// <param name="AFolderPath">
    ///   The full path to the folder containing Delphi source files to format.
    /// </param>
    /// <param name="AOptions">
    ///   A TDelphiFmtOptions record specifying all formatting rules.
    /// </param>
    /// <param name="ARecurse">
    ///   When True (default), all subdirectories are searched recursively.
    ///   When False, only the top-level folder is processed.
    /// </param>
    /// <param name="ACreateBackup">
    ///   When True (default), a .bak backup is created for each file before changes
    ///   are written.
    /// </param>
    /// <returns>
    ///   An array of TDelphiFmtFormatResult records, one per file processed,
    ///   each containing the file path, change status, success flag, and any error.
    /// </returns>
    function FormatFolder(const AFolderPath: string;
      const AOptions: TDelphiFmtOptions;
      const ARecurse: Boolean = True;
      const ACreateBackup: Boolean = True): TArray<TDelphiFmtFormatResult>;

    /// <summary>
    ///   Returns a TDelphiFmtOptions record pre-populated with default formatting
    ///   settings based on the Castalia Delphi Expert style guide. This provides
    ///   a sensible baseline that can be customised before passing to FormatSource,
    ///   FormatFile, or FormatFolder.
    /// </summary>
    /// <returns>
    ///   A TDelphiFmtOptions record with all fields set to Castalia-style defaults.
    /// </returns>
    function DefaultOptions(): TDelphiFmtOptions;
  end;

implementation

uses
  System.Rtti,
  Metamorf.API,
  Metamorf.Common,
  Metamorf.Lexer,
  Metamorf.Parser,
  DelphiFmt.Lexer,
  DelphiFmt.Grammar,
  DelphiFmt.Emitter;

// =============================================================================
//  Constructor / Destructor
// =============================================================================

constructor TDelphiFmt.Create();
begin
  inherited Create();
end;

destructor TDelphiFmt.Destroy();
begin
  inherited Destroy();
end;

// =============================================================================
//  Line break string helper
// =============================================================================

function TDelphiFmt.GetLineBreakStr(
  const AOption: TDelphiFmtLineBreakCharsOption): string;
begin
  case AOption of
    lbcCRLF:   Result := #13#10;
    lbcLF:     Result := #10;
    lbcCR:     Result := #13;
  else
    Result := sLineBreak;  // lbcSystem
  end;
end;

// =============================================================================
//  Encoding detection
// =============================================================================

function TDelphiFmt.DetectEncoding(const ABytes: TBytes): TEncoding;
var
  LLen: Integer;
begin
  LLen := Length(ABytes);

  // UTF-8 BOM: EF BB BF
  if (LLen >= 3) and (ABytes[0] = $EF) and
     (ABytes[1] = $BB) and (ABytes[2] = $BF) then
  begin
    Result := TEncoding.UTF8;
    Exit;
  end;

  // UTF-16 LE BOM: FF FE
  if (LLen >= 2) and (ABytes[0] = $FF) and (ABytes[1] = $FE) then
  begin
    Result := TEncoding.Unicode;
    Exit;
  end;

  // UTF-16 BE BOM: FE FF
  if (LLen >= 2) and (ABytes[0] = $FE) and (ABytes[1] = $FF) then
  begin
    Result := TEncoding.BigEndianUnicode;
    Exit;
  end;

  // Default to UTF-8 without BOM (most modern Delphi source)
  Result := TEncoding.UTF8;
end;

// =============================================================================
//  Core formatting pipeline
// =============================================================================

function TDelphiFmt.DoFormatSource(const ASource: string;
  const AOptions: TDelphiFmtOptions; out AErrorMsg: string): string;
var
  LPax:        TMetamorf;
  LLexer:       TLexer;
  LParser:      TParser;
  LRoot:        TASTNode;
  LEmitter: TDelphiFmtEmitter;
begin
  Result    := ASource;  // on failure, return original
  AErrorMsg := '';

  if Trim(ASource) = '' then
    Exit;

  LPax := TMetamorf.Create();
  try
    // Configure language definition (keywords, operators, grammar rules)
    ConfigLexer(LPax);
    ConfigGrammar(LPax);

    // Step 1: Tokenize
    LLexer := TLexer.Create();
    try
      LLexer.SetConfig(LPax.Config());

      if not LLexer.LoadFromString(ASource) then
        Exit;

      if not LLexer.Tokenize() then
        Exit;

      // Step 2: Parse
      LParser := TParser.Create();
      try
        LParser.SetConfig(LPax.Config());
        LParser.SetErrors(LPax.GetErrors());

        if not LParser.LoadFromLexer(LLexer) then
          Exit;

        LRoot := LParser.ParseTokens();
        if LRoot = nil then
          Exit;

        if LPax.HasErrors() then
        begin
          AErrorMsg := LPax.GetErrors().GetItems()[0].ToIDEString();
          Exit;
        end;

        // Step 3: Emit formatted source
        LEmitter := TDelphiFmtEmitter.Create();
        try
          Result := LEmitter.FormatTree(LRoot, AOptions);
        finally
          LEmitter.Free();
          LRoot.Free();
        end;

      finally
        LParser.Free();
      end;
    finally
      LLexer.Free();
    end;
  finally
    LPax.Free();
  end;
end;

// =============================================================================
//  Default Options (Castalia style)
// =============================================================================

function TDelphiFmt.DefaultOptions(): TDelphiFmtOptions;
begin
  Result := Default(TDelphiFmtOptions);

  // Indentation
  Result.Indentation.ContinuationIndent                    := 2;
  Result.Indentation.DoNotIndentAfterPosition              := 40;
  Result.Indentation.IndentAssemblySections                := True;
  Result.Indentation.IndentBeginEndKeywords                := False;
  Result.Indentation.IndentBlocksBetweenBeginEnd           := True;
  Result.Indentation.IndentClassDefinitionBodies           := False;
  Result.Indentation.IndentComments                        := True;
  Result.Indentation.IndentCompilerDirectives              := False;
  Result.Indentation.IndentFunctionBodies                  := False;
  Result.Indentation.IndentInnerFunctions                  := True;
  Result.Indentation.IndentInterfaceImplementationSections := True;
  Result.Indentation.IndentNestedBracketsParentheses       := False;
  Result.Indentation.IndentCaseContents                    := True;
  Result.Indentation.IndentCaseLabels                      := True;
  Result.Indentation.IndentElseInCase                      := False;
  Result.Indentation.IndentLabels                          := liDecreaseOneIndent;

  // Spacing
  Result.Spacing.AroundColons                 := spAfterOnly;
  Result.Spacing.AroundColonsInFormat         := spNone;
  Result.Spacing.AroundCommas                 := spAfterOnly;
  Result.Spacing.AroundSemicolons             := spAfterOnly;
  Result.Spacing.BeforeParenthesisInFunctions := False;
  Result.Spacing.ForLineComments              := spBeforeAndAfter;
  Result.Spacing.ForBlockComments             := spxInnerAndOuter;
  Result.Spacing.AroundAssignmentOperators    := spBeforeAndAfter;
  Result.Spacing.AroundBinaryOperators        := spBeforeAndAfter;
  Result.Spacing.AroundUnaryPrefixOperators   := spNone;
  Result.Spacing.ForParentheses               := False;
  Result.Spacing.ForSquareBrackets            := False;
  Result.Spacing.InsideAngleBrackets          := False;
  Result.Spacing.ResolveConflictsAs           := scSpace;

  // Line breaks
  Result.LineBreaks.KeepUserLineBreaks                          := False;
  Result.LineBreaks.LineBreakCharacters                         := lbcSystem;
  Result.LineBreaks.RightMargin                                 := 80;
  Result.LineBreaks.TrimSource                                  := True;
  Result.LineBreaks.AfterLabel                                  := True;
  Result.LineBreaks.InsideElseIf                                := False;
  Result.LineBreaks.AfterSemicolons                             := True;
  Result.LineBreaks.AfterUsesKeywords                           := ynaYes;
  Result.LineBreaks.BeforeThen                                  := False;
  Result.LineBreaks.InAnonymousFunctionAssignments              := False;
  Result.LineBreaks.InAnonymousFunctionUsage                    := True;
  Result.LineBreaks.InArrayInitializations                      := ynoYes;
  Result.LineBreaks.InInheritanceLists                          := ynoNo;
  Result.LineBreaks.InLabelExportRequiresContains               := ynaAsIs;
  Result.LineBreaks.InPropertyDeclarations                      := False;
  Result.LineBreaks.InUsesClauses                               := ynaYes;
  Result.LineBreaks.InVarConstSections                          := ynoYes;
  Result.LineBreaks.RemoveInsideEndElseBegin                    := False;
  Result.LineBreaks.RemoveInsideEndElseIf                       := False;
  Result.LineBreaks.AfterBegin                                  := True;
  Result.LineBreaks.AfterBeginInControlStatements               := True;
  Result.LineBreaks.AfterBeginInMethodDefinitions               := True;
  Result.LineBreaks.BeforeBeginInControlStatements              := True;
  Result.LineBreaks.BeforeSingleInstructionsInControlStatements := True;
  Result.LineBreaks.BeforeSingleInstructionsInTryExcept         := True;
  Result.LineBreaks.NewLineForReturnType                        := False;
  Result.LineBreaks.OneParameterPerLineInCalls                  := False;
  Result.LineBreaks.OneParameterPerLineInDefinitions            := False;
  Result.LineBreaks.MaxAdjacentEmptyLines                       := 1;
  Result.LineBreaks.EmptyLinesAroundCompilerDirectives          := 0;
  Result.LineBreaks.EmptyLinesAroundSectionKeywords             := 1;
  Result.LineBreaks.EmptyLinesSeparatorInImplementation         := 1;
  Result.LineBreaks.EmptyLinesSeparatorInInterface              := 1;
  Result.LineBreaks.EmptyLinesBeforeSubsections                 := 1;
  Result.LineBreaks.EmptyLinesBeforeTypeKeyword                 := 1;
  Result.LineBreaks.EmptyLinesBeforeVisibilityModifiers         := 0;

  // Capitalization
  Result.Capitalization.CompilerDirectives         := capUpperCase;
  Result.Capitalization.Numbers                    := capUpperCase;
  Result.Capitalization.OtherWords                 := capAsFirstOccurrence;
  Result.Capitalization.ReservedWordsAndDirectives := capLowerCase;

  // Alignment — all off for v1
  Result.Alignment.EqualsInConstants        := False;
  Result.Alignment.EqualsInInitializations  := False;
  Result.Alignment.EqualsInTypeDeclarations := False;
  Result.Alignment.AssignmentOperators      := False;
  Result.Alignment.EndOfLineComments        := False;
  Result.Alignment.FieldsInProperties       := False;
  Result.Alignment.TypeNames                := False;
  Result.Alignment.TypesOfParameters        := False;
  Result.Alignment.ColonBeforeTypeNames     := False;
  Result.Alignment.MaximumColumn            := 60;
  Result.Alignment.MaximumUnalignedLines    := 0;
end;

// =============================================================================
//  Public API
// =============================================================================

function TDelphiFmt.FormatSource(const ASource: string;
  const AOptions: TDelphiFmtOptions): string;
var
  LIgnored: string;
begin
  Result := DoFormatSource(ASource, AOptions, LIgnored);
end;

function TDelphiFmt.FormatFile(const AFilePath: string;
  const AOptions: TDelphiFmtOptions;
  const ACreateBackup: Boolean): TDelphiFmtFormatResult;
var
  LRawBytes:   TBytes;
  LEncoding:   TEncoding;
  LSource:     string;
  LFormatted:  string;
  LBackupPath: string;
  LParseError: string;
begin
  Result.FilePath := AFilePath;
  Result.Changed  := False;
  Result.Success  := False;
  Result.ErrorMsg := '';

  try
    if not TFile.Exists(AFilePath) then
    begin
      Result.ErrorMsg := 'File not found: ' + AFilePath;
      Exit;
    end;

    LRawBytes := TFile.ReadAllBytes(AFilePath);
    LEncoding := DetectEncoding(LRawBytes);
    LSource   := LEncoding.GetString(LRawBytes);

    // Strip BOM if present
    if (Length(LSource) > 0) and (Ord(LSource[1]) = $FEFF) then
      LSource := Copy(LSource, 2, MaxInt);

    LFormatted := DoFormatSource(LSource, AOptions, LParseError);
    if LParseError <> '' then
    begin
      Result.ErrorMsg := LParseError;
      Exit;
    end;

    if LFormatted <> LSource then
    begin
      if ACreateBackup then
      begin
        LBackupPath := AFilePath + '.bak';
        TFile.WriteAllBytes(LBackupPath, LRawBytes);
      end;
      TFile.WriteAllText(AFilePath, LFormatted, LEncoding);
      Result.Changed := True;
    end;

    Result.Success := True;

  except
    on E: Exception do
      Result.ErrorMsg := E.Message;
  end;
end;

function TDelphiFmt.FormatFolder(const AFolderPath: string;
  const AOptions: TDelphiFmtOptions;
  const ARecurse: Boolean;
  const ACreateBackup: Boolean): TArray<TDelphiFmtFormatResult>;
const
  SOURCE_EXTS: array[0..3] of string = ('.pas', '.dpr', '.dpk', '.inc');
var
  LResults:   TList<TDelphiFmtFormatResult>;
  LFiles:     TArray<string>;
  LFile:      string;
  LExt:       string;
  LSearchOpt: TSearchOption;
  LIsSource:  Boolean;
  LSrcExt:    string;
begin
  LResults := TList<TDelphiFmtFormatResult>.Create();
  try
    if ARecurse then
      LSearchOpt := TSearchOption.soAllDirectories
    else
      LSearchOpt := TSearchOption.soTopDirectoryOnly;

    LFiles := TDirectory.GetFiles(AFolderPath, '*.*', LSearchOpt);

    for LFile in LFiles do
    begin
      LExt      := LowerCase(TPath.GetExtension(LFile));
      LIsSource := False;
      for LSrcExt in SOURCE_EXTS do
      begin
        if LExt = LSrcExt then
        begin
          LIsSource := True;
          Break;
        end;
      end;

      if not LIsSource then
        Continue;

      LResults.Add(FormatFile(LFile, AOptions, ACreateBackup));
    end;

    Result := LResults.ToArray();
  finally
    LResults.Free();
  end;
end;

end.
