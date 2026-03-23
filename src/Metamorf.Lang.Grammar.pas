{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lang.Grammar;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigGrammar(const AMetamorf: TMetamorf);

implementation

uses
  System.SysUtils,
  System.Rtti,
  Metamorf.Common;

// =========================================================================
// BLOCK HELPER
// =========================================================================

function ParseBlock(const AParser: TParserBase): TASTNode;
begin
  Result := AParser.CreateNode('meta.block');
  while not AParser.Check('delimiter.rbrace') do
    Result.AddChild(AParser.ParseStatement() as TASTNode);
end;

// =========================================================================
// EXPRESSION PREFIXES
// =========================================================================

procedure RegisterLiteralPrefixes(const AMetamorf: TMetamorf);
begin
  // String literal
  AMetamorf.Config().RegisterPrefix(KIND_STRING, 'expr.literal_string',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LTok  := AParser.CurrentToken();
      LNode := AParser.CreateNode('expr.literal_string');
      LNode.SetAttr('value', LTok.Value);
      AParser.Consume();
      Result := LNode;
    end);

  // Integer literal
  AMetamorf.Config().RegisterPrefix(KIND_INTEGER, 'expr.literal_int',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LTok  := AParser.CurrentToken();
      LNode := AParser.CreateNode('expr.literal_int');
      LNode.SetAttr('value', LTok.Value);
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterBooleanLiterals(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterPrefix('keyword.true', 'expr.literal_bool',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.literal_bool');
      LNode.SetAttr('value', TValue.From<Boolean>(True));
      AParser.Consume();
      Result := LNode;
    end);

  AMetamorf.Config().RegisterPrefix('keyword.false', 'expr.literal_bool',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.literal_bool');
      LNode.SetAttr('value', TValue.From<Boolean>(False));
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterNilLiteral(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterPrefix('keyword.nil', 'expr.literal_nil',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.literal_nil');
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterAttrAccess(const AMetamorf: TMetamorf);
begin
  // @name — attribute access on the current node
  AMetamorf.Config().RegisterPrefix('delimiter.at', 'expr.attr_access',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('expr.attr_access');
      AParser.Consume(); // consume @
      LTok := AParser.CurrentToken();
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume(); // consume identifier
      Result := LNode;
    end);
end;

procedure RegisterIdentPrefix(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterPrefix(KIND_IDENTIFIER, 'expr.ident',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LTok  := AParser.CurrentToken();
      LNode := AParser.CreateNode('expr.ident');
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume();
      Result := LNode;
    end);
end;

procedure RegisterGroupedExpr(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterPrefix('delimiter.lparen', 'expr.group',
    function(AParser: TParserBase): TASTNodeBase
    begin
      AParser.Consume(); // consume (
      Result := AParser.ParseExpression(0);
      AParser.Expect('delimiter.rparen');
    end);
end;

procedure RegisterUnaryNot(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterPrefix('keyword.not', 'expr.unary_not',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.unary_not');
      AParser.Consume(); // consume 'not'
      LNode.AddChild(AParser.ParseExpression(60) as TASTNode);
      Result := LNode;
    end);
end;

procedure RegisterUnaryMinus(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterPrefix('op.minus', 'expr.unary_minus',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.unary_minus');
      AParser.Consume(); // consume -
      LNode.AddChild(AParser.ParseExpression(60) as TASTNode);
      Result := LNode;
    end);
end;

// =========================================================================
// EXPRESSION INFIXES
// =========================================================================

procedure RegisterBinaryOps(const AMetamorf: TMetamorf);

  procedure RegBinOp(const AMetamorf: TMetamorf; const AKind: string;
    const APower: Integer);
  begin
    AMetamorf.Config().RegisterInfixLeft(AKind, APower, 'expr.binary',
      function(AParser: TParserBase;
        ALeft: TASTNodeBase): TASTNodeBase
      var
        LNode: TASTNode;
        LTok:  TToken;
      begin
        LTok  := AParser.CurrentToken();
        LNode := AParser.CreateNode('expr.binary');
        LNode.SetAttr('operator', TValue.From<string>(LTok.Text));
        LNode.AddChild(ALeft as TASTNode);
        AParser.Consume(); // consume operator
        LNode.AddChild(AParser.ParseExpression(
          AParser.CurrentInfixPowerRight()) as TASTNode);
        Result := LNode;
      end);
  end;

begin
  // Logical (low precedence)
  RegBinOp(AMetamorf, 'keyword.or',   10);
  RegBinOp(AMetamorf, 'keyword.and',  20);

  // Comparison
  RegBinOp(AMetamorf, 'op.eq',   30);
  RegBinOp(AMetamorf, 'op.neq',  30);
  RegBinOp(AMetamorf, 'op.lt',   30);
  RegBinOp(AMetamorf, 'op.gt',   30);
  RegBinOp(AMetamorf, 'op.lte',  30);
  RegBinOp(AMetamorf, 'op.gte',  30);

  // Additive
  RegBinOp(AMetamorf, 'op.plus',    40);
  RegBinOp(AMetamorf, 'op.minus',   40);

  // Multiplicative
  RegBinOp(AMetamorf, 'op.multiply', 50);
  RegBinOp(AMetamorf, 'op.divide',   50);
  RegBinOp(AMetamorf, 'op.modulo',   50);
end;

procedure RegisterFieldAccess(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterInfixLeft('delimiter.dot', 70, 'expr.field_access',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('expr.field_access');
      LNode.AddChild(ALeft as TASTNode);
      AParser.Consume(); // consume .
      LTok := AParser.CurrentToken();
      LNode.SetAttr('field', TValue.From<string>(LTok.Text));
      AParser.Consume(); // consume field name
      Result := LNode;
    end);
end;

procedure RegisterCallExpr(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterInfixLeft('delimiter.lparen', 70, 'expr.call',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.call');
      LNode.AddChild(ALeft as TASTNode); // callee
      AParser.Consume(); // consume (

      if not AParser.Check('delimiter.rparen') then
      begin
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
        while AParser.Match('delimiter.comma') do
          LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      end;

      AParser.Expect('delimiter.rparen');
      Result := LNode;
    end);
end;

procedure RegisterArrayIndex(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterInfixLeft('delimiter.lbracket', 70, 'expr.index',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.index');
      LNode.AddChild(ALeft as TASTNode);
      AParser.Consume(); // consume [
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.rbracket');
      Result := LNode;
    end);
end;

// =========================================================================
// HANDLER BODY — CONTROL FLOW STATEMENTS
// =========================================================================

procedure RegisterLetStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.let', 'stmt.let',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('stmt.let');
      AParser.Consume(); // consume 'let'

      LTok := AParser.CurrentToken();
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume(); // consume identifier

      // Optional type annotation
      if AParser.Match('delimiter.colon') then
      begin
        LTok := AParser.CurrentToken();
        LNode.SetAttr('type_name', TValue.From<string>(LTok.Text));
        AParser.Consume();
      end;

      AParser.Expect('op.assign');
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterIfStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.if', 'stmt.if',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LCondNode:  TASTNode;
      LBlockNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.if');
      AParser.Consume(); // consume 'if'

      // Condition
      LCondNode := AParser.CreateNode('meta.condition');
      LCondNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      LNode.AddChild(LCondNode);

      // Then block
      AParser.Expect('delimiter.lbrace');
      LBlockNode := ParseBlock(AParser);
      LNode.AddChild(LBlockNode);
      AParser.Expect('delimiter.rbrace');

      // Else-if / else chains
      while AParser.Check('keyword.else') do
      begin
        AParser.Consume(); // consume 'else'
        if AParser.Check('keyword.if') then
        begin
          LNode.AddChild(AParser.ParseStatement() as TASTNode);
          Break;
        end
        else
        begin
          AParser.Expect('delimiter.lbrace');
          LBlockNode := ParseBlock(AParser);
          LBlockNode.SetAttr('is_else', TValue.From<Boolean>(True));
          LNode.AddChild(LBlockNode);
          AParser.Expect('delimiter.rbrace');
          Break;
        end;
      end;

      Result := LNode;
    end);
end;

procedure RegisterWhileStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.while', 'stmt.while',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.while');
      AParser.Consume(); // consume 'while'
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterForInStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.for', 'stmt.for',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('stmt.for');
      AParser.Consume(); // consume 'for'

      LTok := AParser.CurrentToken();
      LNode.SetAttr('var_name', TValue.From<string>(LTok.Text));
      AParser.Consume();

      AParser.Expect('keyword.in');
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);

      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterMatchStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.match', 'stmt.match',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:    TASTNode;
      LArmNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.match');
      AParser.Consume(); // consume 'match'

      // Subject expression
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);

      AParser.Expect('delimiter.lbrace');

      while not AParser.Check('delimiter.rbrace') do
      begin
        LArmNode := AParser.CreateNode('stmt.match_arm');

        if AParser.Check('keyword.else') then
        begin
          LArmNode.SetAttr('is_default', TValue.From<Boolean>(True));
          AParser.Consume(); // consume 'else'
        end
        else
        begin
          // Pattern(s): value | value | ...
          LArmNode.AddChild(AParser.ParseExpression(0) as TASTNode);
          while AParser.Match('delimiter.pipe') do
            LArmNode.AddChild(AParser.ParseExpression(0) as TASTNode);
        end;

        AParser.Expect('op.fat_arrow');
        AParser.Expect('delimiter.lbrace');
        LArmNode.AddChild(ParseBlock(AParser));
        AParser.Expect('delimiter.rbrace');

        LNode.AddChild(LArmNode);
      end;

      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterGuardStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.guard', 'stmt.guard',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.guard');
      AParser.Consume(); // consume 'guard'
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterReturnStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.return', 'stmt.return',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.return');
      AParser.Consume(); // consume 'return'
      if not AParser.Check('delimiter.semicolon') then
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterTryRecoverStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.try', 'stmt.try_recover',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.try_recover');
      AParser.Consume(); // consume 'try'

      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');

      AParser.Expect('keyword.recover');
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');

      Result := LNode;
    end);
end;

// =========================================================================
// HANDLER BODY — DOMAIN-SPECIFIC STATEMENTS
// =========================================================================

procedure RegisterVisitStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.visit', 'stmt.visit',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('stmt.visit');
      AParser.Consume(); // consume 'visit'

      LTok := AParser.CurrentToken();
      if LTok.Kind = 'keyword.children' then
      begin
        LNode.SetAttr('target', TValue.From<string>('children'));
        AParser.Consume();
      end
      else if LTok.Kind = 'keyword.child' then
      begin
        LNode.SetAttr('target', TValue.From<string>('child'));
        AParser.Consume();
        AParser.Expect('delimiter.lbracket');
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
        AParser.Expect('delimiter.rbracket');
      end
      else if LTok.Kind = 'delimiter.at' then
      begin
        LNode.SetAttr('target', TValue.From<string>('attr'));
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      end
      else
      begin
        LNode.SetAttr('target', TValue.From<string>('expr'));
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      end;

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterEmitStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.emit', 'stmt.emit_to',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('stmt.emit_to');
      AParser.Consume(); // consume 'emit'

      // Check for "to section_name:"
      if AParser.Check('keyword.to') then
      begin
        AParser.Consume(); // consume 'to'
        LTok := AParser.CurrentToken();
        LNode.SetAttr('section', TValue.From<string>(LTok.Text));
        AParser.Consume(); // consume section name
        AParser.Expect('delimiter.colon');
      end;

      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterDeclareStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.declare', 'stmt.declare',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('stmt.declare');
      AParser.Consume(); // consume 'declare'

      // @name
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);

      // as kind
      AParser.Expect('keyword.as');
      LTok := AParser.CurrentToken();
      LNode.SetAttr('symbol_kind', TValue.From<string>(LTok.Text));
      AParser.Consume();

      // Optional: typed expr
      if AParser.Check('keyword.typed') then
      begin
        AParser.Consume();
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      end;

      // Optional: where { key = value; ... }
      if AParser.Check('keyword.where') then
      begin
        AParser.Consume();
        AParser.Expect('delimiter.lbrace');
        LNode.AddChild(ParseBlock(AParser));
        AParser.Expect('delimiter.rbrace');
      end
      else
        AParser.Expect('delimiter.semicolon');

      Result := LNode;
    end);
end;

procedure RegisterLookupStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.lookup', 'stmt.lookup',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('stmt.lookup');
      AParser.Consume(); // consume 'lookup'

      // @name — parse at power above 'or' (10) so Pratt loop stops before 'or'
      LNode.AddChild(AParser.ParseExpression(11) as TASTNode);

      if AParser.Check('op.arrow') then
      begin
        AParser.Consume(); // consume ->
        AParser.Expect('keyword.let');
        LTok := AParser.CurrentToken();
        LNode.SetAttr('bind_name', TValue.From<string>(LTok.Text));
        AParser.Consume();
        AParser.Expect('delimiter.semicolon');
      end
      else if AParser.Check('keyword.or') then
      begin
        AParser.Consume();
        AParser.Expect('delimiter.lbrace');
        LNode.AddChild(ParseBlock(AParser));
        AParser.Expect('delimiter.rbrace');
      end
      else
        AParser.Expect('delimiter.semicolon');

      Result := LNode;
    end);
end;

procedure RegisterScopeStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.scope', 'stmt.scope',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.scope');
      AParser.Consume(); // consume 'scope'
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterSetAttrStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.set', 'stmt.set_attr',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.set_attr');
      AParser.Consume(); // consume 'set'
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('op.assign');
      LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterIndentStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.indent', 'stmt.indent',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.indent');
      AParser.Consume(); // consume 'indent'
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterDiagnosticStatements(const AMetamorf: TMetamorf);

  procedure RegDiag(const AMetamorf: TMetamorf; const AKeyword, ALevel: string);
  begin
    AMetamorf.Config().RegisterStatement(AKeyword, 'stmt.diagnostic',
      function(AParser: TParserBase): TASTNodeBase
      var
        LNode: TASTNode;
      begin
        LNode := AParser.CreateNode('stmt.diagnostic');
        LNode.SetAttr('level', TValue.From<string>(ALevel));
        AParser.Consume();
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
        AParser.Expect('delimiter.semicolon');
        Result := LNode;
      end);
  end;

