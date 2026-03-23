{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit Myra.CLI;

interface

procedure RunCLI();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Metamorf.API,
  Myra.Common,
  Myra.Compiler,
  Myra.Tester;

type
  { TMyraCLI }
  TMyraCLI = class
  private
    FMyra:      TMyraCompiler;
    FSourceFile:   string;
    FOutputPath:   string;
    FBuild:        Boolean;
    FAutoRun:      Boolean;

    // Test subcommand state
    FTestFolder:   string;
    FTestSpec:     string;
    FTestPlatform: TTargetPlatform;
    FTestConfig:   string;

    procedure Print(const AText: string);
    procedure ShowBanner();

    // Compile subcommand
    procedure ShowCompileHelp();
    procedure ShowErrors();
    procedure SetupCallbacks();
    function  ParseCompileArgs(): Boolean;
    procedure RunCompile();

    // Test subcommand
    procedure ShowTestHelp();
    function  ParseTestArgs(): Boolean;
    procedure RunTestSuite();
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Execute();
  end;

{ TMyraCLI }

constructor TMyraCLI.Create();
begin
  inherited Create();
  FMyra      := nil;
  FSourceFile   := '';
  FOutputPath   := 'output';
  FBuild        := True;
  FAutoRun      := False;
  FTestFolder   := '';
  FTestSpec     := 'all';
  FTestPlatform := tpWin64;
  FTestConfig   := '';

  FMyra := TMyraCompiler.Create();
end;

destructor TMyraCLI.Destroy();
begin
  FreeAndNil(FMyra);
  inherited Destroy();
end;

procedure TMyraCLI.Print(const AText: string);
begin
  TUtils.PrintLn(AText);
end;

procedure TMyraCLI.ShowBanner();
begin
  Print(COLOR_WHITE + COLOR_BOLD + 'Myra™ Compiler for Win64 v' + FMyra.GetVersionStr());
  Print(COLOR_WHITE + 'Copyright © 2025-present tinyBigGAMES™ LLC. All Rights Reserved.');
  Print(COLOR_YELLOW + 'https://paxkit.org');
  Print('');
end;

{ --- Compile subcommand --- }

procedure TMyraCLI.ShowCompileHelp();
begin
  Print(COLOR_WHITE + 'Syntax: Myra [options] -s <file> [options]');
  Print('');

  Print(COLOR_BOLD + 'USAGE:');
  Print('  Myra ' + COLOR_CYAN + '-s <file>' + ' [OPTIONS]');
  Print('');
  Print(COLOR_BOLD + 'REQUIRED:');
  Print('  ' + COLOR_CYAN + '-s, --source  <file>' + '   Source file to compile');
  Print('');
  Print(COLOR_BOLD + 'OPTIONS:');
  Print('  ' + COLOR_CYAN + '-o, --output  <path>' + '   Output path (default: output)');
  Print('  ' + COLOR_CYAN + '-nb, --no-build     ' + '   Generate sources only, skip binary build');
  Print('  ' + COLOR_CYAN + '-r, --autorun       ' + '   Build and run the compiled binary');
  Print('  ' + COLOR_CYAN + '-h, --help          ' + '   Display this help message');
  Print('');
  Print(COLOR_BOLD + 'SUBCOMMANDS:');
  Print('  ' + COLOR_CYAN + 'test                ' + '   Run the test suite (use Myra test -h for details)');
  Print('');
  Print(COLOR_BOLD + 'EXAMPLES:');
  Print('  ' + COLOR_CYAN + 'Myra -s hello.myra');
  Print('  ' + COLOR_CYAN + 'Myra -s hello.myra -o build');
  Print('  ' + COLOR_CYAN + 'Myra -s hello.myra -r');
  Print('  ' + COLOR_CYAN + 'Myra test');
  Print('');
end;

procedure TMyraCLI.ShowErrors();
var
  LErrors: TErrors;
  LError:  TError;
  LColor:  string;
  LI:      Integer;
begin
  if not FMyra.HasErrors() then
    Exit;

  LErrors := FMyra.GetErrors();

  Print('');
  Print(COLOR_WHITE + Format('Errors (%d):', [LErrors.Count()]));

  for LI := 0 to LErrors.GetItems().Count - 1 do
  begin
    LError := LErrors.GetItems()[LI];

    case LError.Severity of
      esHint:    LColor := COLOR_CYAN;
      esWarning: LColor := COLOR_YELLOW;
      esError:   LColor := COLOR_RED;
      esFatal:   LColor := COLOR_BOLD + COLOR_RED;
    else
      LColor := COLOR_WHITE;
    end;

    Print(LColor + '  ' + LError.ToFullString());
  end;
end;

procedure TMyraCLI.SetupCallbacks();
begin
  // Print compiler status messages
  FMyra.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TUtils.PrintLn(AText);
    end);

  // Print program output (no newline — output drives its own line endings)
  FMyra.SetOutputCallback(
    procedure(const ALine: string; const AUserData: Pointer)
    begin
      TUtils.Print(ALine);
    end);
