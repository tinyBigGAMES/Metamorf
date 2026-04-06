{===============================================================================
  Myra Language — Test Harness

  Standalone entry point that creates a TMyraTester, registers all Myra
  test files, configures build settings, and runs the suite.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.
===============================================================================}

unit UMyraTester;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  Metamorf.Utils,
  Metamorf.Build,
  Myra.Tester;

procedure RunMyraTester();

implementation

procedure RunMyraTester();
var
  LTester: TMyraTester;
begin
  try
    LTester := TMyraTester.Create();
    try
      LTester.Target        := tpWin64;
      LTester.OptimizeLevel := olDebug;
      LTester.Subsystem     := stConsole;

      // --- Core exe tests (compile and run) ---
      LTester.RegisterTest(0000, 'test_exe_hello', True);
      LTester.RegisterTest(0001, 'test_exe_variables', True);
      LTester.RegisterTest(0002, 'test_exe_vars', True);
      LTester.RegisterTest(0003, 'test_exe_assign', True);
      LTester.RegisterTest(0004, 'test_exe_consts', True);
      LTester.RegisterTest(0005, 'test_exe_constants_enums', True);
      LTester.RegisterTest(0006, 'test_exe_types', True);
      LTester.RegisterTest(0007, 'test_exe_math', True);

      // --- Control flow ---
      LTester.RegisterTest(0050, 'test_exe_ifelse', True);
      LTester.RegisterTest(0051, 'test_exe_conditional', True);
      LTester.RegisterTest(0052, 'test_exe_control_flow', True);
      LTester.RegisterTest(0053, 'test_exe_loops', True);
      LTester.RegisterTest(0054, 'test_exe_match', True);

      // --- Routines ---
      LTester.RegisterTest(0100, 'test_exe_routines', True);
      LTester.RegisterTest(0101, 'test_exe_variadic_routines', True);
      LTester.RegisterTest(0102, 'test_exe_routine_type_linkage', True);
      LTester.RegisterTest(0103, 'test_exe_intrinsics', True);

      // --- Data structures ---
      LTester.RegisterTest(0150, 'test_exe_arrays', True);
      LTester.RegisterTest(0151, 'test_exe_dynamic_arrays', True);
      LTester.RegisterTest(0152, 'test_exe_records', True);
      LTester.RegisterTest(0153, 'test_exe_pointers', True);
      LTester.RegisterTest(0154, 'test_exe_strings', True);
      LTester.RegisterTest(0155, 'test_exe_strings_full', True);
      LTester.RegisterTest(0156, 'test_exe_sets', True);
      LTester.RegisterTest(0157, 'test_exe_sets_enum', True);
      LTester.RegisterTest(0158, 'test_exe_sets_sizes', True);
      LTester.RegisterTest(0159, 'test_exe_classes', True);

      // --- Memory management ---
      LTester.RegisterTest(0200, 'test_exe_memory', True);
      LTester.RegisterTest(0201, 'test_exe_new_dispose', True);
      LTester.RegisterTest(0202, 'test_exe_new_dispose_managed', True);
      LTester.RegisterTest(0203, 'test_exe_setlength_shrink_managed', True);

      // --- Exceptions ---
      LTester.RegisterTest(0250, 'test_exe_exceptions', True);
      LTester.RegisterTest(0251, 'test_exe_exception_scope', True);

      // --- Modules/imports ---
      LTester.RegisterTest(0300, 'test_exe_import', True);
      LTester.RegisterTest(0301, 'test_exe_std', True);

      // --- DLL/Lib consumers (depend on earlier builds) ---
      LTester.RegisterTests(0350, 'test_exe_usedll',
        ['test_dll_exports'], True);
      LTester.RegisterTests(0351, 'test_exe_uselib',
        ['test_lib_utils'], True);

      // --- Miscellaneous ---
      LTester.RegisterTest(0400, 'test_exe_mixedmode', True);
      LTester.RegisterTest(0401, 'test_exe_target', True);
      LTester.RegisterTest(0402, 'test_exe_verinfo', True);
      LTester.RegisterTest(0503, 'test_exe_debug', True);

      // --- External deps (compile only, require runtime DLLs) ---
      LTester.RegisterTest(0450, 'test_exe_sdl3', False);
      LTester.RegisterTest(0451, 'test_exe_sdl3_image', False);
      LTester.RegisterTest(0452, 'test_exe_sdl3_mixer', False);
      LTester.RegisterTest(0453, 'test_exe_raylib', False);

      //LTester.RunAllTests();
      LTester.RunTestByIndex(152);
    finally
      LTester.Free();
    end;

  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);
    end;
  end;

  if TUtils.RunFromIDE() then
    TUtils.Pause();

end;

end.