begin
  RegDiag(AMetamorf, 'keyword.error',   'error');
  RegDiag(AMetamorf, 'keyword.warning', 'warning');
  RegDiag(AMetamorf, 'keyword.hint',    'hint');
  RegDiag(AMetamorf, 'keyword.note',    'note');
  RegDiag(AMetamorf, 'keyword.info',    'info');
end;

procedure RegisterIdentifierStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement(KIND_IDENTIFIER, 'stmt.ident_stmt',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LExprNode: TASTNodeBase;
    begin
      LExprNode := AParser.ParseExpression(0);

      if AParser.Check('op.assign') then
      begin
        LNode := AParser.CreateNode('stmt.assign');
        LNode.AddChild(LExprNode as TASTNode);
        AParser.Consume(); // consume =
        LNode.AddChild(AParser.ParseExpression(0) as TASTNode);
        AParser.Expect('delimiter.semicolon');
        Result := LNode;
      end
      else
      begin
        LNode := AParser.CreateNode('stmt.expr');
        LNode.AddChild(LExprNode as TASTNode);
        AParser.Expect('delimiter.semicolon');
        Result := LNode;
      end;
    end);
end;

// =========================================================================
// TOP-LEVEL — LANGUAGE HEADER
// =========================================================================

procedure RegisterLanguageDecl(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.language', 'meta.language_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.language_decl');
      AParser.Consume(); // consume 'language'

      LTok := AParser.CurrentToken();
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume();

      AParser.Expect('keyword.version');
      LTok := AParser.CurrentToken();
      LNode.SetAttr('version', LTok.Value);
      AParser.Consume();

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterImportStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.import', 'meta.import',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.import');
      AParser.Consume();
      LTok := AParser.CurrentToken();
      LNode.SetAttr('path', LTok.Value);
      AParser.Consume();
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterIncludeStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.include', 'meta.include',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.include');
      AParser.Consume();
      LTok := AParser.CurrentToken();
      LNode.SetAttr('fragment_name', TValue.From<string>(LTok.Text));
      AParser.Consume();
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — TOKENS BLOCK
// =========================================================================