end;

function TMyraCLI.ParseCompileArgs(): Boolean;
var
  LI:    Integer;
  LFlag: string;
begin
  Result := True;

  if ParamCount = 0 then
  begin
    ShowCompileHelp();
    Result := False;
    Exit;
  end;

  LI := 1;
  while LI <= ParamCount do
  begin
    LFlag := ParamStr(LI).Trim();

    if (LFlag = '-h') or (LFlag = '--help') then
    begin
      ShowCompileHelp();
      Result := False;
      Exit;
    end
    else if (LFlag = '-s') or (LFlag = '--source') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a file argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FSourceFile := TPath.ChangeExtension(ParamStr(LI).Trim(), MYRA_EXT);

    end
    else if (LFlag = '-o') or (LFlag = '--output') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a path argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FOutputPath := ParamStr(LI).Trim();
    end
    else if (LFlag = '-nb') or (LFlag = '--no-build') then
    begin
      FBuild := False;
    end
    else if (LFlag = '-r') or (LFlag = '--autorun') then
    begin
      FAutoRun := True;
    end
    else
    begin
      Print(COLOR_RED + 'Error: Unknown flag: ' + COLOR_YELLOW + LFlag);
      Print('');
      Print('Run ' + COLOR_CYAN + 'Myra -h' + ' to see available options');
      Print('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    Inc(LI);
  end;

  // Validate required arguments
  if FSourceFile = '' then
  begin
    Print(COLOR_RED + 'Error: Source file is required (-s <file>)');
    Print('');
    Print('Run ' + COLOR_CYAN + 'Myra -h' + ' to see available options');
    Print('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;
end;

procedure TMyraCLI.RunCompile();
var
  LSuccess: Boolean;
begin
  // Configure the compiler
  FMyra.SetSourceFile(FSourceFile);
  FMyra.SetOutputPath(FOutputPath);
  FMyra.SetLineDirectives(True);

  SetupCallbacks();

  Print('');

  LSuccess := FMyra.Compile(FBuild, False);

  // Always display all errors/warnings/hints regardless of outcome
  ShowErrors();

  if LSuccess then
  begin
    if FBuild then
      Print(COLOR_GREEN + 'Build OK')
    else
      Print(COLOR_GREEN + 'Compile OK');
  end
  else
  begin
    Print(COLOR_RED + 'Build failed.');
    ExitCode := 1;
  end;

  if FAutoRun then
  begin
    ExitCode := FMyra.Run();
  end;
end;

{ --- Test subcommand --- }

procedure TMyraCLI.ShowTestHelp();
begin
  Print(COLOR_BOLD + 'USAGE:');
  Print('  Myra test ' + COLOR_CYAN + '[name|index|all]' + COLOR_RESET + ' [OPTIONS]');
  Print('');
  Print(COLOR_BOLD + 'TEST SPECIFIER:');
  Print('  ' + COLOR_CYAN + '<name>            ' + COLOR_RESET + '  Run test by name (e.g. test_exe_hello)');
  Print('  ' + COLOR_CYAN + '<index>           ' + COLOR_RESET + '  Run test by index (e.g. 0)');
  Print('  ' + COLOR_CYAN + 'all               ' + COLOR_RESET + '  Run all discovered tests (default)');
  Print('');
  Print(COLOR_BOLD + 'OPTIONS:');
  Print('  ' + COLOR_CYAN + '-t, --tests <path>' + COLOR_RESET + '  Test folder (default: ' + DEFAULT_TEST_FOLDER + ')');
  Print('  ' + COLOR_CYAN + '-c, --config <file>' + COLOR_RESET + '  Test config file (default: tests.toml in test folder)');
  Print('  ' + COLOR_CYAN + '-p, --platform <p>' + COLOR_RESET + '  Target platform: win64, linux64 (default: win64)');
  Print('  ' + COLOR_CYAN + '-h, --help        ' + COLOR_RESET + '  Display this help message');
  Print('');
  Print(COLOR_BOLD + 'EXAMPLES:');
  Print('  ' + COLOR_CYAN + 'Myra test');
  Print('  ' + COLOR_CYAN + 'Myra test all');
  Print('  ' + COLOR_CYAN + 'Myra test test_exe_hello');
  Print('  ' + COLOR_CYAN + 'Myra test 0');
  Print('  ' + COLOR_CYAN + 'Myra test all -p linux64');
  Print('  ' + COLOR_CYAN + 'Myra test -t C:\MyTests');
  Print('  ' + COLOR_CYAN + 'Myra test all -c D:\config\mytests.toml');
  Print('');
end;

function TMyraCLI.ParseTestArgs(): Boolean;
var
  LI:    Integer;
  LFlag: string;
begin
  Result := True;

  // No args after 'test' — show help
  if ParamCount < 2 then
  begin
    ShowTestHelp();
    Result := False;
    Exit;
  end;

  // Args start at index 2 (index 1 is 'test')
  LI := 2;
  while LI <= ParamCount do
  begin
    LFlag := ParamStr(LI).Trim();

    if (LFlag = '-h') or (LFlag = '--help') then
    begin
      ShowTestHelp();
      Result := False;
      Exit;
    end
    else if (LFlag = '-t') or (LFlag = '--tests') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a path argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FTestFolder := ParamStr(LI).Trim();
    end
    else if (LFlag = '-c') or (LFlag = '--config') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a file argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FTestConfig := ParamStr(LI).Trim();
    end
    else if (LFlag = '-p') or (LFlag = '--platform') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a platform argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      if SameText(ParamStr(LI).Trim(), 'linux64') then
        FTestPlatform := tpLinux64
      else if SameText(ParamStr(LI).Trim(), 'win64') then
        FTestPlatform := tpWin64
      else
      begin
        Print(COLOR_RED + 'Error: Unknown platform: ' + COLOR_YELLOW + ParamStr(LI).Trim());
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
    end
    else if LFlag.StartsWith('-') then
    begin
      Print(COLOR_RED + 'Error: Unknown flag: ' + COLOR_YELLOW + LFlag);
      Print('');
      Print('Run ' + COLOR_CYAN + 'Myra test -h' + COLOR_RESET + ' to see available options');
      Print('');
      ExitCode := 2;
      Result := False;
      Exit;
    end
    else
    begin
      // Positional: test specifier (name, index, or 'all')
      FTestSpec := LFlag;
    end;

    Inc(LI);
  end;

  // Default test folder relative to exe if not specified
  if FTestFolder = '' then
    FTestFolder := TPath.Combine(ExtractFilePath(ParamStr(0)), DEFAULT_TEST_FOLDER);
end;

procedure TMyraCLI.RunTestSuite();
var
  LTester: TMyraTester;
  LIndex:  Integer;
begin
  LTester := TMyraTester.Create();
  try
    LTester.TestFolder     := FTestFolder;
    LTester.OutputPath     := 'output';
    LTester.Verbose        := True;
    LTester.TargetPlatform := FTestPlatform;
    LTester.OptimizeLevel  := olDebug;
    LTester.Subsystem      := stConsole;

    // Load test config (deps, run flags, execution order)
    if FTestConfig <> '' then
      LTester.ConfigPath := FTestConfig;
    LTester.LoadConfig();

    if LTester.RegisteredTestCount = 0 then
    begin
      Print(COLOR_RED + 'Error: No test config found. Create a tests.toml in the test folder or specify one with --config.');
      Print('');
      ExitCode := 2;
      Exit;
    end;

    if SameText(FTestSpec, 'all') then
      LTester.RunAllTests()
    else if TryStrToInt(FTestSpec, LIndex) then
      LTester.RunTestByIndex(LIndex)
    else
      LTester.RunTest(FTestSpec, True);
  finally
    LTester.Free();
  end;
end;

{ --- Main dispatch --- }

procedure TMyraCLI.Execute();
begin
  ShowBanner();

  // Check for 'test' subcommand
  if (ParamCount >= 1) and SameText(ParamStr(1).Trim(), 'test') then
  begin
    if not ParseTestArgs() then
      Exit;
    RunTestSuite();
  end
  else
  begin
    if not ParseCompileArgs() then
      Exit;
    RunCompile();
  end;
end;

{ RunCLI }

procedure RunCLI();
var
  LCLI: TMyraCLI;
begin
  ExitCode := 0;
  LCLI := nil;

  try
    LCLI := TMyraCLI.Create();
    try
      LCLI.Execute();
    finally
      FreeAndNil(LCLI);
    end;
  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + COLOR_BOLD + 'Fatal Error: ' + E.Message);
      TUtils.PrintLn('');
      ExitCode := 1;
    end;
  end;
end;

end.
