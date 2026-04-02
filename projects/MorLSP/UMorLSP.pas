{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UMorLSP;

{$I Metamorf.Defines.inc}

interface

procedure RunMorLSP();

implementation

uses
  System.SysUtils,
  Metamorf.Utils,
  Metamorf.LSP;

procedure RunMorLSP();
var
  LServer: TMorLSPServer;
begin
  try
    if ParamCount() < 1 then
    begin
      TUtils.PrintLn('Usage: MorLSP <lang.mor>');
      Exit;
    end;

    LServer := TMorLSPServer.Create();
    try
      LServer.SetMorFile(ParamStr(1));
      LServer.Run();
    finally
      LServer.Free();
    end;

  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message + COLOR_RESET);
    end;
  end;
end;

end.
