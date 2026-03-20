{===============================================================================
  DelphiFmt™ - Delphi Source Code Formatter

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

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
