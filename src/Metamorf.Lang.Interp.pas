{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lang.Interp;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.Classes,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.API,
  Metamorf.Lang.Common;

type

  { EInterpReturn — non-local control flow for return statements }
  EInterpReturn = class(Exception)
  public
    ReturnValue: TValue;
    constructor Create(const AValue: TValue);
  end;

  { EInterpBreak — non-local control flow for break in loops }
  EInterpBreak = class(Exception);

  { EInterpContinue — non-local control flow for continue in loops }
  EInterpContinue = class(Exception);

  { TMetamorfLangInterpreter
    Standalone interpreter that walks a Phase 1 Metamorf AST and
    configures a TMetamorf instance. Dictionary-based dispatch for
    statements, expressions, and built-in functions. }
  TMetamorfLangInterpreter = class(TErrorsObject)
  private type
    TStmtHandler = reference to procedure(const ANode: TASTNode);
    TExprHandler = reference to function(const ANode: TASTNode): TValue;
    TBuiltinFunc = reference to function(const AArgs: TArray<TValue>): TValue;

  private
    // Environment stack — each entry is a scope frame
    FEnvStack: TObjectList<TDictionary<string, TValue>>;

    // Dispatch tables
    FStmtHandlers: TDictionary<string, TStmtHandler>;
    FExprHandlers: TDictionary<string, TExprHandler>;
    FBuiltins:     TDictionary<string, TBuiltinFunc>;
    FRoutines:     TDictionary<string, TASTNode>;
    FFragments:    TDictionary<string, TASTNode>;
    FImportedFiles: TStringList;
    FImportedASTs:  TObjectList<TASTNode>;
    FOnLoadDefinition: TFunc<string, TASTNode>;

    // Context objects — set during callback execution
    FTargetMetamorf:  TMetamorf;
    FParser:     TParserBase;
    FIR:         TIRBase;
    FSemantic:   TSemanticBase;
    FNode:       TASTNodeBase;
    FResultNode: TASTNode;

    // Pipeline callbacks for build bridge
    FPipeline: TMetamorfLangPipelineCallbacks;

    // ExprToString capture mode — when True, DoEmit appends to buffer
    FExprToStringMode: Boolean;
    FExprToStringBuf:  string;

    // Environment stack operations
    procedure PushScope();
    procedure PopScope();
    function  LookupVar(const AName: string; out AValue: TValue): Boolean;
    procedure SetVar(const AName: string; const AValue: TValue);
    procedure DeclareVar(const AName: string; const AValue: TValue);

    // Core evaluator/executor
    function  EvalExpr(const ANode: TASTNode): TValue;
    procedure ExecStmt(const ANode: TASTNode);
    procedure ExecBlock(const ANode: TASTNode);

    // Dispatch table registration
    procedure RegisterStmtHandlers();
    procedure RegisterExprHandlers();
    procedure RegisterBuiltins();

    // ---- Statement handlers ----

    // Control flow
    procedure DoLet(const ANode: TASTNode);
    procedure DoAssign(const ANode: TASTNode);
    procedure DoIf(const ANode: TASTNode);
    procedure DoWhile(const ANode: TASTNode);
    procedure DoFor(const ANode: TASTNode);
    procedure DoReturn(const ANode: TASTNode);
    procedure DoMatch(const ANode: TASTNode);
    procedure DoGuard(const ANode: TASTNode);
    procedure DoExprStmt(const ANode: TASTNode);
    procedure DoTryRecover(const ANode: TASTNode);

    // Domain-specific (context-dependent — populated in later slices)
    procedure DoVisit(const ANode: TASTNode);
    procedure DoEmit(const ANode: TASTNode);
    procedure DoDeclare(const ANode: TASTNode);
    procedure DoLookup(const ANode: TASTNode);
    procedure DoScope(const ANode: TASTNode);
    procedure DoSetAttr(const ANode: TASTNode);
    procedure DoExpect(const ANode: TASTNode);
    procedure DoConsume(const ANode: TASTNode);
    procedure DoParseSub(const ANode: TASTNode);
    procedure DoOptional(const ANode: TASTNode);
    procedure DoDiagnostic(const ANode: TASTNode);
    procedure DoIndent(const ANode: TASTNode);

    // ---- Expression handlers ----
    function EvalLiteralString(const ANode: TASTNode): TValue;
    function EvalLiteralInt(const ANode: TASTNode): TValue;
    function EvalLiteralBool(const ANode: TASTNode): TValue;
    function EvalLiteralNil(const ANode: TASTNode): TValue;
    function EvalIdent(const ANode: TASTNode): TValue;
    function EvalAttrAccess(const ANode: TASTNode): TValue;
    function EvalBinary(const ANode: TASTNode): TValue;
    function EvalUnaryNot(const ANode: TASTNode): TValue;
    function EvalUnaryMinus(const ANode: TASTNode): TValue;
    function EvalCall(const ANode: TASTNode): TValue;
    function EvalIndex(const ANode: TASTNode): TValue;
    function EvalFieldAccess(const ANode: TASTNode): TValue;

    // Top-level walk helpers
    procedure WalkTokensBlock(const ANode: TASTNode);
    procedure WalkGrammarBlock(const ANode: TASTNode);
    procedure WalkSemanticsBlock(const ANode: TASTNode);
    procedure WalkEmittersBlock(const ANode: TASTNode);
    procedure WalkConstBlock(const ANode: TASTNode);
    procedure WalkTypesBlock(const ANode: TASTNode);
    procedure RouteTopLevelNode(const ANode: TASTNode);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Main entry point: walk ARootNode, configure ATargetMetamorf
    function Execute(const ARootNode: TASTNode;
      const ATargetMetamorf: TMetamorf): Boolean;

    // Set pipeline callbacks for build bridge operations
    procedure SetPipeline(const APipeline: TMetamorfLangPipelineCallbacks);

    // Set callback for loading imported .pax definition files
    procedure SetOnLoadDefinition(const AFunc: TFunc<string, TASTNode>);
  end;

implementation

uses
  Metamorf.LangConfig;

// =========================================================================
// TValue HELPERS
// =========================================================================

function ValNil(): TValue;
begin
  Result := TValue.Empty;
end;

function ValInt(const AValue: Int64): TValue;
begin
  Result := TValue.From<Int64>(AValue);
end;

function ValBool(const AValue: Boolean): TValue;
begin
  Result := TValue.From<Boolean>(AValue);
end;

function ValStr(const AValue: string): TValue;
begin
  Result := TValue.From<string>(AValue);
end;

function ValNode(const AValue: TASTNodeBase): TValue;
begin
  Result := TValue.From<TObject>(AValue);
end;

function IsNilVal(const AValue: TValue): Boolean;
begin
  Result := AValue.IsEmpty;
end;

function IsIntVal(const AValue: TValue): Boolean;
begin
  Result := (not AValue.IsEmpty) and AValue.IsType<Int64>();
end;

function IsBoolVal(const AValue: TValue): Boolean;
begin
  Result := (not AValue.IsEmpty) and AValue.IsType<Boolean>();
end;

function IsStrVal(const AValue: TValue): Boolean;
begin
  Result := (not AValue.IsEmpty) and AValue.IsType<string>();
end;

function IsNodeVal(const AValue: TValue): Boolean;
begin
  Result := (not AValue.IsEmpty) and AValue.IsType<TObject>();
end;

function AsInt(const AValue: TValue): Int64;
begin
  if AValue.IsType<Int64>() then
    Result := AValue.AsInt64()
  else if AValue.IsType<Integer>() then
    Result := AValue.AsInteger()
  else
    Result := 0;
end;

function AsBool(const AValue: TValue): Boolean;
begin
  if AValue.IsType<Boolean>() then
    Result := AValue.AsBoolean()
  else
    Result := False;
end;

function AsStr(const AValue: TValue): string;
begin
  if AValue.IsEmpty then
    Result := ''
  else if AValue.IsType<string>() then
    Result := AValue.AsString()
  else
    Result := AValue.ToString();
end;

function AsNode(const AValue: TValue): TASTNodeBase;
begin
  if AValue.IsType<TObject>() then
    Result := TASTNodeBase(AValue.AsObject())
  else
    Result := nil;
end;

function IsTruthy(const AValue: TValue): Boolean;
begin
  if AValue.IsEmpty then
    Result := False
  else if AValue.IsType<Boolean>() then
    Result := AValue.AsBoolean()
  else if AValue.IsType<Int64>() then
    Result := AValue.AsInt64() <> 0
  else if AValue.IsType<Integer>() then
    Result := AValue.AsInteger() <> 0
  else if AValue.IsType<string>() then
    Result := AValue.AsString() <> ''
  else if AValue.IsType<TObject>() then
    Result := AValue.AsObject() <> nil
  else
    Result := True;
end;

// =========================================================================
// EInterpReturn
// =========================================================================

constructor EInterpReturn.Create(const AValue: TValue);
begin
  inherited Create('return');
  ReturnValue := AValue;
end;

// =========================================================================
// TMetamorfLangInterpreter — CONSTRUCTION / DESTRUCTION
// =========================================================================

constructor TMetamorfLangInterpreter.Create();
begin
  inherited;
  FEnvStack     := TObjectList<TDictionary<string, TValue>>.Create(True);
  FStmtHandlers := TDictionary<string, TStmtHandler>.Create();
  FExprHandlers := TDictionary<string, TExprHandler>.Create();
  FBuiltins     := TDictionary<string, TBuiltinFunc>.Create();
  FRoutines     := TDictionary<string, TASTNode>.Create();
  FFragments    := TDictionary<string, TASTNode>.Create();
  FImportedFiles := TStringList.Create();
  FImportedFiles.CaseSensitive := True;
  FImportedASTs  := TObjectList<TASTNode>.Create(False);

  FTargetMetamorf  := nil;
  FParser     := nil;
  FIR         := nil;
  FSemantic   := nil;
  FNode       := nil;
  FResultNode := nil;
  FExprToStringMode := False;
  FExprToStringBuf  := '';

  RegisterStmtHandlers();
  RegisterExprHandlers();
  RegisterBuiltins();
end;

destructor TMetamorfLangInterpreter.Destroy();
begin
  FreeAndNil(FImportedASTs);
  FreeAndNil(FImportedFiles);
  FreeAndNil(FFragments);
  FreeAndNil(FRoutines);
  FreeAndNil(FBuiltins);
  FreeAndNil(FExprHandlers);
  FreeAndNil(FStmtHandlers);
  FreeAndNil(FEnvStack);
  inherited;
end;

// =========================================================================
// ENVIRONMENT STACK
// =========================================================================

procedure TMetamorfLangInterpreter.PushScope();
begin
  FEnvStack.Add(TDictionary<string, TValue>.Create());
end;

procedure TMetamorfLangInterpreter.PopScope();
begin
  if FEnvStack.Count > 0 then
    FEnvStack.Delete(FEnvStack.Count - 1);
end;

function TMetamorfLangInterpreter.LookupVar(const AName: string;
  out AValue: TValue): Boolean;
var
  LI: Integer;
begin
  // Walk the stack top-down
  for LI := FEnvStack.Count - 1 downto 0 do
  begin
    if FEnvStack[LI].TryGetValue(AName, AValue) then
      Exit(True);
  end;
  Result := False;
end;

procedure TMetamorfLangInterpreter.SetVar(const AName: string;
  const AValue: TValue);
var
  LI: Integer;
begin
  // Find existing binding and update it
  for LI := FEnvStack.Count - 1 downto 0 do
  begin
    if FEnvStack[LI].ContainsKey(AName) then
    begin
      FEnvStack[LI].AddOrSetValue(AName, AValue);
      Exit;
    end;
  end;
  // Not found — declare in top scope
  if FEnvStack.Count > 0 then
    FEnvStack[FEnvStack.Count - 1].AddOrSetValue(AName, AValue);
end;

procedure TMetamorfLangInterpreter.DeclareVar(const AName: string;
  const AValue: TValue);
begin
  // Always add to top scope frame
  if FEnvStack.Count > 0 then
    FEnvStack[FEnvStack.Count - 1].AddOrSetValue(AName, AValue);
end;

procedure TMetamorfLangInterpreter.SetPipeline(
  const APipeline: TMetamorfLangPipelineCallbacks);
begin
  FPipeline := APipeline;
end;

procedure TMetamorfLangInterpreter.SetOnLoadDefinition(
  const AFunc: TFunc<string, TASTNode>);
begin
  FOnLoadDefinition := AFunc;
end;

// =========================================================================
// DISPATCH TABLE REGISTRATION
// =========================================================================

procedure TMetamorfLangInterpreter.RegisterStmtHandlers();
begin
  // Control flow
  FStmtHandlers.Add('stmt.let',          DoLet);
  FStmtHandlers.Add('stmt.assign',       DoAssign);
  FStmtHandlers.Add('stmt.if',           DoIf);
  FStmtHandlers.Add('stmt.while',        DoWhile);
  FStmtHandlers.Add('stmt.for',          DoFor);
  FStmtHandlers.Add('stmt.return',       DoReturn);
  FStmtHandlers.Add('stmt.match',        DoMatch);
  FStmtHandlers.Add('stmt.guard',        DoGuard);
  FStmtHandlers.Add('stmt.expr',         DoExprStmt);
  FStmtHandlers.Add('stmt.try_recover',  DoTryRecover);

  // Domain-specific
  FStmtHandlers.Add('stmt.visit',        DoVisit);
  FStmtHandlers.Add('stmt.emit_to',      DoEmit);
  FStmtHandlers.Add('stmt.declare',      DoDeclare);
  FStmtHandlers.Add('stmt.lookup',       DoLookup);
  FStmtHandlers.Add('stmt.scope',        DoScope);
  FStmtHandlers.Add('stmt.set_attr',     DoSetAttr);
  FStmtHandlers.Add('stmt.expect',       DoExpect);
  FStmtHandlers.Add('stmt.consume',      DoConsume);
  FStmtHandlers.Add('stmt.parse_sub',    DoParseSub);
  FStmtHandlers.Add('stmt.optional',     DoOptional);
  FStmtHandlers.Add('stmt.diagnostic',   DoDiagnostic);
  FStmtHandlers.Add('stmt.indent',       DoIndent);
end;

procedure TMetamorfLangInterpreter.RegisterExprHandlers();
begin
  FExprHandlers.Add('expr.literal_string', EvalLiteralString);
  FExprHandlers.Add('expr.literal_int',    EvalLiteralInt);
  FExprHandlers.Add('expr.literal_bool',   EvalLiteralBool);
  FExprHandlers.Add('expr.literal_nil',    EvalLiteralNil);
  FExprHandlers.Add('expr.ident',          EvalIdent);
  FExprHandlers.Add('expr.attr_access',    EvalAttrAccess);
  FExprHandlers.Add('expr.binary',         EvalBinary);
  FExprHandlers.Add('expr.unary_not',      EvalUnaryNot);
  FExprHandlers.Add('expr.unary_minus',    EvalUnaryMinus);
  FExprHandlers.Add('expr.call',           EvalCall);
  FExprHandlers.Add('expr.index',          EvalIndex);
  FExprHandlers.Add('expr.field_access',   EvalFieldAccess);
  FExprHandlers.Add('expr.group',          EvalCall); // group delegates via child
end;

procedure TMetamorfLangInterpreter.RegisterBuiltins();
begin
  // ---- String operations ----

  FBuiltins.Add('concat',
    function(const AArgs: TArray<TValue>): TValue
    var
      LResult: string;
      LI: Integer;
    begin
      LResult := '';
      for LI := 0 to Length(AArgs) - 1 do
        LResult := LResult + AsStr(AArgs[LI]);
      Result := ValStr(LResult);
    end);

  FBuiltins.Add('upper',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) > 0 then
        Result := ValStr(UpperCase(AsStr(AArgs[0])))
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('lower',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) > 0 then
        Result := ValStr(LowerCase(AsStr(AArgs[0])))
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('trim',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) > 0 then
        Result := ValStr(Trim(AsStr(AArgs[0])))
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('replace',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) >= 3 then
        Result := ValStr(StringReplace(AsStr(AArgs[0]),
          AsStr(AArgs[1]), AsStr(AArgs[2]), [rfReplaceAll]))
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('starts_with',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) >= 2 then
        Result := ValBool(AsStr(AArgs[0]).StartsWith(AsStr(AArgs[1])))
      else
        Result := ValBool(False);
    end);

  FBuiltins.Add('ends_with',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) >= 2 then
        Result := ValBool(AsStr(AArgs[0]).EndsWith(AsStr(AArgs[1])))
      else
        Result := ValBool(False);
    end);

  FBuiltins.Add('contains',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) >= 2 then
        Result := ValBool(AsStr(AArgs[0]).Contains(AsStr(AArgs[1])))
      else
        Result := ValBool(False);
    end);

  FBuiltins.Add('length',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) > 0 then
        Result := ValInt(Length(AsStr(AArgs[0])))
      else
        Result := ValInt(0);
    end);

  FBuiltins.Add('to_int',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) > 0 then
        Result := ValInt(StrToInt64Def(AsStr(AArgs[0]), 0))
      else
        Result := ValInt(0);
    end);

  FBuiltins.Add('to_string',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) > 0 then
        Result := ValStr(AsStr(AArgs[0]))
      else
        Result := ValStr('');
    end);

  // ---- Node/tree operations ----

  FBuiltins.Add('child_count',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
    begin
      // child_count() — count on FNode; child_count(n) — count on arg
      if (Length(AArgs) > 0) and IsNodeVal(AArgs[0]) then
        LNode := AsNode(AArgs[0])
      else
        LNode := Self.FNode;
      if LNode <> nil then
        Result := ValInt(LNode.ChildCount())
      else
        Result := ValInt(0);
    end);

  FBuiltins.Add('childCount',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
    begin
      // alias for child_count — pascal.pax uses both forms
      if (Length(AArgs) > 0) and IsNodeVal(AArgs[0]) then
        LNode := AsNode(AArgs[0])
      else
        LNode := Self.FNode;
      if LNode <> nil then
        Result := ValInt(LNode.ChildCount())
      else
        Result := ValInt(0);
    end);

  FBuiltins.Add('getChild',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
      LIdx:  Integer;
    begin
      Result := TValue.Empty;
      if Length(AArgs) >= 2 then
      begin
        // getChild(node, index)
        LNode := AsNode(AArgs[0]);
        LIdx  := Integer(AsInt(AArgs[1]));
        if (LNode <> nil) and (LIdx >= 0) and
           (LIdx < LNode.ChildCount()) then
          Result := ValNode(LNode.GetChild(LIdx));
      end
      else if Length(AArgs) = 1 then
      begin
        // getChild(index) — from FNode
        LIdx := Integer(AsInt(AArgs[0]));
        if (Self.FNode <> nil) and (LIdx >= 0) and
           (LIdx < Self.FNode.ChildCount()) then
          Result := ValNode(Self.FNode.GetChild(LIdx));
      end;
    end);

  FBuiltins.Add('nodeKind',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
    begin
      if (Length(AArgs) > 0) and IsNodeVal(AArgs[0]) then
        LNode := AsNode(AArgs[0])
      else
        LNode := Self.FNode;
      if LNode <> nil then
        Result := ValStr(LNode.GetNodeKind())
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('get_node_kind',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
    begin
      // alias
      if (Length(AArgs) > 0) and IsNodeVal(AArgs[0]) then
        LNode := AsNode(AArgs[0])
      else
        LNode := Self.FNode;
      if LNode <> nil then
        Result := ValStr(LNode.GetNodeKind())
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('getAttr',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
      LKey:  string;
    begin
      Result := TValue.Empty;
      if Length(AArgs) >= 2 then
      begin
        // getAttr(node, key)
        LNode := AsNode(AArgs[0]);
        LKey  := AsStr(AArgs[1]);
        if LNode <> nil then
          LNode.GetAttr(LKey, Result);
      end
      else if Length(AArgs) = 1 then
      begin
        // getAttr(key) — from FNode
        LKey := AsStr(AArgs[0]);
        if Self.FNode <> nil then
          Self.FNode.GetAttr(LKey, Result);
      end;
    end);

  FBuiltins.Add('has_attr',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
      LKey:  string;
      LDummy: TValue;
    begin
      Result := ValBool(False);
      if Length(AArgs) >= 2 then
      begin
        LNode := AsNode(AArgs[0]);
        LKey  := AsStr(AArgs[1]);
        if LNode <> nil then
          Result := ValBool(LNode.GetAttr(LKey, LDummy));
      end
      else if Length(AArgs) = 1 then
      begin
        LKey := AsStr(AArgs[0]);
        if Self.FNode <> nil then
          Result := ValBool(Self.FNode.GetAttr(LKey, LDummy));
      end;
    end);

  FBuiltins.Add('setAttr',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNode;
    begin
      Result := TValue.Empty;
      if Length(AArgs) >= 3 then
      begin
        // setAttr(node, key, value)
        if IsNodeVal(AArgs[0]) then
        begin
          LNode := TASTNode(AsNode(AArgs[0]));
          if LNode <> nil then
            LNode.SetAttr(AsStr(AArgs[1]), AArgs[2]);
        end;
      end
      else if Length(AArgs) = 2 then
      begin
        // setAttr(key, value) — on FNode
        if Self.FNode <> nil then
          (Self.FNode as TASTNode).SetAttr(AsStr(AArgs[0]), AArgs[1]);
      end;
    end);

  FBuiltins.Add('addChild',
    function(const AArgs: TArray<TValue>): TValue
    var
      LParent: TASTNode;
      LChild:  TASTNode;
    begin
      Result := TValue.Empty;
      if Length(AArgs) >= 2 then
      begin
        // addChild(parent, child)
        if IsNodeVal(AArgs[0]) and IsNodeVal(AArgs[1]) then
        begin
          LParent := TASTNode(AsNode(AArgs[0]));
          LChild  := TASTNode(AsNode(AArgs[1]));
          if (LParent <> nil) and (LChild <> nil) then
            LParent.AddChild(LChild);
        end;
      end;
    end);

  FBuiltins.Add('createNode',
    function(const AArgs: TArray<TValue>): TValue
    var
      LKind: string;
      LTok:  TToken;
    begin
      if Length(AArgs) > 0 then
        LKind := AsStr(AArgs[0])
      else
        LKind := 'unknown';
      FillChar(LTok, SizeOf(LTok), 0);
      Result := ValNode(TASTNode.CreateNode(LKind, LTok));
    end);

  FBuiltins.Add('getResultNode',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FResultNode <> nil then
        Result := ValNode(Self.FResultNode)
      else
        Result := TValue.Empty;
    end);

  // ---- Parse-context builtins ----

  FBuiltins.Add('checkToken',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FParser <> nil) and (Length(AArgs) > 0) then
        Result := ValBool(Self.FParser.Check(AsStr(AArgs[0])))
      else
        Result := ValBool(False);
    end);

  FBuiltins.Add('matchToken',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FParser <> nil) and (Length(AArgs) > 0) then
        Result := ValBool(Self.FParser.Match(AsStr(AArgs[0])))
      else
        Result := ValBool(False);
    end);

  FBuiltins.Add('advance',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FParser <> nil then
        Self.FParser.Consume();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('requireToken',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FParser <> nil) and (Length(AArgs) > 0) then
        Self.FParser.Expect(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('currentText',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FParser <> nil then
        Result := ValStr(Self.FParser.CurrentToken().Text)
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('currentKind',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FParser <> nil then
        Result := ValStr(Self.FParser.CurrentToken().Kind)
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('peekKind',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FParser <> nil then
        Result := ValStr(Self.FParser.PeekToken(1).Kind)
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('parseExpr',
    function(const AArgs: TArray<TValue>): TValue
    var
      LPower: Integer;
    begin
      Result := TValue.Empty;
      if Self.FParser = nil then
        Exit;
      if Length(AArgs) > 0 then
        LPower := Integer(AsInt(AArgs[0]))
      else
        LPower := 0;
      Result := ValNode(Self.FParser.ParseExpression(LPower));
    end);

  FBuiltins.Add('parseStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FParser <> nil then
        Result := ValNode(Self.FParser.ParseStatement())
      else
        Result := TValue.Empty;
    end);

  FBuiltins.Add('collectRaw',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FParser <> nil then
        Result := ValStr(Self.FParser.CollectRawTokens())
      else
        Result := ValStr('');
    end);

  // ---- IR / emitter builtins ----

  FBuiltins.Add('func',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 2) then
        Self.FIR.Func(AsStr(AArgs[0]), AsStr(AArgs[1]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('param',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 2) then
        Self.FIR.Param(AsStr(AArgs[0]), AsStr(AArgs[1]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('endFunc',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.EndFunc();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('declVar',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
      begin
        if Length(AArgs) >= 3 then
          Self.FIR.DeclVar(AsStr(AArgs[0]), AsStr(AArgs[1]),
            AsStr(AArgs[2]))
        else if Length(AArgs) >= 2 then
          Self.FIR.DeclVar(AsStr(AArgs[0]), AsStr(AArgs[1]));
      end;
      Result := TValue.Empty;
    end);

  FBuiltins.Add('assign',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 2) then
        Self.FIR.Assign(AsStr(AArgs[0]), AsStr(AArgs[1]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('stmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Self.FIR.Stmt(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('ifStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Self.FIR.IfStmt(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('elseIfStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Self.FIR.ElseIfStmt(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('elseStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.ElseStmt();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('endIf',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.EndIf();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('whileStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Self.FIR.WhileStmt(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('endWhile',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.EndWhile();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('forStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 4) then
        Self.FIR.ForStmt(AsStr(AArgs[0]), AsStr(AArgs[1]),
          AsStr(AArgs[2]), AsStr(AArgs[3]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('endFor',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.EndFor();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('returnVal',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Self.FIR.Return(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('returnVoid',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.Return();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('breakStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.BreakStmt();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('continueStmt',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.ContinueStmt();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('blankLine',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.BlankLine();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('emitInclude',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Self.FIR.Include(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('emitLine',
    function(const AArgs: TArray<TValue>): TValue
    var
      LTarget: TSourceFile;
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
      begin
        LTarget := sfSource;
        if (Length(AArgs) >= 2) and (AsStr(AArgs[1]) = 'header') then
          LTarget := sfHeader;
        Self.FIR.EmitLine(AsStr(AArgs[0]), LTarget);
      end;
      Result := TValue.Empty;
    end);

  FBuiltins.Add('indentIn',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.IndentIn();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('indentOut',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Self.FIR.IndentOut();
      Result := TValue.Empty;
    end);

  FBuiltins.Add('emitNode',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
    begin
      Result := TValue.Empty;
      if Self.FIR = nil then
        Exit;
      if (Length(AArgs) > 0) and IsNodeVal(AArgs[0]) then
      begin
        LNode := AsNode(AArgs[0]);
        if LNode <> nil then
          Self.FIR.EmitNode(LNode);
      end;
    end);

  FBuiltins.Add('emitChildren',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode: TASTNodeBase;
    begin
      Result := TValue.Empty;
      if Self.FIR = nil then
        Exit;
      if (Length(AArgs) > 0) and IsNodeVal(AArgs[0]) then
      begin
        LNode := AsNode(AArgs[0]);
        if LNode <> nil then
          Self.FIR.EmitChildren(LNode);
      end;
    end);

  FBuiltins.Add('invoke',
    function(const AArgs: TArray<TValue>): TValue
    var
      LFuncName: string;
      LIRArgs:   TArray<string>;
      LI:        Integer;
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
      begin
        LFuncName := AsStr(AArgs[0]);
        SetLength(LIRArgs, Length(AArgs) - 1);
        for LI := 1 to Length(AArgs) - 1 do
          LIRArgs[LI - 1] := AsStr(AArgs[LI]);
        Result := ValStr(Self.FIR.Invoke(LFuncName, LIRArgs));
      end
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('get',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Result := ValStr(Self.FIR.Get(AsStr(AArgs[0])))
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('neg',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FIR <> nil) and (Length(AArgs) >= 1) then
        Result := ValStr(Self.FIR.Neg(AsStr(AArgs[0])))
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('nullLit',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if Self.FIR <> nil then
        Result := ValStr(Self.FIR.Null())
      else
        Result := ValStr('');
    end);

  FBuiltins.Add('exprToString',
    function(const AArgs: TArray<TValue>): TValue
    var
      LNode:      TASTNodeBase;
      LKind:      string;
      LHandler:   TEmitHandler;
      LSavedMode: Boolean;
      LSavedBuf:  string;
      LSavedNode: TASTNodeBase;
      LOpVal:     TValue;
    begin
      Result := ValStr('');
      if (Length(AArgs) < 1) or not IsNodeVal(AArgs[0]) then
        Exit;
      LNode := AsNode(AArgs[0]);
      if LNode = nil then
        Exit;

      LKind := LNode.GetNodeKind();

      // Try registered emitter handler in string-capture mode first
      if (Self.FTargetMetamorf <> nil) and
         Self.FTargetMetamorf.Config().GetEmitHandler(LKind, LHandler) then
      begin
        LSavedMode := Self.FExprToStringMode;
        LSavedBuf  := Self.FExprToStringBuf;
        LSavedNode := Self.FNode;
        Self.FExprToStringMode := True;
        Self.FExprToStringBuf  := '';
        Self.FNode := LNode;
        try
          LHandler(LNode, Self.FIR);
        finally
          Result := ValStr(Self.FExprToStringBuf);
          Self.FExprToStringMode := LSavedMode;
          Self.FExprToStringBuf  := LSavedBuf;
          Self.FNode := LSavedNode;
        end;
        Exit;
      end;

      // Fall back: generic binary op (node with @operator and 2 children)
      if LNode.ChildCount() = 2 then
      begin
        LOpVal := TValue.Empty;
        if LNode.GetAttr('operator', LOpVal) then
        begin
          Result := ValStr(
            AsStr(Self.FBuiltins['exprToString'](
              TArray<TValue>.Create(ValNode(LNode.GetChild(0))))) +
            ' ' + AsStr(LOpVal) + ' ' +
            AsStr(Self.FBuiltins['exprToString'](
              TArray<TValue>.Create(ValNode(LNode.GetChild(1))))));
          Exit;
        end;
      end;

      // Fall back to TLangConfig.ExprToString for default node kinds
      if Self.FTargetMetamorf <> nil then
        Result := ValStr(
          Self.FTargetMetamorf.Config().ExprToString(LNode));
    end);

  FBuiltins.Add('typeTextToKind',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FTargetMetamorf <> nil) and (Length(AArgs) >= 1) then
        Result := ValStr(
          Self.FTargetMetamorf.Config().TypeTextToKind(AsStr(AArgs[0])))
      else
        Result := ValStr('type.unknown');
    end);

  FBuiltins.Add('typeToIR',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Self.FTargetMetamorf <> nil) and (Length(AArgs) >= 1) then
        Result := ValStr(
          Self.FTargetMetamorf.Config().TypeToIR(AsStr(AArgs[0])))
      else
        Result := ValStr('');
    end);

  // ---- Build bridge builtins ----

  FBuiltins.Add('setPlatform',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetPlatform) then
        Self.FPipeline.OnSetPlatform(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setBuildMode',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetBuildMode) then
        Self.FPipeline.OnSetBuildMode(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setOptimize',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetOptimize) then
        Self.FPipeline.OnSetOptimize(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setSubsystem',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetSubsystem) then
        Self.FPipeline.OnSetSubsystem(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('addSourceFile',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnAddSourceFile) then
        Self.FPipeline.OnAddSourceFile(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('addIncludePath',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnAddIncludePath) then
        Self.FPipeline.OnAddIncludePath(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('addLibraryPath',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnAddLibraryPath) then
        Self.FPipeline.OnAddLibraryPath(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('addLinkLibrary',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnAddLinkLibrary) then
        Self.FPipeline.OnAddLinkLibrary(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('addCopyDLL',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnAddCopyDLL) then
        Self.FPipeline.OnAddCopyDLL(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setModuleExtension',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetModuleExtension) then
        Self.FPipeline.OnSetModuleExtension(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setExeIcon',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIExeIcon) then
        Self.FPipeline.OnSetVIExeIcon(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setVersionMajor',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIMajor) then
        Self.FPipeline.OnSetVIMajor(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setVersionMinor',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIMinor) then
        Self.FPipeline.OnSetVIMinor(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setVersionPatch',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIPatch) then
        Self.FPipeline.OnSetVIPatch(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setProductName',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIProductName) then
        Self.FPipeline.OnSetVIProductName(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setDescription',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIDescription) then
        Self.FPipeline.OnSetVIDescription(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setFilename',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIFilename) then
        Self.FPipeline.OnSetVIFilename(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setCompanyName',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVICompanyName) then
        Self.FPipeline.OnSetVICompanyName(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setCopyright',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVICopyright) then
        Self.FPipeline.OnSetVICopyright(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('setAddVerInfo',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and Assigned(Self.FPipeline.OnSetVIEnabled) then
        Self.FPipeline.OnSetVIEnabled(AsStr(AArgs[0]));
      Result := TValue.Empty;
    end);

  FBuiltins.Add('symbolExistsWithPrefix',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and (Self.FSemantic <> nil) then
        Result := TValue.From<Boolean>(
          Self.FSemantic.SymbolExistsWithPrefix(AsStr(AArgs[0])))
      else
        Result := TValue.From<Boolean>(False);
    end);

  FBuiltins.Add('demoteCLinkageForPrefix',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and (Self.FSemantic <> nil) then
        Result := TValue.From<Integer>(
          Self.FSemantic.DemoteCLinkageForPrefix(AsStr(AArgs[0])))
      else
        Result := TValue.From<Integer>(0);
    end);

  FBuiltins.Add('compileModule',
    function(const AArgs: TArray<TValue>): TValue
    begin
      if (Length(AArgs) > 0) and (Self.FSemantic <> nil) then
        Result := TValue.From<Boolean>(
          Self.FSemantic.CompileModule(AsStr(AArgs[0])))
      else
        Result := TValue.From<Boolean>(True);
    end);
end;

// =========================================================================
// CORE EVALUATOR / EXECUTOR
// =========================================================================

function TMetamorfLangInterpreter.EvalExpr(const ANode: TASTNode): TValue;
var
  LKind:    string;
  LHandler: TExprHandler;
begin
  Result := TValue.Empty;
  if ANode = nil then
    Exit;

  LKind := ANode.GetNodeKind();
  if FExprHandlers.TryGetValue(LKind, LHandler) then
    Result := LHandler(ANode)
  else
  begin
    if FErrors <> nil then
      FErrors.Add(esError, 'I100',
        'Unknown expression kind: %s', [LKind]);
  end;
end;

procedure TMetamorfLangInterpreter.ExecStmt(const ANode: TASTNode);
var
  LKind:    string;
  LHandler: TStmtHandler;
begin
  if ANode = nil then
    Exit;

  LKind := ANode.GetNodeKind();

  // stmt.ident_stmt from the grammar is parsed as either stmt.assign
  // or stmt.expr — both are already registered. But handle it as
  // a fallback if it arrives directly.
  if LKind = 'stmt.ident_stmt' then
    LKind := 'stmt.expr';

  if FStmtHandlers.TryGetValue(LKind, LHandler) then
    LHandler(ANode)
  else
  begin
    if FErrors <> nil then
      FErrors.Add(esError, 'I101',
        'Unknown statement kind: %s', [ANode.GetNodeKind()]);
  end;
end;

procedure TMetamorfLangInterpreter.ExecBlock(const ANode: TASTNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  for LI := 0 to ANode.ChildCount() - 1 do
    ExecStmt(ANode.GetChildNode(LI));
end;

// =========================================================================
// STATEMENT HANDLERS — CONTROL FLOW
// =========================================================================

procedure TMetamorfLangInterpreter.DoLet(const ANode: TASTNode);
var
  LName: TValue;
  LVal:  TValue;
begin
  // stmt.let: attr 'name', child[0] = initializer expr
  if not ANode.GetAttr('name', LName) then
    Exit;
  if ANode.ChildCount() > 0 then
    LVal := EvalExpr(ANode.GetChildNode(0))
  else
    LVal := TValue.Empty;
  DeclareVar(LName.AsString(), LVal);
end;

procedure TMetamorfLangInterpreter.DoAssign(const ANode: TASTNode);
var
  LTarget: TASTNode;
  LVal:    TValue;
  LName:   TValue;
begin
  // stmt.assign: child[0] = lhs expr, child[1] = rhs expr
  if ANode.ChildCount() < 2 then
    Exit;

  LTarget := ANode.GetChildNode(0);
  LVal    := EvalExpr(ANode.GetChildNode(1));

  if LTarget.GetNodeKind() = 'expr.ident' then
  begin
    LTarget.GetAttr('name', LName);
    SetVar(LName.AsString(), LVal);
  end
  else if LTarget.GetNodeKind() = 'expr.attr_access' then
  begin
    // Set attribute on current node: @attr = value
    LTarget.GetAttr('name', LName);
    if FNode <> nil then
      (FNode as TASTNode).SetAttr(LName.AsString(), LVal)
    else if FResultNode <> nil then
      FResultNode.SetAttr(LName.AsString(), LVal);
  end;
end;

procedure TMetamorfLangInterpreter.DoIf(const ANode: TASTNode);
var
  LCondNode: TASTNode;
  LCondExpr: TASTNode;
  LCond:     TValue;
  LI:        Integer;
  LChild:    TASTNode;
  LIsElse:   TValue;
begin
  // stmt.if: child[0] = meta.condition, child[1] = then block,
  // child[2+] = else-if chain or else block
  if ANode.ChildCount() < 2 then
    Exit;

  // Evaluate condition — child[0] is meta.condition wrapper
  LCondNode := ANode.GetChildNode(0);
  if LCondNode.GetNodeKind() = 'meta.condition' then
    LCondExpr := LCondNode.GetChildNode(0)
  else
    LCondExpr := LCondNode;

  LCond := EvalExpr(LCondExpr);

  if IsTruthy(LCond) then
  begin
    ExecBlock(ANode.GetChildNode(1));
    Exit;
  end;

  // Check for else-if / else branches (child[2+])
  for LI := 2 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChildNode(LI);
    if LChild.GetNodeKind() = 'stmt.if' then
    begin
      // Else-if: recurse
      DoIf(LChild);
      Exit;
    end
    else if LChild.GetNodeKind() = 'meta.block' then
    begin
      // Could be else block (has is_else attr) or just a block
      if LChild.GetAttr('is_else', LIsElse) and
         LIsElse.IsType<Boolean>() and LIsElse.AsBoolean() then
      begin
        ExecBlock(LChild);
        Exit;
      end;
    end;
  end;
end;

procedure TMetamorfLangInterpreter.DoWhile(const ANode: TASTNode);
var
  LCond: TValue;
  LMax:  Integer;
begin
  // stmt.while: child[0] = condition expr, child[1] = body block
  if ANode.ChildCount() < 2 then
    Exit;

  LMax := 100000; // infinite loop guard
  while LMax > 0 do
  begin
    Dec(LMax);
    LCond := EvalExpr(ANode.GetChildNode(0));
    if not IsTruthy(LCond) then
      Break;
    try
      ExecBlock(ANode.GetChildNode(1));
    except
      on EInterpBreak do
        Break;
      on EInterpContinue do
        Continue;
    end;
  end;
end;

procedure TMetamorfLangInterpreter.DoFor(const ANode: TASTNode);
var
  LVarName:  TValue;
  LIterable: TValue;
  LNodeRef:  TASTNodeBase;
  LI:        Integer;
  LMax:      Integer;
begin
  // stmt.for: attr 'var_name', child[0] = iterable, child[1] = body
  if ANode.ChildCount() < 2 then
    Exit;
  if not ANode.GetAttr('var_name', LVarName) then
    Exit;

  LIterable := EvalExpr(ANode.GetChildNode(0));

  // If iterable is a node, iterate over its children
  if IsNodeVal(LIterable) then
  begin
    LNodeRef := AsNode(LIterable);
    if LNodeRef = nil then
      Exit;
    LMax := LNodeRef.ChildCount();
    for LI := 0 to LMax - 1 do
    begin
      PushScope();
      try
        DeclareVar(LVarName.AsString(),
          ValNode(LNodeRef.GetChild(LI)));
        try
          ExecBlock(ANode.GetChildNode(1));

        except
          on EInterpBreak do
          begin
            PopScope();
            Exit;
          end;
          on EInterpContinue do
            ; // continue to next iteration
        end;
      finally
        PopScope();
      end;
    end;
  end;
end;

procedure TMetamorfLangInterpreter.DoReturn(const ANode: TASTNode);
var
  LVal: TValue;
begin
  // stmt.return: optional child[0] = return value expr
  if ANode.ChildCount() > 0 then
    LVal := EvalExpr(ANode.GetChildNode(0))
  else
    LVal := TValue.Empty;
  raise EInterpReturn.Create(LVal);
end;

procedure TMetamorfLangInterpreter.DoMatch(const ANode: TASTNode);
var
  LSubject:   TValue;
  LI:         Integer;
  LArm:       TASTNode;
  LIsDefault: TValue;
  LPattern:   TValue;
  LJ:         Integer;
  LMatched:   Boolean;
  LBodyIdx:   Integer;
begin
  // stmt.match: child[0] = subject, child[1+] = match arms
  if ANode.ChildCount() < 2 then
    Exit;

  LSubject := EvalExpr(ANode.GetChildNode(0));

  for LI := 1 to ANode.ChildCount() - 1 do
  begin
    LArm := ANode.GetChildNode(LI);
    if LArm.GetNodeKind() <> 'stmt.match_arm' then
      Continue;

    // Check for default arm
    if LArm.GetAttr('is_default', LIsDefault) and
       LIsDefault.IsType<Boolean>() and LIsDefault.AsBoolean() then
    begin
      // Body is last child
      if LArm.ChildCount() > 0 then
        ExecBlock(LArm.GetChildNode(LArm.ChildCount() - 1));
      Exit;
    end;

    // Pattern children are before the body block (last child)
    LBodyIdx := LArm.ChildCount() - 1;
    LMatched := False;
    for LJ := 0 to LBodyIdx - 1 do
    begin
      LPattern := EvalExpr(LArm.GetChildNode(LJ));
      // Compare as strings for simplicity
      if AsStr(LSubject) = AsStr(LPattern) then
      begin
        LMatched := True;
        Break;
      end;
    end;

    if LMatched then
    begin
      ExecBlock(LArm.GetChildNode(LBodyIdx));
      Exit;
    end;
  end;
end;

procedure TMetamorfLangInterpreter.DoGuard(const ANode: TASTNode);
var
  LCond: TValue;
begin
  // stmt.guard: child[0] = condition, child[1] = fail body
  if ANode.ChildCount() < 2 then
    Exit;
  LCond := EvalExpr(ANode.GetChildNode(0));
  if not IsTruthy(LCond) then
    ExecBlock(ANode.GetChildNode(1));
end;

procedure TMetamorfLangInterpreter.DoExprStmt(const ANode: TASTNode);
begin
  // stmt.expr: child[0] = expression (typically a function call)
  if ANode.ChildCount() > 0 then
    EvalExpr(ANode.GetChildNode(0));
end;

procedure TMetamorfLangInterpreter.DoTryRecover(const ANode: TASTNode);
begin
  // stmt.try_recover: child[0] = try block, child[1] = recover block
  if ANode.ChildCount() < 2 then
    Exit;
  try
    ExecBlock(ANode.GetChildNode(0));
  except
    on E: Exception do
    begin
      if (E is EInterpReturn) or (E is EInterpBreak) or
         (E is EInterpContinue) then
        raise;
      // Swallow other exceptions, run recovery
      ExecBlock(ANode.GetChildNode(1));
    end;
  end;
end;

// =========================================================================
// STATEMENT HANDLERS — DOMAIN-SPECIFIC
// =========================================================================

procedure TMetamorfLangInterpreter.DoVisit(const ANode: TASTNode);
var
  LTarget: TValue;
  LTgtStr: string;
  LIdx:    TValue;
  LNode:   TASTNodeBase;
begin
  // stmt.visit: attr 'target' = children|child|attr|expr
  // child[0] = optional index/expression
  if not ANode.GetAttr('target', LTarget) then
    Exit;
  LTgtStr := LTarget.AsString();

  if LTgtStr = 'children' then
  begin
    // visit children — recurse into all children of FNode
    if (FSemantic <> nil) and (FNode <> nil) then
      FSemantic.VisitChildren(FNode);
  end
  else if LTgtStr = 'child' then
  begin
    // visit child[index]
    if (FSemantic <> nil) and (FNode <> nil) and
       (ANode.ChildCount() > 0) then
    begin
      LIdx  := EvalExpr(ANode.GetChildNode(0));
      LNode := FNode.GetChild(Integer(AsInt(LIdx)));
      if LNode <> nil then
        FSemantic.VisitNode(LNode);
    end;
  end
  else if (LTgtStr = 'expr') or (LTgtStr = 'attr') then
  begin
    // visit expression — evaluate to get a node, then visit it
    if (FSemantic <> nil) and (ANode.ChildCount() > 0) then
    begin
      LIdx  := EvalExpr(ANode.GetChildNode(0));
      LNode := AsNode(LIdx);
      if LNode <> nil then
        FSemantic.VisitNode(LNode);
    end;
  end;
end;

procedure TMetamorfLangInterpreter.DoEmit(const ANode: TASTNode);
var
  LVal: TValue;
begin
  // stmt.emit_to: optional attr 'section', child[0] = expression
  if ANode.ChildCount() < 1 then
    Exit;
  LVal := EvalExpr(ANode.GetChildNode(0));

  // In capture mode, append to buffer instead of writing to IR
  if FExprToStringMode then
  begin
    FExprToStringBuf := FExprToStringBuf + AsStr(LVal);
    Exit;
  end;

  if FIR <> nil then
    FIR.EmitLine(AsStr(LVal));
end;

procedure TMetamorfLangInterpreter.DoDeclare(const ANode: TASTNode);
var
  LNameExpr: TValue;
  LNameStr:  string;
begin
  // stmt.declare: child[0] = name expr (typically @attr), attr 'symbol_kind'
  if (FSemantic = nil) or (ANode.ChildCount() < 1) then
    Exit;
  LNameExpr := EvalExpr(ANode.GetChildNode(0));
  LNameStr  := AsStr(LNameExpr);
  if (LNameStr <> '') and (FNode <> nil) then
    FSemantic.DeclareSymbol(LNameStr, FNode);
end;

procedure TMetamorfLangInterpreter.DoLookup(const ANode: TASTNode);
var
  LNameExpr: TValue;
  LNameStr:  string;
  LBindName: TValue;
  LFound:    TASTNodeBase;
begin
  // stmt.lookup: child[0] = name expr, optional attr 'bind_name',
  // optional child[1] = 'or' fail block
  if (FSemantic = nil) or (ANode.ChildCount() < 1) then
    Exit;
  LNameExpr := EvalExpr(ANode.GetChildNode(0));
  LNameStr  := AsStr(LNameExpr);

  if FSemantic.LookupSymbol(LNameStr, LFound) then
  begin
    // Bind to variable if -> let varName was specified
    if ANode.GetAttr('bind_name', LBindName) then
      DeclareVar(LBindName.AsString(), ValNode(LFound));
  end
  else
  begin
    // Not found — execute 'or' block if present
    if ANode.ChildCount() >= 2 then
      ExecBlock(ANode.GetChildNode(1));
  end;
end;

procedure TMetamorfLangInterpreter.DoScope(const ANode: TASTNode);
var
  LScopeName: TValue;
  LScopeStr:  string;
  LTok:       TToken;
begin
  // stmt.scope: child[0] = scope name expr, child[1] = body block
  if (FSemantic = nil) or (ANode.ChildCount() < 2) then
    Exit;
  LScopeName := EvalExpr(ANode.GetChildNode(0));
  LScopeStr  := AsStr(LScopeName);
  FillChar(LTok, SizeOf(LTok), 0);
  FSemantic.PushScope(LScopeStr, LTok);
  try
    ExecBlock(ANode.GetChildNode(1));
  finally
    FSemantic.PopScope(LTok);
  end;
end;

procedure TMetamorfLangInterpreter.DoSetAttr(const ANode: TASTNode);
var
  LAttrExpr: TValue;
  LValExpr:  TValue;
  LTarget:   TASTNode;
begin
  // stmt.set_attr: child[0] = attr name expr, child[1] = value expr
  if ANode.ChildCount() < 2 then
    Exit;
  LAttrExpr := EvalExpr(ANode.GetChildNode(0));
  LValExpr  := EvalExpr(ANode.GetChildNode(1));

  if FNode <> nil then
    LTarget := FNode as TASTNode
  else if FResultNode <> nil then
    LTarget := FResultNode
  else
    Exit;

  LTarget.SetAttr(AsStr(LAttrExpr), LValExpr);
end;

procedure TMetamorfLangInterpreter.DoExpect(const ANode: TASTNode);
var
  LKindAttr:    TValue;
  LCaptureAttr: TValue;
  LTok:         TToken;
begin
  // stmt.expect: attr 'token_kind' = kind to expect
  // Optional attr 'capture_attr' = @attr to store text
  // Optional children = [meta.token_ref] list
  if FParser = nil then
    Exit;

  if ANode.GetAttr('token_kind', LKindAttr) then
  begin
    // Capture token before expect (expect advances past it)
    LTok := FParser.CurrentToken();
    FParser.Expect(LKindAttr.AsString());
    if ANode.GetAttr('capture_attr', LCaptureAttr) and
       (FResultNode <> nil) then
      FResultNode.SetAttr(LCaptureAttr.AsString(),
        TValue.From<string>(LTok.Text));
  end
  else if ANode.ChildCount() > 0 then
  begin
    // List of token refs — expect any one of them
    LTok := FParser.CurrentToken();
    FParser.Expect(LTok.Kind); // just advance; list validation TBD
    if ANode.GetAttr('capture_attr', LCaptureAttr) and
       (FResultNode <> nil) then
      FResultNode.SetAttr(LCaptureAttr.AsString(),
        TValue.From<string>(LTok.Text));
  end;
end;

procedure TMetamorfLangInterpreter.DoConsume(const ANode: TASTNode);
var
  LKindAttr:    TValue;
  LCaptureAttr: TValue;
  LTok:         TToken;
  LI:           Integer;
  LChild:       TASTNode;
  LRefKind:     TValue;
  LMatched:     Boolean;
begin
  // stmt.consume: attr 'token_kind' = single kind, or children = list
  // Optional attr 'capture_attr' = @attr to store text
  if FParser = nil then
    Exit;

  LTok := FParser.CurrentToken();

  if ANode.GetAttr('token_kind', LKindAttr) then
  begin
    // Single token kind — consume it
    FParser.Consume();
    if ANode.GetAttr('capture_attr', LCaptureAttr) and
       (FResultNode <> nil) then
      FResultNode.SetAttr(LCaptureAttr.AsString(),
        TValue.From<string>(LTok.Text));
  end
  else if ANode.ChildCount() > 0 then
  begin
    // List of token refs — consume whichever matches
    LMatched := False;
    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LChild := ANode.GetChildNode(LI);
      if (LChild <> nil) and
         (LChild.GetNodeKind() = 'meta.token_ref') then
      begin
        if LChild.GetAttr('kind', LRefKind) and
           (LRefKind.AsString() = LTok.Kind) then
        begin
          LMatched := True;
          Break;
        end;
      end;
    end;
    if LMatched or (ANode.ChildCount() > 0) then
      FParser.Consume();
    if ANode.GetAttr('capture_attr', LCaptureAttr) and
       (FResultNode <> nil) then
      FResultNode.SetAttr(LCaptureAttr.AsString(),
        TValue.From<string>(LTok.Text));
  end;
end;

procedure TMetamorfLangInterpreter.DoParseSub(const ANode: TASTNode);
var
  LNodeKind:    TValue;
  LIsMany:      TValue;
  LCaptureAttr: TValue;
  LUntilKinds:  TValue;
  LKindStr:     string;
  LCapture:     string;
  LUntilStr:    string;
  LUntilArr:    TArray<string>;
  LParsed:      TASTNodeBase;
  LContainer:   TASTNode;
  LI:           Integer;
  LDone:        Boolean;
  LTok:         TToken;
  LMax:         Integer;
begin
  // stmt.parse_sub: attrs 'node_kind', 'is_many', 'capture_attr',
  // optional 'until_kinds'. Parses expr/stmt and adds as child.
  if FParser = nil then
    Exit;
  if not ANode.GetAttr('node_kind', LNodeKind) then
    Exit;
  LKindStr := LNodeKind.AsString();

  // Get capture attr name
  LCapture := '';
  if ANode.GetAttr('capture_attr', LCaptureAttr) then
    LCapture := LCaptureAttr.AsString();

  // Check for 'many'
  if ANode.GetAttr('is_many', LIsMany) and
     LIsMany.IsType<Boolean>() and LIsMany.AsBoolean() then
  begin
    // parse many stmt until ...
    LUntilStr := '';
    if ANode.GetAttr('until_kinds', LUntilKinds) then
      LUntilStr := LUntilKinds.AsString();
    LUntilArr := LUntilStr.Split([',']);

    LContainer := TASTNode.CreateNode('meta.block',
      FParser.CurrentToken());

    LMax := 10000;
    while LMax > 0 do
    begin
      Dec(LMax);
      LTok := FParser.CurrentToken();
      if LTok.Kind = KIND_EOF then
        Break;

      // Check until conditions
      LDone := False;
      for LI := 0 to Length(LUntilArr) - 1 do
      begin
        if (LUntilArr[LI] <> '') and (LTok.Kind = Trim(LUntilArr[LI])) then
        begin
          LDone := True;
          Break;
        end;
      end;
      if LDone then
        Break;

      if (LKindStr = 'stmt') or LKindStr.StartsWith('stmt.') then
        LParsed := FParser.ParseStatement()
      else
        LParsed := FParser.ParseExpression(0);

      if LParsed <> nil then
        LContainer.AddChild(LParsed as TASTNode);
    end;

    if (LCapture <> '') and (FResultNode <> nil) then
      FResultNode.SetAttr(LCapture, ValNode(LContainer));
    FResultNode.AddChild(LContainer);
  end
  else
  begin
    // Single parse
    if (LKindStr = 'expr') or LKindStr.StartsWith('expr.') then
      LParsed := FParser.ParseExpression(0)
    else
      LParsed := FParser.ParseStatement();

    if LParsed <> nil then
    begin
      if (LCapture <> '') and (FResultNode <> nil) then
        FResultNode.SetAttr(LCapture, ValNode(LParsed));
      if FResultNode <> nil then
        FResultNode.AddChild(LParsed as TASTNode);
    end;
  end;
end;

procedure TMetamorfLangInterpreter.DoOptional(const ANode: TASTNode);
begin
  // stmt.optional: child[0] = block to try
  // Swallow parse failures — if the block fails, just continue
  if ANode.ChildCount() < 1 then
    Exit;
  try
    ExecBlock(ANode.GetChildNode(0));
  except
    on E: Exception do
    begin
      // Re-raise control flow exceptions
      if (E is EInterpReturn) or (E is EInterpBreak) or
         (E is EInterpContinue) then
        raise;
      // Swallow parse/eval errors
    end;
  end;
end;

procedure TMetamorfLangInterpreter.DoDiagnostic(const ANode: TASTNode);
var
  LLevel: TValue;
  LMsg:   string;
  LSev:   TErrorSeverity;
begin
  // stmt.diagnostic: attr 'level', child[0] = message expr
  if (FErrors = nil) or (ANode.ChildCount() < 1) then
    Exit;
  if not ANode.GetAttr('level', LLevel) then
    Exit;

  LMsg := AsStr(EvalExpr(ANode.GetChildNode(0)));

  if LLevel.AsString() = 'error' then
    LSev := esError
  else if LLevel.AsString() = 'warning' then
    LSev := esWarning
  else
    LSev := esHint;

  FErrors.Add(LSev, 'P100', LMsg);
end;

procedure TMetamorfLangInterpreter.DoIndent(const ANode: TASTNode);
begin
  // stmt.indent: child[0] = block — indent in, exec, indent out
  if (FIR = nil) or (ANode.ChildCount() < 1) then
    Exit;
  FIR.IndentIn();
  try
    ExecBlock(ANode.GetChildNode(0));
  finally
    FIR.IndentOut();
  end;
end;

// =========================================================================
// EXPRESSION HANDLERS
// =========================================================================

function TMetamorfLangInterpreter.EvalLiteralString(
  const ANode: TASTNode): TValue;
var
  LVal: TValue;
begin
  if ANode.GetAttr('value', LVal) then
    Result := LVal
  else
    Result := ValStr(ANode.GetToken().Text);
end;

function TMetamorfLangInterpreter.EvalLiteralInt(
  const ANode: TASTNode): TValue;
var
  LVal: TValue;
begin
  if ANode.GetAttr('value', LVal) then
    Result := LVal
  else
    Result := ValInt(StrToInt64Def(ANode.GetToken().Text, 0));
end;

function TMetamorfLangInterpreter.EvalLiteralBool(
  const ANode: TASTNode): TValue;
var
  LVal: TValue;
begin
  if ANode.GetAttr('value', LVal) then
    Result := LVal
  else
    Result := ValBool(ANode.GetToken().Text = 'true');
end;

function TMetamorfLangInterpreter.EvalLiteralNil(
  const ANode: TASTNode): TValue;
begin
  Result := TValue.Empty;
end;

function TMetamorfLangInterpreter.EvalIdent(
  const ANode: TASTNode): TValue;
var
  LName: TValue;
  LStr:  string;
begin
  if not ANode.GetAttr('name', LName) then
  begin
    Result := TValue.Empty;
    Exit;
  end;
  LStr := LName.AsString();

  // Special identifier: node — refers to FNode
  if LStr = 'node' then
  begin
    if FNode <> nil then
      Result := ValNode(FNode)
    else if FResultNode <> nil then
      Result := ValNode(FResultNode)
    else
      Result := TValue.Empty;
    Exit;
  end;

  // Variable lookup
  if not LookupVar(LStr, Result) then
    Result := TValue.Empty;
end;

function TMetamorfLangInterpreter.EvalAttrAccess(
  const ANode: TASTNode): TValue;
var
  LName:    TValue;
  LAttrStr: string;
  LTarget:  TASTNodeBase;
begin
  Result := TValue.Empty;
  if not ANode.GetAttr('name', LName) then
    Exit;
  LAttrStr := LName.AsString();

  // Read from current context node
  if FNode <> nil then
    LTarget := FNode
  else if FResultNode <> nil then
    LTarget := FResultNode
  else
    Exit;

  if not LTarget.GetAttr(LAttrStr, Result) then
    Result := TValue.Empty;
end;

function TMetamorfLangInterpreter.EvalBinary(
  const ANode: TASTNode): TValue;
var
  LOp:    TValue;
  LOpStr: string;
  LLeft:  TValue;
  LRight: TValue;
begin
  Result := TValue.Empty;
  if ANode.ChildCount() < 2 then
    Exit;
  if not ANode.GetAttr('operator', LOp) then
    Exit;

  LOpStr := LOp.AsString();

  // Short-circuit for 'and' / 'or'
  if LOpStr = 'and' then
  begin
    LLeft := EvalExpr(ANode.GetChildNode(0));
    if not IsTruthy(LLeft) then
      Exit(ValBool(False));
    LRight := EvalExpr(ANode.GetChildNode(1));
    Exit(ValBool(IsTruthy(LRight)));
  end;

  if LOpStr = 'or' then
  begin
    LLeft := EvalExpr(ANode.GetChildNode(0));
    if IsTruthy(LLeft) then
      Exit(ValBool(True));
    LRight := EvalExpr(ANode.GetChildNode(1));
    Exit(ValBool(IsTruthy(LRight)));
  end;

  // Evaluate both sides
  LLeft  := EvalExpr(ANode.GetChildNode(0));
  LRight := EvalExpr(ANode.GetChildNode(1));

  // String concatenation with +
  if (LOpStr = '+') and (IsStrVal(LLeft) or IsStrVal(LRight)) then
  begin
    Result := ValStr(AsStr(LLeft) + AsStr(LRight));
    Exit;
  end;

  // Equality / inequality — works on all types via string comparison
  if LOpStr = '==' then
  begin
    Result := ValBool(AsStr(LLeft) = AsStr(LRight));
    Exit;
  end;
  if LOpStr = '!=' then
  begin
    Result := ValBool(AsStr(LLeft) <> AsStr(LRight));
    Exit;
  end;

  // Arithmetic — integer operations
  if LOpStr = '+' then
    Result := ValInt(AsInt(LLeft) + AsInt(LRight))
  else if LOpStr = '-' then
    Result := ValInt(AsInt(LLeft) - AsInt(LRight))
  else if LOpStr = '*' then
    Result := ValInt(AsInt(LLeft) * AsInt(LRight))
  else if LOpStr = '/' then
  begin
    if AsInt(LRight) <> 0 then
      Result := ValInt(AsInt(LLeft) div AsInt(LRight))
    else
      Result := ValInt(0);
  end
  else if LOpStr = '%' then
  begin
    if AsInt(LRight) <> 0 then
      Result := ValInt(AsInt(LLeft) mod AsInt(LRight))
    else
      Result := ValInt(0);
  end

  // Comparison — integer
  else if LOpStr = '<' then
    Result := ValBool(AsInt(LLeft) < AsInt(LRight))
  else if LOpStr = '>' then
    Result := ValBool(AsInt(LLeft) > AsInt(LRight))
  else if LOpStr = '<=' then
    Result := ValBool(AsInt(LLeft) <= AsInt(LRight))
  else if LOpStr = '>=' then
    Result := ValBool(AsInt(LLeft) >= AsInt(LRight))
  else
    Result := TValue.Empty;
end;

function TMetamorfLangInterpreter.EvalUnaryNot(
  const ANode: TASTNode): TValue;
begin
  if ANode.ChildCount() > 0 then
    Result := ValBool(not IsTruthy(EvalExpr(ANode.GetChildNode(0))))
  else
    Result := ValBool(True);
end;

function TMetamorfLangInterpreter.EvalUnaryMinus(
  const ANode: TASTNode): TValue;
begin
  if ANode.ChildCount() > 0 then
    Result := ValInt(-AsInt(EvalExpr(ANode.GetChildNode(0))))
  else
    Result := ValInt(0);
end;

function TMetamorfLangInterpreter.EvalCall(
  const ANode: TASTNode): TValue;
var
  LCallee:     TASTNode;
  LCalleeName: TValue;
  LFuncName:   string;
  LBuiltin:    TBuiltinFunc;
  LRoutineAST: TASTNode;
  LArgs:       TArray<TValue>;
  LI:          Integer;
  LBodyNode:   TASTNode;
  LParamNode:  TASTNode;
  LParamName:  TValue;
  LParamIdx:   Integer;
begin
  Result := TValue.Empty;

  // expr.group — just evaluate the child
  if ANode.GetNodeKind() = 'expr.group' then
  begin
    if ANode.ChildCount() > 0 then
      Result := EvalExpr(ANode.GetChildNode(0));
    Exit;
  end;

  // expr.call: child[0] = callee, child[1+] = arguments
  if ANode.ChildCount() < 1 then
    Exit;

  LCallee := ANode.GetChildNode(0);
  if LCallee = nil then
    Exit;

  // Resolve function name
  if LCallee.GetNodeKind() = 'expr.ident' then
  begin
    if LCallee.GetAttr('name', LCalleeName) then
      LFuncName := LCalleeName.AsString()
    else
      Exit;
  end
  else
  begin
    // Could be a field access like node.method() — for now,
    // evaluate the callee and try to use it as a string name
    LCalleeName := EvalExpr(LCallee);
    LFuncName := AsStr(LCalleeName);
  end;

  // Evaluate arguments (child[1+])
  SetLength(LArgs, ANode.ChildCount() - 1);
  for LI := 1 to ANode.ChildCount() - 1 do
    LArgs[LI - 1] := EvalExpr(ANode.GetChildNode(LI));

  // Check built-in functions first
  if FBuiltins.TryGetValue(LFuncName, LBuiltin) then
  begin
    Result := LBuiltin(LArgs);
    Exit;
  end;

  // Check user-defined routines
  if FRoutines.TryGetValue(LFuncName, LRoutineAST) then
  begin
    // meta.routine_decl: children = param_decl nodes + body block (last child)
    PushScope();
    try
      // Bind arguments to parameter names
      LParamIdx := 0;
      for LI := 0 to LRoutineAST.ChildCount() - 2 do
      begin
        LParamNode := LRoutineAST.GetChildNode(LI);
        if LParamNode.GetNodeKind() = 'meta.param_decl' then
        begin
          if LParamNode.GetAttr('name', LParamName) then
          begin
            if LParamIdx < Length(LArgs) then
              DeclareVar(LParamName.AsString(), LArgs[LParamIdx])
            else
              DeclareVar(LParamName.AsString(), TValue.Empty);
            Inc(LParamIdx);
          end;
        end;
      end;

      // Execute body (last child)
      LBodyNode := LRoutineAST.GetChildNode(
        LRoutineAST.ChildCount() - 1);
      try
        ExecBlock(LBodyNode);
      except
        on E: EInterpReturn do
          Result := E.ReturnValue;
      end;
    finally
      PopScope();
    end;
    Exit;
  end;

  // Unknown function
  if FErrors <> nil then
    FErrors.Add(esError, 'I102',
      'Unknown function: %s', [LFuncName]);
end;

function TMetamorfLangInterpreter.EvalIndex(
  const ANode: TASTNode): TValue;
var
  LTarget: TValue;
  LIdx:    TValue;
  LNode:   TASTNodeBase;
  LIndex:  Integer;
begin
  Result := TValue.Empty;
  if ANode.ChildCount() < 2 then
    Exit;

  LTarget := EvalExpr(ANode.GetChildNode(0));
  LIdx    := EvalExpr(ANode.GetChildNode(1));

  // Node child access: node[index]
  if IsNodeVal(LTarget) then
  begin
    LNode  := AsNode(LTarget);
    LIndex := Integer(AsInt(LIdx));
    if (LNode <> nil) and (LIndex >= 0) and
       (LIndex < LNode.ChildCount()) then
      Result := ValNode(LNode.GetChild(LIndex));
  end;
end;

function TMetamorfLangInterpreter.EvalFieldAccess(
  const ANode: TASTNode): TValue;
var
  LTarget:   TValue;
  LField:    TValue;
  LFieldStr: string;
  LNode:     TASTNodeBase;
begin
  Result := TValue.Empty;
  if ANode.ChildCount() < 1 then
    Exit;
  if not ANode.GetAttr('field', LField) then
    Exit;

  LTarget   := EvalExpr(ANode.GetChildNode(0));
  LFieldStr := LField.AsString();

  // Node attribute access: node.attrName
  if IsNodeVal(LTarget) then
  begin
    LNode := AsNode(LTarget);
    if LNode <> nil then
      LNode.GetAttr(LFieldStr, Result);
  end;
end;

// =========================================================================
// TOP-LEVEL WALK HELPERS (stubs for Slice 1)
// =========================================================================

procedure TMetamorfLangInterpreter.WalkTokensBlock(const ANode: TASTNode);
var
  LI:          Integer;
  LChild:      TASTNode;
  LKind:       string;
  LCategory:   TValue;
  LNameAttr:   TValue;
  LKindAttr:   TValue;
  LPatternAttr: TValue;
  LCatStr:     string;
  LNameStr:    string;
  LKindStr:    string;
  LPatStr:     string;
  LBlockOpen:  string;
  LCfg:        TLangConfig;
  LRole:       TConditionalRole;
  LRoleVal:    TValue;
  LRoleStr:    string;
  LAllowEscape: Boolean;
  LCloseStr:   string;
  LEscVal:     TValue;
  LCloseVal:   TValue;

  // Reconstruct a dotted identifier from an expression node tree
  function ExprToDottedStr(const AExpr: TASTNode): string;
  var
    LVal: TValue;
  begin
    Result := '';
    if AExpr = nil then
      Exit;
    if AExpr.GetNodeKind() = 'expr.ident' then
    begin
      if AExpr.GetAttr('name', LVal) then
        Result := LVal.AsString();
    end
    else if AExpr.GetNodeKind() = 'expr.field_access' then
    begin
      Result := ExprToDottedStr(AExpr.GetChildNode(0));
      if AExpr.GetAttr('field', LVal) then
        Result := Result + '.' + LVal.AsString();
    end
    else
    begin
      // Fall back to evaluating
      LVal := EvalExpr(AExpr);
      Result := AsStr(LVal);
    end;
  end;

  // Get config key name from the LHS of a stmt.assign
  function GetAssignKey(const AStmt: TASTNode): string;
  var
    LLhs: TASTNode;
    LVal: TValue;
  begin
    Result := '';
    if AStmt.ChildCount() < 1 then
      Exit;
    LLhs := AStmt.GetChildNode(0);
    if (LLhs <> nil) and (LLhs.GetNodeKind() = 'expr.ident') then
    begin
      if LLhs.GetAttr('name', LVal) then
        Result := LVal.AsString();
    end;
  end;

begin
  if ANode = nil then
    Exit;

  LCfg := FTargetMetamorf.Config();
  LBlockOpen := '';

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChildNode(LI);
    if LChild = nil then
      Continue;

    LKind := LChild.GetNodeKind();

    if LKind = 'meta.token_decl' then
    begin
      // Read attributes: category, name, kind, pattern
      if not LChild.GetAttr('category', LCategory) then
        Continue;
      if not LChild.GetAttr('name', LNameAttr) then
        Continue;
      if not LChild.GetAttr('kind', LKindAttr) then
        Continue;
      if not LChild.GetAttr('pattern', LPatternAttr) then
        Continue;

      LCatStr  := LCategory.AsString();
      LNameStr := LNameAttr.AsString();
      LKindStr := LKindAttr.AsString();
      LPatStr  := AsStr(LPatternAttr);

      if LCatStr = 'keyword' then
        LCfg.AddKeyword(LPatStr, LKindStr)
      else if (LCatStr = 'op') or (LCatStr = 'delimiter') then
        LCfg.AddOperator(LPatStr, LKindStr)
      else if LCatStr = 'comment' then
      begin
        if LNameStr = 'line' then
          LCfg.AddLineComment(LPatStr)
        else if LNameStr = 'block_open' then
          LBlockOpen := LPatStr
        else if LNameStr = 'block_close' then
        begin
          if LBlockOpen <> '' then
          begin
            LCfg.AddBlockComment(LBlockOpen, LPatStr);
            LBlockOpen := '';
          end;
        end;
      end
      else if LCatStr = 'string' then
      begin
        LAllowEscape := True;
        if LChild.GetAttr('noescape', LEscVal) and LEscVal.AsBoolean() then
          LAllowEscape := False;
        LCloseStr := LPatStr;
        if LChild.GetAttr('close_pattern', LCloseVal) then
          LCloseStr := LCloseVal.AsString();
        LCfg.AddStringStyle(LPatStr, LCloseStr, LKindStr, LAllowEscape);
      end
      else if LCatStr = 'directive' then
      begin
        LRole := crNone;
        if LChild.GetAttr('directive_role', LRoleVal) then
        begin
          LRoleStr := LRoleVal.AsString();
          if LRoleStr = 'define' then LRole := crDefine
          else if LRoleStr = 'undef' then LRole := crUndef
          else if LRoleStr = 'ifdef' then LRole := crIfDef
          else if LRoleStr = 'ifndef' then LRole := crIfNDef
          else if LRoleStr = 'elseif' then LRole := crElseIf
          else if LRoleStr = 'else' then LRole := crElse
          else if LRoleStr = 'endif' then LRole := crEndIf;
        end;
        LCfg.AddDirective(LNameStr, LKindStr, LRole);
      end;
    end
    else if LKind = 'stmt.assign' then
    begin
      // Config assignment: key = value;
      LNameStr := GetAssignKey(LChild);
      if (LNameStr <> '') and (LChild.ChildCount() >= 2) then
      begin
        if LNameStr = 'casesensitive' then
          LCfg.CaseSensitiveKeywords(
            IsTruthy(EvalExpr(LChild.GetChildNode(1))))
        else if LNameStr = 'identifier_start' then
          LCfg.IdentifierStart(
            AsStr(EvalExpr(LChild.GetChildNode(1))))
        else if LNameStr = 'identifier_part' then
          LCfg.IdentifierPart(
            AsStr(EvalExpr(LChild.GetChildNode(1))))
        else if LNameStr = 'terminator' then
          LCfg.SetStatementTerminator(
            ExprToDottedStr(LChild.GetChildNode(1)))
        else if LNameStr = 'block_open' then
          LCfg.SetBlockOpen(
            ExprToDottedStr(LChild.GetChildNode(1)))
        else if LNameStr = 'block_close' then
          LCfg.SetBlockClose(
            ExprToDottedStr(LChild.GetChildNode(1)))
        else if LNameStr = 'directive_prefix' then
          LCfg.SetDirectivePrefix(
            AsStr(EvalExpr(LChild.GetChildNode(1))), '')
        else if LNameStr = 'hex_prefix' then
          LCfg.SetHexPrefix(
            AsStr(EvalExpr(LChild.GetChildNode(1))), 'literal.hex')
        else if LNameStr = 'binary_prefix' then
          LCfg.SetBinaryPrefix(
            AsStr(EvalExpr(LChild.GetChildNode(1))), 'literal.binary');
      end;
    end;
    // Other children (mode blocks, etc.) — skip for now
  end;

  // After all tokens registered, set up literal prefix handlers
  LCfg.RegisterLiteralPrefixes();
end;

procedure TMetamorfLangInterpreter.WalkGrammarBlock(const ANode: TASTNode);

  // Scan a rule body for its first expect/consume to determine trigger token(s)
  function FindTriggerKinds(const ABody: TASTNode): TArray<string>;
  var
    LI:    Integer;
    LJ:    Integer;
    LStmt: TASTNode;
    LKind: string;
    LVal:  TValue;
    LRef:  TASTNode;
  begin
    SetLength(Result, 0);
    if ABody = nil then
      Exit;
    for LI := 0 to ABody.ChildCount() - 1 do
    begin
      LStmt := ABody.GetChildNode(LI);
      if LStmt = nil then
        Continue;
      LKind := LStmt.GetNodeKind();
      if (LKind = 'stmt.expect') or (LKind = 'stmt.consume') then
      begin
        if LStmt.GetAttr('token_kind', LVal) then
        begin
          SetLength(Result, 1);
          Result[0] := LVal.AsString();
          Exit;
        end;
        // List form — collect ALL token refs
        if LStmt.ChildCount() > 0 then
        begin
          SetLength(Result, LStmt.ChildCount());
          for LJ := 0 to LStmt.ChildCount() - 1 do
          begin
            LRef := LStmt.GetChildNode(LJ);
            if (LRef <> nil) and LRef.GetAttr('kind', LVal) then
              Result[LJ] := LVal.AsString()
            else
              Result[LJ] := '';
          end;
          Exit;
        end;
      end;
    end;
  end;

  // Helper: create a statement handler closure with proper capture
  function MakeStmtHandler(const AInterp: TMetamorfLangInterpreter;
    const ABody: TASTNode): TStatementHandler;
  begin
    Result :=
      function(AParser: TParserBase): TASTNodeBase
      var
        LSavedParser: TParserBase;
        LSavedResult: TASTNode;
      begin
        LSavedParser := AInterp.FParser;
        LSavedResult := AInterp.FResultNode;
        AInterp.FParser     := AParser;
        AInterp.FResultNode := AParser.CreateNode();
        AInterp.PushScope();
        try
          AInterp.ExecBlock(ABody);
        finally
          AInterp.PopScope();
        end;
        Result := AInterp.FResultNode;
        AInterp.FParser     := LSavedParser;
        AInterp.FResultNode := LSavedResult;
      end;
  end;

  // Helper: create a prefix handler closure with proper capture
  function MakePrefixHandler(const AInterp: TMetamorfLangInterpreter;
    const ABody: TASTNode): TPrefixHandler;
  begin
    Result :=
      function(AParser: TParserBase): TASTNodeBase
      var
        LSavedParser: TParserBase;
        LSavedResult: TASTNode;
      begin
        LSavedParser := AInterp.FParser;
        LSavedResult := AInterp.FResultNode;
        AInterp.FParser     := AParser;
        AInterp.FResultNode := AParser.CreateNode();
        AInterp.PushScope();
        try
          AInterp.ExecBlock(ABody);
        finally
          AInterp.PopScope();
        end;
        Result := AInterp.FResultNode;
        AInterp.FParser     := LSavedParser;
        AInterp.FResultNode := LSavedResult;
      end;
  end;

  // Helper: create an infix handler closure with proper capture
  function MakeInfixHandler(const AInterp: TMetamorfLangInterpreter;
    const ABody: TASTNode): TInfixHandler;
  begin
    Result :=
      function(AParser: TParserBase;
        ALeft: TASTNodeBase): TASTNodeBase
      var
        LSavedParser: TParserBase;
        LSavedResult: TASTNode;
      begin
        LSavedParser := AInterp.FParser;
        LSavedResult := AInterp.FResultNode;
        AInterp.FParser     := AParser;
        AInterp.FResultNode := AParser.CreateNode();
        AInterp.FResultNode.AddChild(ALeft as TASTNode);
        AInterp.PushScope();
        try
          AInterp.ExecBlock(ABody);
        finally
          AInterp.PopScope();
        end;
        Result := AInterp.FResultNode;
        AInterp.FParser     := LSavedParser;
        AInterp.FResultNode := LSavedResult;
      end;
  end;

var
  LI:          Integer;
  LJ:          Integer;
  LChild:      TASTNode;
  LNodeKind:   TValue;
  LNodeKindStr: string;
  LAssoc:      TValue;
  LPower:      TValue;
  LPowerInt:   Integer;
  LBody:       TASTNode;
  LTriggers:   TArray<string>;
  LTrigger:    string;
  LCfg:        TLangConfig;
begin
  if ANode = nil then
    Exit;
  LCfg := FTargetMetamorf.Config();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChildNode(LI);
    if (LChild = nil) or (LChild.GetNodeKind() <> 'meta.rule_decl') then
      Continue;

    if not LChild.GetAttr('node_kind', LNodeKind) then
      Continue;
    LNodeKindStr := LNodeKind.AsString();

    // Body is last child (meta.block)
    LBody := LChild.GetChildNode(LChild.ChildCount() - 1);
    if LBody = nil then
      Continue;

    // Determine trigger token(s)
    LTriggers := FindTriggerKinds(LBody);
    if Length(LTriggers) = 0 then
    begin
      SetLength(LTriggers, 1);
      LTriggers[0] := KIND_IDENTIFIER;
    end;

    // Register for EACH trigger token
    for LJ := 0 to Length(LTriggers) - 1 do
    begin
      LTrigger := LTriggers[LJ];
      if LTrigger = '' then
        Continue;

      if LChild.GetAttr('assoc', LAssoc) and
         LChild.GetAttr('power', LPower) then
      begin
        LPowerInt := Integer(AsInt(LPower));
        if LAssoc.AsString() = 'right' then
          LCfg.RegisterInfixRight(LTrigger, LPowerInt, LNodeKindStr,
            MakeInfixHandler(Self, LBody))
        else
          LCfg.RegisterInfixLeft(LTrigger, LPowerInt, LNodeKindStr,
            MakeInfixHandler(Self, LBody));
      end
      else if LNodeKindStr.StartsWith('expr.') then
      begin
        LCfg.RegisterPrefix(LTrigger, LNodeKindStr,
          MakePrefixHandler(Self, LBody));
      end
      else
      begin
        LCfg.RegisterStatement(LTrigger, LNodeKindStr,
          MakeStmtHandler(Self, LBody));
      end;
    end;
  end;
end;

procedure TMetamorfLangInterpreter.WalkSemanticsBlock(const ANode: TASTNode);

  function MakeSemanticHandler(const AInterp: TMetamorfLangInterpreter;
    const ABody: TASTNode): TSemanticHandler;
  begin
    Result :=
      procedure(const ASemanticNode: TASTNodeBase;
        ASem: TSemanticBase)
      var
        LSavedSem:  TSemanticBase;
        LSavedNode: TASTNodeBase;
      begin
        LSavedSem  := AInterp.FSemantic;
        LSavedNode := AInterp.FNode;
        AInterp.FSemantic := ASem;
        AInterp.FNode     := ASemanticNode;
        AInterp.PushScope();
        try
          AInterp.ExecBlock(ABody);
        finally
          AInterp.PopScope();
        end;
        AInterp.FSemantic := LSavedSem;
        AInterp.FNode     := LSavedNode;
      end;
  end;

var
  LI:          Integer;
  LJ:          Integer;
  LChild:      TASTNode;
  LPassChild:  TASTNode;
  LNodeKind:   TValue;
  LNodeKindStr: string;
  LBody:       TASTNode;
  LCfg:        TLangConfig;
begin
  if ANode = nil then
    Exit;
  LCfg := FTargetMetamorf.Config();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChildNode(LI);
    if LChild = nil then
      Continue;

    if LChild.GetNodeKind() = 'meta.on_handler' then
    begin
      if not LChild.GetAttr('node_kind', LNodeKind) then
        Continue;
      LNodeKindStr := LNodeKind.AsString();
      LBody := LChild.GetChildNode(0);
      if LBody = nil then
        Continue;
      LCfg.RegisterSemanticRule(LNodeKindStr,
        MakeSemanticHandler(Self, LBody));
    end
    else if LChild.GetNodeKind() = 'meta.pass_block' then
    begin
      // Iterate into pass block children — register handlers
      // (single-pass: all handlers execute in one traversal)
      for LJ := 0 to LChild.ChildCount() - 1 do
      begin
        LPassChild := LChild.GetChildNode(LJ);
        if (LPassChild = nil) or
           (LPassChild.GetNodeKind() <> 'meta.on_handler') then
          Continue;
        if not LPassChild.GetAttr('node_kind', LNodeKind) then
          Continue;
        LNodeKindStr := LNodeKind.AsString();
        LBody := LPassChild.GetChildNode(0);
        if LBody = nil then
          Continue;
        LCfg.RegisterSemanticRule(LNodeKindStr,
          MakeSemanticHandler(Self, LBody));
      end;
    end;
  end;
end;

procedure TMetamorfLangInterpreter.WalkEmittersBlock(const ANode: TASTNode);

  function MakeEmitHandler(const AInterp: TMetamorfLangInterpreter;
    const ABody: TASTNode): TEmitHandler;
  begin
    Result :=
      procedure(AEmitNode: TASTNodeBase; AGen: TIRBase)
      var
        LSavedIR:   TIRBase;
        LSavedNode: TASTNodeBase;
      begin
        LSavedIR   := AInterp.FIR;
        LSavedNode := AInterp.FNode;
        AInterp.FIR  := AGen;
        AInterp.FNode := AEmitNode;
        AInterp.PushScope();
        try
          AInterp.ExecBlock(ABody);
        finally
          AInterp.PopScope();
        end;
        AInterp.FIR  := LSavedIR;
        AInterp.FNode := LSavedNode;
      end;
  end;

var
  LI:          Integer;
  LChild:      TASTNode;
  LNodeKind:   TValue;
  LNodeKindStr: string;
  LBody:       TASTNode;
  LCfg:        TLangConfig;
begin
  if ANode = nil then
    Exit;
  LCfg := FTargetMetamorf.Config();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChildNode(LI);
    if (LChild = nil) or (LChild.GetNodeKind() <> 'meta.on_handler') then
      Continue;
    if not LChild.GetAttr('node_kind', LNodeKind) then
      Continue;
    LNodeKindStr := LNodeKind.AsString();

    LBody := LChild.GetChildNode(0);
    if LBody = nil then
      Continue;

    LCfg.RegisterEmitter(LNodeKindStr,
      MakeEmitHandler(Self, LBody));
  end;
end;

// =========================================================================
// TOP-LEVEL NODE ROUTER
// =========================================================================

procedure TMetamorfLangInterpreter.RouteTopLevelNode(const ANode: TASTNode);
var
  LKind:     string;
  LNameAttr: TValue;
  LPath:     string;
  LImportedRoot: TASTNode;
  LFragNode: TASTNode;
  LJ:        Integer;
  LMemberVal: TValue;
  LMemberIdx: Integer;
begin
  LKind := ANode.GetNodeKind();

  if LKind = 'meta.language_decl' then
  begin
    if ANode.GetAttr('name', LNameAttr) then
      DeclareVar('__language_name', LNameAttr);
    if ANode.GetAttr('version', LNameAttr) then
      DeclareVar('__language_version', LNameAttr);
  end
  else if LKind = 'meta.tokens_block' then
    WalkTokensBlock(ANode)
  else if LKind = 'meta.grammar_block' then
    WalkGrammarBlock(ANode)
  else if LKind = 'meta.semantics_block' then
    WalkSemanticsBlock(ANode)
  else if LKind = 'meta.emitters_block' then
    WalkEmittersBlock(ANode)
  else if LKind = 'meta.types_block' then
    WalkTypesBlock(ANode)
  else if LKind = 'meta.routine_decl' then
  begin
    if ANode.GetAttr('name', LNameAttr) then
      FRoutines.AddOrSetValue(LNameAttr.AsString(), ANode);
  end
  else if LKind = 'meta.const_block' then
    WalkConstBlock(ANode)
  else if LKind = 'meta.enum_decl' then
  begin
    // Declare enum members as sequential integer constants
    if ANode.GetAttr('name', LNameAttr) then
    begin
      LMemberIdx := 0;
      while ANode.GetAttr('member_' + IntToStr(LMemberIdx), LMemberVal) do
      begin
        DeclareVar(LMemberVal.AsString(), TValue.From<Integer>(LMemberIdx));
        Inc(LMemberIdx);
      end;
    end;
  end
  else if LKind = 'meta.fragment_decl' then
  begin
    if ANode.GetAttr('name', LNameAttr) then
      FFragments.AddOrSetValue(LNameAttr.AsString(), ANode);
  end
  else if LKind = 'meta.include' then
  begin
    if ANode.GetAttr('fragment_name', LNameAttr) and
       FFragments.TryGetValue(LNameAttr.AsString(), LFragNode) then
    begin
      for LJ := 0 to LFragNode.ChildCount() - 1 do
        RouteTopLevelNode(LFragNode.GetChildNode(LJ));
    end;
  end
  else if LKind = 'meta.import' then
  begin
    if ANode.GetAttr('path', LNameAttr) and Assigned(FOnLoadDefinition) then
    begin
      LPath := LNameAttr.AsString();
      if FImportedFiles.IndexOf(LPath) < 0 then
      begin
        FImportedFiles.Add(LPath);
        LImportedRoot := FOnLoadDefinition(LPath);
        if LImportedRoot <> nil then
        begin
          FImportedASTs.Add(LImportedRoot);
          for LJ := 0 to LImportedRoot.ChildCount() - 1 do
            RouteTopLevelNode(LImportedRoot.GetChildNode(LJ));
        end;
      end;
    end;
  end;
end;

// =========================================================================
// MAIN ENTRY POINT
// =========================================================================

function TMetamorfLangInterpreter.Execute(const ARootNode: TASTNode;
  const ATargetMetamorf: TMetamorf): Boolean;
var
  LI:     Integer;
  LChild: TASTNode;
begin
  Result := False;
  if ARootNode = nil then
    Exit;
  if ATargetMetamorf = nil then
    Exit;

  FTargetMetamorf := ATargetMetamorf;
  FRoutines.Clear();
  FFragments.Clear();
  FImportedFiles.Clear();
  FImportedASTs.Clear();

  // Push global scope
  PushScope();
  try
    // Walk top-level children
    for LI := 0 to ARootNode.ChildCount() - 1 do
    begin
      LChild := ARootNode.GetChildNode(LI);
      if LChild <> nil then
        RouteTopLevelNode(LChild);
    end;

    // Check for errors
    if FErrors <> nil then
      Result := not FErrors.HasErrors()
    else
      Result := True;
  finally
    PopScope();
    // NOTE: Do NOT clear FTargetMetamorf here. The closures registered on
    // FTargetMetamorf.Config() capture Self and fire during Phase 2 compilation
    // which happens AFTER Execute() returns. FTargetMetamorf must remain valid.
  end;
end;

// =========================================================================
// CONST BLOCK WALKER
// =========================================================================

procedure TMetamorfLangInterpreter.WalkConstBlock(const ANode: TASTNode);
var
  LI:       Integer;
  LChild:   TASTNode;
  LName:    TValue;
  LVal:     TValue;
begin
  // meta.const_block: children are meta.const_decl nodes
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChildNode(LI);
    if (LChild <> nil) and
       (LChild.GetNodeKind() = 'meta.const_decl') then
    begin
      if LChild.GetAttr('name', LName) and
         (LChild.ChildCount() > 0) then
      begin
        LVal := EvalExpr(LChild.GetChildNode(0));
        DeclareVar(LName.AsString(), LVal);
      end;
    end;
  end;
end;

// =========================================================================
// TYPES BLOCK WALKER
// =========================================================================

procedure TMetamorfLangInterpreter.WalkTypesBlock(const ANode: TASTNode);
var
  LI:       Integer;
  LChild:   TASTNode;
  LKind:    string;
  LAttr1:   TValue;
  LAttr2:   TValue;
  LAttr3:   TValue;
  LCfg:     TLangConfig;
  LCompatList: TList<TPair<string, TPair<string, string>>>;
  LCapturedList: TList<TPair<string, TPair<string, string>>>;
begin
  LCfg := FTargetMetamorf.Config();
  LCompatList := TList<TPair<string, TPair<string, string>>>.Create();
  try
    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LChild := ANode.GetChildNode(LI);
      if LChild = nil then
        Continue;
      LKind := LChild.GetNodeKind();

      if LKind = 'meta.type_keyword_decl' then
      begin
        // type int32 = "type.int32";
        LChild.GetAttr('type_text', LAttr1);
        LChild.GetAttr('type_kind', LAttr2);
        LCfg.AddTypeKeyword(LAttr1.AsString(), LAttr2.AsString());
      end
      else if LKind = 'meta.type_mapping_decl' then
      begin
        // map "type.int32" -> "int32_t";
        LChild.GetAttr('source', LAttr1);
        LChild.GetAttr('target', LAttr2);
        LCfg.AddTypeMapping(LAttr1.AsString(), LAttr2.AsString());
      end
      else if LKind = 'meta.literal_type_decl' then
      begin
        // literal "expr.integer" = "type.int32";
        LChild.GetAttr('node_kind', LAttr1);
        LChild.GetAttr('type_kind', LAttr2);
        LCfg.AddLiteralType(LAttr1.AsString(), LAttr2.AsString());
      end
      else if LKind = 'meta.decl_kind_decl' then
      begin
        LChild.GetAttr('node_kind', LAttr1);
        LCfg.AddDeclKind(LAttr1.AsString());
      end
      else if LKind = 'meta.call_kind_decl' then
      begin
        LChild.GetAttr('node_kind', LAttr1);
        LCfg.AddCallKind(LAttr1.AsString());
      end
      else if LKind = 'meta.type_compat_rule' then
      begin
        LChild.GetAttr('from_type', LAttr1);
        LChild.GetAttr('to_type', LAttr2);
        if LChild.GetAttr('coerce_to', LAttr3) then
          LCompatList.Add(TPair<string, TPair<string, string>>.Create(
            LAttr1.AsString(),
            TPair<string, string>.Create(LAttr2.AsString(), LAttr3.AsString())))
        else
          LCompatList.Add(TPair<string, TPair<string, string>>.Create(
            LAttr1.AsString(),
            TPair<string, string>.Create(LAttr2.AsString(), LAttr2.AsString())));
      end
      else if LKind = 'stmt.assign' then
      begin
        // call_name_attr = "call.name";
        if (LChild.ChildCount() >= 2) and
           (LChild.GetChildNode(0) <> nil) and
           (LChild.GetChildNode(0).GetNodeKind() = 'expr.ident') and
           LChild.GetChildNode(0).GetAttr('name', LAttr1) then
        begin
          if LAttr1.AsString() = 'call_name_attr' then
            LCfg.SetCallNameAttr(AsStr(EvalExpr(LChild.GetChildNode(1))));
        end;
      end;
    end;

    // Register collected compat pairs as one callback
    if LCompatList.Count > 0 then
    begin
      LCapturedList := LCompatList;
      LCompatList := nil; // transfer ownership to closure
      LCfg.RegisterTypeCompat(
        function(const AFromType, AToType: string;
          out ACoerceTo: string): Boolean
        var
          LJ: Integer;
          LPair: TPair<string, TPair<string, string>>;
        begin
          Result := False;
          ACoerceTo := '';
          // Check exact match
          if AFromType = AToType then
          begin
            ACoerceTo := AFromType;
            Result := True;
            Exit;
          end;
          for LJ := 0 to LCapturedList.Count - 1 do
          begin
            LPair := LCapturedList[LJ];
            if (LPair.Key = AFromType) and
               (LPair.Value.Key = AToType) then
            begin
              ACoerceTo := LPair.Value.Value;
              Result := True;
              Exit;
            end;
            // Check reverse direction
            if (LPair.Key = AToType) and
               (LPair.Value.Key = AFromType) then
            begin
              ACoerceTo := LPair.Value.Value;
              Result := True;
              Exit;
            end;
          end;
        end);
    end;
  finally
    LCompatList.Free();
  end;
end;

end.
