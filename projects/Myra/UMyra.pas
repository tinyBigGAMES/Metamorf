{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit UMyra;

interface

procedure RunMyra();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  Metamorf.API,
  Myra.Compiler,
  Myra.Tester,
  Myra.CLI;

procedure RegisterTests(const ATester: TMyraTester);
begin
  // Register all tests - ACanRun=True: build and run, False: build only
  {00} ATester.RegisterTest('test_exe_hello', True);
  {01} ATester.RegisterTest('test_exe_consts', True);
  {02} ATester.RegisterTest('test_exe_uselib', True);
  {03} ATester.RegisterTest('test_exe_ifelse', True);
  {04} ATester.RegisterTest('test_exe_loops', True);
  {05} ATester.RegisterTest('test_exe_match', True);
  {06} ATester.RegisterTest('test_exe_routines', True);
  {07} ATester.RegisterTest('test_exe_strings', True);
  {08} ATester.RegisterTest('test_exe_types', True);
  {09} ATester.RegisterTest('test_exe_vars', True);
  {10} ATester.RegisterTest('test_lib_utils', True);
  {11} ATester.RegisterTest('test_exe_mixedmode', True);
  {12} ATester.RegisterTests('test_exe_usedll', ['test_dll_exports']);
  {13} ATester.RegisterTest('test_exe_raylib', True, 'STATIC', '1');
  {14} ATester.RegisterTest('test_exe_raylib', True, '', '');

end;

procedure RunTest(const ATestName: string; const APlatform: TTargetPlatform=tpWin64; const AOptLevel: TOptimizeLevel=olDebug; const ASubsytem: TSubsystemType=stConsole); overload;
var
  LTester:     TMyraTester;
begin
  LTester := TMyraTester.Create();
  try
    LTester.OutputPath     := 'output';
    LTester.Verbose        := True;
    LTester.TargetPlatform := APlatform;
    LTester.OptimizeLevel  := AOptLevel;
    LTester.Subsystem      := ASubsytem;

    RegisterTests(LTester);

    if ATestName.IsEmpty() then
      LTester.RunAllTests()
    else
      LTester.RunTest(ATestName, True);

  finally
    LTester.Free();
  end;
end;

procedure RunTest(const ATestIndex: Integer; const APlatform: TTargetPlatform=tpWin64; const AOptLevel: TOptimizeLevel=olDebug; const ASubsytem: TSubsystemType=stConsole); overload;
var
  LTester:     TMyraTester;
begin
  LTester := TMyraTester.Create();
  try
    LTester.OutputPath     := 'output';
    LTester.Verbose        := True;
    LTester.TargetPlatform := APlatform;
    LTester.OptimizeLevel  := AOptLevel;
    LTester.Subsystem      := ASubsytem;

    RegisterTests(LTester);

    LTester.RunTestByIndex(ATestIndex)

  finally
    LTester.Free();
  end;
end;

procedure RunTestbed();
var
  LPlatform: TTargetPlatform;
  LOptLevel: TOptimizeLevel;
  LSubSystem: TSubsystemType;
  LTestIndex: Integer;
begin
  try
    // olDebug | olReleaseSafe | olReleaseFast | olReleaseSmall
    LOptLevel := olDebug;

    // tpWin64 | tpLinux64
    LPlatform := tpLinux64;

    // stConsole | stGUI
    LSubSystem := stConsole;

    LTestIndex := 13;
    RunTest(LTestIndex, LPlatform, LOptLevel, LSubSystem);
  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message);
    end;
  end;

  if TUtils.RunFromIDE() then
    TUtils.Pause();
end;

procedure RunMyra();
begin
  {$IFDEF RELEASE}
  RunCLI();
  {$ELSE}
  RunTestbed();
  {$ENDIF}
end;

end.
