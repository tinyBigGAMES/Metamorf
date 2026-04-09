{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.EngineAPI;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.AST,
  Metamorf.Engine,
  Metamorf.Interpreter,
  Metamorf.Lexer,
  Metamorf.Parser,
  Metamorf.Scopes,
  Metamorf.CodeGen;

const
  // EngineAPI Error Codes (EA001-EA099)
  MOR_ERR_ENGINEAPI_MOR_NOT_LOADED = 'EA001';
  MOR_ERR_ENGINEAPI_SRC_NOT_PARSED = 'EA002';
  MOR_ERR_ENGINEAPI_SEM_NOT_RUN    = 'EA003';
  MOR_ERR_ENGINEAPI_EMIT_NOT_RUN   = 'EA004';

  // Run mode constants for DLL surface
  MOR_RUN_NONE    = 0;
  MOR_RUN_EXECUTE = 1;
  MOR_RUN_DEBUG   = 2;

type

  { Callback types for DLL consumers }
  TMorStatusProc = procedure(const AMessage: PUTF8Char;
    const AUserData: Pointer);

  TMorEmitProc = procedure(const ANodeHandle: UInt64;
    const AUserData: Pointer);

  TMorOutputProc = procedure(const ALine: PUTF8Char;
    const AUserData: Pointer);

  { TMorEngineAPI }
  TMorEngineAPI = class(TMorBaseObject)
  private
    FEngine: TMorEngine;
    FLastResultUTF8: UTF8String;

    // .mor lexer/parser (owned, for LoadMor and imports)
    FMorLexer: TMorLexer;
    FMorParser: TMorParser;
    FMorMasterRoot: TMorASTNode;
    FImportedMorFiles: TDictionary<string, Boolean>;
    FMorFileDir: string;

    // Stepped pipeline state
    FMasterRoot: TMorASTNode;
    FScopes: TScopeManager;
    FOutput: TMorCodeOutput;
    FProcessedFiles: TDictionary<string, Boolean>;
    FSourceDir: string;
    FOutputPath: string;
    FMorLoaded: Boolean;
    FSourceParsed: Boolean;
    FSemanticsRun: Boolean;
    FEmittersRun: Boolean;

    // External callback registrations
    FStatusProc: TMorStatusProc;
    FStatusUserData: Pointer;
    FOutputProc: TMorOutputProc;
    FOutputUserData: Pointer;

    // UTF-8 return helper
    {$HINTS OFF}
    function ReturnUTF8(const AValue: string): PUTF8Char;
    {$HINTS ON}

    // Internal status/output forwarding
    procedure OnEngineStatus(const AMessage: string);
    procedure OnBuildOutput(const ALine: string);

    // Module compilation callback (called by interpreter during semantics)
    function CompileModule(const AModuleName: string): Boolean;

    // .mor import callback (called by interpreter during setup)
    function ImportMorFile(const AMorPath: string): TMorASTNode;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Callback registration
    procedure SetStatusCallback(const AProc: TMorStatusProc;
      const AUserData: Pointer);
    procedure SetOutputCallback(const AProc: TMorOutputProc;
      const AUserData: Pointer);

    // Stepped pipeline
    function LoadMor(const AMorFile: string): Boolean;
    function ParseSource(const ASourceFile: string): Boolean;
    function RunSemantics(): Boolean;
    function RunEmitters(): Boolean;
    function Build(const AOutputPath: string;
      const AAutoRun: Boolean = False): Boolean;

    // One-shot convenience (equivalent to TMorEngine.Compile)
    function CompileAll(const AMorFile: string;
      const ASourceFile: string; const AOutputPath: string;
      const AAutoRun: Boolean = False): Boolean;

    // Cleanup between compilations
    procedure Reset();

    // AST access (after ParseSource)
    function GetMasterRoot(): TMorASTNode;
    function GetInterpreter(): TMorInterpreter;
    function GetErrors(): TMorErrors;

    // Native emit handler registration (for external consumers)
    procedure RegisterEmitHandler(const ANodeKind: string;
      const AProc: TMorEmitProc; const AUserData: Pointer);

    // Debug: standalone post-build debug launch
    function DebugExe(const AExePath: string;
      const APort: Integer = 4711): Boolean;

    // Build configuration
    procedure SetTarget(const ATarget: Integer);
    function GetTarget(): Integer;
    procedure SetOptimizeLevel(const ALevel: Integer);
    function GetOptimizeLevel(): Integer;
    procedure SetSubsystem(const ASubsystem: Integer);
    function GetSubsystem(): Integer;
    procedure SetBuildMode(const AMode: Integer);
    function GetBuildMode(): Integer;
    procedure SetDefine(const ADefineName: string;
      const AValue: string = '');

    // Toolchain paths
    procedure SetToolchainPath(const APath: string);
    function GetToolchainPath(): string;
    function GetZigPath(const AFilename: string = ''): string;
    function GetRuntimePath(const AFilename: string = ''): string;
    function GetLibsPath(const AFilename: string = ''): string;
    function GetAssetsPath(const AFilename: string = ''): string;

    // Process/build control
    function GetLastExitCode(): Integer;

    // Advanced pipeline
    function SetupLanguage(const AMorFile: string): Boolean;
    procedure CompileBaked(const ASourceFile: string;
      const AOutputPath: string; const AAutoRun: Boolean);
  end;

implementation

uses
  System.IOUtils,
  System.Classes,
  Metamorf.Common,
  Metamorf.Resources,
  Metamorf.Build,
  Metamorf.Debug.Server,
  Metamorf.GenericLexer,
  Metamorf.GenericParser,
  Metamorf.Cpp;

{ TMorEngineAPI }

constructor TMorEngineAPI.Create();
begin
  inherited;

  FEngine := TMorEngine.Create();

  FMorLexer := TMorLexer.Create();
  FMorLexer.SetErrors(FEngine.GetErrors());

  FMorParser := TMorParser.Create();
  FMorParser.SetErrors(FEngine.GetErrors());

  FImportedMorFiles := TDictionary<string, Boolean>.Create();
  FProcessedFiles := TDictionary<string, Boolean>.Create();

  FMorLoaded := False;
  FSourceParsed := False;
  FSemanticsRun := False;
  FEmittersRun := False;

  // Wire engine status callback to forward to external consumer
  FEngine.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      OnEngineStatus(AText);
    end);
