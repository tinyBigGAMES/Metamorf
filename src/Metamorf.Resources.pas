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
  RSUserLexerUnknownDirective    = 'Unknown directive: ''%s''';

  //--------------------------------------------------------------------------
  // User Parser Messages
  //--------------------------------------------------------------------------
  RSUserParserExpectedToken      = 'Expected %s but found ''%s''';
  RSUserParserNoPrefixHandler    = 'Unexpected token in expression: ''%s''';


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
  RSEngineTargetPlatform          = 'Target: %s';
  RSEngineBuildMode               = 'Build mode: %s';
  RSEngineOptimizeLevel           = 'Optimization: %s';
  RSEngineCppPassthrough          = 'Registering C++ passthrough...';

  //--------------------------------------------------------------------------
  // Engine API Messages
  //--------------------------------------------------------------------------
  RSEngineAPIMorNotLoaded = 'LoadMor must be called before ParseSource';
  RSEngineAPISrcNotParsed = 'ParseSource must be called before RunSemantics';
  RSEngineAPISemNotRun    = 'RunSemantics must be called before RunEmitters';
  RSEngineAPIEmitNotRun   = 'RunEmitters must be called before Build';

implementation

end.
