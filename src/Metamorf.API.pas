{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.API;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Rtti,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.Common,
  Metamorf.Config,
  Metamorf.LangConfig,
  Metamorf.Lexer,
  Metamorf.Parser,
  Metamorf.Semantics,
  Metamorf.CodeGen,
  Metamorf.IR,
  Metamorf.Build;

const
  // Color constants
  COLOR_RESET  = Metamorf.Utils.COLOR_RESET;
  COLOR_BOLD   = Metamorf.Utils.COLOR_BOLD;
  COLOR_RED    = Metamorf.Utils.COLOR_RED;
  COLOR_GREEN  = Metamorf.Utils.COLOR_GREEN;
  COLOR_YELLOW = Metamorf.Utils.COLOR_YELLOW;
  COLOR_BLUE   = Metamorf.Utils.COLOR_BLUE;
  COLOR_CYAN   = Metamorf.Utils.COLOR_CYAN;
  COLOR_WHITE  = Metamorf.Utils.COLOR_WHITE;

  // Token kind constants
  KIND_EOF           = Metamorf.Common.KIND_EOF;
  KIND_UNKNOWN       = Metamorf.Common.KIND_UNKNOWN;
  KIND_IDENTIFIER    = Metamorf.Common.KIND_IDENTIFIER;
  KIND_INTEGER       = Metamorf.Common.KIND_INTEGER;
  KIND_FLOAT         = Metamorf.Common.KIND_FLOAT;
  KIND_STRING        = Metamorf.Common.KIND_STRING;
  KIND_CHAR          = Metamorf.Common.KIND_CHAR;
  KIND_COMMENT_LINE  = Metamorf.Common.KIND_COMMENT_LINE;
  KIND_COMMENT_BLOCK = Metamorf.Common.KIND_COMMENT_BLOCK;
  KIND_DIRECTIVE     = Metamorf.Common.KIND_DIRECTIVE;

  // Semantic attribute constants
  ATTR_TYPE_KIND       = Metamorf.Common.ATTR_TYPE_KIND;
  ATTR_RESOLVED_SYMBOL = Metamorf.Common.ATTR_RESOLVED_SYMBOL;
  ATTR_DECL_NODE       = Metamorf.Common.ATTR_DECL_NODE;
  ATTR_STORAGE_CLASS   = Metamorf.Common.ATTR_STORAGE_CLASS;
  ATTR_SCOPE_NAME      = Metamorf.Common.ATTR_SCOPE_NAME;
  ATTR_CALL_RESOLVED   = Metamorf.Common.ATTR_CALL_RESOLVED;
  ATTR_COERCE_TO       = Metamorf.Common.ATTR_COERCE_TO;

  // Build mode values
  bmExe          = Metamorf.Build.bmExe;
  bmLib          = Metamorf.Build.bmLib;
  bmDll          = Metamorf.Build.bmDll;

  // Optimize level values
  olDebug        = Metamorf.Build.olDebug;
  olReleaseSafe  = Metamorf.Build.olReleaseSafe;
  olReleaseFast  = Metamorf.Build.olReleaseFast;
  olReleaseSmall = Metamorf.Build.olReleaseSmall;

  // Target platform values
  tpWin64        = Metamorf.Build.tpWin64;
  tpLinux64      = Metamorf.Build.tpLinux64;

  // Subsystem type values
  stConsole      = Metamorf.Build.stConsole;
  stGUI          = Metamorf.Build.stGUI;

  // Error severity values
  esHint         = Metamorf.Utils.esHint;
  esWarning      = Metamorf.Utils.esWarning;
  esError        = Metamorf.Utils.esError;
  esFatal        = Metamorf.Utils.esFatal;

  // Source file values
  sfHeader       = Metamorf.Common.sfHeader;
  sfSource       = Metamorf.Common.sfSource;

  // Associativity values
  aoLeft         = Metamorf.Common.aoLeft;
  aoRight        = Metamorf.Common.aoRight;

type
  // ---- Type aliases --------------------------------------------------------
  // Every type a consumer needs is aliased here. Nobody touches internal units.

  // From System.Rtti
  TValue                     = System.Rtti.TValue;

  // From Metamorf.Utils
  TUtils                = Metamorf.Utils.TUtils;
  TErrorSeverity        = Metamorf.Utils.TErrorSeverity;
  TError                = Metamorf.Utils.TError;
  TErrors               = Metamorf.Utils.TErrors;
  TStatusCallback       = Metamorf.Utils.TStatusCallback;
  TCaptureConsoleCallback = Metamorf.Utils.TCaptureConsoleCallback;
  TOutputObject         = Metamorf.Utils.TOutputObject;

  // From Metamorf.Build
  TBuildMode            = Metamorf.Build.TBuildMode;
  TOptimizeLevel        = Metamorf.Build.TOptimizeLevel;
  TTargetPlatform       = Metamorf.Build.TTargetPlatform;
  TSubsystemType        = Metamorf.Build.TSubsystemType;

  // From Metamorf.Common — records and enums
  TToken                = Metamorf.Common.TToken;
  TAssociativity        = Metamorf.Common.TAssociativity;
  TSourceFile           = Metamorf.Common.TSourceFile;

  // From Metamorf.Common — base classes and concrete AST node
  TASTNodeBase          = Metamorf.Common.TASTNodeBase;
  TASTNode              = Metamorf.Common.TASTNode;
  TParserBase           = Metamorf.Common.TParserBase;
  TIRBase               = Metamorf.Common.TIRBase;
  TSemanticBase         = Metamorf.Common.TSemanticBase;

  // From Metamorf.Common — handler types
  TStatementHandler     = Metamorf.Common.TStatementHandler;
  TPrefixHandler        = Metamorf.Common.TPrefixHandler;
  TInfixHandler         = Metamorf.Common.TInfixHandler;
  TEmitHandler          = Metamorf.Common.TEmitHandler;
  TSemanticHandler      = Metamorf.Common.TSemanticHandler;
  TTypeCompatFunc       = Metamorf.Common.TTypeCompatFunc;

  // From Metamorf.LangConfig
  TNameMangler          = Metamorf.LangConfig.TNameMangler;
  TTypeToIR             = Metamorf.LangConfig.TTypeToIR;
  TExprToStringFunc     = Metamorf.Common.TExprToStringFunc;
  TExprOverride         = Metamorf.Common.TExprOverride;
  TLangConfig           = Metamorf.LangConfig.TLangConfig;

  { TMetamorf }
  TMetamorf = class(TOutputObject)
  private
    // Configuration
    FSourceFile:    string;
    FOutputPath:    string;
    FSourceFiles:   TList<string>;

    FTargetPlatform: TTargetPlatform;
    FSubsystem:     TSubsystemType;
    FOptimizeLevel: TOptimizeLevel;
    FBuildMode:     TBuildMode;

    // Version info / post-build resources
    FAddVersionInfo: Boolean;
    FVIMajor:        Word;
    FVIMinor:        Word;
    FVIPatch:        Word;
    FVIProductName:  string;
    FVIDescription:  string;
    FVIFilename:     string;
    FVICompanyName:  string;
    FVICopyright:    string;
    FExeIcon:        string;

    FRawOutput:        Boolean;
    FLineDirectives:   Boolean;

    // Owned components
    FConfig:     TLangConfig;
    FOwnsConfig: Boolean;
    FBuild:      TBuild;
    FErrors:     TErrors;

    // State
    FProject: TASTNode;

    // Internal helpers
    function GetConfigPath(): string;
    function GetGeneratedPath(): string;

    {$HINTS OFF}
    function ResolvePath(const APath: string): string;
    {$HINTS ON}

    procedure ApplyPostBuildResources(const AExePath: string);

  protected
    FIncludePaths:  TList<string>;
    FLibraryPaths:  TList<string>;
    FLinkLibraries: TList<string>;
    FCopyDLLs:      TList<string>;
    FParsedModules: TStringList;
  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Language definition — returns the owned config for fluent API access
    function Config(): TLangConfig;
    procedure SetConfig(const AConfig: TLangConfig);

    // Config persistence — uses FOutputPath/config/lang.toml
    procedure SaveLangConfig();
    procedure LoadLangConfig();

    // Source and output configuration
    procedure SetSourceFile(const AFilename: string);
    function  GetSourceFile(): string;
    procedure SetOutputPath(const APath: string);
    function  GetOutputPath(): string;

    // Source files
    procedure AddSourceFile(const ASourceFile: string);
    procedure ClearSourceFiles();
    // Include paths
    procedure AddIncludePath(const APath: string);
    procedure ClearIncludePaths();
    // Library paths
    procedure AddLibraryPath(const APath: string);
    procedure ClearLibraryPaths();
    // Link libraries
    procedure AddLinkLibrary(const ALibrary: string);
    procedure ClearLinkLibraries();
    // Defines
    procedure SetDefine(const ADefineName: string); overload;
    procedure SetDefine(const ADefineName, AValue: string); overload;
    procedure ClearDefines();
    function  HasDefine(const ADefineName: string): Boolean;
    function  GetDefines(): TStringList;
    // Undefines
    procedure UnsetDefine(const ADefineName: string);
    procedure ClearUndefines();
    function  HasUndefine(const ADefineName: string): Boolean;
    function  GetUndefines(): TStringList;
    // Copy DLLs
    procedure AddCopyDLL(const ADLLPath: string);
    procedure ClearCopyDLLs();

    // Build configuration
    procedure SetTargetPlatform(const APlatform: TTargetPlatform);
    function  GetTargetPlatform(): TTargetPlatform;
    procedure SetOptimizeLevel(const ALevel: TOptimizeLevel);
    function  GetOptimizeLevel(): TOptimizeLevel;
    procedure SetSubsystem(const ASubsystem: TSubsystemType);
    function  GetSubsystem(): TSubsystemType;
    procedure SetBuildMode(const ABuildMode: TBuildMode);
    function  GetBuildMode(): TBuildMode;

    // Version info / post-build resources
    procedure SetAddVersionInfo(const AValue: Boolean);
    function  GetAddVersionInfo(): Boolean;
    procedure SetVIMajor(const AValue: Word);
    function  GetVIMajor(): Word;
    procedure SetVIMinor(const AValue: Word);
    function  GetVIMinor(): Word;
    procedure SetVIPatch(const AValue: Word);
    function  GetVIPatch(): Word;
    procedure SetVIProductName(const AValue: string);
    function  GetVIProductName(): string;
    procedure SetVIDescription(const AValue: string);
    function  GetVIDescription(): string;
    procedure SetVIFilename(const AValue: string);
    function  GetVIFilename(): string;
    procedure SetVICompanyName(const AValue: string);
    function  GetVICompanyName(): string;
    procedure SetVICopyright(const AValue: string);
    function  GetVICopyright(): string;
    procedure SetExeIcon(const AValue: string);
    function  GetExeIcon(): string;

    // Callbacks
    procedure SetRawOutput(const AValue: Boolean);
    procedure SetLineDirectives(const AEnabled: Boolean);
    function  GetLineDirectives(): Boolean;
    procedure SetStatusCallback(const ACallback: TStatusCallback; const AUserData: Pointer = nil); override;

    // Error handling
    function  GetErrors(): TErrors;
    function  HasErrors(): Boolean;
    procedure ShowErrors();


    // Pipeline

    // Virtual factory for child compilers. Override in language subclasses
    // so that CompileModule creates a fully configured child (with its own
    // TLangConfig and closures) instead of a bare TMetamorf with shared config.
    function  CreateChild(): TMetamorf; virtual;

    function  CompileModule(const AModuleName: string): Boolean;
    function  CompileImportedModules(): Boolean; virtual;
    function  Compile(const ABuild: Boolean = True; const AAutoRun: Boolean = True): Boolean;
    function  Run(): Cardinal;
    procedure Clear();

    // Results
    function  GetProject(): TASTNode;
    function  GetOutputFilename(): string;
    function  GetLastExitCode(): Cardinal;
    function  GetVersionStr(): string;
  end;

implementation


{$R Metamorf.ResData.res}

const
  LANG_CONFIG_FILENAME = 'lang.toml';
  CONFIG_DIR_NAME      = 'config';
  GENERATED_DIR_NAME   = 'generated';

{ TMetamorf }

constructor TMetamorf.Create();
begin
  inherited;

  FSourceFile    := '';
  FOutputPath    := '';
  FTargetPlatform := tpWin64;
  FOptimizeLevel := olDebug;
  FSubsystem     := stConsole;
  FBuildMode     := bmExe;

  FAddVersionInfo := False;
  FVIMajor        := 0;
  FVIMinor        := 0;
  FVIPatch        := 0;
  FVIProductName  := '';
  FVIDescription  := '';
  FVIFilename     := '';
  FVICompanyName  := '';
  FVICopyright    := '';
  FExeIcon        := '';

  FRawOutput      := False;
  FLineDirectives := False;

  FIncludePaths  := TList<string>.Create();
  FSourceFiles   := TList<string>.Create();
  FLibraryPaths  := TList<string>.Create();
  FLinkLibraries := TList<string>.Create();
  FCopyDLLs      := TList<string>.Create();

  FBuild  := TBuild.Create();
  FConfig := TLangConfig.Create();
  FOwnsConfig := True;

  // Universal delimiters — needed by any language surface
  FConfig
    .AddOperator(':',   'delimiter.colon')
    .AddOperator(';',   'delimiter.semicolon')
    .AddOperator(',',   'delimiter.comma')
    .AddOperator('.',   'delimiter.dot')
    .AddOperator('(',   'delimiter.lparen')
    .AddOperator(')',   'delimiter.rparen')
    .AddOperator('[',   'delimiter.lbracket')
    .AddOperator(']',   'delimiter.rbracket');

  FErrors := TErrors.Create();
  FProject := nil;
  FParsedModules := TStringList.Create();
  FParsedModules.CaseSensitive := True;

  // Wire mor runtime include path and source
  AddIncludePath('res/runtime');
  AddSourceFile('res/runtime/mor_runtime.cpp');
end;

destructor TMetamorf.Destroy();
begin
  Clear();

  if FOwnsConfig then
    FreeAndNil(FConfig);
  FreeAndNil(FBuild);
  FreeAndNil(FIncludePaths);
  FreeAndNil(FSourceFiles);
  FreeAndNil(FLibraryPaths);
  FreeAndNil(FLinkLibraries);
  FreeAndNil(FCopyDLLs);
  FreeAndNil(FParsedModules);
  FreeAndNil(FErrors);

  inherited Destroy();
end;

// Internal helpers

function TMetamorf.GetConfigPath(): string;
begin
  Result := TPath.Combine(FOutputPath, CONFIG_DIR_NAME);
end;

function TMetamorf.GetGeneratedPath(): string;
begin
  Result := TPath.Combine(FOutputPath, GENERATED_DIR_NAME);
end;

function TMetamorf.ResolvePath(const APath: string): string;
begin
  // If already absolute, return as-is; otherwise resolve relative to source file
  if TPath.IsPathRooted(APath) then
    Result := APath
  else if FSourceFile <> '' then
    Result := TPath.Combine(TPath.GetDirectoryName(FSourceFile), APath)
  else
    Result := TPath.GetFullPath(APath);
end;

// Post-build resources

procedure TMetamorf.ApplyPostBuildResources(const AExePath: string);
var
  LIsExe: Boolean;
  LIsDll: Boolean;
begin
  LIsExe := AExePath.EndsWith('.exe', True);
  LIsDll := AExePath.EndsWith('.dll', True);
  if not LIsExe and not LIsDll then Exit;
  if LIsExe then
  begin
    if TUtils.ResourceExist('EXE_MANIFEST') then
      if not TUtils.AddResManifestFromResource('EXE_MANIFEST', AExePath) then
        FErrors.Add(esWarning, 'W980',
          'Failed to add manifest to executable', []);
  end;
  if LIsExe and (FExeIcon <> '') then
  begin
    if TFile.Exists(FExeIcon) then
      TUtils.UpdateIconResource(AExePath, FExeIcon)
    else
      FErrors.Add(esWarning, 'W982',
        'Icon file not found: %s', [FExeIcon]);
  end;
  if FAddVersionInfo then
    TUtils.UpdateVersionInfoResource(AExePath,
      FVIMajor, FVIMinor, FVIPatch, FVIProductName,
      FVIDescription, FVIFilename, FVICompanyName, FVICopyright);
end;

// Language definition

function TMetamorf.Config(): TLangConfig;
begin
  Result := FConfig;
end;

procedure TMetamorf.SetConfig(const AConfig: TLangConfig);
begin
  if FOwnsConfig and (FConfig <> AConfig) then
    FreeAndNil(FConfig);
  FConfig := AConfig;
  FOwnsConfig := False;
end;

// Config persistence

procedure TMetamorf.SaveLangConfig();
var
  LConfigPath: string;
begin
  if FOutputPath = '' then
    Exit;

  LConfigPath := GetConfigPath();
  TDirectory.CreateDirectory(LConfigPath);

  FConfig.SetConfigFilename(TPath.Combine(LConfigPath, LANG_CONFIG_FILENAME));
  FConfig.SaveConfig();
end;

procedure TMetamorf.LoadLangConfig();
var
  LConfigFile: string;
begin
  if FOutputPath = '' then
    Exit;

  LConfigFile := TPath.Combine(GetConfigPath(), LANG_CONFIG_FILENAME);
  if not TFile.Exists(LConfigFile) then
    Exit;

  FConfig.SetConfigFilename(LConfigFile);
  FConfig.LoadConfig();
end;

// Virtual factory for child compilers

function TMetamorf.CreateChild(): TMetamorf;
begin
  Result := TMetamorf.Create();
end;

// Virtual hook for language-specific module compilation

function TMetamorf.CompileModule(const AModuleName: string): Boolean;
var
  LModuleFile:   string;
  LChild:        TMetamorf;
  LGeneratedCpp: string;
  LSearchPath:   string;
  LEntry:        string;
  LEqualPos:     Integer;
  LI:            Integer;
  LExt:          string;
begin
  Result := False;

  // Already compiled — skip
  if FParsedModules.IndexOf(AModuleName) >= 0 then
  begin
    Result := True;
    Exit;
  end;

  // Mark as being compiled (cycle detection)
  FParsedModules.Add(AModuleName);

  // Resolve file path: source dir first, then include paths
  LExt := FConfig.GetModuleExtension();
  LModuleFile := TPath.Combine(
    TPath.GetDirectoryName(FSourceFile),
    TPath.ChangeExtension(AModuleName, LExt));

  if not TFile.Exists(LModuleFile) then
  begin
    LModuleFile := '';
    for LSearchPath in FIncludePaths do
    begin
      LModuleFile := TPath.Combine(LSearchPath,
        TPath.ChangeExtension(AModuleName, LExt));
      if TFile.Exists(LModuleFile) then
        Break;
      LModuleFile := '';
    end;
  end;

  if LModuleFile = '' then
  begin
    FErrors.Add(esError, ERR_COMPILER_MODULE_NOT_FOUND,
      RSCompilerModuleNotFound,
      [TPath.ChangeExtension(AModuleName, LExt)]);
    Exit;
  end;

  // Compile the module: codegen only, no build/run.
  // CreateChild() returns a fully configured compiler (with its own
  // TLangConfig and closures) so child compilation cannot mutate the parent.
  LChild := CreateChild();
  try
    // Share language config with child so it has the full lexer/parser/emitter
    // surface. For subclasses like TMyraCompiler, CreateChild() already
    // populates an identical config; sharing the parent's is equivalent.
    // For plain TMetamorf (the .mor path), the child would otherwise have
    // an empty config and fail to lex comments, keywords, etc.
    LChild.SetConfig(Self.FConfig);
    LChild.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
    LChild.SetSourceFile(LModuleFile);
    LChild.SetOutputPath(FOutputPath);
    LChild.SetBuildMode(bmLib);
    LChild.SetTargetPlatform(GetTargetPlatform());
    LChild.SetOptimizeLevel(GetOptimizeLevel());
    LChild.SetSubsystem(GetSubsystem());
    LChild.SetLineDirectives(GetLineDirectives());

    // Share defines and undefines
    for LI := 0 to GetDefines().Count - 1 do
    begin
      LEntry := GetDefines()[LI];
      LEqualPos := Pos('=', LEntry);
      if LEqualPos > 0 then
        LChild.SetDefine(
          Copy(LEntry, 1, LEqualPos - 1),
          Copy(LEntry, LEqualPos + 1, Length(LEntry)))
      else
        LChild.SetDefine(LEntry);
    end;
    for LI := 0 to GetUndefines().Count - 1 do
      LChild.UnsetDefine(GetUndefines()[LI]);

    // Share include paths
    for LSearchPath in FIncludePaths do
      LChild.AddIncludePath(LSearchPath);

    // Share parsed-modules list for cross-instance cycle detection
    LChild.FParsedModules.Free();
    LChild.FParsedModules := FParsedModules;

    // Compile child (codegen only — no build, no run)
    LChild.Compile(False, False);

    // Propagate build settings back to parent
    for LSearchPath in LChild.FIncludePaths do
      AddIncludePath(LSearchPath);
    for LSearchPath in LChild.FLibraryPaths do
      AddLibraryPath(LSearchPath);
    for LSearchPath in LChild.FLinkLibraries do
      AddLinkLibrary(LSearchPath);
    for LSearchPath in LChild.FCopyDLLs do
      AddCopyDLL(LSearchPath);

    // Relay all errors to parent
    for LI := 0 to LChild.GetErrors().Count() - 1 do
      GetErrors().Add(
        LChild.GetErrors().GetItems()[LI].Range,
        LChild.GetErrors().GetItems()[LI].Severity,
        LChild.GetErrors().GetItems()[LI].Code,
        LChild.GetErrors().GetItems()[LI].Message);

    // Detach shared list before freeing child
    LChild.FParsedModules := nil;

    if LChild.HasErrors() then
      Exit;

    // Add module's generated .cpp to the main build
    LGeneratedCpp := TPath.Combine(FOutputPath,
      TPath.Combine('generated', AModuleName + '.cpp'));
    AddSourceFile(LGeneratedCpp);

    // Add generated path to include paths for the header
    AddIncludePath(TPath.Combine(FOutputPath, 'generated'));

    Result := True;
  finally
    if LChild.FParsedModules = FParsedModules then
      LChild.FParsedModules := nil;
    LChild.Free();
  end;
end;

function TMetamorf.CompileImportedModules(): Boolean;
begin
  Result := True;
end;

// Source and output configuration

procedure TMetamorf.SetSourceFile(const AFilename: string);
begin
  FSourceFile := AFilename;
end;

function TMetamorf.GetSourceFile(): string;
begin
  Result := FSourceFile;
end;

procedure TMetamorf.SetOutputPath(const APath: string);
begin
  FOutputPath := APath;
end;

function TMetamorf.GetOutputPath(): string;
begin
  Result := FOutputPath;
end;

// Source files

procedure TMetamorf.AddSourceFile(const ASourceFile: string);
begin
  if (ASourceFile <> '') and (FSourceFiles.IndexOf(ASourceFile) < 0) then
    FSourceFiles.Add(ASourceFile);
end;

procedure TMetamorf.ClearSourceFiles();
begin
  FSourceFiles.Clear();
  if FBuild <> nil then
    FBuild.ClearSourceFiles();
end;

// Include paths

procedure TMetamorf.AddIncludePath(const APath: string);
begin
  if (APath <> '') and (FIncludePaths.IndexOf(APath) < 0) then
    FIncludePaths.Add(APath);
end;

procedure TMetamorf.ClearIncludePaths();
begin
  FIncludePaths.Clear();
  if FBuild <> nil then
    FBuild.ClearIncludePaths();
end;

// Library paths

procedure TMetamorf.AddLibraryPath(const APath: string);
begin
  if (APath <> '') and (FLibraryPaths.IndexOf(APath) < 0) then
    FLibraryPaths.Add(APath);
end;

procedure TMetamorf.ClearLibraryPaths();
begin
  FLibraryPaths.Clear();
  if FBuild <> nil then
    FBuild.ClearLibraryPaths();
end;

// Link libraries

procedure TMetamorf.AddLinkLibrary(const ALibrary: string);
begin
  if (ALibrary <> '') and (FLinkLibraries.IndexOf(ALibrary) < 0) then
    FLinkLibraries.Add(ALibrary);
end;

procedure TMetamorf.ClearLinkLibraries();
begin
  FLinkLibraries.Clear();
  if FBuild <> nil then
    FBuild.ClearLinkLibraries();
end;

// Defines

procedure TMetamorf.SetDefine(const ADefineName: string);
begin
  if ADefineName <> '' then
    FBuild.SetDefine(ADefineName);
end;

procedure TMetamorf.SetDefine(const ADefineName, AValue: string);
begin
  if ADefineName <> '' then
    FBuild.SetDefine(ADefineName, AValue);
end;

procedure TMetamorf.ClearDefines();
begin
  FBuild.ClearDefines();
end;

function TMetamorf.HasDefine(const ADefineName: string): Boolean;
begin
  Result := FBuild.HasDefine(ADefineName);
end;

function TMetamorf.GetDefines(): TStringList;
begin
  Result := FBuild.GetDefines();
end;

// Undefines

procedure TMetamorf.UnsetDefine(const ADefineName: string);
begin
  if ADefineName <> '' then
    FBuild.UnsetDefine(ADefineName);
end;

procedure TMetamorf.ClearUndefines();
begin
  FBuild.ClearUndefines();
end;

function TMetamorf.HasUndefine(const ADefineName: string): Boolean;
begin
  Result := FBuild.HasUndefine(ADefineName);
end;

function TMetamorf.GetUndefines(): TStringList;
begin
  Result := FBuild.GetUndefines();
end;

// Copy DLLs

procedure TMetamorf.AddCopyDLL(const ADLLPath: string);
begin
  if (ADLLPath <> '') and (FCopyDLLs.IndexOf(ADLLPath) < 0) then
  begin
    FCopyDLLs.Add(ADLLPath);
    if FBuild <> nil then
      FBuild.AddCopyDLL(ADLLPath);
  end;
end;

procedure TMetamorf.ClearCopyDLLs();
begin
  FCopyDLLs.Clear();
  if FBuild <> nil then
    FBuild.ClearCopyDLLs();
end;

// Build configuration

procedure TMetamorf.SetTargetPlatform(const APlatform: TTargetPlatform);
begin
  FTargetPlatform := APlatform;
  if FBuild <> nil then
    FBuild.SetTarget(APlatform);
end;

function TMetamorf.GetTargetPlatform(): TTargetPlatform;
begin
  if FBuild <> nil then
    Result := FBuild.GetTarget()
  else
    Result := FTargetPlatform;
end;

procedure TMetamorf.SetOptimizeLevel(const ALevel: TOptimizeLevel);
begin
  FOptimizeLevel := ALevel;
end;

function TMetamorf.GetOptimizeLevel(): TOptimizeLevel;
begin
  Result := FOptimizeLevel;
end;

procedure TMetamorf.SetSubsystem(const ASubsystem: TSubsystemType);
begin
  FSubsystem := ASubsystem;
  if FBuild <> nil then
    FBuild.SetSubsystem(ASubsystem);
end;

function TMetamorf.GetSubsystem(): TSubsystemType;
begin
  if FBuild <> nil then
    Result := FBuild.GetSubsystem()
  else
    Result := FSubsystem;
end;

procedure TMetamorf.SetBuildMode(const ABuildMode: TBuildMode);
begin
  FBuildMode := ABuildMode;
  if FBuild <> nil then
    FBuild.SetBuildMode(ABuildMode);
end;

function TMetamorf.GetBuildMode(): TBuildMode;
begin
  if FBuild <> nil then
    Result := FBuild.GetBuildMode()
  else
    Result := FBuildMode;
end;

// Version info / post-build resources

procedure TMetamorf.SetAddVersionInfo(const AValue: Boolean);
begin
  FAddVersionInfo := AValue;
end;

function TMetamorf.GetAddVersionInfo(): Boolean;
begin
  Result := FAddVersionInfo;
end;

procedure TMetamorf.SetVIMajor(const AValue: Word);
begin
  FVIMajor := AValue;
end;

function TMetamorf.GetVIMajor(): Word;
begin
  Result := FVIMajor;
end;

procedure TMetamorf.SetVIMinor(const AValue: Word);
begin
  FVIMinor := AValue;
end;

function TMetamorf.GetVIMinor(): Word;
begin
  Result := FVIMinor;
end;

procedure TMetamorf.SetVIPatch(const AValue: Word);
begin
  FVIPatch := AValue;
end;

function TMetamorf.GetVIPatch(): Word;
begin
  Result := FVIPatch;
end;

procedure TMetamorf.SetVIProductName(const AValue: string);
begin
  FVIProductName := AValue;
end;

function TMetamorf.GetVIProductName(): string;
begin
  Result := FVIProductName;
end;

procedure TMetamorf.SetVIDescription(const AValue: string);
begin
  FVIDescription := AValue;
end;

function TMetamorf.GetVIDescription(): string;
begin
  Result := FVIDescription;
end;

procedure TMetamorf.SetVIFilename(const AValue: string);
begin
  FVIFilename := AValue;
end;

function TMetamorf.GetVIFilename(): string;
begin
  Result := FVIFilename;
end;

procedure TMetamorf.SetVICompanyName(const AValue: string);
begin
  FVICompanyName := AValue;
end;

function TMetamorf.GetVICompanyName(): string;
begin
  Result := FVICompanyName;
end;

procedure TMetamorf.SetVICopyright(const AValue: string);
begin
  FVICopyright := AValue;
end;

function TMetamorf.GetVICopyright(): string;
begin
  Result := FVICopyright;
end;

procedure TMetamorf.SetExeIcon(const AValue: string);
begin
  FExeIcon := AValue;
end;

function TMetamorf.GetExeIcon(): string;
begin
  Result := FExeIcon;
end;

// Callbacks

procedure TMetamorf.SetRawOutput(const AValue: Boolean);
begin
  FRawOutput := AValue;
end;

procedure TMetamorf.SetLineDirectives(const AEnabled: Boolean);
begin
  FLineDirectives := AEnabled;
end;

function TMetamorf.GetLineDirectives(): Boolean;
begin
  Result := FLineDirectives;
end;

procedure TMetamorf.SetStatusCallback(const ACallback: TStatusCallback; const AUserData: Pointer);
begin
  inherited SetStatusCallback(ACallback, AUserData);
  if FBuild <> nil then
    FBuild.SetStatusCallback(ACallback, AUserData);
end;

// Error handling
function TMetamorf.GetErrors(): TErrors;
begin
  Result := FErrors;
end;

function TMetamorf.HasErrors(): Boolean;
begin
  Result := (FErrors <> nil) and (FErrors.ErrorCount > 0);
end;

procedure TMetamorf.ShowErrors();
var
  LError: TError;
begin
  if not HasErrors() then Exit;

  TUtils.PrintLn('');
  TUtils.PrintLn('--- Errors ---');
  for LError in GetErrors().GetItems() do
  begin
    case LError.Severity of
      esHint:
        TUtils.PrintLn(COLOR_CYAN   + '  ' + LError.ToFullString());
      esWarning:
        TUtils.PrintLn(COLOR_YELLOW + '  ' + LError.ToFullString());
      esError:
        TUtils.PrintLn(COLOR_RED    + '  ' + LError.ToFullString());
      esFatal:
        TUtils.PrintLn(COLOR_CYAN   + '  ' + LError.ToFullString());
    end;
  end;
end;

// Pipeline

procedure TMetamorf.Clear();
begin
  FreeAndNil(FProject);

  if FErrors <> nil then
    FErrors.Clear();
end;

function TMetamorf.Compile(const ABuild: Boolean; const AAutoRun: Boolean): Boolean;
var
  LLexer:         TLexer;
  LParser:        TParser;
  LSemantics:     TSemantics;
  LCodeGen:       TCodeGen;
  LGeneratedPath: string;
  LProjectName:   string;
  LPath:          string;
begin
  Result := False;
  Clear();

  // Validate source file
  if FSourceFile = '' then
  begin
    if FErrors <> nil then
      FErrors.Add(esError, ERR_COMPILER_NO_SOURCE, RSCompilerNoSource, []);
    Exit;
  end;

  if not TFile.Exists(FSourceFile) then
  begin
    if FErrors <> nil then
      FErrors.Add(esError, ERR_COMPILER_NO_SOURCE,
        RSCompilerSourceNotFound, [TUtils.NormalizePath(TPath.GetFullPath(FSourceFile))]);
    Exit;
  end;

  // Default output path to source file directory if not set
  if FOutputPath = '' then
    FOutputPath := TPath.GetDirectoryName(FSourceFile);

  Status('Compiling %s', [TUtils.NormalizePath(TPath.GetFullPath(FSourceFile))]);

  // Configure build for this compilation
  FBuild.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
  FBuild.SetErrors(FErrors);
  FBuild.SetTarget(FTargetPlatform);
  FBuild.SetOptimizeLevel(FOptimizeLevel);
  FBuild.SetSubsystem(FSubsystem);
  FBuild.SetBuildMode(FBuildMode);

  // Set subsystem defines so $ifdef works
  if FSubsystem = stGUI then
  begin
    FBuild.RemoveDefine('CONSOLE_APP');
    FBuild.SetDefine('GUI_APP');
  end
  else
  begin
    FBuild.RemoveDefine('GUI_APP');
    FBuild.SetDefine('CONSOLE_APP');
  end;

  // Add generated path to include paths
  AddIncludePath(GetGeneratedPath());

  // Step 1: Lexer
  LLexer := TLexer.Create();
  try
    LLexer.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
    LLexer.SetErrors(FErrors);
    LLexer.SetConfig(FConfig);
    LLexer.SetBuild(FBuild);

    if not LLexer.LoadFromFile(FSourceFile) then
      Exit;

    if not LLexer.Tokenize() then
      Exit;

    // Step 2: Parser
    LParser := TParser.Create();
    try
      LParser.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
      LParser.SetErrors(FErrors);
      LParser.SetConfig(FConfig);

      if not LParser.LoadFromLexer(LLexer) then
        Exit;

      FProject := LParser.ParseTokens();
      if FProject = nil then
        Exit;

      if HasErrors() then
        Exit;

    finally
      LParser.Free();
    end;
  finally
    LLexer.Free();
  end;

  // Step 3: Semantic analysis
  LSemantics := TSemantics.Create();
  try
    LSemantics.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
    LSemantics.SetErrors(FErrors);
    LSemantics.SetConfig(FConfig);
    LSemantics.SetCompileModule(
      function(AName: string): Boolean
      begin
        Result := Self.CompileModule(AName);
      end);

    if not LSemantics.Analyze(FProject) then
      Exit;

    if HasErrors() then
      Exit;

    // Compile all imported module dependencies (AST-driven, after semantics)
    if not CompileImportedModules() then
      Exit;

    // Step 4: Code generation
    LGeneratedPath := GetGeneratedPath();
    TDirectory.CreateDirectory(LGeneratedPath);

    LCodeGen := TCodeGen.Create();
    try
      LCodeGen.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
      LCodeGen.SetErrors(FErrors);
      LCodeGen.SetConfig(FConfig);
      LCodeGen.SetLineDirectives(FLineDirectives);

      if not LCodeGen.Generate(FProject) then
        Exit;

      // Save generated .h/.cpp to output/generated/
      LProjectName := TPath.GetFileNameWithoutExtension(FSourceFile);
      LCodeGen.SaveToFiles(
        TPath.Combine(LGeneratedPath, LProjectName + '.h'),
        TPath.Combine(LGeneratedPath, LProjectName + '.cpp')
      );
    finally
      LCodeGen.Free();
    end;
  finally
    LSemantics.Free();
  end;

  // Check for codegen errors before building
  if HasErrors() then
    Exit;

  // Skip Zig build if caller only wants codegen (e.g. compiling a unit dependency)
  if not ABuild then
  begin
    Result := True;
    Exit;
  end;

  // Step 5: Build via Zig
  FBuild.SetOutputCallback(FOutput.Callback, FOutput.UserData);
  FBuild.SetRawOutput(FRawOutput);
  FBuild.SetOutputPath(FOutputPath);
  FBuild.SetProjectName(LProjectName);

  // Add generated source to build
  FBuild.AddSourceFile(TPath.Combine(LGeneratedPath, LProjectName + '.cpp'));
  FBuild.AddIncludePath(LGeneratedPath);

  // Wire configured paths into build
  for LPath in FIncludePaths do
    FBuild.AddIncludePath(LPath);

  for LPath in FSourceFiles do
    FBuild.AddSourceFile(LPath);

  for LPath in FLibraryPaths do
    FBuild.AddLibraryPath(LPath);

  for LPath in FLinkLibraries do
    FBuild.AddLinkLibrary(LPath);

  // Wire copy DLLs into build
  for LPath in FCopyDLLs do
    FBuild.AddCopyDLL(LPath);

  // Sync build settings — FBuild is ground truth for target/subsystem
  // (set by lexer directive callbacks). Read them back into local fields.
  // OptimizeLevel/BuildMode still flow from TMetamorf into FBuild.
  FTargetPlatform := FBuild.GetTarget();
  FSubsystem := FBuild.GetSubsystem();
  FBuild.SetOptimizeLevel(FOptimizeLevel);
  FBuild.SetBuildMode(FBuildMode);

  // Generate build.zig and compile
  if not FBuild.SaveBuildFile() then
  begin
    Status('Failed to create build.zig');
    Exit;
  end;

  if not FBuild.Process(False) then
    Exit;

  // Post-build: apply manifest, icon, version info
  ApplyPostBuildResources(
    TPath.Combine(FOutputPath, 'zig-out/bin/' + GetOutputFilename()));

  // Run only if requested
  if AAutoRun then
  begin
    if not FBuild.Run() then
      Exit;
  end;

  Result := True;
end;

function TMetamorf.Run(): Cardinal;
begin
  Result := 0;
  if FBuild <> nil then
  begin
    FBuild.Run();
    Result := FBuild.GetLastExitCode();
  end;
end;

// Results

function TMetamorf.GetProject(): TASTNode;
begin
  Result := FProject;
end;

function TMetamorf.GetOutputFilename(): string;
begin
  Result := '';
  if FBuild <> nil then
    Result := FBuild.GetOutputFilename();
end;

function TMetamorf.GetLastExitCode(): Cardinal;
begin
  Result := 0;
  if FBuild <> nil then
    Result := FBuild.GetLastExitCode();
end;

function TMetamorf.GetVersionStr(): string;
begin
  Result := METAMORF_VERSION_STR;
end;

end.