end;

destructor TMorEngineAPI.Destroy();
begin
  FreeAndNil(FMasterRoot);
  FreeAndNil(FScopes);
  FreeAndNil(FOutput);
  FreeAndNil(FMorMasterRoot);
  FreeAndNil(FProcessedFiles);
  FreeAndNil(FImportedMorFiles);
  FreeAndNil(FMorParser);
  FreeAndNil(FMorLexer);
  FreeAndNil(FEngine);

  inherited;
end;

function TMorEngineAPI.ReturnUTF8(const AValue: string): PUTF8Char;
begin
  FLastResultUTF8 := UTF8Encode(AValue);
  Result := PUTF8Char(FLastResultUTF8);
end;

procedure TMorEngineAPI.OnEngineStatus(const AMessage: string);
begin
  if Assigned(FStatusProc) then
  begin
    FLastResultUTF8 := UTF8Encode(AMessage);
    FStatusProc(PUTF8Char(FLastResultUTF8), FStatusUserData);
  end;
end;

procedure TMorEngineAPI.OnBuildOutput(const ALine: string);
begin
  if Assigned(FOutputProc) then
  begin
    FLastResultUTF8 := UTF8Encode(ALine);
    FOutputProc(PUTF8Char(FLastResultUTF8), FOutputUserData);
  end;
end;

procedure TMorEngineAPI.SetStatusCallback(const AProc: TMorStatusProc;
  const AUserData: Pointer);
begin
  FStatusProc := AProc;
  FStatusUserData := AUserData;
end;

procedure TMorEngineAPI.SetOutputCallback(const AProc: TMorOutputProc;
  const AUserData: Pointer);
begin
  FOutputProc := AProc;
  FOutputUserData := AUserData;
  // Wire to build output callback
  FEngine.SetOutputCallback(
    procedure(const ALine: string; const AUserData: Pointer)
    begin
      OnBuildOutput(ALine);
    end);
end;

function TMorEngineAPI.LoadMor(const AMorFile: string): Boolean;
var
  LMorFile: string;
  LMorSource: string;
  LMorTokens: TList<TMorToken>;
  LMorAST: TMorASTNode;
  LErrors: TMorErrors;
  LMorDisplay: string;
  LInterp: TMorInterpreter;
begin
  Result := False;
  LErrors := FEngine.GetErrors();
  LErrors.Clear();
  FImportedMorFiles.Clear();

  // Free previous .mor state if reloading
  FreeAndNil(FMorMasterRoot);
  FMorLoaded := False;
  FSourceParsed := False;
  FSemanticsRun := False;
  FEmittersRun := False;

  LMorFile := TPath.ChangeExtension(AMorFile, MOR_LANG_EXT);
  LMorDisplay := TMorUtils.DisplayPath(LMorFile);

  // Check .mor file exists
  if not TFile.Exists(LMorFile) then
  begin
    LErrors.Add(esFatal, MOR_ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LMorDisplay]);
    Exit;
  end;

  LMorSource := TFile.ReadAllText(LMorFile, TEncoding.UTF8);

  // Lex .mor source
  FEngine.Status(RSMorLexerTokenizing, [LMorDisplay]);
  LMorTokens := FMorLexer.Tokenize(LMorSource, LMorDisplay);
  if LErrors.HasErrors() then
  begin
    LMorTokens.Free();
    Exit;
  end;

  // Parse .mor source
  FEngine.Status(RSMorParserParsing, [LMorDisplay]);
  LMorAST := FMorParser.Parse(LMorTokens, LMorDisplay);
  LMorTokens.Free();
  if LErrors.HasErrors() then
  begin
    LMorAST.Free();
    Exit;
  end;

  // Setup interpreter tables
  FEngine.Status(RSMorInterpSetup);
  FMorFileDir := TPath.GetDirectoryName(TPath.GetFullPath(LMorFile));
  FImportedMorFiles.Add(TPath.GetFullPath(LMorFile), True);

  // Build .mor master root (owns all .mor ASTs including imports)
  FMorMasterRoot := TMorASTNode.Create();
  FMorMasterRoot.SetKind('mor.master');
  FMorMasterRoot.AddChild(LMorAST);

  LInterp := FEngine.GetInterpreter();
  LInterp.SetImportMorFunc(ImportMorFile);
  LInterp.RunSetup(LMorAST);
  LInterp.SetImportMorFunc(nil);
  if LErrors.HasErrors() then
    Exit;

  // Register C++ passthrough (AFTER custom lang setup)
  MorConfigCpp(LInterp);
  FEngine.Status(RSEngineCppPassthrough);

  FMorLoaded := True;
  Result := True;
