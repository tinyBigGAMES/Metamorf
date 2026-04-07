{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lexer;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Character,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.AST;

const
  // .mor Lexer Error Codes (ML001-ML099)
  MOR_ERR_MORLEXER_UNEXPECTED_CHAR     = 'ML001';
  MOR_ERR_MORLEXER_UNTERMINATED_STRING = 'ML002';
  MOR_ERR_MORLEXER_UNTERMINATED_COMMENT= 'ML003';
  MOR_ERR_MORLEXER_INVALID_NUMBER      = 'ML004';
  MOR_ERR_MORLEXER_UNTERMINATED_TRIPLE = 'ML005';

type

  { TOperatorEntry }
  TOperatorEntry = record
    Text: string;
    Kind: string;
  end;

  { TMorLexer }
  TMorLexer = class(TMorErrorsObject)
  private
    FSource: string;
    FFilename: string;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;
    FKeywords: TDictionary<string, string>;
    FOperators: TList<TOperatorEntry>;

    procedure InitKeywords();
    procedure InitOperators();

    function AtEnd(): Boolean;
    function Current(): Char;
    function Peek(): Char;
    function PeekAt(const AOffset: Integer): Char;
    function Advance(): Char;
    function MakeToken(const AKind: string; const AText: string;
      const ALine: Integer; const ACol: Integer): TMorToken;

    procedure SkipWhitespace();
    function SkipLineComment(): Boolean;
    function SkipBlockComment(): Boolean;
    function TryTripleString(var AToken: TMorToken): Boolean;
    function TryString(var AToken: TMorToken): Boolean;
    function TryNumber(var AToken: TMorToken): Boolean;
    function TryOperator(var AToken: TMorToken): Boolean;
    function TryIdentifier(var AToken: TMorToken): Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Tokenize(const ASource: string;
      const AFilename: string = ''): TList<TMorToken>;
  end;

implementation

{ TMorLexer }

constructor TMorLexer.Create();
begin
  inherited;
  FKeywords := TDictionary<string, string>.Create();
  FOperators := TList<TOperatorEntry>.Create();
  InitKeywords();
  InitOperators();
end;

destructor TMorLexer.Destroy();
begin
  FreeAndNil(FOperators);
  FreeAndNil(FKeywords);
  inherited;
end;

procedure TMorLexer.InitKeywords();
begin
  FKeywords.Add('language', 'kw.language');
  FKeywords.Add('version', 'kw.version');
  FKeywords.Add('tokens', 'kw.tokens');
  FKeywords.Add('types', 'kw.types');
  FKeywords.Add('grammar', 'kw.grammar');
  FKeywords.Add('semantics', 'kw.semantics');
  FKeywords.Add('emitters', 'kw.emitters');
  FKeywords.Add('rule', 'kw.rule');
  FKeywords.Add('on', 'kw.on');
  FKeywords.Add('pass', 'kw.pass');
  FKeywords.Add('token', 'kw.token');
  FKeywords.Add('type', 'kw.type');
  FKeywords.Add('map', 'kw.map');
  FKeywords.Add('literal', 'kw.literal');
  FKeywords.Add('compatible', 'kw.compatible');
  FKeywords.Add('decl_kind', 'kw.decl_kind');
  FKeywords.Add('call_kind', 'kw.call_kind');
  FKeywords.Add('call_name_attr', 'kw.call_name_attr');
  FKeywords.Add('name_mangler', 'kw.name_mangler');
  FKeywords.Add('let', 'kw.let');
  FKeywords.Add('if', 'kw.if');
  FKeywords.Add('else', 'kw.else');
  FKeywords.Add('while', 'kw.while');
  FKeywords.Add('for', 'kw.for');
  FKeywords.Add('in', 'kw.in');
  FKeywords.Add('match', 'kw.match');
  FKeywords.Add('guard', 'kw.guard');
  FKeywords.Add('return', 'kw.return');
  FKeywords.Add('routine', 'kw.routine');
  FKeywords.Add('const', 'kw.const');
  FKeywords.Add('enum', 'kw.enum');
  FKeywords.Add('fragment', 'kw.fragment');
  FKeywords.Add('import', 'kw.import');
  FKeywords.Add('include', 'kw.include');
  FKeywords.Add('expect', 'kw.expect');
  FKeywords.Add('consume', 'kw.consume');
  FKeywords.Add('parse', 'kw.parse');
  FKeywords.Add('expr', 'kw.expr');
  FKeywords.Add('stmt', 'kw.stmt');
  FKeywords.Add('many', 'kw.many');
  FKeywords.Add('until', 'kw.until');
  FKeywords.Add('optional', 'kw.optional');
  FKeywords.Add('sync', 'kw.sync');
  FKeywords.Add('scope', 'kw.scope');
  FKeywords.Add('declare', 'kw.declare');
  FKeywords.Add('visit', 'kw.visit');
  FKeywords.Add('lookup', 'kw.lookup');
  FKeywords.Add('emit', 'kw.emit');
  FKeywords.Add('section', 'kw.section');
  FKeywords.Add('indent', 'kw.indent');
  FKeywords.Add('before', 'kw.before');
  FKeywords.Add('after', 'kw.after');
  FKeywords.Add('precedence', 'kw.precedence');
  FKeywords.Add('left', 'kw.left');
  FKeywords.Add('right', 'kw.right');
  FKeywords.Add('try', 'kw.try');
  FKeywords.Add('recover', 'kw.recover');
  FKeywords.Add('not', 'kw.not');
  FKeywords.Add('and', 'kw.and');
  FKeywords.Add('or', 'kw.or');
  FKeywords.Add('true', 'kw.true');
  FKeywords.Add('false', 'kw.false');
  FKeywords.Add('nil', 'kw.nil');
  FKeywords.Add('children', 'kw.children');
  FKeywords.Add('child', 'kw.child');
  FKeywords.Add('as', 'kw.as');
  FKeywords.Add('variable', 'kw.variable');
  FKeywords.Add('constant', 'kw.constant');
  FKeywords.Add('parameter', 'kw.parameter');
  FKeywords.Add('typed', 'kw.typed');
  FKeywords.Add('where', 'kw.where');
  FKeywords.Add('set', 'kw.set');
  FKeywords.Add('to', 'kw.to');
end;

procedure TMorLexer.InitOperators();

  procedure AddOp(const AText: string; const AKind: string);
  var
    LEntry: TOperatorEntry;
  begin
    LEntry.Text := AText;
    LEntry.Kind := AKind;
    FOperators.Add(LEntry);
  end;

begin
  // Sorted longest-first for correct matching
  // 2-char operators
  AddOp('==', 'op.eq');
  AddOp('!=', 'op.ne');
  AddOp('<=', 'op.le');
  AddOp('>=', 'op.ge');
  AddOp('->', 'op.arrow');
  AddOp('=>', 'op.fat_arrow');

  // 1-char operators
  AddOp('=', 'op.assign');
  AddOp('<', 'op.lt');
  AddOp('>', 'op.gt');
  AddOp('+', 'op.plus');
  AddOp('-', 'op.minus');
  AddOp('*', 'op.star');
  AddOp('/', 'op.slash');
  AddOp('%', 'op.percent');
  AddOp('@', 'op.at');

  // Delimiters
  AddOp('(', 'delimiter.lparen');
  AddOp(')', 'delimiter.rparen');
  AddOp('{', 'delimiter.lbrace');
  AddOp('}', 'delimiter.rbrace');
  AddOp('[', 'delimiter.lbracket');
  AddOp(']', 'delimiter.rbracket');
  AddOp(';', 'delimiter.semicolon');
  AddOp(':', 'delimiter.colon');
  AddOp(',', 'delimiter.comma');
  AddOp('.', 'delimiter.dot');
  AddOp('|', 'delimiter.pipe');
end;

function TMorLexer.AtEnd(): Boolean;
begin
  Result := FPos > Length(FSource);
end;

function TMorLexer.Current(): Char;
begin
  if AtEnd() then
    Result := #0
  else
    Result := FSource[FPos];
end;

function TMorLexer.Peek(): Char;
begin
  Result := PeekAt(1);
end;

function TMorLexer.PeekAt(const AOffset: Integer): Char;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx < 1) or (LIdx > Length(FSource)) then
    Result := #0
  else
    Result := FSource[LIdx];
