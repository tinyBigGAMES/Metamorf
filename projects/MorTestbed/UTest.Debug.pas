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
  Metamorf.Debug,
  Metamorf.Debug.REPL;

procedure Test01();
var
  LBasePath: string;
  LExePath: string;
  LDebugger: TMorDebug;
  LREPL: TMorDebugREPL;
begin
  TUtils.PrintLn('========================================');
  TUtils.PrintLn('Test01: Debug REPL Test');
  TUtils.PrintLn('========================================');
  TUtils.PrintLn('');

  // Build paths relative to executable (bin\)
  LBasePath := ExtractFilePath(ParamStr(0));
  LExePath := TPath.Combine(LBasePath, 'output\zig-out\bin\hello_debug.exe');

  // Verify exe exists (must be compiled first)
  if not TFile.Exists(LExePath) then
  begin
    TUtils.PrintLn(COLOR_RED + 'ERROR: Executable not found: ' + LExePath);
    TUtils.PrintLn(COLOR_YELLOW + 'Compile hello_debug.pas first to produce the exe.');
    Exit;
  end;

  TUtils.PrintLn('Exe: ' + LExePath);
  TUtils.PrintLn('');

  // Create debugger and start DAP session
  LDebugger := TMorDebug.Create();
  try
    if not LDebugger.Start() then
    begin
      TUtils.PrintLn(COLOR_RED + 'ERROR: Failed to start DAP: ' + LDebugger.GetLastError());
      Exit;
    end;

    if not LDebugger.Initialize() then
    begin
      TUtils.PrintLn(COLOR_RED + 'ERROR: Failed to initialize DAP: ' + LDebugger.GetLastError());
      Exit;
    end;

    TUtils.PrintLn(COLOR_GREEN + 'DAP session ready.');
    TUtils.PrintLn('');

    // Launch REPL - handles launch, breakpoints, interactive loop
    LREPL := TMorDebugREPL.Create();
    try
      LREPL.Debugger := LDebugger;
      LREPL.Run(LExePath);
    finally
      LREPL.Free();
    end;

  finally
    LDebugger.Free();
  end;

  TUtils.PrintLn('');
  TUtils.PrintLn('========================================');
  TUtils.PrintLn('Debug REPL Test Complete');
  TUtils.PrintLn('========================================');
end;

end.
