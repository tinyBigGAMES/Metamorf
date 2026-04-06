{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.GenericLexer;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Character,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.AST,
  Metamorf.Interpreter;

const
  // User Lexer Error Codes (UL001-UL099)
  ERR_USERLEXER_UNEXPECTED_CHAR  = 'UL001';
  ERR_USERLEXER_UNTERMINATED_STR = 'UL002';
  ERR_USERLEXER_UNTERMINATED_CMT = 'UL003';
  ERR_USERLEXER_INVALID_NUMBER   = 'UL004';

type

  { TCondEntry - tracks one level of conditional compilation nesting }
  TCondEntry = record
    ParentSkipping: Boolean; // was FSkipping when this level was entered?
    BranchTaken: Boolean;    // did any branch at this level already emit?
  end;

  { TGenericLexer }
  TGenericLexer = class(TErrorsObject)
  private
    FSource: string;
    FFilename: string;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;

    FKeywords: TDictionary<string, string>;
    FOperators: TList<TOperatorEntryInterp>;
    FStringStyles: TList<TStringStyleEntry>;
    FLineComments: TList<string>;
    FBlockComments: TList<TPair<string, string>>;
    FDirectives: TDictionary<string, string>;
    FDirectiveFlags: TDictionary<string, string>;
    FDirectivePrefix: string;
    FConfig: TLexerConfig;

    // Conditional compilation state
    FDefines: TDictionary<string, Boolean>;
    FCondStack: TList<TCondEntry>;
    FSkipping: Boolean;

    function AtEnd(): Boolean;
    function Current(): Char;
    function PeekAt(const AOffset: Integer): Char;
    function Advance(): Char;
    function MakeToken(const AKind: string; const AText: string;
      const ALine: Integer; const ACol: Integer): TToken;

    procedure SkipWhitespace();
    function SkipComment(): Boolean;
    function TryOperator(var AToken: TToken): Boolean;
    function TryStringLiteral(var AToken: TToken): Boolean;
    function TryNumber(var AToken: TToken): Boolean;
    function TryIdentifier(var AToken: TToken): Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Configure(const AInterp: TMorInterpreter);
    function Tokenize(const ASource: string;
      const AFilename: string = ''): TList<TToken>;
  end;

implementation

{ TGenericLexer }

constructor TGenericLexer.Create();
begin
  inherited;
  FKeywords := nil;
  FOperators := nil;
  FStringStyles := nil;
  FLineComments := nil;
  FBlockComments := nil;
  FDirectiveFlags := nil;
  FDefines := TDictionary<string, Boolean>.Create();
  FCondStack := TList<TCondEntry>.Create();
  FSkipping := False;
end;

destructor TGenericLexer.Destroy();
begin
  FreeAndNil(FCondStack);
  FreeAndNil(FDefines);
  // We don't own these - they belong to the interpreter
  inherited;
end;

procedure TGenericLexer.Configure(const AInterp: TMorInterpreter);
begin
  FKeywords := AInterp.GetKeywords();
  FOperators := AInterp.GetOperators();
  FStringStyles := AInterp.GetStringStyles();
  FLineComments := AInterp.GetLineComments();
  FBlockComments := AInterp.GetBlockComments();
  FDirectives := AInterp.GetDirectives();
  FDirectiveFlags := AInterp.GetDirectiveFlags();
  FConfig := AInterp.GetLexerConfig();
  FDirectivePrefix := FConfig.DirectivePrefix;
end;

function TGenericLexer.AtEnd(): Boolean;
begin
  Result := FPos > Length(FSource);
end;

function TGenericLexer.Current(): Char;
begin
  if AtEnd() then
    Result := #0
  else
    Result := FSource[FPos];
end;

function TGenericLexer.PeekAt(const AOffset: Integer): Char;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx < 1) or (LIdx > Length(FSource)) then
    Result := #0
  else
    Result := FSource[LIdx];
end;

function TGenericLexer.Advance(): Char;
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

function TGenericLexer.MakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TToken;
begin
  Result.Kind := AKind;
  Result.Text := AText;
  Result.Filename := FFilename;
  Result.Line := ALine;
  Result.Col := ACol;
end;

