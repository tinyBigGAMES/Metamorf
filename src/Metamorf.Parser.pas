{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Parser;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.AST;

const
  // .mor Parser Error Codes (MP001-MP099)
  ERR_MORPARSER_EXPECTED_TOKEN   = 'MP001';
  ERR_MORPARSER_UNEXPECTED_TOP   = 'MP002';
  ERR_MORPARSER_EXPECTED_IDENT   = 'MP003';
  ERR_MORPARSER_EXPECTED_LBRACE  = 'MP004';
  ERR_MORPARSER_EXPECTED_RBRACE  = 'MP005';
  ERR_MORPARSER_EXPECTED_SEMI    = 'MP006';
  ERR_MORPARSER_UNEXPECTED_EXPR  = 'MP007';

type

  { TInfixInfo }
  TInfixInfo = record
    Power: Integer;
    RightAssoc: Boolean;
    IsValid: Boolean;
  end;

  { TMorParser }
  TMorParser = class(TErrorsObject)
  private
    FTokens: TList<TToken>;
    FPos: Integer;
    FFilename: string;

    // Token navigation
    function Current(): TToken;
    {$HINTS OFF}
    function Peek(): TToken;
    {$HINTS ON}
    function AtEnd(): Boolean;
    function Check(const AKind: string): Boolean;
    {$HINTS OFF}
    function CheckKeyword(const AText: string): Boolean;
    {$HINTS ON}
    function Match(const AKind: string): Boolean;
    procedure DoAdvance();
    procedure Expect(const AKind: string);
    procedure ExpectSemicolon();

    // Consumption helpers
    function ConsumeIdentifier(): string;
    function ConsumeDottedIdent(): string;
    function ConsumeString(): string;
    function ConsumeInteger(): string;

    // Node creation
    function CreateNode(const AKind: string): TASTNode;

    // Infix power lookup
    function GetInfixInfo(const AKind: string): TInfixInfo;

    // Expression parsing (Pratt)
    function ParseExpr(const AMinPower: Integer): TASTNode;
    function ParsePrefix(): TASTNode;
    function ParseCallArgs(const ACallee: TASTNode): TASTNode;

    // Block helper
    function ParseBlock(): TASTNode;

    // Statement parsing
    function ParseStmt(): TASTNode;
    function ParseLanguageDecl(): TASTNode;
    function ParseTokensBlock(): TASTNode;
    function ParseTokenDecl(): TASTNode;
    function ParseTokenFlags(const ANode: TASTNode): TASTNode;
    function ParseConfigEntry(): TASTNode;
    function ParseTypesBlock(): TASTNode;
    function ParseGrammarBlock(): TASTNode;
    function ParseRule(): TASTNode;
    function ParseSemanticsBlock(): TASTNode;
    function ParsePassDecl(): TASTNode;
    function ParseOnHandler(): TASTNode;
    function ParseEmittersBlock(): TASTNode;
    function ParseRoutineDecl(): TASTNode;
    function ParseConstBlock(): TASTNode;
    function ParseEnumDecl(): TASTNode;
    function ParseFragmentDecl(): TASTNode;
    function ParseImport(): TASTNode;
    function ParseInclude(): TASTNode;
    function ParseLet(): TASTNode;
    function ParseSet(): TASTNode;
    function ParseIf(): TASTNode;
    function ParseWhile(): TASTNode;
    function ParseFor(): TASTNode;
    function ParseMatch(): TASTNode;
    function ParseGuard(): TASTNode;
    function ParseReturn(): TASTNode;
    function ParseTryRecover(): TASTNode;
    function ParseExpectStmt(): TASTNode;
    function ParseConsumeStmt(): TASTNode;
    function ParseParseDirective(): TASTNode;
    function ParseOptional(): TASTNode;
    function ParseSync(): TASTNode;
    function ParseScope(): TASTNode;
    function ParseDeclare(): TASTNode;
    function ParseVisit(): TASTNode;
    function ParseLookup(): TASTNode;
    function ParseEmit(): TASTNode;
    function ParseSection(): TASTNode;
    function ParseIndentBlock(): TASTNode;
    function ParseBefore(): TASTNode;
    function ParseAfter(): TASTNode;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Parse(const ATokens: TList<TToken>;
      const AFilename: string = ''): TASTNode;
    function ParseSingleExpr(const ATokens: TList<TToken>): TASTNode;
  end;

implementation

{ TMorParser }

constructor TMorParser.Create();
begin
  inherited;
  FTokens := nil;
  FPos := 0;
  FFilename := '';
end;

destructor TMorParser.Destroy();
begin
  inherited;
end;

function TMorParser.Current(): TToken;
begin
  if (FPos >= 0) and (FPos < FTokens.Count) then
    Result := FTokens[FPos]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TMorParser.Peek(): TToken;
begin
  if (FPos + 1 >= 0) and (FPos + 1 < FTokens.Count) then
    Result := FTokens[FPos + 1]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TMorParser.AtEnd(): Boolean;
begin
  Result := Current().Kind = 'eof';
end;

function TMorParser.Check(const AKind: string): Boolean;
begin
  Result := Current().Kind = AKind;
end;

function TMorParser.CheckKeyword(const AText: string): Boolean;
begin
  Result := Current().Text = AText;
end;

function TMorParser.Match(const AKind: string): Boolean;
begin
  if Current().Kind = AKind then
  begin
    DoAdvance();
    Result := True;
  end
  else
    Result := False;
end;

procedure TMorParser.DoAdvance();
begin
  if FPos < FTokens.Count then
    Inc(FPos);
end;

procedure TMorParser.Expect(const AKind: string);
begin
  if Current().Kind = AKind then
    DoAdvance()
  else if Assigned(FErrors) then
    FErrors.Add(FFilename, Current().Line, Current().Col,
      esError, ERR_MORPARSER_EXPECTED_TOKEN,
      RSMorParserExpectedToken, [AKind, Current().Text]);
end;

procedure TMorParser.ExpectSemicolon();
begin
  Expect('delimiter.semicolon');
end;

function TMorParser.ConsumeIdentifier(): string;
begin
  if (Current().Kind = 'identifier') or Current().Kind.StartsWith('kw.') then
  begin
    Result := Current().Text;
    DoAdvance();
  end
  else
  begin
    Result := '';
    if Assigned(FErrors) then
      FErrors.Add(FFilename, Current().Line, Current().Col,
        esError, ERR_MORPARSER_EXPECTED_IDENT,
        RSMorParserExpectedIdentifier, [Current().Text]);
  end;
end;

function TMorParser.ConsumeDottedIdent(): string;
begin
  // Consume identifiers and keywords joined by dots: e.g. "keyword.if", "op.plus"
  // Accept identifiers or any keyword token for the parts
  if (Current().Kind = 'identifier') or Current().Kind.StartsWith('kw.') then
  begin
    Result := Current().Text;
    DoAdvance();
  end
  else
  begin
    Result := '';
    if Assigned(FErrors) then
      FErrors.Add(FFilename, Current().Line, Current().Col,
        esError, ERR_MORPARSER_EXPECTED_IDENT,
        RSMorParserExpectedIdentifier, [Current().Text]);
    Exit;
  end;

  // Continue consuming .part segments
  while Check('delimiter.dot') do
  begin
    DoAdvance(); // skip dot
    if (Current().Kind = 'identifier') or Current().Kind.StartsWith('kw.') then
    begin
      Result := Result + '.' + Current().Text;
      DoAdvance();
    end
    else
      Break;
  end;
end;

function TMorParser.ConsumeString(): string;
begin
  if Current().Kind = 'literal.string' then
  begin
    Result := Current().Text;
    DoAdvance();
  end
  else
  begin
    Result := '';
    if Assigned(FErrors) then
      FErrors.Add(FFilename, Current().Line, Current().Col,
        esError, ERR_MORPARSER_EXPECTED_TOKEN,
        RSMorParserExpectedToken, ['string literal', Current().Text]);
  end;
end;

function TMorParser.ConsumeInteger(): string;
begin
  if Current().Kind = 'literal.integer' then
  begin
    Result := Current().Text;
    DoAdvance();
  end
  else
  begin
    Result := '';
    if Assigned(FErrors) then
      FErrors.Add(FFilename, Current().Line, Current().Col,
        esError, ERR_MORPARSER_EXPECTED_TOKEN,
        RSMorParserExpectedToken, ['integer literal', Current().Text]);
  end;
end;

function TMorParser.CreateNode(const AKind: string): TASTNode;
begin
  Result := TASTNode.Create();
  Result.SetKind(AKind);
  Result.SetToken(Current());
end;

function TMorParser.GetInfixInfo(const AKind: string): TInfixInfo;
begin
  Result.IsValid := True;
  Result.RightAssoc := False;

  if AKind = 'op.plus' then Result.Power := 30
  else if AKind = 'op.minus' then Result.Power := 30
  else if AKind = 'op.star' then Result.Power := 40
  else if AKind = 'op.slash' then Result.Power := 40
  else if AKind = 'op.percent' then Result.Power := 40
  else if AKind = 'op.eq' then Result.Power := 20
  else if AKind = 'op.ne' then Result.Power := 20
  else if AKind = 'op.lt' then Result.Power := 20
  else if AKind = 'op.gt' then Result.Power := 20
  else if AKind = 'op.le' then Result.Power := 20
  else if AKind = 'op.ge' then Result.Power := 20
  else if AKind = 'kw.and' then Result.Power := 10
  else if AKind = 'kw.or' then Result.Power := 5
  else if AKind = 'delimiter.lparen' then Result.Power := 80
  else if AKind = 'delimiter.dot' then Result.Power := 90
  else if AKind = 'delimiter.lbracket' then Result.Power := 85
  else
  begin
    Result.IsValid := False;
    Result.Power := 0;
  end;
end;

function TMorParser.ParseExpr(const AMinPower: Integer): TASTNode;
var
  LLeft: TASTNode;
  LInfo: TInfixInfo;
  LOp: string;
  LToken: TToken;
  LNode: TASTNode;
begin
  // Prefix dispatch
  LLeft := ParsePrefix();

  // Infix loop
  while not AtEnd() do
  begin
    LInfo := GetInfixInfo(Current().Kind);
    if not LInfo.IsValid then
      Break;

    // Power check
    if LInfo.RightAssoc then
    begin
      if LInfo.Power < AMinPower then Break;
    end
    else
    begin
      if LInfo.Power <= AMinPower then Break;
    end;

    // Dispatch infix
    if Check('delimiter.lparen') then
    begin
      // Function call
      LLeft := ParseCallArgs(LLeft);
    end
    else if Check('delimiter.dot') then
    begin
      // Member access: expr.field
      LToken := Current();
      DoAdvance(); // skip dot
      LNode := CreateNode('expr.member');
      LNode.SetToken(LToken);
      LNode.AddChild(LLeft);
      LNode.SetAttr('member', ConsumeIdentifier());
      LLeft := LNode;
    end
    else if Check('delimiter.lbracket') then
    begin
      // Index access: expr[index]
      LToken := Current();
      DoAdvance(); // skip [
      LNode := CreateNode('expr.index');
      LNode.SetToken(LToken);
      LNode.AddChild(LLeft);
      LNode.AddChild(ParseExpr(0));
      Expect('delimiter.rbracket');
      LLeft := LNode;
    end
    else
    begin
      // Binary operator
      LOp := Current().Text;
      LToken := Current();
      DoAdvance(); // skip operator
      LNode := CreateNode('expr.binary');
      LNode.SetToken(LToken);
      LNode.SetAttr('op', LOp);
      LNode.AddChild(LLeft);
      if LInfo.RightAssoc then
        LNode.AddChild(ParseExpr(LInfo.Power))
      else
        LNode.AddChild(ParseExpr(LInfo.Power));
      LLeft := LNode;
    end;
  end;

  Result := LLeft;
end;

function TMorParser.ParsePrefix(): TASTNode;
var
  LNode: TASTNode;
  LToken: TToken;
  LKind: string;
begin
  LKind := Current().Kind;
  LToken := Current();

  // Integer literal
  if LKind = 'literal.integer' then
  begin
    LNode := CreateNode('expr.integer');
    LNode.SetAttr('value', Current().Text);
    DoAdvance();
    Result := LNode;
  end
  // Float literal
  else if LKind = 'literal.float' then
  begin
    LNode := CreateNode('expr.float');
    LNode.SetAttr('value', Current().Text);
    DoAdvance();
    Result := LNode;
  end
  // String literal
  else if LKind = 'literal.string' then
  begin
    LNode := CreateNode('expr.string');
    LNode.SetAttr('value', Current().Text);
    DoAdvance();
    Result := LNode;
  end
  // Triple-quoted string
  else if LKind = 'literal.triplestring' then
  begin
    LNode := CreateNode('expr.triplestring');
    LNode.SetAttr('value', Current().Text);
    DoAdvance();
    Result := LNode;
  end
  // true
  else if LKind = 'kw.true' then
  begin
    LNode := CreateNode('expr.bool');
    LNode.SetAttr('value', 'true');
    DoAdvance();
    Result := LNode;
  end
  // false
  else if LKind = 'kw.false' then
  begin
    LNode := CreateNode('expr.bool');
    LNode.SetAttr('value', 'false');
    DoAdvance();
    Result := LNode;
  end
  // nil
  else if LKind = 'kw.nil' then
  begin
    LNode := CreateNode('expr.nil');
    DoAdvance();
    Result := LNode;
  end
  // Identifier
  else if LKind = 'identifier' then
  begin
    LNode := CreateNode('expr.ident');
    LNode.SetAttr('identifier', Current().Text);
    DoAdvance();
    Result := LNode;
  end
  // @ attribute access
  else if LKind = 'op.at' then
  begin
    DoAdvance(); // skip @
    LNode := CreateNode('expr.attr');
    LNode.SetToken(LToken);
    LNode.SetAttr('attr_name', ConsumeIdentifier());
    Result := LNode;
  end
  // not (unary)
  else if LKind = 'kw.not' then
  begin
    DoAdvance(); // skip 'not'
    LNode := CreateNode('expr.unary_not');
    LNode.SetToken(LToken);
    LNode.AddChild(ParseExpr(50));
    Result := LNode;
  end
  // - (unary negate)
  else if LKind = 'op.minus' then
  begin
    DoAdvance(); // skip '-'
    LNode := CreateNode('expr.negate');
    LNode.SetToken(LToken);
    LNode.AddChild(ParseExpr(50));
    Result := LNode;
  end
  // ( grouped expression
  else if LKind = 'delimiter.lparen' then
  begin
    DoAdvance(); // skip (
    LNode := CreateNode('expr.grouped');
    LNode.SetToken(LToken);
    LNode.AddChild(ParseExpr(0));
    Expect('delimiter.rparen');
    Result := LNode;
  end
  // Context-sensitive keyword: treat as identifier in expression position
  // Handles cases like stmt(), expr(), left, right, etc. used as names
  else if LKind.StartsWith('kw.') then
  begin
    LNode := CreateNode('expr.ident');
    LNode.SetToken(LToken);
    LNode.SetAttr('identifier', LToken.Text);
    DoAdvance();
    Result := LNode;
  end
  else
  begin
    // Unexpected token in expression
    if Assigned(FErrors) then
      FErrors.Add(FFilename, Current().Line, Current().Col,
        esError, ERR_MORPARSER_UNEXPECTED_EXPR,
        RSMorParserUnexpectedExpr, [Current().Text]);
    LNode := CreateNode('expr.error');
    DoAdvance();
    Result := LNode;
  end;
end;

function TMorParser.ParseCallArgs(const ACallee: TASTNode): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('expr.call');
  LNode.AddChild(ACallee);
  DoAdvance(); // skip (
  if not Check('delimiter.rparen') then
  begin
    LNode.AddChild(ParseExpr(0));
    while Match('delimiter.comma') do
      LNode.AddChild(ParseExpr(0));
  end;
  Expect('delimiter.rparen');
  Result := LNode;
end;

function TMorParser.ParseBlock(): TASTNode;
var
  LBlock: TASTNode;
begin
  LBlock := CreateNode('meta.block');
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
    LBlock.AddChild(ParseStmt());
  Expect('delimiter.rbrace');
  Result := LBlock;
end;

function TMorParser.ParseStmt(): TASTNode;
var
  LKind: string;
  LExpr: TASTNode;
  LNode: TASTNode;
begin
  LKind := Current().Kind;

  if LKind = 'kw.language' then Result := ParseLanguageDecl()
  else if LKind = 'kw.tokens' then Result := ParseTokensBlock()
  else if LKind = 'kw.types' then Result := ParseTypesBlock()
  else if LKind = 'kw.grammar' then Result := ParseGrammarBlock()
  else if LKind = 'kw.semantics' then Result := ParseSemanticsBlock()
  else if LKind = 'kw.emitters' then Result := ParseEmittersBlock()
  else if LKind = 'kw.routine' then Result := ParseRoutineDecl()
  else if LKind = 'kw.const' then Result := ParseConstBlock()
  else if LKind = 'kw.enum' then Result := ParseEnumDecl()
  else if LKind = 'kw.fragment' then Result := ParseFragmentDecl()
  else if LKind = 'kw.import' then Result := ParseImport()
  else if LKind = 'kw.include' then Result := ParseInclude()
  else if LKind = 'kw.let' then Result := ParseLet()
  else if LKind = 'kw.set' then Result := ParseSet()
  else if LKind = 'kw.if' then Result := ParseIf()
  else if LKind = 'kw.while' then Result := ParseWhile()
  else if LKind = 'kw.for' then Result := ParseFor()
  else if LKind = 'kw.match' then Result := ParseMatch()
  else if LKind = 'kw.guard' then Result := ParseGuard()
  else if LKind = 'kw.return' then Result := ParseReturn()
  else if LKind = 'kw.try' then Result := ParseTryRecover()
  else if LKind = 'kw.expect' then Result := ParseExpectStmt()
  else if LKind = 'kw.consume' then Result := ParseConsumeStmt()
  else if LKind = 'kw.parse' then Result := ParseParseDirective()
  else if LKind = 'kw.optional' then Result := ParseOptional()
  else if LKind = 'kw.sync' then Result := ParseSync()
  else if LKind = 'kw.scope' then Result := ParseScope()
  else if LKind = 'kw.declare' then Result := ParseDeclare()
  else if LKind = 'kw.visit' then Result := ParseVisit()
  else if LKind = 'kw.lookup' then Result := ParseLookup()
  else if LKind = 'kw.emit' then Result := ParseEmit()
  else if LKind = 'kw.section' then Result := ParseSection()
  else if LKind = 'kw.indent' then Result := ParseIndentBlock()
  else if LKind = 'kw.before' then Result := ParseBefore()
  else if LKind = 'kw.after' then Result := ParseAfter()
  else
  begin
    // Expression statement or assignment
    LExpr := ParseExpr(0);
    if Match('op.assign') then
    begin
      LNode := CreateNode('meta.assign');
      LNode.AddChild(LExpr);
      LNode.AddChild(ParseExpr(0));
      ExpectSemicolon();
      Result := LNode;
    end
    else
    begin
      LNode := CreateNode('meta.expr_stmt');
      LNode.AddChild(LExpr);
      ExpectSemicolon();
      Result := LNode;
    end;
  end;
end;

function TMorParser.ParseLanguageDecl(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.language_decl');
  DoAdvance(); // skip 'language'
  LNode.SetAttr('identifier', ConsumeIdentifier());
  Expect('kw.version');
  LNode.SetAttr('version', ConsumeString());
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseTokensBlock(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.tokens_block');
  DoAdvance(); // skip 'tokens'
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    if Check('kw.token') then
      LNode.AddChild(ParseTokenDecl())
    else if Check('kw.include') then
      LNode.AddChild(ParseInclude())
    else
      LNode.AddChild(ParseConfigEntry());
  end;
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseTokenDecl(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.token_decl');
  DoAdvance(); // skip 'token'
  LNode.SetAttr('kind', ConsumeDottedIdent());
  Expect('op.assign');
  LNode.SetAttr('text', ConsumeString());
  if Check('delimiter.lbracket') then
    ParseTokenFlags(LNode);
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseTokenFlags(const ANode: TASTNode): TASTNode;
var
  LFlags: string;
begin
  Result := ANode;
  DoAdvance(); // skip [
  LFlags := '';
  while not AtEnd() and not Check('delimiter.rbracket') do
  begin
    if LFlags <> '' then
      LFlags := LFlags + ',';
    // Flags can be identifiers, keywords, or strings
    if Check('literal.string') then
    begin
      LFlags := LFlags + Current().Text;
      DoAdvance();
    end
    else
    begin
      LFlags := LFlags + Current().Text;
      DoAdvance();
    end;
    // Skip commas between flags
    Match('delimiter.comma');
  end;
  Expect('delimiter.rbracket');
  ANode.SetAttr('flags', LFlags);
end;

function TMorParser.ParseConfigEntry(): TASTNode;
var
  LNode: TASTNode;
  LKey: string;
begin
  LNode := CreateNode('meta.config_entry');
  // Config entries are: key = value;
  // Key can be identifier or keyword used as identifier
  LKey := Current().Text;
  DoAdvance();
  LNode.SetAttr('key', LKey);
  // Accept = or -> as separator
  if Check('op.arrow') then
    DoAdvance()
  else
    Expect('op.assign');
  // Value can be identifier, dotted ident, string, bool, or integer
  if Check('literal.string') then
  begin
    LNode.SetAttr('value', Current().Text);
    DoAdvance();
  end
  else if Check('kw.true') or Check('kw.false') then
  begin
    LNode.SetAttr('value', Current().Text);
    DoAdvance();
  end
  else if Check('literal.integer') then
  begin
    LNode.SetAttr('value', Current().Text);
    DoAdvance();
  end
  else
  begin
    // Dotted identifier value (e.g., delimiter.semicolon)
    LNode.SetAttr('value', ConsumeDottedIdent());
  end;
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseTypesBlock(): TASTNode;
var
  LNode: TASTNode;
  LChild: TASTNode;
begin
  LNode := CreateNode('meta.types_block');
  DoAdvance(); // skip 'types'
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    // Types block contains: map, literal, compatible, decl_kind, call_kind,
    // call_name_attr, name_mangler, token, type keywords and config entries
    if Check('kw.map') then
    begin
      DoAdvance();
      LNode.AddChild(ParseConfigEntry()); // reuse: key = value;
      LNode.GetChild(LNode.ChildCount() - 1).SetKind('meta.type_map');
    end
    else if Check('kw.literal') then
    begin
      DoAdvance();
      LNode.AddChild(ParseConfigEntry());
      LNode.GetChild(LNode.ChildCount() - 1).SetKind('meta.literal_type');
    end
    else if Check('kw.compatible') then
    begin
      // compatible string "," string [ "->" string ] ";"
      DoAdvance();
      LChild := CreateNode('meta.compatible');
      LChild.SetAttr('key', Current().Text);
      DoAdvance();
      Expect('delimiter.comma');
      LChild.SetAttr('value', Current().Text);
      DoAdvance();
      if Check('op.arrow') then
      begin
        DoAdvance();
        LChild.SetAttr('coerce', Current().Text);
        DoAdvance();
      end;
      Expect('delimiter.semicolon');
      LNode.AddChild(LChild);
    end
    else if Check('kw.decl_kind') then
    begin
      // decl_kind string ";"
      DoAdvance();
      LChild := CreateNode('meta.decl_kind');
      LChild.SetAttr('value', Current().Text);
      DoAdvance();
      Expect('delimiter.semicolon');
      LNode.AddChild(LChild);
    end
    else if Check('kw.call_kind') then
    begin
      // call_kind string ";"
      DoAdvance();
      LChild := CreateNode('meta.call_kind');
      LChild.SetAttr('value', Current().Text);
      DoAdvance();
      Expect('delimiter.semicolon');
      LNode.AddChild(LChild);
    end
    else if Check('kw.call_name_attr') then
    begin
      // call_name_attr "=" string ";"
      DoAdvance();
      LChild := CreateNode('meta.call_name_attr');
      Expect('op.assign');
      LChild.SetAttr('value', Current().Text);
      DoAdvance();
      Expect('delimiter.semicolon');
      LNode.AddChild(LChild);
    end
    else if Check('kw.name_mangler') then
    begin
      // name_mangler "=" ident ";"
      DoAdvance();
      LChild := CreateNode('meta.name_mangler');
      Expect('op.assign');
      LChild.SetAttr('value', Current().Text);
      DoAdvance();
      Expect('delimiter.semicolon');
      LNode.AddChild(LChild);
    end
    else if Check('kw.type') then
    begin
      DoAdvance();
      LNode.AddChild(ParseConfigEntry());
      // Stays as meta.config_entry — WalkTypesBlock stores in FTypeKeywords
    end
    else if Check('kw.include') then
      LNode.AddChild(ParseInclude())
    else
      LNode.AddChild(ParseConfigEntry());
  end;
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseGrammarBlock(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.grammar_block');
  DoAdvance(); // skip 'grammar'
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    if Check('kw.include') then
      LNode.AddChild(ParseInclude())
    else
      LNode.AddChild(ParseRule());
  end;
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseRule(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.rule');
  Expect('kw.rule');
  LNode.SetAttr('node_kind', ConsumeDottedIdent());

  // Optional: precedence left/right power
  if Check('kw.precedence') then
  begin
    DoAdvance(); // skip 'precedence'
    if Check('kw.left') then
    begin
      LNode.SetAttr('assoc', 'left');
      DoAdvance();
    end
    else if Check('kw.right') then
    begin
      LNode.SetAttr('assoc', 'right');
      DoAdvance();
    end;
    LNode.SetAttr('power', ConsumeInteger());
  end;

  // Rule body
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
    LNode.AddChild(ParseStmt());
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseSemanticsBlock(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.semantics_block');
  DoAdvance(); // skip 'semantics'
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    if Check('kw.pass') then
      LNode.AddChild(ParsePassDecl())
    else if Check('kw.on') then
      LNode.AddChild(ParseOnHandler())
    else if Check('kw.include') then
      LNode.AddChild(ParseInclude())
    else
      LNode.AddChild(ParseStmt());
  end;
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParsePassDecl(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.pass');
  DoAdvance(); // skip 'pass'
  LNode.SetAttr('pass_number', ConsumeInteger());
  if Check('literal.string') then
    LNode.SetAttr('pass_name', ConsumeString());
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    if Check('kw.on') then
      LNode.AddChild(ParseOnHandler())
    else
      LNode.AddChild(ParseStmt());
  end;
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseOnHandler(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.on_handler');
  DoAdvance(); // skip 'on'
  LNode.SetAttr('node_kind', ConsumeDottedIdent());
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
    LNode.AddChild(ParseStmt());
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseEmittersBlock(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.emitters_block');
  DoAdvance(); // skip 'emitters'
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    if Check('kw.on') then
      LNode.AddChild(ParseOnHandler())
    else if Check('kw.section') then
      LNode.AddChild(ParseSection())
    else if Check('kw.before') then
      LNode.AddChild(ParseBefore())
    else if Check('kw.after') then
      LNode.AddChild(ParseAfter())
    else if Check('kw.include') then
      LNode.AddChild(ParseInclude())
    else
      LNode.AddChild(ParseStmt());
  end;
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseRoutineDecl(): TASTNode;
var
  LNode: TASTNode;
  LPName: string;
  LPType: string;
  LParamIdx: Integer;
begin
  LNode := CreateNode('meta.routine');
  DoAdvance(); // skip 'routine'
  LNode.SetAttr('identifier', ConsumeIdentifier());
  Expect('delimiter.lparen');

  // Parse parameters
  LParamIdx := 0;
  if not Check('delimiter.rparen') then
  begin
    LPName := ConsumeIdentifier();
    Expect('delimiter.colon');
    LPType := ConsumeIdentifier();
    LNode.SetAttr('param_' + IntToStr(LParamIdx) + '_name', LPName);
    LNode.SetAttr('param_' + IntToStr(LParamIdx) + '_type', LPType);
    Inc(LParamIdx);

    while Match('delimiter.comma') do
    begin
      LPName := ConsumeIdentifier();
      Expect('delimiter.colon');
      LPType := ConsumeIdentifier();
      LNode.SetAttr('param_' + IntToStr(LParamIdx) + '_name', LPName);
      LNode.SetAttr('param_' + IntToStr(LParamIdx) + '_type', LPType);
      Inc(LParamIdx);
    end;
  end;
  LNode.SetAttr('param_count', IntToStr(LParamIdx));
  Expect('delimiter.rparen');

  // Optional return type
  if Match('op.arrow') then
    LNode.SetAttr('return_type', ConsumeIdentifier());

  // Body
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseConstBlock(): TASTNode;
var
  LNode: TASTNode;
  LEntry: TASTNode;
begin
  LNode := CreateNode('meta.const_block');
  DoAdvance(); // skip 'const'
  Expect('delimiter.lbrace');
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    LEntry := CreateNode('meta.const_decl');
    LEntry.SetAttr('identifier', ConsumeIdentifier());
    Expect('op.assign');
    LEntry.AddChild(ParseExpr(0));
    ExpectSemicolon();
    LNode.AddChild(LEntry);
  end;
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseEnumDecl(): TASTNode;
var
  LNode: TASTNode;
  LIdx: Integer;
begin
  LNode := CreateNode('meta.enum');
  DoAdvance(); // skip 'enum'
  LNode.SetAttr('identifier', ConsumeIdentifier());
  Expect('delimiter.lbrace');
  LIdx := 0;
  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    LNode.SetAttr('member_' + IntToStr(LIdx), ConsumeIdentifier());
    Inc(LIdx);
    Match('delimiter.comma');
  end;
  LNode.SetAttr('member_count', IntToStr(LIdx));
  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseFragmentDecl(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.fragment');
  DoAdvance(); // skip 'fragment'
  LNode.SetAttr('identifier', ConsumeIdentifier());
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseImport(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.import');
  DoAdvance(); // skip 'import'
  LNode.SetAttr('path', ConsumeString());
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseInclude(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.include');
  DoAdvance(); // skip 'include'
  LNode.SetAttr('path', ConsumeString());
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseLet(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.let');
  DoAdvance(); // skip 'let'
  LNode.SetAttr('var_name', ConsumeIdentifier());
  Expect('op.assign');
  LNode.AddChild(ParseExpr(0));
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseSet(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.set');
  DoAdvance(); // skip 'set'
  LNode.SetAttr('var_name', ConsumeIdentifier());
  Expect('kw.to');
  LNode.AddChild(ParseExpr(0));
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseIf(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.if');
  DoAdvance(); // skip 'if'

  // Child 0 = condition
  LNode.AddChild(ParseExpr(0));

  // Child 1 = then block
  LNode.AddChild(ParseBlock());

  // Optional else / else if
  if Check('kw.else') then
  begin
    DoAdvance(); // skip 'else'
    if Check('kw.if') then
      // else if (recurse)
      LNode.AddChild(ParseIf())
    else
      // else block
      LNode.AddChild(ParseBlock());
  end;

  Result := LNode;
end;

function TMorParser.ParseWhile(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.while');
  DoAdvance(); // skip 'while'
  LNode.AddChild(ParseExpr(0));   // child 0 = condition
  LNode.AddChild(ParseBlock());   // child 1 = body
  Result := LNode;
end;

function TMorParser.ParseFor(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.for_in');
  DoAdvance(); // skip 'for'
  LNode.SetAttr('var_name', ConsumeIdentifier());
  Expect('kw.in');
  LNode.AddChild(ParseExpr(0));   // child 0 = count/iterable expression
  LNode.AddChild(ParseBlock());   // child 1 = body
  Result := LNode;
end;

function TMorParser.ParseMatch(): TASTNode;
var
  LNode: TASTNode;
  LArm: TASTNode;
begin
  LNode := CreateNode('meta.match');
  DoAdvance(); // skip 'match'
  LNode.AddChild(ParseExpr(0));   // child 0 = match expression
  Expect('delimiter.lbrace');

  while not AtEnd() and not Check('delimiter.rbrace') do
  begin
    if Check('kw.else') then
    begin
      // else => { ... }
      DoAdvance(); // skip 'else'
      Expect('op.fat_arrow');
      LArm := CreateNode('meta.match_else');
      LArm.AddChild(ParseBlock());
      LNode.AddChild(LArm);
    end
    else
    begin
      // pattern | pattern => { ... }
      LArm := CreateNode('meta.match_arm');
      LArm.AddChild(ParseExpr(0));   // first pattern
      while Match('delimiter.pipe') do
        LArm.AddChild(ParseExpr(0)); // alternative patterns
      Expect('op.fat_arrow');
      LArm.AddChild(ParseBlock());   // arm body (last child)
      LNode.AddChild(LArm);
    end;
  end;

  Expect('delimiter.rbrace');
  Result := LNode;
end;

function TMorParser.ParseGuard(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.guard');
  DoAdvance(); // skip 'guard'
  LNode.AddChild(ParseExpr(0));   // child 0 = condition
  LNode.AddChild(ParseBlock());   // child 1 = body
  Result := LNode;
end;

function TMorParser.ParseReturn(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.return');
  DoAdvance(); // skip 'return'
  if not Check('delimiter.semicolon') then
    LNode.AddChild(ParseExpr(0)); // child 0 = return value (optional)
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseTryRecover(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.try_recover');
  DoAdvance(); // skip 'try'
  LNode.AddChild(ParseBlock());   // child 0 = try block
  Expect('kw.recover');
  LNode.AddChild(ParseBlock());   // child 1 = recover block
  Result := LNode;
end;

function TMorParser.ParseExpectStmt(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.expect');
  DoAdvance(); // skip 'expect'
  LNode.SetAttr('token_kind', ConsumeDottedIdent());
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseConsumeStmt(): TASTNode;
var
  LNode: TASTNode;
  LKinds: string;
begin
  LNode := CreateNode('meta.consume');
  DoAdvance(); // skip 'consume'

  // Can be single kind or [kind1, kind2, ...]
  if Match('delimiter.lbracket') then
  begin
    LKinds := ConsumeDottedIdent();
    while Match('delimiter.comma') do
      LKinds := LKinds + ',' + ConsumeDottedIdent();
    Expect('delimiter.rbracket');
    LNode.SetAttr('token_kinds', LKinds);
  end
  else
    LNode.SetAttr('token_kind', ConsumeDottedIdent());

  // -> @target
  Expect('op.arrow');
  Expect('op.at');
  LNode.SetAttr('target_attr', ConsumeIdentifier());
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseParseDirective(): TASTNode;
var
  LNode: TASTNode;
  LUntil: string;
begin
  LNode := CreateNode('meta.parse_directive');
  DoAdvance(); // skip 'parse'

  if Check('kw.many') then
  begin
    DoAdvance(); // skip 'many'
    LNode.SetAttr('mode', 'many');
    Expect('kw.stmt');
    Expect('kw.until');
    if Match('delimiter.lbracket') then
    begin
      LUntil := ConsumeDottedIdent();
      while Match('delimiter.comma') do
        LUntil := LUntil + ',' + ConsumeDottedIdent();
      Expect('delimiter.rbracket');
      LNode.SetAttr('until_kinds', LUntil);
    end
    else
      LNode.SetAttr('until_kind', ConsumeDottedIdent());
  end
  else
  begin
    Expect('kw.expr');
    LNode.SetAttr('mode', 'expr');
    // Optional binding power: parse expr 35 -> @operand;
    if Check('literal.integer') then
    begin
      LNode.SetAttr('bind_power', Current().Text);
      DoAdvance();
    end;
  end;

  // -> @target
  Expect('op.arrow');
  Expect('op.at');
  LNode.SetAttr('target_attr', ConsumeIdentifier());
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseOptional(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.optional');
  DoAdvance(); // skip 'optional'
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseSync(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.sync');
  DoAdvance(); // skip 'sync'
  LNode.SetAttr('token_kind', ConsumeDottedIdent());
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseScope(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.scope');
  DoAdvance(); // skip 'scope'

  // Scope name: string literal or @attr
  if Check('op.at') then
  begin
    DoAdvance();
    LNode.SetAttr('scope_attr', ConsumeIdentifier());
  end
  else if Check('literal.string') then
    LNode.SetAttr('scope_name', ConsumeString())
  else
    LNode.SetAttr('scope_name', ConsumeIdentifier());

  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseDeclare(): TASTNode;
var
  LNode: TASTNode;
  LKey: string;
begin
  LNode := CreateNode('meta.declare');
  DoAdvance(); // skip 'declare'

  // @name_attr
  Expect('op.at');
  LNode.SetAttr('name_attr', ConsumeIdentifier());

  // as sym_kind
  Expect('kw.as');
  LNode.SetAttr('sym_kind', ConsumeIdentifier());

  // Optional: typed @type_attr
  if Check('kw.typed') then
  begin
    DoAdvance();
    Expect('op.at');
    LNode.SetAttr('type_attr', ConsumeIdentifier());
  end;

  // Optional: where { key = value; ... }
  if Check('kw.where') then
  begin
    DoAdvance();
    Expect('delimiter.lbrace');
    while not AtEnd() and not Check('delimiter.rbrace') do
    begin
      LKey := ConsumeIdentifier();
      Expect('op.assign');
      LNode.SetAttr('where_' + LKey, ConsumeString());
      ExpectSemicolon();
    end;
    Expect('delimiter.rbrace');
  end;

  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseVisit(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.visit');
  DoAdvance(); // skip 'visit'

  if Check('kw.children') then
  begin
    DoAdvance();
    LNode.SetAttr('mode', 'children');
  end
  else if Check('op.at') then
  begin
    DoAdvance();
    LNode.SetAttr('mode', 'attr');
    LNode.SetAttr('attr_name', ConsumeIdentifier());
  end
  else if Check('kw.child') then
  begin
    DoAdvance();
    LNode.SetAttr('mode', 'index');
    Expect('delimiter.lbracket');
    LNode.SetAttr('child_index', ConsumeInteger());
    Expect('delimiter.rbracket');
  end
  else
  begin
    // visit expr;
    LNode.SetAttr('mode', 'expr');
    LNode.AddChild(ParseExpr(0));
  end;

  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseLookup(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.lookup');
  DoAdvance(); // skip 'lookup'

  // @name_attr
  Expect('op.at');
  LNode.SetAttr('name_attr', ConsumeIdentifier());

  if Match('op.arrow') then
  begin
    // -> let bind_var;
    Expect('kw.let');
    LNode.SetAttr('mode', 'bind');
    LNode.SetAttr('bind_var', ConsumeIdentifier());
    ExpectSemicolon();
  end
  else if Check('kw.or') then
  begin
    // or { ... }
    DoAdvance();
    LNode.SetAttr('mode', 'or_block');
    LNode.AddChild(ParseBlock());
    ExpectSemicolon();
  end
  else
    ExpectSemicolon();

  Result := LNode;
end;

function TMorParser.ParseEmit(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.emit');
  DoAdvance(); // skip 'emit'

  // Optional: to target:
  if Check('kw.to') then
  begin
    DoAdvance();
    LNode.SetAttr('target', ConsumeIdentifier());
    Expect('delimiter.colon');
  end;

  // Value expression
  LNode.AddChild(ParseExpr(0));
  ExpectSemicolon();
  Result := LNode;
end;

function TMorParser.ParseSection(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.section');
  DoAdvance(); // skip 'section'
  LNode.SetAttr('identifier', ConsumeIdentifier());
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseIndentBlock(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.indent_block');
  DoAdvance(); // skip 'indent'
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseBefore(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.before');
  DoAdvance(); // skip 'before'
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

function TMorParser.ParseAfter(): TASTNode;
var
  LNode: TASTNode;
begin
  LNode := CreateNode('meta.after');
  DoAdvance(); // skip 'after'
  LNode.AddChild(ParseBlock());
  Result := LNode;
end;

{ Public }

function TMorParser.Parse(const ATokens: TList<TToken>;
  const AFilename: string): TASTNode;
var
  LRoot: TASTNode;
  LKind: string;
begin
  FTokens := ATokens;
  FPos := 0;
  FFilename := AFilename;

  LRoot := CreateNode('mor.root');

  // First statement must be language declaration
  if Check('kw.language') then
    LRoot.AddChild(ParseLanguageDecl());

  // Parse remaining top-level declarations
  while not AtEnd() do
  begin
    if Assigned(FErrors) and FErrors.ReachedMaxErrors() then
      Break;

    LKind := Current().Kind;
    if LKind = 'kw.tokens' then LRoot.AddChild(ParseTokensBlock())
    else if LKind = 'kw.types' then LRoot.AddChild(ParseTypesBlock())
    else if LKind = 'kw.grammar' then LRoot.AddChild(ParseGrammarBlock())
    else if LKind = 'kw.semantics' then LRoot.AddChild(ParseSemanticsBlock())
    else if LKind = 'kw.emitters' then LRoot.AddChild(ParseEmittersBlock())
    else if LKind = 'kw.routine' then LRoot.AddChild(ParseRoutineDecl())
    else if LKind = 'kw.const' then LRoot.AddChild(ParseConstBlock())
    else if LKind = 'kw.enum' then LRoot.AddChild(ParseEnumDecl())
    else if LKind = 'kw.fragment' then LRoot.AddChild(ParseFragmentDecl())
    else if LKind = 'kw.import' then LRoot.AddChild(ParseImport())
    else if LKind = 'kw.include' then LRoot.AddChild(ParseInclude())
    else if LKind = 'kw.guard' then LRoot.AddChild(ParseGuard())
    else
    begin
      if Assigned(FErrors) then
        FErrors.Add(FFilename, Current().Line, Current().Col,
          esError, ERR_MORPARSER_UNEXPECTED_TOP,
          RSMorParserUnexpectedTopLevel, [Current().Text]);
      DoAdvance(); // skip unexpected token to avoid infinite loop
    end;
  end;

  Result := LRoot;
end;

function TMorParser.ParseSingleExpr(const ATokens: TList<TToken>): TASTNode;
begin
  FTokens := ATokens;
  FPos := 0;
  FFilename := '<interpolation>';
  Result := ParseExpr(0);
end;

end.