end;

function TMorEngineAPI.ParseSource(const ASourceFile: string): Boolean;
var
  LUserSource: string;
  LUserTokens: TList<TMorToken>;
  LGenLexer: TMorGenericLexer;
  LGenParser: TMorGenericParser;
  LUserBranch: TMorASTNode;
  LErrors: TMorErrors;
  LSrcDisplay: string;
begin
  Result := False;
  LErrors := FEngine.GetErrors();

  if not FMorLoaded then
  begin
    LErrors.Add(esFatal, MOR_ERR_ENGINEAPI_MOR_NOT_LOADED,
      RSEngineAPIMorNotLoaded);
    Exit;
  end;

  // Free previous source state if re-parsing
  FreeAndNil(FMasterRoot);
  FreeAndNil(FScopes);
  FreeAndNil(FOutput);
  FProcessedFiles.Clear();
  FSourceParsed := False;
  FSemanticsRun := False;
  FEmittersRun := False;

  LSrcDisplay := TMorUtils.DisplayPath(ASourceFile);

  // Check source file exists
  if not TFile.Exists(ASourceFile) then
  begin
    LErrors.Add(esFatal, MOR_ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LSrcDisplay]);
    Exit;
  end;

  LUserSource := TFile.ReadAllText(ASourceFile, TEncoding.UTF8);

  // Lex user source via table-driven lexer
  FEngine.Status(RSUserLexerTokenizing, [LSrcDisplay]);
  LGenLexer := TMorGenericLexer.Create();
  try
    LGenLexer.SetErrors(LErrors);
    LGenLexer.SetBuild(FEngine.GetBuild());
    LGenLexer.Configure(FEngine.GetInterpreter());
    LUserTokens := LGenLexer.Tokenize(LUserSource, LSrcDisplay);
  finally
    LGenLexer.Free();
  end;
  if LErrors.HasErrors() then
    Exit;

  // Parse user source into a branch
  FEngine.Status(RSUserParserParsing, [LSrcDisplay]);
  LGenParser := TMorGenericParser.Create();
  try
    LGenParser.SetErrors(LErrors);
    LGenParser.Configure(FEngine.GetInterpreter());
    LUserBranch := LGenParser.ParseProgram(LUserTokens, LSrcDisplay);
  finally
    LGenParser.Free();
  end;
  LUserTokens.Free();
  if LErrors.HasErrors() then
  begin
    LUserBranch.Free();
    Exit;
  end;

  // Assemble master AST
  FMasterRoot := TMorASTNode.Create();
  FMasterRoot.SetKind('master.root');
  FMasterRoot.AddChild(LUserBranch);
  LUserBranch.SetAttr('source_name',
    TPath.GetFileNameWithoutExtension(ASourceFile));
  FProcessedFiles.Add(TPath.GetFullPath(ASourceFile), True);
  FSourceDir := TPath.GetDirectoryName(TPath.GetFullPath(ASourceFile));

  FSourceParsed := True;
  Result := True;
end;

function TMorEngineAPI.RunSemantics(): Boolean;
var
  LErrors: TMorErrors;
  LInterp: TMorInterpreter;
begin
  Result := False;
  LErrors := FEngine.GetErrors();

  if not FSourceParsed then
  begin
    LErrors.Add(esFatal, MOR_ERR_ENGINEAPI_SRC_NOT_PARSED,
      RSEngineAPISrcNotParsed);
    Exit;
  end;

  // Create scopes and output for semantic/emit phases
  FScopes := TScopeManager.Create();
  FScopes.SetErrors(LErrors);
  FOutput := TMorCodeOutput.Create();

  LInterp := FEngine.GetInterpreter();
  LInterp.SetScopes(FScopes);
  LInterp.SetOutput(FOutput);
  LInterp.SetCompileModuleFunc(CompileModule);

  // Run semantic analysis
  FEngine.Status(RSUserSemanticAnalyzing,
    ['source']);
  LInterp.RunSemantics(FMasterRoot);

  if LErrors.HasErrors() then
  begin
    LInterp.SetCompileModuleFunc(nil);
    LInterp.SetScopes(nil);
    LInterp.SetOutput(nil);
    FreeAndNil(FScopes);
    FreeAndNil(FOutput);
    Exit;
  end;

  FSemanticsRun := True;
  Result := True;
end;

function TMorEngineAPI.RunEmitters(): Boolean;
var
  LErrors: TMorErrors;
  LInterp: TMorInterpreter;
  LBranch: TMorASTNode;
  LBranchOutput: TMorCodeOutput;
  LGeneratedPath: string;
  LHeaderPath: string;
  LSourcePath: string;
  LProjectName: string;
  LBranchName: string;
  LI: Integer;
