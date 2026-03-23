{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

/// <summary>
///   Provides the public API for the DelphiCImp C header to Delphi import unit
///   generator. Declares the TDelphCImp class which is the main entry point for
///   parsing C header files and generating equivalent Delphi import units with
///   type declarations, external function bindings, and constant definitions.
/// </summary>
/// <remarks>
///   To generate a Delphi import unit from a C header, create an instance of
///   TDelphCImp, configure it with the header file path, include paths, module
///   name, and DLL name, then call Process. Alternatively, load all settings
///   from a TOML configuration file via LoadFromConfig and call Process.
///   <para>
///   The generator uses zig cc as a preprocessor to resolve macros and includes
///   before parsing the C declarations into structs, enums, typedefs, function
///   pointers, external functions, and #define constants.
///   </para>
///   <para>
///   Post-generation text insertions and replacements allow fine-tuning of the
///   output without manual editing.
///   </para>
/// </remarks>
unit DelphiCImp;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Build,
  Metamorf.Config,
  DelphiCImp.Common;

type
  /// <summary>
  ///   The main entry point for generating Delphi import units from C header
  ///   files. Provides methods to configure include paths, source filters, DLL
  ///   names, and output options, then processes a C header through
  ///   preprocessing, parsing, and Delphi code generation in a single call
  ///   to Process.
  /// </summary>
  /// <remarks>
  ///   TDelphCImp operates by invoking zig cc to preprocess the header
  ///   (resolving macros, includes, and conditionals), then tokenising and
  ///   parsing the preprocessed output to extract structs, unions, enums,
  ///   typedefs, function pointer types, external function declarations, and
  ///   #define constants. The extracted declarations are mapped to their Delphi
  ///   equivalents and emitted as a complete Delphi unit with platform-conditional
  ///   DLL name constants and properly ordered type blocks.
  ///   <para>
  ///   Typical usage:
  ///   </para>
  ///   <code>
  ///   var
  ///     LImp: TDelphCImp;
  ///   begin
  ///     LImp := TDelphCImp.Create();
  ///     try
  ///       LImp.SetHeader('include/raylib.h');
  ///       LImp.SetModuleName('raylib');
  ///       LImp.SetDllName('raylib');
  ///       LImp.SetUnitName('URaylibImport');
  ///       LImp.AddIncludePath('include');
  ///       LImp.AddSourcePath('include');
  ///       LImp.SetOutputPath('output');
  ///       if not LImp.Process() then
  ///         Writeln('Error: ', LImp.GetLastError());
  ///     finally
  ///       LImp.Free();
  ///     end;
  ///   end;
  ///   </code>
  ///   <para>
  ///   Alternatively, all settings can be loaded from a TOML configuration file:
  ///   </para>
  ///   <code>
  ///   var
  ///     LImp: TDelphCImp;
  ///   begin
  ///     LImp := TDelphCImp.Create();
  ///     try
  ///       if LImp.LoadFromConfig('raylib.toml') then
  ///         LImp.Process();
  ///     finally
  ///       LImp.Free();
  ///     end;
  ///   end;
  ///   </code>
  /// </remarks>
  { TDelphCImp }
  TDelphCImp = class(TStatusObject)
  private
    FLexer: TCLexer;
    FPos: Integer;
    FCurrentToken: TCToken;
    FModuleName: string;
    FUnitName: string;
    FDllName: string;
    FDelayLoad: Boolean;
    FOutput: TStringBuilder;
    FIndent: Integer;
    FIncludePaths: TList<string>;
    FIncludeModules: TDictionary<string, string>;
    FExternalTypes: TDictionary<string, string>;
    FSourcePaths: TList<string>;
    FExcludedTypes: TList<string>;
    FExcludedFunctions: TList<string>;
    FSavePreprocessed: Boolean;
    FOutputPath: string;
    FHeader: string;
    FLastError: string;

    // Per-platform DLL name overrides
    FPlatformDllNames: TDictionary<TTargetPlatform, string>;

    FStructs: TList<TCStructInfo>;
    FEnums: TList<TCEnumInfo>;
    FTypedefs: TList<TCTypedefInfo>;
    FDefines: TList<TCDefineInfo>;
    FFunctions: TList<TCFunctionInfo>;
    FForwardDecls: TList<string>;
    FInsertions: TList<TInsertionInfo>;
    FReplacements: TList<TReplacementInfo>;
    FPostCopyFiles: TList<TPostCopyInfo>;
    FCurrentSourceFile: string;

    function GetZigExePath(): string;
    function PreprocessHeader(const AHeaderFile: string; out APreprocessedSource: string): Boolean;

    function IsAtEnd(): Boolean;
    {$HINTS OFF}
    function Peek(): TCToken;
    {$HINTS ON}
    function PeekNext(): TCToken;
    procedure Advance();
    function Check(const AKind: TCTokenKind): Boolean;
    function Match(const AKind: TCTokenKind): Boolean;
    function MatchAny(const AKinds: array of TCTokenKind): Boolean;

    procedure SkipToSemicolon();
    procedure SkipToRBrace();
    function IsTypeKeyword(): Boolean;
    function ParseBaseType(): string;
    function ParsePointerDepth(): Integer;

    procedure ParseTopLevel();
    procedure ParseTypedef();
    procedure ParseStruct(const AIsUnion: Boolean; out AInfo: TCStructInfo);
    procedure ParseEnum(out AInfo: TCEnumInfo);
    procedure ParseFunction(const AReturnType: string; const AReturnPtrDepth: Integer; const AFuncName: string);
    procedure ParseStructField(const AStruct: TCStructInfo; var AFields: TArray<TCFieldInfo>);

    procedure EmitLn(const AText: string = '');
    procedure EmitFmt(const AFormat: string; const AArgs: array of const);
    function MapCTypeToDelphi(const ACType: string; const AIsPointer: Boolean; const APtrDepth: Integer; const AIsConstTarget: Boolean = False): string;
    function ResolveTypedefAlias(const ATypeName: string): string;
    function SanitizeIdentifier(const AName: string): string;
    function DelphifyTypeName(const AName: string): string;
    function FormatLibName(const APlatform: TTargetPlatform; const AName: string): string;
    function IsAllowedSourceFile(): Boolean;
    function GetModuleForCurrentFile(): string;
    function TypedefReferencesExcludedType(const ATypedef: TCTypedefInfo): Boolean;
    function FunctionReferencesExcludedType(const AFunc: TCFunctionInfo): Boolean;
    procedure GenerateDelphiUnit();
    procedure GenerateAllTypes();
    procedure GenerateFunctions();
    procedure GenerateSimpleConstants();
    procedure GenerateTypedConstants();
    procedure ProcessInsertions();
    procedure DoPostCopyFile();

    procedure ParseDefines(const APreprocessedSource: string);
    procedure ParsePreprocessed(const APreprocessedSource: string);

  public
    /// <summary>
    ///   Creates a new instance of TDelphCImp and initialises all internal
    ///   collections, the C lexer, and the output buffer.
    /// </summary>
    constructor Create(); override;
    /// <summary>
    ///   Destroys the TDelphCImp instance and releases all associated resources
    ///   including the lexer, parsed declaration lists, and configuration
    ///   collections.
    /// </summary>
    destructor Destroy(); override;

    /// <summary>
    ///   Adds a directory to the list of include paths passed to the zig cc
    ///   preprocessor. Optionally associates the path with a module name so
    ///   that types discovered under that path are recorded as external types
    ///   belonging to that module rather than being emitted in the output unit.
    /// </summary>
    /// <param name="APath">
    ///   The directory path to add as an include search directory. Forward and
    ///   back slashes are normalised internally.
    /// </param>
    /// <param name="AModuleName">
    ///   An optional module name to associate with this include path. When set,
    ///   types found in headers under this path are recorded as external to
    ///   that module and excluded from the generated output. Pass an empty
    ///   string (the default) to treat the path as a standard include without
    ///   module association.
    /// </param>
    procedure AddIncludePath(const APath: string; const AModuleName: string = '');
    /// <summary>
    ///   Adds a directory to the source path filter list. When source paths are
    ///   specified, only declarations found in headers located under one of the
    ///   source paths are included in the generated output. Headers from other
    ///   locations are skipped. If no source paths are added, include paths are
    ///   used as the filter instead.
    /// </summary>
    /// <param name="APath">
    ///   The directory path to add as an allowed source location. Forward and
    ///   back slashes are normalised internally.
    /// </param>
    procedure AddSourcePath(const APath: string);
    /// <summary>
    ///   Adds a type name to the exclusion list. Excluded types and any typedefs
    ///   or functions that reference them are omitted from the generated output.
    ///   Also used to exclude specific #define constant names.
    /// </summary>
    /// <param name="ATypeName">
    ///   The exact C type name to exclude, such as a struct, enum, or typedef
    ///   alias name.
    /// </param>
    procedure AddExcludedType(const ATypeName: string);
    /// <summary>
    ///   Adds a function name to the exclusion list. Excluded functions are
    ///   omitted from the generated external function declarations regardless
    ///   of whether their parameter and return types are otherwise valid.
    /// </summary>
    /// <param name="AFuncName">
    ///   The exact C function name to exclude from the generated output.
    /// </param>
    procedure AddExcludedFunction(const AFuncName: string);
    /// <summary>
    ///   Controls whether the intermediate preprocessed C source is saved to
    ///   disk after preprocessing. When enabled, the preprocessed output is
    ///   written to the output directory as ModuleName_pp.c for inspection
    ///   and debugging.
    /// </summary>
    /// <param name="AValue">
    ///   True to save the preprocessed source file; False (the default) to
    ///   delete it after parsing.
    /// </param>
    procedure SetSavePreprocessed(const AValue: Boolean);
    /// <summary>
    ///   Controls whether the generated external function declarations use
    ///   the Delphi delayed loading mechanism. When enabled, each external
    ///   function is declared with the delayed directive, deferring DLL
    ///   loading until the function is first called at runtime.
    /// </summary>
    /// <param name="AValue">
    ///   True to emit external declarations with the delayed directive;
    ///   False (the default) to use standard static linking.
    /// </param>
    procedure EnableDelayLoad(const AValue: Boolean);
    /// <summary>
    ///   Registers a text insertion to be applied to the generated output after
    ///   code generation completes. The specified text is inserted immediately
    ///   after the target line in the output.
    /// </summary>
    /// <param name="ATargetLine">
    ///   The content of the line in the generated output after which the text
    ///   should be inserted. Matching is performed on trimmed, case-insensitive
    ///   content.
    /// </param>
    /// <param name="AText">
    ///   The text to insert. May contain multiple lines including line breaks.
    /// </param>
    /// <param name="AOccurrence">
    ///   Which occurrence of the target line to insert after. Defaults to 1
    ///   (the first occurrence). Set to a higher value to target a later
    ///   occurrence of the same line content.
    /// </param>
    procedure InsertTextAfter(const ATargetLine: string; const AText: string; const AOccurrence: Integer = 1);
    /// <summary>
    ///   Registers a file-content insertion to be applied to the generated
    ///   output after code generation completes. The entire contents of the
    ///   specified file are read and inserted immediately after the target
    ///   line in the output.
    /// </summary>
    /// <param name="ATargetLine">
    ///   The content of the line in the generated output after which the file
    ///   contents should be inserted. Matching is performed on trimmed,
    ///   case-insensitive content.
    /// </param>
    /// <param name="AFilePath">
    ///   The full path to the UTF-8 text file whose contents will be inserted.
    ///   If the file does not exist, the insertion is silently skipped.
    /// </param>
    /// <param name="AOccurrence">
    ///   Which occurrence of the target line to insert after. Defaults to 1
    ///   (the first occurrence).
    /// </param>
    procedure InsertFileAfter(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer = 1);
    /// <summary>
    ///   Registers a text insertion to be applied to the generated output after
    ///   code generation completes. The specified text is inserted immediately
    ///   before the target line in the output.
    /// </summary>
    /// <param name="ATargetLine">
    ///   The content of the line in the generated output before which the text
    ///   should be inserted. Matching is performed on trimmed, case-insensitive
    ///   content.
    /// </param>
    /// <param name="AText">
    ///   The text to insert. May contain multiple lines including line breaks.
    /// </param>
    /// <param name="AOccurrence">
    ///   Which occurrence of the target line to insert before. Defaults to 1
    ///   (the first occurrence).
    /// </param>
    procedure InsertTextBefore(const ATargetLine: string; const AText: string; const AOccurrence: Integer = 1);
    /// <summary>
    ///   Registers a file-content insertion to be applied to the generated
    ///   output after code generation completes. The entire contents of the
    ///   specified file are read and inserted immediately before the target
    ///   line in the output.
    /// </summary>
    /// <param name="ATargetLine">
    ///   The content of the line in the generated output before which the file
    ///   contents should be inserted. Matching is performed on trimmed,
    ///   case-insensitive content.
    /// </param>
    /// <param name="AFilePath">
    ///   The full path to the UTF-8 text file whose contents will be inserted.
    ///   If the file does not exist, the insertion is silently skipped.
    /// </param>
    /// <param name="AOccurrence">
    ///   Which occurrence of the target line to insert before. Defaults to 1
    ///   (the first occurrence).
    /// </param>
    procedure InsertFileBefore(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer = 1);
    /// <summary>
    ///   Registers a text replacement to be applied to the generated output
    ///   after code generation and insertions are processed. Replaces
    ///   occurrences of the old text with the new text in the final output
    ///   string.
    /// </summary>
    /// <param name="AOldText">
    ///   The exact text to search for in the generated output. The search is
    ///   case-sensitive.
    /// </param>
    /// <param name="ANewText">
    ///   The replacement text. Pass an empty string to delete the matched text.
    /// </param>
    /// <param name="AOccurrence">
    ///   Which occurrence to replace. Defaults to 0, which replaces all
    ///   occurrences. Set to a positive integer to replace only that specific
    ///   occurrence.
    /// </param>
    procedure ReplaceText(const AOldText: string; const ANewText: string; const AOccurrence: Integer = 0);
    /// <summary>
    ///   Registers a file to be copied to a destination directory after the
    ///   import unit has been successfully generated. Only files matching the
    ///   current compilation platform are copied. This is typically used to
    ///   deploy the native DLL or shared library alongside the generated unit.
    /// </summary>
    /// <param name="APlatform">
    ///   The target platform for which this copy operation applies. The file
    ///   is only copied when running on the matching platform (tpWin64 on
    ///   Windows, tpLinux64 on Linux).
    /// </param>
    /// <param name="ASourceFile">
    ///   The full path to the source file to copy.
    /// </param>
    /// <param name="ADestDir">
    ///   The destination directory to copy the file into. The directory is
    ///   created automatically if it does not exist.
    /// </param>
    procedure AddPostCopyFile(const APlatform: TTargetPlatform; const ASourceFile: string; const ADestDir: string);
    /// <summary>
    ///   Sets the output directory where the generated Delphi unit file and
    ///   optional preprocessed source file are written. If not set, the output
    ///   is written to the same directory as the input header file.
    /// </summary>
    /// <param name="APath">
    ///   The directory path for output files. Forward and back slashes are
    ///   normalised internally.
    /// </param>
    procedure SetOutputPath(const APath: string);
    /// <summary>
    ///   Sets the C header file to process. This is the primary input file
    ///   that will be preprocessed and parsed to extract declarations for the
    ///   generated Delphi import unit.
    /// </summary>
    /// <param name="AFilename">
    ///   The path to the C header file (.h) to process. Forward and back
    ///   slashes are normalised internally.
    /// </param>
    procedure SetHeader(const AFilename: string);
    /// <summary>
    ///   Executes the complete C-to-Delphi import generation pipeline:
    ///   preprocesses the header file using zig cc, parses the preprocessed
    ///   output to extract all declarations, generates a Delphi unit with
    ///   mapped types, constants, and external function bindings, applies any
    ///   registered insertions and replacements, writes the output file, and
    ///   performs any registered post-copy file operations.
    /// </summary>
    /// <returns>
    ///   True if the entire pipeline completed successfully and the output
    ///   file was written. False if any stage failed, in which case
    ///   GetLastError returns a description of the failure.
    /// </returns>
    function Process(): Boolean;
    /// <summary>
    ///   Sets the module name used to identify the library being imported.
    ///   The module name is used as a fallback for the DLL name and as the
    ///   base name for the preprocessed output file. If not set, the module
    ///   name defaults to the header filename without its extension.
    /// </summary>
    /// <param name="AName">
    ///   The module name to use, such as 'raylib' or 'SDL3'.
    /// </param>
    procedure SetModuleName(const AName: string);
    /// <summary>
    ///   Sets the Delphi unit name for the generated output file. The unit
    ///   name determines both the unit identifier in the generated source and
    ///   the output filename (UnitName.pas). If not set, the unit name
    ///   defaults to 'U' + ModuleName + 'Import'.
    /// </summary>
    /// <param name="AName">
    ///   The Delphi unit name to use, such as 'URaylibImport'.
    /// </param>
    procedure SetUnitName(const AName: string);
    /// <summary>
    ///   Sets the default DLL or shared library name used in the generated
    ///   external function declarations. This name is used as the fallback
    ///   for any platform that does not have a platform-specific override
    ///   set via the overloaded SetDllName.
    /// </summary>
    /// <param name="ADllName">
    ///   The base library name, such as 'raylib'. Platform-appropriate
    ///   extensions (.dll, .so) and prefixes (lib) are added automatically
    ///   during generation.
    /// </param>
    procedure SetDllName(const ADllName: string); overload;
    /// <summary>
    ///   Sets a platform-specific DLL or shared library name override. When
    ///   generating the CLibName constant, this name is used for the specified
    ///   platform instead of the default DLL name set via the parameterless
    ///   SetDllName overload.
    /// </summary>
    /// <param name="APlatform">
    ///   The target platform for which this library name applies.
    /// </param>
    /// <param name="ADllName">
    ///   The library name for the specified platform. Platform-appropriate
    ///   extensions (.dll, .so) and prefixes (lib) are added automatically
    ///   during generation.
    /// </param>
    procedure SetDllName(const APlatform: TTargetPlatform; const ADllName: string); overload;
    /// <summary>
    ///   Loads all import configuration settings from a TOML file. The
    ///   configuration file specifies the header file, module name, DLL name,
    ///   include paths with optional module associations, source paths,
    ///   excluded types and functions, insertions, replacements, post-copy
    ///   files, and all other options that would otherwise be set through
    ///   individual method calls.
    /// </summary>
    /// <param name="AFilename">
    ///   The path to the TOML configuration file to load.
    /// </param>
    /// <returns>
    ///   True if the configuration file was loaded and parsed successfully.
    ///   False if the file could not be read or a required key is missing,
    ///   in which case GetLastError returns a description of the failure.
    /// </returns>
    function LoadFromConfig(const AFilename: string): Boolean;
    /// <summary>
    ///   Saves the current import configuration to a TOML file. All settings
    ///   including the header path, module name, DLL names, include paths
    ///   with module associations, source paths, excluded types and functions,
    ///   insertions, replacements, and post-copy file operations are written
    ///   to the file.
    /// </summary>
    /// <param name="AFilename">
    ///   The path to the TOML configuration file to write. The file is
    ///   created if it does not exist, or overwritten if it does.
    /// </param>
    /// <returns>
    ///   True if the configuration was saved successfully. False if the file
    ///   could not be written, in which case GetLastError returns a description
    ///   of the failure.
    /// </returns>
    function SaveToConfig(const AFilename: string): Boolean;
    /// <summary>
    ///   Returns the error message from the most recent operation that failed.
    ///   The error string is set by Process, LoadFromConfig, SaveToConfig, and
    ///   the preprocessing stage. The value is empty when no error has occurred.
    /// </summary>
    /// <returns>
    ///   The error description string from the last failed operation, or an
    ///   empty string if no error has occurred.
    /// </returns>
    function GetLastError(): string;
    /// <summary>
    ///   Resets the TDelphCImp instance to its initial state, clearing all
    ///   configuration settings, parsed declarations, output buffers, and
    ///   error state. After calling Clear, the instance can be reconfigured
    ///   and used to process a different header file without creating a new
    ///   instance.
    /// </summary>
    procedure Clear();
  end;


implementation


{ TDelphCImp }

constructor TDelphCImp.Create();
begin
  inherited;
  FLexer := TCLexer.Create();
  FOutput := TStringBuilder.Create();
  FStructs := TList<TCStructInfo>.Create();
  FEnums := TList<TCEnumInfo>.Create();
  FTypedefs := TList<TCTypedefInfo>.Create();
  FDefines := TList<TCDefineInfo>.Create();
  FFunctions := TList<TCFunctionInfo>.Create();
  FForwardDecls := TList<string>.Create();
  FInsertions := TList<TInsertionInfo>.Create();
  FReplacements := TList<TReplacementInfo>.Create();
  FPostCopyFiles := TList<TPostCopyInfo>.Create();
  FIncludePaths := TList<string>.Create();
  FIncludeModules := TDictionary<string, string>.Create();
  FExternalTypes := TDictionary<string, string>.Create();
  FSourcePaths := TList<string>.Create();
  FExcludedTypes := TList<string>.Create();
  FExcludedFunctions := TList<string>.Create();
  FSavePreprocessed := False;
  FDelayLoad := False;
  FModuleName := '';
  FUnitName := '';
  FDllName := '';
  FDelayLoad := False;
  FOutputPath := '';
  FHeader := '';
  FLastError := '';
  FCurrentSourceFile := '';
  FIndent := 0;
  FPos := 0;

  FPlatformDllNames := TDictionary<TTargetPlatform, string>.Create();
end;

destructor TDelphCImp.Destroy();
begin
  FExcludedFunctions.Free();
  FExcludedTypes.Free();
  FIncludePaths.Free();
  FIncludeModules.Free();
  FExternalTypes.Free();
  FSourcePaths.Free();
  FPostCopyFiles.Free();
  FReplacements.Free();
  FInsertions.Free();
  FForwardDecls.Free();
  FFunctions.Free();
  FDefines.Free();
  FTypedefs.Free();
  FEnums.Free();
  FStructs.Free();
  FOutput.Free();
  FLexer.Free();
  FPlatformDllNames.Free();
  inherited;
end;

function TDelphCImp.GetZigExePath(): string;
var
  LBase: string;
begin
  LBase := TPath.GetDirectoryName(ParamStr(0));
  Result := TPath.Combine(LBase, 'res\zig\zig.exe');
end;

function TDelphCImp.PreprocessHeader(const AHeaderFile: string; out APreprocessedSource: string): Boolean;
var
  LZigPath: string;
  LOutputFile: string;
  LOutputDir: string;
  LArgs: string;
  LPath: string;
  LExitCode: Cardinal;
  LWorkDir: string;
  LHeaderFile: string;
  LIncludePath: string;
  LCmdLine: string;
begin
  Result := False;
  APreprocessedSource := '';

  LZigPath := GetZigExePath();
  if not TFile.Exists(LZigPath) then
  begin
    FLastError := 'zig.exe not found at ' + LZigPath;
    Exit;
  end;

  LHeaderFile := TPath.GetFullPath(AHeaderFile);
  LWorkDir := TPath.GetDirectoryName(LHeaderFile);

  if FOutputPath <> '' then
    LOutputDir := TPath.GetFullPath(FOutputPath)
  else
    LOutputDir := LWorkDir;
  LOutputFile := TPath.Combine(LOutputDir, FModuleName + '_pp.c');

  // Build args: cc -E -dD -I<path> ... <header> -o <output>
  LArgs := 'cc -E -dD';
  for LPath in FIncludePaths do
  begin
    LIncludePath := TPath.GetFullPath(LPath).Replace('\', '/');
    LArgs := LArgs + ' -I"' + LIncludePath + '"';
  end;
  LArgs := LArgs + ' "' + LHeaderFile.Replace('\', '/') + '"';

  // zig cc -E outputs to stdout, use cmd.exe to redirect
  LCmdLine := Format('/c ""%s" %s > "%s""', [LZigPath, LArgs, LOutputFile]);

  LExitCode := TUtils.RunPE(GetEnvironmentVariable('COMSPEC'), LCmdLine, LWorkDir, True, SW_HIDE);

  if LExitCode <> 0 then
  begin
    FLastError := Format('Preprocessing failed with exit code %d', [LExitCode]);
    if TFile.Exists(LOutputFile) then
      TFile.Delete(LOutputFile);
    Exit;
  end;

  if TFile.Exists(LOutputFile) then
  begin
    APreprocessedSource := TFile.ReadAllText(LOutputFile);
    if not FSavePreprocessed then
      TFile.Delete(LOutputFile);
    Result := True;
  end
  else
    FLastError := 'Preprocessor output file not created';
end;

function TDelphCImp.IsAtEnd(): Boolean;
begin
  Result := FCurrentToken.Kind = ctkEOF;
end;

function TDelphCImp.Peek(): TCToken;
begin
  Result := FCurrentToken;
end;

function TDelphCImp.PeekNext(): TCToken;
begin
  Result := FLexer.GetToken(FPos + 1);
end;

procedure TDelphCImp.Advance();
begin
  Inc(FPos);
  FCurrentToken := FLexer.GetToken(FPos);
end;

function TDelphCImp.Check(const AKind: TCTokenKind): Boolean;
begin
  Result := FCurrentToken.Kind = AKind;
end;

function TDelphCImp.Match(const AKind: TCTokenKind): Boolean;
begin
  if Check(AKind) then
  begin
    Advance();
    Result := True;
  end
  else
    Result := False;
end;

function TDelphCImp.FunctionReferencesExcludedType(const AFunc: TCFunctionInfo): Boolean;
var
  LI: Integer;
  LTypedef: TCTypedefInfo;
begin
  // Check return type directly
  if FExcludedTypes.Contains(AFunc.ReturnType) then
    Exit(True);

  // Check if return type is a typedef that references excluded types
  for LTypedef in FTypedefs do
  begin
    if LTypedef.AliasName = AFunc.ReturnType then
    begin
      if TypedefReferencesExcludedType(LTypedef) then
        Exit(True);
      Break;
    end;
  end;

  // Check all parameter types
  for LI := 0 to High(AFunc.Params) do
  begin
    if FExcludedTypes.Contains(AFunc.Params[LI].TypeName) then
      Exit(True);

    // Also check if parameter type is a typedef that references excluded types
    for LTypedef in FTypedefs do
    begin
      if LTypedef.AliasName = AFunc.Params[LI].TypeName then
      begin
        if TypedefReferencesExcludedType(LTypedef) then
          Exit(True);
        Break;
      end;
    end;
  end;

  Result := False;
end;

function TDelphCImp.MatchAny(const AKinds: array of TCTokenKind): Boolean;
var
  LKind: TCTokenKind;
begin
  for LKind in AKinds do
  begin
    if Check(LKind) then
    begin
      Advance();
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TDelphCImp.SkipToSemicolon();
begin
  while not IsAtEnd() and not Check(ctkSemicolon) do
    Advance();
  if Check(ctkSemicolon) then
    Advance();
end;

procedure TDelphCImp.SkipToRBrace();
var
  LDepth: Integer;
begin
  LDepth := 1;
  while not IsAtEnd() and (LDepth > 0) do
  begin
    if Check(ctkLBrace) then
      Inc(LDepth)
    else if Check(ctkRBrace) then
      Dec(LDepth);
    Advance();
  end;
end;

function TDelphCImp.IsTypeKeyword(): Boolean;
begin
  Result := FCurrentToken.Kind in [
    ctkVoid, ctkChar, ctkShort, ctkInt, ctkLong,
    ctkFloat, ctkDouble, ctkSigned, ctkUnsigned, ctkBool,
    ctkStruct, ctkUnion, ctkEnum, ctkConst
  ];
end;

function TDelphCImp.ParseBaseType(): string;
var
  LHasUnsigned: Boolean;
  LHasSigned: Boolean;
  LHasLong: Boolean;
  LLongCount: Integer;
  LHasShort: Boolean;
  LDepth: Integer;
begin
  Result := '';
  LHasUnsigned := False;
  LHasSigned := False;
  LHasLong := False;
  LLongCount := 0;
  LHasShort := False;

  while True do
  begin
    case FCurrentToken.Kind of
      ctkConst, ctkVolatile, ctkRestrict, ctkAtomic, ctkInline, ctkStatic:
        Advance();
      ctkUnsigned:
        begin
          LHasUnsigned := True;
          Advance();
        end;
      ctkSigned:
        begin
          LHasSigned := True;
          Advance();
        end;
      ctkLong:
        begin
          LHasLong := True;
          Inc(LLongCount);
          Advance();
        end;
      ctkShort:
        begin
          LHasShort := True;
          Advance();
        end;
      ctkVoid:
        begin
          Result := 'void';
          Advance();
          Exit;
        end;
      ctkChar:
        begin
          if LHasUnsigned then
            Result := 'unsigned char'
          else if LHasSigned then
            Result := 'signed char'
          else
            Result := 'char';
          Advance();
          Exit;
        end;
      ctkInt:
        begin
          if LHasShort then
          begin
            if LHasUnsigned then Result := 'unsigned short' else Result := 'short';
          end
          else if LHasLong then
          begin
            if LLongCount >= 2 then
            begin
              if LHasUnsigned then Result := 'unsigned long long' else Result := 'long long';
            end
            else
            begin
              if LHasUnsigned then Result := 'unsigned long' else Result := 'long';
            end;
          end
          else
          begin
            if LHasUnsigned then Result := 'unsigned int' else Result := 'int';
          end;
          Advance();
          Exit;
        end;
      ctkFloat:
        begin
          Result := 'float';
          Advance();
          Exit;
        end;
      ctkDouble:
        begin
          if LHasLong then Result := 'long double' else Result := 'double';
          Advance();
          Exit;
        end;
      ctkBool:
        begin
          Result := '_Bool';
          Advance();
          Exit;
        end;
      ctkStruct, ctkUnion:
        begin
          if FCurrentToken.Kind = ctkStruct then Result := 'struct ' else Result := 'union ';
          Advance();
          if Check(ctkIdentifier) then
          begin
            Result := Result + FCurrentToken.Lexeme;
            Advance();
          end;
          if Check(ctkLBrace) then
          begin
            Advance();
            SkipToRBrace();
          end;
          Exit;
        end;
      ctkEnum:
        begin
          Result := 'enum ';
          Advance();
          if Check(ctkIdentifier) then
          begin
            Result := Result + FCurrentToken.Lexeme;
            Advance();
          end;
          if Check(ctkLBrace) then
          begin
            Advance();
            SkipToRBrace();
          end;
          Exit;
        end;
      ctkIdentifier:
        begin
          // If we've seen type modifiers (long, short, unsigned, signed),
          // this identifier is NOT a type name - it's the variable/param name
          if LHasUnsigned or LHasSigned or LHasLong or LHasShort then
            Break;  // Let final logic construct type from modifiers
          Result := FCurrentToken.Lexeme;
          Advance();
          Exit;
        end;
      ctkBuiltin:
        begin
          Result := FCurrentToken.Lexeme;
          Advance();
          if Check(ctkLParen) then
          begin
            LDepth := 1;
            Advance();
            while not IsAtEnd() and (LDepth > 0) do
            begin
              if Check(ctkLParen) then Inc(LDepth)
              else if Check(ctkRParen) then Dec(LDepth);
              Advance();
            end;
          end;
          Exit;
        end;
    else
      Break;
    end;
  end;

  if (Result = '') and (LHasUnsigned or LHasSigned or LHasLong or LHasShort) then
  begin
    if LHasShort then
    begin
      if LHasUnsigned then Result := 'unsigned short' else Result := 'short';
    end
    else if LHasLong then
    begin
      if LLongCount >= 2 then
      begin
        if LHasUnsigned then Result := 'unsigned long long' else Result := 'long long';
      end
      else
      begin
        if LHasUnsigned then Result := 'unsigned long' else Result := 'long';
      end;
    end
    else
    begin
      if LHasUnsigned then Result := 'unsigned int' else Result := 'int';
    end;
  end;
end;

function TDelphCImp.ParsePointerDepth(): Integer;
begin
  Result := 0;
  while Check(ctkStar) do
  begin
    Inc(Result);
    Advance();
    while MatchAny([ctkConst, ctkVolatile, ctkRestrict]) do
      ;
  end;
end;

procedure TDelphCImp.ParseTopLevel();
var
  LBaseType: string;
  LPtrDepth: Integer;
  LName: string;
begin
  while not IsAtEnd() do
  begin
    // Handle line markers to track current source file
    if Check(ctkLineMarker) then
    begin
      if FCurrentToken.Lexeme <> '' then
        FCurrentSourceFile := FCurrentToken.Lexeme;
      Advance();
      Continue;
    end;

    while MatchAny([ctkExtern, ctkStatic, ctkInline]) do
      ;

    if Check(ctkTypedef) then
      ParseTypedef()
    else if IsTypeKeyword() or Check(ctkIdentifier) then
    begin
      LBaseType := ParseBaseType();
      LPtrDepth := ParsePointerDepth();

      if Check(ctkIdentifier) then
      begin
        LName := FCurrentToken.Lexeme;
        Advance();

        if Check(ctkLParen) then
          ParseFunction(LBaseType, LPtrDepth, LName)
        else
          SkipToSemicolon();
      end
      else
        SkipToSemicolon();
    end
    else if Check(ctkSemicolon) then
      Advance()
    else
      Advance();
  end;
end;

procedure TDelphCImp.ParseTypedef();
var
  LInfo: TCTypedefInfo;
  LStructInfo: TCStructInfo;
  LEnumInfo: TCEnumInfo;
  LBaseType: string;
  LPtrDepth: Integer;
  LIsUnion: Boolean;
  LTagName: string;
  LAliasName: string;
  LModule: string;
  LParam: TCParamInfo;
begin
  Advance();

  if Check(ctkStruct) or Check(ctkUnion) then
  begin
    LIsUnion := Check(ctkUnion);
    Advance();

    LTagName := '';
    if Check(ctkIdentifier) then
    begin
      LTagName := FCurrentToken.Lexeme;
      Advance();
    end;

    if Check(ctkLBrace) then
    begin
      ParseStruct(LIsUnion, LStructInfo);

      if Check(ctkIdentifier) then
      begin
        LStructInfo.StructName := FCurrentToken.Lexeme;
        Advance();
      end
      else if LTagName <> '' then
        LStructInfo.StructName := LTagName;

      if LStructInfo.StructName <> '' then
      begin
        if IsAllowedSourceFile() then
          FStructs.Add(LStructInfo)
        else
        begin
          // Record as external type if from a module-associated include path
          LModule := GetModuleForCurrentFile();
          if LModule <> '' then
            FExternalTypes.AddOrSetValue(LStructInfo.StructName, LModule);
        end;
      end;
    end
    else
    begin
      // Handle pointer typedefs like: typedef struct X *Y;
      LPtrDepth := ParsePointerDepth();
      if Check(ctkIdentifier) then
      begin
        LAliasName := FCurrentToken.Lexeme;
        Advance();

        if (LTagName <> '') and (LTagName = LAliasName) and (LPtrDepth = 0) then
        begin
          if IsAllowedSourceFile() and not FForwardDecls.Contains(LAliasName) then
            FForwardDecls.Add(LAliasName)
          else
          begin
            LModule := GetModuleForCurrentFile();
            if LModule <> '' then
              FExternalTypes.AddOrSetValue(LAliasName, LModule);
          end;
        end
        else if LTagName <> '' then
        begin
          // Add tag name as forward decl if it's an opaque struct (no body defined)
          if IsAllowedSourceFile() and not FForwardDecls.Contains(LTagName) then
            FForwardDecls.Add(LTagName)
          else
          begin
            LModule := GetModuleForCurrentFile();
            if LModule <> '' then
              FExternalTypes.AddOrSetValue(LTagName, LModule);
          end;

          LInfo.AliasName := LAliasName;
          LInfo.TargetType := LTagName;
          LInfo.IsPointer := LPtrDepth > 0;
          LInfo.PointerDepth := LPtrDepth;
          LInfo.IsFunctionPointer := False;
          if IsAllowedSourceFile() then
            FTypedefs.Add(LInfo)
          else
          begin
            LModule := GetModuleForCurrentFile();
            if LModule <> '' then
              FExternalTypes.AddOrSetValue(LAliasName, LModule);
          end;
        end;
      end;
    end;
  end
  else if Check(ctkEnum) then
  begin
    Advance();
    LTagName := '';
    if Check(ctkIdentifier) then
    begin
      LTagName := FCurrentToken.Lexeme;
      Advance();
    end;

    if Check(ctkLBrace) then
    begin
      ParseEnum(LEnumInfo);

      if Check(ctkIdentifier) then
      begin
        LEnumInfo.EnumName := FCurrentToken.Lexeme;
        Advance();
      end
      else if LTagName <> '' then
        LEnumInfo.EnumName := LTagName;

      if LEnumInfo.EnumName <> '' then
      begin
        if IsAllowedSourceFile() then
          FEnums.Add(LEnumInfo)
        else
        begin
          LModule := GetModuleForCurrentFile();
          if LModule <> '' then
            FExternalTypes.AddOrSetValue(LEnumInfo.EnumName, LModule);
        end;
      end;
    end;
  end
  else
  begin
    LBaseType := ParseBaseType();
    LPtrDepth := ParsePointerDepth();

    if Check(ctkLParen) then
    begin
      Advance();
      if Check(ctkStar) then
      begin
        Advance();
        if Check(ctkIdentifier) then
        begin
          LInfo.AliasName := FCurrentToken.Lexeme;
          LInfo.IsFunctionPointer := True;
          LInfo.TargetType := LBaseType;
          LInfo.IsPointer := LPtrDepth > 0;
          LInfo.PointerDepth := LPtrDepth;
          Advance();

          if Check(ctkRParen) then
            Advance();

          // Parse function pointer parameters into FuncInfo
          LInfo.FuncInfo.FuncName := LInfo.AliasName;
          LInfo.FuncInfo.ReturnType := LBaseType;
          LInfo.FuncInfo.ReturnIsPointer := LPtrDepth > 0;
          LInfo.FuncInfo.ReturnPointerDepth := LPtrDepth;
          LInfo.FuncInfo.IsVariadic := False;
          SetLength(LInfo.FuncInfo.Params, 0);

          if Check(ctkLParen) then
          begin
            Advance();

            while not IsAtEnd() and not Check(ctkRParen) do
            begin
              // Check for void parameter list
              if Check(ctkVoid) and (PeekNext().Kind = ctkRParen) then
              begin
                Advance();
                Break;
              end;

              // Check for variadic
              if Check(ctkEllipsis) then
              begin
                LInfo.FuncInfo.IsVariadic := True;
                Advance();
                Break;
              end;

              LParam.IsConst := False;
              LParam.IsConstTarget := False;
              if Check(ctkConst) then
              begin
                LParam.IsConst := True;
                Advance();
              end;

              LParam.TypeName := ParseBaseType();
              LParam.PointerDepth := ParsePointerDepth();
              LParam.IsPointer := LParam.PointerDepth > 0;

              // If const was before type and we have a pointer, it's pointer to const
              if LParam.IsConst and LParam.IsPointer then
                LParam.IsConstTarget := True;

              if Check(ctkConst) then
              begin
                LParam.IsConst := True;
                Advance();
              end;

              if Check(ctkIdentifier) then
              begin
                LParam.ParamName := FCurrentToken.Lexeme;
                Advance();
              end
              else
                LParam.ParamName := '';

              // Handle array parameters as pointers
              if Check(ctkLBracket) then
              begin
                LParam.IsPointer := True;
                Inc(LParam.PointerDepth);
                while not IsAtEnd() and not Check(ctkRBracket) do
                  Advance();
                Match(ctkRBracket);
              end;

              SetLength(LInfo.FuncInfo.Params, Length(LInfo.FuncInfo.Params) + 1);
              LInfo.FuncInfo.Params[High(LInfo.FuncInfo.Params)] := LParam;

              if not Match(ctkComma) then
                Break;
            end;

            Match(ctkRParen);
          end;

          if IsAllowedSourceFile() then
            FTypedefs.Add(LInfo)
          else
          begin
            LModule := GetModuleForCurrentFile();
            if LModule <> '' then
              FExternalTypes.AddOrSetValue(LInfo.AliasName, LModule);
          end;
        end;
      end
      else
      begin
        SkipToSemicolon();
        Exit;
      end;
    end
    else if Check(ctkIdentifier) then
    begin
      LInfo.AliasName := FCurrentToken.Lexeme;
      LInfo.TargetType := LBaseType;
      LInfo.IsPointer := LPtrDepth > 0;
      LInfo.PointerDepth := LPtrDepth;
      LInfo.IsFunctionPointer := False;
      Advance();
      if IsAllowedSourceFile() then
        FTypedefs.Add(LInfo)
      else
      begin
        LModule := GetModuleForCurrentFile();
        if LModule <> '' then
          FExternalTypes.AddOrSetValue(LInfo.AliasName, LModule);
      end;
    end;
  end;

  if Check(ctkSemicolon) then
    Advance();
end;

procedure TDelphCImp.ParseStruct(const AIsUnion: Boolean; out AInfo: TCStructInfo);
begin
  AInfo.StructName := '';
  AInfo.IsUnion := AIsUnion;
  SetLength(AInfo.Fields, 0);

  if not Match(ctkLBrace) then
    Exit;

  while not IsAtEnd() and not Check(ctkRBrace) do
    ParseStructField(AInfo, AInfo.Fields);

  Match(ctkRBrace);
end;

procedure TDelphCImp.ParseStructField(const AStruct: TCStructInfo; var AFields: TArray<TCFieldInfo>);
var
  LField: TCFieldInfo;
  LBaseType: string;
begin
  // Skip line markers inside structs/unions
  while Check(ctkLineMarker) do
  begin
    FCurrentSourceFile := FCurrentToken.Lexeme;
    Advance();
  end;

  if Check(ctkStruct) or Check(ctkUnion) then
  begin
    Advance();
    if Check(ctkIdentifier) then
      Advance();
    if Check(ctkLBrace) then
    begin
      Advance();
      SkipToRBrace();
    end;
  end;

  LBaseType := ParseBaseType();
  if LBaseType = '' then
  begin
    SkipToSemicolon();
    Exit;
  end;

  repeat
    LField.TypeName := LBaseType;
    LField.PointerDepth := ParsePointerDepth();
    LField.IsPointer := LField.PointerDepth > 0;
    LField.ArraySize := 0;
    LField.BitWidth := 0;

    if Check(ctkIdentifier) then
    begin
      LField.FieldName := FCurrentToken.Lexeme;
      Advance();

      if Check(ctkLBracket) then
      begin
        Advance();
        if Check(ctkIntLiteral) then
        begin
          LField.ArraySize := FCurrentToken.IntValue;
          Advance();
        end;
        Match(ctkRBracket);
      end;

      if Check(ctkColon) then
      begin
        Advance();
        if Check(ctkIntLiteral) then
        begin
          LField.BitWidth := FCurrentToken.IntValue;
          Advance();
        end;
      end;

      SetLength(AFields, Length(AFields) + 1);
      AFields[High(AFields)] := LField;
    end;
  until not Match(ctkComma);

  Match(ctkSemicolon);
end;

procedure TDelphCImp.ParseEnum(out AInfo: TCEnumInfo);
var
  LValue: TCEnumValue;
  LNextVal: Int64;
begin
  AInfo.EnumName := '';
  SetLength(AInfo.Values, 0);
  LNextVal := 0;

  if not Match(ctkLBrace) then
    Exit;

  while not IsAtEnd() and not Check(ctkRBrace) do
  begin
    if Check(ctkIdentifier) then
    begin
      LValue.ValueName := FCurrentToken.Lexeme;
      LValue.HasExplicitValue := False;
      LValue.Value := LNextVal;
      Advance();

      if Match(ctkEquals) then
      begin
        LValue.HasExplicitValue := True;

        if Check(ctkIntLiteral) then
        begin
          LValue.Value := FCurrentToken.IntValue;
          Advance();
        end
        else
        begin
          // Skip complex expressions (macros, bitwise ops, etc.) until comma or rbrace
          while not IsAtEnd() and not Check(ctkComma) and not Check(ctkRBrace) do
            Advance();
          LValue.HasExplicitValue := False;  // Can't determine value
        end;
      end;

      LNextVal := LValue.Value + 1;
      SetLength(AInfo.Values, Length(AInfo.Values) + 1);
      AInfo.Values[High(AInfo.Values)] := LValue;
    end;

    if not Match(ctkComma) then
      Break;
  end;

  Match(ctkRBrace);
end;

procedure TDelphCImp.ParseFunction(const AReturnType: string; const AReturnPtrDepth: Integer; const AFuncName: string);
var
  LFunc: TCFunctionInfo;
  LParam: TCParamInfo;
  LExisting: TCFunctionInfo;
  LI: Integer;
begin
  // Skip if we've already seen this function name
  for LExisting in FFunctions do
  begin
    if LExisting.FuncName = AFuncName then
    begin
      // Skip to end of this declaration/definition
      while not IsAtEnd() and not Check(ctkSemicolon) do
      begin
        if Check(ctkLBrace) then
        begin
          Advance();
          SkipToRBrace();
          Exit;
        end;
        Advance();
      end;
      Match(ctkSemicolon);
      Exit;
    end;
  end;

  LFunc.FuncName := AFuncName;
  LFunc.ReturnType := AReturnType;
  LFunc.ReturnIsPointer := AReturnPtrDepth > 0;
  LFunc.ReturnPointerDepth := AReturnPtrDepth;
  LFunc.IsVariadic := False;
  SetLength(LFunc.Params, 0);

  if not Match(ctkLParen) then
  begin
    SkipToSemicolon();
    Exit;
  end;

  while not IsAtEnd() and not Check(ctkRParen) do
  begin
    if Check(ctkVoid) and (PeekNext().Kind = ctkRParen) then
    begin
      Advance();
      Break;
    end;

    if Check(ctkEllipsis) then
    begin
      LFunc.IsVariadic := True;
      Advance();
      Break;
    end;

    LParam.IsConst := False;
    LParam.IsConstTarget := False;
    if Check(ctkConst) then
    begin
      LParam.IsConst := True;
      Advance();
    end;

    LParam.TypeName := ParseBaseType();
    LParam.PointerDepth := ParsePointerDepth();
    LParam.IsPointer := LParam.PointerDepth > 0;

    // If const was before type and we have a pointer, it's pointer to const
    if LParam.IsConst and LParam.IsPointer then
      LParam.IsConstTarget := True;

    if Check(ctkConst) then
    begin
      LParam.IsConst := True;
      Advance();
    end;

    if Check(ctkIdentifier) then
    begin
      LParam.ParamName := FCurrentToken.Lexeme;
      Advance();
    end
    else
      LParam.ParamName := '';

    if Check(ctkLBracket) then
    begin
      LParam.IsPointer := True;
      Inc(LParam.PointerDepth);
      while not IsAtEnd() and not Check(ctkRBracket) do
        Advance();
      Match(ctkRBracket);
    end;

    SetLength(LFunc.Params, Length(LFunc.Params) + 1);
    LFunc.Params[High(LFunc.Params)] := LParam;

    if not Match(ctkComma) then
      Break;
  end;

  Match(ctkRParen);
  Match(ctkSemicolon);

  if IsAllowedSourceFile() then
  begin
    // Don't add malformed functions (parsing errors from macros/inline defs)
    for LI := 0 to High(LFunc.Params) do
    begin
      if LFunc.Params[LI].TypeName = '' then
        Exit;
      if (Length(LFunc.Params[LI].TypeName) = 1) and CharInSet(LFunc.Params[LI].TypeName[1], ['a'..'z', 'A'..'Z']) then
        Exit;
    end;
    // Final duplicate check
    for LExisting in FFunctions do
    begin
      if LExisting.FuncName = LFunc.FuncName then
        Exit;
    end;
    FFunctions.Add(LFunc);
  end;
end;

procedure TDelphCImp.EmitLn(const AText: string);
begin
  FOutput.AppendLine(StringOfChar(' ', FIndent * 2) + AText);
end;

procedure TDelphCImp.EmitFmt(const AFormat: string; const AArgs: array of const);
begin
  EmitLn(Format(AFormat, AArgs));
end;

function TDelphCImp.MapCTypeToDelphi(const ACType: string; const AIsPointer: Boolean; const APtrDepth: Integer; const AIsConstTarget: Boolean): string;
var
  LBaseType: string;
  LDelphiType: string;
begin
  LBaseType := ACType;

  // Strip struct/union/enum prefixes
  if LBaseType.StartsWith('struct ') then
    LBaseType := Copy(LBaseType, 8, Length(LBaseType))
  else if LBaseType.StartsWith('union ') then
    LBaseType := Copy(LBaseType, 7, Length(LBaseType))
  else if LBaseType.StartsWith('enum ') then
    LBaseType := Copy(LBaseType, 6, Length(LBaseType));

  // Map C types to Delphi types
  LDelphiType := '';

  if LBaseType = 'void' then LDelphiType := ''
  else if LBaseType = '_Bool' then LDelphiType := 'Boolean'
  else if LBaseType = 'char' then LDelphiType := 'AnsiChar'
  else if LBaseType = 'signed char' then LDelphiType := 'Int8'
  else if LBaseType = 'unsigned char' then LDelphiType := 'Byte'
  else if LBaseType = 'wchar_t' then LDelphiType := 'WideChar'
  else if LBaseType = 'short' then LDelphiType := 'Int16'
  else if LBaseType = 'unsigned short' then LDelphiType := 'UInt16'
  else if LBaseType = 'int' then LDelphiType := 'Int32'
  else if LBaseType = 'unsigned int' then LDelphiType := 'UInt32'
  else if LBaseType = 'long' then LDelphiType := 'Int32'
  else if LBaseType = 'unsigned long' then LDelphiType := 'UInt32'
  else if LBaseType = 'long long' then LDelphiType := 'Int64'
  else if LBaseType = 'unsigned long long' then LDelphiType := 'UInt64'
  else if LBaseType = 'float' then LDelphiType := 'Single'
  else if LBaseType = 'double' then LDelphiType := 'Double'
  else if LBaseType = 'long double' then LDelphiType := 'Double'

  // C99 stdint.h exact-width types
  else if LBaseType = 'int8_t' then LDelphiType := 'Int8'
  else if LBaseType = 'int16_t' then LDelphiType := 'Int16'
  else if LBaseType = 'int32_t' then LDelphiType := 'Int32'
  else if LBaseType = 'int64_t' then LDelphiType := 'Int64'
  else if LBaseType = 'uint8_t' then LDelphiType := 'UInt8'
  else if LBaseType = 'uint16_t' then LDelphiType := 'UInt16'
  else if LBaseType = 'uint32_t' then LDelphiType := 'UInt32'
  else if LBaseType = 'uint64_t' then LDelphiType := 'UInt64'

  // C99 stdint.h pointer/size types
  else if LBaseType = 'size_t' then LDelphiType := 'NativeUInt'
  else if LBaseType = 'ssize_t' then LDelphiType := 'NativeInt'
  else if LBaseType = 'ptrdiff_t' then LDelphiType := 'NativeInt'
  else if LBaseType = 'intptr_t' then LDelphiType := 'NativeInt'
  else if LBaseType = 'uintptr_t' then LDelphiType := 'NativeUInt'
  else if LBaseType = 'intmax_t' then LDelphiType := 'Int64'
  else if LBaseType = 'uintmax_t' then LDelphiType := 'UInt64'

  // SDL-specific integer types
  else if LBaseType = 'Sint8' then LDelphiType := 'Int8'
  else if LBaseType = 'Sint16' then LDelphiType := 'Int16'
  else if LBaseType = 'Sint32' then LDelphiType := 'Int32'
  else if LBaseType = 'Sint64' then LDelphiType := 'Int64'
  else if LBaseType = 'Uint8' then LDelphiType := 'UInt8'
  else if LBaseType = 'Uint16' then LDelphiType := 'UInt16'
  else if LBaseType = 'Uint32' then LDelphiType := 'UInt32'
  else if LBaseType = 'Uint64' then LDelphiType := 'UInt64'

  // Variadic argument types
  else if LBaseType = 'va_list' then LDelphiType := 'Pointer'
  else if LBaseType = '__va_list_tag' then LDelphiType := 'Pointer';

  // Handle pointer types
  if AIsPointer or (APtrDepth > 0) then
  begin
    // Special pointer mappings
    if (APtrDepth = 1) then
    begin
      if (LBaseType = 'void') then
        Exit('Pointer')
      else if (LBaseType = 'char') or ((LBaseType = 'char') and AIsConstTarget) then
        Exit('PAnsiChar')
      else if (LBaseType = 'wchar_t') then
        Exit('PWideChar')
      else if (LBaseType = 'unsigned char') then
        Exit('PByte');
    end;

    // Multi-level pointers default to Pointer
    if APtrDepth >= 2 then
      Exit('Pointer');

    // Single pointer to known type
    if LDelphiType <> '' then
      // Pointer to builtin (Int32, Single, etc.) - no P-prefixed type exists
      Result := 'Pointer'
    else
      // Pointer to user type (struct/enum) - use P prefix on raw name
      Result := 'P' + SanitizeIdentifier(LBaseType);
    Exit;
  end;

  // Non-pointer
  if LDelphiType <> '' then
    Result := LDelphiType
  else
    Result := DelphifyTypeName(LBaseType);
end;

function TDelphCImp.ResolveTypedefAlias(const ATypeName: string): string;
var
  LTypedef: TCTypedefInfo;
begin
  // Check if this type is a typedef alias and return the target type
  for LTypedef in FTypedefs do
  begin
    if (not LTypedef.IsFunctionPointer) and (LTypedef.AliasName = ATypeName) then
      Exit(LTypedef.TargetType);
  end;
  // Not a typedef alias, return as-is
  Result := ATypeName;
end;

function TDelphCImp.SanitizeIdentifier(const AName: string): string;
const
  CDelphiKeywords: array[0..50] of string = (
    'and', 'array', 'as', 'asm', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports', 'file', 'finalization', 'finally',
    'for', 'function', 'goto', 'if', 'implementation', 'in', 'inherited',
    'initialization', 'inline', 'interface', 'is', 'label', 'library',
    'mod', 'nil', 'not', 'object', 'of', 'on', 'or', 'out', 'packed',
    'procedure', 'program', 'property', 'raise', 'record', 'repeat',
    'resourcestring', 'set'
  );
  CDelphiKeywords2: array[0..8] of string = (
    'shl', 'shr', 'string', 'then', 'threadvar', 'to', 'try', 'type',
    'unit'
  );
  CDelphiKeywords3: array[0..4] of string = (
    'until', 'uses', 'var', 'while', 'with'
  );
var
  LLower: string;
  LKeyword: string;
begin
  Result := AName;
  LLower := LowerCase(AName);
  for LKeyword in CDelphiKeywords do
  begin
    if LLower = LKeyword then
    begin
      Result := AName + '_';
      Exit;
    end;
  end;
  for LKeyword in CDelphiKeywords2 do
  begin
    if LLower = LKeyword then
    begin
      Result := AName + '_';
      Exit;
    end;
  end;
  for LKeyword in CDelphiKeywords3 do
  begin
    if LLower = LKeyword then
    begin
      Result := AName + '_';
      Exit;
    end;
  end;
end;

function TDelphCImp.IsAllowedSourceFile(): Boolean;
var
  LPath: string;
  LNormalizedCurrent: string;
  LNormalizedAllowed: string;
  LFilterPaths: TList<string>;
begin
  // Use source paths if specified, otherwise fall back to include paths
  if FSourcePaths.Count > 0 then
    LFilterPaths := FSourcePaths
  else
    LFilterPaths := FIncludePaths;

  // If no filter paths specified, allow all
  if LFilterPaths.Count = 0 then
    Exit(True);

  // If no current source file tracked, allow (safety)
  if FCurrentSourceFile = '' then
    Exit(True);

  // Normalize current file path (forward slashes, lowercase)
  LNormalizedCurrent := LowerCase(FCurrentSourceFile.Replace('\', '/'));

  // Check if current file is under any allowed path
  for LPath in LFilterPaths do
  begin
    LNormalizedAllowed := LowerCase(LPath.Replace('\', '/'));
    // Ensure path ends with /
    if not LNormalizedAllowed.EndsWith('/') then
      LNormalizedAllowed := LNormalizedAllowed + '/';

    if LNormalizedCurrent.Contains(LNormalizedAllowed) then
      Exit(True);
  end;

  // File is from other headers, skip it
  Result := False;
end;

function TDelphCImp.GetModuleForCurrentFile(): string;
var
  LPath: string;
  LNormalizedCurrent: string;
  LNormalizedPath: string;
begin
  Result := '';

  if FCurrentSourceFile = '' then
    Exit;

  LNormalizedCurrent := LowerCase(FCurrentSourceFile.Replace('\', '/'));

  for LPath in FIncludeModules.Keys do
  begin
    LNormalizedPath := LowerCase(LPath.Replace('\', '/'));
    if not LNormalizedPath.EndsWith('/') then
      LNormalizedPath := LNormalizedPath + '/';

    if LNormalizedCurrent.Contains(LNormalizedPath) then
      Exit(FIncludeModules[LPath]);
  end;
end;

function TDelphCImp.TypedefReferencesExcludedType(const ATypedef: TCTypedefInfo): Boolean;
var
  LI: Integer;
begin
  // Check alias name
  if FExcludedTypes.Contains(ATypedef.AliasName) then
    Exit(True);

  // Check target type
  if FExcludedTypes.Contains(ATypedef.TargetType) then
    Exit(True);

  // For function pointers, check return type and all parameter types
  if ATypedef.IsFunctionPointer then
  begin
    if FExcludedTypes.Contains(ATypedef.FuncInfo.ReturnType) then
      Exit(True);

    for LI := 0 to High(ATypedef.FuncInfo.Params) do
    begin
      if FExcludedTypes.Contains(ATypedef.FuncInfo.Params[LI].TypeName) then
        Exit(True);
    end;
  end;

  Result := False;
end;

function TDelphCImp.DelphifyTypeName(const AName: string): string;
begin
  // Keep original C type name as-is, no T prefix
  Result := AName;
end;

function TDelphCImp.FormatLibName(const APlatform: TTargetPlatform; const AName: string): string;
begin
  Result := AName;
  if APlatform = tpWin64 then
  begin
    if not Result.EndsWith('.dll', True) then
      Result := Result + '.dll';
  end
  else
  begin
    if not Result.StartsWith('lib', True) then
      Result := 'lib' + Result;
    if not Result.EndsWith('.so', True) then
      Result := Result + '.so';
  end;
end;

procedure TDelphCImp.GenerateDelphiUnit();
var
  LDllName: string;
  LUnitName: string;
begin
  FOutput.Clear();

  // Determine unit name
  if FUnitName <> '' then
    LUnitName := FUnitName
  else
    LUnitName := 'U' + FModuleName + 'Import';

  EmitFmt('unit %s;', [LUnitName]);
  EmitLn();
  EmitLn('{$IF NOT (DEFINED(WIN64) OR DEFINED(LINUX64))}');
  EmitLn('  {$MESSAGE Error ''Unsupported platform''}');
  EmitLn('{$IFEND}');
  EmitLn();
  EmitLn('{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}');
  EmitLn();
  if FDelayLoad then
    EmitLn('{$WARN SYMBOL_PLATFORM OFF}');
  EmitLn();
  EmitLn('interface');
  EmitLn();
  EmitLn('uses');
  EmitLn('  System.SysUtils;');
  EmitLn();

  // Emit CLibName constant with platform conditionals
  EmitLn('const');
  EmitLn('  {$IFDEF MSWINDOWS}');
  if FPlatformDllNames.TryGetValue(tpWin64, LDllName) then
    EmitFmt('  CLibName = ''%s'';', [FormatLibName(tpWin64, LDllName)])
  else if FDllName <> '' then
    EmitFmt('  CLibName = ''%s'';', [FormatLibName(tpWin64, FDllName)])
  else
    EmitFmt('  CLibName = ''%s'';', [FormatLibName(tpWin64, FModuleName)]);
  EmitLn('  {$ENDIF}');
  EmitLn('  {$IFDEF LINUX}');
  if FPlatformDllNames.TryGetValue(tpLinux64, LDllName) then
    EmitFmt('  CLibName = ''%s'';', [FormatLibName(tpLinux64, LDllName)])
  else
    EmitFmt('  CLibName = ''%s'';', [FormatLibName(tpLinux64, FModuleName)]);
  EmitLn('  {$ENDIF}');
  EmitLn();

  GenerateSimpleConstants();
  GenerateAllTypes();
  GenerateTypedConstants();
  GenerateFunctions();

  EmitLn('implementation');
  EmitLn();
  EmitLn('end.');
end;

procedure TDelphCImp.GenerateAllTypes();
var
  LStruct: TCStructInfo;
  LEnum: TCEnumInfo;
  LTypedef: TCTypedefInfo;
  LField: TCFieldInfo;
  LValue: TCEnumValue;
  LFieldType: string;
  LTargetType: string;
  LI: Integer;
  LLine: string;
  LHasTypes: Boolean;
  LParamStr: string;
  LParam: TCParamInfo;
  LParamType: string;
  LParamName: string;
  LReturnType: string;
  LDelphiName: string;
  LName: string;
  LResolved: string;
  LFound: Boolean;
begin
  LHasTypes := (FStructs.Count > 0) or (FEnums.Count > 0) or
    (FTypedefs.Count > 0) or (FForwardDecls.Count > 0);
  if not LHasTypes then
    Exit;

  EmitLn('type');

  // Phase 1: Forward pointer declarations for all structs
  if FStructs.Count > 0 then
  begin
    EmitLn('  // Forward pointer declarations for structs');
    for LStruct in FStructs do
    begin
      LDelphiName := DelphifyTypeName(SanitizeIdentifier(LStruct.StructName));
      EmitFmt('  P%s = ^%s;', [SanitizeIdentifier(LStruct.StructName), LDelphiName]);
    end;
    EmitLn();
  end;

  // Phase 2: Forward pointer declarations for opaque types
  if FForwardDecls.Count > 0 then
  begin
    EmitLn('  // Forward pointer declarations for opaque types');
    for LName in FForwardDecls do
    begin
      LDelphiName := DelphifyTypeName(SanitizeIdentifier(LName));
      EmitFmt('  P%s = ^%s;', [SanitizeIdentifier(LName), LDelphiName]);
    end;
    EmitLn();
  end;

  // Phase 3: Forward pointer declarations for typedef aliases targeting structs/opaques
  for LTypedef in FTypedefs do
  begin
    if TypedefReferencesExcludedType(LTypedef) then
      Continue;
    if LTypedef.IsFunctionPointer then
      Continue;

    // Skip redundant aliases
    LTargetType := MapCTypeToDelphi(LTypedef.TargetType, LTypedef.IsPointer, LTypedef.PointerDepth);
    if MapCTypeToDelphi(LTypedef.AliasName, False, 0) = LTargetType then
      Continue;

    LResolved := ResolveTypedefAlias(LTypedef.TargetType);
    LFound := False;
    for LStruct in FStructs do
    begin
      if LStruct.StructName = LResolved then
      begin
        LFound := True;
        Break;
      end;
    end;
    if not LFound then
      LFound := FForwardDecls.Contains(LResolved);
    if LFound then
    begin
      LDelphiName := DelphifyTypeName(SanitizeIdentifier(LTypedef.AliasName));
      EmitFmt('  P%s = ^%s;', [SanitizeIdentifier(LTypedef.AliasName), LDelphiName]);
    end;
  end;
  EmitLn();

  // Phase 4: Opaque type definitions
  if FForwardDecls.Count > 0 then
  begin
    EmitLn('  // Opaque type definitions');
    for LName in FForwardDecls do
    begin
      LDelphiName := DelphifyTypeName(SanitizeIdentifier(LName));
      EmitFmt('  %s = record end;', [LDelphiName]);
    end;
    EmitLn();
  end;

  // Phase 5: Enums
  if FEnums.Count > 0 then
  begin
    EmitLn('  // Enums');
    for LEnum in FEnums do
    begin
      LDelphiName := DelphifyTypeName(SanitizeIdentifier(LEnum.EnumName));
      EmitFmt('  %s = (', [LDelphiName]);
      for LI := 0 to High(LEnum.Values) do
      begin
        LValue := LEnum.Values[LI];
        if LValue.HasExplicitValue then
          LLine := Format('    %s = %d', [SanitizeIdentifier(LValue.ValueName), LValue.Value])
        else
          LLine := '    ' + SanitizeIdentifier(LValue.ValueName);
        if LI < High(LEnum.Values) then
          LLine := LLine + ',';
        EmitLn(LLine);
      end;
      EmitLn('  );');
      EmitLn();
    end;
  end;

  // Phase 6: Records (structs and unions)
  if FStructs.Count > 0 then
  begin
    EmitLn('  // Records');
    for LStruct in FStructs do
    begin
      LDelphiName := DelphifyTypeName(SanitizeIdentifier(LStruct.StructName));
      if LStruct.IsUnion then
      begin
        // Delphi variant record for unions
        EmitFmt('  %s = record', [LDelphiName]);
        EmitLn('    case Integer of');
        for LI := 0 to High(LStruct.Fields) do
        begin
          LField := LStruct.Fields[LI];
          LFieldType := MapCTypeToDelphi(ResolveTypedefAlias(LField.TypeName), LField.IsPointer, LField.PointerDepth);
          if LField.ArraySize > 0 then
            EmitFmt('      %d: (%s: array[0..%d] of %s);', [LI, SanitizeIdentifier(LField.FieldName), LField.ArraySize - 1, LFieldType])
          else
            EmitFmt('      %d: (%s: %s);', [LI, SanitizeIdentifier(LField.FieldName), LFieldType]);
        end;
      end
      else
      begin
        EmitFmt('  %s = record', [LDelphiName]);
        for LField in LStruct.Fields do
        begin
          LFieldType := MapCTypeToDelphi(ResolveTypedefAlias(LField.TypeName), LField.IsPointer, LField.PointerDepth);
          if LField.ArraySize > 0 then
            EmitFmt('    %s: array[0..%d] of %s;', [SanitizeIdentifier(LField.FieldName), LField.ArraySize - 1, LFieldType])
          else if LField.BitWidth > 0 then
            EmitFmt('    %s: %s; // bit width: %d', [SanitizeIdentifier(LField.FieldName), LFieldType, LField.BitWidth])
          else
            EmitFmt('    %s: %s;', [SanitizeIdentifier(LField.FieldName), LFieldType]);
        end;
      end;
      EmitLn('  end;');
      EmitLn();
    end;
  end;

  // Phase 7: Type aliases (non-function-pointer typedefs)
  EmitLn('  // Type aliases');
  for LTypedef in FTypedefs do
  begin
    if TypedefReferencesExcludedType(LTypedef) then
      Continue;
    if LTypedef.IsFunctionPointer then
      Continue;

    LTargetType := MapCTypeToDelphi(LTypedef.TargetType, LTypedef.IsPointer, LTypedef.PointerDepth);

    // Skip redundant aliases
    if MapCTypeToDelphi(LTypedef.AliasName, False, 0) = LTargetType then
      Continue;

    LDelphiName := DelphifyTypeName(SanitizeIdentifier(LTypedef.AliasName));
    EmitFmt('  %s = %s;', [LDelphiName, LTargetType]);
  end;
  EmitLn();

  // Phase 8: Function pointer typedefs
  EmitLn('  // Function pointer types');
  for LTypedef in FTypedefs do
  begin
    if TypedefReferencesExcludedType(LTypedef) then
      Continue;
    if not LTypedef.IsFunctionPointer then
      Continue;

    // Build parameter list
    LParamStr := '';
    for LI := 0 to High(LTypedef.FuncInfo.Params) do
    begin
      LParam := LTypedef.FuncInfo.Params[LI];
      LParamType := MapCTypeToDelphi(LParam.TypeName, LParam.IsPointer, LParam.PointerDepth, LParam.IsConstTarget);
      if LParam.ParamName <> '' then
        LParamName := 'A' + LParam.ParamName
      else
        LParamName := Format('AParam%d', [LI]);
      if LI > 0 then
        LParamStr := LParamStr + '; ';
      LParamStr := LParamStr + Format('const %s: %s', [SanitizeIdentifier(LParamName), LParamType]);
    end;

    LDelphiName := DelphifyTypeName(SanitizeIdentifier(LTypedef.AliasName));

    if (LTypedef.FuncInfo.ReturnType = 'void') and not LTypedef.FuncInfo.ReturnIsPointer then
      EmitFmt('  %s = procedure(%s);', [LDelphiName, LParamStr])
    else
    begin
      LReturnType := MapCTypeToDelphi(LTypedef.FuncInfo.ReturnType, LTypedef.FuncInfo.ReturnIsPointer, LTypedef.FuncInfo.ReturnPointerDepth);
      EmitFmt('  %s = function(%s): %s;', [LDelphiName, LParamStr, LReturnType]);
    end;
  end;
  EmitLn();
end;

procedure TDelphCImp.GenerateFunctions();
var
  LFunc: TCFunctionInfo;
  LParam: TCParamInfo;
  LReturnType: string;
  LParamStr: string;
  LI: Integer;
  LParamType: string;
  LParamName: string;
  LSkip: Boolean;
  LLine: string;
begin
  if FFunctions.Count = 0 then
    Exit;

  EmitLn('// External functions');

  for LFunc in FFunctions do
  begin
    // Skip explicitly excluded functions
    if FExcludedFunctions.Contains(LFunc.FuncName) then
      Continue;

    // Skip functions that reference excluded types
    if FunctionReferencesExcludedType(LFunc) then
      Continue;

    // Skip malformed functions
    if (LFunc.ReturnType = '') or (LFunc.ReturnType = 'return') then
      Continue;
    if (Length(LFunc.ReturnType) = 1) and CharInSet(LFunc.ReturnType[1], ['a'..'z', 'A'..'Z']) then
      Continue;

    // Check for invalid parameter types
    LSkip := False;
    for LI := 0 to High(LFunc.Params) do
    begin
      if LFunc.Params[LI].TypeName = '' then
      begin
        LSkip := True;
        Break;
      end;
      if (Length(LFunc.Params[LI].TypeName) = 1) and CharInSet(LFunc.Params[LI].TypeName[1], ['a'..'z', 'A'..'Z']) then
      begin
        LSkip := True;
        Break;
      end;
    end;
    if LSkip then
      Continue;

    // Build parameter list
    LParamStr := '';
    for LI := 0 to High(LFunc.Params) do
    begin
      LParam := LFunc.Params[LI];
      LParamType := MapCTypeToDelphi(LParam.TypeName, LParam.IsPointer, LParam.PointerDepth, LParam.IsConstTarget);
      if LParam.ParamName <> '' then
        LParamName := 'A' + LParam.ParamName
      else
        LParamName := Format('AParam%d', [LI]);
      if LI > 0 then
        LParamStr := LParamStr + '; ';
      LParamStr := LParamStr + Format('const %s: %s', [SanitizeIdentifier(LParamName), LParamType]);
    end;

    // Emit procedure or function
    if FDelayLoad then
      LLine := 'external CLibName delayed'
    else
      LLine := 'external CLibName';
    if LFunc.IsVariadic then
    begin
      if (LFunc.ReturnType = 'void') and not LFunc.ReturnIsPointer then
        EmitFmt('procedure %s(%s); varargs; %s;', [SanitizeIdentifier(LFunc.FuncName), LParamStr, LLine])
      else
      begin
        LReturnType := MapCTypeToDelphi(LFunc.ReturnType, LFunc.ReturnIsPointer, LFunc.ReturnPointerDepth);
        EmitFmt('function  %s(%s): %s; varargs; %s;', [SanitizeIdentifier(LFunc.FuncName), LParamStr, LReturnType, LLine]);
      end;
    end
    else
    begin
      if (LFunc.ReturnType = 'void') and not LFunc.ReturnIsPointer then
        EmitFmt('procedure %s(%s); %s;', [SanitizeIdentifier(LFunc.FuncName), LParamStr, LLine])
      else
      begin
        LReturnType := MapCTypeToDelphi(LFunc.ReturnType, LFunc.ReturnIsPointer, LFunc.ReturnPointerDepth);
        EmitFmt('function  %s(%s): %s; %s;', [SanitizeIdentifier(LFunc.FuncName), LParamStr, LReturnType, LLine]);
      end;
    end;
  end;
  EmitLn();
end;

procedure TDelphCImp.GenerateSimpleConstants();
var
  LDefine: TCDefineInfo;
  LHasConstants: Boolean;
begin
  LHasConstants := False;
  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;
    if LDefine.IsInteger or LDefine.IsFloat or LDefine.IsString then
    begin
      LHasConstants := True;
      Break;
    end;
  end;

  if not LHasConstants then
    Exit;

  EmitLn('const');
  EmitLn('  // Constants from #define');

  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;

    if LDefine.IsInteger then
      EmitFmt('  %s = %d;', [SanitizeIdentifier(LDefine.DefineName), LDefine.IntValue])
    else if LDefine.IsFloat then
      EmitFmt('  %s = %s;', [SanitizeIdentifier(LDefine.DefineName), FloatToStr(LDefine.FloatValue)])
    else if LDefine.IsString then
      EmitFmt('  %s = ''%s'';', [SanitizeIdentifier(LDefine.DefineName), LDefine.StringValue.Replace('''', '''''')]);
  end;

  EmitLn();
end;

procedure TDelphCImp.GenerateTypedConstants();
var
  LDefine: TCDefineInfo;
  LHasTypedConstants: Boolean;
  LStruct: TCStructInfo;
  LValues: TArray<string>;
  LLine: string;
  LI: Integer;
  LFound: Boolean;
  LTypeName: string;
begin
  LHasTypedConstants := False;
  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;
    if LDefine.IsTypedConstant then
    begin
      LHasTypedConstants := True;
      Break;
    end;
  end;

  if not LHasTypedConstants then
    Exit;

  EmitLn('const');
  EmitLn('  // Typed constants from compound literals');

  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;
    if not LDefine.IsTypedConstant then
      Continue;

    LTypeName := DelphifyTypeName(SanitizeIdentifier(LDefine.TypedConstType));

    // Split values and try to match against struct fields
    LValues := LDefine.TypedConstValues.Split([',']);
    for LI := 0 to High(LValues) do
      LValues[LI] := Trim(LValues[LI]);

    // Look up the struct by name
    LFound := False;
    for LStruct in FStructs do
    begin
      if (DelphifyTypeName(SanitizeIdentifier(LStruct.StructName)) = LTypeName) and
         (Length(LStruct.Fields) = Length(LValues)) and
         (not LStruct.IsUnion) then
      begin
        // Field count matches, emit with field names
        LLine := Format('  %s: %s = (', [SanitizeIdentifier(LDefine.DefineName), LTypeName]);
        for LI := 0 to High(LStruct.Fields) do
        begin
          if LI > 0 then
            LLine := LLine + '; ';
          LLine := LLine + Format('%s: %s', [SanitizeIdentifier(LStruct.Fields[LI].FieldName), LValues[LI]]);
        end;
        LLine := LLine + ');';
        EmitLn(LLine);
        LFound := True;
        Break;
      end;
    end;

    // Fallback: emit as comment if struct not found or field count mismatch
    if not LFound then
      EmitFmt('  // %s: %s = (%s);  // TODO: fill in field names', [
        SanitizeIdentifier(LDefine.DefineName),
        LTypeName,
        LDefine.TypedConstValues
      ]);
  end;

  EmitLn();
end;

procedure TDelphCImp.ParseDefines(const APreprocessedSource: string);
var
  LLines: TArray<string>;
  LLine: string;
  LTrimmed: string;
  LDefineInfo: TCDefineInfo;
  LSpacePos: Integer;
  LValue: string;
  LIntVal: Int64;
  LFloatVal: Double;
  LQuoteStart: Integer;
  LQuoteEnd: Integer;
  LParenPos: Integer;
  LBracePos: Integer;
  LPrefix: string;
  LBraceEnd: Integer;
  LTypeStart: Integer;
  LTypeName: string;
  LValues: string;
  LCastEnd: Integer;
  LInnerValue: string;
begin
  // Parse #define directives from preprocessed source
  // Format: #define NAME value
  LLines := APreprocessedSource.Split([#10]);
  for LLine in LLines do
  begin
    LTrimmed := LLine.Trim();

    // Check for line marker to track current source file
    // Format: # linenum "filename" [flags]
    if (Length(LTrimmed) > 2) and (LTrimmed[1] = '#') and (LTrimmed[2] = ' ') and
       CharInSet(LTrimmed[3], ['0'..'9']) then
    begin
      LQuoteStart := Pos('"', LTrimmed);
      if LQuoteStart > 0 then
      begin
        LQuoteEnd := Pos('"', LTrimmed, LQuoteStart + 1);
        if LQuoteEnd > LQuoteStart then
          FCurrentSourceFile := Copy(LTrimmed, LQuoteStart + 1, LQuoteEnd - LQuoteStart - 1);
      end;
      Continue;
    end;

    // Skip if not a #define
    if not LTrimmed.StartsWith('#define ') then
      Continue;

    // Skip defines from non-allowed source files
    if not IsAllowedSourceFile() then
      Continue;

    // Extract name and value: "#define NAME value"
    LTrimmed := Copy(LTrimmed, 9, Length(LTrimmed)); // Skip "#define "
    LTrimmed := LTrimmed.TrimLeft();

    // Skip function-like macros (parenthesis immediately after name, before space)
    // Function-like: #define FOO(x) -> "FOO(x) ..."
    // Value with cast: #define FOO ((Type) val) -> "FOO ((Type) val)"
    LSpacePos := Pos(' ', LTrimmed);
    LParenPos := Pos('(', LTrimmed);
    if (LParenPos > 0) and ((LSpacePos = 0) or (LParenPos < LSpacePos)) then
      Continue;

    // Find space separating name from value (already found above)
    if LSpacePos = 0 then
      Continue; // No value, skip

    LDefineInfo.DefineName := Copy(LTrimmed, 1, LSpacePos - 1);
    LValue := Copy(LTrimmed, LSpacePos + 1, Length(LTrimmed)).Trim();
    LDefineInfo.DefineValue := LValue;

    // Skip empty values
    if LValue = '' then
      Continue;

    // Skip internal/system defines (start with underscore)
    if LDefineInfo.DefineName.StartsWith('_') then
      Continue;

    // Determine value type
    LDefineInfo.IsInteger := False;
    LDefineInfo.IsFloat := False;
    LDefineInfo.IsString := False;
    LDefineInfo.IsTypedConstant := False;
    LDefineInfo.IntValue := 0;
    LDefineInfo.FloatValue := 0;
    LDefineInfo.StringValue := '';
    LDefineInfo.TypedConstType := '';
    LDefineInfo.TypedConstValues := '';

    // Handle compound literals: IDENTIFIER(Type){ val1, val2, ... } or (Type){ val1, val2, ... }
    // Examples: CLITERAL(Color){ 200, 200, 200, 255 }, (Vector2){ 1.0f, 2.0f }
    LBracePos := Pos('{', LValue);
    if LBracePos > 1 then
    begin
      LPrefix := Copy(LValue, 1, LBracePos - 1).Trim();
      LBraceEnd := Pos('}', LValue);
      if (LBraceEnd > LBracePos) and LPrefix.EndsWith(')') then
      begin
        // Extract type name from IDENTIFIER(Type) or (Type)
        LTypeStart := Pos('(', LPrefix);
        if LTypeStart > 0 then
        begin
          LTypeName := Copy(LPrefix, LTypeStart + 1, Length(LPrefix) - LTypeStart - 1);
          // Extract values between { and }
          LValues := Copy(LValue, LBracePos + 1, LBraceEnd - LBracePos - 1).Trim();
          if (LTypeName <> '') and (LValues <> '') then
          begin
            LDefineInfo.IsTypedConstant := True;
            LDefineInfo.TypedConstType := LTypeName;
            LDefineInfo.TypedConstValues := LValues;
            FDefines.Add(LDefineInfo);
            Continue;
          end;
        end;
      end;
    end;

    // Handle C cast expressions: ((TypeName) value) or (TypeName) value
    // Examples: ((SDL_AudioDeviceID) 0xFFFFFFFFu), (int) 42
    if LValue.StartsWith('(') then
    begin
      // Find the closing paren of the cast type
      LCastEnd := Pos(')', LValue);
      if LCastEnd > 0 then
      begin
        // Extract everything after the cast
        LInnerValue := Copy(LValue, LCastEnd + 1, Length(LValue)).Trim();
        // Strip outer parens if present: ((Type) val) -> val)
        if LInnerValue.EndsWith(')') then
          LInnerValue := Copy(LInnerValue, 1, Length(LInnerValue) - 1).Trim();
        // Use extracted value for further parsing
        if LInnerValue <> '' then
          LValue := LInnerValue;
      end;
    end;

    // Check for hex integer
    if LValue.StartsWith('0x') or LValue.StartsWith('0X') then
    begin
      // Strip suffixes
      while (Length(LValue) > 0) and CharInSet(LValue[Length(LValue)], ['u', 'U', 'l', 'L']) do
        LValue := Copy(LValue, 1, Length(LValue) - 1);
      if TryStrToInt64('$' + Copy(LValue, 3, Length(LValue)), LIntVal) then
      begin
        LDefineInfo.IsInteger := True;
        LDefineInfo.IntValue := LIntVal;
      end;
    end
    // Check for decimal integer
    else if (Length(LValue) > 0) and (CharInSet(LValue[1], ['0'..'9', '-'])) then
    begin
      // Strip suffixes
      while (Length(LValue) > 0) and CharInSet(LValue[Length(LValue)], ['u', 'U', 'l', 'L', 'f', 'F']) do
        LValue := Copy(LValue, 1, Length(LValue) - 1);

      // Try integer first
      if TryStrToInt64(LValue, LIntVal) then
      begin
        LDefineInfo.IsInteger := True;
        LDefineInfo.IntValue := LIntVal;
      end
      // Try float
      else if TryStrToFloat(LValue, LFloatVal) then
      begin
        LDefineInfo.IsFloat := True;
        LDefineInfo.FloatValue := LFloatVal;
      end;
    end
    // Check for string literal
    else if LValue.StartsWith('"') and LValue.EndsWith('"') then
    begin
      LDefineInfo.IsString := True;
      LDefineInfo.StringValue := Copy(LValue, 2, Length(LValue) - 2);
    end;

    // Only add if we parsed a value
    if LDefineInfo.IsInteger or LDefineInfo.IsFloat or LDefineInfo.IsString then
      FDefines.Add(LDefineInfo);
  end;
end;

procedure TDelphCImp.ParsePreprocessed(const APreprocessedSource: string);
begin
  // Parse #define directives first (before tokenization strips them)
  ParseDefines(APreprocessedSource);

  FLexer.Tokenize(APreprocessedSource);
  FPos := 0;
  FCurrentToken := FLexer.GetToken(0);
  ParseTopLevel();
  GenerateDelphiUnit();
  ProcessInsertions();
end;

procedure TDelphCImp.AddIncludePath(const APath: string; const AModuleName: string);
var
  LPath: string;
begin
  LPath := APath.Replace('\', '/');
  if not FIncludePaths.Contains(LPath) then
    FIncludePaths.Add(LPath);

  // Store module association if provided
  if AModuleName <> '' then
    FIncludeModules.AddOrSetValue(LPath, AModuleName);
end;

procedure TDelphCImp.AddSourcePath(const APath: string);
var
  LPath: string;
begin
  LPath := APath.Replace('\', '/');
  if not FSourcePaths.Contains(LPath) then
    FSourcePaths.Add(LPath);
end;



procedure TDelphCImp.AddExcludedType(const ATypeName: string);
begin
  if not FExcludedTypes.Contains(ATypeName) then
    FExcludedTypes.Add(ATypeName);
end;

procedure TDelphCImp.AddExcludedFunction(const AFuncName: string);
begin
  if not FExcludedFunctions.Contains(AFuncName) then
    FExcludedFunctions.Add(AFuncName);
end;



procedure TDelphCImp.SetSavePreprocessed(const AValue: Boolean);
begin
  FSavePreprocessed := AValue;
end;

procedure TDelphCImp.EnableDelayLoad(const AValue: Boolean);
begin
  FDelayLoad := AValue;
end;

procedure TDelphCImp.InsertTextAfter(const ATargetLine: string; const AText: string; const AOccurrence: Integer);
var
  LInfo: TInsertionInfo;
begin
  LInfo.TargetLine := ATargetLine;
  LInfo.Content := AText;
  LInfo.InsertBefore := False;
  LInfo.Occurrence := AOccurrence;
  FInsertions.Add(LInfo);
end;

procedure TDelphCImp.InsertFileAfter(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer);
var
  LContent: string;
begin
  if TFile.Exists(AFilePath) then
  begin
    LContent := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
    InsertTextAfter(ATargetLine, LContent, AOccurrence);
  end;
end;

procedure TDelphCImp.InsertTextBefore(const ATargetLine: string; const AText: string; const AOccurrence: Integer);
var
  LInfo: TInsertionInfo;
begin
  LInfo.TargetLine := ATargetLine;
  LInfo.Content := AText;
  LInfo.InsertBefore := True;
  LInfo.Occurrence := AOccurrence;
  FInsertions.Add(LInfo);
end;

procedure TDelphCImp.InsertFileBefore(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer);
var
  LContent: string;
begin
  if TFile.Exists(AFilePath) then
  begin
    LContent := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
    InsertTextBefore(ATargetLine, LContent, AOccurrence);
  end;
end;

procedure TDelphCImp.ReplaceText(const AOldText: string; const ANewText: string; const AOccurrence: Integer);
var
  LInfo: TReplacementInfo;
begin
  LInfo.OldText := AOldText;
  LInfo.NewText := ANewText;
  LInfo.Occurrence := AOccurrence;
  FReplacements.Add(LInfo);
end;

function TDelphCImp.Process(): Boolean;
var
  LPreprocessedSource: string;
  LHeaderName: string;
  LOutputFile: string;
  LOutputDir: string;
  LStructCount: Integer;
  LUnionCount: Integer;
  LEnumCount: Integer;
  LTypedefCount: Integer;
  LFuncPtrCount: Integer;
  LDefineCount: Integer;
  LStruct: TCStructInfo;
  LTypedef: TCTypedefInfo;
  LDefine: TCDefineInfo;
  LUnitName: string;
begin
  Result := False;
  FLastError := '';

  if FHeader = '' then
  begin
    FLastError := 'No header file specified';
    Exit;
  end;

  FLexer.Clear();
  FOutput.Clear();
  FStructs.Clear();
  FEnums.Clear();
  FTypedefs.Clear();
  FDefines.Clear();
  FFunctions.Clear();
  FForwardDecls.Clear();
  FCurrentSourceFile := '';
  FPos := 0;
  FIndent := 0;

  LHeaderName := TPath.GetFileNameWithoutExtension(FHeader);

  if FModuleName = '' then
    FModuleName := LHeaderName;

  // Determine unit name
  if FUnitName <> '' then
    LUnitName := FUnitName
  else
    LUnitName := 'U' + FModuleName + 'Import';

  if FOutputPath <> '' then
    LOutputDir := FOutputPath
  else
    LOutputDir := TPath.GetDirectoryName(TPath.GetFullPath(FHeader));

  LOutputFile := TPath.Combine(LOutputDir, LUnitName + '.pas').Replace('\', '/');

  // Header info
  Status(COLOR_CYAN + 'DelphiCImp' + COLOR_RESET + ' - C Header to Delphi Import Unit Generator', []);
  Status(COLOR_WHITE + '  Header: ' + COLOR_RESET + '%s', [FHeader]);
  Status(COLOR_WHITE + '  Module: ' + COLOR_RESET + '%s', [FModuleName]);
  Status(COLOR_WHITE + '  Unit:   ' + COLOR_RESET + '%s', [LUnitName]);
  Status('', []);

  // Preprocessing phase
  Status(COLOR_CYAN + 'Preprocessing...' + COLOR_RESET, []);
  if not PreprocessHeader(FHeader, LPreprocessedSource) then
  begin
    Status(COLOR_RED + '  Failed: ' + COLOR_RESET + '%s', [FLastError]);
    Exit;
  end;
  Status(COLOR_WHITE + '  Preprocessed size: ' + COLOR_RESET + '%d bytes', [Length(LPreprocessedSource)]);
  if FSavePreprocessed then
    Status(COLOR_WHITE + '  Saved preprocessed: ' + COLOR_RESET + '%s_pp.c', [FModuleName]);

  // Parsing phase
  Status(COLOR_CYAN + 'Parsing declarations...' + COLOR_RESET, []);
  ParsePreprocessed(LPreprocessedSource);

  // Count structs vs unions
  LStructCount := 0;
  LUnionCount := 0;
  for LStruct in FStructs do
  begin
    if LStruct.IsUnion then
      Inc(LUnionCount)
    else
      Inc(LStructCount);
  end;

  // Count typedefs vs function pointers
  LTypedefCount := 0;
  LFuncPtrCount := 0;
  for LTypedef in FTypedefs do
  begin
    if LTypedef.IsFunctionPointer then
      Inc(LFuncPtrCount)
    else
      Inc(LTypedefCount);
  end;

  LEnumCount := FEnums.Count;

  // Count defines
  LDefineCount := 0;
  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;
    if LDefine.IsInteger or LDefine.IsFloat or LDefine.IsString then
      Inc(LDefineCount);
  end;

  Status(COLOR_WHITE + '  Forward decls:    ' + COLOR_RESET + '%d', [FForwardDecls.Count]);
  Status(COLOR_WHITE + '  Structs:          ' + COLOR_RESET + '%d', [LStructCount]);
  Status(COLOR_WHITE + '  Unions:           ' + COLOR_RESET + '%d', [LUnionCount]);
  Status(COLOR_WHITE + '  Enums:            ' + COLOR_RESET + '%d', [LEnumCount]);
  Status(COLOR_WHITE + '  Type aliases:     ' + COLOR_RESET + '%d', [LTypedefCount]);
  Status(COLOR_WHITE + '  Function ptrs:    ' + COLOR_RESET + '%d', [LFuncPtrCount]);
  Status(COLOR_WHITE + '  External funcs:   ' + COLOR_RESET + '%d', [FFunctions.Count]);
  Status(COLOR_WHITE + '  Defines:          ' + COLOR_RESET + '%d', [LDefineCount]);

  // Writing phase
  Status(COLOR_CYAN + 'Writing output...' + COLOR_RESET, []);
  try
    TUtils.CreateDirInPath(LOutputFile);
    TFile.WriteAllText(LOutputFile, FOutput.ToString(), TEncoding.UTF8);
  except
    on E: Exception do
    begin
      FLastError := 'Failed to write output file: ' + E.Message;
      Status(COLOR_RED + '  Failed: ' + COLOR_RESET + '%s', [FLastError]);
      Exit;
    end;
  end;

  Status(COLOR_WHITE + '  Output: ' + COLOR_RESET + '%s', [LOutputFile]);
  Status('', []);

  Status(COLOR_GREEN + 'Import complete.' + COLOR_RESET, []);

  DoPostCopyFile();

  Result := True;
end;

procedure TDelphCImp.AddPostCopyFile(const APlatform: TTargetPlatform; const ASourceFile: string; const ADestDir: string);
var
  LInfo: TPostCopyInfo;
begin
  LInfo.Platform := APlatform;
  LInfo.SourceFile := ASourceFile;
  LInfo.DestDir := ADestDir;
  FPostCopyFiles.Add(LInfo);
end;

procedure TDelphCImp.DoPostCopyFile();
var
  LInfo: TPostCopyInfo;
  LDestFile: string;
begin
  if FPostCopyFiles.Count = 0 then
    Exit;

  Status(COLOR_CYAN + 'Copying post-build files...' + COLOR_RESET, []);
  for LInfo in FPostCopyFiles do
  begin
    // Only copy files for the current platform
    {$IFDEF MSWINDOWS}
    if LInfo.Platform <> tpWin64 then
      Continue;
    {$ENDIF}
    {$IFDEF LINUX}
    if LInfo.Platform <> tpLinux64 then
      Continue;
    {$ENDIF}

    LDestFile := TPath.Combine(LInfo.DestDir, TPath.GetFileName(LInfo.SourceFile));
    try
      TUtils.CreateDirInPath(LDestFile);
      TFile.Copy(LInfo.SourceFile, LDestFile, True);
      Status(COLOR_WHITE + '  Copied: ' + COLOR_RESET + '%s -> %s', [LInfo.SourceFile.Replace('\', '/'), LDestFile.Replace('\', '/')]);
    except
      on E: Exception do
      begin
        FLastError := Format('Failed to copy %s: %s', [LInfo.SourceFile.Replace('\', '/'), E.Message]);
        Status(COLOR_RED + '  Failed: ' + COLOR_RESET + '%s', [FLastError]);
      end;
    end;
  end;
end;

procedure TDelphCImp.ProcessInsertions();
var
  LOutput: string;
  LInsertion: TInsertionInfo;
  LReplacement: TReplacementInfo;
  LOccurrenceCount: Integer;
  LTargetTrimmed: string;
  LLines: TArray<string>;
  LLine: string;
  LTrimmedLine: string;
  LResult: TStringBuilder;
  LI: Integer;
  LInserted: Boolean;
  LPos: Integer;
  LCount: Integer;
  LSearchStart: Integer;
begin
  if (FInsertions.Count = 0) and (FReplacements.Count = 0) then
    Exit;

  LOutput := FOutput.ToString();

  for LInsertion in FInsertions do
  begin
    LTargetTrimmed := LowerCase(Trim(LInsertion.TargetLine));
    LOccurrenceCount := 0;
    LInserted := False;

    // Split preserving empty lines
    LLines := LOutput.Split([#13#10, #10], TStringSplitOptions.None);

    LResult := TStringBuilder.Create();
    try
      for LI := 0 to High(LLines) do
      begin
        LLine := LLines[LI];
        LTrimmedLine := LowerCase(Trim(LLine));

        if (not LInserted) and (LTrimmedLine = LTargetTrimmed) then
        begin
          Inc(LOccurrenceCount);
          if LOccurrenceCount = LInsertion.Occurrence then
          begin
            if LInsertion.InsertBefore then
            begin
              LResult.Append(LInsertion.Content);
              LResult.AppendLine(LLine);
            end
            else
            begin
              LResult.AppendLine(LLine);
              LResult.Append(LInsertion.Content);
            end;
            LInserted := True;
          end
          else
          begin
            LResult.AppendLine(LLine);
          end;
        end
        else
        begin
          // Don't add newline after last line
          if LI < High(LLines) then
            LResult.AppendLine(LLine)
          else
            LResult.Append(LLine);
        end;
      end;

      LOutput := LResult.ToString();
    finally
      LResult.Free();
    end;
  end;

  // Update output
  FOutput.Clear();
  FOutput.Append(LOutput);

  // Process replacements
  if FReplacements.Count > 0 then
  begin
    LOutput := FOutput.ToString();

    for LReplacement in FReplacements do
    begin
      if LReplacement.Occurrence = 0 then
      begin
        // Replace all occurrences
        LOutput := LOutput.Replace(LReplacement.OldText, LReplacement.NewText);
      end
      else
      begin
        // Replace specific occurrence
        LCount := 0;
        LSearchStart := 1;

        while LSearchStart <= Length(LOutput) do
        begin
          LPos := Pos(LReplacement.OldText, LOutput, LSearchStart);
          if LPos = 0 then
            Break;

          Inc(LCount);
          if LCount = LReplacement.Occurrence then
          begin
            // Replace this occurrence
            LOutput := Copy(LOutput, 1, LPos - 1) +
                       LReplacement.NewText +
                       Copy(LOutput, LPos + Length(LReplacement.OldText), MaxInt);
            Break;
          end;

          LSearchStart := LPos + Length(LReplacement.OldText);
        end;
      end;
    end;

    FOutput.Clear();
    FOutput.Append(LOutput);
  end;
end;

procedure TDelphCImp.SetOutputPath(const APath: string);
begin
  FOutputPath := APath.Replace('\', '/');
end;

procedure TDelphCImp.SetHeader(const AFilename: string);
begin
  FHeader := AFilename.Replace('\', '/');
end;

procedure TDelphCImp.SetModuleName(const AName: string);
begin
  FModuleName := AName;
end;
procedure TDelphCImp.SetUnitName(const AName: string);
begin
  FUnitName := AName;
end;

procedure TDelphCImp.SetDllName(const ADllName: string);
begin
  FDllName := ADllName;
end;

procedure TDelphCImp.SetDllName(const APlatform: TTargetPlatform; const ADllName: string);
begin
  FPlatformDllNames.AddOrSetValue(APlatform, ADllName);
end;

function TDelphCImp.LoadFromConfig(const AFilename: string): Boolean;
var
  LConfig: TConfig;
  LPaths: TArray<string>;
  LPath: string;
  LInsertionCount: Integer;
  LI: Integer;
  LTarget: string;
  LContent: string;
  LFilePath: string;
  LPosition: string;
  LOccurrence: Integer;
begin
  Result := False;

  LConfig := TConfig.Create();
  try
    if not LConfig.LoadFromFile(AFilename) then
    begin
      FLastError := LConfig.GetLastError();
      Exit;
    end;

    // Header (required)
    if not LConfig.HasKey('cimporter.header') then
    begin
      FLastError := 'No header file specified in configuration';
      Exit;
    end;
    SetHeader(LConfig.GetString('cimporter.header'));

    // Simple settings
    if LConfig.HasKey('cimporter.module_name') then
      SetModuleName(LConfig.GetString('cimporter.module_name'));

    if LConfig.HasKey('cimporter.dll_name') then
      SetDllName(LConfig.GetString('cimporter.dll_name'));

    if LConfig.HasKey('cimporter.unit_name') then
      SetUnitName(LConfig.GetString('cimporter.unit_name'));

    if LConfig.HasKey('cimporter.output_path') then
      SetOutputPath(LConfig.GetString('cimporter.output_path'));

    // Include paths (array of tables with path and optional module)
    LInsertionCount := LConfig.GetTableCount('cimporter.include_paths');
    if LInsertionCount > 0 then
    begin
      for LI := 0 to LInsertionCount - 1 do
      begin
        LPath := LConfig.GetTableString('cimporter.include_paths', LI, 'path');
        LContent := LConfig.GetTableString('cimporter.include_paths', LI, 'module');
        if LPath <> '' then
          AddIncludePath(LPath, LContent);
      end;
    end
    else
    begin
      // Fallback: simple string array for backward compatibility
      LPaths := LConfig.GetStringArray('cimporter.include_paths');
      for LPath in LPaths do
        AddIncludePath(LPath);
    end;

    // Source paths (for filtering output)
    LPaths := LConfig.GetStringArray('cimporter.source_paths');
    for LPath in LPaths do
      AddSourcePath(LPath);

    // Excluded types
    LPaths := LConfig.GetStringArray('cimporter.excluded_types');
    for LPath in LPaths do
      AddExcludedType(LPath);

    // Excluded functions
    LPaths := LConfig.GetStringArray('cimporter.excluded_functions');
    for LPath in LPaths do
      AddExcludedFunction(LPath);

    // Save preprocessed flag
    if LConfig.HasKey('cimporter.save_preprocessed') then
      SetSavePreprocessed(LConfig.GetBoolean('cimporter.save_preprocessed'));

    // Delay load flag
    if LConfig.HasKey('cimporter.delay_load') then
      EnableDelayLoad(LConfig.GetBoolean('cimporter.delay_load'));

    // Insertions (array of tables)
    LInsertionCount := LConfig.GetTableCount('cimporter.insertions');
    for LI := 0 to LInsertionCount - 1 do
    begin
      LTarget := LConfig.GetTableString('cimporter.insertions', LI, 'target');
      LContent := LConfig.GetTableString('cimporter.insertions', LI, 'content');
      LFilePath := LConfig.GetTableString('cimporter.insertions', LI, 'file');
      LPosition := LConfig.GetTableString('cimporter.insertions', LI, 'position', 'after');
      LOccurrence := LConfig.GetTableInteger('cimporter.insertions', LI, 'occurrence', 1);

      if LFilePath <> '' then
      begin
        if LPosition = 'before' then
          InsertFileBefore(LTarget, LFilePath, LOccurrence)
        else
          InsertFileAfter(LTarget, LFilePath, LOccurrence);
      end
      else if LContent <> '' then
      begin
        if LPosition = 'before' then
          InsertTextBefore(LTarget, LContent, LOccurrence)
        else
          InsertTextAfter(LTarget, LContent, LOccurrence);
      end;
    end;

    // Replacements (array of tables)
    LInsertionCount := LConfig.GetTableCount('cimporter.replacements');
    for LI := 0 to LInsertionCount - 1 do
    begin
      LContent := LConfig.GetTableString('cimporter.replacements', LI, 'old_text');
      LTarget := LConfig.GetTableString('cimporter.replacements', LI, 'new_text');
      LOccurrence := LConfig.GetTableInteger('cimporter.replacements', LI, 'occurrence', 0);

      if LContent <> '' then
        ReplaceText(LContent, LTarget, LOccurrence);
    end;

    // Post-copy files (array of tables)
    LInsertionCount := LConfig.GetTableCount('cimporter.post_copy_files');
    for LI := 0 to LInsertionCount - 1 do
    begin
      LContent := LConfig.GetTableString('cimporter.post_copy_files', LI, 'source');
      LTarget := LConfig.GetTableString('cimporter.post_copy_files', LI, 'dest_dir');
      LPosition := LConfig.GetTableString('cimporter.post_copy_files', LI, 'platform', 'win64');
      if LContent <> '' then
      begin
        if LPosition = 'linux64' then
          AddPostCopyFile(tpLinux64, LContent, LTarget)
        else
          AddPostCopyFile(tpWin64, LContent, LTarget);
      end;
    end;

    Result := True;
  finally
    LConfig.Free();
  end;
end;

function TDelphCImp.SaveToConfig(const AFilename: string): Boolean;
var
  LConfig: TConfig;
  LPaths: TArray<string>;
  LI: Integer;
  LInsertion: TInsertionInfo;
  LReplacement: TReplacementInfo;
  LOutput: TStringBuilder;
  LContent: string;
begin
  Result := False;

  LConfig := TConfig.Create();
  try
    // Header
    if FHeader <> '' then
      LConfig.SetString('cimporter.header', FHeader);

    // Module name
    if FModuleName <> '' then
      LConfig.SetString('cimporter.module_name', FModuleName);

    if FUnitName <> '' then
      LConfig.SetString('cimporter.unit_name', FUnitName);

    // DLL name
    if FDllName <> '' then
      LConfig.SetString('cimporter.dll_name', FDllName);

    // Output path
    if FOutputPath <> '' then
      LConfig.SetString('cimporter.output_path', FOutputPath);

    // Include paths saved separately as array of tables (below)

    // Source paths
    if FSourcePaths.Count > 0 then
    begin
      SetLength(LPaths, FSourcePaths.Count);
      for LI := 0 to FSourcePaths.Count - 1 do
        LPaths[LI] := FSourcePaths[LI];
      LConfig.SetStringArray('cimporter.source_paths', LPaths);
    end;

    // Excluded types
    if FExcludedTypes.Count > 0 then
    begin
      SetLength(LPaths, FExcludedTypes.Count);
      for LI := 0 to FExcludedTypes.Count - 1 do
        LPaths[LI] := FExcludedTypes[LI];
      LConfig.SetStringArray('cimporter.excluded_types', LPaths);
    end;

    // Excluded functions
    if FExcludedFunctions.Count > 0 then
    begin
      SetLength(LPaths, FExcludedFunctions.Count);
      for LI := 0 to FExcludedFunctions.Count - 1 do
        LPaths[LI] := FExcludedFunctions[LI];
      LConfig.SetStringArray('cimporter.excluded_functions', LPaths);
    end;

    // Save preprocessed flag
    if FSavePreprocessed then
      LConfig.SetBoolean('cimporter.save_preprocessed', True);

    // Delay load flag
    if FDelayLoad then
      LConfig.SetBoolean('cimporter.delay_load', True);

    // Save base config first
    if not LConfig.SaveToFile(AFilename) then
    begin
      FLastError := LConfig.GetLastError();
      Exit;
    end;

    // Append include_paths as array of tables
    if FIncludePaths.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LI := 0 to FIncludePaths.Count - 1 do
        begin
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.include_paths]]');
          LOutput.AppendLine(Format('path = "%s"', [FIncludePaths[LI].Replace('\', '\\')]));
          if FIncludeModules.TryGetValue(FIncludePaths[LI], LContent) and (LContent <> '') then
            LOutput.AppendLine(Format('module = "%s"', [LContent]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    // Append insertions manually (array of tables not supported by generic SetXxx)
    if FInsertions.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LI := 0 to FInsertions.Count - 1 do
        begin
          LInsertion := FInsertions[LI];
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.insertions]]');
          LOutput.AppendLine(Format('target = "%s"', [LInsertion.TargetLine]));

          LContent := LInsertion.Content;
          if (Pos(#10, LContent) > 0) or (Pos(#13, LContent) > 0) then
            LOutput.AppendLine('content = """' + #10 + LContent + '"""')
          else
            LOutput.AppendLine(Format('content = "%s"', [LContent]));

          if LInsertion.InsertBefore then
            LOutput.AppendLine('position = "before"')
          else
            LOutput.AppendLine('position = "after"');

          if LInsertion.Occurrence <> 1 then
            LOutput.AppendLine(Format('occurrence = %d', [LInsertion.Occurrence]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    // Append replacements manually (array of tables not supported by generic SetXxx)
    if FReplacements.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LI := 0 to FReplacements.Count - 1 do
        begin
          LReplacement := FReplacements[LI];
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.replacements]]');
          LOutput.AppendLine(Format('old_text = "%s"', [LReplacement.OldText]));
          LOutput.AppendLine(Format('new_text = "%s"', [LReplacement.NewText]));

          if LReplacement.Occurrence <> 0 then
            LOutput.AppendLine(Format('occurrence = %d', [LReplacement.Occurrence]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    // Append post-copy files
    if FPostCopyFiles.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LI := 0 to FPostCopyFiles.Count - 1 do
        begin
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.post_copy_files]]');
          if FPostCopyFiles[LI].Platform = tpLinux64 then
            LOutput.AppendLine('platform = "linux64"')
          else
            LOutput.AppendLine('platform = "win64"');
          LOutput.AppendLine(Format('source = "%s"', [FPostCopyFiles[LI].SourceFile.Replace('\', '\\')]));
          LOutput.AppendLine(Format('dest_dir = "%s"', [FPostCopyFiles[LI].DestDir.Replace('\', '\\')]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    Result := True;
  finally
    LConfig.Free();
  end;
end;

function TDelphCImp.GetLastError(): string;
begin
  Result := FLastError;
end;

procedure TDelphCImp.Clear();
begin
  FLexer.Clear();
  FOutput.Clear();
  FStructs.Clear();
  FEnums.Clear();
  FTypedefs.Clear();
  FDefines.Clear();
  FFunctions.Clear();
  FForwardDecls.Clear();
  FInsertions.Clear();
  FReplacements.Clear();
  FPostCopyFiles.Clear();
  FIncludePaths.Clear();
  FIncludeModules.Clear();
  FExternalTypes.Clear();
  FSourcePaths.Clear();
  FExcludedTypes.Clear();
  FExcludedFunctions.Clear();
  FSavePreprocessed := False;
  FDelayLoad := False;
  FModuleName := '';
  FUnitName := '';
  FDllName := '';
  FDelayLoad := False;
  FOutputPath := '';
  FHeader := '';
  FLastError := '';
  FCurrentSourceFile := '';
  FPos := 0;
  FIndent := 0;

  // Clear per-platform dictionaries
  FPlatformDllNames.Clear();
end;

end.