procedure RegisterTokensBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.tokens', 'meta.tokens_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LChild:    TASTNode;
      LTok:      TToken;
      LCategory: string;
      LName:     string;
    begin
      LNode := AParser.CreateNode('meta.tokens_block');
      AParser.Consume(); // consume 'tokens'
      AParser.Expect('delimiter.lbrace');

      while not AParser.Check('delimiter.rbrace') do
      begin
        LTok := AParser.CurrentToken();

        if LTok.Kind = 'keyword.token' then
        begin
          LChild := AParser.CreateNode('meta.token_decl');
          AParser.Consume(); // consume 'token'

          // category.name
          LTok := AParser.CurrentToken();
          LCategory := LTok.Text;
          AParser.Consume();
          AParser.Expect('delimiter.dot');
          LTok := AParser.CurrentToken();
          LName := LTok.Text;
          AParser.Consume();

          LChild.SetAttr('category', TValue.From<string>(LCategory));
          LChild.SetAttr('name', TValue.From<string>(LName));
          LChild.SetAttr('kind', TValue.From<string>(LCategory + '.' + LName));

          AParser.Expect('op.assign');

          LTok := AParser.CurrentToken();
          LChild.SetAttr('pattern', LTok.Value);
          AParser.Consume();

          // Optional flags [caseless, hidden, push mode xxx, pop mode, priority N]
          if AParser.Match('delimiter.lbracket') then
          begin
            while not AParser.Check('delimiter.rbracket') do
            begin
              LTok := AParser.CurrentToken();
              if LTok.Kind = 'keyword.caseless' then
              begin
                LChild.SetAttr('caseless', TValue.From<Boolean>(True));
                AParser.Consume();
              end
              else if LTok.Kind = 'keyword.hidden' then
              begin
                LChild.SetAttr('hidden', TValue.From<Boolean>(True));
                AParser.Consume();
              end
              else if LTok.Kind = 'keyword.priority' then
              begin
                AParser.Consume();
                LTok := AParser.CurrentToken();
                LChild.SetAttr('priority', LTok.Value);
                AParser.Consume();
              end
              else if LTok.Kind = 'keyword.push' then
              begin
                AParser.Consume();
                AParser.Expect('keyword.mode');
                LTok := AParser.CurrentToken();
                LChild.SetAttr('push_mode', TValue.From<string>(LTok.Text));
                AParser.Consume();
              end
              else if LTok.Kind = 'keyword.pop' then
              begin
                AParser.Consume();
                AParser.Expect('keyword.mode');
                LChild.SetAttr('pop_mode', TValue.From<Boolean>(True));
              end
              else if (LTok.Kind = 'identifier') and
                      (LTok.Text = 'noescape') then
              begin
                LChild.SetAttr('noescape', TValue.From<Boolean>(True));
                AParser.Consume();
              end
              else if (LTok.Kind = 'identifier') and
                      (LTok.Text = 'close') then
              begin
                AParser.Consume(); // consume 'close'
                LTok := AParser.CurrentToken();
                LChild.SetAttr('close_pattern', LTok.Value);
                AParser.Consume(); // consume the string value
              end
              else if LTok.Kind = 'identifier' then
              begin
                // Directive conditional roles: define, ifdef, etc.
                LChild.SetAttr('directive_role',
                  TValue.From<string>(LTok.Text));
                AParser.Consume();
              end
              else
                AParser.Consume();

              AParser.Match('delimiter.comma');
            end;
            AParser.Expect('delimiter.rbracket');
          end;

          AParser.Expect('delimiter.semicolon');
          LNode.AddChild(LChild);
        end
        else if LTok.Kind = 'keyword.mode' then
        begin
          LChild := AParser.CreateNode('meta.lexer_mode');
          AParser.Consume();
          LTok := AParser.CurrentToken();
          LChild.SetAttr('name', TValue.From<string>(LTok.Text));
          AParser.Consume();
          AParser.Expect('delimiter.lbrace');
          while not AParser.Check('delimiter.rbrace') do
            LChild.AddChild(AParser.ParseStatement() as TASTNode);
          AParser.Expect('delimiter.rbrace');
          LNode.AddChild(LChild);
        end
        else
          LNode.AddChild(AParser.ParseStatement() as TASTNode);
      end;

      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — GRAMMAR BLOCK