begin
  Result := False;
  LErrors := FEngine.GetErrors();

  if not FSemanticsRun then
  begin
    LErrors.Add(esFatal, MOR_ERR_ENGINEAPI_SEM_NOT_RUN,
      RSEngineAPISemNotRun);
    Exit;
  end;

  LInterp := FEngine.GetInterpreter();

  // Setup build paths
  LProjectName := '';
  if FMasterRoot.ChildCount() > 0 then
    LProjectName := FMasterRoot.GetChild(0).GetAttr('source_name');
  if LProjectName = '' then
    LProjectName := 'output';

  LGeneratedPath := TPath.Combine(FOutputPath, 'generated');
  TDirectory.CreateDirectory(LGeneratedPath);
  FEngine.SetOutputPath(FOutputPath);
  FEngine.SetProjectName(LProjectName);
  FEngine.ClearSourceFiles();
  FEngine.AddIncludePath(LGeneratedPath);
  FEngine.AddIncludePath(FEngine.GetRuntimePath());
  FEngine.AddSourceFile(FEngine.GetRuntimePath('mor_runtime.cpp'));

  // Pass 1: module branches (index 1+)
  for LI := 1 to FMasterRoot.ChildCount() - 1 do
  begin
    LBranch := FMasterRoot.GetChild(LI);
    LBranchName := LBranch.GetAttr('source_name');
    if LBranchName = '' then
      LBranchName := 'module_' + IntToStr(LI);

    LBranchOutput := TMorCodeOutput.Create();
    try
      LInterp.SetOutput(LBranchOutput);
      FEngine.Status(RSUserCodeGenEmitting, [LBranchName]);
      LInterp.RunEmitHandler(LBranch);
      if LErrors.HasErrors() then
        Exit;

      LHeaderPath := TPath.Combine(LGeneratedPath, LBranchName + '.h');
      LSourcePath := TPath.Combine(LGeneratedPath, LBranchName + '.cpp');
      LBranchOutput.SaveToFiles(LHeaderPath, LSourcePath);
      FEngine.AddSourceFile(LSourcePath);
    finally
      LBranchOutput.Free();
    end;
  end;

  // Pass 2: main program branch (index 0)
  if FMasterRoot.ChildCount() > 0 then
  begin
    LBranch := FMasterRoot.GetChild(0);
    LBranchName := LBranch.GetAttr('source_name');
    if LBranchName = '' then
      LBranchName := LProjectName;

    LBranchOutput := TMorCodeOutput.Create();
    try
      LInterp.SetOutput(LBranchOutput);
      FEngine.Status(RSUserCodeGenEmitting, [LBranchName]);
      LInterp.RunEmitHandler(LBranch);
      if LErrors.HasErrors() then
        Exit;

      LHeaderPath := TPath.Combine(LGeneratedPath, LBranchName + '.h');
      LSourcePath := TPath.Combine(LGeneratedPath, LBranchName + '.cpp');
      LBranchOutput.SaveToFiles(LHeaderPath, LSourcePath);
      FEngine.AddSourceFile(LSourcePath);
    finally
      LBranchOutput.Free();
    end;
  end;

  // Restore main output on interpreter
  LInterp.SetOutput(FOutput);
  FEmittersRun := True;
  Result := True;
end;

function TMorEngineAPI.Build(const AOutputPath: string;
  const AAutoRun: Boolean): Boolean;
var
  LErrors: TMorErrors;
begin
  Result := False;
  LErrors := FEngine.GetErrors();

  if not FEmittersRun then
  begin
    LErrors.Add(esFatal, MOR_ERR_ENGINEAPI_EMIT_NOT_RUN,
      RSEngineAPIEmitNotRun);
    Exit;
  end;

  if AOutputPath <> '' then
    FEngine.SetOutputPath(AOutputPath);

  // Report build configuration
  if FEngine.GetTarget() = tpWin64 then
  begin
    if FEngine.GetSubsystem() = stGUI then
      FEngine.Status(RSEngineTargetPlatform, [COLOR_CYAN + 'Win64 (GUI)'])
    else
      FEngine.Status(RSEngineTargetPlatform, [COLOR_CYAN + 'Win64 (Console)']);
  end
  else
    FEngine.Status(RSEngineTargetPlatform, [COLOR_CYAN + 'Linux64']);

  if FEngine.GetBuildMode() = bmExe then
    FEngine.Status(RSEngineBuildMode, [COLOR_CYAN + 'Executable'])
  else if FEngine.GetBuildMode() = bmDll then
    FEngine.Status(RSEngineBuildMode, [COLOR_CYAN + 'DLL'])
  else
    FEngine.Status(RSEngineBuildMode, [COLOR_CYAN + 'Library']);

  if FEngine.GetOptimizeLevel() = olDebug then
    FEngine.Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'Debug'])
  else if FEngine.GetOptimizeLevel() = olReleaseSafe then
    FEngine.Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'ReleaseSafe'])
  else if FEngine.GetOptimizeLevel() = olReleaseFast then
    FEngine.Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'ReleaseFast'])
  else
    FEngine.Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'ReleaseSmall']);
  FEngine.Process(AAutoRun);

  Result := not LErrors.HasErrors();
end;

function TMorEngineAPI.CompileAll(const AMorFile: string;
  const ASourceFile: string; const AOutputPath: string;
  const AAutoRun: Boolean): Boolean;
