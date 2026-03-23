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
  System.Rtti,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.LangConfig,
  Metamorf.Lexer;

type

  { TParser }
  TParser = class(TParserBase)
  private
    FConfig:            TLangConfig;  // not owned — caller manages lifetime
    FTokens:            TArray<TToken>;
    FPos:               Integer;
    FCurrentNodeKind:   string;   // set by engine before each handler dispatch
    FCurrentInfixPower: Integer;  // set by engine before each infix handler dispatch
    FPendingComments:   TObjectList<TASTNode>;  // OwnsObjects = False (transferred to AST)

    // Returns True if position is at or past the last token
    function IsAtEnd(): Boolean;

    // Returns a synthetic EOF token for safe out-of-bounds access
    function MakeEOFToken(): TToken;

    // Advance position by one — does NOT skip comments (they are AST nodes)
    procedure Advance();

    // Report a parse error at the given token's location via FErrors
    procedure AddError(const AToken: TToken; const AMsg: string);

    // Error recovery — advance until a statement boundary is found
    {$HINTS OFF}
    procedure Synchronize();
    {$HINTS ON}

    // Advance past any comment tokens at the current position.
    // Called by Check, Match, and Expect so grammar handler while-loops
    // transparently skip comments without any language-specific code.
    procedure SkipComments();

    // Post-parse: attach pending comments as decorations on nearest stmt nodes
    procedure AttachComments(const ARoot: TASTNode);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Bind the language config. Must be called before LoadFromLexer.
    procedure SetConfig(const AConfig: TLangConfig);

    // Copy the token array from a fully tokenized lexer.
    // Returns False if ALexer is nil or has no tokens.
    function LoadFromLexer(const ALexer: TLexer): Boolean;

    // Parse the full token stream and return the root AST node.
    // The caller owns the returned node and is responsible for freeing it
    // (which frees the entire tree).
    function ParseTokens(): TASTNode;

    // TParserBase virtuals — implemented here

    // Returns the token at the current position (or a synthetic EOF token)
    function  CurrentToken(): TToken; override;

    // Returns the token at current + AOffset (or a synthetic EOF token)
    function  PeekToken(const AOffset: Integer = 1): TToken; override;

    // Advances past the current token and returns it
    function  Consume(): TToken; override;

    // If current token kind = AKind, consume it. Otherwise add an error.
    procedure Expect(const AKind: string); override;

    // Returns True if the current token kind matches AKind
    function  Check(const AKind: string): Boolean; override;

    // If Check() is True, consumes the token and returns True. Else False.
    function  Match(const AKind: string): Boolean; override;

    // Pratt expression parser — AMinPower is the caller's binding power floor
    function  ParseExpression(const AMinPower: Integer = 0): TASTNodeBase; override;

    // Parse one statement — dispatches via statement handlers or falls back
    // to expression-statement. Comments become first-class AST nodes here.
    function  ParseStatement(): TASTNodeBase; override;

    // Node creation — three overloads (kind comes from dispatch context or caller)
    function  CreateNode(): TASTNode; override;
    function  CreateNode(const ANodeKind: string): TASTNode; override;
    function  CreateNode(const ANodeKind: string;
      const AToken: TToken): TASTNode; override;

    // Returns the binding power of the currently dispatching infix operator
    function  CurrentInfixPower(): Integer; override;

    // Returns binding power - 1 for right-associative recursive calls
    function  CurrentInfixPowerRight(): Integer; override;

    // Returns the configured block-close kind string
    function  GetBlockCloseKind(): string; override;

    // Returns the configured statement terminator kind string
    function  GetStatementTerminatorKind(): string; override;

    // Collects raw tokens as verbatim text with balanced depth tracking
    function  CollectRawTokens(): string; override;
  end;

implementation

{ TParser }

constructor TParser.Create();
begin
  inherited;
  FConfig            := nil;
  FPos               := 0;
  FCurrentNodeKind   := '';
  FCurrentInfixPower := 0;
  FPendingComments   := TObjectList<TASTNode>.Create(False);
  SetLength(FTokens, 0);
end;

destructor TParser.Destroy();
var
  LI: Integer;
