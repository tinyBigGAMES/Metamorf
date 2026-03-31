{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Engine;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.Build,
  Metamorf.AST,
  Metamorf.Lexer,
  Metamorf.Parser,
  Metamorf.Interpreter,
  Metamorf.Scopes,
  Metamorf.CodeGen,
  Metamorf.GenericLexer,
  Metamorf.GenericParser,
  Metamorf.Cpp;

const
  // Engine Error Codes (E001-E099)
  ERR_ENGINE_FILE_NOT_FOUND   = 'E001';
  ERR_ENGINE_MODULE_NOT_FOUND = 'E002';

type

  { TMorEngine }
  TMorEngine = class(TErrorsObject)
  private
    FBuild: TBuild;
    FMorLexer: TMorLexer;
    FMorParser: TMorParser;
    FInterp: TMorInterpreter;
    FProcessedFiles: TDictionary<string, Boolean>;
    FImportedMorFiles: TDictionary<string, Boolean>;
    FMasterRoot: TASTNode;
    FMorMasterRoot: TASTNode;
    FSourceDir: string;
    FMorFileDir: string;
    FOutputPath: string;

    // Module compilation callback (called by interpreter during semantics)
    function CompileModule(const AModuleName: string): Boolean;

    // .mor import callback (called by interpreter during setup)
    function ImportMorFile(const AMorPath: string): TASTNode;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Full compilation pipeline: .mor + user source -> native binary
    procedure Compile(const AMorFile: string;
      const ASourceFile: string; const AOutputPath: string;
      const AAutoRun: Boolean = False);

    // Access to subcomponents
    function GetBuild(): TBuild;
    function GetInterpreter(): TMorInterpreter;
    function GetErrors(): TErrors;
  end;

implementation

{ TMorEngine }

constructor TMorEngine.Create();
begin
  inherited;

  FErrors := TErrors.Create();

  FBuild := TBuild.Create();
  FBuild.SetErrors(FErrors);

  FMorLexer := TMorLexer.Create();
  FMorLexer.SetErrors(FErrors);

  FMorParser := TMorParser.Create();
  FMorParser.SetErrors(FErrors);

  FInterp := TMorInterpreter.Create();
  FInterp.SetErrors(FErrors);
  FInterp.SetBuild(FBuild);

  FProcessedFiles := TDictionary<string, Boolean>.Create();
  FImportedMorFiles := TDictionary<string, Boolean>.Create();
end;

destructor TMorEngine.Destroy();
begin
  FreeAndNil(FImportedMorFiles);
  FreeAndNil(FProcessedFiles);
  FreeAndNil(FInterp);
  FreeAndNil(FMorParser);
  FreeAndNil(FMorLexer);
  FreeAndNil(FBuild);
  FreeAndNil(FErrors);
  inherited;
end;

procedure TMorEngine.Compile(const AMorFile: string;
  const ASourceFile: string; const AOutputPath: string;
  const AAutoRun: Boolean);
var
  LMorSource: string;
  LMorTokens: TList<TToken>;
  LMorAST: TASTNode;
  LUserSource: string;
  LUserTokens: TList<TToken>;
  LGenLexer: TGenericLexer;
  LGenParser: TGenericParser;
  LMasterRoot: TASTNode;
  LUserBranch: TASTNode;
  LScopes: TScopeManager;
  LOutput: TCodeOutput;
  LBranchOutput: TCodeOutput;
  LBranch: TASTNode;
  LGeneratedPath: string;
  LHeaderPath: string;
  LSourcePath: string;
  LProjectName: string;
  LBranchName: string;
  LMorDisplay: string;
  LSrcDisplay: string;
  LI: Integer;
begin
  FErrors.Clear();
  FProcessedFiles.Clear();
  FImportedMorFiles.Clear();

  LMorDisplay := TUtils.DisplayPath(AMorFile);
  LSrcDisplay := TUtils.DisplayPath(ASourceFile);

  // --- Phase 1: Read and parse .mor file ---
  if not TFile.Exists(AMorFile) then
  begin
    FErrors.Add(esFatal, ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LMorDisplay]);
    Exit;
  end;

  LMorSource := TFile.ReadAllText(AMorFile, TEncoding.UTF8);

  // Lex .mor source
  Status(RSMorLexerTokenizing, [LMorDisplay]);
  LMorTokens := FMorLexer.Tokenize(LMorSource, LMorDisplay);
  if FErrors.HasErrors() then
  begin
    LMorTokens.Free();
    Exit;
  end;

  // Parse .mor source
  Status(RSMorParserParsing, [LMorDisplay]);
  LMorAST := FMorParser.Parse(LMorTokens, LMorDisplay);
  LMorTokens.Free();
  if FErrors.HasErrors() then Exit;

  // --- Phase 2: Setup interpreter tables ---
  Status(RSMorInterpSetup);
  FMorFileDir := TPath.GetDirectoryName(TPath.GetFullPath(AMorFile));
  FImportedMorFiles.Add(TPath.GetFullPath(AMorFile), True);

  // Build .mor master root -- owns all .mor ASTs (main + imports)
  FMorMasterRoot := TASTNode.Create();
  FMorMasterRoot.SetKind('mor.master');
  FMorMasterRoot.AddChild(LMorAST);

  FInterp.SetImportMorFunc(ImportMorFile);
  FInterp.RunSetup(LMorAST);
  FInterp.SetImportMorFunc(nil);
  if FErrors.HasErrors() then Exit;

  // Register C++ passthrough (AFTER custom lang setup)
  ConfigCpp(FInterp);

  // --- Phase 3: Read and process user source ---
  if not TFile.Exists(ASourceFile) then
  begin
    FErrors.Add(esFatal, ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LSrcDisplay]);
    Exit;
  end;

  LUserSource := TFile.ReadAllText(ASourceFile, TEncoding.UTF8);

  // Lex user source via table-driven lexer
  Status(RSUserLexerTokenizing, [LSrcDisplay]);
  LGenLexer := TGenericLexer.Create();
  try
    LGenLexer.SetErrors(FErrors);
    LGenLexer.Configure(FInterp);
    LUserTokens := LGenLexer.Tokenize(LUserSource, LSrcDisplay);
  finally
    LGenLexer.Free();
  end;
  if FErrors.HasErrors() then Exit;

  // Parse user source into a branch
  Status(RSUserParserParsing, [LSrcDisplay]);
  LGenParser := TGenericParser.Create();
  try
    LGenParser.SetErrors(FErrors);
    LGenParser.Configure(FInterp);
    LUserBranch := LGenParser.ParseProgram(LUserTokens, LSrcDisplay);
  finally
    LGenParser.Free();
  end;
  LUserTokens.Free();
  if FErrors.HasErrors() then Exit;

  // Assemble master AST: single root, one branch per file
  LMasterRoot := TASTNode.Create();
  LMasterRoot.SetKind('master.root');
  LMasterRoot.AddChild(LUserBranch);
  LUserBranch.SetAttr('source_name', TPath.GetFileNameWithoutExtension(ASourceFile));
  FProcessedFiles.Add(TPath.GetFullPath(ASourceFile), True);
  FMasterRoot := LMasterRoot;
  FSourceDir := TPath.GetDirectoryName(TPath.GetFullPath(ASourceFile));
  FOutputPath := AOutputPath;

  // Wire scopes and output into interpreter
  LScopes := TScopeManager.Create();
  LScopes.SetErrors(FErrors);
  LOutput := TCodeOutput.Create();
  try
    FInterp.SetScopes(LScopes);
    FInterp.SetOutput(LOutput);
    FInterp.SetCompileModuleFunc(CompileModule);

    // --- Phase 4: Semantic analysis ---
    Status(RSUserSemanticAnalyzing, [LSrcDisplay]);
    FInterp.RunSemantics(LMasterRoot);
    if FErrors.HasErrors() then Exit;

    // --- Phase 5-6: Code generation and output per branch ---
    // Emit module branches first (index 1+), then main program (index 0)
    // so the main program's build settings (exe mode) stick on FBuild.
    LProjectName := TPath.GetFileNameWithoutExtension(ASourceFile);
    LGeneratedPath := TPath.Combine(AOutputPath, 'generated');
    TDirectory.CreateDirectory(LGeneratedPath);
    FBuild.SetOutputPath(AOutputPath);
    FBuild.SetProjectName(LProjectName);
    FBuild.ClearSourceFiles();
    FBuild.AddIncludePath(LGeneratedPath);
    FBuild.AddIncludePath('res/runtime');
    FBuild.AddSourceFile('res/runtime/mor_runtime.cpp');

    // Pass 1: module branches (index 1+)
    for LI := 1 to LMasterRoot.ChildCount() - 1 do
    begin
      LBranch := LMasterRoot.GetChild(LI);
      LBranchName := LBranch.GetAttr('source_name');
      if LBranchName = '' then
        LBranchName := 'module_' + IntToStr(LI);

      LBranchOutput := TCodeOutput.Create();
      try
        FInterp.SetOutput(LBranchOutput);
        Status(RSUserCodeGenEmitting, [LBranchName]);
        FInterp.RunEmitHandler(LBranch);
        if FErrors.HasErrors() then Exit;

        LHeaderPath := TPath.Combine(LGeneratedPath, LBranchName + '.h');
        LSourcePath := TPath.Combine(LGeneratedPath, LBranchName + '.cpp');
        LBranchOutput.SaveToFiles(LHeaderPath, LSourcePath);
        FBuild.AddSourceFile(LSourcePath);
      finally
        LBranchOutput.Free();
      end;
    end;

    // Pass 2: main program branch (index 0) -- sets exe build mode last
    if LMasterRoot.ChildCount() > 0 then
    begin
      LBranch := LMasterRoot.GetChild(0);
      LBranchName := LBranch.GetAttr('source_name');
      if LBranchName = '' then
        LBranchName := LProjectName;

      LBranchOutput := TCodeOutput.Create();
      try
        FInterp.SetOutput(LBranchOutput);
        Status(RSUserCodeGenEmitting, [LBranchName]);
        FInterp.RunEmitHandler(LBranch);
        if FErrors.HasErrors() then Exit;

        LHeaderPath := TPath.Combine(LGeneratedPath, LBranchName + '.h');
        LSourcePath := TPath.Combine(LGeneratedPath, LBranchName + '.cpp');
        LBranchOutput.SaveToFiles(LHeaderPath, LSourcePath);
        FBuild.AddSourceFile(LSourcePath);
      finally
        LBranchOutput.Free();
      end;
    end;

    // --- Phase 7: Build via Zig/Clang ---
    FBuild.Process(AAutoRun);
  finally
    FInterp.SetCompileModuleFunc(nil);
    FInterp.SetScopes(nil);
    FInterp.SetOutput(nil);
    FMasterRoot := nil;
    LOutput.Free();
    LScopes.Free();
    LMasterRoot.Free();
    FreeAndNil(FMorMasterRoot);
  end;
