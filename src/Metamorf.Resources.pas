{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Resources;

{$I Metamorf.Defines.inc}

interface

const
  //--------------------------------------------------------------------------
  // ZigBuild Error Codes (Z001-Z099)
  //--------------------------------------------------------------------------
  ERR_ZIGBUILD_NO_OUTPUT_PATH   = 'Z001';
  ERR_ZIGBUILD_NO_SOURCES       = 'Z002';
  ERR_ZIGBUILD_SAVE_FAILED      = 'Z003';
  ERR_ZIGBUILD_ZIG_NOT_FOUND    = 'Z004';
  ERR_ZIGBUILD_BUILD_FAILED     = 'Z005';
  WRN_ZIGBUILD_CANNOT_RUN_CROSS = 'Z006';

  //--------------------------------------------------------------------------
  // Lexer Error Codes (L001-L099)
  //--------------------------------------------------------------------------
  ERR_LEXER_FILE_NOT_FOUND      = 'L001';
  ERR_LEXER_FILE_READ_ERROR     = 'L002';
  ERR_LEXER_INVALID_FILENAME    = 'L003';
  ERR_LEXER_UNEXPECTED_CHAR     = 'L004';
  ERR_LEXER_UNTERMINATED_STRING = 'L005';
  ERR_LEXER_UNTERMINATED_CHAR   = 'L006';
  ERR_LEXER_INVALID_NUMBER      = 'L007';
  ERR_LEXER_INVALID_ESCAPE      = 'L008';
  ERR_LEXER_INVALID_HEX_ESCAPE  = 'L009';
  ERR_LEXER_UNTERMINATED_COMMENT= 'L010';
  ERR_LEXER_COND_UNMATCHED      = 'L011';
  ERR_LEXER_COND_DUPLICATE      = 'L012';
  ERR_LEXER_COND_UNTERMINATED   = 'L013';
  ERR_LEXER_COND_MISSING_ARG    = 'L014';
  ERR_LEXER_DIRECTIVE_ERROR      = 'L015';

  //--------------------------------------------------------------------------
  // Parser Error Codes (P001-P099)
  //--------------------------------------------------------------------------
  ERR_PARSER_LEXER_NOT_SET      = 'P001';
  ERR_PARSER_NO_TOKENS          = 'P002';
  ERR_PARSER_EXPECTED_TOKEN     = 'P003';
  ERR_PARSER_EXPECTED_IDENT     = 'P004';
  ERR_PARSER_KEYWORD_AS_IDENT   = 'P005';
  ERR_PARSER_UNEXPECTED_TOKEN   = 'P006';
  ERR_PARSER_EXPECTED_DECL      = 'P007';
  ERR_PARSER_EXPECTED_TYPE_REF  = 'P008';
  ERR_PARSER_MISSING_END        = 'P009';
  ERR_PARSER_UNMATCHED_ENDIF    = 'P010';
  ERR_PARSER_UNMATCHED_ELSE     = 'P011';
  ERR_PARSER_UNMATCHED_ELSEIF   = 'P012';
  ERR_PARSER_UNCLOSED_COND      = 'P013';
  ERR_PARSER_UNKNOWN_DIRECTIVE  = 'P014';

  //--------------------------------------------------------------------------
  // Semantic Error Codes (S001-S099)
  //--------------------------------------------------------------------------
  ERR_SEMANTIC_UNDECLARED_IDENT = 'S001';
  ERR_SEMANTIC_UNDECLARED_TYPE  = 'S002';
  ERR_SEMANTIC_DUPLICATE_DECL   = 'S003';
  ERR_SEMANTIC_TYPE_MISMATCH    = 'S004';
  ERR_SEMANTIC_NOT_A_VARIABLE   = 'S005';
  ERR_SEMANTIC_RETURN_MISMATCH  = 'S006';
  ERR_SEMANTIC_OP_TYPE_MISMATCH = 'S007';
  ERR_SEMANTIC_ARG_COUNT        = 'S008';
  ERR_SEMANTIC_ARG_TYPE         = 'S009';
  ERR_SEMANTIC_FIELD_NOT_FOUND  = 'S010';
  ERR_SEMANTIC_CANNOT_DEREF     = 'S011';
  ERR_SEMANTIC_CANNOT_INDEX     = 'S012';
  ERR_SEMANTIC_CANNOT_CALL      = 'S013';
  ERR_SEMANTIC_NOT_BOOLEAN      = 'S014';
  ERR_SEMANTIC_CASE_NOT_ORDINAL = 'S015';
  ERR_SEMANTIC_FOR_NOT_ORDINAL  = 'S016';
  ERR_SEMANTIC_SET_NOT_ORDINAL  = 'S017';
  ERR_SEMANTIC_MODULE_NOT_FOUND = 'S018';
  ERR_SEMANTIC_NOT_EXPORTED     = 'S019';
  ERR_SEMANTIC_INCOMPAT_TYPES   = 'S020';

  //--------------------------------------------------------------------------
  // CodeGen Error Codes (G001-G099)
  //--------------------------------------------------------------------------
  ERR_CODEGEN_NIL_ROOT          = 'G001';
  ERR_CODEGEN_NO_CONFIG         = 'G002';
  ERR_CODEGEN_EMPTY_UNIT        = 'G003';

  //--------------------------------------------------------------------------
  // Compiler Error Codes (C001-C099)
  //--------------------------------------------------------------------------
  ERR_COMPILER_NO_SOURCE        = 'C000';
  ERR_COMPILER_INVALID_TARGET   = 'C001';
  ERR_COMPILER_INVALID_OPTIMIZE = 'C002';
  ERR_COMPILER_INVALID_SUBSYS   = 'C003';
  ERR_COMPILER_MODULE_NOT_FOUND = 'C010';

resourcestring

  //--------------------------------------------------------------------------
  // Severity Names
  //--------------------------------------------------------------------------
  RSSeverityHint    = 'Hint';
  RSSeverityWarning = 'Warning';
  RSSeverityError   = 'Error';
  RSSeverityFatal   = 'Fatal';
  RSSeverityNote    = 'Note';
  RSSeverityUnknown = 'Unknown';

  //--------------------------------------------------------------------------
  // Error Format Strings
  //--------------------------------------------------------------------------
  RSErrorFormatSimple              = '%s %s: %s';
  RSErrorFormatWithLocation        = '%s: %s %s: %s';
  RSErrorFormatRelatedSimple       = '  %s: %s';
  RSErrorFormatRelatedWithLocation = '  %s: %s: %s';

  //--------------------------------------------------------------------------
  // Lexer Messages
  //--------------------------------------------------------------------------
  RSLexerTokenizing          = 'Tokenizing %s...';
  RSLexerFileNotFound        = 'File not found: ''%s''';
  RSLexerFileReadError       = 'Cannot read file ''%s'': %s';
  RSLexerInvalidFilename     = 'Invalid filename: ''%s'' (%s)';
  RSLexerUnexpectedChar      = 'Unexpected character: ''%s''';
  RSLexerUnterminatedString  = 'Unterminated string literal';
  RSLexerUnterminatedChar    = 'Unterminated character literal';
  RSLexerInvalidNumber       = 'Invalid number format: %s';
  RSLexerInvalidEscape       = 'Invalid escape sequence: \%s';
  RSLexerInvalidHexEscape    = 'Invalid hex escape sequence';
  RSLexerUnterminatedComment = 'Unterminated comment';
  RSLexerCondUnmatched        = '%s without matching @ifdef';
  RSLexerCondDuplicate        = 'Duplicate @else in conditional block';
  RSLexerCondUnterminated     = 'Unterminated conditional block (missing @endif)';
  RSLexerCondMissingArg       = '%s requires a symbol name';
  RSLexerDirectiveError        = '%s';

  //--------------------------------------------------------------------------
  // Parser Messages
  //--------------------------------------------------------------------------
  RSParserParsing            = 'Parsing %s...';
  RSParserLexerNotSet        = 'Lexer not set';
  RSParserNoTokens           = 'No tokens to parse';
  RSParserExpectedToken      = 'Expected %s but found %s';
  RSParserExpectedIdentifier = 'Expected identifier but found ''%s''';
  RSParserKeywordAsIdentifier= '''%s'' is a reserved keyword and cannot be used as an identifier';
  RSParserUnexpectedToken    = 'Unexpected token: ''%s''';
  RSParserExpectedDeclaration= 'Expected declaration but found %s';
  RSParserExpectedTypeRef    = 'Expected type reference';
  RSParserMissingEnd         = 'Missing ''end'' or end of declaration';
  RSParserUnmatchedEndif     = 'Unexpected $endif without matching $ifdef/$ifndef';
  RSParserUnmatchedElse      = 'Unexpected $else without matching $ifdef/$ifndef';
  RSParserUnmatchedElseif    = 'Unexpected $elseif without matching $ifdef/$ifndef';
  RSParserUnclosedConditional= 'Unclosed conditional: missing $endif';
  RSParserUnknownDirective   = 'Unknown directive ''$%s''';
  RSParserExpectedSymbolName = 'Expected symbol name after $%s';

  //--------------------------------------------------------------------------
  // Semantic Messages
  //--------------------------------------------------------------------------
  RSSemanticAnalyzing              = 'Analyzing %s...';
  RSSemanticUndeclaredIdentifier   = 'Undeclared identifier: ''%s''';
  RSSemanticUndeclaredType         = 'Undeclared type: ''%s''';
  RSSemanticDuplicateDeclaration   = 'Duplicate declaration: ''%s''';
  RSSemanticAssignmentTypeMismatch = 'Cannot assign %s to %s';
  RSSemanticNotAVariable           = '''%s'' is not a variable';
  RSSemanticReturnTypeMismatch     = 'Return type mismatch: expected %s, got %s';
  RSSemanticOperatorTypeMismatch   = 'Operator ''%s'' cannot be applied to %s and %s';
  RSSemanticNotEnoughArguments     = 'Not enough arguments for ''%s'': expected %d, got %d';
  RSSemanticTooManyArguments       = 'Too many arguments for ''%s'': expected %d, got %d';
  RSSemanticArgumentTypeMismatch   = 'Argument %d type mismatch: expected %s, got %s';
  RSSemanticFieldNotFound          = 'Field ''%s'' not found in type ''%s''';
  RSSemanticCannotDereference      = 'Cannot dereference non-pointer type %s';
  RSSemanticArrayIndexNotOrdinal   = 'Array index must be ordinal type, got %s';
  RSSemanticCannotIndexType        = 'Cannot index non-array type %s';
  RSSemanticSetElementNotOrdinal   = 'Set element must be ordinal type';
  RSSemanticSetElementTypeMismatch = 'Set element type mismatch: expected %s, got %s';
  RSSemanticConditionNotBoolean    = 'Condition must be boolean, got %s';
  RSSemanticCaseSelectorNotOrdinal = 'Case selector must be ordinal type';
  RSSemanticForVarNotOrdinal       = 'For loop variable must be ordinal type';
  RSSemanticCannotCallType         = 'Cannot call non-routine type %s';
  RSSemanticModuleNotFound         = 'Module not found: ''%s''';
  RSSemanticSymbolNotExported      = 'Symbol ''%s'' is not exported from module ''%s''';
  RSSemanticIncompatibleTypes      = 'Incompatible types: %s and %s';
  RSSemanticUnaryOpMismatch        = 'Unary operator ''%s'' cannot be applied to %s';
  RSSemanticAddressOfNonAddressable= 'Cannot take address of this expression';

  //--------------------------------------------------------------------------
  // CodeGen Messages
  //--------------------------------------------------------------------------
  RSCodeGenEmitting        = 'Emitting %s...';
  RSCodeGenComplete        = 'Emission complete';
  RSCodeGenGeneratedHeader = 'Generated header: %s';
  RSCodeGenGeneratedSource = 'Generated source: %s';
  RSCodeGenNilRoot         = 'AST root is nil';
  RSCodeGenNoConfig        = 'No language config set';
  RSCodeGenEmptyUnit       = 'Unit name is empty';

  //--------------------------------------------------------------------------
  // ZigBuild Messages
  //--------------------------------------------------------------------------
  RSZigBuildNoOutputPath    = 'Output path not specified';
  RSZigBuildNoSources       = 'No source files specified';
  RSZigBuildSaveFailed      = 'Failed to save build.zig: %s';
  RSZigBuildFileNotFound    = 'build.zig not found: %s';
  RSZigBuildZigNotFound     = 'Zig executable not found (expected: %s)';
  RSZigBuildFailed          = 'Zig build failed with exit code: %d';
  RSZigBuildNoProjectName   = 'Project name not set';
  RSZigBuildExeNotFound     = 'Executable not found: %s';
  RSZigBuildRunFailed       = 'Execution failed with exit code: %d';
  RSZigBuildCannotRunLib    = 'Cannot run a library, only executables can be run';
  RSZigBuildCannotRunCross  = 'Cannot run cross-compiled binary (target: %s). Only Win64 and Linux64 (via WSL) targets can be run from Windows';
  RSZigBuildSaving          = 'Saving build.zig...';
  RSZigBuildTargetPlatform  = 'Target platform: %s';
  RSZigBuildOptimizeLevel   = 'Optimization level: %s';
  RSZigBuildSubsystem        = 'Subsystem: %s';
  RSZigBuildBuilding        = 'Building %s...';
  RSZigBuildFailedWithCode  = 'Build failed with exit code %d';
  RSZigBuildSucceeded       = 'Build succeeded';
  RSZigBuildOutput          = 'Output: %s';
  RSZigBuildCopying         = 'Copying %s...';
  RSZigBuildDllNotFound     = 'DLL not found: %s';
  RSZigBuildRunning         = 'Running %s...';

  //--------------------------------------------------------------------------
  // Compiler Messages
  //--------------------------------------------------------------------------
  RSCompilerNoSource          = 'No source file specified';
  RSCompilerSourceNotFound    = 'Source file not found: ''%s''';
  RSCompilerCompiling         = 'Compiling %s...';
  RSCompilerSuccess          = 'Compilation successful';
  RSCompilerFailed           = 'Compilation failed with %d error(s)';
  RSInvalidTargetPlatform    = 'Invalid target platform: ''%s''';
  RSInvalidOptimizeLevel     = 'Invalid optimization level: ''%s''';
  RSInvalidSubsystem         = 'Invalid subsystem: ''%s''. Expected ''console'' or ''gui''';
  RSCompilerModuleNotFound    = 'Module source file not found: ''%s''';

  //--------------------------------------------------------------------------
  // Fatal / I/O Messages
  //--------------------------------------------------------------------------
  RSFatalFileNotFound  = 'File not found: ''%s''';
  RSFatalFileReadError = 'Cannot read file ''%s'': %s';
  RSFatalInternalError = 'Internal error: %s';

  //--------------------------------------------------------------------------
  // .mor Lexer Messages
  //--------------------------------------------------------------------------
  RSMorLexerUnexpectedChar       = 'Unexpected character: ''%s''';
  RSMorLexerUnterminatedString   = 'Unterminated string literal';
  RSMorLexerUnterminatedComment  = 'Unterminated block comment';
  RSMorLexerInvalidNumber        = 'Invalid number format: %s';
  RSMorLexerUnterminatedTriple   = 'Unterminated triple-quoted string';

  //--------------------------------------------------------------------------
  // .mor Parser Messages
  //--------------------------------------------------------------------------
  RSMorParserExpectedToken       = 'Expected %s but found ''%s''';
  RSMorParserUnexpectedTopLevel  = 'Unexpected top-level token: ''%s''';
  RSMorParserExpectedIdentifier  = 'Expected identifier but found ''%s''';
  RSMorParserExpectedLBrace      = 'Expected ''{'' to open block';
  RSMorParserExpectedRBrace      = 'Expected ''}'' to close block';
  RSMorParserExpectedSemicolon   = 'Expected '';''';
  RSMorParserUnexpectedExpr      = 'Unexpected token in expression: ''%s''';

  //--------------------------------------------------------------------------
  // .mor Interpreter Messages
  //--------------------------------------------------------------------------
  RSMorInterpUndefinedVar        = 'Undefined variable: ''%s''';
  RSMorInterpUndefinedRoutine    = 'Undefined routine: ''%s''';
  RSMorInterpUnknownBuiltin      = 'Unknown built-in function: ''%s''';
  RSMorInterpTypeMismatch        = 'Type error: expected %s, got %s';
  RSMorInterpNilNode             = 'Nil node dereference';
  RSMorInterpChildOutOfBounds    = 'Child index %d out of bounds (count: %d)';
  RSMorInterpEmitterCrash        = 'Emitter crash on node ''%s'': %s';
  RSMorInterpBuiltinCrash        = 'Builtin ''%s'' crash on node ''%s'': %s';
  RSMorInterpBadIndexType        = 'getChild index has unexpected type: %s (value: %s, node: %s)';

  //--------------------------------------------------------------------------
  // User Lexer Messages
  //--------------------------------------------------------------------------
  RSUserLexerUnexpectedChar      = 'Unexpected character: ''%s''';
  RSUserLexerUnterminatedString  = 'Unterminated string literal';
  RSUserLexerUnterminatedComment = 'Unterminated comment';

  //--------------------------------------------------------------------------
  // User Parser Messages
  //--------------------------------------------------------------------------
  RSUserParserExpectedToken      = 'Expected %s but found ''%s''';
  RSUserParserNoPrefixHandler    = 'Unexpected token in expression: ''%s''';

  //--------------------------------------------------------------------------
  // User Semantic Messages
  //--------------------------------------------------------------------------
  RSUserSemanticUndeclared       = 'Undeclared identifier: ''%s''';
  RSUserSemanticDuplicate        = 'Duplicate declaration: ''%s''';
  RSUserSemanticModuleNotFound   = 'Module not found: ''%s''';

  //--------------------------------------------------------------------------
  // User CodeGen Messages
  //--------------------------------------------------------------------------
  RSUserCodeGenEmitterError      = 'Emitter error on node ''%s'': %s';

  //--------------------------------------------------------------------------
  // .mor Engine Status Messages
  //--------------------------------------------------------------------------
  RSMorLexerTokenizing           = 'Tokenizing .mor file: %s...';
  RSMorParserParsing             = 'Parsing .mor file: %s...';
  RSMorInterpSetup               = 'Setting up language tables...';
  RSUserLexerTokenizing          = 'Tokenizing %s...';
  RSUserParserParsing            = 'Parsing %s...';
  RSUserSemanticAnalyzing        = 'Analyzing %s...';
  RSUserCodeGenEmitting          = 'Emitting %s...';

implementation

end.