begin
  if FPendingComments <> nil then
  begin
    for LI := 0 to FPendingComments.Count - 1 do
      FPendingComments[LI].Free();
    FreeAndNil(FPendingComments);
  end;
  inherited;
end;

procedure TParser.SetConfig(const AConfig: TLangConfig);
begin
  FConfig := AConfig;
end;

function TParser.LoadFromLexer(const ALexer: TLexer): Boolean;
begin
  Result := False;
  if ALexer = nil then
    Exit;
  if ALexer.GetTokenCount() = 0 then
    Exit;

  FTokens := ALexer.GetTokens();
  FPos    := 0;
  Result  := True;
end;

function TParser.IsAtEnd(): Boolean;
begin
  Result := FPos >= Length(FTokens);

  // Also treat EOF token kind as end-of-stream
  if not Result then
    Result := FTokens[FPos].Kind = FConfig.GetEOFKind();
end;

function TParser.MakeEOFToken(): TToken;
begin
  Result.Kind      := KIND_EOF;
  Result.Text      := '';
  Result.Value     := TValue.Empty;
  if Length(FTokens) > 0 then
  begin
    Result.Filename  := FTokens[High(FTokens)].Filename;
    Result.Line      := FTokens[High(FTokens)].Line;
    Result.Column    := FTokens[High(FTokens)].Column;
    Result.EndLine   := FTokens[High(FTokens)].EndLine;
    Result.EndColumn := FTokens[High(FTokens)].EndColumn;
  end
  else
  begin
    Result.Filename  := '';
    Result.Line      := 0;
    Result.Column    := 0;
    Result.EndLine   := 0;
    Result.EndColumn := 0;
  end;
end;

procedure TParser.Advance();
begin
  if FPos < Length(FTokens) then
    Inc(FPos);
end;

procedure TParser.SkipComments();
var
  LKind:         string;
  LCommentNode:  TASTNode;
  LCommentToken: TToken;
  LPrevToken:    TToken;
  LGap:          Integer;
begin
  // Advance past any comment tokens, capturing each one into
  // FPendingComments for post-parse attachment as decorations.
  // Inline detection: when a comment sits on the same source line as the
  // preceding token, store the column gap as 'comment.gap' so the emitter
  // can reproduce the original spacing.
  while not IsAtEnd() do
  begin
    LKind := CurrentToken().Kind;
    if (LKind = FConfig.GetLineCommentKind()) or
       (LKind = FConfig.GetBlockCommentKind()) then
    begin
      LCommentToken := CurrentToken();
      LCommentNode := TASTNode.CreateNode(LKind, LCommentToken);
      if (FPos > 0) then
      begin
        LPrevToken := FTokens[FPos - 1];
        if (LPrevToken.EndLine = LCommentToken.Line) then
        begin
          LGap := LCommentToken.Column - LPrevToken.EndColumn;
          if LGap < 1 then
            LGap := 1;
          LCommentNode.SetAttr('comment.gap', TValue.From<Integer>(LGap));
        end;
      end;
      FPendingComments.Add(LCommentNode);
      Advance();
    end
    else
      Break;
  end;
end;

procedure TParser.AttachComments(const ARoot: TASTNode);

  procedure FlattenStmtNodes(const ANode: TASTNode;
    const AList: TList<TASTNode>);
  var
    LI:   Integer;
    LKind: string;
  begin
    if ANode = nil then
      Exit;
    LKind := ANode.GetNodeKind();
    if (LKind = 'program.root') or LKind.StartsWith('stmt.') then
      AList.Add(ANode);
    for LI := 0 to ANode.ChildCount() - 1 do
      FlattenStmtNodes(ANode.GetChildNode(LI), AList);
  end;

var
  LNodeList:    TList<TASTNode>;
  LComment:     TASTNode;
  LCommentLine: Integer;
  LGapValue:    TValue;
  LIsInline:    Boolean;
  LCI:          Integer;
  LNI:          Integer;
  LAttached:    Boolean;
