{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.GenericParser;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.AST,
  Metamorf.Interpreter;

const
  // User Parser Error Codes (UP001-UP099)
  ERR_USERPARSER_EXPECTED_TOKEN  = 'UP001';
  ERR_USERPARSER_NO_PREFIX       = 'UP002';
  ERR_USERPARSER_EXPECTED_IDENT  = 'UP003';
  ERR_USERPARSER_UNEXPECTED_STMT = 'UP004';

type

  { TGenericParser }
  TGenericParser = class(TErrorsObject)
  private
    FTokens: TList<TToken>;
    FPos: Integer;
    FFilename: string;
    FInterp: TMorInterpreter;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Configure(const AInterp: TMorInterpreter);

    // Token navigation (public so interpreter can call them)
    function Current(): TToken;
    function Peek(): TToken;
    function AtEnd(): Boolean;
    function Check(const AKind: string): Boolean;
    function Match(const AKind: string): Boolean;
    procedure DoAdvance();
    procedure Expect(const AKind: string);

    // Position save/restore (for optional backtracking)
    function GetPos(): Integer;
    procedure SetPos(const APos: Integer);

    // Parsing entry points
    function ParseExpression(const AMinPower: Integer): TASTNode;
    function ParseStatement(): TASTNode;
    function ParseProgram(const ATokens: TList<TToken>;
      const AFilename: string = ''): TASTNode;
  end;

implementation

{ TGenericParser }

constructor TGenericParser.Create();
begin
  inherited;
  FTokens := nil;
  FPos := 0;
  FFilename := '';
  FInterp := nil;
end;

destructor TGenericParser.Destroy();
begin
  inherited;
end;

procedure TGenericParser.Configure(const AInterp: TMorInterpreter);
begin
  FInterp := AInterp;
end;

function TGenericParser.Current(): TToken;
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

function TGenericParser.Peek(): TToken;
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

function TGenericParser.AtEnd(): Boolean;
begin
  Result := Current().Kind = 'eof';
end;

function TGenericParser.Check(const AKind: string): Boolean;
begin
  Result := Current().Kind = AKind;
end;

function TGenericParser.Match(const AKind: string): Boolean;
begin
  if Current().Kind = AKind then
  begin
    DoAdvance();
    Result := True;
  end
  else
    Result := False;
end;

procedure TGenericParser.DoAdvance();
begin
  if FPos < FTokens.Count then
    Inc(FPos);
end;

procedure TGenericParser.Expect(const AKind: string);
begin
  if Current().Kind = AKind then
    DoAdvance()
  else if Assigned(FErrors) then
    FErrors.Add(FFilename, Current().Line, Current().Col,
      esError, ERR_USERPARSER_EXPECTED_TOKEN,
      RSUserParserExpectedToken, [AKind, Current().Text]);
end;

function TGenericParser.GetPos(): Integer;
begin
  Result := FPos;
end;

procedure TGenericParser.SetPos(const APos: Integer);
begin
  FPos := APos;
end;

function TGenericParser.ParseExpression(const AMinPower: Integer): TASTNode;
var
  LPrefixRule: TASTNode;
  LInfixEntry: TInfixEntry;
  LNativePrefixHandler: TNativePrefixHandler;
  LNativeInfixEntry: TNativeInfixEntry;
  LLeft: TASTNode;
  LPrefixRules: TDictionary<string, TASTNode>;
  LInfixRules: TDictionary<string, TInfixEntry>;
  LNativePrefixRules: TDictionary<string, TNativePrefixHandler>;
  LNativeInfixRules: TDictionary<string, TNativeInfixEntry>;
  LCurrentKind: string;
  LSavedParser: TObject;
  LSavedPos: Integer;
begin
  LPrefixRules := FInterp.GetPrefixRules();
  LInfixRules := FInterp.GetInfixRules();
  LNativePrefixRules := FInterp.GetNativePrefixRules();
  LNativeInfixRules := FInterp.GetNativeInfixRules();

  // Set active parser so interpreter/native handlers can access us
  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    // Prefix dispatch
    LCurrentKind := Current().Kind;

    // Check native prefix handlers first (C++ passthrough)
    if LNativePrefixRules.TryGetValue(LCurrentKind, LNativePrefixHandler) then
      LLeft := LNativePrefixHandler()
    // Then check interpreted prefix rules
    else if LPrefixRules.TryGetValue(LCurrentKind, LPrefixRule) then
      LLeft := FInterp.ExecuteGrammarRule(LPrefixRule)
    else
    begin
      if Assigned(FErrors) then
        FErrors.Add(FFilename, Current().Line, Current().Col,
          esError, ERR_USERPARSER_NO_PREFIX,
          RSUserParserNoPrefixHandler, [Current().Text]);
      Result := TASTNode.Create();
      Result.SetKind('error');
      DoAdvance();
      Exit;
    end;

    // Infix loop
    while not AtEnd() do
    begin
      LCurrentKind := Current().Kind;

      // Check native infix handlers first
      if LNativeInfixRules.TryGetValue(LCurrentKind, LNativeInfixEntry) then
      begin
        // Power check
        if LNativeInfixEntry.Assoc = 'right' then
        begin
          if LNativeInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LNativeInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        LLeft := LNativeInfixEntry.Handler(LLeft);
        if FPos = LSavedPos then Break; // stuck protection
      end
      // Then check interpreted infix rules
      else if LInfixRules.TryGetValue(LCurrentKind, LInfixEntry) then
      begin
        // Power check
        if LInfixEntry.Assoc = 'right' then
        begin
          if LInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        LLeft := FInterp.ExecuteGrammarRule(LInfixEntry.RuleAST, LLeft);
        if FPos = LSavedPos then Break; // stuck protection
      end
      else
        Break;
    end;

    Result := LLeft;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TGenericParser.ParseStatement(): TASTNode;
var
  LStmtRules: TDictionary<string, TASTNode>;
  LNativeStmtRules: TDictionary<string, TNativeStmtHandler>;
  LStmtRule: TASTNode;
  LNativeStmtHandler: TNativeStmtHandler;
  LCurrentKind: string;
  LSavedParser: TObject;
begin
  LStmtRules := FInterp.GetStmtRules();
  LNativeStmtRules := FInterp.GetNativeStmtRules();
  LCurrentKind := Current().Kind;

  // Set active parser so interpreter/native handlers can access us
  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    // Check native statement handlers first (C++ passthrough)
    if LNativeStmtRules.TryGetValue(LCurrentKind, LNativeStmtHandler) then
      Result := LNativeStmtHandler()
    // Then check interpreted statement rules
    else if LStmtRules.TryGetValue(LCurrentKind, LStmtRule) then
      Result := FInterp.ExecuteGrammarRule(LStmtRule)
    else
    begin
      // Fall through to expression statement
      Result := ParseExpression(0);
    end;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TGenericParser.ParseProgram(const ATokens: TList<TToken>;
  const AFilename: string): TASTNode;
var
  LRoot: TASTNode;
  LSavedPos: Integer;
  LToken: TToken;
begin
  FTokens := ATokens;
  FPos := 0;
  FFilename := AFilename;

  LRoot := TASTNode.Create();
  LRoot.SetKind('program.root');
  LToken.Kind := 'program.root';
  LToken.Text := '';
  LToken.Filename := AFilename;
  LToken.Line := 1;
  LToken.Col := 1;
  LRoot.SetToken(LToken);

  while not AtEnd() do
  begin
    if Assigned(FErrors) and FErrors.ReachedMaxErrors() then
      Break;
    LSavedPos := FPos;
    LRoot.AddChild(ParseStatement());
    // Safety: if no tokens were consumed, skip one to prevent infinite loop
    if FPos = LSavedPos then
    begin
      if Assigned(FErrors) then
        FErrors.Add(FFilename, Current().Line, Current().Col,
          esError, ERR_USERPARSER_UNEXPECTED_STMT,
          'Parser stuck at token: ''%s''', [Current().Text]);
      DoAdvance();
    end;
  end;

  Result := LRoot;
end;

end.
