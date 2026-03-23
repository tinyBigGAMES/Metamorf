{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

program Myra;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Myra.CLI in 'Myra.CLI.pas',
  Myra.CodeGen in 'Myra.CodeGen.pas',
  Myra.Compiler in 'Myra.Compiler.pas',
  Myra.Grammar in 'Myra.Grammar.pas',
  Myra.Lexer in 'Myra.Lexer.pas',
  Myra.Semantics in 'Myra.Semantics.pas',
  Myra.Tester in 'Myra.Tester.pas',
  UMyra in 'UMyra.pas',
  Myra.Common in 'Myra.Common.pas';

begin
  RunMyra();
end.

