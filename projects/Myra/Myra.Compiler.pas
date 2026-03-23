{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit Myra.Compiler;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  Metamorf.API,
  Metamorf.Cpp,
  Myra.Semantics,
  Myra.Lexer,
  Myra.Grammar,
  Myra.CodeGen;

type
  { TMyraCompiler }
  TMyraCompiler = class(TMetamorf)
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function CreateChild(): TMetamorf; override;
  end;

implementation

{ TMyraCompiler }
constructor TMyraCompiler.Create();
begin
  inherited;

  // Register language surface (order matters: Lang first, then Cpp wrapping)
  ConfigMyraLexer(Self);
  ConfigMyraGrammar(Self);
  ConfigMyraCodeGen(Self);
  ConfigMyraSemantics(Self);

  // C++ cast wrapping needs Lang's delimiter.lparen prefix handler
  ConfigCpp(Self);
end;

destructor TMyraCompiler.Destroy();
begin
  inherited;
end;

function TMyraCompiler.CreateChild(): TMetamorf;
begin
  Result := TMyraCompiler.Create();
end;

end.
