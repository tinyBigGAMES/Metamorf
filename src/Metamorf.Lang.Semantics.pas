{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lang.Semantics;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigSemantics(const AMetamorf: TMetamorf);

implementation

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Metamorf.Common;

// =========================================================================
// SEMANTIC HANDLERS
// =========================================================================

procedure RegisterRootHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('root',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      // Walk all top-level declarations
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterLanguageDeclHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.language_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LAttr: TValue;
      LName: string;
    begin
      ANode.GetAttr('name', LAttr);
      LName := LAttr.AsString;

      if LName = '' then
        ASem.AddSemanticError(ANode, 'M001', 'Language name cannot be empty');

      // Declare the language name in global scope
      ASem.DeclareSymbol(LName, ANode);
    end);
end;

procedure RegisterTokensBlockHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.tokens_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      // Visit all token declarations — duplicates caught at child level
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterTokenDeclHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.token_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LAttr:    TValue;
      LKind:    string;
      LPattern: string;
    begin
      ANode.GetAttr('kind', LAttr);
      LKind := LAttr.AsString;

      ANode.GetAttr('pattern', LAttr);
      LPattern := LAttr.AsString;

      if LKind = '' then
        ASem.AddSemanticError(ANode, 'M010', 'Token kind cannot be empty');

      if LPattern = '' then
        ASem.AddSemanticError(ANode, 'M011', 'Token pattern cannot be empty');

      // Register in symbol table to detect duplicates
      if not ASem.DeclareSymbol('token:' + LKind, ANode) then
        ASem.AddSemanticError(ANode, 'M012',
          Format('Duplicate token declaration: ''%s''', [LKind]));
    end);
end;

procedure RegisterGrammarBlockHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.grammar_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterRuleDeclHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.rule_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LAttr:     TValue;
      LNodeKind: string;
    begin
      ANode.GetAttr('node_kind', LAttr);
      LNodeKind := LAttr.AsString;

      if LNodeKind = '' then
        ASem.AddSemanticError(ANode, 'M020',
          'Rule must specify a node kind');

      if not ASem.DeclareSymbol('rule:' + LNodeKind, ANode) then
        ASem.AddSemanticError(ANode, 'M021',
          Format('Duplicate rule for node kind: ''%s''', [LNodeKind]));

      // Visit handler body
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterSemanticsBlockHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.semantics_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterEmitBlockHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.emitters_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterOnHandlerSemantic(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.on_handler',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LAttr:     TValue;
      LNodeKind: string;
    begin
      ANode.GetAttr('node_kind', LAttr);
      LNodeKind := LAttr.AsString;

      if LNodeKind = '' then
        ASem.AddSemanticError(ANode, 'M030',
          'Handler must specify a node kind');

      // Visit handler body for nested validation
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterRoutineDeclHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.routine_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LAttr: TValue;
      LName: string;
    begin
      ANode.GetAttr('name', LAttr);
      LName := LAttr.AsString;

      if LName = '' then
        ASem.AddSemanticError(ANode, 'M040',
          'Routine name cannot be empty');

      if not ASem.DeclareSymbol('routine:' + LName, ANode) then
        ASem.AddSemanticError(ANode, 'M041',
          Format('Duplicate routine: ''%s''', [LName]));

      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterConstBlockHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.const_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterConstDeclHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.const_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LAttr: TValue;
      LName: string;
    begin
      ANode.GetAttr('name', LAttr);
      LName := LAttr.AsString;

      if not ASem.DeclareSymbol('const:' + LName, ANode) then
        ASem.AddSemanticError(ANode, 'M050',
          Format('Duplicate constant: ''%s''', [LName]));
    end);
end;

procedure RegisterTypesBlockHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.types_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterFragmentDeclHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.fragment_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LAttr: TValue;
      LName: string;
    begin
      ANode.GetAttr('name', LAttr);
      LName := LAttr.AsString;

      if not ASem.DeclareSymbol('fragment:' + LName, ANode) then
        ASem.AddSemanticError(ANode, 'M060',
          Format('Duplicate fragment: ''%s''', [LName]));

      ASem.VisitChildren(ANode);
    end);
end;

procedure RegisterPassBlockHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterSemanticRule('meta.pass_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

// =========================================================================
// PUBLIC ENTRY POINT
// =========================================================================

procedure ConfigSemantics(const AMetamorf: TMetamorf);
begin
  RegisterRootHandler(AMetamorf);
  RegisterLanguageDeclHandler(AMetamorf);
  RegisterTokensBlockHandler(AMetamorf);
  RegisterTokenDeclHandler(AMetamorf);
  RegisterGrammarBlockHandler(AMetamorf);
  RegisterRuleDeclHandler(AMetamorf);
  RegisterSemanticsBlockHandler(AMetamorf);
  RegisterEmitBlockHandler(AMetamorf);
  RegisterOnHandlerSemantic(AMetamorf);
  RegisterRoutineDeclHandler(AMetamorf);
  RegisterConstBlockHandler(AMetamorf);
  RegisterConstDeclHandler(AMetamorf);
  RegisterTypesBlockHandler(AMetamorf);
  RegisterFragmentDeclHandler(AMetamorf);
  RegisterPassBlockHandler(AMetamorf);
end;

end.
