{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

program Mor;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UMor in 'UMor.pas',
  Metamorf.CLI in '..\..\src\Metamorf.CLI.pas';

begin
  RunCLI();
end.
