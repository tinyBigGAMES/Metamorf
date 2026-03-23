{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Semantics;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Rtti,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.LangConfig;

type

  // Forward declarations
  TScope     = class;
  TSemantics = class;

  { TSymbol }
  TSymbol = record
    SymbolName: string;                         // declared identifier text (key in scope)
    DeclKind:   string;                         // node kind of the declaring AST node
    DeclNode:   TASTNodeBase;              // the declaring AST node (not owned here)
    References: TList<TASTNodeBase>;       // all use-site nodes (owned by TSemantics)
  end;

  { TScope }
  TScope = class
  private
    FScopeName:  string;
    FParent:     TScope;                        // not owned
    FChildren:   TObjectList<TScope>;           // owned
    FSymbols:    TDictionary<string, TSymbol>;  // name → symbol record
    FOpenToken:  TToken;
    FCloseToken: TToken;

  public
    constructor Create(const AScopeName: string; const AParent: TScope);
    destructor Destroy(); override;

    // Declare a symbol in this scope.
    // Returns False if a symbol with ASymbol.SymbolName already exists here.
    function Declare(const ASymbol: TSymbol): Boolean;

    // Look up a name in this scope only — does not walk the parent chain.
    function LookupLocal(const AName: string;
      out ASymbol: TSymbol): Boolean;

    // Walk up the scope chain from this scope to find a name.
    function Lookup(const AName: string;
      out ASymbol: TSymbol): Boolean;

    // Returns True if this scope's source range contains AFile:ALine:ACol.
    // Used by FindScopeAt to locate the deepest active scope at a position.
    function ContainsPosition(const AFile: string;
      const ALine, ACol: Integer): Boolean;

    // Add a child scope (called by TSemantics.PushScope)
    procedure AddChild(const AChild: TScope);

    property ScopeName:   string      read FScopeName;
    property ParentScope: TScope read FParent;
    property OpenToken:   TToken  read FOpenToken  write FOpenToken;
    property CloseToken:  TToken  read FCloseToken write FCloseToken;
    property Children:    TObjectList<TScope>           read FChildren;
    property Symbols:     TDictionary<string, TSymbol>  read FSymbols;
  end;

  { TSemantics }
  TSemantics = class(TSemanticBase)
  private
    FConfig:      TLangConfig;          // not owned — caller manages lifetime
    FRootScope:   TScope;               // owned — root of the scope tree
    FScopeStack:  TList<TScope>;        // active scope chain (not owned entries)
    FNodeIndex:   TList<TASTNodeBase>;  // all visited nodes in document order
    FRefLists:    TObjectList<TList<TASTNodeBase>>;  // owns all reference lists

    // Return the innermost currently active scope
    function CurrentScope(): TScope;

    // Walk one node — dispatch handler if registered, else auto-visit children.
    // Also appends ANode to FNodeIndex.
    procedure DoVisitNode(const ANode: TASTNodeBase);

    // Recursive scope search — deepest scope whose range contains AFile:ALine:ACol
    function FindScopeAt(const AScope: TScope; const AFile: string;
      const ALine, ACol: Integer): TScope;

    // Collect all symbols visible from AScope upward into AResult
    procedure CollectScopeSymbols(const AScope: TScope;
      const AResult: TList<TSymbol>);

    // Report a semantic error using FErrors (inherited from TErrorsObject)
    procedure ReportError(const ANode: TASTNodeBase;
      const ACode, AMsg: string);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Bind the language config. Must be called before Analyze().
    procedure SetConfig(const AConfig: TLangConfig);

    // Walk ARoot, dispatch semantic handlers, enrich nodes with ATTR_*
    // attributes in place. Returns True if analysis completed with no errors.
    // TSemantics retains scope tree and node index after this call.
    function Analyze(const ARoot: TASTNodeBase): Boolean;

    // -------------------------------------------------------------------------
    // LSP query API — available after Analyze()
    // These are acceleration-structure queries over the enriched AST.
    // LSP and CodeGen do NOT need to call these — the enriched AST is
    // self-sufficient. These exist only for efficient position-based lookup.
    // -------------------------------------------------------------------------

    // Find the innermost AST node whose source range contains AFile:ALine:ACol.
    // Returns nil if no node covers that position.
    function FindNodeAt(const AFile: string;
      const ALine, ACol: Integer): TASTNodeBase;

    // Return all symbols visible in scope at AFile:ALine:ACol.
    // Walks from the deepest matching scope up to global.
    // Caller owns the returned TArray.
    function GetSymbolsInScopeAt(const AFile: string;
      const ALine, ACol: Integer): TArray<TSymbol>;

    // Look up a symbol by name across all scopes (global symbol search).
    // Returns True and sets ASymbol if found.
    function FindSymbol(const AName: string;
      out ASymbol: TSymbol): Boolean;

    // -------------------------------------------------------------------------
    // TSemanticBase virtuals — called by semantic handlers during Analyze()
    // -------------------------------------------------------------------------

    // Push a new named scope level. AOpenToken is the token that opened it
    // (e.g. 'begin', '{') — stored for LSP scope range queries.
    procedure PushScope(const AScopeName: string;
      const AOpenToken: TToken); override;

    // Pop the current scope back to its parent. ACloseToken is stored
    // on the scope for LSP range queries.
    procedure PopScope(const ACloseToken: TToken); override;

    // Declare a symbol in the current scope.
    // Returns False if AName is already declared in the current scope.
    function DeclareSymbol(const AName: string;
      const ANode: TASTNodeBase): Boolean; override;

    // Look up AName in current scope and all parents.
    // Returns True and sets ANode to the declaring node if found.
    function LookupSymbol(const AName: string;
      out ANode: TASTNodeBase): Boolean; override;

    // Look up AName in current scope only.
    // Returns True and sets ANode to the declaring node if found.
    function LookupSymbolLocal(const AName: string;
      out ANode: TASTNodeBase): Boolean; override;
    function SymbolExistsWithPrefix(const APrefix: string): Boolean; override;
    function DemoteCLinkageForPrefix(const APrefix: string): Integer; override;

    // Recurse into a single node — dispatches its handler or auto-visits children.
    // Handlers call this to drive traversal into specific child nodes.
    procedure VisitNode(const ANode: TASTNodeBase); override;

    // Recurse into all children of ANode in document order.
    // Handlers use this when they want the engine to walk a block of children.
    procedure VisitChildren(const ANode: TASTNodeBase); override;

    // Report a semantic error at the source location of ANode.
    procedure AddSemanticError(const ANode: TASTNodeBase;
      const ACode, AMsg: string); override;
    procedure AddSemanticWarning(const ANode: TASTNodeBase;
      const ACode, AMsg: string); override;

    // Returns True if currently inside a named scope (function/procedure body).
    // False at the root/global scope level.
    function IsInsideRoutine(): Boolean; override;
  end;

implementation

{ TScope }
constructor TScope.Create(const AScopeName: string;
  const AParent: TScope);
begin
  inherited Create();
  FScopeName := AScopeName;
  FParent    := AParent;
  FChildren  := TObjectList<TScope>.Create(True);  // owns children
  FSymbols   := TDictionary<string, TSymbol>.Create();
end;

destructor TScope.Destroy();
begin
  FreeAndNil(FSymbols);
  FreeAndNil(FChildren);
  inherited;
end;

function TScope.Declare(const ASymbol: TSymbol): Boolean;
begin
  // Refuse duplicate declarations within the same scope level.
  if FSymbols.ContainsKey(ASymbol.SymbolName) then
  begin
    Result := False;
    Exit;
  end;
  FSymbols.Add(ASymbol.SymbolName, ASymbol);
  Result := True;
end;

function TScope.LookupLocal(const AName: string;
  out ASymbol: TSymbol): Boolean;
begin
  Result := FSymbols.TryGetValue(AName, ASymbol);
end;

function TScope.Lookup(const AName: string;
  out ASymbol: TSymbol): Boolean;
var
  LScope: TScope;
begin
  // Walk up the parent chain until found or we run out of scopes.
  LScope := Self;
  while LScope <> nil do
  begin
    if LScope.FSymbols.TryGetValue(AName, ASymbol) then
    begin
      Result := True;
      Exit;
    end;
    LScope := LScope.FParent;
  end;
  Result := False;
end;

function TScope.ContainsPosition(const AFile: string;
  const ALine, ACol: Integer): Boolean;
var
  LOpenLine:  Integer;
  LOpenCol:   Integer;
  LCloseLine: Integer;
  LCloseCol:  Integer;
begin
  // If the scope has no recorded open/close positions it cannot contain anything.
  if (FOpenToken.Filename = '') and (FCloseToken.Filename = '') then
  begin
    Result := False;
    Exit;
  end;

  // Match the file — scope ranges are per-file.
  if (FOpenToken.Filename <> '') and (FOpenToken.Filename <> AFile) then
  begin
    Result := False;
    Exit;
  end;

  LOpenLine  := FOpenToken.Line;
  LOpenCol   := FOpenToken.Column;
  LCloseLine := FCloseToken.Line;
  LCloseCol  := FCloseToken.Column;

  // ALine:ACol must fall within [open, close] inclusive.
  if ALine < LOpenLine then
  begin
    Result := False;
    Exit;
  end;
  if (ALine = LOpenLine) and (ACol < LOpenCol) then
  begin
    Result := False;
    Exit;
  end;
  if LCloseLine > 0 then
  begin
    if ALine > LCloseLine then
    begin
      Result := False;
      Exit;
    end;
    if (ALine = LCloseLine) and (ACol > LCloseCol) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

procedure TScope.AddChild(const AChild: TScope);
begin
  FChildren.Add(AChild);
end;

{ TSemantics }
constructor TSemantics.Create();
begin
  inherited;
  FConfig     := nil;
  FRootScope  := TScope.Create('global', nil);
  FScopeStack := TList<TScope>.Create();
  FNodeIndex  := TList<TASTNodeBase>.Create();
  FRefLists   := TObjectList<TList<TASTNodeBase>>.Create(True);

  // Global scope is always the bottom of the stack.
  FScopeStack.Add(FRootScope);
end;

destructor TSemantics.Destroy();
begin
  FreeAndNil(FRefLists);
  FreeAndNil(FNodeIndex);
  FreeAndNil(FScopeStack);
  FreeAndNil(FRootScope);
  inherited;
end;

procedure TSemantics.SetConfig(const AConfig: TLangConfig);
begin
  FConfig := AConfig;
end;

function TSemantics.CurrentScope(): TScope;
begin
  // The stack always has at least the global scope on it.
  Result := FScopeStack[FScopeStack.Count - 1];
end;

procedure TSemantics.ReportError(const ANode: TASTNodeBase;
  const ACode, AMsg: string);
var
  LToken: TToken;
begin
  if FErrors = nil then
    Exit;
  if ANode <> nil then
  begin
    LToken := ANode.GetToken();
    FErrors.Add(
      LToken.Filename,
      LToken.Line,
      LToken.Column,
      esError,
      ACode,
      AMsg);
  end
  else
    FErrors.Add(esError, ACode, AMsg, []);
end;

procedure TSemantics.PushScope(const AScopeName: string;
  const AOpenToken: TToken);
var
  LParent:   TScope;
  LNewScope: TScope;
begin
  LParent   := CurrentScope();
  LNewScope := TScope.Create(AScopeName, LParent);
  LNewScope.OpenToken := AOpenToken;

  // The scope tree (rooted at FRootScope) owns all child scopes via
  // TObjectList — register the new scope as a child of its parent.
  LParent.AddChild(LNewScope);

  FScopeStack.Add(LNewScope);
end;

procedure TSemantics.PopScope(const ACloseToken: TToken);
begin
  if FScopeStack.Count <= 1 then
    Exit;  // never pop the global scope

  // Record the close token on the scope before popping — needed by LSP
  // range queries after analysis completes.
  CurrentScope().CloseToken := ACloseToken;

  FScopeStack.Delete(FScopeStack.Count - 1);
end;

function TSemantics.DeclareSymbol(const AName: string;
  const ANode: TASTNodeBase): Boolean;
var
  LSymbol:  TSymbol;
  LRefList: TList<TASTNodeBase>;
begin
  // Create a fresh reference list owned by FRefLists so it survives scope
  // destruction and remains accessible for find-references / rename queries.
  LRefList := TList<TASTNodeBase>.Create();
  FRefLists.Add(LRefList);

  LSymbol.SymbolName := AName;
  LSymbol.DeclNode   := ANode;
  LSymbol.References := LRefList;

  // Record the declaring node's node kind if available.
  if ANode <> nil then
    LSymbol.DeclKind := ANode.GetNodeKind()
  else
    LSymbol.DeclKind := '';

  Result := CurrentScope().Declare(LSymbol);
end;

function TSemantics.LookupSymbol(const AName: string;
  out ANode: TASTNodeBase): Boolean;
var
  LSymbol: TSymbol;
begin
  ANode := nil;
  if CurrentScope().Lookup(AName, LSymbol) then
  begin
    ANode  := LSymbol.DeclNode;
    Result := True;
  end
  else
    Result := False;
end;

function TSemantics.LookupSymbolLocal(const AName: string;
  out ANode: TASTNodeBase): Boolean;
var
  LSymbol: TSymbol;
begin
  ANode := nil;
  if CurrentScope().LookupLocal(AName, LSymbol) then
  begin
    ANode  := LSymbol.DeclNode;
    Result := True;
  end
  else
    Result := False;
end;

function TSemantics.SymbolExistsWithPrefix(const APrefix: string): Boolean;
var
  LKey: string;
begin
  Result := False;
  for LKey in CurrentScope().Symbols.Keys do
  begin
    if LKey.StartsWith(APrefix) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TSemantics.DemoteCLinkageForPrefix(const APrefix: string): Integer;
var
  LPair:    TPair<string, TSymbol>;
  LLinkVal: TValue;
  LNameVal: TValue;
  LNode:    TASTNode;
begin
  Result := 0;
  for LPair in CurrentScope().Symbols do
  begin
    if LPair.Key.StartsWith(APrefix) and (LPair.Value.DeclNode <> nil) then
    begin
      LNode := TASTNode(LPair.Value.DeclNode);
      if LNode.GetAttr('decl.linkage', LLinkVal) and
         (LLinkVal.AsString = '"C"') then
      begin
        LNode.SetAttr('decl.linkage', TValue.From<string>(''));
        LNode.GetAttr('decl.name', LNameVal);
        AddSemanticWarning(LPair.Value.DeclNode, 'W200',
          'Overloaded routine ''' + LNameVal.AsString +
          ''' cannot use C linkage; defaulting to C++ linkage');
        Inc(Result);
      end;
    end;
  end;
end;

procedure TSemantics.VisitNode(const ANode: TASTNodeBase);
begin
  if ANode = nil then
    Exit;
  DoVisitNode(ANode);
end;

procedure TSemantics.VisitChildren(const ANode: TASTNodeBase);
var
  LI:    Integer;
  LChild: TASTNodeBase;
begin
  if ANode = nil then
    Exit;
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChild(LI);
    if LChild <> nil then
      DoVisitNode(LChild);
  end;
end;

procedure TSemantics.AddSemanticError(const ANode: TASTNodeBase;
  const ACode, AMsg: string);
begin
  ReportError(ANode, ACode, AMsg);
end;

procedure TSemantics.AddSemanticWarning(const ANode: TASTNodeBase;
  const ACode, AMsg: string);
var
  LToken: TToken;
begin
  if FErrors = nil then
    Exit;
  if ANode <> nil then
  begin
    LToken := ANode.GetToken();
    FErrors.Add(
      LToken.Filename,
      LToken.Line,
      LToken.Column,
      esWarning,
      ACode,
      AMsg);
  end
  else
    FErrors.Add(esWarning, ACode, AMsg, []);
end;

function TSemantics.IsInsideRoutine(): Boolean;
begin
  // Root scope is always at index 0. Inside a routine, the stack has >= 2 entries.
  Result := FScopeStack.Count > 1;
end;

procedure TSemantics.DoVisitNode(const ANode: TASTNodeBase);
var
  LHandler: TSemanticHandler;
  LI:       Integer;
  LChild:   TASTNodeBase;
begin
  if ANode = nil then
    Exit;

  // Record every node in document order — enables position-based LSP queries.
  FNodeIndex.Add(ANode);

  // Dispatch: if the language registered a handler for this node kind, call it.
  // The handler is fully responsible for:
  //   - Writing ATTR_* enrichment attributes onto ANode
  //   - Declaring/resolving symbols via DeclareSymbol / LookupSymbol
  //   - Driving traversal of child nodes via VisitNode / VisitChildren
  //   - Pushing/popping scopes where the node introduces a new scope level
  if (FConfig <> nil) and
     FConfig.GetSemanticHandler(ANode.GetNodeKind(), LHandler) then
  begin
    LHandler(ANode, Self);
    Exit;  // handler owns its subtree — do not auto-visit children
  end;

  // No handler registered for this node kind — transparently auto-visit all
  // children. This ensures that unregistered structural nodes (e.g. 'program.root',
  // arbitrary wrapper nodes) are walked through without requiring boilerplate.
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChild(LI);
    if LChild <> nil then
      DoVisitNode(LChild);
  end;
end;

function TSemantics.Analyze(const ARoot: TASTNodeBase): Boolean;
begin
  // Report the filename and AST node count so the user can see what is being analyzed
  if ARoot <> nil then
    Status('Analyzing %s (%d nodes)...', [ARoot.GetToken().Filename, ARoot.ChildCount()])
  else
    Status('Analyzing...');
  // Reset state from any previous run so TSemantics can be reused.
  FNodeIndex.Clear();
  FRefLists.Clear();

  // Reinitialise the scope tree — free the old root and create a fresh one.
  FreeAndNil(FRootScope);
  FRootScope := TScope.Create('global', nil);
  FScopeStack.Clear();
  FScopeStack.Add(FRootScope);

  // Walk the entire AST, enriching nodes in place.
  if ARoot <> nil then
    DoVisitNode(ARoot);

  // Analysis succeeded if no errors were reported.
  Result := (FErrors = nil) or (FErrors.ErrorCount() = 0);
end;

// -----------------------------------------------------------------------------
// LSP query API (acceleration-structure queries over the enriched AST)
// -----------------------------------------------------------------------------

function TSemantics.FindNodeAt(const AFile: string;
  const ALine, ACol: Integer): TASTNodeBase;
var
  LI:        Integer;
  LNode:     TASTNodeBase;
  LToken:    TToken;
  LBest:     TASTNodeBase;
  LBestLine: Integer;
  LBestCol:  Integer;
begin
  // Scan FNodeIndex for the node whose token position is the closest match
  // that does not exceed ALine:ACol. Nodes are in document order so we find
  // the last one that is at or before the cursor.
  LBest     := nil;
  LBestLine := 0;
  LBestCol  := 0;

  for LI := 0 to FNodeIndex.Count - 1 do
  begin
    LNode  := FNodeIndex[LI];
    LToken := LNode.GetToken();

    if LToken.Filename <> AFile then
      Continue;

    // Node must start at or before the cursor position.
    if LToken.Line > ALine then
      Continue;
    if (LToken.Line = ALine) and (LToken.Column > ACol) then
      Continue;

    // Among qualifying nodes, prefer the one with the latest (deepest) start.
    if (LToken.Line > LBestLine) or
       ((LToken.Line = LBestLine) and (LToken.Column > LBestCol)) then
    begin
      LBest     := LNode;
      LBestLine := LToken.Line;
      LBestCol  := LToken.Column;
    end;
  end;

  Result := LBest;
end;

function TSemantics.FindScopeAt(const AScope: TScope;
  const AFile: string; const ALine, ACol: Integer): TScope;
var
  LI:    Integer;
  LChild: TScope;
  LDeep:  TScope;
begin
  Result := AScope;

  // Try to find a deeper matching child scope.
  for LI := 0 to AScope.Children.Count - 1 do
  begin
    LChild := AScope.Children[LI];
    if LChild.ContainsPosition(AFile, ALine, ACol) then
    begin
      // Recurse — the deepest matching scope wins.
      LDeep := FindScopeAt(LChild, AFile, ALine, ACol);
      if LDeep <> nil then
        Result := LDeep;
      Exit;
    end;
  end;
end;

procedure TSemantics.CollectScopeSymbols(const AScope: TScope;
  const AResult: TList<TSymbol>);
var
  LPair:  TPair<string, TSymbol>;
  LScope: TScope;
begin
  // Walk from AScope up to global, collecting all symbols.
  LScope := AScope;
  while LScope <> nil do
  begin
    for LPair in LScope.Symbols do
      AResult.Add(LPair.Value);
    LScope := LScope.ParentScope;
  end;
end;

function TSemantics.GetSymbolsInScopeAt(const AFile: string;
  const ALine, ACol: Integer): TArray<TSymbol>;
var
  LScope:  TScope;
  LResult: TList<TSymbol>;
begin
  LScope  := FindScopeAt(FRootScope, AFile, ALine, ACol);
  LResult := TList<TSymbol>.Create();
  try
    CollectScopeSymbols(LScope, LResult);
    Result := LResult.ToArray();
  finally
    LResult.Free();
  end;
end;

function TSemantics.FindSymbol(const AName: string;
  out ASymbol: TSymbol): Boolean;
begin
  // Search from the global root scope down the chain.
  Result := FRootScope.Lookup(AName, ASymbol);
end;

end.