begin
  if FPendingComments.Count = 0 then
    Exit;

  LNodeList := TList<TASTNode>.Create();
  try
    FlattenStmtNodes(ARoot, LNodeList);

    for LCI := 0 to FPendingComments.Count - 1 do
    begin
      LComment     := FPendingComments[LCI];
      LCommentLine := LComment.GetToken().Line;
      LIsInline    := LComment.GetAttr('comment.gap', LGapValue);
      LAttached    := False;

      if LIsInline then
      begin
        // Trailing (inline): find last stmt node on the same line
        for LNI := LNodeList.Count - 1 downto 0 do
        begin
          if LNodeList[LNI].GetToken().Line = LCommentLine then
          begin
            LNodeList[LNI].AddTrailingComment(LComment);
            LAttached := True;
            Break;
          end;
          if LNodeList[LNI].GetToken().Line < LCommentLine then
            Break;
        end;
        // Fallback: attach as trailing on the last node before this line
        if not LAttached then
        begin
          for LNI := LNodeList.Count - 1 downto 0 do
          begin
            if LNodeList[LNI].GetToken().Line <= LCommentLine then
            begin
              LNodeList[LNI].AddTrailingComment(LComment);
              LAttached := True;
              Break;
            end;
          end;
        end;
      end
      else
      begin
        // Leading (standalone): find first stmt node after the comment
        for LNI := 0 to LNodeList.Count - 1 do
        begin
          if LNodeList[LNI].GetToken().Line > LCommentLine then
          begin
            LNodeList[LNI].AddLeadingComment(LComment);
            LAttached := True;
            Break;
          end;
        end;
        // End-of-file fallback
        if not LAttached and (LNodeList.Count > 0) then
        begin
          LNodeList[LNodeList.Count - 1].AddTrailingComment(LComment);
          LAttached := True;
        end;
      end;

      if not LAttached then
        LComment.Free();
    end;

    FPendingComments.Clear();
  finally
    LNodeList.Free();
  end;
end;

procedure TParser.AddError(const AToken: TToken;
  const AMsg: string);
begin
  if FErrors = nil then
    Exit;
  FErrors.Add(
    AToken.Filename,
    AToken.Line,
    AToken.Column,
    esError,
    'P0001',
    AMsg);
end;

procedure TParser.Synchronize();
var
  LTerminator: string;
  LBlockClose: string;
begin
  // Advance until we find a statement terminator, block close, or EOF.
  // This gives the parser a chance to continue after an error and report
  // further errors rather than cascading from one bad token.
  LTerminator := FConfig.GetStructural().StatementTerminator;
  LBlockClose := FConfig.GetStructural().BlockClose;

  while not IsAtEnd() do
  begin
    if (LTerminator <> '') and (CurrentToken().Kind = LTerminator) then
    begin
      Advance();  // consume the terminator and stop
      Exit;
    end;

    if (LBlockClose <> '') and (CurrentToken().Kind = LBlockClose) then
      Exit;  // leave block-close for the caller to consume

    Advance();
  end;
end;

function TParser.CurrentToken(): TToken;
begin
  if FPos < Length(FTokens) then
    Result := FTokens[FPos]
  else
    Result := MakeEOFToken();
end;

function TParser.PeekToken(const AOffset: Integer): TToken;
var
  LIndex: Integer;
begin
  LIndex := FPos + AOffset;
  if (LIndex >= 0) and (LIndex < Length(FTokens)) then
    Result := FTokens[LIndex]
  else
    Result := MakeEOFToken();
end;

function TParser.Consume(): TToken;
begin
  Result := CurrentToken();
  Advance();
end;

procedure TParser.Expect(const AKind: string);
var
  LToken: TToken;
begin
  SkipComments();
  LToken := CurrentToken();
  if LToken.Kind = AKind then
    Advance()
  else
    if LToken.Text <> '' then
      AddError(LToken,
        'Expected ' + AKind + ' but found ' + LToken.Kind +
        ' (' + LToken.Text + ')')
    else
      AddError(LToken,
        'Expected ' + AKind + ' but found ' + LToken.Kind);
end;

function TParser.Check(const AKind: string): Boolean;
begin
  SkipComments();
  Result := CurrentToken().Kind = AKind;
end;

function TParser.Match(const AKind: string): Boolean;
begin
  if Check(AKind) then
  begin
    Advance();
    Result := True;
  end
  else
    Result := False;
