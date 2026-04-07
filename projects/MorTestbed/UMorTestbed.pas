{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UMorTestbed;

{$I Metamorf.Defines.inc}

interface

procedure RunMorTestbed();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Metamorf.Utils,
  Metamorf.Engine,
  Metamorf.Build,
  Metamorf.CLI,
  UTest.API,
  UTest.LSP,
  UTest.Debug;

function TestLang(const ALangFile: string; const ASrcFile: string): Boolean;
var
  LEngine: TMorEngine;
  LLangFile: string;
  LSrcFile: string;
begin
  Result := False;
  LEngine := TMorEngine.Create();
  try
    LEngine.SetStatusCallback(
      procedure(const AMsg: string; const AUserData: Pointer)
      begin
        TMorUtils.PrintLn(AMsg);
      end);

    // Print program output (no newline - output drives its own line endings)
    LEngine.SetOutputCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        TMorUtils.Print(ALine);
      end);

    LLangFile := TPath.Combine('..\tests',
      TPath.ChangeExtension(ALangFile, '.mor'));
    LSrcFile := TPath.Combine('..\tests', ASrcFile);

    if not TFile.Exists(LLangFile) then Exit;
    if not TFile.Exists(LSrcFile) then Exit;

    //LEngine.SetTarget(tpLinux64);

    LEngine.Compile(LLangFile, LSrcFile, 'output', True);

    Result := not LEngine.GetErrors().HasErrors();

    if LEngine.GetErrors().HasErrors() then
      TMorUtils.PrintLn(LEngine.GetErrors().Dump());
  finally
    LEngine.Free();
  end;
end;

procedure RunMorTestbed();
var
  LNum: Integer;
begin
  try

    //LNum := 8;
    //LNum := 300;
    LNum := 100;

    case LNum of
      // Languages
      01: TestLang('..\tests\pascal', '..\tests\hello.pas');
      02: TestLang('..\tests\lua',    '..\tests\hello.lua');
      03: TestLang('..\tests\basic',  '..\tests\hello.bas');
      04: TestLang('..\tests\scheme', '..\tests\hello.scm');
      05: TestLang('..\tests\mylang', '..\tests\hello.ml');
      06: TestLang('..\tests\pascal2', '..\tests\hello2.pas');
      07: TestLang('..\tests\testbed', '..\tests\testbed.pas');
      08: TestLang('..\tests\pascal', '..\tests\hello_debug.pas');

      // Test C-API
      100: UTest.API.Test_CompileBuild();
      101: UTest.API.Test_CustomCodeGen();

      // Test LSP
      200: UTest.LSP.Test_LSP_InProcess();
      201: UTest.LSP.Test_LSP_OutOfProcess();

      // Test Debug
      300: UTest.Debug.Test01();

      // issue-3 (1000-1002) Fixed
      1000: TestLang('..\bugs\issue-3\root_ok', '..\bugs\issue-3\test.pas');
      1001: TestLang('..\bugs\issue-3\root_crash', '..\bugs\issue-3\test.pas');
      1002: TestLang('..\bugs\issue-3\root_broken', '..\bugs\issue-3\test.pas'); // to test for memory leaks

      // issue-4 (1003-1004) Fixed
      1003: TestLang('..\bugs\issue-4\works', '..\bugs\issue-4\test.pas');
      1004: TestLang('..\bugs\issue-4\crashes', '..\bugs\issue-4\test.pas');

      // issue-5 (1005-1006) Fixed
      1005: TestLang('..\bugs\issue-5\works', '..\bugs\issue-5\test.pas');
      1006: TestLang('..\bugs\issue-5\crashes', '..\bugs\issue-5\test.pas');

      // issue-6 (1007-1008) Fixed
      1007: TestLang('..\bugs\issue-6\works', '..\bugs\issue-6\test.pas');
      1008: TestLang('..\bugs\issue-6\crashes', '..\bugs\issue-6\test.pas');
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