end;

function TMorLexer.Advance(): Char;
begin
  Result := Current();
  if not AtEnd() then
  begin
    if FSource[FPos] = #10 then
    begin
      Inc(FLine);
      FCol := 1;
    end
    else
      Inc(FCol);
    Inc(FPos);
  end;
end;

function TMorLexer.MakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TMorToken;
begin
  Result.Kind := AKind;
  Result.Text := AText;
  Result.Line := ALine;
  Result.Col := ACol;
end;

procedure TMorLexer.SkipWhitespace();
begin
  while not AtEnd() do
  begin
    if Current().IsWhiteSpace then
      Advance()
    else
      Break;
  end;
end;

function TMorLexer.SkipLineComment(): Boolean;
begin
  Result := False;
  if (Current() = '/') and (Peek() = '/') then
  begin
    Result := True;
    // Skip until end of line
    while not AtEnd() and (Current() <> #10) do
      Advance();
  end;
end;

function TMorLexer.SkipBlockComment(): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
begin
  Result := False;
  if (Current() = '/') and (Peek() = '*') then
  begin
    Result := True;
    LStartLine := FLine;
    LStartCol := FCol;
    Advance(); // skip /
    Advance(); // skip *
    while not AtEnd() do
    begin
      if (Current() = '*') and (Peek() = '/') then
      begin
        Advance(); // skip *
        Advance(); // skip /
        Exit;
      end;
      Advance();
    end;
    // Unterminated block comment
    if Assigned(FErrors) then
      FErrors.Add(FFilename, LStartLine, LStartCol,
        esError, MOR_ERR_MORLEXER_UNTERMINATED_COMMENT,
        RSMorLexerUnterminatedComment);
  end;
end;

function TMorLexer.TryTripleString(var AToken: TMorToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
begin
  Result := False;
  // Check for """ (three double quotes)
  if (Current() = '"') and (PeekAt(1) = '"') and (PeekAt(2) = '"') then
  begin
    Result := True;
    LStartLine := FLine;
    LStartCol := FCol;
    Advance(); // skip first "
    Advance(); // skip second "
    Advance(); // skip third "
    LText := '';
    while not AtEnd() do
    begin
      if (Current() = '"') and (PeekAt(1) = '"') and (PeekAt(2) = '"') then
      begin
        Advance(); // skip first "
        Advance(); // skip second "
        Advance(); // skip third "
        AToken := MakeToken('literal.triplestring', LText, LStartLine, LStartCol);
        Exit;
      end;
      LText := LText + Current();
      Advance();
    end;
    // Unterminated triple-quoted string
    if Assigned(FErrors) then
      FErrors.Add(FFilename, LStartLine, LStartCol,
        esError, MOR_ERR_MORLEXER_UNTERMINATED_TRIPLE,
        RSMorLexerUnterminatedTriple);
    AToken := MakeToken('literal.triplestring', LText, LStartLine, LStartCol);
  end;
end;

function TMorLexer.TryString(var AToken: TMorToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LCh: Char;
begin
  Result := False;
  if Current() = '"' then
  begin
    Result := True;
    LStartLine := FLine;
    LStartCol := FCol;
    Advance(); // skip opening "
    LText := '';
    while not AtEnd() and (Current() <> '"') do
    begin
      if Current() = '\' then
      begin
        Advance(); // skip backslash
        if not AtEnd() then
        begin
          LCh := Current();
          case LCh of
            'n': LText := LText + #10;
            't': LText := LText + #9;
            '\': LText := LText + '\';
            '"': LText := LText + '"';
            '{': LText := LText + '\{';  // preserve escaped interpolation marker
          else
            LText := LText + '\' + LCh;
          end;
          Advance();
        end;
      end
      else if Current() = #10 then
      begin
        // Newline inside string -- keep it as literal
        LText := LText + Current();
        Advance();
      end
      else
      begin
        LText := LText + Current();
        Advance();
      end;
    end;
    if not AtEnd() then
      Advance() // skip closing "
    else if Assigned(FErrors) then
      FErrors.Add(FFilename, LStartLine, LStartCol,
        esError, MOR_ERR_MORLEXER_UNTERMINATED_STRING,
        RSMorLexerUnterminatedString);
    AToken := MakeToken('literal.string', LText, LStartLine, LStartCol);
  end;
end;

function TMorLexer.TryNumber(var AToken: TMorToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LIsFloat: Boolean;
begin
  Result := False;
  if Current().IsDigit then
  begin
    Result := True;
    LStartLine := FLine;
    LStartCol := FCol;
    LText := '';
    LIsFloat := False;

    // Collect digits
    while not AtEnd() and Current().IsDigit do
    begin
      LText := LText + Current();
      Advance();
    end;

    // Check for decimal point
    if not AtEnd() and (Current() = '.') and PeekAt(1).IsDigit then
    begin
      LIsFloat := True;
      LText := LText + Current();
      Advance(); // skip .
      while not AtEnd() and Current().IsDigit do
      begin
        LText := LText + Current();
        Advance();
      end;
    end;

    if LIsFloat then
      AToken := MakeToken('literal.float', LText, LStartLine, LStartCol)
    else
      AToken := MakeToken('literal.integer', LText, LStartLine, LStartCol);
  end;
end;

function TMorLexer.TryOperator(var AToken: TMorToken): Boolean;
var
  LI: Integer;
  LEntry: TOperatorEntry;
  LLen: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LMatch: Boolean;
  LJ: Integer;
begin
  Result := False;
  LStartLine := FLine;
  LStartCol := FCol;

  // Try longest match first (operators are sorted longest-first)
  for LI := 0 to FOperators.Count - 1 do
  begin
    LEntry := FOperators[LI];
    LLen := Length(LEntry.Text);

    // Check if we have enough chars remaining
    if FPos + LLen - 1 > Length(FSource) then
      Continue;

    // Compare each character
    LMatch := True;
    for LJ := 1 to LLen do
    begin
      if FSource[FPos + LJ - 1] <> LEntry.Text[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;

    if LMatch then
    begin
      // Special case: don't match '/' if followed by '/' or '*' (comment)
      if (LEntry.Text = '/') and not AtEnd() then
      begin
        if (PeekAt(1) = '/') or (PeekAt(1) = '*') then
          Continue;
      end;

      // Advance past the operator
      for LJ := 1 to LLen do
        Advance();

      AToken := MakeToken(LEntry.Kind, LEntry.Text, LStartLine, LStartCol);
      Result := True;
      Exit;
    end;
  end;
end;

function TMorLexer.TryIdentifier(var AToken: TMorToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LKind: string;
begin
  Result := False;
  if Current().IsLetter or (Current() = '_') then
  begin
    Result := True;
    LStartLine := FLine;
    LStartCol := FCol;
    LText := '';

    while not AtEnd() and (Current().IsLetterOrDigit or (Current() = '_')) do
    begin
      LText := LText + Current();
      Advance();
    end;

    // Check keyword table for promotion
    if FKeywords.TryGetValue(LText, LKind) then
      AToken := MakeToken(LKind, LText, LStartLine, LStartCol)
    else
      AToken := MakeToken('identifier', LText, LStartLine, LStartCol);
  end;
end;

function TMorLexer.Tokenize(const ASource: string;
  const AFilename: string): TList<TMorToken>;
var
  LToken: TMorToken;
  LStartLine: Integer;
  LStartCol: Integer;
  LSkipped: Boolean;
begin
  FSource := ASource;
  FFilename := AFilename;
  FPos := 1;
  FLine := 1;
  FCol := 1;

  Result := TList<TMorToken>.Create();

  while not AtEnd() do
  begin
    // Check error limit
    if Assigned(FErrors) and FErrors.ReachedMaxErrors() then
      Break;

    // Skip whitespace
    SkipWhitespace();
    if AtEnd() then
      Break;

    // Skip comments
    LSkipped := False;
    if SkipLineComment() then
      LSkipped := True
    else if SkipBlockComment() then
      LSkipped := True;

    if LSkipped then
      Continue;

    // Skip whitespace again after comments
    if Current().IsWhiteSpace then
      Continue;

    // Try triple-quoted string (must check before single quote operator if we add one)
    if TryTripleString(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    // Try string literal
    if TryString(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    // Try number literal
    if TryNumber(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    // Try operator/delimiter (longest match)
    if TryOperator(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    // Try identifier/keyword
    if TryIdentifier(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    // Unexpected character
    LStartLine := FLine;
    LStartCol := FCol;
    if Assigned(FErrors) then
      FErrors.Add(FFilename, LStartLine, LStartCol,
        esError, MOR_ERR_MORLEXER_UNEXPECTED_CHAR,
        RSMorLexerUnexpectedChar, [Current()]);
    Advance();
  end;

  // Add EOF token
  Result.Add(MakeToken('eof', '', FLine, FCol));
end;

end.
