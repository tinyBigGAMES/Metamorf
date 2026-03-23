{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit Myra.Tester;

{$I Metamorf.Defines.inc}

{===============================================================================
  Test File Comment Directives
  -----------------------------------------------------------------------------
  These special comment tokens are embedded in .myra test source files and are
  parsed by TMyraTester before (or without) invoking the compiler.

  /* EXITCODE: <n> */
    Expected process exit code after running the compiled executable.
    Defaults to 0 if omitted. The test fails if the actual exit code differs.
    Example: /* EXITCODE: 1 */

  /* EXPECT:
    <text>
  */
    Expected stdout output. Displayed in the test runner output for manual
    comparison. Not automatically diffed - for human review only.
    Example:
      /* EXPECT:
      Hello, world!
      */

  /* ALLOW_WARNINGS */
    Suppresses the "warnings present" failure. Use when a test intentionally
    produces compiler warnings.
    Example: /* ALLOW_WARNINGS */

  /* PLATFORMS: <P1>, <P2>, ... */
    Comma-separated list of platforms on which this test is valid.
    If the current target platform is not in the list the test is skipped
    (counted as neither pass nor fail). Omit entirely to run on all platforms.
    Valid platform names: WIN64, LINUX64
    Example: /* PLATFORMS: WIN64 */
    Example: /* PLATFORMS: WIN64, LINUX64 */
===============================================================================}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.API,
  Myra.Common,
  Myra.Compiler;

const
  DEFAULT_TEST_FOLDER = '..\projects\myra\tests';


type
  { TTestEntry }
  TTestEntry = record
    TestName:     string;
    Dependencies: TArray<string>;
    CanRun:       Boolean;
    DefineName:   string;
    DefineValue:  string;
  end;

  { TMyraTester }
  TMyraTester = class(TOutputObject)
  private
    FTestFolder:      string;
    FOutputPath:      string;
    FVerbose:         Boolean;
    FPassCount:       Integer;
    FFailCount:       Integer;
    FSkipCount:       Integer;
    FLastTestSkipped: Boolean;
    FFailedTests:     TList<string>;
    FRegisteredTests: TList<TTestEntry>;
    FTargetPlatform:  TTargetPlatform;
    FOptimizeLevel:   TOptimizeLevel;
    FSubsystem:       TSubsystemType;
    FOutputCallback:  TProc<string>;
    FConfigPath:      string;
    FCommentOpen:     string;
    FCommentClose:    string;

    function ExtractExpected(const ASource: string): string;
    function ExtractExpectedExitCode(const ASource: string): Integer;
    function ExtractAllowWarnings(const ASource: string): Boolean;
    function ExtractPlatforms(const ASource: string): TArray<string>;
    function PlatformMatchesCurrent(const APlatforms: TArray<string>): Boolean;
    function ExtractTestName(const AFilePath: string): string;
    function RunTestFile(const AFilePath: string; const AAutoRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Boolean;
    procedure PrintResults();
    procedure Print(const AText: string); overload;
    {$HINTS OFF}
    procedure Print(const AFormat: string; const AArgs: array of const); overload;
    {$HINTS ON}
    function GetFailedTests(): TArray<string>;
    function GetRegisteredTestCount(): Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Config
    procedure LoadConfig(); override;
    procedure SaveConfig(); override;

    // Run methods
    function RunTest(const ATestName: string; const ACanRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Boolean;
    function RunTestByIndex(const AIndex: Integer): Boolean;
    function RunTests(const ATestNames: array of string; const ACanRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Integer;
    function RunAllTests(): Integer;
    function RunTestsMatching(const APattern: string; const ACanRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Integer;

    // Registration (for ordered execution)
    // ACanRun = True (default): build and run. ACanRun = False: build only.
    procedure RegisterTest(const ATestName: string; const ACanRun: Boolean = True; const ADefine: string = ''; const ADefineValue: string = '');
    procedure RegisterTests(const ATestName: string; const ADependencies: array of string; const ACanRun: Boolean = True; const ADefine: string = ''; const ADefineValue: string = '');
    procedure ClearRegisteredTests();

    // Results
    procedure Reset();

    // Properties
    property TestFolder:     string               read FTestFolder     write FTestFolder;
    property OutputPath:     string               read FOutputPath     write FOutputPath;
    property Verbose:        Boolean              read FVerbose        write FVerbose;
    property PassCount:      Integer              read FPassCount;
    property FailCount:      Integer              read FFailCount;
    property SkipCount:      Integer              read FSkipCount;
    property FailedTests:    TArray<string>       read GetFailedTests;
    property TargetPlatform: TTargetPlatform read FTargetPlatform write FTargetPlatform;
    property OptimizeLevel:  TOptimizeLevel  read FOptimizeLevel  write FOptimizeLevel;
    property Subsystem:      TSubsystemType  read FSubsystem      write FSubsystem;
    property OutputCallback: TProc<string>        read FOutputCallback write FOutputCallback;
    property ConfigPath:     string               read FConfigPath     write FConfigPath;
    property RegisteredTestCount: Integer         read GetRegisteredTestCount;
  end;

implementation

uses
  System.Types,
  System.IOUtils,
  System.Classes,
  Metamorf.Common,
  Metamorf.Config;

const
  // Delay between test runs to allow ConPTY, WSL, and Zig cache resources
  // to fully release before the next test fires up its own process.
  TEST_RUNNER_SETTLE_MS = 500;

{ TMyraTester }

constructor TMyraTester.Create();
var
  LCompiler: TMyraCompiler;
begin
  inherited;
  FFailedTests     := TList<string>.Create();
  FRegisteredTests := TList<TTestEntry>.Create();
  FVerbose         := True;
  FOutputPath      := 'output';
  FTargetPlatform  := tpWin64;
  FOptimizeLevel   := olDebug;
  FSubsystem       := stConsole;
  FTestFolder      := DEFAULT_TEST_FOLDER;
  FConfigPath      := '';

  LCompiler := TMyraCompiler.Create();
  try
    FCommentOpen  := LCompiler.Config().GetBlockComments()[0].OpenStr;
    FCommentClose := LCompiler.Config().GetBlockComments()[0].CloseStr;
  finally
    LCompiler.Free();
  end;
end;

destructor TMyraTester.Destroy();
begin
  FRegisteredTests.Free();
  FFailedTests.Free();
  inherited;
end;

procedure TMyraTester.Reset();
begin
  FPassCount       := 0;
  FFailCount       := 0;
  FSkipCount       := 0;
  FLastTestSkipped := False;
  FFailedTests.Clear();
end;

procedure TMyraTester.RegisterTest(const ATestName: string; const ACanRun: Boolean = True; const ADefine: string = ''; const ADefineValue: string = '');
var
  LEntry: TTestEntry;
begin
  LEntry.TestName     := ATestName;
  LEntry.Dependencies := [];
  LEntry.CanRun       := ACanRun;
  LEntry.DefineName   := ADefine;
  LEntry.DefineValue  := ADefineValue;
  FRegisteredTests.Add(LEntry);
end;

procedure TMyraTester.RegisterTests(const ATestName: string; const ADependencies: array of string; const ACanRun: Boolean = True; const ADefine: string = ''; const ADefineValue: string = '');
var
  LEntry: TTestEntry;
  LI:     Integer;
begin
  LEntry.TestName    := ATestName;
  LEntry.CanRun      := ACanRun;
  LEntry.DefineName  := ADefine;
  LEntry.DefineValue := ADefineValue;
  SetLength(LEntry.Dependencies, Length(ADependencies));
  for LI := 0 to High(ADependencies) do
    LEntry.Dependencies[LI] := ADependencies[LI];
  FRegisteredTests.Add(LEntry);
end;

procedure TMyraTester.ClearRegisteredTests();
begin
  FRegisteredTests.Clear();
end;

procedure TMyraTester.LoadConfig();
var
  LConfig:      TConfig;
  LPath:        string;
  LCount:       Integer;
  LI:           Integer;
  LName:        string;
  LDeps:        TArray<string>;
  LCanRun:      Boolean;
  LDefine:      string;
  LDefineValue: string;
begin
  // Derive config path from test folder if not set explicitly
  if FConfigPath <> '' then
    LPath := FConfigPath
  else
    LPath := TPath.Combine(FTestFolder, 'tests.toml');

  if not TFile.Exists(LPath) then
    Exit;

  LConfig := TConfig.Create();
  try
    if not LConfig.LoadFromFile(LPath) then
      Exit;

    LCount := LConfig.GetTableCount('test');
    for LI := 0 to LCount - 1 do
    begin
      LName         := LConfig.GetTableString('test', LI, 'name');
      LDeps         := LConfig.GetTableStringArray('test', LI, 'deps');
      LCanRun       := LConfig.GetTableBoolean('test', LI, 'run', True);
      LDefine       := LConfig.GetTableString('test', LI, 'define');
      LDefineValue  := LConfig.GetTableString('test', LI, 'define_value');

      if LName = '' then
        Continue;

      if Length(LDeps) > 0 then
        RegisterTests(LName, LDeps, LCanRun, LDefine, LDefineValue)
      else
        RegisterTest(LName, LCanRun, LDefine, LDefineValue);
    end;
  finally
    LConfig.Free();
  end;
end;

procedure TMyraTester.SaveConfig();
var
  LConfig: TConfig;
  LPath:   string;
  LI:      Integer;
  LIdx:    Integer;
  LEntry:  TTestEntry;
begin
  // Derive config path from test folder if not set explicitly
  if FConfigPath <> '' then
    LPath := FConfigPath
  else
    LPath := TPath.Combine(FTestFolder, 'tests.toml');

  LConfig := TConfig.Create();
  try
    for LI := 0 to FRegisteredTests.Count - 1 do
    begin
      LEntry := FRegisteredTests[LI];
      LIdx   := LConfig.AddTableEntry('test');

      LConfig.SetTableString('test', LIdx, 'name', LEntry.TestName);

      if Length(LEntry.Dependencies) > 0 then
        LConfig.SetTableStringArray('test', LIdx, 'deps', LEntry.Dependencies);

      if not LEntry.CanRun then
        LConfig.SetTableBoolean('test', LIdx, 'run', False);

      if LEntry.DefineName <> '' then
      begin
        LConfig.SetTableString('test', LIdx, 'define', LEntry.DefineName);
        if LEntry.DefineValue <> '' then
          LConfig.SetTableString('test', LIdx, 'define_value', LEntry.DefineValue);
      end;
    end;

    LConfig.SaveToFile(LPath);
  finally
    LConfig.Free();
  end;
end;

function TMyraTester.GetFailedTests(): TArray<string>;
begin
  Result := FFailedTests.ToArray();
end;

function TMyraTester.GetRegisteredTestCount(): Integer;
begin
  Result := FRegisteredTests.Count;
end;

procedure TMyraTester.Print(const AText: string);
begin
  if Assigned(FOutputCallback) then
    FOutputCallback(AText)
  else
    TUtils.PrintLn(AText);
end;

procedure TMyraTester.Print(const AFormat: string; const AArgs: array of const);
begin
  Print(Format(AFormat, AArgs));
end;

function TMyraTester.ExtractExpected(const ASource: string): string;
var
  LStart:  Integer;
  LEnd:    Integer;
  LBlock:  string;
  LPrefix: string;
begin
  Result  := '';
  LPrefix := FCommentOpen + ' EXPECT:';

  LStart := Pos(LPrefix, ASource);
  if LStart = 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd   := Pos(FCommentClose, ASource, LStart);
  if LEnd = 0 then
    Exit;

  LBlock := Copy(ASource, LStart, LEnd - LStart);
  Result := Trim(LBlock);
end;

function TMyraTester.ExtractExpectedExitCode(const ASource: string): Integer;
var
  LStart:  Integer;
  LEnd:    Integer;
  LValue:  string;
  LPrefix: string;
begin
  Result  := 0;
  LPrefix := FCommentOpen + ' EXITCODE:';

  LStart := Pos(LPrefix, ASource);
  if LStart = 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd   := Pos(FCommentClose, ASource, LStart);
  if LEnd = 0 then
    Exit;

  LValue := Trim(Copy(ASource, LStart, LEnd - LStart));
  Result := StrToIntDef(LValue, 0);
end;

function TMyraTester.ExtractAllowWarnings(const ASource: string): Boolean;
begin
  Result := ASource.Contains(FCommentOpen + ' ALLOW_WARNINGS ' + FCommentClose);
end;

function TMyraTester.ExtractPlatforms(const ASource: string): TArray<string>;
var
  LStart:  Integer;
  LEnd:    Integer;
  LBlock:  string;
  LPrefix: string;
  LParts:  TArray<string>;
  LI:      Integer;
begin
  SetLength(Result, 0);
  LPrefix := FCommentOpen + ' PLATFORMS:';

  LStart := Pos(LPrefix, ASource);
  if LStart = 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd   := Pos(FCommentClose, ASource, LStart);
  if LEnd = 0 then
    Exit;

  LBlock := Trim(Copy(ASource, LStart, LEnd - LStart));
  LParts := LBlock.Split([',']);

  SetLength(Result, Length(LParts));
  for LI := 0 to High(LParts) do
    Result[LI] := Trim(LParts[LI]).ToUpper();
end;

function TMyraTester.PlatformMatchesCurrent(const APlatforms: TArray<string>): Boolean;
var
  LCurrentPlatform: string;
  LPlatform:        string;
begin
  // No platforms specified means run everywhere
  if Length(APlatforms) = 0 then
    Exit(True);

  // Map current target platform enum to its string name
  if FTargetPlatform = tpWin64 then
    LCurrentPlatform := 'WIN64'
  else if FTargetPlatform = tpLinux64 then
    LCurrentPlatform := 'LINUX64'
  else
    LCurrentPlatform := '';

  // Check if current platform is in the list
  Result := False;
  for LPlatform in APlatforms do
  begin
    if SameText(LPlatform, LCurrentPlatform) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TMyraTester.ExtractTestName(const AFilePath: string): string;
begin
  Result := TPath.GetFileNameWithoutExtension(AFilePath);
end;

function TMyraTester.RunTestFile(const AFilePath: string; const AAutoRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Boolean;
var
  LCompiler:         TMyraCompiler;
  LSource:           string;
  LExpected:         string;
  LExpectedExitCode: Integer;
  LAllowWarnings:    Boolean;
  LExitCode:         Cardinal;
  LTestName:         string;
  LBuildResult:      Boolean;
  LI:                Integer;
  LErrors:           TErrors;
  LItems:            TList<TError>;
begin
  Result           := False;
  FLastTestSkipped := False;

  if not TFile.Exists(AFilePath) then
  begin
    Print(COLOR_RED + 'ERROR: File not found: ' + AFilePath);
    Exit;
  end;

  LSource           := TFile.ReadAllText(AFilePath);
  LExpected         := ExtractExpected(LSource);
  LExpectedExitCode := ExtractExpectedExitCode(LSource);
  LAllowWarnings    := ExtractAllowWarnings(LSource);
  LTestName         := ExtractTestName(AFilePath);

  Print(COLOR_CYAN + '=== Test: ' + LTestName + ' ===');
  Print('');

  // Check platform requirements before doing any work
  if not PlatformMatchesCurrent(ExtractPlatforms(LSource)) then
  begin
    Print(COLOR_YELLOW + '  Skipped (not supported on current platform).');
    Print('');
    FLastTestSkipped := True;
    Exit;
  end;

  LCompiler := TMyraCompiler.Create();
  try
    // Configure compiler
    LCompiler.SetSourceFile(AFilePath);
    LCompiler.SetOutputPath(FOutputPath);
    LCompiler.SetTargetPlatform(FTargetPlatform);
    LCompiler.SetOptimizeLevel(FOptimizeLevel);
    LCompiler.SetSubsystem(FSubsystem);

    // Apply test-level define if specified
    if ADefine <> '' then
    begin
      if ADefineValue <> '' then
        LCompiler.SetDefine(ADefine, ADefineValue)
      else
        LCompiler.SetDefine(ADefine);
    end;

    // Set callbacks
    if FVerbose then
      LCompiler.SetStatusCallback(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          if Assigned(FOutputCallback) then
            FOutputCallback(AText)
          else
            TUtils.PrintLn(AText);
        end);

    LCompiler.SetOutputCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        if Assigned(FOutputCallback) then
          FOutputCallback(ALine)
        else
          TUtils.Print(ALine);
      end);

    // Build (compile + link, no auto-run)
    LBuildResult := LCompiler.Compile(True, False);  // ABuild=True, AAutoRun=False
    LErrors      := LCompiler.GetErrors();
    LItems       := LErrors.GetItems();

    // Display all messages (hints, warnings, errors, fatal)
    for LI := 0 to LErrors.Count() - 1 do
    begin
      case LItems[LI].Severity of
        esHint:
          Print(COLOR_CYAN   + '  ' + LItems[LI].ToFullString());
        esWarning:
          Print(COLOR_YELLOW + '  ' + LItems[LI].ToFullString());
        esError,
        esFatal:
          Print(COLOR_RED    + '  ' + LItems[LI].ToFullString());
      end;
    end;

    // Exit if build failed
    if not LBuildResult then
    begin
      Print(COLOR_RED + 'Build failed.');
      Exit;
    end;

    // Check for warnings (fail unless allowed)
    if LErrors.HasWarnings() and (not LAllowWarnings) then
    begin
      Print(COLOR_RED + 'Test failed: warnings present (use ' + FCommentOpen + ' ALLOW_WARNINGS ' + FCommentClose + ' to allow).');
      Exit;
    end;

    // Show success
    Print(COLOR_GREEN + '  Build OK');

    // Run if caller opted in via AAutoRun
    if AAutoRun then
    begin
      Print('');
      Print(COLOR_YELLOW + '[RUN]');
      Print(COLOR_CYAN + '--- Output ---');

      LErrors.Clear();
      LExitCode := LCompiler.Run();

      Print(COLOR_CYAN + '--- End ---');

      // Display any run-time errors
      for LI := 0 to LErrors.Count() - 1 do
      begin
        if (LItems[LI].Code = 'Z005') and (LExitCode = Cardinal(LExpectedExitCode)) then
          Continue;

        case LItems[LI].Severity of
          esHint:
            Print(COLOR_CYAN   + '  ' + LItems[LI].ToFullString());
          esWarning:
            Print(COLOR_YELLOW + '  ' + LItems[LI].ToFullString());
          esError:
            Print(COLOR_RED    + '  ' + LItems[LI].ToFullString());
          esFatal:
            Print(COLOR_CYAN   + '  ' + LItems[LI].ToFullString());
        end;
      end;
      Print('');

      // Check exit code
      if LExitCode <> Cardinal(LExpectedExitCode) then
      begin
        Print(COLOR_RED + Format('Test failed: expected exit code %d, got %d.', [LExpectedExitCode, LExitCode]));
        Exit;
      end;

      if LExpected <> '' then
      begin
        Print(COLOR_YELLOW + '[EXPECTED]');
        Print(LExpected);
      end;
      Print('');
    end;

    Result := True;

    // Allow ConPTY, WSL, and Zig cache to settle before the next test.
    Sleep(TEST_RUNNER_SETTLE_MS);
  finally
    LCompiler.Free();
  end;
end;

function TMyraTester.RunTest(const ATestName: string; const ACanRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Boolean;
var
  LFilePath: string;
  LI:        Integer;
  LDep:      string;
begin
  // Look up registered entry — if it has dependencies, build them first
  for LI := 0 to FRegisteredTests.Count - 1 do
  begin
    if SameText(FRegisteredTests[LI].TestName, ATestName) then
    begin
      for LDep in FRegisteredTests[LI].Dependencies do
      begin
        if not RunTest(LDep, False) then
        begin
          Result := False;
          Exit;
        end;
        Print('');
        Print(COLOR_BLUE + '----------------------------------------');
        Print('');
      end;
      Break;
    end;
  end;

  LFilePath := TPath.Combine(FTestFolder, TPath.ChangeExtension(ATestName, MYRA_EXT));
  Result    := RunTestFile(LFilePath, ACanRun, ADefine, ADefineValue);
  if FLastTestSkipped then
    Inc(FSkipCount)
  else if Result then
    Inc(FPassCount)
  else
  begin
    Inc(FFailCount);
    FFailedTests.Add(ATestName);
  end;
end;

function TMyraTester.RunTestByIndex(const AIndex: Integer): Boolean;
var
  LEntry: TTestEntry;
begin
  Result := True;
  if AIndex < 0 then
  begin
    RunAllTests();
    Exit(FFailCount = 0);
  end;

  if AIndex >= FRegisteredTests.Count then
  begin
    Print(COLOR_RED + Format('ERROR: Test index %d out of range (0..%d)', [AIndex, FRegisteredTests.Count - 1]));
    Exit(False);
  end;

  Reset();
  LEntry := FRegisteredTests[AIndex];
  Print(COLOR_CYAN + Format('Running test #%d...', [AIndex]));
  Print('');

  if not RunTest(LEntry.TestName, LEntry.CanRun, LEntry.DefineName, LEntry.DefineValue) then
    Result := False;

  Print('');
  PrintResults();
end;

function TMyraTester.RunTests(const ATestNames: array of string; const ACanRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Integer;
var
  LName:  string;
  LTotal: Integer;
begin
  Reset();
  LTotal := Length(ATestNames);

  Print(COLOR_CYAN + Format('Running %d test(s)...', [LTotal]));
  Print('');

  for LName in ATestNames do
  begin
    RunTest(LName, ACanRun, ADefine, ADefineValue);
    Print('');
    Print(COLOR_BLUE + '----------------------------------------');
    Print('');
  end;

  PrintResults();
  Result := FPassCount;
end;

function TMyraTester.RunAllTests(): Integer;
var
  LFiles: TStringDynArray;
  LFile:  string;
  LTotal: Integer;
  LEntry: TTestEntry;
  LI:     Integer;
begin
  Reset();

  if not TDirectory.Exists(FTestFolder) then
  begin
    Print(COLOR_RED + 'ERROR: Test folder not found: ' + FTestFolder);
    Exit(0);
  end;

  // If tests have been registered, run them in registration order
  // honouring each entry's CanRun flag
  if FRegisteredTests.Count > 0 then
  begin
    LTotal := FRegisteredTests.Count;
    Print(COLOR_CYAN + Format('Running %d registered test(s) in order...', [LTotal]));
    Print('');

    for LI := 0 to FRegisteredTests.Count - 1 do
    begin
      LEntry := FRegisteredTests[LI];
      RunTest(LEntry.TestName, LEntry.CanRun, LEntry.DefineName, LEntry.DefineValue);
      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end
  else
  begin
    // No registered tests - scan directory (alphabetical, backward compatible)
    // Directory scan defaults to build-only (ACanRun = False)
    LFiles := TDirectory.GetFiles(FTestFolder, 'test_*.' + MYRA_EXT);
    TArray.Sort<string>(LFiles);
    LTotal := Length(LFiles);

    Print(COLOR_CYAN + Format('Found %d test(s) in %s', [LTotal, FTestFolder]));
    Print('');

    for LFile in LFiles do
    begin
      if RunTestFile(LFile, False) then
        Inc(FPassCount)
      else if FLastTestSkipped then
        Inc(FSkipCount)
      else
      begin
        Inc(FFailCount);
        FFailedTests.Add(TPath.GetFileNameWithoutExtension(LFile));
      end;
      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end;

  PrintResults();
  Result := FPassCount;
end;

function TMyraTester.RunTestsMatching(const APattern: string; const ACanRun: Boolean = False; const ADefine: string = ''; const ADefineValue: string = ''): Integer;
var
  LFiles: TStringDynArray;
  LFile:  string;
begin
  Reset();

  if not TDirectory.Exists(FTestFolder) then
  begin
    Print(COLOR_RED + 'ERROR: Test folder not found: ' + FTestFolder);
    Exit(0);
  end;

  LFiles := TDirectory.GetFiles(FTestFolder, 'test_*.' + MYRA_EXT);
  TArray.Sort<string>(LFiles);

  for LFile in LFiles do
  begin
    if Pos(APattern, TPath.GetFileName(LFile)) > 0 then
    begin
      if RunTestFile(LFile, ACanRun, ADefine, ADefineValue) then
        Inc(FPassCount)
      else if FLastTestSkipped then
        Inc(FSkipCount)
      else
      begin
        Inc(FFailCount);
        FFailedTests.Add(TPath.GetFileNameWithoutExtension(LFile));
      end;
      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end;

  Print('Pattern: ' + APattern);
  PrintResults();
  Result := FPassCount;
end;

procedure TMyraTester.PrintResults();
var
  LTotal: Integer;
  LI:     Integer;
begin
  LTotal := FPassCount + FFailCount + FSkipCount;

  Print('');
  Print(COLOR_CYAN + '=== RESULTS ===');
  if FFailCount = 0 then
  begin
    Print(COLOR_GREEN + Format('Passed: %d / %d', [FPassCount, LTotal]));
    if FSkipCount > 0 then
      Print(COLOR_YELLOW + Format('Skipped: %d', [FSkipCount]));
  end
  else
  begin
    Print(COLOR_RED + Format('Passed: %d / %d', [FPassCount, LTotal]));
    if FSkipCount > 0 then
      Print(COLOR_YELLOW + Format('Skipped: %d', [FSkipCount]));
    Print('');
    Print(COLOR_RED + 'Failed tests:');
    for LI := 0 to FFailedTests.Count - 1 do
      Print(COLOR_RED + '  - ' + FFailedTests[LI]);
  end;
end;

end.
