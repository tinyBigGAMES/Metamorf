{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UTest.Debug;

{$I Metamorf.Defines.inc}

interface

procedure Test01();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Metamorf.Utils,
  Metamorf.Debug.REPL;

procedure Test01();
var
  LBasePath: string;
  LExePath: string;
  LREPL: TMorDebugREPL;
begin
  TMorUtils.PrintLn('========================================');
  TMorUtils.PrintLn('Test01: PDB DAP Debugger (REPL)');
  TMorUtils.PrintLn('========================================');
  TMorUtils.PrintLn('');

  LBasePath := ExtractFilePath(ParamStr(0));
  LExePath := TPath.Combine(LBasePath,
    'output\zig-out\bin\hello_debug.exe');

  if not TFile.Exists(LExePath) then
  begin
    TMorUtils.PrintLn(COLOR_RED +
      'ERROR: Executable not found: ' + LExePath);
    TMorUtils.PrintLn(COLOR_YELLOW +
      'Compile hello_debug.pas first.');
    Exit;
  end;

  LREPL := TMorDebugREPL.Create();
  try
    LREPL.Run(LExePath);
  finally
    LREPL.Free();
  end;
end;

end.