begin
  FOutputPath := AOutputPath;

  if not LoadMor(AMorFile) then
    Exit(False);

  if not ParseSource(ASourceFile) then
    Exit(False);

  if not RunSemantics() then
    Exit(False);

  if not RunEmitters() then
    Exit(False);

  Result := Build(AOutputPath, AAutoRun);
end;

procedure TMorEngineAPI.Reset();
var
  LInterp: TMorInterpreter;
begin
  // Unwire interpreter from scopes/output/module callback
  LInterp := FEngine.GetInterpreter();
  LInterp.SetCompileModuleFunc(nil);
  LInterp.SetScopes(nil);
  LInterp.SetOutput(nil);

  // Free pipeline state
  FreeAndNil(FMasterRoot);
  FreeAndNil(FScopes);
  FreeAndNil(FOutput);
  FProcessedFiles.Clear();

  // Clear pipeline flags (but NOT FMorLoaded -- grammar stays loaded)
  FSourceParsed := False;
  FSemanticsRun := False;
  FEmittersRun := False;
end;

function TMorEngineAPI.GetMasterRoot(): TMorASTNode;
begin
  Result := FMasterRoot;
end;

function TMorEngineAPI.GetInterpreter(): TMorInterpreter;
begin
  Result := FEngine.GetInterpreter();
end;

function TMorEngineAPI.GetErrors(): TMorErrors;
begin
  Result := FEngine.GetErrors();
end;

procedure TMorEngineAPI.RegisterEmitHandler(const ANodeKind: string;
  const AProc: TMorEmitProc; const AUserData: Pointer);
var
  LProc: TMorEmitProc;
  LUserData: Pointer;
begin
  LProc := AProc;
  LUserData := AUserData;
  FEngine.GetInterpreter().RegisterNativeEmit(ANodeKind,
    procedure(const ANode: TMorASTNode)
    begin
      LProc(UInt64(ANode), LUserData);
    end);
end;

function TMorEngineAPI.CompileModule(const AModuleName: string): Boolean;
var
  LModuleFile: string;
  LModulePath: string;
  LModuleDisplay: string;
  LSource: string;
  LGenLexer: TMorGenericLexer;
  LGenParser: TMorGenericParser;
  LTokens: TList<TMorToken>;
  LBranch: TMorASTNode;
  LErrors: TMorErrors;
  LInterp: TMorInterpreter;
begin
  LInterp := FEngine.GetInterpreter();
  LErrors := FEngine.GetErrors();

  // Resolve filename using module extension
  LModuleFile := AModuleName + '.' + LInterp.GetModuleExtension();
  LModulePath := TPath.Combine(FSourceDir, LModuleFile);
  LModuleDisplay := TMorUtils.DisplayPath(LModulePath);

  // Check dedup
  if FProcessedFiles.ContainsKey(TPath.GetFullPath(LModulePath)) then
    Exit(True);

  // Check existence
  if not TFile.Exists(LModulePath) then
  begin
    LErrors.Add(esError, MOR_ERR_ENGINE_MODULE_NOT_FOUND,
      RSFatalFileNotFound, [LModuleDisplay]);
    Exit(False);
  end;

  LSource := TFile.ReadAllText(LModulePath, TEncoding.UTF8);

  // Lex module source
  FEngine.Status(RSUserLexerTokenizing, [LModuleDisplay]);
  LGenLexer := TMorGenericLexer.Create();
  try
    LGenLexer.SetErrors(LErrors);
    LGenLexer.SetBuild(FEngine.GetBuild());
    LGenLexer.Configure(LInterp);
    LTokens := LGenLexer.Tokenize(LSource, LModuleDisplay);
  finally
    LGenLexer.Free();
  end;
  if LErrors.HasErrors() then
    Exit(False);

  // Parse module source into a branch
  FEngine.Status(RSUserParserParsing, [LModuleDisplay]);
  LGenParser := TMorGenericParser.Create();
  try
    LGenParser.SetErrors(LErrors);
    LGenParser.Configure(LInterp);
    LBranch := LGenParser.ParseProgram(LTokens, LModuleDisplay);
  finally
    LGenParser.Free();
  end;
  LTokens.Free();
  if LErrors.HasErrors() then
    Exit(False);

  // Attach branch to master root and mark processed
  LBranch.SetAttr('source_name', AModuleName);
  FMasterRoot.AddChild(LBranch);
  FProcessedFiles.Add(TPath.GetFullPath(LModulePath), True);

  // Run semantics on the new branch (may trigger further CompileModule calls)
  LInterp.RunSemanticHandler(LBranch);

  Result := True;
end;

function TMorEngineAPI.ImportMorFile(const AMorPath: string): TMorASTNode;
var
  LFullPath: string;
  LDisplay: string;
  LSource: string;
  LTokens: TList<TMorToken>;
  LAST: TMorASTNode;
  LErrors: TMorErrors;
