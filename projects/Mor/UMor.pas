{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UMor;

{$I Metamorf.Defines.inc}

interface

procedure RunCLI();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Metamorf.Utils,
  Metamorf.Engine,
  Metamorf.Build,
  Metamorf.CLI;

procedure RunCLI();
var
  LCLI: TMorCLI;
begin
 try
    ExitCode := 0;
    LCLI := TMorCLI.Create();
    try
      LCLI.Execute();
    finally
      LCLI.Free();
    end;
  except
    on E: Exception do
    begin
      TMorUtils.PrintLn('');
      TMorUtils.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message + COLOR_RESET);
    end;
  end;
end;

end.
