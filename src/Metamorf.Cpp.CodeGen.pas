{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Cpp.CodeGen;

{$I Metamorf.Defines.inc}

interface

uses
  System.Rtti,
  Metamorf.API;

procedure ConfigCppCodeGen(const AMetamorf: TMetamorf);

implementation

procedure ConfigCppCodeGen(const AMetamorf: TMetamorf);
begin
  // stmt.cpp_raw — C++ statement passthrough, emitted verbatim to source
  AMetamorf.Config().RegisterEmitter('stmt.cpp_raw',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LRawVal: TValue;
    begin
      TASTNode(ANode).GetAttr('cpp.raw', LRawVal);
      AGen.EmitLine(LRawVal.AsString);
    end);

  // stmt.preprocessor — #include, #define, etc., emitted to header
  AMetamorf.Config().RegisterEmitter('stmt.preprocessor',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LRawVal: TValue;
    begin
      TASTNode(ANode).GetAttr('cpp.raw', LRawVal);
      AGen.EmitLine(LRawVal.AsString, sfHeader);
    end);

  // expr.cpp_raw — C++ expression passthrough, emitted inline
  AMetamorf.Config().RegisterEmitter('expr.cpp_raw',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LRawVal: TValue;
    begin
      TASTNode(ANode).GetAttr('cpp.raw', LRawVal);
      AGen.Emit(LRawVal.AsString);
    end);

  // expr.cpp_cast — C-style cast: (type*)operand
  AMetamorf.Config().RegisterEmitter('expr.cpp_cast',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LRawVal: TValue;
    begin
      TASTNode(ANode).GetAttr('cast.raw', LRawVal);
      AGen.Emit('(%s)', [LRawVal.AsString]);
      AGen.EmitNode(ANode.GetChild(0));
    end);

  // expr.cpp_qualified — scope-resolved name: std::string, etc.
  AMetamorf.Config().RegisterEmitter('expr.cpp_qualified',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LQVal: TValue;
    begin
      TASTNode(ANode).GetAttr('qualified.name', LQVal);
      AGen.Emit(LQVal.AsString);
    end);

  // expr.cpp_arrow — pointer member access: expr->member
  AMetamorf.Config().RegisterEmitter('expr.cpp_arrow',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LFieldVal: TValue;
    begin
      TASTNode(ANode).GetAttr('field.name', LFieldVal);
      AGen.EmitNode(ANode.GetChild(0));
      AGen.Emit('->%s', [LFieldVal.AsString]);
    end);

  // ---- ExprToString overrides for C++ node kinds ----
  // These are needed so TLangConfig.ExprToString can handle C++ nodes
  // when the interp-based emitter calls exprToString().

  // expr.cpp_cast — C-style cast: (type)operand
  AMetamorf.Config().RegisterExprOverride('expr.cpp_cast',
    function(const ANode: TASTNodeBase;
      const ADefault: TExprToStringFunc): string
    var
      LRawVal: TValue;
    begin
      TASTNode(ANode).GetAttr('cast.raw', LRawVal);
      Result := '(' + LRawVal.AsString + ')' + ADefault(ANode.GetChild(0));
    end);

  // expr.cpp_raw — raw C++ expression passthrough
  AMetamorf.Config().RegisterExprOverride('expr.cpp_raw',
    function(const ANode: TASTNodeBase;
      const ADefault: TExprToStringFunc): string
    var
      LRawVal: TValue;
    begin
      TASTNode(ANode).GetAttr('cpp.raw', LRawVal);
      Result := LRawVal.AsString;
    end);

  // expr.cpp_qualified — scope-resolved name: std::string, etc.
  AMetamorf.Config().RegisterExprOverride('expr.cpp_qualified',
    function(const ANode: TASTNodeBase;
      const ADefault: TExprToStringFunc): string
    var
      LQVal: TValue;
    begin
      TASTNode(ANode).GetAttr('qualified.name', LQVal);
      Result := LQVal.AsString;
    end);
end;

end.
