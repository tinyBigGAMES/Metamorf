{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UMetamorf;

interface

procedure RunMetamorf();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Metamorf.Utils,
  Metamorf.Engine,
  Metamorf.Build;

// =========================================================================
// CLI MODE (Release)
// =========================================================================

procedure RunCLI();
var
  LEngine: TMorEngine;
  LMorFile: string;
  LSrcFile: string;
  LOutputPath: string;
begin
  ExitCode := 0;

  if ParamCount() < 2 then
  begin
    TUtils.PrintLn('Usage: metamorf <lang.mor> <source> [output_path]');
    ExitCode := 1;
    Exit;
  end;

  LMorFile := ParamStr(1);
  LSrcFile := ParamStr(2);
  if ParamCount() >= 3 then
    LOutputPath := ParamStr(3)
  else
    LOutputPath := 'output';

  LEngine := TMorEngine.Create();
  try
    try
      LEngine.SetStatusCallback(
        procedure(const AMsg: string; const AUserData: Pointer)
        begin
          TUtils.PrintLn(AMsg);
        end);

      LEngine.GetBuild().SetOutputCallback(
        procedure(const ALine: string; const AUserData: Pointer)
        begin
          TUtils.Print(ALine);
        end);

      LEngine.Compile(LMorFile, LSrcFile, LOutputPath, True);

      if LEngine.GetErrors().HasErrors() then
      begin
        TUtils.PrintLn(LEngine.GetErrors().Dump());
        ExitCode := 1;
      end;
    finally
      FreeAndNil(LEngine);
    end;
  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + COLOR_BOLD + 'Fatal Error: ' +
        E.Message + COLOR_RESET);
      TUtils.PrintLn('');
      ExitCode := 1;
    end;
  end;
end;

// =========================================================================
// TESTBED MODE (Debug / IDE)
// =========================================================================

function TestLang(const ALangFile: string;
  const ASrcFile: string): Boolean;
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
        TUtils.PrintLn(AMsg);
      end);

    // Print program output (no newline - output drives its own line endings)
    LEngine.GetBuild().SetOutputCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        TUtils.Print(ALine);
      end);

    LLangFile := TPath.Combine('..\tests',
      TPath.ChangeExtension(ALangFile, '.mor'));
    LSrcFile := TPath.Combine('..\tests', ASrcFile);

    if not TFile.Exists(LLangFile) then Exit;
    if not TFile.Exists(LSrcFile) then Exit;

    //LEngine.GetBuild().SetTarget(tpLinux64);

    LEngine.Compile(LLangFile, LSrcFile, 'output', True);

    Result := not LEngine.GetErrors().HasErrors();

    if LEngine.GetErrors().HasErrors() then
      TUtils.PrintLn(LEngine.GetErrors().Dump());
  finally
    LEngine.Free();
  end;
end;

procedure RunTestbed();
var
  LNum: Integer;
begin
  try
    LNum := 8;

    case LNum of
      01: TestLang('..\tests\pascal', '..\tests\hello.pas');
      02: TestLang('..\tests\lua',    '..\tests\hello.lua');
      03: TestLang('..\tests\basic',  '..\tests\hello.bas');
      04: TestLang('..\tests\scheme', '..\tests\hello.scm');
      05: TestLang('..\tests\mylang', '..\tests\hello.ml');
      06: TestLang('..\tests\myra', '..\projects\myra\tests\test_exe_hello.myra');
      07: TestLang('..\tests\myra', '..\projects\myra\tests\test_exe_mixedmode.myra');
      08: TestLang('..\tests\pascal2', '..\tests\hello2.pas');

    end;

  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message + COLOR_RESET);
    end;
  end;

  if TUtils.RunFromIDE() then
    TUtils.Pause();
end;

// =========================================================================
// ENTRY POINT
// =========================================================================

procedure RunMetamorf();
begin
  {$IFDEF RELEASE}
  RunCLI();
  {$ELSE}
  RunTestbed();
  {$ENDIF}
end;

end.
