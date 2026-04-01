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
  Metamorf.Build,
  Metamorf.CLI;

// =========================================================================
// CLI MODE (Release)
// =========================================================================

procedure RunCLI();
var
  LCLI: TMorCLI;
begin
  ExitCode := 0;
  LCLI := TMorCLI.Create();
  try
    LCLI.Execute();
  finally
    FreeAndNil(LCLI);
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
    LNum := 4;

    case LNum of
      01: TestLang('..\tests\pascal', '..\tests\hello.pas');
      02: TestLang('..\tests\lua',    '..\tests\hello.lua');
      03: TestLang('..\tests\basic',  '..\tests\hello.bas');
      04: TestLang('..\tests\scheme', '..\tests\hello.scm');
      05: TestLang('..\tests\mylang', '..\tests\hello.ml');
      06: TestLang('..\tests\pascal2', '..\tests\hello2.pas');
      07: TestLang('..\tests\testbed', '..\tests\testbed.pas');

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
