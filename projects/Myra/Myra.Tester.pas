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
  Metamorf.Engine;

const
  MYRA_TEST_EXT         = '.myra';
  MYRA_DEFAULT_LANG     = '..\projects\Myra\mor\myra.mor';
  MYRA_DEFAULT_TESTS    = '..\projects\Myra\tests';
  MYRA_COMMENT_OPEN     = '/*';
  MYRA_COMMENT_CLOSE    = '*/';

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

    function ExtractExpected(const ASource: string): string;
    function ExtractExpectedExitCode(const ASource: string): Integer;
    function ExtractAllowWarnings(const ASource: string): Boolean;
    function ExtractTestName(const AFilePath: string): string;
    function RunTestFile(const AFilePath: string;
      const AAutoRun: Boolean = False;
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
      const ACanRun: Boolean = True;
      const ADefine: string = '';
      const ADefineValue: string = '');
    procedure RegisterTests(const AIndex: Integer;
      const ATestName: string;
      const ADependencies: array of string;
      const ACanRun: Boolean = True;
      const ADefine: string = '';
      const ADefineValue: string = '');
    procedure ClearRegisteredTests();

    // Execution
    function RunTest(const ATestName: string;
      const ACanRun: Boolean = False;
      const ADefine: string = '';
      const ADefineValue: string = ''): Boolean;
    function RunTestByIndex(const AIndex: Integer): Boolean;
    function RunAllTests(): Integer;
    function RunTestsMatching(const APattern: string;
      const ACanRun: Boolean = False): Integer;

    // State
    procedure Reset();

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

procedure TMyraTester.RegisterTest(const AIndex: Integer;
  const ATestName: string; const ACanRun: Boolean;
  const ADefine: string; const ADefineValue: string);
var
  LEntry: TTestEntry;
  LKey:   Integer;
  LMax:   Integer;
  LK:     Integer;
begin
  LEntry.TestName     := ATestName;
  LEntry.Dependencies := [];
  LEntry.CanRun       := ACanRun;
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
  const ACanRun: Boolean; const ADefine: string;
  const ADefineValue: string);
var
  LEntry: TTestEntry;
  LI:     Integer;
  LKey:   Integer;
  LMax:   Integer;
  LK:     Integer;
begin
  LEntry.TestName    := ATestName;
  LEntry.CanRun      := ACanRun;
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

function TMyraTester.ExtractTestName(const AFilePath: string): string;
begin
  Result := TPath.GetFileNameWithoutExtension(AFilePath);
end;

function TMyraTester.RunTestFile(const AFilePath: string;
  const AAutoRun: Boolean; const ADefine: string;
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
    LEngine.Compile(FLangFile, AFilePath, FOutputPath, AAutoRun);
    LErrors := LEngine.GetErrors();
    LItems  := LErrors.GetItems();

    // Display all messages (hints, warnings, errors, fatal)
    for LI := 0 to LErrors.Count() - 1 do
    begin
      if LItems[LI].Severity = esHint then
        Print(COLOR_CYAN + '  ' + LItems[LI].ToFullString())
      else if LItems[LI].Severity = esWarning then
        Print(COLOR_YELLOW + '  ' + LItems[LI].ToFullString())
      else
        Print(COLOR_RED + '  ' + LItems[LI].ToFullString());
    end;

    // Exit if build failed
    if LErrors.HasErrors() then
    begin
      Print(COLOR_RED + 'Build failed.');
      Exit;
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
    if AAutoRun then
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

    // Allow ConPTY, WSL, and Zig cache to settle before the next test
    Sleep(TEST_RUNNER_SETTLE_MS);
  finally
    LEngine.Free();
  end;
end;

function TMyraTester.RunTest(const ATestName: string;
  const ACanRun: Boolean; const ADefine: string;
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

  LFilePath := TPath.Combine(FTestFolder,
    TPath.ChangeExtension(ATestName, MYRA_TEST_EXT));
  Result := RunTestFile(LFilePath, ACanRun, ADefine, ADefineValue);
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

  if not FRegisteredTests.TryGetValue(AIndex, LEntry) then
  begin
    Print(COLOR_RED + Format('ERROR: Test index %d not found', [AIndex]));
    Exit(False);
  end;

  Reset();
  Print(COLOR_CYAN + Format('Running test #%d...', [AIndex]));
  Print('');

  if not RunTest(LEntry.TestName, LEntry.CanRun,
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
      RunTest(LEntry.TestName, LEntry.CanRun,
        LEntry.DefineName, LEntry.DefineValue);
      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end
  else
  begin
    // No registered tests -- scan directory (alphabetical)
    // Directory scan defaults to build-only (ACanRun = False)
    LFiles := TDirectory.GetFiles(FTestFolder, 'test_*' + MYRA_TEST_EXT);
    TArray.Sort<string>(LFiles);
    LTotal := Length(LFiles);

    Print(COLOR_CYAN + Format(
      'Found %d test(s) in %s', [LTotal, FTestFolder]));
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

function TMyraTester.RunTestsMatching(const APattern: string;
  const ACanRun: Boolean): Integer;
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

  LFiles := TDirectory.GetFiles(FTestFolder, 'test_*' + MYRA_TEST_EXT);
  TArray.Sort<string>(LFiles);

  for LFile in LFiles do
  begin
    if Pos(APattern, TPath.GetFileName(LFile)) > 0 then
    begin
      if RunTestFile(LFile, ACanRun) then
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
