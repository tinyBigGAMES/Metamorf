{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

program DFTestbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UDFTestbed in 'UDFTestbed.pas',
  DelphiFmt.Emitter in 'DelphiFmt.Emitter.pas',
  DelphiFmt.Grammar in 'DelphiFmt.Grammar.pas',
  DelphiFmt.Lexer in 'DelphiFmt.Lexer.pas',
  DelphiFmt in 'DelphiFmt.pas';

begin
  try
    RunTestbed();
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
