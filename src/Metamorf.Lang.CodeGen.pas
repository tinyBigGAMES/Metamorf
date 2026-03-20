{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lang.CodeGen;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.API,
  Metamorf.Lang.Common;

procedure ConfigCodeGen(
  const AMetamorf      : TMetamorf;
  const ACustomMetamorf: TMetamorf;
  const APipeline:    TMetamorfLangPipelineCallbacks);

implementation

uses
  System.Rtti,
  Metamorf.Common;

// =========================================================================
// SCRIPT VALUE
// =========================================================================

type

  TScriptValueKind = (
    svkNil,
    svkInt,
    svkBool,
    svkString,
    svkNode,
    svkToken
  );

  TScriptValue = record
    Kind:    TScriptValueKind;
    IntVal:  Int64;
    BoolVal: Boolean;
    StrVal:  string;
    NodeVal: TASTNodeBase;
    TokVal:  TToken;
  end;

// =========================================================================
// CONTEXT KIND
// =========================================================================

type

  TScriptContextKind = (
    sckNone,
    sckParse,
    sckSemantic,
    sckEmit
  );

// =========================================================================
// SHARED STATE STORE
// =========================================================================

type

  IMetamorfScriptStore = interface
    ['{B4A9D315-8C2F-4E6B-AD3F-1F7E4B928C56}']
    function GetHelperFuncs(): TDictionary<string, TASTNodeBase>;
    function GetTypeMap():     TDictionary<string, string>;
  end;

  TMetamorfScriptStore = class(TInterfacedObject, IMetamorfScriptStore)
  private
    FHelperFuncs: TDictionary<string, TASTNodeBase>;
    FTypeMap:     TDictionary<string, string>;
  public
    constructor Create();
    destructor  Destroy(); override;
    function GetHelperFuncs(): TDictionary<string, TASTNodeBase>;
    function GetTypeMap():     TDictionary<string, string>;
  end;

constructor TMetamorfScriptStore.Create();
begin
  inherited Create();
  FHelperFuncs := TDictionary<string, TASTNodeBase>.Create();
  FTypeMap     := TDictionary<string, string>.Create();
end;

destructor TMetamorfScriptStore.Destroy();
begin
  FreeAndNil(FTypeMap);
  FreeAndNil(FHelperFuncs);
  inherited Destroy();
end;

function TMetamorfScriptStore.GetHelperFuncs(): TDictionary<string, TASTNodeBase>;
begin
  Result := FHelperFuncs;
end;

function TMetamorfScriptStore.GetTypeMap(): TDictionary<string, string>;
begin
  Result := FTypeMap;
end;

// =========================================================================
// INTERPRETER
// =========================================================================

type

  TMetamorfScriptInterp = class
  private
    FContextKind:  TScriptContextKind;
    FCustomConfig: TLangConfig;
    FStore:        IMetamorfScriptStore;
    FPipeline:     TMetamorfLangPipelineCallbacks;
    FEnv:          TDictionary<string, TScriptValue>;

    // Phase-2 context objects
    FParser:     TParserBase;
    FLeftNode:   TASTNodeBase;
    FSemantic:   TSemanticBase;
    FIR:         TIRBase;
    FNode:       TASTNodeBase;  // current node in emit/semantic context
    FResultNode: TASTNode;      // node being built in parse context
    FNodeKind:   string;             // node kind for the current rule

    function MakeInt(const AValue: Int64): TScriptValue;
    function MakeBool(const AValue: Boolean): TScriptValue;
    function MakeStr(const AValue: string): TScriptValue;
    function MakeNode(const AValue: TASTNodeBase): TScriptValue;
    function MakeNil(): TScriptValue;

    function ResolveStr(const AVal: TScriptValue): string;
    function ResolveInt(const AVal: TScriptValue): Int64;
    function ResolveBool(const AVal: TScriptValue): Boolean;

    procedure ExecStmt(const AStmt: TASTNodeBase);
    function  EvalExpr(const AExpr: TASTNodeBase): TScriptValue;
    function  EvalBinary(const AOp: string;
      const ALeft, ARight: TScriptValue): TScriptValue;

    function CallBuiltin(const AName: string;
      const AArgs: TArray<TScriptValue>): TScriptValue;
    function CallBuiltinCommon(const AName: string;
      const AArgs: TArray<TScriptValue>;
      out AResult: TScriptValue): Boolean;
    function CallBuiltinEmit(const AName: string;
      const AArgs: TArray<TScriptValue>;
      out AResult: TScriptValue): Boolean;
    function CallBuiltinSemantic(const AName: string;
      const AArgs: TArray<TScriptValue>;
      out AResult: TScriptValue): Boolean;
    function CallHelper(const AName: string;
      const AArgs: TArray<TScriptValue>): TScriptValue;

    function InterpolateString(const ATemplate: string): string;

  public
    constructor Create(
      const ACustomConfig: TLangConfig;
      const AStore:        IMetamorfScriptStore;
      const APipeline:     TMetamorfLangPipelineCallbacks);
    destructor Destroy(); override;

    procedure SetEmitContext(const AIR: TIRBase;
      const ANode: TASTNodeBase);
    procedure SetSemanticContext(const ASemantic: TSemanticBase;
      const ANode: TASTNodeBase);

    procedure ExecBlock(const ABlock: TASTNodeBase);
  end;

// =========================================================================
// INTERPRETER — VALUE CONSTRUCTORS
// =========================================================================

function TMetamorfScriptInterp.MakeInt(const AValue: Int64): TScriptValue;
begin
  Result := Default(TScriptValue);
  Result.Kind   := svkInt;
  Result.IntVal := AValue;
end;

function TMetamorfScriptInterp.MakeBool(const AValue: Boolean): TScriptValue;
begin
  Result := Default(TScriptValue);
  Result.Kind    := svkBool;
  Result.BoolVal := AValue;
end;

function TMetamorfScriptInterp.MakeStr(const AValue: string): TScriptValue;
begin
  Result := Default(TScriptValue);
  Result.Kind   := svkString;
  Result.StrVal := AValue;
end;

function TMetamorfScriptInterp.MakeNode(
  const AValue: TASTNodeBase): TScriptValue;
begin
  Result := Default(TScriptValue);
  Result.Kind    := svkNode;
  Result.NodeVal := AValue;
end;

function TMetamorfScriptInterp.MakeNil(): TScriptValue;
begin
  Result := Default(TScriptValue);
  Result.Kind := svkNil;
end;

function TMetamorfScriptInterp.ResolveStr(const AVal: TScriptValue): string;
begin
  case AVal.Kind of
    svkString: Result := AVal.StrVal;
    svkInt:    Result := IntToStr(AVal.IntVal);
    svkBool:   if AVal.BoolVal then Result := 'true' else Result := 'false';
    svkNil:    Result := '';
  else
    Result := '';
  end;
end;

function TMetamorfScriptInterp.ResolveInt(const AVal: TScriptValue): Int64;
begin
  case AVal.Kind of
    svkInt:    Result := AVal.IntVal;
    svkString: Result := StrToInt64Def(AVal.StrVal, 0);
    svkBool:   if AVal.BoolVal then Result := 1 else Result := 0;
  else
    Result := 0;
  end;
end;

function TMetamorfScriptInterp.ResolveBool(const AVal: TScriptValue): Boolean;
begin
  case AVal.Kind of
    svkBool:   Result := AVal.BoolVal;
    svkInt:    Result := AVal.IntVal <> 0;
    svkString: Result := AVal.StrVal <> '';
    svkNil:    Result := False;
    svkNode:   Result := AVal.NodeVal <> nil;
  else
    Result := False;
  end;
end;

// =========================================================================
// INTERPRETER — STRING INTERPOLATION
// =========================================================================

function TMetamorfScriptInterp.InterpolateString(
  const ATemplate: string): string;
var
  LI:      Integer;
  LLen:    Integer;
  LExpr:   string;
  LDepth:  Integer;
  LAttr:   TValue;
begin
  Result := '';
  LI     := 1;
  LLen   := Length(ATemplate);

  while LI <= LLen do
  begin
    if (ATemplate[LI] = '{') and (LI < LLen) then
    begin
      if ATemplate[LI + 1] = '@' then
      begin
        // {@attr_name} — attribute interpolation
        Inc(LI, 2); // skip {  @
        LExpr := '';
        while (LI <= LLen) and (ATemplate[LI] <> '}') do
        begin
          LExpr := LExpr + ATemplate[LI];
          Inc(LI);
        end;
        Inc(LI); // skip }
        // Read attribute from current node
        if (FNode <> nil) and FNode.GetAttr(LExpr, LAttr) then
          Result := Result + LAttr.AsString
        else
          Result := Result + '';
      end
      else
      begin
        // {var_name} — variable interpolation
        Inc(LI); // skip {
        LExpr := '';
        LDepth := 1;
        while (LI <= LLen) and (LDepth > 0) do
        begin
          if ATemplate[LI] = '{' then Inc(LDepth)
          else if ATemplate[LI] = '}' then Dec(LDepth);
          if LDepth > 0 then
          begin
            LExpr := LExpr + ATemplate[LI];
            Inc(LI);
          end
          else
            Inc(LI); // skip closing }
        end;
        // Look up variable
        if FEnv.ContainsKey(LExpr) then
          Result := Result + ResolveStr(FEnv[LExpr])
        else
          Result := Result + '';
      end;
    end
    else
    begin
      Result := Result + ATemplate[LI];
      Inc(LI);
    end;
  end;
end;

// =========================================================================
// INTERPRETER — CONSTRUCTOR / DESTRUCTOR
// =========================================================================

constructor TMetamorfScriptInterp.Create(
  const ACustomConfig: TLangConfig;
  const AStore:        IMetamorfScriptStore;
  const APipeline:     TMetamorfLangPipelineCallbacks);
begin
  inherited Create();
  FCustomConfig := ACustomConfig;
  FStore        := AStore;
  FPipeline     := APipeline;
  FContextKind  := sckNone;
  FEnv          := TDictionary<string, TScriptValue>.Create();
  FParser       := nil;
  FLeftNode     := nil;
  FSemantic     := nil;
  FIR           := nil;
  FNode         := nil;
  FResultNode   := nil;
  FNodeKind     := '';
end;

destructor TMetamorfScriptInterp.Destroy();
begin
  FreeAndNil(FEnv);
  inherited Destroy();
end;

// =========================================================================
// INTERPRETER — CONTEXT SETTERS
// =========================================================================

procedure TMetamorfScriptInterp.SetEmitContext(const AIR: TIRBase;
  const ANode: TASTNodeBase);
begin
  FContextKind := sckEmit;
  FIR          := AIR;
  FNode        := ANode;
end;

procedure TMetamorfScriptInterp.SetSemanticContext(
  const ASemantic: TSemanticBase;
  const ANode: TASTNodeBase);
begin
  FContextKind := sckSemantic;
  FSemantic    := ASemantic;
  FNode        := ANode;
end;

// =========================================================================
// INTERPRETER — BLOCK / STATEMENT EXECUTION
// =========================================================================

procedure TMetamorfScriptInterp.ExecBlock(const ABlock: TASTNodeBase);
var
  LI: Integer;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
    ExecStmt(ABlock.GetChild(LI));
end;

procedure TMetamorfScriptInterp.ExecStmt(const AStmt: TASTNodeBase);
var
  LKind:           string;
  LVal:            TScriptValue;
  LAttr:           TValue;
  LName:           string;
  LI:              Integer;
  LFoundNode:      TASTNodeBase;
  LNodeKindTarget: string;
  LIsMany:         Boolean;
  LContainer:      TASTNode;
  LUntilKinds:     string;
  LStopLoop:       Boolean;
  LSavedLine:      Integer;
  LSavedCol:       Integer;
begin
  LKind := AStmt.GetNodeKind();

  // --- let name = expr; ---
  if LKind = 'stmt.let' then
  begin
    AStmt.GetAttr('name', LAttr);
    LName := LAttr.AsString;
    LVal  := EvalExpr(AStmt.GetChild(0));
    FEnv.AddOrSetValue(LName, LVal);
  end

  // --- name = expr; ---
  else if LKind = 'stmt.assign' then
  begin
    LVal := EvalExpr(AStmt.GetChild(0)); // LHS
    LName := ResolveStr(LVal);
    LVal := EvalExpr(AStmt.GetChild(1)); // RHS
    FEnv.AddOrSetValue(LName, LVal);
  end

  // --- if cond { } else { } ---
  else if LKind = 'stmt.if' then
  begin
    // Child 0 = condition wrapper, child 1 = then block, child 2+ = else/elseif
    LVal := EvalExpr(AStmt.GetChild(0).GetChild(0));
    if ResolveBool(LVal) then
      ExecBlock(AStmt.GetChild(1))
    else if AStmt.ChildCount() > 2 then
    begin
      // Child 2 is either an else block or a nested stmt.if
      if AStmt.GetChild(2).GetNodeKind() = 'stmt.if' then
        ExecStmt(AStmt.GetChild(2))
      else
        ExecBlock(AStmt.GetChild(2));
    end;
  end

  // --- while cond { } ---
  else if LKind = 'stmt.while' then
  begin
    LSavedLine := -1;
    LSavedCol  := -1;
    while ResolveBool(EvalExpr(AStmt.GetChild(0))) do
    begin
      // Guard: in parse context, detect no-progress to prevent infinite loops
      if FParser <> nil then
        LSavedLine := FParser.CurrentToken().Line;
      if FParser <> nil then
        LSavedCol := FParser.CurrentToken().Column;
      ExecBlock(AStmt.GetChild(1));
      if (FParser <> nil) and
         (FParser.CurrentToken().Line = LSavedLine) and
         (FParser.CurrentToken().Column = LSavedCol) then
        Break;
    end;
  end

  // --- for var in expr { } ---
  else if LKind = 'stmt.for' then
  begin
    AStmt.GetAttr('var_name', LAttr);
    LName := LAttr.AsString;
    LVal  := EvalExpr(AStmt.GetChild(0));
    if LVal.Kind = svkNode then
    begin
      for LI := 0 to LVal.NodeVal.ChildCount() - 1 do
      begin
        FEnv.AddOrSetValue(LName, MakeNode(LVal.NodeVal.GetChild(LI)));
        ExecBlock(AStmt.GetChild(1));
      end;
    end;
  end

  // --- match expr { patterns } ---
  else if LKind = 'stmt.match' then
  begin
    LVal := EvalExpr(AStmt.GetChild(0));
    for LI := 1 to AStmt.ChildCount() - 1 do
    begin
      // Each arm is stmt.match_arm
      // TODO: pattern matching evaluation
      ExecBlock(AStmt.GetChild(LI).GetChild(
        AStmt.GetChild(LI).ChildCount() - 1));
      Break; // first match wins (placeholder)
    end;
  end

  // --- guard expr { } ---
  else if LKind = 'stmt.guard' then
  begin
    LVal := EvalExpr(AStmt.GetChild(0));
    if ResolveBool(LVal) then
      ExecBlock(AStmt.GetChild(1));
  end

  // --- return [expr]; ---
  else if LKind = 'stmt.return' then
  begin
    // For now, just evaluate the expression if present
    if AStmt.ChildCount() > 0 then
      LVal := EvalExpr(AStmt.GetChild(0));
    // TODO: proper early exit mechanism
  end

  // --- visit target; ---
  else if LKind = 'stmt.visit' then
  begin
    if FContextKind = sckEmit then
    begin
      AStmt.GetAttr('target', LAttr);
      LName := LAttr.AsString;
      if LName = 'children' then
        FIR.EmitChildren(FNode)
      else if LName = 'child' then
      begin
        LVal := EvalExpr(AStmt.GetChild(0));
        FIR.EmitNode(FNode.GetChild(ResolveInt(LVal)));
      end
      else if LName = 'attr' then
      begin
        // Extract attribute name directly from expr.attr_access child
        // Don't EvalExpr — that reads the value, we need the name
        if (AStmt.ChildCount() > 0) and
           (AStmt.GetChild(0).GetNodeKind() = 'expr.attr_access') then
        begin
          AStmt.GetChild(0).GetAttr('name', LAttr);
          LName := LAttr.AsString;
          if FNode.GetAttr(LName, LAttr) then
          begin
            if LAttr.IsObject and (LAttr.AsObject is TASTNodeBase) then
              FIR.EmitNode(TASTNodeBase(LAttr.AsObject));
          end;
        end;
      end
      else if (LName = 'expr') and (AStmt.ChildCount() > 0) then
      begin
        LVal := EvalExpr(AStmt.GetChild(0));
        if LVal.Kind = svkNode then
          FIR.EmitNode(LVal.NodeVal);
      end;
    end
    else if FContextKind = sckSemantic then
    begin
      AStmt.GetAttr('target', LAttr);
      LName := LAttr.AsString;
      if LName = 'children' then
        FSemantic.VisitChildren(FNode)
      else if LName = 'child' then
      begin
        LVal := EvalExpr(AStmt.GetChild(0));
        FSemantic.VisitNode(FNode.GetChild(ResolveInt(LVal)));
      end;
    end;
  end

  // --- emit [to section:] expr; ---
  else if LKind = 'stmt.emit_to' then
  begin
    if FContextKind = sckEmit then
    begin
      LVal := EvalExpr(AStmt.GetChild(0));
      LName := InterpolateString(ResolveStr(LVal));
      if AStmt.GetAttr('section', LAttr) then
      begin
        // Emit to named section — uses EmitLine (adds newline)
        if LAttr.AsString = 'header' then
          FIR.EmitLine(LName, sfHeader)
        else
          FIR.EmitLine(LName, sfSource);
      end
      else
        // Bare emit — inline text, no newline (for building expressions)
        FIR.Emit(LName);
    end;
  end

  // --- indent { } ---
  else if LKind = 'stmt.indent' then
  begin
    if FContextKind = sckEmit then
    begin
      FIR.IndentIn();
      try
        ExecBlock(AStmt.GetChild(0));
      finally
        FIR.IndentOut();
      end;
    end;
  end

  // --- declare @name as kind typed type; ---
  else if LKind = 'stmt.declare' then
  begin
    if FContextKind = sckSemantic then
    begin
      LVal := EvalExpr(AStmt.GetChild(0));
      LName := ResolveStr(LVal);
      FSemantic.DeclareSymbol(LName, FNode);
    end;
  end

  // --- lookup @name or { error } ---
  else if LKind = 'stmt.lookup' then
  begin
    if FContextKind = sckSemantic then
    begin
      LVal := EvalExpr(AStmt.GetChild(0));
      LName := ResolveStr(LVal);
      if not FSemantic.LookupSymbol(LName, LFoundNode) then
      begin
        // Execute the 'or' block if present
        if AStmt.ChildCount() > 1 then
          ExecBlock(AStmt.GetChild(1));
      end;
    end;
  end

  // --- scope expr { } ---
  else if LKind = 'stmt.scope' then
  begin
    if FContextKind = sckSemantic then
    begin
      LVal := EvalExpr(AStmt.GetChild(0));
      LName := ResolveStr(LVal);
      FSemantic.PushScope(LName, Default(TToken));
      try
        ExecBlock(AStmt.GetChild(1));
      finally
        FSemantic.PopScope(Default(TToken));
      end;
    end;
  end

  // --- set @attr = expr; ---
  else if LKind = 'stmt.set_attr' then
  begin
    LVal := EvalExpr(AStmt.GetChild(1));
    // Get the attribute name from the attr_access child
    if AStmt.GetChild(0).GetNodeKind() = 'expr.attr_access' then
    begin
      AStmt.GetChild(0).GetAttr('name', LAttr);
      LName := LAttr.AsString;
      if FNode <> nil then
        (FNode as TASTNode).SetAttr(LName,
          TValue.From<string>(ResolveStr(LVal)));
    end;
  end

  // --- error/warning/hint/note/info expr; ---
  else if LKind = 'stmt.diagnostic' then
  begin
    AStmt.GetAttr('level', LAttr);
    LName := LAttr.AsString;
    LVal  := EvalExpr(AStmt.GetChild(0));
    if FContextKind = sckSemantic then
    begin
      if LName = 'error' then
        FSemantic.AddSemanticError(FNode, 'U000',
          InterpolateString(ResolveStr(LVal)));
    end;
  end

  // --- expression statement (function call) ---
  else if LKind = 'stmt.expr' then
  begin
    EvalExpr(AStmt.GetChild(0));
  end

  // --- try { } recover { } ---
  else if LKind = 'stmt.try_recover' then
  begin
    try
      ExecBlock(AStmt.GetChild(0));
    except
      on E: Exception do
        ExecBlock(AStmt.GetChild(1));
    end;
  end

  // --- Parse context: expect token_kind; ---
  else if LKind = 'stmt.expect' then
  begin
    if FContextKind = sckParse then
    begin
      if AStmt.GetAttr('token_kind', LAttr) then
      begin
        LName := LAttr.AsString;
        // If this is the first expect AND it matches the trigger,
        // the parser already matched it to dispatch here — just consume.
        FParser.Expect(LName);
      end;
      // Capture to attribute if specified
      if AStmt.GetAttr('capture_attr', LAttr) then
      begin
        // The token was already consumed by Expect — nothing to capture
        // Expect doesn't return the token. For capture, use consume.
      end;
    end;
  end

  // --- Parse context: consume token_kind -> @attr; ---
  else if LKind = 'stmt.consume' then
  begin
    if FContextKind = sckParse then
    begin
      if AStmt.GetAttr('token_kind', LAttr) then
      begin
        LName := LAttr.AsString;
        // Verify current token matches, then consume
        if FParser.Check(LName) then
        begin
          LVal := MakeStr(FParser.CurrentToken().Text);
          FParser.Consume();
        end
        else
        begin
          FParser.Expect(LName); // will report error
          LVal := MakeStr('');
        end;
      end
      else if AStmt.ChildCount() > 0 then
      begin
        // List of token kinds [a.b, c.d] — match any
        LVal := MakeStr(FParser.CurrentToken().Text);
        FParser.Consume();
      end
      else
      begin
        LVal := MakeStr(FParser.CurrentToken().Text);
        FParser.Consume();
      end;
      // Store captured value as attribute on the result node
      if AStmt.GetAttr('capture_attr', LAttr) then
      begin
        LName := LAttr.AsString;
        if FResultNode <> nil then
          FResultNode.SetAttr(LName, TValue.From<string>(ResolveStr(LVal)));
      end;
    end;
  end

  // --- Parse context: parse [many] kind -> @attr; ---
  else if LKind = 'stmt.parse_sub' then
  begin
    if FContextKind = sckParse then
    begin
      AStmt.GetAttr('capture_attr', LAttr);
      LName := LAttr.AsString;

      // Determine parse target: "expr" or "stmt"
      AStmt.GetAttr('node_kind', LAttr);
      LNodeKindTarget := LAttr.AsString;
      LIsMany := False;
      if AStmt.GetAttr('is_many', LAttr) then
        LIsMany := LAttr.AsBoolean;

      if LIsMany then
      begin
        // Read until_kinds if specified, else fall back to block close
        LUntilKinds := '';
        if AStmt.GetAttr('until_kinds', LAttr) then
          LUntilKinds := LAttr.AsString;

        LContainer := TASTNode.CreateNode('block', FParser.CurrentToken());
        LStopLoop := False;
        while not LStopLoop and not FParser.Check(KIND_EOF) do
        begin
          // Check termination conditions
          if LUntilKinds <> '' then
          begin
            // Check each comma-separated until kind
            LStopLoop := Pos(FParser.CurrentToken().Kind + ',', LUntilKinds + ',') > 0;
          end
          else
            LStopLoop := FParser.Check(FParser.GetBlockCloseKind());

          if not LStopLoop then
          begin
            LSavedLine := FParser.CurrentToken().Line;
            LSavedCol  := FParser.CurrentToken().Column;
            if LNodeKindTarget = 'stmt' then
              LContainer.AddChild(TASTNode(FParser.ParseStatement()))
            else
              LContainer.AddChild(TASTNode(FParser.ParseExpression(0)));
            // Guard: if parser didn't advance, break to prevent infinite loop
            if (FParser.CurrentToken().Line = LSavedLine) and
               (FParser.CurrentToken().Column = LSavedCol) then
              Break;
          end;
        end;
        if FResultNode <> nil then
        begin
          FResultNode.SetAttr(LName, TValue.From<TObject>(LContainer));
          FResultNode.AddChild(LContainer);
        end;
      end
      else
      begin
        // parse expr -> @x  or  parse stmt -> @x: single parse
        if LNodeKindTarget = 'stmt' then
          LVal := MakeNode(FParser.ParseStatement())
        else
          LVal := MakeNode(FParser.ParseExpression(0));
        if (FResultNode <> nil) and (LVal.Kind = svkNode) and (LVal.NodeVal <> nil) then
        begin
          FResultNode.SetAttr(LName, TValue.From<TObject>(LVal.NodeVal));
          FResultNode.AddChild(LVal.NodeVal as TASTNode);
        end;
      end;
    end;
  end

  // --- Parse context: optional { } ---
  else if LKind = 'stmt.optional' then
  begin
    if FContextKind = sckParse then
    begin
      // Try to execute the block; if expect/consume fails, that's okay
      try
        ExecBlock(AStmt.GetChild(0));
      except
        // Optional block failed — silently continue
      end;
    end;
  end;
end;

// =========================================================================
// INTERPRETER — EXPRESSION EVALUATION
// =========================================================================

function TMetamorfScriptInterp.EvalExpr(
  const AExpr: TASTNodeBase): TScriptValue;
var
  LKind:    string;
  LAttr:    TValue;
  LName:    string;
  LLeft:    TScriptValue;
  LRight:   TScriptValue;
  LArgs:    TArray<TScriptValue>;
  LI:       Integer;
begin
  LKind := AExpr.GetNodeKind();

  if LKind = 'expr.literal_string' then
  begin
    AExpr.GetAttr('value', LAttr);
    Result := MakeStr(LAttr.AsString);
  end

  else if LKind = 'expr.literal_int' then
  begin
    AExpr.GetAttr('value', LAttr);
    Result := MakeInt(LAttr.AsInt64);
  end

  else if LKind = 'expr.literal_bool' then
  begin
    AExpr.GetAttr('value', LAttr);
    Result := MakeBool(LAttr.AsBoolean);
  end

  else if LKind = 'expr.literal_nil' then
    Result := MakeNil()

  else if LKind = 'expr.attr_access' then
  begin
    AExpr.GetAttr('name', LAttr);
    LName := LAttr.AsString;
    if (FNode <> nil) and FNode.GetAttr(LName, LAttr) then
    begin
      if LAttr.IsType<Boolean> then
        Result := MakeBool(LAttr.AsBoolean)
      else if LAttr.IsType<Int64> then
        Result := MakeInt(LAttr.AsInt64)
      else if LAttr.IsType<Integer> then
        Result := MakeInt(LAttr.AsInteger)
      else if LAttr.IsObject then
      begin
        if LAttr.AsObject is TASTNodeBase then
          Result := MakeNode(TASTNodeBase(LAttr.AsObject))
        else
          Result := MakeNil();
      end
      else if LAttr.IsEmpty then
        Result := MakeNil()
      else
        Result := MakeStr(LAttr.AsString);
    end
    else
      Result := MakeNil();
  end

  else if LKind = 'expr.ident' then
  begin
    AExpr.GetAttr('name', LAttr);
    LName := LAttr.AsString;
    if FEnv.ContainsKey(LName) then
      Result := FEnv[LName]
    else
      Result := MakeNil();
  end

  else if LKind = 'expr.binary' then
  begin
    AExpr.GetAttr('operator', LAttr);
    LName  := LAttr.AsString;
    LLeft  := EvalExpr(AExpr.GetChild(0));
    LRight := EvalExpr(AExpr.GetChild(1));
    Result := EvalBinary(LName, LLeft, LRight);
  end

  else if LKind = 'expr.unary_not' then
  begin
    LLeft := EvalExpr(AExpr.GetChild(0));
    Result := MakeBool(not ResolveBool(LLeft));
  end

  else if LKind = 'expr.unary_minus' then
  begin
    LLeft := EvalExpr(AExpr.GetChild(0));
    Result := MakeInt(-ResolveInt(LLeft));
  end

  else if LKind = 'expr.call' then
  begin
    // Child 0 = callee, children 1..n = args
    // For identifier callees, use the name directly — don't eval (it's not in FEnv)
    if AExpr.GetChild(0).GetNodeKind() = 'expr.ident' then
    begin
      AExpr.GetChild(0).GetAttr('name', LAttr);
      LName := LAttr.AsString;
    end
    else
    begin
      LLeft := EvalExpr(AExpr.GetChild(0));
      LName := ResolveStr(LLeft);
    end;
    SetLength(LArgs, AExpr.ChildCount() - 1);
    for LI := 1 to AExpr.ChildCount() - 1 do
      LArgs[LI - 1] := EvalExpr(AExpr.GetChild(LI));
    Result := CallBuiltin(LName, LArgs);
  end

  else if LKind = 'expr.field_access' then
  begin
    LLeft := EvalExpr(AExpr.GetChild(0));
    AExpr.GetAttr('field', LAttr);
    LName := LAttr.AsString;
    // Field access on a node
    if (LLeft.Kind = svkNode) and (LLeft.NodeVal <> nil) then
    begin
      if LLeft.NodeVal.GetAttr(LName, LAttr) then
        Result := MakeStr(LAttr.AsString)
      else
        Result := MakeNil();
    end
    else
      Result := MakeNil();
  end

  else if LKind = 'expr.index' then
  begin
    LLeft  := EvalExpr(AExpr.GetChild(0));
    LRight := EvalExpr(AExpr.GetChild(1));
    if (LLeft.Kind = svkNode) and (LLeft.NodeVal <> nil) then
      Result := MakeNode(LLeft.NodeVal.GetChild(ResolveInt(LRight)))
    else
      Result := MakeNil();
  end

  else if LKind = 'expr.group' then
    Result := EvalExpr(AExpr.GetChild(0))

  else if LKind = 'expr.unary_not' then
    Result := MakeBool(not ResolveBool(EvalExpr(AExpr.GetChild(0))))

  else if LKind = 'expr.unary_minus' then
    Result := MakeInt(-ResolveInt(EvalExpr(AExpr.GetChild(0))))

  else
    Result := MakeNil();
end;

// =========================================================================
// INTERPRETER — BINARY OPERATORS
// =========================================================================

function TMetamorfScriptInterp.EvalBinary(const AOp: string;
  const ALeft, ARight: TScriptValue): TScriptValue;
begin
  // String concatenation with +
  if (AOp = '+') and
     ((ALeft.Kind = svkString) or (ARight.Kind = svkString)) then
    Result := MakeStr(ResolveStr(ALeft) + ResolveStr(ARight))

  // Arithmetic
  else if AOp = '+' then
    Result := MakeInt(ResolveInt(ALeft) + ResolveInt(ARight))
  else if AOp = '-' then
    Result := MakeInt(ResolveInt(ALeft) - ResolveInt(ARight))
  else if AOp = '*' then
    Result := MakeInt(ResolveInt(ALeft) * ResolveInt(ARight))
  else if AOp = '/' then
  begin
    if ResolveInt(ARight) = 0 then
      Result := MakeInt(0)
    else
      Result := MakeInt(ResolveInt(ALeft) div ResolveInt(ARight));
  end
  else if AOp = '%' then
  begin
    if ResolveInt(ARight) = 0 then
      Result := MakeInt(0)
    else
      Result := MakeInt(ResolveInt(ALeft) mod ResolveInt(ARight));
  end

  // Comparison — string comparison when either side is string
  else if AOp = '==' then
  begin
    if (ALeft.Kind = svkString) or (ARight.Kind = svkString) then
      Result := MakeBool(ResolveStr(ALeft) = ResolveStr(ARight))
    else
      Result := MakeBool(ResolveInt(ALeft) = ResolveInt(ARight));
  end
  else if AOp = '!=' then
  begin
    if (ALeft.Kind = svkString) or (ARight.Kind = svkString) then
      Result := MakeBool(ResolveStr(ALeft) <> ResolveStr(ARight))
    else
      Result := MakeBool(ResolveInt(ALeft) <> ResolveInt(ARight));
  end
  else if AOp = '<' then
    Result := MakeBool(ResolveInt(ALeft) < ResolveInt(ARight))
  else if AOp = '>' then
    Result := MakeBool(ResolveInt(ALeft) > ResolveInt(ARight))
  else if AOp = '<=' then
    Result := MakeBool(ResolveInt(ALeft) <= ResolveInt(ARight))
  else if AOp = '>=' then
    Result := MakeBool(ResolveInt(ALeft) >= ResolveInt(ARight))

  // Logical
  else if AOp = 'and' then
    Result := MakeBool(ResolveBool(ALeft) and ResolveBool(ARight))
  else if AOp = 'or' then
    Result := MakeBool(ResolveBool(ALeft) or ResolveBool(ARight))

  else
    Result := MakeNil();
end;

// =========================================================================
// INTERPRETER — BUILT-IN FUNCTIONS
// =========================================================================

function TMetamorfScriptInterp.CallBuiltin(const AName: string;
  const AArgs: TArray<TScriptValue>): TScriptValue;
begin
  if CallBuiltinCommon(AName, AArgs, Result) then Exit;
  if (FContextKind = sckEmit) and CallBuiltinEmit(AName, AArgs, Result) then Exit;
  if (FContextKind = sckSemantic) and CallBuiltinSemantic(AName, AArgs, Result) then Exit;
  Result := CallHelper(AName, AArgs);
end;

function TMetamorfScriptInterp.CallBuiltinCommon(const AName: string;
  const AArgs: TArray<TScriptValue>;
  out AResult: TScriptValue): Boolean;
var
  LTmpAttr: TValue;
begin
  Result := True;

  if AName = 'concat' then
  begin
    if Length(AArgs) >= 2 then
      AResult := MakeStr(ResolveStr(AArgs[0]) + ResolveStr(AArgs[1]))
    else
      AResult := MakeStr('');
  end
  else if AName = 'upper' then
    AResult := MakeStr(UpperCase(ResolveStr(AArgs[0])))
  else if AName = 'lower' then
    AResult := MakeStr(LowerCase(ResolveStr(AArgs[0])))
  else if AName = 'trim' then
    AResult := MakeStr(Trim(ResolveStr(AArgs[0])))
  else if AName = 'length' then
    AResult := MakeInt(Length(ResolveStr(AArgs[0])))
  else if AName = 'contains' then
    AResult := MakeBool(Pos(ResolveStr(AArgs[1]), ResolveStr(AArgs[0])) > 0)
  else if AName = 'starts_with' then
    AResult := MakeBool(ResolveStr(AArgs[0]).StartsWith(ResolveStr(AArgs[1])))
  else if AName = 'ends_with' then
    AResult := MakeBool(ResolveStr(AArgs[0]).EndsWith(ResolveStr(AArgs[1])))
  else if AName = 'replace' then
    AResult := MakeStr(StringReplace(ResolveStr(AArgs[0]),
      ResolveStr(AArgs[1]), ResolveStr(AArgs[2]), [rfReplaceAll]))
  else if AName = 'to_int' then
    AResult := MakeInt(StrToInt64Def(ResolveStr(AArgs[0]), 0))
  else if AName = 'to_string' then
    AResult := MakeStr(ResolveStr(AArgs[0]))
  else if AName = 'has_attr' then
  begin
    if FNode <> nil then
    begin
      AResult := MakeBool(FNode.GetAttr(ResolveStr(AArgs[0]), LTmpAttr));
    end
    else
      AResult := MakeBool(False);
  end
  else if AName = 'get_node_kind' then
  begin
    if (Length(AArgs) > 0) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      AResult := MakeStr(AArgs[0].NodeVal.GetNodeKind())
    else if FNode <> nil then
      AResult := MakeStr(FNode.GetNodeKind())
    else
      AResult := MakeStr('');
  end
  else if AName = 'child_count' then
  begin
    if (Length(AArgs) > 0) then
    begin
      if AArgs[0].Kind = svkNode then
        AResult := MakeInt(AArgs[0].NodeVal.ChildCount())
      else if (AArgs[0].Kind = svkString) and (FNode <> nil) then
      begin
        if FNode.GetAttr(ResolveStr(AArgs[0]), LTmpAttr) and
           LTmpAttr.IsObject and (LTmpAttr.AsObject is TASTNodeBase) then
          AResult := MakeInt(TASTNodeBase(LTmpAttr.AsObject).ChildCount())
        else
          AResult := MakeInt(0);
      end
      else
        AResult := MakeInt(0);
    end
    else if FNode <> nil then
      AResult := MakeInt(FNode.ChildCount())
    else
      AResult := MakeInt(0);
  end

  // Build system bridge
  else if AName = 'SetTarget' then
  begin
    if Assigned(FPipeline.OnSetPlatform) then
      FPipeline.OnSetPlatform(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetOptimize' then
  begin
    if Assigned(FPipeline.OnSetOptimize) then
      FPipeline.OnSetOptimize(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetSubsystem' then
  begin
    if Assigned(FPipeline.OnSetSubsystem) then
      FPipeline.OnSetSubsystem(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetVersionMajor' then
  begin
    if Assigned(FPipeline.OnSetVIMajor) then
      FPipeline.OnSetVIMajor(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetVersionMinor' then
  begin
    if Assigned(FPipeline.OnSetVIMinor) then
      FPipeline.OnSetVIMinor(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetVersionPatch' then
  begin
    if Assigned(FPipeline.OnSetVIPatch) then
      FPipeline.OnSetVIPatch(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetProductName' then
  begin
    if Assigned(FPipeline.OnSetVIProductName) then
      FPipeline.OnSetVIProductName(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetDescription' then
  begin
    if Assigned(FPipeline.OnSetVIDescription) then
      FPipeline.OnSetVIDescription(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetFilename' then
  begin
    if Assigned(FPipeline.OnSetVIFilename) then
      FPipeline.OnSetVIFilename(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetCompanyName' then
  begin
    if Assigned(FPipeline.OnSetVICompanyName) then
      FPipeline.OnSetVICompanyName(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetCopyright' then
  begin
    if Assigned(FPipeline.OnSetVICopyright) then
      FPipeline.OnSetVICopyright(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetExeIcon' then
  begin
    if Assigned(FPipeline.OnSetVIExeIcon) then
      FPipeline.OnSetVIExeIcon(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'SetAddVerInfo' then
  begin
    if Assigned(FPipeline.OnSetVIEnabled) then
      FPipeline.OnSetVIEnabled(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end

  // =====================================================================
  // Parse-context built-ins (manual parsing from rule bodies)
  // Names avoid Metamorf keyword conflicts (consume/expect/match are keywords)
  // =====================================================================

  else if AName = 'checkToken' then
  begin
    if FParser <> nil then
      AResult := MakeBool(FParser.Check(ResolveStr(AArgs[0])))
    else
      AResult := MakeBool(False);
  end
  else if AName = 'matchToken' then
  begin
    if FParser <> nil then
      AResult := MakeBool(FParser.Match(ResolveStr(AArgs[0])))
    else
      AResult := MakeBool(False);
  end
  else if AName = 'advance' then
  begin
    if FParser <> nil then
    begin
      AResult := MakeStr(FParser.CurrentToken().Text);
      FParser.Consume();
    end
    else
      AResult := MakeStr('');
  end
  else if AName = 'requireToken' then
  begin
    if FParser <> nil then
      FParser.Expect(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'currentText' then
  begin
    if FParser <> nil then
      AResult := MakeStr(FParser.CurrentToken().Text)
    else
      AResult := MakeStr('');
  end
  else if AName = 'currentKind' then
  begin
    if FParser <> nil then
      AResult := MakeStr(FParser.CurrentToken().Kind)
    else
      AResult := MakeStr('');
  end
  else if AName = 'peekKind' then
  begin
    if (FParser <> nil) and (Length(AArgs) > 0) then
      AResult := MakeStr(FParser.PeekToken(ResolveInt(AArgs[0])).Kind)
    else if FParser <> nil then
      AResult := MakeStr(FParser.PeekToken(1).Kind)
    else
      AResult := MakeStr('');
  end
  else if AName = 'parseExpr' then
  begin
    if FParser <> nil then
    begin
      if Length(AArgs) > 0 then
        AResult := MakeNode(FParser.ParseExpression(ResolveInt(AArgs[0])))
      else
        AResult := MakeNode(FParser.ParseExpression(0));
    end
    else
      AResult := MakeNil();
  end
  else if AName = 'parseStmt' then
  begin
    if FParser <> nil then
      AResult := MakeNode(FParser.ParseStatement())
    else
      AResult := MakeNil();
  end
  else if AName = 'createNode' then
  begin
    if (FParser <> nil) and (Length(AArgs) > 0) then
      AResult := MakeNode(FParser.CreateNode(ResolveStr(AArgs[0])))
    else if FParser <> nil then
      AResult := MakeNode(FParser.CreateNode())
    else
      AResult := MakeNil();
  end
  else if AName = 'getResultNode' then
  begin
    if FResultNode <> nil then
      AResult := MakeNode(FResultNode)
    else
      AResult := MakeNil();
  end

  // =====================================================================
  // Node manipulation (works in all contexts)
  // =====================================================================

  else if AName = 'addChild' then
  begin
    if (Length(AArgs) >= 2) and (AArgs[0].Kind = svkNode) and
       (AArgs[1].Kind = svkNode) and (AArgs[0].NodeVal <> nil) and
       (AArgs[1].NodeVal <> nil) then
      (AArgs[0].NodeVal as TASTNode).AddChild(AArgs[1].NodeVal as TASTNode);
    AResult := MakeNil();
  end
  else if AName = 'setAttr' then
  begin
    if (Length(AArgs) >= 3) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      (AArgs[0].NodeVal as TASTNode).SetAttr(
        ResolveStr(AArgs[1]), TValue.From<string>(ResolveStr(AArgs[2])));
    AResult := MakeNil();
  end
  else if AName = 'getAttr' then
  begin
    if (Length(AArgs) >= 2) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
    begin
      if AArgs[0].NodeVal.GetAttr(ResolveStr(AArgs[1]), LTmpAttr) then
        AResult := MakeStr(LTmpAttr.AsString)
      else
        AResult := MakeStr('');
    end
    else if (Length(AArgs) >= 1) and (FNode <> nil) then
    begin
      if FNode.GetAttr(ResolveStr(AArgs[0]), LTmpAttr) then
        AResult := MakeStr(LTmpAttr.AsString)
      else
        AResult := MakeStr('');
    end
    else
      AResult := MakeStr('');
  end
  else if AName = 'getChild' then
  begin
    if (Length(AArgs) >= 2) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      AResult := MakeNode(AArgs[0].NodeVal.GetChild(ResolveInt(AArgs[1])))
    else
      AResult := MakeNil();
  end
  else if AName = 'nodeKind' then
  begin
    if (Length(AArgs) > 0) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      AResult := MakeStr(AArgs[0].NodeVal.GetNodeKind())
    else if FNode <> nil then
      AResult := MakeStr(FNode.GetNodeKind())
    else
      AResult := MakeStr('');
  end
  else if AName = 'childCount' then
  begin
    if (Length(AArgs) > 0) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      AResult := MakeInt(AArgs[0].NodeVal.ChildCount())
    else if FNode <> nil then
      AResult := MakeInt(FNode.ChildCount())
    else
      AResult := MakeInt(0);
  end

  else
    Result := False;
end;

function TMetamorfScriptInterp.CallBuiltinEmit(const AName: string;
  const AArgs: TArray<TScriptValue>;
  out AResult: TScriptValue): Boolean;
var
  LTarget:  TSourceFile;
  LArgs:    TArray<string>;
  LI:       Integer;
  LTmpAttr: TValue;
begin
  Result := True;

  // =====================================================================
  // IR Statement Builders (call FIR methods, return nil)
  // =====================================================================

  if AName = 'func' then
  begin
    FIR.Func(ResolveStr(AArgs[0]), ResolveStr(AArgs[1]));
    AResult := MakeNil();
  end
  else if AName = 'param' then
  begin
    FIR.Param(ResolveStr(AArgs[0]), ResolveStr(AArgs[1]));
    AResult := MakeNil();
  end
  else if AName = 'endFunc' then
  begin
    FIR.EndFunc();
    AResult := MakeNil();
  end
  else if AName = 'declVar' then
  begin
    if Length(AArgs) >= 3 then
      FIR.DeclVar(ResolveStr(AArgs[0]), ResolveStr(AArgs[1]), ResolveStr(AArgs[2]))
    else
      FIR.DeclVar(ResolveStr(AArgs[0]), ResolveStr(AArgs[1]));
    AResult := MakeNil();
  end
  else if AName = 'assign' then
  begin
    FIR.Assign(ResolveStr(AArgs[0]), ResolveStr(AArgs[1]));
    AResult := MakeNil();
  end
  else if AName = 'stmt' then
  begin
    FIR.Stmt(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'ifStmt' then
  begin
    FIR.IfStmt(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'elseIfStmt' then
  begin
    FIR.ElseIfStmt(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'elseStmt' then
  begin
    FIR.ElseStmt();
    AResult := MakeNil();
  end
  else if AName = 'endIf' then
  begin
    FIR.EndIf();
    AResult := MakeNil();
  end
  else if AName = 'whileStmt' then
  begin
    FIR.WhileStmt(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'endWhile' then
  begin
    FIR.EndWhile();
    AResult := MakeNil();
  end
  else if AName = 'forStmt' then
  begin
    FIR.ForStmt(ResolveStr(AArgs[0]), ResolveStr(AArgs[1]),
      ResolveStr(AArgs[2]), ResolveStr(AArgs[3]));
    AResult := MakeNil();
  end
  else if AName = 'endFor' then
  begin
    FIR.EndFor();
    AResult := MakeNil();
  end
  else if AName = 'returnVal' then
  begin
    FIR.Return(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'returnVoid' then
  begin
    FIR.Return();
    AResult := MakeNil();
  end
  else if AName = 'breakStmt' then
  begin
    FIR.BreakStmt();
    AResult := MakeNil();
  end
  else if AName = 'continueStmt' then
  begin
    FIR.ContinueStmt();
    AResult := MakeNil();
  end
  else if AName = 'blankLine' then
  begin
    FIR.BlankLine();
    AResult := MakeNil();
  end
  else if AName = 'include' then
  begin
    // include(name, target) — target is target.header or target.source
    LTarget := sfHeader;
    if (Length(AArgs) >= 2) then
    begin
      if ResolveStr(AArgs[1]) = 'target.source' then
        LTarget := sfSource;
    end;
    FIR.Include(ResolveStr(AArgs[0]), LTarget);
    AResult := MakeNil();
  end
  else if AName = 'emitLine' then
  begin
    // emitLine(text[, target])
    LTarget := sfSource;
    if (Length(AArgs) >= 2) then
    begin
      if ResolveStr(AArgs[1]) = 'target.header' then
        LTarget := sfHeader;
    end;
    FIR.EmitLine(ResolveStr(AArgs[0]), LTarget);
    AResult := MakeNil();
  end
  else if AName = 'indentIn' then
  begin
    FIR.IndentIn();
    AResult := MakeNil();
  end
  else if AName = 'indentOut' then
  begin
    FIR.IndentOut();
    AResult := MakeNil();
  end

  // =====================================================================
  // AST Dispatch
  // =====================================================================

  else if AName = 'emitNode' then
  begin
    if (Length(AArgs) > 0) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      FIR.EmitNode(AArgs[0].NodeVal);
    AResult := MakeNil();
  end
  else if AName = 'emitChildren' then
  begin
    if (Length(AArgs) > 0) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      FIR.EmitChildren(AArgs[0].NodeVal);
    AResult := MakeNil();
  end

  // =====================================================================
  // IR Expression Builders (return string)
  // =====================================================================

  else if AName = 'get' then
    AResult := MakeStr(FIR.Get(ResolveStr(AArgs[0])))
  else if AName = 'neg' then
    AResult := MakeStr(FIR.Neg(ResolveStr(AArgs[0])))
  else if AName = 'nullLit' then
    AResult := MakeStr(FIR.Null())
  else if AName = 'invoke' then
  begin
    // invoke(funcName, arg1, arg2, ...) — variadic
    SetLength(LArgs, Length(AArgs) - 1);
    for LI := 1 to Length(AArgs) - 1 do
      LArgs[LI - 1] := ResolveStr(AArgs[LI]);
    AResult := MakeStr(FIR.Invoke(ResolveStr(AArgs[0]), LArgs));
  end

  // =====================================================================
  // Config Utilities (ExprToString, TypeTextToKind, TypeToIR)
  // =====================================================================

  else if AName = 'exprToString' then
  begin
    if (Length(AArgs) > 0) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      AResult := MakeStr(FCustomConfig.ExprToString(AArgs[0].NodeVal))
    else
      AResult := MakeStr('');
  end
  else if AName = 'typeTextToKind' then
    AResult := MakeStr(FCustomConfig.TypeTextToKind(ResolveStr(AArgs[0])))
  else if AName = 'typeToIR' then
    AResult := MakeStr(FCustomConfig.TypeToIR(ResolveStr(AArgs[0])))

  // =====================================================================
  // Node Utilities (aliases used by .parse/.pax emit handlers)
  // =====================================================================

  else if AName = 'nodeKind' then
  begin
    if (Length(AArgs) > 0) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      AResult := MakeStr(AArgs[0].NodeVal.GetNodeKind())
    else if FNode <> nil then
      AResult := MakeStr(FNode.GetNodeKind())
    else
      AResult := MakeStr('');
  end
  else if AName = 'getAttr' then
  begin
    // getAttr(node, name) or getAttr(name) — read attribute
    if (Length(AArgs) >= 2) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
    begin
      if AArgs[0].NodeVal.GetAttr(ResolveStr(AArgs[1]), LTmpAttr) then
        AResult := MakeStr(LTmpAttr.AsString)
      else
        AResult := MakeStr('');
    end
    else if (Length(AArgs) >= 1) and (FNode <> nil) then
    begin
      if FNode.GetAttr(ResolveStr(AArgs[0]), LTmpAttr) then
        AResult := MakeStr(LTmpAttr.AsString)
      else
        AResult := MakeStr('');
    end
    else
      AResult := MakeStr('');
  end
  else if AName = 'setAttr' then
  begin
    // setAttr(node, key, value)
    if (Length(AArgs) >= 3) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      (AArgs[0].NodeVal as TASTNode).SetAttr(
        ResolveStr(AArgs[1]), TValue.From<string>(ResolveStr(AArgs[2])));
    AResult := MakeNil();
  end
  else if AName = 'getChild' then
  begin
    if (Length(AArgs) >= 2) and (AArgs[0].Kind = svkNode) and
       (AArgs[0].NodeVal <> nil) then
      AResult := MakeNode(AArgs[0].NodeVal.GetChild(ResolveInt(AArgs[1])))
    else
      AResult := MakeNil();
  end
  else if AName = 'addChild' then
  begin
    if (Length(AArgs) >= 2) and (AArgs[0].Kind = svkNode) and
       (AArgs[1].Kind = svkNode) then
      (AArgs[0].NodeVal as TASTNode).AddChild(AArgs[1].NodeVal as TASTNode);
    AResult := MakeNil();
  end

  // =====================================================================
  // Build System Bridge (lowercase aliases used by .parse/.pax files)
  // =====================================================================

  else if AName = 'setPlatform' then
  begin
    if Assigned(FPipeline.OnSetPlatform) then
      FPipeline.OnSetPlatform(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'setBuildMode' then
  begin
    if Assigned(FPipeline.OnSetBuildMode) then
      FPipeline.OnSetBuildMode(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'setOptimize' then
  begin
    if Assigned(FPipeline.OnSetOptimize) then
      FPipeline.OnSetOptimize(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'setSubsystem' then
  begin
    if Assigned(FPipeline.OnSetSubsystem) then
      FPipeline.OnSetSubsystem(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'addSourceFile' then
  begin
    if Assigned(FPipeline.OnAddSourceFile) then
      FPipeline.OnAddSourceFile(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'addIncludePath' then
  begin
    if Assigned(FPipeline.OnAddIncludePath) then
      FPipeline.OnAddIncludePath(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'addLibraryPath' then
  begin
    if Assigned(FPipeline.OnAddLibraryPath) then
      FPipeline.OnAddLibraryPath(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'addLinkLibrary' then
  begin
    if Assigned(FPipeline.OnAddLinkLibrary) then
      FPipeline.OnAddLinkLibrary(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'addCopyDLL' then
  begin
    if Assigned(FPipeline.OnAddCopyDLL) then
      FPipeline.OnAddCopyDLL(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viEnabled' then
  begin
    if Assigned(FPipeline.OnSetVIEnabled) then
      FPipeline.OnSetVIEnabled(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viExeIcon' then
  begin
    if Assigned(FPipeline.OnSetVIExeIcon) then
      FPipeline.OnSetVIExeIcon(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viMajor' then
  begin
    if Assigned(FPipeline.OnSetVIMajor) then
      FPipeline.OnSetVIMajor(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viMinor' then
  begin
    if Assigned(FPipeline.OnSetVIMinor) then
      FPipeline.OnSetVIMinor(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viPatch' then
  begin
    if Assigned(FPipeline.OnSetVIPatch) then
      FPipeline.OnSetVIPatch(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viProductName' then
  begin
    if Assigned(FPipeline.OnSetVIProductName) then
      FPipeline.OnSetVIProductName(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viDescription' then
  begin
    if Assigned(FPipeline.OnSetVIDescription) then
      FPipeline.OnSetVIDescription(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viFilename' then
  begin
    if Assigned(FPipeline.OnSetVIFilename) then
      FPipeline.OnSetVIFilename(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viCompanyName' then
  begin
    if Assigned(FPipeline.OnSetVICompanyName) then
      FPipeline.OnSetVICompanyName(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end
  else if AName = 'viCopyright' then
  begin
    if Assigned(FPipeline.OnSetVICopyright) then
      FPipeline.OnSetVICopyright(ResolveStr(AArgs[0]));
    AResult := MakeNil();
  end

  else
    Result := False;
end;

function TMetamorfScriptInterp.CallBuiltinSemantic(const AName: string;
  const AArgs: TArray<TScriptValue>;
  out AResult: TScriptValue): Boolean;
begin
  Result := False;
  // Semantic-context-specific builtins can be added here
end;

function TMetamorfScriptInterp.CallHelper(const AName: string;
  const AArgs: TArray<TScriptValue>): TScriptValue;
var
  LFuncNode: TASTNodeBase;
  LInterp:   TMetamorfScriptInterp;
  LI:        Integer;
  LParamNode: TASTNodeBase;
  LAttr:     TValue;
  LParamName: string;
begin
  if FStore.GetHelperFuncs().TryGetValue(AName, LFuncNode) then
  begin
    LInterp := TMetamorfScriptInterp.Create(FCustomConfig, FStore, FPipeline);
    try
      LInterp.FContextKind := FContextKind;
      LInterp.FIR          := FIR;
      LInterp.FSemantic    := FSemantic;
      LInterp.FNode        := FNode;

      // Bind arguments to parameter names
      for LI := 0 to LFuncNode.ChildCount() - 2 do // last child is the body block
      begin
        LParamNode := LFuncNode.GetChild(LI);
        if LParamNode.GetNodeKind() = 'meta.param_decl' then
        begin
          LParamNode.GetAttr('name', LAttr);
          LParamName := LAttr.AsString;
          if LI < Length(AArgs) then
            LInterp.FEnv.AddOrSetValue(LParamName, AArgs[LI]);
        end;
      end;

      // Execute the body (last child)
      LInterp.ExecBlock(LFuncNode.GetChild(LFuncNode.ChildCount() - 1));

      // Return value from 'result' variable if set
      if LInterp.FEnv.ContainsKey('result') then
        Result := LInterp.FEnv['result']
      else
        Result := MakeNil();
    finally
      LInterp.Free();
    end;
  end
  else
    Result := MakeNil();
end;

// =========================================================================
// UTILITIES
// =========================================================================

function StripQuotes(const AText: string): string;
begin
  if (Length(AText) >= 2) and (AText[1] = '"') and
     (AText[Length(AText)] = '"') then
    Result := Copy(AText, 2, Length(AText) - 2)
  else
    Result := AText;
end;

// =========================================================================
// REGISTRATION — LEXER SECTIONS
// =========================================================================

procedure RegisterLexerSections(
  const AMetamorf      : TMetamorf;
  const ACustomMetamorf: TMetamorf;
  const AStore:       IMetamorfScriptStore);
begin
  // Walk meta.tokens_block: register tokens on ACustomMetamorf
  AMetamorf.Config().RegisterEmitter('meta.tokens_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI:       Integer;
      LChild:   TASTNodeBase;
      LAttr:    TValue;
      LKind:    string;
      LPattern: string;
      LCategory: string;
      LBlockOpen: string;
    begin
      LBlockOpen := '';
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        LChild := ANode.GetChild(LI);
        if LChild.GetNodeKind() = 'meta.token_decl' then
        begin
          LChild.GetAttr('kind', LAttr);
          LKind := LAttr.AsString;
          LChild.GetAttr('pattern', LAttr);
          LPattern := StripQuotes(LAttr.AsString);
          LChild.GetAttr('category', LAttr);
          LCategory := LAttr.AsString;

          // Route to correct Config method based on category
          if LCategory = 'keyword' then
            ACustomMetamorf.Config().AddKeyword(LPattern, LKind)
          else if LCategory = 'op' then
            ACustomMetamorf.Config().AddOperator(LPattern, LKind)
          else if LCategory = 'delimiter' then
            ACustomMetamorf.Config().AddOperator(LPattern, LKind)
          else if LCategory = 'directive' then
            ACustomMetamorf.Config().AddOperator(LPattern, LKind)
          else if (LCategory = 'comment') then
          begin
            LChild.GetAttr('name', LAttr);
            if LAttr.AsString = 'line' then
              ACustomMetamorf.Config().AddLineComment(LPattern)
            else if LAttr.AsString = 'block_open' then
              LBlockOpen := LPattern
            else if LAttr.AsString = 'block_close' then
            begin
              if LBlockOpen <> '' then
                ACustomMetamorf.Config().AddBlockComment(LBlockOpen, LPattern);
              LBlockOpen := '';
            end;
          end
          else if LCategory = 'string' then
          begin
            // String style: pattern is the delimiter char, used as both open/close
            ACustomMetamorf.Config().AddStringStyle(LPattern, LPattern, LKind, True);
          end
        end;
      end;

      // Auto-register standard literal prefix handlers (identifier, integer,
      // real, string) so user .pax files don't need to define them manually.
      ACustomMetamorf.Config().RegisterLiteralPrefixes();
    end);
end;

// =========================================================================
// REGISTRATION — GRAMMAR RULES
// =========================================================================

procedure RegisterGrammarRules(
  const AMetamorf      : TMetamorf;
  const ACustomMetamorf: TMetamorf;
  const AStore:       IMetamorfScriptStore;
  const APipeline:    TMetamorfLangPipelineCallbacks);
begin
  AMetamorf.Config().RegisterEmitter('meta.rule_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LAttr:        TValue;
      LNodeKind:    string;
      LBlockNode:   TASTNodeBase;
      LFirstStmt:   TASTNodeBase;
      LTriggerKind: string;
      LAssoc:       string;
      LPower:       Integer;
      LIsInfix:     Boolean;
      LIsExpr:      Boolean;
      LTriggers:    TArray<string>;
      LConsumeNode: TASTNodeBase;
      LJ:           Integer;
      LTrigIdx:     Integer;
    begin
      ANode.GetAttr('node_kind', LAttr);
      LNodeKind  := LAttr.AsString;
      LBlockNode := ANode.GetChild(0);

      // Determine rule type from attributes and node kind prefix
      LPower := 0;
      LIsInfix := ANode.GetAttr('assoc', LAttr);
      if LIsInfix then
      begin
        LAssoc := LAttr.AsString;
        ANode.GetAttr('power', LAttr);
        LPower := LAttr.AsInteger;
      end;
      LIsExpr := LNodeKind.StartsWith('expr.');

      // Extract the trigger token from the first expect/consume in the body
      LTriggerKind := LNodeKind; // fallback
      if LBlockNode.ChildCount() > 0 then
      begin
        LFirstStmt := LBlockNode.GetChild(0);
        if (LFirstStmt.GetNodeKind() = 'stmt.expect') or
           (LFirstStmt.GetNodeKind() = 'stmt.consume') then
        begin
          if LFirstStmt.GetAttr('token_kind', LAttr) then
            LTriggerKind := LAttr.AsString
          else if LFirstStmt.ChildCount() > 0 then
          begin
            // List consume [a.b, c.d] — first child is a meta.token_ref
            if LFirstStmt.GetChild(0).GetAttr('kind', LAttr) then
              LTriggerKind := LAttr.AsString;
          end;
        end;
      end;

      // --- Infix rule: precedence left|right N ---
      // For list consumes, register each token in the list as a separate infix
      if LIsInfix then
      begin
        // Build list of trigger tokens: single or from list consume
        if LTriggerKind <> LNodeKind then
        begin
          SetLength(LTriggers, 1);
          LTriggers[0] := LTriggerKind;
          if (LBlockNode.ChildCount() > 0) and
             (LBlockNode.GetChild(0).GetNodeKind() = 'stmt.consume') then
          begin
            LConsumeNode := LBlockNode.GetChild(0);
            SetLength(LTriggers, LConsumeNode.ChildCount());
            for LJ := 0 to LConsumeNode.ChildCount() - 1 do
            begin
              if LConsumeNode.GetChild(LJ).GetAttr('kind', LAttr) then
                LTriggers[LJ] := LAttr.AsString;
            end;
          end;
        end
        else
        begin
          SetLength(LTriggers, 1);
          LTriggers[0] := LTriggerKind;
        end;

        for LTrigIdx := 0 to Length(LTriggers) - 1 do
        begin
          if LAssoc = 'right' then
            ACustomMetamorf.Config().RegisterInfixRight(LTriggers[LTrigIdx], LPower, LNodeKind,
              function(AParser: TParserBase;
                ALeft: TASTNodeBase): TASTNodeBase
              var
                LInterp: TMetamorfScriptInterp;
              begin
                LInterp := TMetamorfScriptInterp.Create(
                  ACustomMetamorf.Config(), AStore, APipeline);
                try
                  LInterp.FContextKind := sckParse;
                  LInterp.FParser      := AParser;
                  LInterp.FNodeKind    := LNodeKind;
                  LInterp.FResultNode  := AParser.CreateNode();
                  LInterp.FLeftNode    := ALeft;
                  LInterp.FResultNode.AddChild(ALeft as TASTNode);
                  LInterp.FResultNode.SetAttr('left', TValue.From<TObject>(ALeft));
                  LInterp.ExecBlock(LBlockNode);
                  Result := LInterp.FResultNode;
                finally
                  LInterp.Free();
                end;
              end)
          else
            ACustomMetamorf.Config().RegisterInfixLeft(LTriggers[LTrigIdx], LPower, LNodeKind,
              function(AParser: TParserBase;
                ALeft: TASTNodeBase): TASTNodeBase
              var
                LInterp: TMetamorfScriptInterp;
              begin
                LInterp := TMetamorfScriptInterp.Create(
                  ACustomMetamorf.Config(), AStore, APipeline);
                try
                  LInterp.FContextKind := sckParse;
                  LInterp.FParser      := AParser;
                  LInterp.FNodeKind    := LNodeKind;
                  LInterp.FResultNode  := AParser.CreateNode();
                  LInterp.FLeftNode    := ALeft;
                  LInterp.FResultNode.AddChild(ALeft as TASTNode);
                  LInterp.FResultNode.SetAttr('left', TValue.From<TObject>(ALeft));
                  LInterp.ExecBlock(LBlockNode);
                  Result := LInterp.FResultNode;
                finally
                  LInterp.Free();
                end;
              end);
        end;
      end

      // --- Expression prefix rule: expr.* ---
      else if LIsExpr then
      begin
        ACustomMetamorf.Config().RegisterPrefix(LTriggerKind, LNodeKind,
          function(AParser: TParserBase): TASTNodeBase
          var
            LInterp: TMetamorfScriptInterp;
          begin
            LInterp := TMetamorfScriptInterp.Create(
              ACustomMetamorf.Config(), AStore, APipeline);
            try
              LInterp.FContextKind := sckParse;
              LInterp.FParser      := AParser;
              LInterp.FNodeKind    := LNodeKind;
              LInterp.FResultNode  := AParser.CreateNode();
              LInterp.ExecBlock(LBlockNode);
              Result := LInterp.FResultNode;
            finally
              LInterp.Free();
            end;
          end);
      end

      // --- Statement rule: stmt.* ---
      else
      begin
        // If no trigger was found (trigger == node kind fallback), use
        // KIND_IDENTIFIER — the default for identifier-initiated statements
        // like assignments and expression-statements.
        if LTriggerKind = LNodeKind then
          LTriggerKind := KIND_IDENTIFIER;
        ACustomMetamorf.Config().RegisterStatement(LTriggerKind, LNodeKind,
          function(AParser: TParserBase): TASTNodeBase
          var
            LInterp: TMetamorfScriptInterp;
          begin
            LInterp := TMetamorfScriptInterp.Create(
              ACustomMetamorf.Config(), AStore, APipeline);
            try
              LInterp.FContextKind := sckParse;
              LInterp.FParser      := AParser;
              LInterp.FNodeKind    := LNodeKind;
              LInterp.FResultNode  := AParser.CreateNode();
              LInterp.ExecBlock(LBlockNode);
              Result := LInterp.FResultNode;
            finally
              LInterp.Free();
            end;
          end);
      end;
    end);
end;

// =========================================================================
// REGISTRATION — SEMANTIC RULES
// =========================================================================

// Helper: register a single semantic rule. Isolates closure capture so each
// handler captures its own ANodeKind/ABlockNode values (not shared loop vars).
procedure DoRegisterOneSemanticRule(
  const ACustomMetamorf: TMetamorf;
  const AStore:       IMetamorfScriptStore;
  const APipeline:    TMetamorfLangPipelineCallbacks;
  const ANodeKind:    string;
  const ABlockNode:   TASTNodeBase);
begin
  ACustomMetamorf.Config().RegisterSemanticRule(ANodeKind,
    procedure(const ASemanticNode: TASTNodeBase;
      ASem: TSemanticBase)
    var
      LInterp: TMetamorfScriptInterp;
    begin
      LInterp := TMetamorfScriptInterp.Create(
        ACustomMetamorf.Config(), AStore, APipeline);
      try
        LInterp.SetSemanticContext(ASem, ASemanticNode);
        LInterp.ExecBlock(ABlockNode);
      finally
        LInterp.Free();
      end;
    end);
end;

procedure RegisterSemanticRules(
  const AMetamorf      : TMetamorf;
  const ACustomMetamorf: TMetamorf;
  const AStore:       IMetamorfScriptStore;
  const APipeline:    TMetamorfLangPipelineCallbacks);
begin
  AMetamorf.Config().RegisterEmitter('meta.semantics_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI:         Integer;
      LChild:     TASTNodeBase;
      LAttr:      TValue;
      LNodeKind:  string;
      LBlockNode: TASTNodeBase;
    begin
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        LChild := ANode.GetChild(LI);
        if LChild.GetNodeKind() = 'meta.on_handler' then
        begin
          LChild.GetAttr('node_kind', LAttr);
          LNodeKind  := LAttr.AsString;
          LBlockNode := LChild.GetChild(0);
          DoRegisterOneSemanticRule(
            ACustomMetamorf, AStore, APipeline, LNodeKind, LBlockNode);
        end;
      end;
    end);
end;

// =========================================================================
// REGISTRATION — EMIT RULES
// =========================================================================

// Helper: register a single emitter rule. Same closure isolation pattern.
procedure DoRegisterOneEmitRule(
  const ACustomMetamorf: TMetamorf;
  const AStore:       IMetamorfScriptStore;
  const APipeline:    TMetamorfLangPipelineCallbacks;
  const ANodeKind:    string;
  const ABlockNode:   TASTNodeBase);
begin
  ACustomMetamorf.Config().RegisterEmitter(ANodeKind,
    procedure(AEmitNode: TASTNodeBase; AIR: TIRBase)
    var
      LInterp: TMetamorfScriptInterp;
    begin
      LInterp := TMetamorfScriptInterp.Create(
        ACustomMetamorf.Config(), AStore, APipeline);
      try
        LInterp.SetEmitContext(AIR, AEmitNode);
        LInterp.ExecBlock(ABlockNode);
      finally
        LInterp.Free();
      end;
    end);
end;

procedure RegisterEmitRules(
  const AMetamorf      : TMetamorf;
  const ACustomMetamorf: TMetamorf;
  const AStore:       IMetamorfScriptStore;
  const APipeline:    TMetamorfLangPipelineCallbacks);
begin
  AMetamorf.Config().RegisterEmitter('meta.emitters_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI:         Integer;
      LChild:     TASTNodeBase;
      LAttr:      TValue;
      LNodeKind:  string;
      LBlockNode: TASTNodeBase;
    begin
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        LChild := ANode.GetChild(LI);

        if LChild.GetNodeKind() = 'meta.on_handler' then
        begin
          LChild.GetAttr('node_kind', LAttr);
          LNodeKind  := LAttr.AsString;
          LBlockNode := LChild.GetChild(0);
          DoRegisterOneEmitRule(
            ACustomMetamorf, AStore, APipeline, LNodeKind, LBlockNode);
        end
        else if LChild.GetNodeKind() = 'meta.section_decl' then
        begin
          // Section declarations — informational for now
        end;
      end;
    end);
end;

// =========================================================================
// REGISTRATION — HELPER FUNCTIONS
// =========================================================================

procedure RegisterHelperFuncCollection(
  const AMetamorf: TMetamorf;
  const AStore: IMetamorfScriptStore);
begin
  AMetamorf.Config().RegisterEmitter('meta.routine_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LAttr:     TValue;
      LFuncName: string;
    begin
      ANode.GetAttr('name', LAttr);
      LFuncName := LAttr.AsString;
      AStore.GetHelperFuncs().AddOrSetValue(LFuncName, ANode);
    end);
end;

// =========================================================================
// REGISTRATION — PASSTHROUGH HANDLERS
// =========================================================================

procedure RegisterPassthroughEmitters(const AMetamorf: TMetamorf);
begin
  // Top-level nodes that just walk their children
  AMetamorf.Config().RegisterEmitter('root',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  AMetamorf.Config().RegisterEmitter('meta.language_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Language header — no emission needed
    end);

  AMetamorf.Config().RegisterEmitter('meta.grammar_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  AMetamorf.Config().RegisterEmitter('meta.const_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Constants are resolved at Phase 1 semantic time
    end);

  AMetamorf.Config().RegisterEmitter('meta.types_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Type compat rules — TODO: register on custom parse
      AGen.EmitChildren(ANode);
    end);

  AMetamorf.Config().RegisterEmitter('meta.import',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // TODO: import handling
    end);

  AMetamorf.Config().RegisterEmitter('meta.include',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // TODO: fragment inclusion
    end);

  AMetamorf.Config().RegisterEmitter('meta.fragment_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Fragment stored for later inclusion — no emission
    end);

  AMetamorf.Config().RegisterEmitter('meta.enum_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Enums are resolved at Phase 1 semantic time
    end);
end;

// =========================================================================
// PUBLIC ENTRY POINT
// =========================================================================

procedure ConfigCodeGen(
  const AMetamorf      : TMetamorf;
  const ACustomMetamorf: TMetamorf;
  const APipeline:    TMetamorfLangPipelineCallbacks);
var
  LStore: IMetamorfScriptStore;
begin
  LStore := TMetamorfScriptStore.Create();

  RegisterPassthroughEmitters(AMetamorf);
  RegisterLexerSections(AMetamorf, ACustomMetamorf, LStore);
  RegisterGrammarRules(AMetamorf, ACustomMetamorf, LStore, APipeline);
  RegisterSemanticRules(AMetamorf, ACustomMetamorf, LStore, APipeline);
  RegisterEmitRules(AMetamorf, ACustomMetamorf, LStore, APipeline);
  RegisterHelperFuncCollection(AMetamorf, LStore);
end;

end.