// =========================================================================

procedure RegisterGrammarBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.grammar', 'meta.grammar_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('meta.grammar_block');
      AParser.Consume();
      AParser.Expect('delimiter.lbrace');
      while not AParser.Check('delimiter.rbrace') do
        LNode.AddChild(AParser.ParseStatement() as TASTNode);
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterRuleDecl(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.rule', 'meta.rule_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LTok:      TToken;
      LCategory: string;
      LName:     string;
    begin
      LNode := AParser.CreateNode('meta.rule_decl');
      AParser.Consume(); // consume 'rule'

      // node_kind: either 'name' or 'category.name'
      LTok := AParser.CurrentToken();
      LCategory := LTok.Text;
      AParser.Consume();
      if AParser.Check('delimiter.dot') then
      begin
        AParser.Consume();
        LTok := AParser.CurrentToken();
        LName := LTok.Text;
        AParser.Consume();
        // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
        while AParser.Check('delimiter.dot') do
        begin
          AParser.Consume();
          LName := LName + '.' + AParser.CurrentToken().Text;
          AParser.Consume();
        end;
        LNode.SetAttr('node_kind', TValue.From<string>(LCategory + '.' + LName));
      end
      else
        LNode.SetAttr('node_kind', TValue.From<string>(LCategory));

      // Optional: precedence left|right N
      if AParser.Check('keyword.precedence') then
      begin
        AParser.Consume();
        LTok := AParser.CurrentToken();
        LNode.SetAttr('assoc', TValue.From<string>(LTok.Text));
        AParser.Consume(); // consume 'left' or 'right'
        LTok := AParser.CurrentToken();
        LNode.SetAttr('power', LTok.Value);
        AParser.Consume(); // consume integer
      end;

      // Optional: sync token_kind
      if AParser.Check('keyword.sync') then
      begin
        AParser.Consume();
        LTok := AParser.CurrentToken();
        LNode.SetAttr('sync', TValue.From<string>(LTok.Text));
        AParser.Consume();
      end;

      // Handler body
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');

      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — SEMANTICS BLOCK
// =========================================================================

procedure RegisterSemanticsBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.semantics', 'meta.semantics_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('meta.semantics_block');
      AParser.Consume();
      AParser.Expect('delimiter.lbrace');
      while not AParser.Check('delimiter.rbrace') do
        LNode.AddChild(AParser.ParseStatement() as TASTNode);
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterOnHandler(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.on', 'meta.on_handler',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LTok:      TToken;
      LCategory: string;
      LName:     string;
    begin
      LNode := AParser.CreateNode('meta.on_handler');
      AParser.Consume(); // consume 'on'

      // node_kind: either 'root' or 'category.name'
      LTok := AParser.CurrentToken();
      LCategory := LTok.Text;
      AParser.Consume();
      if AParser.Check('delimiter.dot') then
      begin
        AParser.Consume();
        LTok := AParser.CurrentToken();
        LName := LTok.Text;
        AParser.Consume();
        // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
        while AParser.Check('delimiter.dot') do
        begin
          AParser.Consume();
          LName := LName + '.' + AParser.CurrentToken().Text;
          AParser.Consume();
        end;
        LNode.SetAttr('node_kind', TValue.From<string>(LCategory + '.' + LName));
      end
      else
        LNode.SetAttr('node_kind', TValue.From<string>(LCategory));

      // Handler body
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');

      Result := LNode;
    end);
end;

procedure RegisterPassBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.pass', 'meta.pass_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.pass_block');
      AParser.Consume(); // consume 'pass'

      // Pass number
      LTok := AParser.CurrentToken();
      LNode.SetAttr('pass_number', LTok.Value);
      AParser.Consume();

      // Pass name (string)
      LTok := AParser.CurrentToken();
      LNode.SetAttr('pass_name', LTok.Value);
      AParser.Consume();

      AParser.Expect('delimiter.lbrace');
      while not AParser.Check('delimiter.rbrace') do
        LNode.AddChild(AParser.ParseStatement() as TASTNode);
      AParser.Expect('delimiter.rbrace');

      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — EMIT BLOCK
// =========================================================================

procedure RegisterEmittersBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.emitters', 'meta.emitters_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('meta.emitters_block');
      AParser.Consume();
      AParser.Expect('delimiter.lbrace');
      while not AParser.Check('delimiter.rbrace') do
        LNode.AddChild(AParser.ParseStatement() as TASTNode);
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterSectionDecl(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.section', 'meta.section_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.section_decl');
      AParser.Consume(); // consume 'section'

      LTok := AParser.CurrentToken();
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume();

      // Optional: indent "  "
      if AParser.Check('keyword.indent') then
      begin
        AParser.Consume();
        LTok := AParser.CurrentToken();
        LNode.SetAttr('indent_str', LTok.Value);
        AParser.Consume();
      end;

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterBeforeAfterHooks(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.before', 'meta.before_hook',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.before_hook');
      AParser.Consume(); // consume 'before'

      // Check for "before children {" vs "before {"
      LTok := AParser.CurrentToken();
      if LTok.Kind = 'keyword.children' then
      begin
        LNode.SetAttr('scope', TValue.From<string>('children'));
        AParser.Consume();
      end
      else
        LNode.SetAttr('scope', TValue.From<string>('global'));

      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);

  AMetamorf.Config().RegisterStatement('keyword.after', 'meta.after_hook',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.after_hook');
      AParser.Consume(); // consume 'after'

      LTok := AParser.CurrentToken();
      if LTok.Kind = 'keyword.children' then
      begin
        LNode.SetAttr('scope', TValue.From<string>('children'));
        AParser.Consume();
      end
      else
        LNode.SetAttr('scope', TValue.From<string>('global'));

      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — TYPES BLOCK
// =========================================================================

procedure RegisterTypesBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.types', 'meta.types_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:  TASTNode;
      LChild: TASTNode;
      LTok:   TToken;
    begin
      LNode := AParser.CreateNode('meta.types_block');
      AParser.Consume();
      AParser.Expect('delimiter.lbrace');

      while not AParser.Check('delimiter.rbrace') do
      begin
        if AParser.Check('keyword.compatible') then
        begin
          LChild := AParser.CreateNode('meta.type_compat_rule');
          AParser.Consume(); // consume 'compatible'

          // from_type
          LTok := AParser.CurrentToken();
          LChild.SetAttr('from_type', TValue.From<string>(LTok.Text));
          AParser.Consume();

          AParser.Expect('delimiter.comma');

          // to_type
          LTok := AParser.CurrentToken();
          LChild.SetAttr('to_type', TValue.From<string>(LTok.Text));
          AParser.Consume();

          // Optional: -> coerce_to
          if AParser.Match('op.arrow') then
          begin
            LTok := AParser.CurrentToken();
            LChild.SetAttr('coerce_to', TValue.From<string>(LTok.Text));
            AParser.Consume();
          end;

          AParser.Expect('delimiter.semicolon');
          LNode.AddChild(LChild);
        end
        else if (AParser.CurrentToken().Kind = 'identifier') and
                (AParser.CurrentToken().Text = 'type') then
        begin
          // type int32 = "type.int32";
          LChild := AParser.CreateNode('meta.type_keyword_decl');
          AParser.Consume(); // consume 'type'
          LTok := AParser.CurrentToken();
          LChild.SetAttr('type_text', TValue.From<string>(LTok.Text));
          AParser.Consume();
          AParser.Expect('op.assign');
          LTok := AParser.CurrentToken();
          LChild.SetAttr('type_kind', LTok.Value);
          AParser.Consume();
          AParser.Expect('delimiter.semicolon');
          LNode.AddChild(LChild);
        end
        else if AParser.CurrentToken().Kind = 'keyword.map' then
        begin
          // map "type.int32" -> "int32_t";
          LChild := AParser.CreateNode('meta.type_mapping_decl');
          AParser.Consume(); // consume 'map'
          LTok := AParser.CurrentToken();
          LChild.SetAttr('source', LTok.Value);
          AParser.Consume();
          AParser.Expect('op.arrow');
          LTok := AParser.CurrentToken();
          LChild.SetAttr('target', LTok.Value);
          AParser.Consume();
          AParser.Expect('delimiter.semicolon');
          LNode.AddChild(LChild);
        end
        else if (AParser.CurrentToken().Kind = 'identifier') and
                (AParser.CurrentToken().Text = 'literal') then
        begin
          // literal "expr.integer" = "type.int32";
          LChild := AParser.CreateNode('meta.literal_type_decl');
          AParser.Consume(); // consume 'literal'
          LTok := AParser.CurrentToken();
          LChild.SetAttr('node_kind', LTok.Value);
          AParser.Consume();
          AParser.Expect('op.assign');
          LTok := AParser.CurrentToken();
          LChild.SetAttr('type_kind', LTok.Value);
          AParser.Consume();
          AParser.Expect('delimiter.semicolon');
          LNode.AddChild(LChild);
        end
        else if (AParser.CurrentToken().Kind = 'identifier') and
                (AParser.CurrentToken().Text = 'decl_kind') then
        begin
          // decl_kind "stmt.var_decl";
          LChild := AParser.CreateNode('meta.decl_kind_decl');
          AParser.Consume(); // consume 'decl_kind'
          LTok := AParser.CurrentToken();
          LChild.SetAttr('node_kind', LTok.Value);
          AParser.Consume();
          AParser.Expect('delimiter.semicolon');
          LNode.AddChild(LChild);
        end
        else if (AParser.CurrentToken().Kind = 'identifier') and
                (AParser.CurrentToken().Text = 'call_kind') then
        begin
          // call_kind "expr.call";
          LChild := AParser.CreateNode('meta.call_kind_decl');
          AParser.Consume(); // consume 'call_kind'
          LTok := AParser.CurrentToken();
          LChild.SetAttr('node_kind', LTok.Value);
          AParser.Consume();
          AParser.Expect('delimiter.semicolon');
          LNode.AddChild(LChild);
        end
        else
          LNode.AddChild(AParser.ParseStatement() as TASTNode);
      end;

      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — CONST BLOCK AND ENUM
// =========================================================================

procedure RegisterConstBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.const', 'meta.const_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:  TASTNode;
      LChild: TASTNode;
      LTok:   TToken;
    begin
      LNode := AParser.CreateNode('meta.const_block');
      AParser.Consume();
      AParser.Expect('delimiter.lbrace');

      while not AParser.Check('delimiter.rbrace') do
      begin
        LChild := AParser.CreateNode('meta.const_decl');
        LTok := AParser.CurrentToken();
        LChild.SetAttr('name', TValue.From<string>(LTok.Text));
        AParser.Consume();
        AParser.Expect('op.assign');
        LChild.AddChild(AParser.ParseExpression(0) as TASTNode);
        AParser.Expect('delimiter.semicolon');
        LNode.AddChild(LChild);
      end;

      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterEnumDecl(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.enum', 'meta.enum_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.enum_decl');
      AParser.Consume(); // consume 'enum'

      LTok := AParser.CurrentToken();
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume();

      AParser.Expect('delimiter.lbrace');

      // Parse comma-separated member names
      LTok := AParser.CurrentToken();
      LNode.SetAttr('member_0', TValue.From<string>(LTok.Text));
      AParser.Consume();

      while AParser.Match('delimiter.comma') do
      begin
        LTok := AParser.CurrentToken();
        // Store members as indexed attrs
        LNode.SetAttr('member_' + IntToStr(LNode.ChildCount()), TValue.From<string>(LTok.Text));
        AParser.Consume();
      end;

      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — ROUTINE DECLARATION
// =========================================================================

procedure RegisterRoutineDecl(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.routine', 'meta.routine_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LParamNode: TASTNode;
      LTok:       TToken;
    begin
      LNode := AParser.CreateNode('meta.routine_decl');
      AParser.Consume(); // consume 'routine'

      // Name
      LTok := AParser.CurrentToken();
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume();

      // Parameters
      AParser.Expect('delimiter.lparen');
      if not AParser.Check('delimiter.rparen') then
      begin
        repeat
          LParamNode := AParser.CreateNode('meta.param_decl');
          LTok := AParser.CurrentToken();
          LParamNode.SetAttr('name', TValue.From<string>(LTok.Text));
          AParser.Consume();
          AParser.Expect('delimiter.colon');
          LTok := AParser.CurrentToken();
          LParamNode.SetAttr('type_name', TValue.From<string>(LTok.Text));
          AParser.Consume();
          LNode.AddChild(LParamNode);
        until not AParser.Match('delimiter.comma');
      end;
      AParser.Expect('delimiter.rparen');

      // Optional return type: -> type
      if AParser.Match('op.arrow') then
      begin
        LTok := AParser.CurrentToken();
        LNode.SetAttr('return_type', TValue.From<string>(LTok.Text));
        AParser.Consume();
      end;

      // Body
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');

      Result := LNode;
    end);
end;

// =========================================================================
// TOP-LEVEL — FRAGMENT DECLARATION
// =========================================================================

procedure RegisterFragmentDecl(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.fragment', 'meta.fragment_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
      LTok:  TToken;
    begin
      LNode := AParser.CreateNode('meta.fragment_decl');
      AParser.Consume(); // consume 'fragment'

      LTok := AParser.CurrentToken();
      LNode.SetAttr('name', TValue.From<string>(LTok.Text));
      AParser.Consume();

      AParser.Expect('delimiter.lbrace');
      while not AParser.Check('delimiter.rbrace') do
        LNode.AddChild(AParser.ParseStatement() as TASTNode);
      AParser.Expect('delimiter.rbrace');

      Result := LNode;
    end);
end;

// =========================================================================
// GRAMMAR BLOCK — PARSE RULE BODY STATEMENTS
// =========================================================================

procedure RegisterExpectStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.expect', 'stmt.expect',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LTok:      TToken;
      LCategory: string;
      LName:     string;
    begin
      LNode := AParser.CreateNode('stmt.expect');
      AParser.Consume(); // consume 'expect'

      // token_kind: category.name or [list]
      LTok := AParser.CurrentToken();
      if LTok.Kind = 'delimiter.lbracket' then
      begin
        // [token.kind, token.kind, ...]
        AParser.Consume();
        while not AParser.Check('delimiter.rbracket') do
        begin
          LTok := AParser.CurrentToken();
          LCategory := LTok.Text;
          AParser.Consume();
          AParser.Expect('delimiter.dot');
          LTok := AParser.CurrentToken();
          LName := LTok.Text;
          AParser.Consume();
          // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
          while AParser.Check('delimiter.dot') do
          begin
            AParser.Consume();
            LName := LName + '.' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
          LNode.AddChild(
            TASTNode.CreateNode('meta.token_ref',
              AParser.CurrentToken()));
          (LNode.GetChild(LNode.ChildCount() - 1) as TASTNode).SetAttr(
            'kind', TValue.From<string>(LCategory + '.' + LName));
          AParser.Match('delimiter.comma');
        end;
        AParser.Expect('delimiter.rbracket');
      end
      else
      begin
        LCategory := LTok.Text;
        AParser.Consume();
        if AParser.Check('delimiter.dot') then
        begin
          AParser.Consume();
          LTok := AParser.CurrentToken();
          LName := LTok.Text;
          AParser.Consume();
          // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
          while AParser.Check('delimiter.dot') do
          begin
            AParser.Consume();
            LName := LName + '.' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
          LNode.SetAttr('token_kind', TValue.From<string>(LCategory + '.' + LName));
        end
        else
          LNode.SetAttr('token_kind', TValue.From<string>(LCategory));
      end;

      // Optional: -> @attr
      if AParser.Match('op.arrow') then
      begin
        AParser.Expect('delimiter.at');
        LTok := AParser.CurrentToken();
        LNode.SetAttr('capture_attr', TValue.From<string>(LTok.Text));
        AParser.Consume();
      end;

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterConsumeStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.consume', 'stmt.consume',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LTok:      TToken;
      LCategory: string;
      LName:     string;
    begin
      LNode := AParser.CreateNode('stmt.consume');
      AParser.Consume(); // consume 'consume'

      LTok := AParser.CurrentToken();
      if LTok.Kind = 'delimiter.lbracket' then
      begin
        AParser.Consume();
        while not AParser.Check('delimiter.rbracket') do
        begin
          LTok := AParser.CurrentToken();
          LCategory := LTok.Text;
          AParser.Consume();
          AParser.Expect('delimiter.dot');
          LTok := AParser.CurrentToken();
          LName := LTok.Text;
          AParser.Consume();
          // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
          while AParser.Check('delimiter.dot') do
          begin
            AParser.Consume();
            LName := LName + '.' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
          LNode.AddChild(
            TASTNode.CreateNode('meta.token_ref',
              AParser.CurrentToken()));
          (LNode.GetChild(LNode.ChildCount() - 1) as TASTNode).SetAttr(
            'kind', TValue.From<string>(LCategory + '.' + LName));
          AParser.Match('delimiter.comma');
        end;
        AParser.Expect('delimiter.rbracket');
      end
      else
      begin
        LCategory := LTok.Text;
        AParser.Consume();
        if AParser.Check('delimiter.dot') then
        begin
          AParser.Consume();
          LTok := AParser.CurrentToken();
          LName := LTok.Text;
          AParser.Consume();
          // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
          while AParser.Check('delimiter.dot') do
          begin
            AParser.Consume();
            LName := LName + '.' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
          LNode.SetAttr('token_kind', TValue.From<string>(LCategory + '.' + LName));
        end
        else
          LNode.SetAttr('token_kind', TValue.From<string>(LCategory));
      end;

      if AParser.Match('op.arrow') then
      begin
        AParser.Expect('delimiter.at');
        LTok := AParser.CurrentToken();
        LNode.SetAttr('capture_attr', TValue.From<string>(LTok.Text));
        AParser.Consume();
      end;

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterParseStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.parse', 'stmt.parse_sub',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:       TASTNode;
      LTok:        TToken;
      LIsMany:     Boolean;
      LCategory:   string;
      LName:       string;
      LUntilKinds: string;
    begin
      LNode := AParser.CreateNode('stmt.parse_sub');
      AParser.Consume(); // consume 'parse'

      // Optional: many
      LIsMany := AParser.Match('keyword.many');
      LNode.SetAttr('is_many', TValue.From<Boolean>(LIsMany));

      // node_kind: category.name or just "expr" / "stmt"
      LTok := AParser.CurrentToken();
      LCategory := LTok.Text;
      AParser.Consume();

      if AParser.Check('delimiter.dot') then
      begin
        AParser.Consume();
        LTok := AParser.CurrentToken();
        LName := LTok.Text;
        AParser.Consume();
        // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
        while AParser.Check('delimiter.dot') do
        begin
          AParser.Consume();
          LName := LName + '.' + AParser.CurrentToken().Text;
          AParser.Consume();
        end;
        LNode.SetAttr('node_kind', TValue.From<string>(LCategory + '.' + LName));
      end
      else
        LNode.SetAttr('node_kind', TValue.From<string>(LCategory));

      // Optional: until token_kind or [token_kind, token_kind, ...]
      if AParser.Check('keyword.until') then
      begin
        AParser.Consume(); // consume 'until'
        LUntilKinds := '';
        LTok := AParser.CurrentToken();
        if LTok.Kind = 'delimiter.lbracket' then
        begin
          // [kind1, kind2, ...]
          AParser.Consume(); // consume '['
          while not AParser.Check('delimiter.rbracket') do
          begin
            LTok := AParser.CurrentToken();
            LCategory := LTok.Text;
            AParser.Consume();
            AParser.Expect('delimiter.dot');
            LTok := AParser.CurrentToken();
            LName := LTok.Text;
            AParser.Consume();
            // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
            while AParser.Check('delimiter.dot') do
            begin
              AParser.Consume();
              LName := LName + '.' + AParser.CurrentToken().Text;
              AParser.Consume();
            end;
          // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
          while AParser.Check('delimiter.dot') do
          begin
            AParser.Consume();
            LName := LName + '.' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
            if LUntilKinds <> '' then
              LUntilKinds := LUntilKinds + ',';
            LUntilKinds := LUntilKinds + LCategory + '.' + LName;
            AParser.Match('delimiter.comma');
          end;
          AParser.Expect('delimiter.rbracket');
        end
        else
        begin
          // Single: category.name
          LCategory := LTok.Text;
          AParser.Consume();
          AParser.Expect('delimiter.dot');
          LTok := AParser.CurrentToken();
          LName := LTok.Text;
          AParser.Consume();
          // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
          while AParser.Check('delimiter.dot') do
          begin
            AParser.Consume();
            LName := LName + '.' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
          LUntilKinds := LCategory + '.' + LName;
        end;
        LNode.SetAttr('until_kinds', TValue.From<string>(LUntilKinds));
      end;

      // -> @attr
      AParser.Expect('op.arrow');
      AParser.Expect('delimiter.at');
      LTok := AParser.CurrentToken();
      LNode.SetAttr('capture_attr', TValue.From<string>(LTok.Text));
      AParser.Consume();

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

procedure RegisterOptionalBlock(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.optional', 'stmt.optional',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('stmt.optional');
      AParser.Consume(); // consume 'optional'
      AParser.Expect('delimiter.lbrace');
      LNode.AddChild(ParseBlock(AParser));
      AParser.Expect('delimiter.rbrace');
      Result := LNode;
    end);
end;

procedure RegisterSyncStatement(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('keyword.sync', 'stmt.sync',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LTok:      TToken;
      LCategory: string;
      LName:     string;
    begin
      LNode := AParser.CreateNode('stmt.sync');
      AParser.Consume(); // consume 'sync'

      LTok := AParser.CurrentToken();
      LCategory := LTok.Text;
      AParser.Consume();
      AParser.Expect('delimiter.dot');
      LTok := AParser.CurrentToken();
      LName := LTok.Text;
      AParser.Consume();
      // Support multi-segment kinds (e.g. cpp.delimiter.lbrace)
      while AParser.Check('delimiter.dot') do
      begin
        AParser.Consume();
        LName := LName + '.' + AParser.CurrentToken().Text;
        AParser.Consume();
      end;
      LNode.SetAttr('sync_kind', TValue.From<string>(LCategory + '.' + LName));

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

// =========================================================================
// PUBLIC ENTRY POINT
// =========================================================================

procedure ConfigGrammar(const AMetamorf: TMetamorf);
begin
  // Expression prefixes
  RegisterLiteralPrefixes(AMetamorf);
  RegisterBooleanLiterals(AMetamorf);
  RegisterNilLiteral(AMetamorf);
  RegisterAttrAccess(AMetamorf);
  RegisterIdentPrefix(AMetamorf);
  RegisterGroupedExpr(AMetamorf);
  RegisterUnaryNot(AMetamorf);
  RegisterUnaryMinus(AMetamorf);

  // Expression infixes
  RegisterBinaryOps(AMetamorf);
  RegisterFieldAccess(AMetamorf);
  RegisterCallExpr(AMetamorf);
  RegisterArrayIndex(AMetamorf);

  // Handler body — control flow
  RegisterLetStatement(AMetamorf);
  RegisterIfStatement(AMetamorf);
  RegisterWhileStatement(AMetamorf);
  RegisterForInStatement(AMetamorf);
  RegisterMatchStatement(AMetamorf);
  RegisterGuardStatement(AMetamorf);
  RegisterReturnStatement(AMetamorf);
  RegisterTryRecoverStatement(AMetamorf);
  RegisterIdentifierStatement(AMetamorf);

  // Handler body — domain-specific
  RegisterVisitStatement(AMetamorf);
  RegisterEmitStatement(AMetamorf);
  RegisterDeclareStatement(AMetamorf);
  RegisterLookupStatement(AMetamorf);
  RegisterScopeStatement(AMetamorf);
  RegisterSetAttrStatement(AMetamorf);
  RegisterIndentStatement(AMetamorf);
  RegisterDiagnosticStatements(AMetamorf);

  // Grammar rule body — parse operations
  RegisterExpectStatement(AMetamorf);
  RegisterConsumeStatement(AMetamorf);
  RegisterParseStatement(AMetamorf);
  RegisterOptionalBlock(AMetamorf);
  RegisterSyncStatement(AMetamorf);

  // Top-level constructs
  RegisterLanguageDecl(AMetamorf);
  RegisterImportStatement(AMetamorf);
  RegisterIncludeStatement(AMetamorf);
  RegisterTokensBlock(AMetamorf);
  RegisterGrammarBlock(AMetamorf);
  RegisterRuleDecl(AMetamorf);
  RegisterSemanticsBlock(AMetamorf);
  RegisterOnHandler(AMetamorf);
  RegisterPassBlock(AMetamorf);
  RegisterEmittersBlock(AMetamorf);
  RegisterSectionDecl(AMetamorf);
  RegisterBeforeAfterHooks(AMetamorf);
  RegisterTypesBlock(AMetamorf);
  RegisterConstBlock(AMetamorf);
  RegisterEnumDecl(AMetamorf);
  RegisterRoutineDecl(AMetamorf);
  RegisterFragmentDecl(AMetamorf);
end;

end.