begin
  Result := nil;
  LErrors := FEngine.GetErrors();

  // Resolve relative to .mor file directory
  if TPath.IsRelativePath(AMorPath) then
    LFullPath := TPath.GetFullPath(TPath.Combine(FMorFileDir, AMorPath))
  else
    LFullPath := TPath.GetFullPath(AMorPath);

  LDisplay := TMorUtils.DisplayPath(LFullPath);

  // Dedup check
  if FImportedMorFiles.ContainsKey(LFullPath) then
    Exit;

  // Check existence
  if not TFile.Exists(LFullPath) then
  begin
    LErrors.Add(esError, MOR_ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LDisplay]);
    Exit;
  end;

  // Mark as imported
  FImportedMorFiles.Add(LFullPath, True);

  LSource := TFile.ReadAllText(LFullPath, TEncoding.UTF8);

  // Lex imported .mor file
  FEngine.Status(RSMorLexerTokenizing, [LDisplay]);
  LTokens := FMorLexer.Tokenize(LSource, LDisplay);
  if LErrors.HasErrors() then
  begin
    LTokens.Free();
    Exit;
  end;

  // Parse imported .mor file
  FEngine.Status(RSMorParserParsing, [LDisplay]);
  LAST := FMorParser.Parse(LTokens, LDisplay);
  LTokens.Free();
  if LErrors.HasErrors() then
  begin
    LAST.Free();
    Exit;
  end;

  // Add to .mor master root for lifetime management
  FMorMasterRoot.AddChild(LAST);

  Result := LAST;
end;


function TMorEngineAPI.DebugExe(const AExePath: string;
  const APort: Integer): Boolean;
var
  LErrors: TMorErrors;
  LServer: TMorDebugServer;
begin
  Result := False;
  LErrors := FEngine.GetErrors();

  LServer := TMorDebugServer.Create();
  try
    LServer.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        FEngine.Status('%s', [AText]);
      end);

    if not LServer.DebugExe(AExePath, APort) then
    begin
      if LServer.HasErrors() then
        LErrors.Add(esFatal, 'ERR_DEBUG', LServer.GetErrorText());
      Exit;
    end;

    Result := True;
  finally
    LServer.Free();
  end;
end;

procedure TMorEngineAPI.SetTarget(const ATarget: Integer);
begin
  FEngine.SetTarget(TMorTargetPlatform(ATarget));
end;

function TMorEngineAPI.GetTarget(): Integer;
begin
  Result := Ord(FEngine.GetTarget());
end;

procedure TMorEngineAPI.SetOptimizeLevel(const ALevel: Integer);
begin
  FEngine.SetOptimizeLevel(TMorOptimizeLevel(ALevel));
end;

function TMorEngineAPI.GetOptimizeLevel(): Integer;
begin
  Result := Ord(FEngine.GetOptimizeLevel());
end;

procedure TMorEngineAPI.SetSubsystem(const ASubsystem: Integer);
begin
  FEngine.SetSubsystem(TMorSubsystemType(ASubsystem));
end;

function TMorEngineAPI.GetSubsystem(): Integer;
begin
  Result := Ord(FEngine.GetSubsystem());
end;

procedure TMorEngineAPI.SetBuildMode(const AMode: Integer);
begin
  FEngine.SetBuildMode(TMorBuildMode(AMode));
end;

function TMorEngineAPI.GetBuildMode(): Integer;
begin
  Result := Ord(FEngine.GetBuildMode());
end;

procedure TMorEngineAPI.SetDefine(const ADefineName: string;
  const AValue: string);
begin
  if AValue = '' then
    FEngine.SetDefine(ADefineName)
  else
    FEngine.SetDefine(ADefineName, AValue);
end;

procedure TMorEngineAPI.SetToolchainPath(const APath: string);
begin
  FEngine.SetToolchainPath(APath);
end;

function TMorEngineAPI.GetToolchainPath(): string;
begin
  Result := FEngine.GetToolchainPath();
end;

function TMorEngineAPI.GetZigPath(const AFilename: string): string;
begin
  Result := FEngine.GetZigPath(AFilename);
end;

function TMorEngineAPI.GetRuntimePath(const AFilename: string): string;
begin
  Result := FEngine.GetRuntimePath(AFilename);
end;

function TMorEngineAPI.GetLibsPath(const AFilename: string): string;
begin
  Result := FEngine.GetLibsPath(AFilename);
end;

function TMorEngineAPI.GetAssetsPath(const AFilename: string): string;
begin
  Result := FEngine.GetAssetsPath(AFilename);
end;

function TMorEngineAPI.GetLastExitCode(): Integer;
begin
  Result := Integer(FEngine.GetLastExitCode());
end;

function TMorEngineAPI.SetupLanguage(const AMorFile: string): Boolean;
begin
  Result := FEngine.SetupLanguage(AMorFile);
end;

procedure TMorEngineAPI.CompileBaked(const ASourceFile: string;
  const AOutputPath: string; const AAutoRun: Boolean);
begin
  FEngine.CompileBaked(ASourceFile, AOutputPath, AAutoRun);
end;

// ==========================================================================
// Flat C-compatible exports (DLL surface)
// ==========================================================================

{$IFDEF METAMORF_EXPORTS}

// --- Lifecycle ---

function mor_create(): UInt64;
begin
  Result := UInt64(TMorEngineAPI.Create());
end;

procedure mor_destroy(const AHandle: UInt64);
begin
  TMorEngineAPI(Pointer(AHandle)).Free();
end;

