{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UMyraTester;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.Build,
  Myra.Tester;

procedure RunMyraTester();

implementation

procedure RegisterAllTests(const ATester: TMyraTester);
begin
  // --- Core exe tests (compile and run) ---
  ATester.RegisterTest(0000, 'test_exe_hello', rmExecute);
  ATester.RegisterTest(0001, 'test_exe_variables', rmExecute);
  ATester.RegisterTest(0002, 'test_exe_vars', rmExecute);
  ATester.RegisterTest(0003, 'test_exe_assign', rmExecute);
  ATester.RegisterTest(0004, 'test_exe_consts', rmExecute);
  ATester.RegisterTest(0005, 'test_exe_constants_enums', rmExecute);
  ATester.RegisterTest(0006, 'test_exe_types', rmExecute);
  ATester.RegisterTest(0007, 'test_exe_math', rmExecute);

  // --- Control flow ---
  ATester.RegisterTest(0050, 'test_exe_ifelse', rmExecute);
  ATester.RegisterTest(0051, 'test_exe_conditional', rmExecute);
  ATester.RegisterTest(0052, 'test_exe_control_flow', rmExecute);
  ATester.RegisterTest(0053, 'test_exe_loops', rmExecute);
  ATester.RegisterTest(0054, 'test_exe_match', rmExecute);

  // --- Routines ---
  ATester.RegisterTest(0100, 'test_exe_routines', rmExecute);
  ATester.RegisterTest(0101, 'test_exe_variadic_routines', rmExecute);
  ATester.RegisterTest(0102, 'test_exe_routine_type_linkage', rmExecute);
  ATester.RegisterTest(0103, 'test_exe_intrinsics', rmExecute);

  // --- Data structures ---
  ATester.RegisterTest(0150, 'test_exe_arrays', rmExecute);
  ATester.RegisterTest(0151, 'test_exe_dynamic_arrays', rmExecute);
  ATester.RegisterTest(0152, 'test_exe_records', rmExecute);
  ATester.RegisterTest(0153, 'test_exe_pointers', rmExecute);
  ATester.RegisterTest(0154, 'test_exe_strings', rmExecute);
  ATester.RegisterTest(0155, 'test_exe_strings_full', rmExecute);
  ATester.RegisterTest(0156, 'test_exe_sets', rmExecute);
  ATester.RegisterTest(0157, 'test_exe_sets_enum', rmExecute);
  ATester.RegisterTest(0158, 'test_exe_sets_sizes', rmExecute);
  ATester.RegisterTest(0159, 'test_exe_classes', rmExecute);

  // --- Memory management ---
  ATester.RegisterTest(0200, 'test_exe_memory', rmExecute);
  ATester.RegisterTest(0201, 'test_exe_new_dispose', rmExecute);
  ATester.RegisterTest(0202, 'test_exe_new_dispose_managed', rmExecute);
  ATester.RegisterTest(0203, 'test_exe_setlength_shrink_managed', rmExecute);

  // --- Exceptions ---
  ATester.RegisterTest(0250, 'test_exe_exceptions', rmExecute);
  ATester.RegisterTest(0251, 'test_exe_exception_scope', rmExecute);

  // --- Modules/imports ---
  ATester.RegisterTest(0300, 'test_exe_import', rmExecute);
  ATester.RegisterTest(0301, 'test_exe_std', rmExecute);

  // --- DLL/Lib consumers (depend on earlier builds) ---
  ATester.RegisterTests(0350, 'test_exe_usedll',
    ['test_dll_exports'], rmExecute);
  ATester.RegisterTests(0351, 'test_exe_uselib',
    ['test_lib_utils'], rmExecute);

  // --- Miscellaneous ---
  ATester.RegisterTest(0400, 'test_exe_mixedmode', rmExecute);
  ATester.RegisterTest(0401, 'test_exe_target', rmExecute);
  ATester.RegisterTest(0402, 'test_exe_verinfo', rmExecute);
  ATester.RegisterTest(0403, 'test_exe_debug', rmDebug);
  ATester.RegisterTest(0404, 'test_exe_unittest', rmExecute);

  // --- raylib
  ATester.RegisterTest(0450, 'test_exe_raylib', rmExecute, '', '');
  ATester.RegisterTest(0451, 'test_exe_raylib', rmExecute, 'STATIC', '1');

  //--- sdl3
  ATester.RegisterTest(0500, 'test_exe_sdl3', rmExecute);
end;

procedure ProcessCmdLine(const ATester: TMyraTester);
var
  LI:        Integer;
  LSelector: string;
  LFlag:     string;
  LPlatform: string;
  LOptimize: string;
  LDash:     Integer;
  LFrom:     Integer;
  LTo:       Integer;
begin
  if ParamCount() < 1 then
  begin
    TMorUtils.PrintLn(COLOR_WHITE + 'Usage: tester <selector> [options]');
    TMorUtils.PrintLn('');
    TMorUtils.PrintLn(COLOR_BOLD + 'SELECTORS:');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + 'NNN        ' + COLOR_WHITE +
      '   Run test at index NNN');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + 'NNN-NNN    ' + COLOR_WHITE +
      '   Run tests in index range NNN to MMM');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + 'all        ' + COLOR_WHITE +
      '   Run all registered tests');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + '<name>     ' + COLOR_WHITE +
      '   Run test by name pattern');
    TMorUtils.PrintLn('');
    TMorUtils.PrintLn(COLOR_BOLD + 'OPTIONS:');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + '-p, --platform <platform>' + COLOR_WHITE +
      '   Target platform (default: win64)');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + '-o, --optimize <level>   ' + COLOR_WHITE +
      '   Optimization level (default: debug)');
    TMorUtils.PrintLn('');
    TMorUtils.PrintLn(COLOR_BOLD + 'PLATFORMS:');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + 'win64' + COLOR_WHITE +
      ', ' + COLOR_CYAN + 'linux64');
    TMorUtils.PrintLn('');
    TMorUtils.PrintLn(COLOR_BOLD + 'OPTIMIZATION LEVELS:');
    TMorUtils.PrintLn('  ' + COLOR_CYAN + 'debug' + COLOR_WHITE +
      ', ' + COLOR_CYAN + 'release_safe' + COLOR_WHITE +
      ', ' + COLOR_CYAN + 'release_fast' + COLOR_WHITE +
      ', ' + COLOR_CYAN + 'release_small');
    TMorUtils.PrintLn('');
    Exit;
  end;

  LSelector := ParamStr(1);

  // Parse optional flags
  LI := 2;
  while LI <= ParamCount() do
  begin
    LFlag := ParamStr(LI).Trim();

    if (LFlag = '-p') or (LFlag = '--platform') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TMorUtils.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a platform argument');
        Exit;
      end;
      LPlatform := ParamStr(LI).Trim();
      if SameText(LPlatform, 'linux64') then
        ATester.Target := tpLinux64
      else if SameText(LPlatform, 'win64') then
        ATester.Target := tpWin64
      else
      begin
        TMorUtils.PrintLn(COLOR_RED + 'Error: Unknown platform: ' +
          COLOR_YELLOW + LPlatform);
        Exit;
      end;
    end
    else if (LFlag = '-o') or (LFlag = '--optimize') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TMorUtils.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires an optimization level argument');
        Exit;
      end;
      LOptimize := ParamStr(LI).Trim();
      if SameText(LOptimize, 'debug') then
        ATester.OptimizeLevel := olDebug
      else if SameText(LOptimize, 'release_safe') then
        ATester.OptimizeLevel := olReleaseSafe
      else if SameText(LOptimize, 'release_fast') then
        ATester.OptimizeLevel := olReleaseFast
      else if SameText(LOptimize, 'release_small') then
        ATester.OptimizeLevel := olReleaseSmall
      else
      begin
        TMorUtils.PrintLn(COLOR_RED + 'Error: Unknown optimization level: ' +
          COLOR_YELLOW + LOptimize);
        Exit;
      end;
    end
    else
    begin
      TMorUtils.PrintLn(COLOR_RED + 'Error: Unknown flag: ' +
        COLOR_YELLOW + LFlag);
      Exit;
    end;

    Inc(LI);
  end;

  // Dispatch on selector
  if SameText(LSelector, 'all') then
    ATester.RunAllTests()
  else
  begin
    LDash := Pos('-', LSelector);
    if (LDash > 1) and TryStrToInt(Copy(LSelector, 1, LDash - 1), LFrom)
      and TryStrToInt(Copy(LSelector, LDash + 1), LTo) then
    begin
      for LI := LFrom to LTo do
        ATester.RunTestByIndex(LI);
    end
    else if TryStrToInt(LSelector, LFrom) then
      ATester.RunTestByIndex(LFrom)
    else
      ATester.RunTestsMatching(LSelector);
  end;
end;

procedure RunMyraTester();
var
  LTester: TMyraTester;
begin
  try
    LTester := TMyraTester.Create();
    try
      // Always register tests in code (source of truth)
      RegisterAllTests(LTester);
      LTester.SaveTests();

      // Try loading from disk (overrides code registrations if file exists)
      LTester.LoadTests();

      {$IFDEF RELEASE}
      ProcessCmdLine(LTester);
      {$ELSE}
      //LTester.RunTestByIndex(301, tpLinux64);
      LTester.RunTestByIndex(500, tpWin64);
      //LTester.RunTestByIndex(451, tpwin64);
      {$ENDIF}
    finally
      LTester.Free();
    end;

  except
    on E: Exception do
    begin
      TMorUtils.PrintLn('');
      TMorUtils.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);
    end;
  end;

  {$IFNDEF RELEASE}
  if TMorUtils.RunFromIDE() then
    TMorUtils.Pause();
  {$ENDIF}
end;

end.
