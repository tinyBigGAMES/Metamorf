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
  Metamorf.Common,
  Metamorf.API,
  Metamorf.Lang,
  Metamorf.Lang.CLI;

// =========================================================================
// CLI MODE (Release)
// =========================================================================

procedure RunCLI();
var
  LCLI: TMetamorfLangCLI;
begin
  ExitCode := 0;
  LCLI := nil;

  try
    LCLI := TMetamorfLangCLI.Create();
    try
      LCLI.Execute();
    finally
      FreeAndNil(LCLI);
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

function TestLang(const ALangFile, ASrcFile: string): Boolean;
var
  LCompiler: TMetamorfLang;
  LLangFile: string;
  LSrcFile: string;
begin
  Result := False;
  LCompiler := TMetamorfLang.Create();
  try
    LCompiler.SetStatusCallback(
      procedure(const AMsg: string; const AUserData: Pointer)
      begin
        TUtils.PrintLn(AMsg);
      end);

    // Print program output (no newline — output drives its own line endings)
    LCompiler.SetOutputCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        TUtils.Print(ALine);
      end);
    // — -
    LLangFile := TPath.Combine('..\tests', TPath.ChangeExtension(ALangFile, METAMORF_LANG_EXT));
    //LLangFile := TPath.ChangeExtension(ALangFile, METAMORF_LANG_EXT).Replace('\', '/');

    LSrcFile := TPath.Combine('..\tests', ASrcFile);
    //LSrcFile := ASrcFile.Replace('\', '/');

    if not TFile.Exists(LLangFile) then Exit;
    if not TFile.Exists(LSrcFile) then Exit;

    LCompiler.SetLangFile(LLangFile);
    LCompiler.SetSourceFile(LSrcFile);
    LCompiler.SetOutputPath('output');
    LCompiler.SetLineDirectives(True);

    Result := LCompiler.Compile(True, True);

    if LCompiler.HasErrors() then
      TUtils.PrintLn(LCompiler.GetErrors().Dump());
  finally
    LCompiler.Free();
  end;
end;

procedure RunTestbed();
var
  LNum: Integer;
begin
  try
    LNum := 6;

    case LNum of
      01: TestLang('..\tests\pascal', '..\tests\hello.pas');
      02: TestLang('..\tests\lua',    '..\tests\hello.lua');
      03: TestLang('..\tests\basic',  '..\tests\hello.bas');
      04: TestLang('..\tests\scheme', '..\tests\hello.scm');
      05: TestLang('..\tests\mylang', '..\tests\hello.ml');
      06: TestLang('..\tests\myra', '..\projects\myra\tests\test_exe_hello.myra');
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
