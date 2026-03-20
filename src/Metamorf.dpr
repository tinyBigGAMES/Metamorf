program Metamorf;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Metamorf.API in 'Metamorf.API.pas',
  Metamorf.Build in 'Metamorf.Build.pas',
  Metamorf.CodeGen in 'Metamorf.CodeGen.pas',
  Metamorf.Common in 'Metamorf.Common.pas',
  Metamorf.Config in 'Metamorf.Config.pas',
  Metamorf.Cpp.CodeGen in 'Metamorf.Cpp.CodeGen.pas',
  Metamorf.Cpp.Grammar in 'Metamorf.Cpp.Grammar.pas',
  Metamorf.Cpp.Lexer in 'Metamorf.Cpp.Lexer.pas',
  Metamorf.Cpp in 'Metamorf.Cpp.pas',
  Metamorf.IR in 'Metamorf.IR.pas',
  Metamorf.Lang.CLI in 'Metamorf.Lang.CLI.pas',
  Metamorf.Lang.CodeGen in 'Metamorf.Lang.CodeGen.pas',
  Metamorf.Lang.Common in 'Metamorf.Lang.Common.pas',
  Metamorf.Lang.Grammar in 'Metamorf.Lang.Grammar.pas',
  Metamorf.Lang.Interp in 'Metamorf.Lang.Interp.pas',
  Metamorf.Lang.Lexer in 'Metamorf.Lang.Lexer.pas',
  Metamorf.Lang in 'Metamorf.Lang.pas',
  Metamorf.Lang.Semantics in 'Metamorf.Lang.Semantics.pas',
  Metamorf.LangConfig in 'Metamorf.LangConfig.pas',
  Metamorf.Lexer in 'Metamorf.Lexer.pas',
  Metamorf.Parser in 'Metamorf.Parser.pas',
  Metamorf.Resources in 'Metamorf.Resources.pas',
  Metamorf.Semantics in 'Metamorf.Semantics.pas',
  Metamorf.TOML in 'Metamorf.TOML.pas',
  Metamorf.Utils in 'Metamorf.Utils.pas',
  UMetamorf in 'UMetamorf.pas';

begin
  RunMetamorf();
end.