end;

function TMorEngine.CompileModule(const AModuleName: string): Boolean;
var
  LModuleFile: string;
  LModulePath: string;
  LModuleDisplay: string;
  LSource: string;
  LGenLexer: TGenericLexer;
  LGenParser: TGenericParser;
  LTokens: TList<TToken>;
  LBranch: TASTNode;
begin
  // Resolve filename using module extension
  LModuleFile := AModuleName + '.' + FInterp.GetModuleExtension();
  LModulePath := TPath.Combine(FSourceDir, LModuleFile);
  LModuleDisplay := TUtils.DisplayPath(LModulePath);

  // Check dedup
  if FProcessedFiles.ContainsKey(TPath.GetFullPath(LModulePath)) then
    Exit(True);

  // Check existence
  if not TFile.Exists(LModulePath) then
  begin
    FErrors.Add(esError, ERR_ENGINE_MODULE_NOT_FOUND,
      RSFatalFileNotFound, [LModuleDisplay]);
    Exit(False);
  end;

  LSource := TFile.ReadAllText(LModulePath, TEncoding.UTF8);

  // Lex module source
  Status(RSUserLexerTokenizing, [LModuleDisplay]);
  LGenLexer := TGenericLexer.Create();
  try
    LGenLexer.SetErrors(FErrors);
    LGenLexer.Configure(FInterp);
    LTokens := LGenLexer.Tokenize(LSource, LModuleDisplay);
  finally
    LGenLexer.Free();
  end;
  if FErrors.HasErrors() then Exit(False);

  // Parse module source into a branch
  Status(RSUserParserParsing, [LModuleDisplay]);
  LGenParser := TGenericParser.Create();
  try
    LGenParser.SetErrors(FErrors);
    LGenParser.Configure(FInterp);
    LBranch := LGenParser.ParseProgram(LTokens, LModuleDisplay);
  finally
    LGenParser.Free();
  end;
  LTokens.Free();
  if FErrors.HasErrors() then Exit(False);

  // Attach branch to master root and mark processed
  LBranch.SetAttr('source_name', AModuleName);
  FMasterRoot.AddChild(LBranch);
  FProcessedFiles.Add(TPath.GetFullPath(LModulePath), True);

  // Run semantics on the new branch (may trigger further compileModule calls)
  FInterp.RunSemanticHandler(LBranch);

  Result := True;