procedure mor_reset(const AHandle: UInt64);
begin
  TMorEngineAPI(Pointer(AHandle)).Reset();
end;

// --- Callbacks ---

procedure mor_set_status_callback(const AHandle: UInt64;
  const AProc: TMorStatusProc; const AUserData: Pointer);
begin
  TMorEngineAPI(Pointer(AHandle)).SetStatusCallback(AProc, AUserData);
end;

procedure mor_set_output_callback(const AHandle: UInt64;
  const AProc: TMorOutputProc; const AUserData: Pointer);
begin
  TMorEngineAPI(Pointer(AHandle)).SetOutputCallback(AProc, AUserData);
end;

procedure mor_register_emit_handler(const AHandle: UInt64;
  const ANodeKind: PUTF8Char; const AProc: TMorEmitProc;
  const AUserData: Pointer);
begin
  TMorEngineAPI(Pointer(AHandle)).RegisterEmitHandler(
    UTF8ToString(ANodeKind), AProc, AUserData);
end;

// --- Stepped pipeline ---

function mor_load_mor(const AHandle: UInt64;
  const AMorFile: PUTF8Char): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).LoadMor(
    UTF8ToString(AMorFile));
end;

function mor_parse_source(const AHandle: UInt64;
  const ASourceFile: PUTF8Char): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ParseSource(
    UTF8ToString(ASourceFile));
end;

function mor_run_semantics(const AHandle: UInt64): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).RunSemantics();
end;

function mor_run_emitters(const AHandle: UInt64): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).RunEmitters();
end;

function mor_build(const AHandle: UInt64;
  const AOutputPath: PUTF8Char; const ARunMode: Integer): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).Build(
    UTF8ToString(AOutputPath),
    ARunMode = MOR_RUN_EXECUTE);
end;

function mor_compile(const AHandle: UInt64;
  const AMorFile: PUTF8Char; const ASourceFile: PUTF8Char;
  const AOutputPath: PUTF8Char; const ARunMode: Integer): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).CompileAll(
    UTF8ToString(AMorFile), UTF8ToString(ASourceFile),
    UTF8ToString(AOutputPath),
    ARunMode = MOR_RUN_EXECUTE);
end;

// --- AST query ---

function mor_get_master_root(const AHandle: UInt64): UInt64;
begin
  Result := UInt64(TMorEngineAPI(Pointer(AHandle)).GetMasterRoot());
end;

function mor_node_kind(const AHandle: UInt64;
  const ANode: UInt64): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorASTNode(Pointer(ANode)).GetKind());
end;

function mor_node_get_attr(const AHandle: UInt64;
  const ANode: UInt64; const AAttrName: PUTF8Char): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorASTNode(Pointer(ANode)).GetAttr(UTF8ToString(AAttrName)));
end;

function mor_node_has_attr(const ANode: UInt64;
  const AAttrName: PUTF8Char): Boolean;
begin
  Result := TMorASTNode(Pointer(ANode)).HasAttr(UTF8ToString(AAttrName));
end;

function mor_node_child_count(const ANode: UInt64): Integer;
begin
  Result := TMorASTNode(Pointer(ANode)).ChildCount();
end;

function mor_node_child(const ANode: UInt64;
  const AIndex: Integer): UInt64;
begin
  Result := UInt64(TMorASTNode(Pointer(ANode)).GetChild(AIndex));
end;

procedure mor_node_set_attr(const ANode: UInt64;
  const AAttrName: PUTF8Char; const AValue: PUTF8Char);
begin
  TMorASTNode(Pointer(ANode)).SetAttr(
    UTF8ToString(AAttrName), UTF8ToString(AValue));
end;

// --- Error query ---

function mor_error_count(const AHandle: UInt64): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetErrors().Count();
end;

function mor_has_errors(const AHandle: UInt64): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetErrors().HasErrors();
end;

procedure mor_clear_errors(const AHandle: UInt64);
begin
  TMorEngineAPI(Pointer(AHandle)).GetErrors().Clear();
end;

function mor_get_max_errors(const AHandle: UInt64): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetErrors().GetMaxErrors();
end;

procedure mor_set_max_errors(const AHandle: UInt64;
  const AMaxErrors: Integer);
begin
  TMorEngineAPI(Pointer(AHandle)).GetErrors().SetMaxErrors(AMaxErrors);
end;

function mor_error_get_severity(const AHandle: UInt64;
  const AIndex: Integer): Integer;
begin
  Result := Ord(TMorEngineAPI(Pointer(AHandle)).GetErrors().GetItems()[AIndex].Severity);
end;

function mor_error_get_code(const AHandle: UInt64;
  const AIndex: Integer): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetErrors().GetItems()[AIndex].Code);
end;

function mor_error_get_message(const AHandle: UInt64;
  const AIndex: Integer): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetErrors().GetItems()[AIndex].Message);
end;

function mor_error_get_filename(const AHandle: UInt64;
  const AIndex: Integer): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetErrors().GetItems()[AIndex].Range.Filename);
end;

function mor_error_get_line(const AHandle: UInt64;
  const AIndex: Integer): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetErrors().GetItems()[AIndex].Range.StartLine;
end;

function mor_error_get_col(const AHandle: UInt64;
  const AIndex: Integer): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetErrors().GetItems()[AIndex].Range.StartColumn;
