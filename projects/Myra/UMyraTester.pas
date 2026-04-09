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

procedure RunMyraTester();
var
  LTester: TMyraTester;
begin
  try
    LTester := TMyraTester.Create();
    try
      // --- Core exe tests (compile and run) ---
      LTester.RegisterTest(0000, 'test_exe_hello', rmExecute);
      LTester.RegisterTest(0001, 'test_exe_variables', rmExecute);
      LTester.RegisterTest(0002, 'test_exe_vars', rmExecute);
      LTester.RegisterTest(0003, 'test_exe_assign', rmExecute);
      LTester.RegisterTest(0004, 'test_exe_consts', rmExecute);
      LTester.RegisterTest(0005, 'test_exe_constants_enums', rmExecute);
      LTester.RegisterTest(0006, 'test_exe_types', rmExecute);
      LTester.RegisterTest(0007, 'test_exe_math', rmExecute);

      // --- Control flow ---
      LTester.RegisterTest(0050, 'test_exe_ifelse', rmExecute);
      LTester.RegisterTest(0051, 'test_exe_conditional', rmExecute);
      LTester.RegisterTest(0052, 'test_exe_control_flow', rmExecute);
      LTester.RegisterTest(0053, 'test_exe_loops', rmExecute);
      LTester.RegisterTest(0054, 'test_exe_match', rmExecute);

      // --- Routines ---
      LTester.RegisterTest(0100, 'test_exe_routines', rmExecute);
      LTester.RegisterTest(0101, 'test_exe_variadic_routines', rmExecute);
      LTester.RegisterTest(0102, 'test_exe_routine_type_linkage', rmExecute);
      LTester.RegisterTest(0103, 'test_exe_intrinsics', rmExecute);

      // --- Data structures ---
      LTester.RegisterTest(0150, 'test_exe_arrays', rmExecute);
      LTester.RegisterTest(0151, 'test_exe_dynamic_arrays', rmExecute);
      LTester.RegisterTest(0152, 'test_exe_records', rmExecute);
      LTester.RegisterTest(0153, 'test_exe_pointers', rmExecute);
      LTester.RegisterTest(0154, 'test_exe_strings', rmExecute);
      LTester.RegisterTest(0155, 'test_exe_strings_full', rmExecute);
      LTester.RegisterTest(0156, 'test_exe_sets', rmExecute);
      LTester.RegisterTest(0157, 'test_exe_sets_enum', rmExecute);
      LTester.RegisterTest(0158, 'test_exe_sets_sizes', rmExecute);
      LTester.RegisterTest(0159, 'test_exe_classes', rmExecute);

      // --- Memory management ---
      LTester.RegisterTest(0200, 'test_exe_memory', rmExecute);
      LTester.RegisterTest(0201, 'test_exe_new_dispose', rmExecute);
      LTester.RegisterTest(0202, 'test_exe_new_dispose_managed', rmExecute);
      LTester.RegisterTest(0203, 'test_exe_setlength_shrink_managed', rmExecute);

      // --- Exceptions ---
      LTester.RegisterTest(0250, 'test_exe_exceptions', rmExecute);
      LTester.RegisterTest(0251, 'test_exe_exception_scope', rmExecute);

      // --- Modules/imports ---
      LTester.RegisterTest(0300, 'test_exe_import', rmExecute);
      LTester.RegisterTest(0301, 'test_exe_std', rmExecute);

      // --- DLL/Lib consumers (depend on earlier builds) ---
      LTester.RegisterTests(0350, 'test_exe_usedll',
        ['test_dll_exports'], rmExecute);
      LTester.RegisterTests(0351, 'test_exe_uselib',
        ['test_lib_utils'], rmExecute);

      // --- Miscellaneous ---
      LTester.RegisterTest(0400, 'test_exe_mixedmode', rmExecute);
      LTester.RegisterTest(0401, 'test_exe_target', rmExecute);
      LTester.RegisterTest(0402, 'test_exe_verinfo', rmExecute);
      LTester.RegisterTest(0403, 'test_exe_debug', rmDebug);
      LTester.RegisterTest(0404, 'test_exe_unittest', rmExecute);

      // --- External deps (compile only, require runtime DLLs) ---
      LTester.RegisterTest(0450, 'test_exe_raylib', rmExecute, '', '');
      LTester.RegisterTest(0451, 'test_exe_raylib', rmExecute, 'STATIC', '1');


      //LTester.RegisterTest(0451, 'test_exe_sdl3', rmNone);
      //LTester.RegisterTest(0452, 'test_exe_sdl3_image', rmNone);
      //LTester.RegisterTest(0453, 'test_exe_sdl3_mixer', rmNone);


      //LTester.RunAllTests();
      //LTester.RunTestByIndex(301); // work on the STD later

      LTester.RunTestByIndex(450, tpLinux64);
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

  if TMorUtils.RunFromIDE() then
    TMorUtils.Pause();

end;

end.