end;

function TMorEngine.ImportMorFile(const AMorPath: string): TASTNode;
var
  LFullPath: string;
  LDisplay: string;
  LSource: string;
  LTokens: TList<TToken>;
  LAST: TASTNode;
begin
  Result := nil;

  // Resolve relative to .mor file directory
  if TPath.IsRelativePath(AMorPath) then
    LFullPath := TPath.GetFullPath(TPath.Combine(FMorFileDir, AMorPath))
  else
    LFullPath := TPath.GetFullPath(AMorPath);

  LDisplay := TUtils.DisplayPath(LFullPath);

  // Dedup check
  if FImportedMorFiles.ContainsKey(LFullPath) then
    Exit;

  // Check existence
  if not TFile.Exists(LFullPath) then
  begin
    FErrors.Add(esError, ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LDisplay]);
    Exit;
  end;

  // Mark as imported
  FImportedMorFiles.Add(LFullPath, True);

  LSource := TFile.ReadAllText(LFullPath, TEncoding.UTF8);

  // Lex imported .mor file
  Status(RSMorLexerTokenizing, [LDisplay]);
  LTokens := FMorLexer.Tokenize(LSource, LDisplay);
  if FErrors.HasErrors() then
  begin
    LTokens.Free();
    Exit;
  end;

  // Parse imported .mor file
  Status(RSMorParserParsing, [LDisplay]);
  LAST := FMorParser.Parse(LTokens, LDisplay);
  LTokens.Free();
  if FErrors.HasErrors() then Exit;

  // Add to .mor master root for lifetime management
  FMorMasterRoot.AddChild(LAST);

  Result := LAST;
end;

function TMorEngine.GetBuild(): TBuild;
begin
  Result := FBuild;
end;

function TMorEngine.GetInterpreter(): TMorInterpreter;
begin
  Result := FInterp;
end;

function TMorEngine.GetErrors(): TErrors;
begin
  Result := FErrors;
end;

end.

