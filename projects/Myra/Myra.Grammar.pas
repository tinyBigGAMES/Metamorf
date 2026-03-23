{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit Myra.Grammar;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigMyraGrammar(const APax: TMetamorf);

implementation

uses
  System.SysUtils,
  System.Rtti,
  Metamorf.Common;

// =========================================================================
// PREFIX HANDLERS
// =========================================================================

procedure RegisterLiteralPrefixes(const APax: TMetamorf);
begin
  APax.Config().RegisterLiteralPrefixes();

  // C-string literal: "..." — not covered by RegisterLiteralPrefixes()
  APax.Config().RegisterPrefix('literal.cstring', 'expr.cstring',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);

  // Wide-string literal: w"..." — not covered by RegisterLiteralPrefixes()
  APax.Config().RegisterPrefix('literal.wstring', 'expr.wstring',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterNilLiteral(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('keyword.nil', 'expr.nil',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterBooleanLiterals(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('keyword.true', 'expr.bool',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);

  APax.Config().RegisterPrefix('keyword.false', 'expr.bool',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterUnaryOps(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('keyword.not', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('!'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(35)));
      Result := LNode;
    end);

  APax.Config().RegisterPrefix('op.minus', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('-'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(35)));
      Result := LNode;
    end);

  // &expr (C++ address-of — shared operator, prefix = address-of)
  APax.Config().RegisterPrefix('op.ampersand', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('&'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(35)));
      Result := LNode;
    end);

  // *expr (C++ dereference — shared operator, prefix = deref, infix = multiply)
  APax.Config().RegisterPrefix('op.multiply', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('*'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(35)));
      Result := LNode;
    end);

  APax.Config().RegisterPrefix('op.plus', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('+'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(35)));
      Result := LNode;
    end);
end;

procedure RegisterAddressOf(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('keyword.address', 'expr.address_of',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'address'
      AParser.Expect('keyword.of');
      LNode.AddChild(TASTNode(AParser.ParseExpression(35)));
      Result := LNode;
    end);
end;

procedure RegisterGroupedExpr(const APax: TMetamorf);
begin
  // Simple grouped expression: ( expr )
  // C++ cast detection is layered on top by Pax.Cpp.Grammar.WrapGroupedExprForCppCast
  APax.Config().RegisterPrefix('delimiter.lparen', 'expr.grouped',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume '('
      LNode := AParser.CreateNode('expr.grouped');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rparen');
      Result := LNode;
    end);
end;

procedure RegisterSetLiteral(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('delimiter.lbracket', 'expr.set_literal',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LElement: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume '['
      if not AParser.Check('delimiter.rbracket') then
      begin
        LElement := AParser.CreateNode('expr.set_element');
        LElement.AddChild(TASTNode(AParser.ParseExpression(0)));
        if AParser.Match('op.range') then
          LElement.AddChild(TASTNode(AParser.ParseExpression(0)));
        LNode.AddChild(LElement);
        while AParser.Match('delimiter.comma') do
        begin
          LElement := AParser.CreateNode('expr.set_element');
          LElement.AddChild(TASTNode(AParser.ParseExpression(0)));
          if AParser.Match('op.range') then
            LElement.AddChild(TASTNode(AParser.ParseExpression(0)));
          LNode.AddChild(LElement);
        end;
      end;
      AParser.Expect('delimiter.rbracket');
      Result := LNode;
    end);
end;

procedure RegisterSelfExpr(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('keyword.self', 'expr.self',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterParentExpr(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('keyword.parent', 'expr.parent',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterVarargsExpr(const APax: TMetamorf);
begin
  APax.Config().RegisterPrefix('keyword.varargs', 'expr.varargs',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

// =========================================================================
// INFIX HANDLERS
// =========================================================================

procedure RegisterAssignment(const APax: TMetamorf);

  procedure RegAssignOp(const APax: TMetamorf;
    const ATokenKind, ACppOp: string);
  begin
    APax.Config().RegisterInfixRight(ATokenKind, 2, 'expr.assign',
      function(AParser: TParserBase;
        ALeft: TASTNodeBase): TASTNodeBase
      var
        LNode: TASTNode;
      begin
        LNode := AParser.CreateNode();
        LNode.SetAttr('op', TValue.From<string>(ACppOp));
        AParser.Consume();
        LNode.AddChild(TASTNode(ALeft));
        LNode.AddChild(TASTNode(
          AParser.ParseExpression(AParser.CurrentInfixPowerRight())));
        Result := LNode;
      end);
  end;

begin
  RegAssignOp(APax, 'op.assign',       '=');
  RegAssignOp(APax, 'op.plus_assign',  '+=');
  RegAssignOp(APax, 'op.minus_assign', '-=');
  RegAssignOp(APax, 'op.mul_assign',   '*=');
  RegAssignOp(APax, 'op.div_assign',   '/=');
end;

procedure RegisterArithmeticOps(const APax: TMetamorf);
begin
  APax.Config().RegisterBinaryOp('op.plus', 20, '+');
  APax.Config().RegisterBinaryOp('op.minus', 20, '-');
  APax.Config().RegisterBinaryOp('op.multiply', 30, '*');
  APax.Config().RegisterBinaryOp('op.divide', 30, '/');

  APax.Config().RegisterInfixLeft('keyword.div', 30, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('/'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  APax.Config().RegisterInfixLeft('keyword.mod', 30, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('%'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

procedure RegisterComparisonOps(const APax: TMetamorf);
begin
  APax.Config().RegisterBinaryOp('op.eq',  10, '==');
  APax.Config().RegisterBinaryOp('op.neq', 10, '!=');
  APax.Config().RegisterBinaryOp('op.lt',  10, '<');
  APax.Config().RegisterBinaryOp('op.gt',  10, '>');
  APax.Config().RegisterBinaryOp('op.lte', 10, '<=');
  APax.Config().RegisterBinaryOp('op.gte', 10, '>=');
end;

procedure RegisterLogicalOps(const APax: TMetamorf);
begin
  APax.Config().RegisterBinaryOp('keyword.and', 8, '&&');
  APax.Config().RegisterBinaryOp('keyword.or',  6, '||');
  APax.Config().RegisterBinaryOp('keyword.xor', 8, '^');
end;

procedure RegisterBitwiseShiftOps(const APax: TMetamorf);
begin
  APax.Config().RegisterInfixLeft('keyword.shl', 25, 'expr.shl',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.shl', AParser.CurrentToken());
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  APax.Config().RegisterInfixLeft('keyword.shr', 25, 'expr.shr',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.shr', AParser.CurrentToken());
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

procedure RegisterCallExpr(const APax: TMetamorf);
begin
  APax.Config().RegisterInfixLeft('delimiter.lparen', 40, 'expr.call',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LLeftKind: string;
      LCallName: string;
      LQVal:     TValue;
    begin
      LLeftKind := TASTNode(ALeft).GetNodeKind();

      // Method call: obj.method(args) or obj->method(args) -> expr.method_call
      if (LLeftKind = 'expr.field_access') or
         (LLeftKind = 'expr.cpp_arrow') then
      begin
        LNode := AParser.CreateNode('expr.method_call', ALeft.GetToken());
        LNode.AddChild(TASTNode(ALeft));  // child 0: field_access
        AParser.Consume();  // consume '('
        if not AParser.Check('delimiter.rparen') then
        begin
          LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
          while AParser.Match('delimiter.comma') do
            LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        end;
        AParser.Expect('delimiter.rparen');
      end
      else
      begin
        // Resolve call name from left node
        if LLeftKind = 'expr.cpp_qualified' then
        begin
          TASTNode(ALeft).GetAttr('qualified.name', LQVal);
          LCallName := LQVal.AsString;
        end
        else if LLeftKind = 'expr.cpp_raw' then
        begin
          TASTNode(ALeft).GetAttr('cpp.raw', LQVal);
          LCallName := LQVal.AsString;
        end
        else
          LCallName := ALeft.GetToken().Text;

        LNode := AParser.CreateNode('expr.call', ALeft.GetToken());
        LNode.SetAttr('call.name', TValue.From<string>(LCallName));
        ALeft.Free();  // name extracted into call.name — free orphaned node
        AParser.Consume();  // consume '('
        if not AParser.Check('delimiter.rparen') then
        begin
          LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
          while AParser.Match('delimiter.comma') do
            LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        end;
        AParser.Expect('delimiter.rparen');
      end;
      Result := LNode;
    end);
end;

procedure RegisterArrayIndex(const APax: TMetamorf);
begin
  APax.Config().RegisterInfixLeft('delimiter.lbracket', 45, 'expr.array_index',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.array_index', ALeft.GetToken());
      AParser.Consume();  // consume '['
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rbracket');
      Result := LNode;
    end);
end;

procedure RegisterFieldAccess(const APax: TMetamorf);
begin
  APax.Config().RegisterInfixLeft('delimiter.dot', 45, 'expr.field_access',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LFieldTok: TToken;
    begin
      AParser.Consume();  // consume '.'
      LFieldTok := AParser.CurrentToken();
      LNode := AParser.CreateNode('expr.field_access', LFieldTok);
      LNode.SetAttr('field.name', TValue.From<string>(LFieldTok.Text));
      LNode.AddChild(TASTNode(ALeft));
      AParser.Consume();  // consume field name
      Result := LNode;
    end);
end;

procedure RegisterPointerDeref(const APax: TMetamorf);
begin
  APax.Config().RegisterInfixLeft('op.deref', 50, 'expr.deref',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume '^'
      LNode := AParser.CreateNode('expr.deref', ALeft.GetToken());
      LNode.AddChild(TASTNode(ALeft));
      Result := LNode;
    end);
end;

procedure RegisterInOperator(const APax: TMetamorf);
begin
  APax.Config().RegisterInfixLeft('keyword.in', 10, 'expr.in',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.in', AParser.CurrentToken());
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

// =========================================================================
// STATEMENT HANDLERS
// =========================================================================

procedure RegisterDirectiveStmt(const APax: TMetamorf);
var
  LHandler: TStatementHandler;
begin
  // Shared handler for all directive kinds — parses: token, optional value, semicolon
  LHandler :=
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LName: string;
    begin
      LNode := AParser.CreateNode();

      // Token text includes '@' prefix — strip it
      LName := AParser.CurrentToken().Text;
      if (LName.Length > 0) and (LName.Chars[0] = '@') then
        LName := LName.Substring(1);
      LNode.SetAttr('directive.name', TValue.From<string>(LName));
      AParser.Consume();  // consume directive token

      // Optional value: ident, cstring, integer, or real
      if AParser.Check(KIND_IDENTIFIER) or
         AParser.Check('literal.cstring') or
         AParser.Check(KIND_INTEGER) or
         AParser.Check(KIND_FLOAT) then
      begin
        LNode.SetAttr('directive.value',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
      end;

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end;

  // Register for generic (unknown) directives
  APax.Config().RegisterStatement('directive', 'stmt.directive', LHandler);

  // Module-level directives (BNF §6)
  APax.Config().RegisterStatement('directive.exeicon',        'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.copydll',        'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.linklibrary',    'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.librarypath',    'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.modulepath',     'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.includepath',    'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.subsystem',      'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.target',         'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.optimize',       'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.addverinfo',     'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.vimajor',        'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.viminor',        'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.vipatch',        'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.viproductname',  'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.videscription',  'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.vifilename',     'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.vicompanyname',  'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.vicopyright',    'stmt.directive', LHandler);

  // Statement-level directives
  APax.Config().RegisterStatement('directive.breakpoint',     'stmt.directive', LHandler);
  APax.Config().RegisterStatement('directive.message',        'stmt.directive', LHandler);
end;

procedure RegisterModuleStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.module', 'stmt.module',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:       TASTNode;
      LImportNode: TASTNode;
      LItemNode:   TASTNode;
      LBodyNode:   TASTNode;
      LBodyChild:  TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'module'
      LNode.SetAttr('module.kind',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume kind
      LNode.SetAttr('module.name',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume name
      AParser.Expect('delimiter.semicolon');

      // Optional directives
      while True do
      begin
        AParser.Check('');  // skip any comment tokens
        if not APax.Config().IsDirectiveKind(AParser.CurrentToken().Kind) then
          Break;
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end;

      // Optional import clause
      if AParser.Match('keyword.import') then
      begin
        LImportNode := AParser.CreateNode('stmt.import_clause',
          AParser.CurrentToken());
        repeat
          LItemNode := AParser.CreateNode('stmt.import_item',
            AParser.CurrentToken());
          LItemNode.SetAttr('import.name',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
          LImportNode.AddChild(LItemNode);
        until not AParser.Match('delimiter.comma');
        AParser.Expect('delimiter.semicolon');
        LNode.AddChild(LImportNode);
      end;

      // Declarations and C++ passthrough
      while AParser.Check('keyword.const') or
            AParser.Check('keyword.type') or
            AParser.Check('keyword.var') or
            AParser.Check('keyword.routine') or
            AParser.Check('keyword.exported') or
            AParser.Check('cpp.op.hash') do
        LNode.AddChild(TASTNode(AParser.ParseStatement()));

      // Optional module body: begin StatementSeq end .
      if AParser.Match('keyword.begin') then
      begin
        LBodyNode := AParser.CreateNode('stmt.module_body');
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LBodyChild := AParser.ParseStatement();
          if LBodyChild <> nil then
            LBodyNode.AddChild(TASTNode(LBodyChild));
        end;
        LNode.AddChild(LBodyNode);
      end;

      AParser.Expect('keyword.end');
      AParser.Expect('delimiter.dot');
      Result := LNode;
    end);
end;

procedure RegisterBeginBlock(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.begin', 'stmt.begin_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:  TASTNode;
      LChild: TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'begin'
      while not AParser.Check('keyword.end') and
            not AParser.Check('keyword.except') and
            not AParser.Check('keyword.finally') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LNode.AddChild(TASTNode(LChild));
      end;
      AParser.Expect('keyword.end');
      Result := LNode;
    end);
end;

procedure RegisterVarBlock(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.var', 'stmt.var_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:       TASTNode;
      LVarNode:    TASTNode;
      LNameTok:    TToken;
      LTypeRaw:    string;
      LAngleDepth: Integer;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'var'
      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LNameTok := AParser.CurrentToken();
        AParser.Consume();
        LVarNode := AParser.CreateNode('stmt.var_decl', LNameTok);
        LVarNode.SetAttr('var.name',
          TValue.From<string>(LNameTok.Text));
        AParser.Expect('delimiter.colon');
        // Collect full type text: handles array[..] of T, pointer to T,
        // std::string, std::vector<int32_t>*, int32_t*, etc.
        if AParser.Check('keyword.array') then
        begin
          LTypeRaw := 'array';
          AParser.Consume();
          if AParser.Match('delimiter.lbracket') then
          begin
            LTypeRaw := LTypeRaw + '[' + AParser.CurrentToken().Text;
            AParser.Consume();  // low bound
            AParser.Expect('op.range');
            LTypeRaw := LTypeRaw + '..' + AParser.CurrentToken().Text + ']';
            AParser.Consume();  // high bound
            AParser.Expect('delimiter.rbracket');
          end;
          AParser.Expect('keyword.of');
          LTypeRaw := LTypeRaw + ' of ' + AParser.CurrentToken().Text;
          AParser.Consume();
        end
        else if AParser.Check('keyword.pointer') then
        begin
          LTypeRaw := 'pointer';
          AParser.Consume();
          if AParser.Match('keyword.to') then
          begin
            if AParser.Match('keyword.const') then
              LTypeRaw := LTypeRaw + ' to const'
            else
              LTypeRaw := LTypeRaw + ' to';
            LTypeRaw := LTypeRaw + ' ' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
        end
        else
        begin
          LTypeRaw := AParser.CurrentToken().Text;
          AParser.Consume();
        end;
        // Follow :: chains
        while AParser.Check('cpp.op.scope') do
        begin
          LTypeRaw := LTypeRaw + '::';
          AParser.Consume();
          LTypeRaw := LTypeRaw + AParser.CurrentToken().Text;
          AParser.Consume();
        end;
        // Follow template <...>
        if AParser.Check('op.lt') then
        begin
          LTypeRaw := LTypeRaw + '<';
          AParser.Consume();
          LAngleDepth := 1;
          while (LAngleDepth > 0) and
                not AParser.Check(KIND_EOF) do
          begin
            if AParser.Check('op.gt') then
            begin
              Dec(LAngleDepth);
              if LAngleDepth > 0 then
              begin
                LTypeRaw := LTypeRaw + '>';
                AParser.Consume();
              end;
            end
            else
            begin
              if AParser.Check('op.lt') then
                Inc(LAngleDepth);
              LTypeRaw := LTypeRaw + AParser.CurrentToken().Text;
              AParser.Consume();
            end;
          end;
          LTypeRaw := LTypeRaw + '>';
          AParser.Consume();  // consume closing >
        end;
        // Follow trailing *
        while AParser.Check('op.multiply') do
        begin
          LTypeRaw := LTypeRaw + '*';
          AParser.Consume();
        end;
        LVarNode.SetAttr('var.type_text',
          TValue.From<string>(LTypeRaw));
        if AParser.Match('op.eq') then
          LVarNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        AParser.Expect('delimiter.semicolon');
        if AParser.Match('keyword.external') then
        begin
          LVarNode.SetAttr('var.external', TValue.From<Boolean>(True));
          if AParser.Check('literal.cstring') or
             AParser.Check(KIND_IDENTIFIER) then
          begin
            LVarNode.SetAttr('var.external_name',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
          end;
          AParser.Expect('delimiter.semicolon');
        end;
        LNode.AddChild(LVarNode);
      end;
      Result := LNode;
    end);
end;

procedure RegisterConstBlock(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.const', 'stmt.const_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LConstNode: TASTNode;
      LNameTok:   TToken;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'const'
      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LNameTok := AParser.CurrentToken();
        AParser.Consume();
        LConstNode := AParser.CreateNode('stmt.const_decl', LNameTok);
        LConstNode.SetAttr('const.name',
          TValue.From<string>(LNameTok.Text));
        if AParser.Match('delimiter.colon') then
        begin
          LConstNode.SetAttr('const.type_text',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
        end;
        AParser.Expect('op.eq');
        LConstNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        AParser.Expect('delimiter.semicolon');
        LNode.AddChild(LConstNode);
      end;
      Result := LNode;
    end);
end;

procedure RegisterTypeBlock(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.type', 'stmt.type_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:       TASTNode;
      LDeclNode:   TASTNode;
      LNameTok:    TToken;
      LFieldNode:  TASTNode;
      LFieldTok:   TToken;
      LChoiceNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'type'
      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LNameTok := AParser.CurrentToken();
        AParser.Consume();
        AParser.Expect('op.eq');
        LDeclNode := AParser.CreateNode('stmt.type_decl', LNameTok);
        LDeclNode.SetAttr('decl.name', TValue.From<string>(LNameTok.Text));

        if AParser.Check('keyword.record') then
        begin
          AParser.Consume();
          LDeclNode.SetAttr('type.kind', TValue.From<string>('record'));
          if AParser.Match('keyword.packed') then
            LDeclNode.SetAttr('type.packed', TValue.From<Boolean>(True));
          if AParser.Match('keyword.align') then
          begin
            AParser.Expect('delimiter.lparen');
            LDeclNode.SetAttr('type.align',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
            AParser.Expect('delimiter.rparen');
          end;
          // Parse fields: ident : type [ : bitwidth ] ;
          while not AParser.Check('keyword.end') and
                not AParser.Check(KIND_EOF) do
          begin
            LFieldTok := AParser.CurrentToken();
            LFieldNode := AParser.CreateNode('stmt.field_decl', LFieldTok);
            LFieldNode.SetAttr('field.name',
              TValue.From<string>(LFieldTok.Text));
            AParser.Consume();  // consume field name
            AParser.Expect('delimiter.colon');
            LFieldNode.SetAttr('field.type_text',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();  // consume type
            // Optional bitfield width: : integer
            if AParser.Match('delimiter.colon') then
            begin
              LFieldNode.SetAttr('field.bitwidth',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();
            end;
            AParser.Expect('delimiter.semicolon');
            LDeclNode.AddChild(LFieldNode);
          end;
          AParser.Expect('keyword.end');
        end
        else if AParser.Check('keyword.object') then
        begin
          AParser.Consume();
          LDeclNode.SetAttr('type.kind', TValue.From<string>('object'));
          if AParser.Match('delimiter.lparen') then
          begin
            LDeclNode.SetAttr('type.parent',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
            AParser.Expect('delimiter.rparen');
          end;
          // Fields and methods
          while not AParser.Check('keyword.end') and
                not AParser.Check(KIND_EOF) do
          begin
            if AParser.Check('keyword.method') then
              LDeclNode.AddChild(TASTNode(AParser.ParseStatement()))
            else
            begin
              LFieldTok := AParser.CurrentToken();
              LFieldNode := AParser.CreateNode('stmt.field_decl', LFieldTok);
              LFieldNode.SetAttr('field.name',
                TValue.From<string>(LFieldTok.Text));
              AParser.Consume();
              AParser.Expect('delimiter.colon');
              LFieldNode.SetAttr('field.type_text',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();
              if AParser.Match('delimiter.colon') then
              begin
                LFieldNode.SetAttr('field.bitwidth',
                  TValue.From<string>(AParser.CurrentToken().Text));
                AParser.Consume();
              end;
              AParser.Expect('delimiter.semicolon');
              LDeclNode.AddChild(LFieldNode);
            end;
          end;
          AParser.Expect('keyword.end');
        end
        else if AParser.Check('keyword.overlay') then
        begin
          AParser.Consume();
          LDeclNode.SetAttr('type.kind', TValue.From<string>('overlay'));
          while not AParser.Check('keyword.end') and
                not AParser.Check(KIND_EOF) do
          begin
            LFieldTok := AParser.CurrentToken();
            LFieldNode := AParser.CreateNode('stmt.field_decl', LFieldTok);
            LFieldNode.SetAttr('field.name',
              TValue.From<string>(LFieldTok.Text));
            AParser.Consume();
            AParser.Expect('delimiter.colon');
            LFieldNode.SetAttr('field.type_text',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
            AParser.Expect('delimiter.semicolon');
            LDeclNode.AddChild(LFieldNode);
          end;
          AParser.Expect('keyword.end');
        end
        else if AParser.Check('keyword.choices') then
        begin
          AParser.Consume();
          LDeclNode.SetAttr('type.kind', TValue.From<string>('choices'));
          AParser.Expect('delimiter.lparen');
          repeat
            begin
              LChoiceNode := AParser.CreateNode('stmt.choices_value',
                AParser.CurrentToken());
              LChoiceNode.SetAttr('choice.name',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();
              if AParser.Match('op.eq') then
                LChoiceNode.AddChild(TASTNode(AParser.ParseExpression(0)));
              LDeclNode.AddChild(LChoiceNode);
            end;
          until not AParser.Match('delimiter.comma');
          AParser.Expect('delimiter.rparen');
        end
        else if AParser.Check('keyword.array') then
        begin
          AParser.Consume();
          LDeclNode.SetAttr('type.kind', TValue.From<string>('array'));
          if AParser.Match('delimiter.lbracket') then
          begin
            if not AParser.Check('delimiter.rbracket') then
            begin
              LDeclNode.SetAttr('type.array_low',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();
              AParser.Expect('op.range');
              LDeclNode.SetAttr('type.array_high',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();
            end;
            AParser.Expect('delimiter.rbracket');
          end;
          AParser.Expect('keyword.of');
          LDeclNode.SetAttr('type.elem_type',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
        end
        else if AParser.Check('keyword.pointer') then
        begin
          AParser.Consume();
          LDeclNode.SetAttr('type.kind', TValue.From<string>('pointer'));
          if AParser.Match('keyword.to') then
          begin
            if AParser.Match('keyword.const') then
              LDeclNode.SetAttr('type.pointer_const', TValue.From<Boolean>(True));
            LDeclNode.SetAttr('type.pointee',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
          end;
        end
        else if AParser.Check('keyword.set') then
        begin
          AParser.Consume();
          LDeclNode.SetAttr('type.kind', TValue.From<string>('set'));
          if AParser.Match('keyword.of') then
          begin
            LDeclNode.SetAttr('type.elem_type',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
          end;
        end
        else
        begin
          LDeclNode.SetAttr('type.kind', TValue.From<string>('alias'));
          LDeclNode.SetAttr('type.alias_text',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
        end;
        AParser.Expect('delimiter.semicolon');
        LNode.AddChild(LDeclNode);
      end;
      Result := LNode;
    end);
end;

procedure RegisterExportedStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.exported', 'stmt.exported',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseStatement()));
      Result := LNode;
    end);
end;

procedure RegisterRoutineDecl(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.routine', 'stmt.routine_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LParamNode: TASTNode;
      LNameTok:   TToken;
      LModifier:  string;
    begin
      AParser.Consume();  // consume 'routine'
      LNode := AParser.CreateNode('stmt.routine_decl', AParser.CurrentToken());
      if AParser.Check('literal.cstring') then
      begin
        LNode.SetAttr('decl.linkage',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
      end;
      LNameTok := AParser.CurrentToken();
      LNode.SetAttr('decl.name', TValue.From<string>(LNameTok.Text));
      AParser.Consume();
      if AParser.Match('delimiter.lparen') then
      begin
        if not AParser.Check('delimiter.rparen') then
        begin
          if AParser.Check('op.ellipsis') then
          begin
            LNode.SetAttr('decl.variadic', TValue.From<Boolean>(True));
            AParser.Consume();
          end
          else
          begin
            repeat
              LModifier := '';
              if AParser.Match('keyword.var') then
                LModifier := 'var'
              else if AParser.Match('keyword.const') then
                LModifier := 'const';
              LParamNode := AParser.CreateNode('stmt.param_decl',
                AParser.CurrentToken());
              LParamNode.SetAttr('param.modifier',
                TValue.From<string>(LModifier));
              LParamNode.SetAttr('param.name',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();
              AParser.Expect('delimiter.colon');
              LParamNode.SetAttr('param.type_text',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();
              LNode.AddChild(LParamNode);
              if AParser.Check('op.ellipsis') then
              begin
                LNode.SetAttr('decl.variadic', TValue.From<Boolean>(True));
                AParser.Consume();
                Break;
              end;
            until not AParser.Match('delimiter.semicolon');
          end;
        end;
        AParser.Expect('delimiter.rparen');
      end;
      if AParser.Match('delimiter.colon') then
      begin
        LNode.SetAttr('decl.return_type',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
      end;
      AParser.Expect('delimiter.semicolon');
      if AParser.Match('keyword.external') then
      begin
        LNode.SetAttr('decl.external', TValue.From<Boolean>(True));
        if AParser.Check('literal.cstring') or
           AParser.Check(KIND_IDENTIFIER) then
        begin
          LNode.SetAttr('decl.external_name',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
        end;
        AParser.Expect('delimiter.semicolon');
      end
      else
      begin
        while AParser.Check('keyword.type') or
              AParser.Check('keyword.const') or
              AParser.Check('keyword.var') do
          LNode.AddChild(TASTNode(AParser.ParseStatement()));
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
        AParser.Expect('delimiter.semicolon');
      end;
      Result := LNode;
    end);
end;

procedure RegisterMethodDecl(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.method', 'stmt.method_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LParamNode: TASTNode;
      LModifier:  string;
    begin
      AParser.Consume();
      LNode := AParser.CreateNode('stmt.method_decl', AParser.CurrentToken());
      LNode.SetAttr('decl.name',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      if AParser.Match('delimiter.lparen') then
      begin
        if not AParser.Check('delimiter.rparen') then
        begin
          repeat
            LModifier := '';
            if AParser.Match('keyword.var') then
              LModifier := 'var'
            else if AParser.Match('keyword.const') then
              LModifier := 'const';
            LParamNode := AParser.CreateNode('stmt.param_decl',
              AParser.CurrentToken());
            LParamNode.SetAttr('param.modifier',
              TValue.From<string>(LModifier));
            LParamNode.SetAttr('param.name',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
            AParser.Expect('delimiter.colon');
            LParamNode.SetAttr('param.type_text',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();
            LNode.AddChild(LParamNode);
          until not AParser.Match('delimiter.semicolon');
        end;
        AParser.Expect('delimiter.rparen');
      end;
      if AParser.Match('delimiter.colon') then
      begin
        LNode.SetAttr('decl.return_type',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
      end;
      AParser.Expect('delimiter.semicolon');
      while AParser.Check('keyword.var') do
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      LNode.AddChild(TASTNode(AParser.ParseStatement()));
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterIfStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.if', 'stmt.if',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LThenNode: TASTNode;
      LElseNode: TASTNode;
      LChild:    TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('keyword.then');
      LThenNode := AParser.CreateNode('stmt.then_branch');
      while not AParser.Check('keyword.else') and
            not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LThenNode.AddChild(TASTNode(LChild));
      end;
      LNode.AddChild(LThenNode);
      if AParser.Match('keyword.else') then
      begin
        LElseNode := AParser.CreateNode('stmt.else_branch');
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LElseNode.AddChild(TASTNode(LChild));
        end;
        LNode.AddChild(LElseNode);
      end;
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterWhileStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.while', 'stmt.while',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:  TASTNode;
      LChild: TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('keyword.do');
      while not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LNode.AddChild(TASTNode(LChild));
      end;
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterForStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.for', 'stmt.for',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:  TASTNode;
      LChild: TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      LNode.SetAttr('for.var',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      AParser.Expect('op.assign');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      if AParser.Check('keyword.to') then
      begin
        LNode.SetAttr('for.dir', TValue.From<string>('to'));
        AParser.Consume();
      end
      else
      begin
        AParser.Expect('keyword.downto');
        LNode.SetAttr('for.dir', TValue.From<string>('downto'));
      end;
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('keyword.do');
      while not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LNode.AddChild(TASTNode(LChild));
      end;
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterRepeatStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.repeat', 'stmt.repeat',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:  TASTNode;
      LChild: TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      while not AParser.Check('keyword.until') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LNode.AddChild(TASTNode(LChild));
      end;
      AParser.Expect('keyword.until');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterMatchStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.match', 'stmt.match',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LArmNode:   TASTNode;
      LElseNode:  TASTNode;
      LLabelNode: TASTNode;
      LChild:     TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'match'
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));  // selector
      AParser.Expect('keyword.of');

      // Parse match arms until 'else' or 'end'
      while not AParser.Check('keyword.else') and
            not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
      begin
        LArmNode := AParser.CreateNode('stmt.match_arm', AParser.CurrentToken());

        // Parse label list: expr[..expr] { "," expr[..expr] } ":"
        LLabelNode := AParser.CreateNode('stmt.match_label', AParser.CurrentToken());
        LLabelNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        if AParser.Match('op.range') then
          LLabelNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        LArmNode.AddChild(LLabelNode);

        while AParser.Match('delimiter.comma') do
        begin
          LLabelNode := AParser.CreateNode('stmt.match_label', AParser.CurrentToken());
          LLabelNode.AddChild(TASTNode(AParser.ParseExpression(0)));
          if AParser.Match('op.range') then
            LLabelNode.AddChild(TASTNode(AParser.ParseExpression(0)));
          LArmNode.AddChild(LLabelNode);
        end;

        AParser.Expect('delimiter.colon');

        // Parse statement sequence for this arm
        while not AParser.Check('keyword.else') and
              not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) and
              not (AParser.Check(KIND_INTEGER) or
                   AParser.Check(KIND_IDENTIFIER)) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LArmNode.AddChild(TASTNode(LChild));
        end;

        LNode.AddChild(LArmNode);
      end;

      // Optional else branch
      if AParser.Match('keyword.else') then
      begin
        LElseNode := AParser.CreateNode('stmt.match_else');
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LElseNode.AddChild(TASTNode(LChild));
        end;
        LNode.AddChild(LElseNode);
      end;

      AParser.Expect('keyword.end');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterReturnStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.return', 'stmt.return',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      if not AParser.Check('delimiter.semicolon') and
         not AParser.Check('keyword.end') and
         not AParser.Check(KIND_EOF) then
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterGuardStmt(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.guard', 'stmt.guard',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LBodyNode: TASTNode;
      LExcNode:  TASTNode;
      LFinNode:  TASTNode;
      LChild:    TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      LBodyNode := AParser.CreateNode('stmt.guard_body');
      while not AParser.Check('keyword.except') and
            not AParser.Check('keyword.finally') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LBodyNode.AddChild(TASTNode(LChild));
      end;
      LNode.AddChild(LBodyNode);
      if AParser.Match('keyword.except') then
      begin
        LExcNode := AParser.CreateNode('stmt.except_block');
        while not AParser.Check('keyword.finally') and
              not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LExcNode.AddChild(TASTNode(LChild));
        end;
        LNode.AddChild(LExcNode);
        if AParser.Match('keyword.finally') then
        begin
          LFinNode := AParser.CreateNode('stmt.finally_block');
          while not AParser.Check('keyword.end') and
                not AParser.Check(KIND_EOF) do
          begin
            LChild := AParser.ParseStatement();
            if LChild <> nil then
              LFinNode.AddChild(TASTNode(LChild));
          end;
          LNode.AddChild(LFinNode);
        end;
      end
      else if AParser.Match('keyword.finally') then
      begin
        LFinNode := AParser.CreateNode('stmt.finally_block');
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LFinNode.AddChild(TASTNode(LChild));
        end;
        LNode.AddChild(LFinNode);
      end;
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterRaiseStmts(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.raiseexception', 'stmt.raiseexception',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Expect('delimiter.lparen');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rparen');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);

  APax.Config().RegisterStatement('keyword.raiseexceptioncode', 'stmt.raiseexceptioncode',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Expect('delimiter.lparen');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.comma');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rparen');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterOneArgStmt(const APax: TMetamorf;
  const AKeyword, ANodeKind: string);
begin
  APax.Config().RegisterStatement(AKeyword, ANodeKind,
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Expect('delimiter.lparen');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rparen');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterTwoArgStmt(const APax: TMetamorf;
  const AKeyword, ANodeKind: string);
begin
  APax.Config().RegisterStatement(AKeyword, ANodeKind,
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Expect('delimiter.lparen');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.comma');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rparen');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterMemoryStmts(const APax: TMetamorf);
begin
  RegisterOneArgStmt(APax, 'keyword.create',    'stmt.create');
  RegisterOneArgStmt(APax, 'keyword.destroy',   'stmt.destroy');
  RegisterOneArgStmt(APax, 'keyword.getmem',    'stmt.getmem');
  RegisterOneArgStmt(APax, 'keyword.freemem',   'stmt.freemem');
  RegisterTwoArgStmt(APax, 'keyword.resizemem', 'stmt.resizemem');
  RegisterTwoArgStmt(APax, 'keyword.setlength', 'stmt.setlength');
end;

procedure RegisterWriteStmts(const APax: TMetamorf);
begin
  APax.Config().RegisterStatement('keyword.writeln', 'stmt.writeln',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Expect('delimiter.lparen');
      if not AParser.Check('delimiter.rparen') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        while AParser.Match('delimiter.comma') do
          LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      end;
      AParser.Expect('delimiter.rparen');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);

  APax.Config().RegisterStatement('keyword.write', 'stmt.write',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Expect('delimiter.lparen');
      if not AParser.Check('delimiter.rparen') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        while AParser.Match('delimiter.comma') do
          LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      end;
      AParser.Expect('delimiter.rparen');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterOneIntrinsic(const APax: TMetamorf;
  const AKeyword, ACppName: string);
begin
  APax.Config().RegisterPrefix(AKeyword, 'expr.call',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.call', AParser.CurrentToken());
      LNode.SetAttr('call.name', TValue.From<string>(ACppName));
      AParser.Consume();
      AParser.Expect('delimiter.lparen');
      if not AParser.Check('delimiter.rparen') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        while AParser.Match('delimiter.comma') do
          LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      end;
      AParser.Expect('delimiter.rparen');
      Result := LNode;
    end);
end;

procedure RegisterIntrinsics(const APax: TMetamorf);
begin
  RegisterOneIntrinsic(APax, 'keyword.len',                  'mor_len');
  RegisterOneIntrinsic(APax, 'keyword.size',                 'sizeof');
  RegisterOneIntrinsic(APax, 'keyword.utf8',                 'mor_utf8');
  RegisterOneIntrinsic(APax, 'keyword.paramcount',           'mor_paramcount');
  RegisterOneIntrinsic(APax, 'keyword.paramstr',             'mor_paramstr');
  RegisterOneIntrinsic(APax, 'keyword.getexceptioncode',     'mor_exc_code');
  RegisterOneIntrinsic(APax, 'keyword.getexceptionmessage',  'mor_exc_msg');
end;

// =========================================================================
// Public Entry Point
// =========================================================================

procedure ConfigMyraGrammar(const APax: TMetamorf);
begin
  // Prefix handlers
  RegisterLiteralPrefixes(APax);
  RegisterNilLiteral(APax);
  RegisterBooleanLiterals(APax);
  RegisterUnaryOps(APax);
  RegisterAddressOf(APax);
  RegisterGroupedExpr(APax);
  RegisterSetLiteral(APax);
  RegisterSelfExpr(APax);
  RegisterParentExpr(APax);
  RegisterVarargsExpr(APax);

  // Infix handlers
  RegisterAssignment(APax);
  RegisterArithmeticOps(APax);
  RegisterComparisonOps(APax);
  RegisterLogicalOps(APax);
  RegisterBitwiseShiftOps(APax);
  RegisterCallExpr(APax);
  RegisterArrayIndex(APax);
  RegisterFieldAccess(APax);
  RegisterPointerDeref(APax);
  RegisterInOperator(APax);

  // Statement handlers
  RegisterDirectiveStmt(APax);
  RegisterModuleStmt(APax);
  RegisterBeginBlock(APax);
  RegisterVarBlock(APax);
  RegisterConstBlock(APax);
  RegisterTypeBlock(APax);
  RegisterExportedStmt(APax);
  RegisterRoutineDecl(APax);
  RegisterMethodDecl(APax);
  RegisterIfStmt(APax);
  RegisterWhileStmt(APax);
  RegisterForStmt(APax);
  RegisterRepeatStmt(APax);
  RegisterMatchStmt(APax);
  RegisterReturnStmt(APax);
  RegisterGuardStmt(APax);
  RegisterRaiseStmts(APax);
  RegisterMemoryStmts(APax);
  RegisterWriteStmts(APax);
  RegisterIntrinsics(APax);
end;

end.