end;

function TParser.CreateNode(): TASTNode;
begin
  // Uses the dispatch context set by the engine immediately before the
  // current handler was called. Token = current at time of creation.
  Result := TASTNode.CreateNode(FCurrentNodeKind, CurrentToken());
end;

function TParser.CreateNode(const ANodeKind: string): TASTNode;
begin
  // Explicit kind, token = current. Used for secondary/structural nodes
  // created within a handler (e.g. 'block.then', 'block.else').
  Result := TASTNode.CreateNode(ANodeKind, CurrentToken());
end;

function TParser.CreateNode(const ANodeKind: string;
  const AToken: TToken): TASTNode;
begin
  // Explicit kind and explicit token. Used when the handler has already
  // consumed past the token it wants to associate with the node.
  Result := TASTNode.CreateNode(ANodeKind, AToken);
end;

function TParser.CurrentInfixPower(): Integer;
begin
  // Returns the binding power of the currently dispatching infix entry.
  // Infix handlers call ParseExpression(AParser.CurrentInfixPower()) for
  // left-associative operators — same power stops equal-precedence operators.
  Result := FCurrentInfixPower;
end;

function TParser.CurrentInfixPowerRight(): Integer;
begin
  // Returns binding power - 1 for right-associative recursive calls.
  // Infix handlers call ParseExpression(AParser.CurrentInfixPowerRight())
  // to allow the right operand to bind at the same precedence level.
  Result := FCurrentInfixPower - 1;
end;

function TParser.GetBlockCloseKind(): string;
begin
  Result := FConfig.GetStructural().BlockClose;
end;

function TParser.GetStatementTerminatorKind(): string;
begin
  Result := FConfig.GetStructural().StatementTerminator;
end;

function TParser.CollectRawTokens(): string;
var
  LRaw:   string;
  LDepth: Integer;
  LDone:  Boolean;
  LKind:  string;
begin
  LRaw   := '';
  LDepth := 0;
  LDone  := False;

  // Use direct kind comparison instead of Check() to avoid
  // SkipComments() silently eating comment tokens that serve
  // as statement boundaries in some languages.
  while not LDone and (CurrentToken().Kind <> KIND_EOF) do
  begin
    LKind := CurrentToken().Kind;

    // At depth 0, comment tokens mark a statement boundary
    if (LDepth <= 0) and
       ((LKind = KIND_COMMENT_LINE) or (LKind = KIND_COMMENT_BLOCK)) then
    begin
      LDone := True;
    end
    // Depth tracking for nested parens, brackets, braces
    else if (LKind = 'delimiter.lparen') or
       (LKind = 'delimiter.lbracket') or
       (LKind = 'cpp.delimiter.lbrace') then
    begin
      Inc(LDepth);
      LRaw := LRaw + CurrentToken().Text;
      Consume();
    end
    else if (LKind = 'delimiter.rparen') or
            (LKind = 'delimiter.rbracket') or
            (LKind = 'cpp.delimiter.rbrace') then
    begin
      if LDepth <= 0 then
        LDone := True   // closer belongs to parent context
      else
      begin
        Dec(LDepth);
        LRaw := LRaw + CurrentToken().Text;
        Consume();
      end;
    end
    else if (LDepth <= 0) and
            ((LKind = 'delimiter.comma') or
             (LKind = 'delimiter.semicolon') or
             LKind.StartsWith('keyword.')) then
    begin
      LDone := True;    // language boundary
    end
    else
    begin
      if LRaw <> '' then
        LRaw := LRaw + ' ';
      LRaw := LRaw + CurrentToken().Text;
      Consume();
    end;
  end;

  Result := LRaw;
end;

function TParser.ParseExpression(
  const AMinPower: Integer): TASTNodeBase;
var
  LToken:        TToken;
  LPrefixEntry:  TPrefixEntry;
  LInfixEntry:   TInfixEntry;
  LLeft:         TASTNodeBase;