end;


// --- Debug ---

function mor_debug_exe(const AHandle: UInt64;
  const AExePath: PUTF8Char; const APort: Integer): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).DebugExe(
    UTF8ToString(AExePath), APort);
end;

// --- Build configuration ---

procedure mor_set_target(const AHandle: UInt64;
  const ATarget: Integer);
begin
  TMorEngineAPI(Pointer(AHandle)).SetTarget(ATarget);
end;

function mor_get_target(const AHandle: UInt64): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetTarget();
end;

procedure mor_set_optimize_level(const AHandle: UInt64;
  const ALevel: Integer);
begin
  TMorEngineAPI(Pointer(AHandle)).SetOptimizeLevel(ALevel);
end;

function mor_get_optimize_level(const AHandle: UInt64): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetOptimizeLevel();
end;

procedure mor_set_subsystem(const AHandle: UInt64;
  const ASubsystem: Integer);
begin
  TMorEngineAPI(Pointer(AHandle)).SetSubsystem(ASubsystem);
end;

function mor_get_subsystem(const AHandle: UInt64): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetSubsystem();
end;

procedure mor_set_build_mode(const AHandle: UInt64;
  const AMode: Integer);
begin
  TMorEngineAPI(Pointer(AHandle)).SetBuildMode(AMode);
end;

function mor_get_build_mode(const AHandle: UInt64): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetBuildMode();
end;

procedure mor_set_define(const AHandle: UInt64;
  const ADefineName: PUTF8Char; const AValue: PUTF8Char);
var
  LValue: string;
begin
  if AValue <> nil then
    LValue := UTF8ToString(AValue)
  else
    LValue := '';
  TMorEngineAPI(Pointer(AHandle)).SetDefine(
    UTF8ToString(ADefineName), LValue);
end;

// --- Toolchain paths ---

procedure mor_set_toolchain_path(const AHandle: UInt64;
  const APath: PUTF8Char);
begin
  TMorEngineAPI(Pointer(AHandle)).SetToolchainPath(
    UTF8ToString(APath));
end;

function mor_get_toolchain_path(const AHandle: UInt64): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetToolchainPath());
end;

function mor_get_zig_path(const AHandle: UInt64;
  const AFilename: PUTF8Char): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetZigPath(
      UTF8ToString(AFilename)));
end;

function mor_get_runtime_path(const AHandle: UInt64;
  const AFilename: PUTF8Char): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetRuntimePath(
      UTF8ToString(AFilename)));
end;

function mor_get_libs_path(const AHandle: UInt64;
  const AFilename: PUTF8Char): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetLibsPath(
      UTF8ToString(AFilename)));
end;

function mor_get_assets_path(const AHandle: UInt64;
  const AFilename: PUTF8Char): PUTF8Char;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).ReturnUTF8(
    TMorEngineAPI(Pointer(AHandle)).GetAssetsPath(
      UTF8ToString(AFilename)));
end;

// --- Process/build control ---

function mor_get_last_exit_code(const AHandle: UInt64): Integer;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).GetLastExitCode();
end;

// --- Advanced pipeline ---

function mor_setup_language(const AHandle: UInt64;
  const AMorFile: PUTF8Char): Boolean;
begin
  Result := TMorEngineAPI(Pointer(AHandle)).SetupLanguage(
    UTF8ToString(AMorFile));
end;

procedure mor_compile_baked(const AHandle: UInt64;
  const ASourceFile: PUTF8Char; const AOutputPath: PUTF8Char;
  const AAutoRun: Boolean);
begin
  TMorEngineAPI(Pointer(AHandle)).CompileBaked(
    UTF8ToString(ASourceFile), UTF8ToString(AOutputPath), AAutoRun);
end;

{$ENDIF METAMORF_EXPORTS}

{$IFDEF METAMORF_EXPORTS}
exports
  mor_create,
  mor_destroy,
  mor_reset,
  mor_set_status_callback,
  mor_set_output_callback,
  mor_register_emit_handler,
  mor_load_mor,
  mor_parse_source,
  mor_run_semantics,
  mor_run_emitters,
  mor_build,
  mor_compile,
  mor_get_master_root,
  mor_node_kind,
  mor_node_get_attr,
  mor_node_has_attr,
  mor_node_child_count,
  mor_node_child,
  mor_node_set_attr,
  mor_error_count,
  mor_has_errors,
  mor_clear_errors,
  mor_get_max_errors,
  mor_set_max_errors,
  mor_error_get_severity,
  mor_error_get_code,
  mor_error_get_message,
  mor_error_get_filename,
  mor_error_get_line,
  mor_error_get_col,
  mor_debug_exe,
  mor_set_target,
  mor_get_target,
  mor_set_optimize_level,
  mor_get_optimize_level,
  mor_set_subsystem,
  mor_get_subsystem,
  mor_set_build_mode,
  mor_get_build_mode,
  mor_set_define,
  mor_set_toolchain_path,
  mor_get_toolchain_path,
  mor_get_zig_path,
  mor_get_runtime_path,
  mor_get_libs_path,
  mor_get_assets_path,
  mor_get_last_exit_code,
  mor_setup_language,
  mor_compile_baked;
{$ENDIF METAMORF_EXPORTS}

end.
