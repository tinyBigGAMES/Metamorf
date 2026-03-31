{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

program Metamorf;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Metamorf.Build in 'Metamorf.Build.pas',
  Metamorf.Config in 'Metamorf.Config.pas',
  Metamorf.Resources in 'Metamorf.Resources.pas',
  Metamorf.TOML in 'Metamorf.TOML.pas',
  Metamorf.Utils in 'Metamorf.Utils.pas',
  Metamorf.AST in 'Metamorf.AST.pas',
  Metamorf.Common in 'Metamorf.Common.pas',
  Metamorf.Cpp in 'Metamorf.Cpp.pas',
  Metamorf.Engine in 'Metamorf.Engine.pas',
  Metamorf.Environment in 'Metamorf.Environment.pas',
  Metamorf.GenericLexer in 'Metamorf.GenericLexer.pas',
  Metamorf.GenericParser in 'Metamorf.GenericParser.pas',
  Metamorf.Interpreter in 'Metamorf.Interpreter.pas',
  Metamorf.Lexer in 'Metamorf.Lexer.pas',
  Metamorf.CodeGen in 'Metamorf.CodeGen.pas',
  Metamorf.Parser in 'Metamorf.Parser.pas',
  Metamorf.Scopes in 'Metamorf.Scopes.pas',
  UMetamorf in 'UMetamorf.pas';

begin
  RunMetamorf();
end.
