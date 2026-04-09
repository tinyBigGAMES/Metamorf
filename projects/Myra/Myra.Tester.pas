{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Myra.Tester;

{$I Metamorf.Defines.inc}

{===============================================================================
  Test File Comment Directives
  ---------------------------------------------------------------------------
  These special comment tokens are embedded in .myra test source files and
  are parsed by TMyraTester before invoking the engine.

  /* EXITCODE: <n> */
    Expected process exit code after running the compiled executable.
    Defaults to 0 if omitted. The test fails if the actual exit code differs.

  /* EXPECT:
    <text>
  */
    Expected stdout output. Displayed in the test runner output for manual
    comparison. Not automatically diffed -- for human review only.

  /* ALLOW_WARNINGS */
    Suppresses the "warnings present" failure. Use when a test intentionally
    produces compiler warnings.

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
  System.Types,
  System.IOUtils,
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.Build,
  Metamorf.Config,
  Metamorf.Resources,
  Metamorf.Engine;

const
  MYRA_TEST_EXT         = '.myra';
  MYRA_DEFAULT_LANG     = '..\projects\Myra\mor\myra.mor';
  MYRA_DEFAULT_TESTS    = '..\projects\Myra\tests';
  MYRA_COMMENT_OPEN     = '/*';
  MYRA_COMMENT_CLOSE    = '*/';
  MOR_TESTS_TOML        = 'tests.toml';

type
  { TTestEntry }
  TTestEntry = record
    TestName:     string;
    Dependencies: TArray<string>;
    RunMode:      TMorRunMode;
    DefineName:   string;
    DefineValue:  string;
  end;

  { TMyraTester }
  TMyraTester = class(TMorOutputObject)
  private
    FLangFile:        string;
    FTestFolder:      string;
    FOutputPath:      string;
    FTarget:          TMorTargetPlatform;
    FOptimizeLevel:   TMorOptimizeLevel;
    FSubsystem:       TMorSubsystemType;
    FVerbose:         Boolean;
    FPassCount:       Integer;
    FFailCount:       Integer;
    FSkipCount:       Integer;
    FLastTestSkipped: Boolean;
    FFailedTests:     TList<string>;
    FRegisteredTests: TDictionary<Integer, TTestEntry>;
    FOutputCallback:  TProc<string>;
    FConfig:          TMorConfig;

    function ExtractExpected(const ASource: string): string;
    function ExtractExpectedExitCode(const ASource: string): Integer;
    function ExtractAllowWarnings(const ASource: string): Boolean;
    function ExtractPlatforms(const ASource: string): TArray<string>;
    function PlatformMatchesCurrent(const APlatforms: TArray<string>): Boolean;
    function ExtractTestName(const AFilePath: string): string;
    function RunTestFile(const AFilePath: string;
      const ARunMode: TMorRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = ''): Boolean;
    procedure PrintResults();
    procedure Print(const AText: string); overload;
    {$HINTS OFF}
    procedure Print(const AFormat: string;
      const AArgs: array of const); overload;
    {$HINTS ON}
    function GetFailedTests(): TArray<string>;
    function GetRegisteredTestCount(): Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Registration (indexed, ordered execution)
    procedure RegisterTest(const AIndex: Integer;
      const ATestName: string;
      const ARunMode: TMorRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = '');
    procedure RegisterTests(const AIndex: Integer;
      const ATestName: string;
      const ADependencies: array of string;
      const ARunMode: TMorRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = '');
    procedure ClearRegisteredTests();

    // Execution
    function RunTest(const ATestName: string;
      const ARunMode: TMorRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = ''): Boolean;
    function RunTestByIndex(const AIndex: Integer; const ATarget: TMorTargetPlatform=tpWin64; const AOptimizeLevel: TMorOptimizeLevel=olDebug; const ASubsystem: TMorSubsystemType=stConsole): Boolean;
    function RunAllTests(): Integer;
    function RunTestsMatching(const APattern: string;
      const ARunMode: TMorRunMode = rmNone): Integer;

    // State
    procedure Reset();

    // TOML persistence
    procedure SaveTests(const AFilename: string = MOR_TESTS_TOML);
    function LoadTests(const AFilename: string = MOR_TESTS_TOML): Boolean;

    // Properties
    property LangFile:        string          read FLangFile        write FLangFile;
    property TestFolder:      string          read FTestFolder      write FTestFolder;
    property OutputPath:      string          read FOutputPath      write FOutputPath;
    property Target:          TMorTargetPlatform read FTarget          write FTarget;
    property OptimizeLevel:   TMorOptimizeLevel  read FOptimizeLevel   write FOptimizeLevel;
    property Subsystem:       TMorSubsystemType  read FSubsystem       write FSubsystem;
    property Verbose:         Boolean         read FVerbose         write FVerbose;
    property OutputCallback:  TProc<string>   read FOutputCallback  write FOutputCallback;
    property PassCount:       Integer         read FPassCount;
    property FailCount:       Integer         read FFailCount;
    property SkipCount:       Integer         read FSkipCount;
    property FailedTests:     TArray<string>  read GetFailedTests;
    property RegisteredTestCount: Integer     read GetRegisteredTestCount;
  end;

implementation

uses
  Metamorf.Debug.REPL;

const
  // Delay between test runs to allow ConPTY, WSL, and Zig cache resources
  // to fully release before the next test fires up its own process.
  TEST_RUNNER_SETTLE_MS = 500;

{ TMyraTester }

constructor TMyraTester.Create();
begin
  inherited;
  FFailedTests     := TList<string>.Create();
  FRegisteredTests := TDictionary<Integer, TTestEntry>.Create();
  FVerbose         := True;
  FOutputPath      := 'output';
  FTarget          := tpWin64;
  FOptimizeLevel   := olDebug;
  FSubsystem       := stConsole;
  FLangFile        := MYRA_DEFAULT_LANG;
  FTestFolder      := MYRA_DEFAULT_TESTS;
  FConfig          := nil;
end;

destructor TMyraTester.Destroy();
begin
  FConfig.Free();
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

procedure TMyraTester.RegisterTest(const AIndex: Integer;
  const ATestName: string; const ARunMode: TMorRunMode;
  const ADefine: string; const ADefineValue: string);
var
  LEntry: TTestEntry;
  LKey:   Integer;
  LMax:   Integer;
  LK:     Integer;
begin
  LEntry.TestName     := ATestName;
  LEntry.Dependencies := [];
  LEntry.RunMode      := ARunMode;
  LEntry.DefineName   := ADefine;
  LEntry.DefineValue  := ADefineValue;

  if AIndex >= 0 then
    LKey := AIndex
  else
  begin
    LMax := -1;
    for LK in FRegisteredTests.Keys do
      if LK > LMax then
        LMax := LK;
    LKey := LMax + 1;
  end;

  FRegisteredTests.AddOrSetValue(LKey, LEntry);
end;

procedure TMyraTester.RegisterTests(const AIndex: Integer;
  const ATestName: string; const ADependencies: array of string;
  const ARunMode: TMorRunMode; const ADefine: string;
  const ADefineValue: string);
var
  LEntry: TTestEntry;
  LI:     Integer;
  LKey:   Integer;
  LMax:   Integer;
  LK:     Integer;
begin
  LEntry.TestName    := ATestName;
  LEntry.RunMode     := ARunMode;
  LEntry.DefineName  := ADefine;
  LEntry.DefineValue := ADefineValue;
  SetLength(LEntry.Dependencies, Length(ADependencies));
  for LI := 0 to High(ADependencies) do
    LEntry.Dependencies[LI] := ADependencies[LI];

  if AIndex >= 0 then
    LKey := AIndex
  else
  begin
    LMax := -1;
    for LK in FRegisteredTests.Keys do
      if LK > LMax then
        LMax := LK;
    LKey := LMax + 1;
  end;

  FRegisteredTests.AddOrSetValue(LKey, LEntry);
end;

procedure TMyraTester.ClearRegisteredTests();
begin
  FRegisteredTests.Clear();
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
    TMorUtils.PrintLn(AText);
end;

procedure TMyraTester.Print(const AFormat: string;
  const AArgs: array of const);
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
  LPrefix := MYRA_COMMENT_OPEN + ' EXPECT:';

  LStart := Pos(LPrefix, ASource);
  if LStart = 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd   := Pos(MYRA_COMMENT_CLOSE, ASource, LStart);
  if LEnd = 0 then
    Exit;

  LBlock := Copy(ASource, LStart, LEnd - LStart);
  Result := Trim(LBlock);
end;

function TMyraTester.ExtractExpectedExitCode(
  const ASource: string): Integer;
var
  LStart:  Integer;
  LEnd:    Integer;
  LValue:  string;
  LPrefix: string;
begin
  Result  := 0;
  LPrefix := MYRA_COMMENT_OPEN + ' EXITCODE:';

  LStart := Pos(LPrefix, ASource);
  if LStart = 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd   := Pos(MYRA_COMMENT_CLOSE, ASource, LStart);
  if LEnd = 0 then
    Exit;

  LValue := Trim(Copy(ASource, LStart, LEnd - LStart));
  Result := StrToIntDef(LValue, 0);
end;

function TMyraTester.ExtractAllowWarnings(
  const ASource: string): Boolean;
begin
  Result := ASource.Contains(
    MYRA_COMMENT_OPEN + ' ALLOW_WARNINGS ' + MYRA_COMMENT_CLOSE);
end;

function TMyraTester.ExtractPlatforms(
  const ASource: string): TArray<string>;
var
  LStart:  Integer;
  LEnd:    Integer;
  LBlock:  string;
  LPrefix: string;
  LParts:  TArray<string>;
  LI:      Integer;
begin
  SetLength(Result, 0);
  LPrefix := MYRA_COMMENT_OPEN + ' PLATFORMS:';

  LStart := Pos(LPrefix, ASource);
  if LStart = 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd := Pos(MYRA_COMMENT_CLOSE, ASource, LStart);
  if LEnd = 0 then
    Exit;

  LBlock := Trim(Copy(ASource, LStart, LEnd - LStart));
  LParts := LBlock.Split([',']);

  SetLength(Result, Length(LParts));
  for LI := 0 to High(LParts) do
    Result[LI] := Trim(LParts[LI]).ToUpper();
end;

function TMyraTester.PlatformMatchesCurrent(
  const APlatforms: TArray<string>): Boolean;
var
  LCurrentPlatform: string;
  LPlatform:        string;
begin
  // No platforms specified means run everywhere
  if Length(APlatforms) = 0 then
    Exit(True);

  // Map current target platform enum to its string name
  if FTarget = tpWin64 then
    LCurrentPlatform := 'WIN64'
  else if FTarget = tpLinux64 then
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

function TMyraTester.RunTestFile(const AFilePath: string;
  const ARunMode: TMorRunMode; const ADefine: string;
  const ADefineValue: string): Boolean;
var
  LEngine:           TMorEngine;
  LSource:           string;
  LExpected:         string;
  LExpectedExitCode: Integer;
  LAllowWarnings:    Boolean;
  LExitCode:         DWORD;
  LTestName:         string;
  LErrors:           TMorErrors;
  LItems:            TList<TMorError>;
  LI:                Integer;
  LOutputShown:      Boolean;
  LOnlyExecError:    Boolean;
  LExePath:          string;
  LREPL:             TMorDebugREPL;
begin
  Result           := False;
  FLastTestSkipped := False;
  LOutputShown     := False;

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

  LEngine := TMorEngine.Create();
  try
    // Configure engine
    LEngine.SetTarget(FTarget);
    LEngine.SetOptimizeLevel(FOptimizeLevel);
    LEngine.SetSubsystem(FSubsystem);

    // Apply test-level define if specified
    if ADefine <> '' then
    begin
      if ADefineValue <> '' then
        LEngine.SetDefine(ADefine, ADefineValue)
      else
        LEngine.SetDefine(ADefine);
    end;

    // Set callbacks
    if FVerbose then
      LEngine.SetStatusCallback(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          if Assigned(FOutputCallback) then
            FOutputCallback(AText)
          else
            TMorUtils.PrintLn(AText);
        end);

    LEngine.SetOutputCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        if not LOutputShown then
        begin
          Print(COLOR_YELLOW + '[OUTPUT]');
          LOutputShown := True;
        end;
        if Assigned(FOutputCallback) then
          FOutputCallback(ALine)
        else
          TMorUtils.Print(ALine);
      end);

    // Compile (and optionally run)
    LEngine.Compile(FLangFile, AFilePath, FOutputPath,
      ARunMode = rmExecute);
    LErrors := LEngine.GetErrors();
    LItems  := LErrors.GetItems();

    // Display all messages (hints, warnings, errors, fatal)
    // Suppress Z005 (execution exit code) when a non-zero exit code is expected
    for LI := 0 to LErrors.Count() - 1 do
    begin
      if (LExpectedExitCode <> 0) and (LItems[LI].Severity = esError) and
         (LItems[LI].Code = ERR_ZIGBUILD_BUILD_FAILED) then
        Continue;
      if LItems[LI].Severity = esHint then
        Print(COLOR_CYAN + '  ' + LItems[LI].ToFullString())
      else if LItems[LI].Severity = esWarning then
        Print(COLOR_YELLOW + '  ' + LItems[LI].ToFullString())
      else
        Print(COLOR_RED + '  ' + LItems[LI].ToFullString());
    end;

    // Exit if build failed
    // Tolerate execution exit code error (Z005) when expected exit code
    // is non-zero and matches the actual exit code
    if LErrors.HasErrors() then
    begin
      LOnlyExecError := False;
      if LExpectedExitCode <> 0 then
      begin
        LExitCode := LEngine.GetLastExitCode();
        if LExitCode = DWORD(LExpectedExitCode) then
        begin
          LOnlyExecError := True;
          for LI := 0 to LItems.Count - 1 do
          begin
            if (LItems[LI].Severity = esError) and
               (LItems[LI].Code <> ERR_ZIGBUILD_BUILD_FAILED) then
            begin
              LOnlyExecError := False;
              Break;
            end;
          end;
        end;
      end;
      if not LOnlyExecError then
      begin
        Print(COLOR_RED + 'Build failed.');
        Exit;
      end;
    end;

    // Check for warnings (fail unless allowed)
    if LErrors.HasWarnings() and (not LAllowWarnings) then
    begin
      Print(COLOR_RED + 'Test failed: warnings present (use ' +
        MYRA_COMMENT_OPEN + ' ALLOW_WARNINGS ' +
        MYRA_COMMENT_CLOSE + ' to allow).');
      Exit;
    end;

    // Show success
    Print(COLOR_GREEN + '  Build OK');

    // Check exit code if the test was run
    if ARunMode = rmExecute then
    begin
      Print('');
      LExitCode := LEngine.GetLastExitCode();

      if LExitCode <> DWORD(LExpectedExitCode) then
      begin
        Print(COLOR_RED + Format(
          'Test failed: expected exit code %d, got %d.',
          [LExpectedExitCode, LExitCode]));
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

    // Launch debug REPL if requested and build succeeded
    if ARunMode = rmDebug then
    begin
      if LEngine.GetTarget() <> tpWin64 then
        Print(COLOR_RED + 'Error: ' + RSEngineAPIDebugWin64)
      else
      begin
        LExePath := TPath.GetFullPath(
          TPath.Combine(FOutputPath, 'zig-out\bin\' +
            LEngine.GetProjectName() + '.exe'));
        if FileExists(LExePath) then
        begin
          LREPL := TMorDebugREPL.Create();
          try
            LREPL.Run(LExePath);
          finally
            LREPL.Free();
          end;
        end
        else
          Print(COLOR_RED + 'Executable not found: ' + LExePath);
      end;
    end;

    // Allow ConPTY, WSL, and Zig cache to settle before the next test
    Sleep(TEST_RUNNER_SETTLE_MS);
  finally
    LEngine.Free();
  end;
end;

function TMyraTester.RunTest(const ATestName: string;
  const ARunMode: TMorRunMode; const ADefine: string;
  const ADefineValue: string): Boolean;
var
  LFilePath: string;
  LEntry:    TTestEntry;
  LDep:      string;
begin
  // Look up registered entry -- if it has dependencies, build them first
  for LEntry in FRegisteredTests.Values do
  begin
    if SameText(LEntry.TestName, ATestName) then
    begin
      for LDep in LEntry.Dependencies do
      begin
        if not RunTest(LDep, rmNone) then
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

  LFilePath := TPath.Combine(FTestFolder,
    TPath.ChangeExtension(ATestName, MYRA_TEST_EXT));
  Result := RunTestFile(LFilePath, ARunMode, ADefine, ADefineValue);
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

function TMyraTester.RunTestByIndex(const AIndex: Integer; const ATarget: TMorTargetPlatform; const AOptimizeLevel: TMorOptimizeLevel; const ASubsystem: TMorSubsystemType): Boolean;
var
  LEntry: TTestEntry;
begin
  Result := True;
  if AIndex < 0 then
  begin
    RunAllTests();
    Exit(FFailCount = 0);
  end;

  if not FRegisteredTests.TryGetValue(AIndex, LEntry) then
  begin
    Print(COLOR_RED + Format('ERROR: Test index %d not found', [AIndex]));
    Exit(False);
  end;

  Reset();
  Print(COLOR_CYAN + Format('Running test #%d...', [AIndex]));
  Print('');

  Target := ATarget;
  OptimizeLevel := AOptimizeLevel;
  Subsystem := ASubsystem;

  if not RunTest(LEntry.TestName, LEntry.RunMode,
    LEntry.DefineName, LEntry.DefineValue) then
    Result := False;

  Print('');
  PrintResults();
end;

function TMyraTester.RunAllTests(): Integer;
var
  LFiles:      TStringDynArray;
  LFile:       string;
  LTotal:      Integer;
  LEntry:      TTestEntry;
  LI:          Integer;
  LSortedKeys: TArray<Integer>;
begin
  Reset();

  if not TDirectory.Exists(FTestFolder) then
  begin
    Print(COLOR_RED + 'ERROR: Test folder not found: ' + FTestFolder);
    Exit(0);
  end;

  // If tests have been registered, run them in key order
  if FRegisteredTests.Count > 0 then
  begin
    LTotal := FRegisteredTests.Count;
    Print(COLOR_CYAN + Format(
      'Running %d registered test(s) in order...', [LTotal]));
    Print('');

    LSortedKeys := FRegisteredTests.Keys.ToArray();
    TArray.Sort<Integer>(LSortedKeys);

    for LI := 0 to High(LSortedKeys) do
    begin
      LEntry := FRegisteredTests[LSortedKeys[LI]];
      RunTest(LEntry.TestName, LEntry.RunMode,
        LEntry.DefineName, LEntry.DefineValue);
      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end
  else
  begin
    // No registered tests -- scan directory (alphabetical)
    // Directory scan defaults to build-only (rmNone)
    LFiles := TDirectory.GetFiles(FTestFolder, 'test_*' + MYRA_TEST_EXT);
    TArray.Sort<string>(LFiles);
    LTotal := Length(LFiles);

    Print(COLOR_CYAN + Format(
      'Found %d test(s) in %s', [LTotal, FTestFolder]));
    Print('');

    for LFile in LFiles do
    begin
      if RunTestFile(LFile, rmNone) then
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

function TMyraTester.RunTestsMatching(const APattern: string;
  const ARunMode: TMorRunMode): Integer;
var
  LFiles:    TStringDynArray;
  LFile:     string;
  LTestName: string;
  LEntry:    TTestEntry;
  LRunMode:  TMorRunMode;
  LDefine:   string;
  LDefVal:   string;
  LFound:    Boolean;
  LKey:      Integer;
begin
  Reset();

  if not TDirectory.Exists(FTestFolder) then
  begin
    Print(COLOR_RED + 'ERROR: Test folder not found: ' + FTestFolder);
    Exit(0);
  end;

  LFiles := TDirectory.GetFiles(FTestFolder, 'test_*' + MYRA_TEST_EXT);
  TArray.Sort<string>(LFiles);

  for LFile in LFiles do
  begin
    if Pos(APattern, TPath.GetFileName(LFile)) > 0 then
    begin
      LTestName := TPath.GetFileNameWithoutExtension(LFile);

      // Look up registered entry to use its RunMode/Define/DefineValue
      LRunMode := ARunMode;
      LDefine  := '';
      LDefVal  := '';
      LFound   := False;
      for LKey in FRegisteredTests.Keys do
      begin
        LEntry := FRegisteredTests[LKey];
        if SameText(LEntry.TestName, LTestName) then
        begin
          LRunMode := LEntry.RunMode;
          LDefine  := LEntry.DefineName;
          LDefVal  := LEntry.DefineValue;
          LFound   := True;
          Break;
        end;
      end;

      if RunTestFile(LFile, LRunMode, LDefine, LDefVal) then
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

procedure TMyraTester.SaveTests(const AFilename: string);
var
  LNewConfig:   TMorConfig;
  LPath:        string;
  LKeys:        TArray<Integer>;
  LI:           Integer;
  LIdx:         Integer;
  LEntry:       TTestEntry;
  LOldCount:    Integer;
  LOldName:     string;
  LOldComment:  string;
  LComments:    TDictionary<string, string>;
  LFileComment: string;
begin
  LPath := TPath.Combine(FTestFolder, AFilename);

  // Extract comments from current FConfig (if loaded)
  LComments := TDictionary<string, string>.Create();
  LFileComment := '';
  try
    if Assigned(FConfig) then
    begin
      LFileComment := FConfig.GetFileComment();
      LOldCount := FConfig.GetTableCount('test');
      for LI := 0 to LOldCount - 1 do
      begin
        LOldName    := FConfig.GetTableString('test', LI, 'name');
        LOldComment := FConfig.GetTableComment('test', LI);
        if (LOldName <> '') and (LOldComment <> '') then
          LComments.AddOrSetValue(LOldName, LOldComment);
      end;
    end;

    // Build new config from current registrations
    LKeys := FRegisteredTests.Keys.ToArray();
    TArray.Sort<Integer>(LKeys);

    LNewConfig := TMorConfig.Create();
    try
      if LFileComment <> '' then
        LNewConfig.SetFileComment(LFileComment);

      for LI := 0 to High(LKeys) do
      begin
        LEntry := FRegisteredTests[LKeys[LI]];
        LIdx := LNewConfig.AddTableEntry('test');

        LNewConfig.SetTableInteger('test', LIdx, 'index', LKeys[LI]);
        LNewConfig.SetTableString('test', LIdx, 'name', LEntry.TestName);

        if Length(LEntry.Dependencies) > 0 then
          LNewConfig.SetTableStringArray('test', LIdx, 'deps',
            LEntry.Dependencies);

        if LEntry.RunMode = rmNone then
          LNewConfig.SetTableString('test', LIdx, 'run_mode', 'none')
        else if LEntry.RunMode = rmDebug then
          LNewConfig.SetTableString('test', LIdx, 'run_mode', 'debug');

        if LEntry.DefineName <> '' then
          LNewConfig.SetTableString('test', LIdx, 'define',
            LEntry.DefineName);

        if LEntry.DefineValue <> '' then
          LNewConfig.SetTableString('test', LIdx, 'define_value',
            LEntry.DefineValue);

        // Restore comment if name matches
        if LComments.TryGetValue(LEntry.TestName, LOldComment) then
          LNewConfig.SetTableComment('test', LIdx, LOldComment);
      end;

      LNewConfig.SaveToFile(LPath);

      // Replace FConfig with the new state
      FreeAndNil(FConfig);
      FConfig := LNewConfig;
      LNewConfig := nil; // prevent double-free
    except
      LNewConfig.Free();
      raise;
    end;
  finally
    LComments.Free();
  end;
end;

function TMyraTester.LoadTests(const AFilename: string): Boolean;
var
  LPath:        string;
  LCount:       Integer;
  LI:           Integer;
  LIndex:       Integer;
  LName:        string;
  LDeps:        TArray<string>;
  LRunModeStr:  string;
  LRunMode:     TMorRunMode;
  LRunBool:     Boolean;
  LDefine:      string;
  LDefineValue: string;
  LEntry:       TTestEntry;
begin
  Result := False;
  LPath := TPath.Combine(FTestFolder, AFilename);

  if not TFile.Exists(LPath) then
    Exit;

  // Free previous config, load fresh from disk
  FreeAndNil(FConfig);
  FConfig := TMorConfig.Create();

  if not FConfig.LoadFromFile(LPath) then
  begin
    FreeAndNil(FConfig);
    Exit;
  end;

  LCount := FConfig.GetTableCount('test');
  if LCount = 0 then
  begin
    FreeAndNil(FConfig);
    Exit;
  end;

  ClearRegisteredTests();

  for LI := 0 to LCount - 1 do
  begin
    LName := FConfig.GetTableString('test', LI, 'name');
    if LName = '' then
      Continue;

    LIndex       := FConfig.GetTableInteger('test', LI, 'index', LI);
    LDeps        := FConfig.GetTableStringArray('test', LI, 'deps');
    LDefine      := FConfig.GetTableString('test', LI, 'define');
    LDefineValue := FConfig.GetTableString('test', LI, 'define_value');

    // Determine run mode: prefer run_mode string, fall back to run bool
    LRunModeStr := FConfig.GetTableString('test', LI, 'run_mode');
    if LRunModeStr <> '' then
    begin
      if SameText(LRunModeStr, 'debug') then
        LRunMode := rmDebug
      else if SameText(LRunModeStr, 'none') then
        LRunMode := rmNone
      else
        LRunMode := rmExecute;
    end
    else
    begin
      LRunBool := FConfig.GetTableBoolean('test', LI, 'run', True);
      if LRunBool then
        LRunMode := rmExecute
      else
        LRunMode := rmNone;
    end;

    LEntry.TestName     := LName;
    LEntry.Dependencies := LDeps;
    LEntry.RunMode      := LRunMode;
    LEntry.DefineName   := LDefine;
    LEntry.DefineValue  := LDefineValue;

    FRegisteredTests.Add(LIndex, LEntry);
  end;

  Result := FRegisteredTests.Count > 0;
end;

end.
