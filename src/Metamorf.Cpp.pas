{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Cpp;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigCpp(const AMetamorf: TMetamorf);

implementation

uses
  Metamorf.Cpp.Lexer,
  Metamorf.Cpp.Grammar,
  Metamorf.Cpp.CodeGen;

procedure ConfigCpp(const AMetamorf: TMetamorf);
begin
  ConfigCppTokens(AMetamorf);
  ConfigCppGrammar(AMetamorf);
  ConfigCppCodeGen(AMetamorf);
end;

end.