procedure TGenericLexer.SkipWhitespace();
begin
  while not AtEnd() and Current().IsWhiteSpace do
    Advance();
end;

function TGenericLexer.SkipComment(): Boolean;
var
  LI: Integer;
  LOpen: string;
  LClose: string;
  LLen: Integer;
  LMatch: Boolean;
  LJ: Integer;
begin
  Result := False;

  // Try line comments
  for LI := 0 to FLineComments.Count - 1 do
  begin
    LOpen := FLineComments[LI];
    LLen := Length(LOpen);
    LMatch := True;
    if FPos + LLen - 1 > Length(FSource) then Continue;
    for LJ := 1 to LLen do
    begin
      if FSource[FPos + LJ - 1] <> LOpen[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;
    if LMatch then
    begin
      while not AtEnd() and (Current() <> #10) do
        Advance();
      Exit(True);
    end;
  end;

  // Try block comments
  for LI := 0 to FBlockComments.Count - 1 do
  begin
    LOpen := FBlockComments[LI].Key;
    LClose := FBlockComments[LI].Value;
    LLen := Length(LOpen);
    LMatch := True;
    if FPos + LLen - 1 > Length(FSource) then Continue;
    for LJ := 1 to LLen do
    begin
      if FSource[FPos + LJ - 1] <> LOpen[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;
    if LMatch then
    begin
      // Skip past the opening
      for LJ := 1 to LLen do Advance();
      // Find closing
      while not AtEnd() do
      begin
        LMatch := True;
        if FPos + Length(LClose) - 1 > Length(FSource) then
        begin
          Advance();
          Continue;
        end;
        for LJ := 1 to Length(LClose) do
        begin
          if FSource[FPos + LJ - 1] <> LClose[LJ] then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if LMatch then
        begin
          for LJ := 1 to Length(LClose) do Advance();
          Exit(True);
        end;
        Advance();
      end;
      // Unterminated
      if Assigned(FErrors) then
        FErrors.Add(FFilename, FLine, FCol,
          esError, ERR_USERLEXER_UNTERMINATED_CMT,
          RSUserLexerUnterminatedComment);
      Exit(True);
    end;
  end;
end;

function TGenericLexer.TryOperator(var AToken: TToken): Boolean;
var
  LI: Integer;
  LEntry: TOperatorEntryInterp;
  LLen: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LMatch: Boolean;
  LJ: Integer;
begin
  Result := False;
  LStartLine := FLine;
  LStartCol := FCol;

  for LI := 0 to FOperators.Count - 1 do
  begin
    LEntry := FOperators[LI];
    LLen := Length(LEntry.Text);
    if FPos + LLen - 1 > Length(FSource) then Continue;

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
      for LJ := 1 to LLen do Advance();
      AToken := MakeToken(LEntry.Kind, LEntry.Text, LStartLine, LStartCol);
      Result := True;
      Exit;
    end;
  end;
end;

function TGenericLexer.TryStringLiteral(var AToken: TToken): Boolean;
var
  LI: Integer;
  LStyle: TStringStyleEntry;
  LOpenLen: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LMatch: Boolean;
  LJ: Integer;
  LNoEscape: Boolean;
begin
  Result := False;

  for LI := 0 to FStringStyles.Count - 1 do
  begin
    LStyle := FStringStyles[LI];
    LOpenLen := Length(LStyle.OpenText);
    if FPos + LOpenLen - 1 > Length(FSource) then Continue;

    LMatch := True;
    for LJ := 1 to LOpenLen do
    begin
      if FSource[FPos + LJ - 1] <> LStyle.OpenText[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;

    if LMatch then
    begin
      LStartLine := FLine;
      LStartCol := FCol;
      LNoEscape := LStyle.Flags.Contains('noescape');

      // Skip opening delimiter
      for LJ := 1 to LOpenLen do Advance();

      // Collect string content until closing delimiter
      LText := '';
      while not AtEnd() do
      begin
        // Check for closing delimiter
        if (LStyle.CloseText <> '') and (Current() = LStyle.CloseText[1]) then
        begin
          if LNoEscape or (LText = '') or (LText[Length(LText)] <> LStyle.CloseText[1]) then
          begin
            Advance();
            AToken := MakeToken(LStyle.Kind, LText, LStartLine, LStartCol);
            Result := True;
            Exit;
          end;
          // Doubled delimiter = literal (e.g., '' in Pascal)
          LText := LText + Current();
          Advance();
        end
        else if (not LNoEscape) and (Current() = '\') then
        begin
          // Escape sequence: preserve the backslash for C++ output
          LText := LText + '\';
          Advance();
          if not AtEnd() then
          begin
            LText := LText + Current();
            Advance();
          end;
        end
        else
        begin
          LText := LText + Current();
          Advance();
        end;
      end;
      // Unterminated string
      if Assigned(FErrors) then
        FErrors.Add(FFilename, LStartLine, LStartCol,
          esError, ERR_USERLEXER_UNTERMINATED_STR,
          RSUserLexerUnterminatedString);
      AToken := MakeToken(LStyle.Kind, LText, LStartLine, LStartCol);
      Result := True;
      Exit;
    end;
  end;
end;

function TGenericLexer.TryNumber(var AToken: TToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LIsFloat: Boolean;
begin
  Result := False;
  if not Current().IsDigit then Exit;

  Result := True;
  LStartLine := FLine;
  LStartCol := FCol;
  LText := '';
  LIsFloat := False;

  while not AtEnd() and Current().IsDigit do
  begin
    LText := LText + Current();
    Advance();
  end;

  // Decimal point
  if not AtEnd() and (Current() = '.') and PeekAt(1).IsDigit then
  begin
    LIsFloat := True;
    LText := LText + Current();
    Advance();
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

function TGenericLexer.TryIdentifier(var AToken: TToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LKind: string;
begin
  Result := False;
  if not (Current().IsLetter or (Current() = '_')) then Exit;

  Result := True;
  LStartLine := FLine;
  LStartCol := FCol;
  LText := '';

  while not AtEnd() and (Current().IsLetterOrDigit or (Current() = '_')) do
  begin
    LText := LText + Current();
    Advance();
  end;

  // Keyword promotion (case-sensitive or insensitive based on config)
  if FConfig.CaseSensitive then
  begin
    if FKeywords.TryGetValue(LText, LKind) then
      AToken := MakeToken(LKind, LText, LStartLine, LStartCol)
    else
      AToken := MakeToken('identifier', LText, LStartLine, LStartCol);
  end
  else
  begin
    if FKeywords.TryGetValue(LowerCase(LText), LKind) then
      AToken := MakeToken(LKind, LText, LStartLine, LStartCol)
    else
      AToken := MakeToken('identifier', LText, LStartLine, LStartCol);
  end;
end;

function TGenericLexer.Tokenize(const ASource: string;
  const AFilename: string): TList<TToken>;
var
  LToken: TToken;
  LFlag: string;
  LSymbol: string;
  LEntry: TCondEntry;
begin
  FSource := ASource;
  FFilename := AFilename;
  FPos := 1;
  FLine := 1;
  FCol := 1;

  // Reset conditional compilation state
  FDefines.Clear();
  FCondStack.Clear();
  FSkipping := False;

  Result := TList<TToken>.Create();

  while not AtEnd() do
  begin
    if Assigned(FErrors) and FErrors.ReachedMaxErrors() then
      Break;

    SkipWhitespace();
    if AtEnd() then Break;

    if SkipComment() then Continue;
    if AtEnd() then Break;
    if Current().IsWhiteSpace then Continue;

    // Try directive FIRST (must be processed even when skipping, for nesting)
    if (FDirectivePrefix <> '') and (Current() = FDirectivePrefix[1]) then
    begin
      LToken.Filename := FFilename;
      LToken.Line := FLine;
      LToken.Col := FCol;
      Advance(); // skip prefix char
      // Read the directive word
      LToken.Text := '';
      while not AtEnd() and (Current().IsLetterOrDigit or (Current() = '_')) do
      begin
        LToken.Text := LToken.Text + Current();
        Advance();
      end;
      if FDirectives.TryGetValue(LToken.Text, LToken.Kind) then
      begin
        // Check if this is a conditional compilation directive
        if Assigned(FDirectiveFlags) and
           FDirectiveFlags.TryGetValue(LToken.Text, LFlag) then
        begin
          // Read symbol name for directives that need one
          if (LFlag = 'define') or (LFlag = 'undef') or
             (LFlag = 'ifdef') or (LFlag = 'ifndef') or
             (LFlag = 'elseif') then
          begin
            // Skip whitespace to the symbol
            while not AtEnd() and Current().IsWhiteSpace and
                  (Current() <> #10) do
              Advance();
            LSymbol := '';
            while not AtEnd() and
                  (Current().IsLetterOrDigit or (Current() = '_')) do
            begin
              LSymbol := LSymbol + Current();
              Advance();
            end;
          end;

          if LFlag = 'define' then
          begin
            if not FSkipping then
              FDefines.AddOrSetValue(LSymbol, True);
          end
          else if LFlag = 'undef' then
          begin
            if not FSkipping then
              FDefines.Remove(LSymbol);
          end
          else if LFlag = 'ifdef' then
          begin
            LEntry.ParentSkipping := FSkipping;
            LEntry.BranchTaken := False;
            if not FSkipping then
            begin
              if FDefines.ContainsKey(LSymbol) then
                LEntry.BranchTaken := True
              else
                FSkipping := True;
            end;
            FCondStack.Add(LEntry);
          end
          else if LFlag = 'ifndef' then
          begin
            LEntry.ParentSkipping := FSkipping;
            LEntry.BranchTaken := False;
            if not FSkipping then
            begin
              if not FDefines.ContainsKey(LSymbol) then
                LEntry.BranchTaken := True
              else
                FSkipping := True;
            end;
            FCondStack.Add(LEntry);
          end
          else if LFlag = 'elseif' then
          begin
            if FCondStack.Count > 0 then
            begin
              LEntry := FCondStack[FCondStack.Count - 1];
              if LEntry.ParentSkipping then
              begin
                // Parent is skipping, stay skipping
                FSkipping := True;
              end
              else if LEntry.BranchTaken then
              begin
                // A branch already ran, skip
                FSkipping := True;
              end
              else if FDefines.ContainsKey(LSymbol) then
              begin
                // This branch is active
                FSkipping := False;
                LEntry.BranchTaken := True;
                FCondStack[FCondStack.Count - 1] := LEntry;
              end
              else
                FSkipping := True;
            end;
          end
          else if LFlag = 'else' then
          begin
            if FCondStack.Count > 0 then
            begin
              LEntry := FCondStack[FCondStack.Count - 1];
              if LEntry.ParentSkipping then
                FSkipping := True
              else if LEntry.BranchTaken then
                FSkipping := True
              else
              begin
                FSkipping := False;
                LEntry.BranchTaken := True;
                FCondStack[FCondStack.Count - 1] := LEntry;
              end;
            end;
          end
          else if LFlag = 'endif' then
          begin
            if FCondStack.Count > 0 then
            begin
              LEntry := FCondStack[FCondStack.Count - 1];
              FSkipping := LEntry.ParentSkipping;
              FCondStack.Delete(FCondStack.Count - 1);
            end;
          end;
          // Conditional directives are consumed, not emitted
          Continue;
        end;

        // Regular directive (non-conditional) -- emit if not skipping
        if not FSkipping then
          Result.Add(LToken);
        Continue;
      end;
      // Not a registered directive -- treat prefix + word as unknown
      if not FSkipping then
      begin
        if Assigned(FErrors) then
          FErrors.Add(FFilename, LToken.Line, LToken.Col,
            esError, ERR_USERLEXER_UNEXPECTED_CHAR,
            RSUserLexerUnexpectedChar, [FDirectivePrefix]);
      end;
      Continue;
    end;

    // When skipping, consume but don't emit non-directive tokens
    if FSkipping then
    begin
      // Skip the current character/token
      Advance();
      Continue;
    end;

    // Try string literal first (before operators, since ' might be both)
    if TryStringLiteral(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    if TryNumber(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    if TryOperator(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    if TryIdentifier(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    // Unexpected character
    if Assigned(FErrors) then
      FErrors.Add(FFilename, FLine, FCol,
        esError, ERR_USERLEXER_UNEXPECTED_CHAR,
        RSUserLexerUnexpectedChar, [Current()]);
    Advance();
  end;

  Result.Add(MakeToken('eof', '', FLine, FCol));
end;

end.
