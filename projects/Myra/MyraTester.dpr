{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

program MyraTester;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Myra.Tester in 'Myra.Tester.pas',
  UMyraTester in 'UMyraTester.pas',
  Metamorf.AST in '..\..\src\Metamorf.AST.pas',
  Metamorf.Build in '..\..\src\Metamorf.Build.pas',
  Metamorf.CLI in '..\..\src\Metamorf.CLI.pas',
  Metamorf.CodeGen in '..\..\src\Metamorf.CodeGen.pas',
  Metamorf.Common in '..\..\src\Metamorf.Common.pas',
  Metamorf.Config in '..\..\src\Metamorf.Config.pas',
  Metamorf.Cpp in '..\..\src\Metamorf.Cpp.pas',
  Metamorf.Debug.Client in '..\..\src\Metamorf.Debug.Client.pas',
  Metamorf.Debug.DAP in '..\..\src\Metamorf.Debug.DAP.pas',
  Metamorf.Debug.PDB in '..\..\src\Metamorf.Debug.PDB.pas',
  Metamorf.Debug.REPL in '..\..\src\Metamorf.Debug.REPL.pas',
  Metamorf.Debug.Runtime in '..\..\src\Metamorf.Debug.Runtime.pas',
  Metamorf.Debug.Server in '..\..\src\Metamorf.Debug.Server.pas',
  Metamorf.Debug.Target in '..\..\src\Metamorf.Debug.Target.pas',
  Metamorf.Engine in '..\..\src\Metamorf.Engine.pas',
  Metamorf.EngineAPI in '..\..\src\Metamorf.EngineAPI.pas',
  Metamorf.Environment in '..\..\src\Metamorf.Environment.pas',
  Metamorf.GenericLexer in '..\..\src\Metamorf.GenericLexer.pas',
  Metamorf.GenericParser in '..\..\src\Metamorf.GenericParser.pas',
  Metamorf.Interpreter in '..\..\src\Metamorf.Interpreter.pas',
  Metamorf.Lexer in '..\..\src\Metamorf.Lexer.pas',
  Metamorf.LSP in '..\..\src\Metamorf.LSP.pas',
  Metamorf.Parser in '..\..\src\Metamorf.Parser.pas',
  Metamorf in '..\..\src\Metamorf.pas',
  Metamorf.Resources in '..\..\src\Metamorf.Resources.pas',
  Metamorf.Scopes in '..\..\src\Metamorf.Scopes.pas',
  Metamorf.TOML in '..\..\src\Metamorf.TOML.pas',
  Metamorf.Utils in '..\..\src\Metamorf.Utils.pas';

begin
  RunMyraTester();
end.