begin
  Result := nil;

  if IsAtEnd() then
    Exit;

  SkipComments();

  if IsAtEnd() then
    Exit;

  LToken := CurrentToken();

  // Look up prefix handler — every expression must start with one
  if not FConfig.GetPrefixEntry(LToken.Kind, LPrefixEntry) then
  begin
    AddError(LToken, 'Unexpected token in expression: ' +
      LToken.Kind + ' (' + LToken.Text + ')');
    Advance();  // consume the bad token to avoid an infinite loop
    Exit;
  end;

  // Set dispatch context then call prefix handler
  FCurrentNodeKind   := LPrefixEntry.NodeKind;
  FCurrentInfixPower := 0;
  LLeft := LPrefixEntry.Handler(Self);

  // Pratt loop — keep consuming infix operators while binding power allows
  while not IsAtEnd() do
  begin
    SkipComments();
    if IsAtEnd() then
      Break;
    LToken := CurrentToken();

    if not FConfig.GetInfixEntry(LToken.Kind, LInfixEntry) then
      Break;  // not a known infix operator at this position

    if LInfixEntry.BindingPower <= AMinPower then
      Break;  // caller's binding power wins — stop here

    // Set dispatch context then call infix handler
    FCurrentNodeKind   := LInfixEntry.NodeKind;
    FCurrentInfixPower := LInfixEntry.BindingPower;
    LLeft := LInfixEntry.Handler(Self, LLeft);
  end;

  Result := LLeft;
end;

function TParser.ParseStatement(): TASTNodeBase;
var
  LToken:       TToken;
  LStmtEntry:   TStatementEntry;
  LStructural:  TStructuralConfig;
  LExprNode:    TASTNodeBase;
  LSavedPos:    Integer;
begin
  Result := nil;

  if IsAtEnd() then
    Exit;

  SkipComments();

  if IsAtEnd() then
    Exit;

  LSavedPos   := FPos;
  LToken      := CurrentToken();
  LStructural := FConfig.GetStructural();

  // Statement handler dispatch
  if FConfig.GetStatementEntry(LToken.Kind, LStmtEntry) then
  begin
    FCurrentNodeKind   := LStmtEntry.NodeKind;
    FCurrentInfixPower := 0;
    Result := LStmtEntry.Handler(Self);
    Exit;
  end;

  // Fallback — expression statement.
  // Wrap in a stmt.expr node so the emitter can add a trailing semicolon.
  LExprNode := ParseExpression(0);
  if LStructural.StatementTerminator <> '' then
  begin
    if not IsAtEnd() then
      Match(LStructural.StatementTerminator);
  end;
  FCurrentNodeKind   := 'stmt.expr';
  FCurrentInfixPower := 0;
  Result := CreateNode();
  TASTNode(Result).AddChild(TASTNode(LExprNode));

  // Guard: if nothing consumed after full dispatch, skip the stuck token
  if FPos = LSavedPos then
  begin
    AddError(CurrentToken(), 'Unexpected token: ' +
      CurrentToken().Kind + ' (' + CurrentToken().Text + ')');
    Advance();
  end;
end;

function TParser.ParseTokens(): TASTNode;
var
  LRoot:     TASTNode;
  LStmt:     TASTNodeBase;
  LFilename: string;
  LSavedPos: Integer;
begin
  // Report the filename and token count so the user can see what is being parsed
  if Length(FTokens) > 0 then
    LFilename := FTokens[0].Filename
  else
    LFilename := '';
  Status('Parsing %s (%d tokens)...', [LFilename, Length(FTokens) - 1]);

  // Synthesise a root node from the very first token for location tracking
  FCurrentNodeKind   := 'program.root';
  FCurrentInfixPower := 0;
  LRoot := TASTNode.CreateNode('program.root', CurrentToken());

  while not IsAtEnd() do
  begin
    SkipComments();
    if IsAtEnd() then
      Break;
    LSavedPos := FPos;
    LStmt := ParseStatement();
    if LStmt <> nil then
      LRoot.AddChild(TASTNode(LStmt));
    // Guard: if ParseStatement did not advance, skip the stuck token
    if FPos = LSavedPos then
    begin
      AddError(CurrentToken(), 'Unexpected token: ' +
        CurrentToken().Kind + ' (' + CurrentToken().Text + ')');
      Advance();
    end;
  end;

  AttachComments(LRoot);

  Result := LRoot;
end;

end.
