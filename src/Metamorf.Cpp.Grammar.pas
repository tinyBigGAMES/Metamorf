{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Cpp.Grammar;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigCppGrammar(const AMetamorf: TMetamorf);

implementation

uses
  System.SysUtils,
  System.Rtti,
  Metamorf.Common,
  Metamorf.LangConfig;

// =========================================================================
// Statement Passthrough
// =========================================================================
// When a cpp.keyword.* appears in statement position, collect all raw
// tokens using brace-depth tracking and store as stmt.cpp_raw.
// Single-line: collects until ';' at brace depth 0.
// Block-level: collects until '}' closes brace depth back to 0.

procedure RegisterCppStmtPassthrough(const AMetamorf: TMetamorf);

  procedure RegCppStmt(const AMetamorf: TMetamorf; const AKeyword: string);
  begin
    AMetamorf.Config().RegisterStatement(AKeyword, 'stmt.cpp_raw',
      function(AParser: TParserBase): TASTNodeBase
      var
        LNode:  TASTNode;
        LRaw:   string;
        LDepth: Integer;
        LDone:  Boolean;
      begin
        LNode  := AParser.CreateNode();
        LDepth := 0;
        LDone  := False;

        // Include the triggering keyword token text
        LRaw := AParser.CurrentToken().Text;
        AParser.Consume();

        while not LDone and not AParser.Check(KIND_EOF) do
        begin
          if AParser.Check('cpp.delimiter.lbrace') then
          begin
            Inc(LDepth);
            LRaw := LRaw + ' { ';
            AParser.Consume();
          end
          else if AParser.Check('cpp.delimiter.rbrace') then
          begin
            Dec(LDepth);
            LRaw := LRaw + ' } ';
            AParser.Consume();
            if LDepth <= 0 then
              LDone := True;
          end
          else if AParser.Check('delimiter.semicolon') and (LDepth <= 0) then
          begin
            LRaw := LRaw + ';';
            AParser.Consume();
            LDone := True;
          end
          else
          begin
            LRaw := LRaw + ' ' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
        end;

        LNode.SetAttr('cpp.raw', TValue.From<string>(LRaw));
        Result := LNode;
      end);
  end;

begin
  RegCppStmt(AMetamorf, 'cpp.keyword.auto');
  RegCppStmt(AMetamorf, 'cpp.keyword.break');
  RegCppStmt(AMetamorf, 'cpp.keyword.catch');
  RegCppStmt(AMetamorf, 'cpp.keyword.class');
  RegCppStmt(AMetamorf, 'cpp.keyword.concept');
  RegCppStmt(AMetamorf, 'cpp.keyword.const_cast');
  RegCppStmt(AMetamorf, 'cpp.keyword.consteval');
  RegCppStmt(AMetamorf, 'cpp.keyword.constexpr');
  RegCppStmt(AMetamorf, 'cpp.keyword.constinit');
  RegCppStmt(AMetamorf, 'cpp.keyword.continue');
  RegCppStmt(AMetamorf, 'cpp.keyword.co_await');
  RegCppStmt(AMetamorf, 'cpp.keyword.co_return');
  RegCppStmt(AMetamorf, 'cpp.keyword.co_yield');
  RegCppStmt(AMetamorf, 'cpp.keyword.decltype');
  RegCppStmt(AMetamorf, 'cpp.keyword.default');
  RegCppStmt(AMetamorf, 'cpp.keyword.delete');
  RegCppStmt(AMetamorf, 'cpp.keyword.dynamic_cast');
  RegCppStmt(AMetamorf, 'cpp.keyword.enum');
  RegCppStmt(AMetamorf, 'cpp.keyword.explicit');
  RegCppStmt(AMetamorf, 'cpp.keyword.export');
  RegCppStmt(AMetamorf, 'cpp.keyword.extern');
  RegCppStmt(AMetamorf, 'cpp.keyword.friend');
  RegCppStmt(AMetamorf, 'cpp.keyword.goto');
  RegCppStmt(AMetamorf, 'cpp.keyword.inline');
  RegCppStmt(AMetamorf, 'cpp.keyword.mutable');
  RegCppStmt(AMetamorf, 'cpp.keyword.namespace');
  RegCppStmt(AMetamorf, 'cpp.keyword.new');
  RegCppStmt(AMetamorf, 'cpp.keyword.noexcept');
  RegCppStmt(AMetamorf, 'cpp.keyword.nullptr');
  RegCppStmt(AMetamorf, 'cpp.keyword.operator');
  RegCppStmt(AMetamorf, 'cpp.keyword.override');
  RegCppStmt(AMetamorf, 'cpp.keyword.private');
  RegCppStmt(AMetamorf, 'cpp.keyword.protected');
  RegCppStmt(AMetamorf, 'cpp.keyword.public');
  RegCppStmt(AMetamorf, 'cpp.keyword.register');
  RegCppStmt(AMetamorf, 'cpp.keyword.reinterpret_cast');
  RegCppStmt(AMetamorf, 'cpp.keyword.requires');
  RegCppStmt(AMetamorf, 'cpp.keyword.sizeof');
  RegCppStmt(AMetamorf, 'cpp.keyword.static');
  RegCppStmt(AMetamorf, 'cpp.keyword.static_assert');
  RegCppStmt(AMetamorf, 'cpp.keyword.static_cast');
  RegCppStmt(AMetamorf, 'cpp.keyword.struct');
  RegCppStmt(AMetamorf, 'cpp.keyword.switch');
  RegCppStmt(AMetamorf, 'cpp.keyword.template');
  RegCppStmt(AMetamorf, 'cpp.keyword.this');
  RegCppStmt(AMetamorf, 'cpp.keyword.throw');
  RegCppStmt(AMetamorf, 'cpp.keyword.try');
  RegCppStmt(AMetamorf, 'cpp.keyword.typedef');
  RegCppStmt(AMetamorf, 'cpp.keyword.typeid');
  RegCppStmt(AMetamorf, 'cpp.keyword.typename');
  RegCppStmt(AMetamorf, 'cpp.keyword.union');
  RegCppStmt(AMetamorf, 'cpp.keyword.using');
  RegCppStmt(AMetamorf, 'cpp.keyword.virtual');
  RegCppStmt(AMetamorf, 'cpp.keyword.volatile');
  RegCppStmt(AMetamorf, 'cpp.keyword.wchar_t');
end;

// =========================================================================
// Expression Prefix Passthrough
// =========================================================================
// When a cpp.keyword.* appears in expression position, collect raw tokens
// until an expression boundary is hit. Boundaries at depth 0:
//   , (arg separator)  ; (statement end)  ) ] (closing parent context)
//   Any language keyword (keyword.*)

procedure RegisterCppExprPrefixes(const AMetamorf: TMetamorf);

  procedure RegCppExpr(const AMetamorf: TMetamorf; const AKeyword: string);
  begin
    AMetamorf.Config().RegisterPrefix(AKeyword, 'expr.cpp_raw',
      function(AParser: TParserBase): TASTNodeBase
      var
        LNode:  TASTNode;
        LRaw:   string;
        LDepth: Integer;
        LDone:  Boolean;
        LKind:  string;
      begin
        LNode := AParser.CreateNode();
        LRaw  := AParser.CurrentToken().Text;
        AParser.Consume();

        LDepth := 0;
        LDone  := False;

        while not LDone and not AParser.Check(KIND_EOF) do
        begin
          LKind := AParser.CurrentToken().Kind;

          // Depth tracking for nested parentheses, brackets, and braces
          if (LKind = 'delimiter.lparen') or
             (LKind = 'delimiter.lbracket') or
             (LKind = 'cpp.delimiter.lbrace') then
          begin
            Inc(LDepth);
            LRaw := LRaw + AParser.CurrentToken().Text;
            AParser.Consume();
          end
          else if (LKind = 'delimiter.rparen') or
                  (LKind = 'delimiter.rbracket') or
                  (LKind = 'cpp.delimiter.rbrace') then
          begin
            if LDepth <= 0 then
            begin
              // This closer belongs to the parent context — stop
              LDone := True;
            end
            else
            begin
              Dec(LDepth);
              LRaw := LRaw + AParser.CurrentToken().Text;
              AParser.Consume();
            end;
          end
          else if (LDepth <= 0) and
                  ((LKind = 'delimiter.comma') or
                   (LKind = 'delimiter.semicolon') or
                   LKind.StartsWith('keyword.')) then
          begin
            // Language boundary — stop
            LDone := True;
          end
          else
          begin
            LRaw := LRaw + ' ' + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
        end;

        LNode.SetAttr('cpp.raw', TValue.From<string>(LRaw));
        Result := LNode;
      end);
  end;

begin
  RegCppExpr(AMetamorf, 'cpp.keyword.auto');
  RegCppExpr(AMetamorf, 'cpp.keyword.bool');
  RegCppExpr(AMetamorf, 'cpp.keyword.break');
  RegCppExpr(AMetamorf, 'cpp.keyword.char');
  RegCppExpr(AMetamorf, 'cpp.keyword.class');
  RegCppExpr(AMetamorf, 'cpp.keyword.const_cast');
  RegCppExpr(AMetamorf, 'cpp.keyword.constexpr');
  RegCppExpr(AMetamorf, 'cpp.keyword.decltype');
  RegCppExpr(AMetamorf, 'cpp.keyword.delete');
  RegCppExpr(AMetamorf, 'cpp.keyword.double');
  RegCppExpr(AMetamorf, 'cpp.keyword.dynamic_cast');
  RegCppExpr(AMetamorf, 'cpp.keyword.float');
  RegCppExpr(AMetamorf, 'cpp.keyword.int');
  RegCppExpr(AMetamorf, 'cpp.keyword.long');
  RegCppExpr(AMetamorf, 'cpp.keyword.new');
  RegCppExpr(AMetamorf, 'cpp.keyword.nullptr');
  RegCppExpr(AMetamorf, 'cpp.keyword.reinterpret_cast');
  RegCppExpr(AMetamorf, 'cpp.keyword.short');
  RegCppExpr(AMetamorf, 'cpp.keyword.signed');
  RegCppExpr(AMetamorf, 'cpp.keyword.sizeof');
  RegCppExpr(AMetamorf, 'cpp.keyword.static_cast');
  RegCppExpr(AMetamorf, 'cpp.keyword.throw');
  RegCppExpr(AMetamorf, 'cpp.keyword.typeid');
  RegCppExpr(AMetamorf, 'cpp.keyword.unsigned');
  RegCppExpr(AMetamorf, 'cpp.keyword.void');
  RegCppExpr(AMetamorf, 'cpp.keyword.wchar_t');
end;

// =========================================================================
// Grouped Expression Wrapping — C-style Cast Detection
// =========================================================================
// Wraps the existing delimiter.lparen prefix handler to detect C-style
// casts: (cpp_type*)expr. If the token after '(' is a cpp.keyword.*,
// collect raw tokens until ')' then parse the operand. Otherwise
// delegate to the language's original grouped expression handler.

procedure WrapGroupedExprForCppCast(const AMetamorf: TMetamorf);
var
  LExisting:    TPrefixEntry;
  LOrigHandler: TPrefixHandler;
begin
  // If the language didn't register a grouped expression handler,
  // there is nothing to wrap.
  if not AMetamorf.Config().GetPrefixEntry('delimiter.lparen', LExisting) then
    Exit;

  LOrigHandler := LExisting.Handler;

  AMetamorf.Config().RegisterPrefix('delimiter.lparen', LExisting.NodeKind,
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:    TASTNode;
      LCastRaw: string;
    begin
      // Peek ahead: if the token after '(' is a C++ keyword, this is
      // a C-style cast like (char*)ptr or (int32_t)value.
      if AParser.PeekToken(1).Kind.StartsWith('cpp.keyword.') then
      begin
        AParser.Consume();  // consume '('

        // Collect the raw cast type text until ')'
        LCastRaw := '';
        while not AParser.Check('delimiter.rparen') and
              not AParser.Check(KIND_EOF) do
        begin
          if LCastRaw <> '' then
            LCastRaw := LCastRaw + ' ';
          LCastRaw := LCastRaw + AParser.CurrentToken().Text;
          AParser.Consume();
        end;
        AParser.Expect('delimiter.rparen');

        LNode := AParser.CreateNode('expr.cpp_cast');
        LNode.SetAttr('cast.raw', TValue.From<string>(LCastRaw));
        // Parse the operand -- the custom language owns this part
        LNode.AddChild(TASTNode(AParser.ParseExpression(50)));
        Result := LNode;
      end
      else
      begin
        // Not a C++ cast — delegate to the language's grouped expr handler
        Result := LOrigHandler(AParser);
      end;
    end);
end;

// =========================================================================
// Scope Resolution — :: infix operator
// =========================================================================
// Collects qualified names like std::string, std::vector::iterator.

procedure RegisterCppScopeResolution(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterInfixLeft('cpp.op.scope', 90, 'expr.cpp_qualified',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LQualified: string;
    begin
      LQualified := ALeft.GetToken().Text;
      while AParser.Check('cpp.op.scope') do
      begin
        AParser.Consume();  // consume '::'
        LQualified := LQualified + '::' + AParser.CurrentToken().Text;
        AParser.Consume();  // consume next identifier
      end;
      LNode := AParser.CreateNode('expr.cpp_qualified', ALeft.GetToken());
      LNode.SetAttr('qualified.name', TValue.From<string>(LQualified));
      ALeft.Free();  // text extracted into qualified.name — free orphaned node
      Result := LNode;
    end);
end;

// =========================================================================
// Arrow Access — -> infix operator
// =========================================================================
// Handles pointer member access: expr->member

procedure RegisterCppArrowAccess(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterInfixLeft('cpp.op.arrow', 85, 'expr.cpp_arrow',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LFieldTok: TToken;
    begin
      AParser.Consume();  // consume '->'
      LFieldTok := AParser.CurrentToken();
      LNode := AParser.CreateNode('expr.cpp_arrow', LFieldTok);
      LNode.SetAttr('field.name', TValue.From<string>(LFieldTok.Text));
      LNode.AddChild(TASTNode(ALeft));
      AParser.Consume();  // consume member name
      Result := LNode;
    end);
end;

// =========================================================================
// Preprocessor — #include, #define, #pragma, etc.
// =========================================================================
// Collects C++ preprocessor directives verbatim. Handles #include with
// both "..." and <...> forms specially to avoid whitespace issues.

procedure RegisterCppPreprocessor(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config().RegisterStatement('cpp.op.hash', 'stmt.preprocessor',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LDirective: string;
      LRaw:       string;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume '#'

      LDirective := AParser.CurrentToken().Text;
      AParser.Consume();  // consume directive name (include, define, pragma, ...)
      LRaw := '#' + LDirective;

      if SameText(LDirective, 'include') then
      begin
        // #include "file.h" — the string token includes quotes
        if AParser.CurrentToken().Text.StartsWith('"') then
        begin
          LRaw := LRaw + ' ' + AParser.CurrentToken().Text;
          AParser.Consume();
        end
        // #include <file.h> — collect tokens between < and >
        else if AParser.Check('op.lt') then
        begin
          LRaw := LRaw + ' <';
          AParser.Consume();  // consume '<'
          while not AParser.Check('op.gt') and
                not AParser.Check(KIND_EOF) do
          begin
            LRaw := LRaw + AParser.CurrentToken().Text;
            AParser.Consume();
          end;
          LRaw := LRaw + '>';
          AParser.Consume();  // consume '>'
        end;
      end
      else
      begin
        // Other directives (#define, #pragma, etc.): collect to ';' or
        // language keyword boundary or EOF
        while not AParser.Check('delimiter.semicolon') and
              not AParser.CurrentToken().Kind.StartsWith('keyword.') and
              not AParser.Check(KIND_EOF) do
        begin
          LRaw := LRaw + ' ' + AParser.CurrentToken().Text;
          AParser.Consume();
        end;
      end;

      LNode.SetAttr('cpp.raw', TValue.From<string>(LRaw));
      Result := LNode;
    end);
end;

// =========================================================================
// Public Entry Point
// =========================================================================

procedure ConfigCppGrammar(const AMetamorf: TMetamorf);
begin
  // Expression-level: prefix handlers for cpp keywords in expr position
  RegisterCppExprPrefixes(AMetamorf);

  // Infix operators: :: and ->
  RegisterCppScopeResolution(AMetamorf);
  RegisterCppArrowAccess(AMetamorf);

  // Statement-level: passthrough for cpp keywords in statement position
  RegisterCppStmtPassthrough(AMetamorf);

  // Preprocessor: #include, #define, etc.
  RegisterCppPreprocessor(AMetamorf);

  // Wrap the language's grouped expression handler to detect C-style casts.
  // This MUST be called last so the language's handler is already registered.
  WrapGroupedExprForCppCast(AMetamorf);
end;

end.
