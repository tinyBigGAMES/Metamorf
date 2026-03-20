{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Common;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Rtti,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Config,
  Metamorf.Build;

const
  METAMORF_MAJOR_VERSION = 0;
  METAMORF_MINOR_VERSION = 1;
  METAMORF_PATCH_VERSION = 0;
  METAMORF_VERSION       = (METAMORF_MAJOR_VERSION * 10000) + (METAMORF_MINOR_VERSION * 100) +
                       METAMORF_PATCH_VERSION;
  METAMORF_VERSION_STR = '0.1.0';

  METAMORF_LANG_EXT           = 'mor';


  // Standard token kind strings shared across the entire toolkit.
  // Components and language files reference these rather than
  // repeating the literal strings.
  KIND_EOF           = 'eof';
  KIND_UNKNOWN       = 'unknown';
  KIND_IDENTIFIER    = 'identifier';
  KIND_INTEGER       = 'literal.integer';
  KIND_FLOAT         = 'literal.float';
  KIND_STRING        = 'literal.string';
  KIND_CHAR          = 'literal.char';
  KIND_COMMENT_LINE  = 'comment.line';
  KIND_COMMENT_BLOCK = 'comment.block';
  KIND_DIRECTIVE     = 'directive';

  // Attribute keys written by TSemantics onto AST nodes during analysis.
  // These are the contract between the semantic pass, the LSP, and CodeGen.
  // After Analyze() the AST is fully self-sufficient — LSP and CodeGen read
  // these attributes directly off nodes without calling back into the engine.

  // Written on every expression and identifier use-site node.
  // Value: string — the resolved type kind string for this expression.
  ATTR_TYPE_KIND       = 'sem.type';

  // Written on every identifier use-site node.
  // Value: string — the declared name of the symbol this identifier resolves to.
  ATTR_RESOLVED_SYMBOL = 'sem.symbol';

  // Written on every identifier use-site and call node.
  // Value: TObject (TASTNodeBase) — pointer to the declaring AST node.
  // Drives: go-to-definition, hover, rename, find-references (collect all
  // nodes whose ATTR_DECL_NODE points to the same declaring node).
  ATTR_DECL_NODE       = 'sem.decl_node';

  // Written on every declaration node (var, const, param, type, routine).
  // Value: string — storage class: 'local', 'global', 'param', 'const', 'type', 'routine'.
  // Drives: CodeGen storage allocation decisions.
  ATTR_STORAGE_CLASS   = 'sem.storage';

  // Written on every declaration node AND every scope-opening node
  // (routine body, block, etc.).
  // Value: string — fully-qualified scope name this node belongs to / opens.
  // Drives: LSP completion (collect declarations whose ATTR_SCOPE_NAME
  // matches the scope at cursor position).
  ATTR_SCOPE_NAME      = 'sem.scope';

  // Written on every call expression node.
  // Value: string — the resolved overload symbol name.
  // Drives: CodeGen — emits the correct overloaded function name.
  ATTR_CALL_RESOLVED   = 'sem.call_symbol';

  // Written on expression nodes that require an implicit type coercion.
  // Value: string — the target type kind string to coerce to.
  // Drives: CodeGen — emits the cast; never infers coercions independently.
  ATTR_COERCE_TO       = 'sem.coerce';

type

  { TToken }
  TToken = record
    Kind:      string;   // e.g. 'keyword.if', 'op.assign', 'literal.integer'
    Text:      string;   // raw source text
    Filename:  string;
    Line:      Integer;
    Column:    Integer;
    EndLine:   Integer;
    EndColumn: Integer;
    Value:     TValue;   // parsed value for literals (integer, float, string)
  end;

  { TBlockCommentDef }
  TBlockCommentDef = record
    OpenStr:   string;
    CloseStr:  string;
    TokenKind: string;  // when non-empty, overrides the global block-comment kind
  end;

  { TStringStyleDef }
  TStringStyleDef = record
    OpenStr:     string;   // opening delimiter, e.g. '"', "'"
    CloseStr:    string;   // closing delimiter, e.g. '"', "'"
    TokenKind:   string;   // kind string to emit
    AllowEscape: Boolean;  // whether backslash escapes are processed
  end;

  { TOperatorDef }
  TOperatorDef = record
    Text:      string;   // operator text, e.g. ':=', '+', '...'
    TokenKind: string;   // kind string to emit
  end;

  { TAssociativity }
  TAssociativity = (aoLeft, aoRight);

  { TConditionalRole — identifies a directive's role in conditional compilation }
  TConditionalRole = (crNone, crDefine, crUndef, crIfDef, crIfNDef,
                      crElseIf, crElse, crEndIf);

  { TSourceFile }
  TSourceFile = (sfHeader, sfSource);

  // Base classes and the concrete AST node type.
  // Defined here so handler types, TParserBase, and TIRBase
  // can all reference them from one shared location with no circular deps.

  { TASTNodeBase
    Abstract base for the AST node. Codegen walks the tree via these virtuals
    without needing to know the concrete type. }
  TASTNodeBase = class(TErrorsObject)
  public
    function GetNodeKind(): string; virtual; abstract;
    function GetToken(): TToken; virtual; abstract;
    function ChildCount(): Integer; virtual; abstract;
    function GetChild(const AIndex: Integer): TASTNodeBase; virtual; abstract;
    function GetAttr(const AKey: string; out AValue: TValue): Boolean; virtual; abstract;
  end;

  { TASTNode
    Concrete AST node used by every language built on Metamorf. Generic —
    no language-specific knowledge here. Node kind strings are set at
    construction time by the parser dispatch engine.

    Children are owned — freeing the root frees the entire tree.
    Attributes carry arbitrary TValue payloads keyed by plain strings. }
  TASTNode = class(TASTNodeBase)
  private
    FNodeKind:         string;
    FToken:            TToken;
    FChildren:         TObjectList<TASTNode>;  // OwnsObjects = True
    FAttributes:       TDictionary<string, TValue>;
    FLeadingComments:  TObjectList<TASTNode>;  // nil until first use, OwnsObjects = True
    FTrailingComments: TObjectList<TASTNode>;  // nil until first use, OwnsObjects = True

    // Recursive helper for Dump() — indents each level by ADepth * 2 spaces
    function DumpNode(const ADepth: Integer): string;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Named constructor used by TParser.CreateNode() implementations
    class function CreateNode(const ANodeKind: string;
      const AToken: TToken): TASTNode;

    // TASTNodeBase virtuals implemented
    function GetNodeKind(): string; override;
    function GetToken(): TToken; override;
    function ChildCount(): Integer; override;
    function GetChild(const AIndex: Integer): TASTNodeBase; override;
    function GetAttr(const AKey: string; out AValue: TValue): Boolean; override;

    // Typed build API — used by handlers to construct the tree
    procedure AddChild(const ANode: TASTNode);
    procedure SetAttr(const AKey: string; const AValue: TValue);

    // Typed child accessor — returns TASTNode directly (avoids casting in handlers)
    function GetChildNode(const AIndex: Integer): TASTNode;

    // Comment decoration API
    procedure AddLeadingComment(const ANode: TASTNode);
    procedure AddTrailingComment(const ANode: TASTNode);
    function LeadingCommentCount(): Integer;
    function TrailingCommentCount(): Integer;
    function GetLeadingComment(const AIndex: Integer): TASTNode;
    function GetTrailingComment(const AIndex: Integer): TASTNode;

    // Debug — returns an indented tree dump of this node and all descendants
    function Dump(const AId: Integer = 0): string; override;
  end;

  { TLexerBase
    Abstract base for the lexer. Directive callbacks receive TLexerBase
    to read arguments and consume terminators from within the callback. }
  TLexerBase = class(TErrorsObject)
  public
    function  Peek(const AOffset: Integer = 0): Char; virtual; abstract;
    procedure Advance(); virtual; abstract;
    function  IsEOF(): Boolean; virtual; abstract;
    function  IsIdentifierPart(const AChar: Char): Boolean; virtual; abstract;
    function  GetBuild(): TBuild; virtual; abstract;
  end;

  { TParserBase
    Abstract base for the parser. Handlers receive TParserBase and call
    back into the parser via these virtuals to drive parsing. }
  TParserBase = class(TErrorsObject)
  public
    // Token navigation
    function  CurrentToken(): TToken; virtual; abstract;
    function  PeekToken(const AOffset: Integer = 1): TToken; virtual; abstract;
    function  Consume(): TToken; virtual; abstract;
    procedure Expect(const AKind: string); virtual; abstract;
    function  Check(const AKind: string): Boolean; virtual; abstract;
    function  Match(const AKind: string): Boolean; virtual; abstract;

    // Recursive parsing — called by handlers to drive sub-expressions and statements
    function  ParseExpression(const AMinPower: Integer = 0): TASTNodeBase; virtual; abstract;
    function  ParseStatement(): TASTNodeBase; virtual; abstract;

    // Node creation — three overloads so handlers never hardcode kind strings
    // Form 1: kind from dispatch context, token = current
    function  CreateNode(): TASTNode; overload; virtual; abstract;
    // Form 2: explicit kind, token = current (for secondary/structural nodes)
    function  CreateNode(const ANodeKind: string): TASTNode; overload; virtual; abstract;
    // Form 3: explicit kind, explicit token (when current has moved past the relevant token)
    function  CreateNode(const ANodeKind: string;
      const AToken: TToken): TASTNode; overload; virtual; abstract;

    // Binding power helpers — infix handlers never hardcode power values
    function  CurrentInfixPower(): Integer; virtual; abstract;
    function  CurrentInfixPowerRight(): Integer; virtual; abstract;

    // Structural config access — handlers write lang-agnostic loops
    function  GetBlockCloseKind(): string; virtual; abstract;
    function  GetStatementTerminatorKind(): string; virtual; abstract;

    // Raw token collection -- collects tokens verbatim as a string,
    // tracking paren/bracket/brace depth. Stops at depth 0 when
    // encountering ), ], }, comma, semicolon, EOF, or a language keyword.
    function  CollectRawTokens(): string; virtual; abstract;
  end;

  { TIRBase
    Abstract base for the IR text emitter. Emit handlers receive this type
    so they can write C++23 text and walk child nodes without a circular
    dependency on Metamorf.IR. The full fluent builder API is declared here as
    abstract virtuals so emit handlers can use it without casting. }
  TIRBase = class(TErrorsObject)
  public
    // ---- Low-level primitives ----

    // Append indent + AText + newline
    procedure EmitLine(const AText: string; const ATarget: TSourceFile = sfSource); overload; virtual; abstract;
    // Formatted overload — AText is a Format() template, AArgs are the arguments
    procedure EmitLine(const AText: string; const AArgs: array of const; const ATarget: TSourceFile = sfSource); overload; virtual; abstract;

    // Append AText verbatim — no indent, no newline
    procedure Emit(const AText: string; const ATarget: TSourceFile = sfSource); overload; virtual; abstract;
    // Formatted overload — AText is a Format() template, AArgs are the arguments
    procedure Emit(const AText: string; const AArgs: array of const; const ATarget: TSourceFile = sfSource); overload; virtual; abstract;

    // Append AText truly verbatim (for $cppstart/$cpp escape hatch blocks)
    procedure EmitRaw(const AText: string; const ATarget: TSourceFile = sfSource); overload; virtual; abstract;
    // Formatted overload — AText is a Format() template, AArgs are the arguments
    procedure EmitRaw(const AText: string; const AArgs: array of const; const ATarget: TSourceFile = sfSource); overload; virtual; abstract;

    // Indentation control
    procedure IndentIn(); virtual; abstract;
    procedure IndentOut(); virtual; abstract;

    // AST dispatch — used by TEmitHandler callbacks
    procedure EmitNode(const ANode: TASTNodeBase); virtual; abstract;
    procedure EmitChildren(const ANode: TASTNodeBase); virtual; abstract;

    // ---- Top-level declarations (fluent) ----

    // #include <AName> or #include "AName"
    function Include(const AHeaderName: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; virtual; abstract;

    // struct AName { ... };
    function Struct(const AStructName: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; virtual; abstract;

    // Field inside a Struct context
    function AddField(const AFieldName, AFieldType: string): TIRBase; virtual; abstract;

    // };  — closes Struct
    function EndStruct(): TIRBase; virtual; abstract;

    // constexpr auto AName = AValueExpr;
    function DeclConst(const AConstName, AConstType, AValueExpr: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; virtual; abstract;

    // static AType AName = AInitExpr;
    function Global(const AGlobalName, AGlobalType, AInitExpr: string;
      const ATarget: TSourceFile = sfSource): TIRBase; virtual; abstract;

    // using AAlias = AOriginal;
    function Using(const AAlias, AOriginal: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; virtual; abstract;

    // namespace AName {
    function Namespace(const ANamespaceName: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; virtual; abstract;

    // } // namespace
    function EndNamespace(
      const ATarget: TSourceFile = sfHeader): TIRBase; virtual; abstract;

    // extern "C" AReturnType AName(AParams...);
    function ExternC(const AFuncName, AReturnType: string;
      const AParams: TArray<TArray<string>>;
      const ATarget: TSourceFile = sfHeader): TIRBase; virtual; abstract;

    // ---- Function builder (fluent) ----

    // AReturnType AName(...)  {
    function Func(const AFuncName, AReturnType: string): TIRBase; virtual; abstract;

    // Parameter inside Func context
    function Param(const AParamName, AParamType: string): TIRBase; virtual; abstract;

    // }  — closes Func
    function EndFunc(): TIRBase; virtual; abstract;

    // ---- Statement methods (fluent) ----

    // Local variable:  AType AName;
    function DeclVar(const AVarName, AVarType: string): TIRBase; overload; virtual; abstract;
    // Local variable:  AType AName = AInitExpr;
    function DeclVar(const AVarName, AVarType, AInitExpr: string): TIRBase; overload; virtual; abstract;

    // Assignment:  ALhs = AExpr;
    function Assign(const ALhs, AExpr: string): TIRBase; virtual; abstract;

    // Expression lhs assignment:  ATargetExpr = AValueExpr;
    function AssignTo(const ATargetExpr, AValueExpr: string): TIRBase; virtual; abstract;

    // Statement-form call:  AFunc(AArgs...);
    function Call(const AFuncName: string;
      const AArgs: TArray<string>): TIRBase; virtual; abstract;

    // Verbatim C++ statement line
    function Stmt(const ARawText: string): TIRBase; overload; virtual; abstract;
    // Formatted overload — ARawText is a Format() template, AArgs are the arguments
    function Stmt(const ARawText: string; const AArgs: array of const): TIRBase; overload; virtual; abstract;

    // return;
    function Return(): TIRBase; overload; virtual; abstract;
    // return AExpr;
    function Return(const AExpr: string): TIRBase; overload; virtual; abstract;

    // if (ACond) {
    function IfStmt(const ACondExpr: string): TIRBase; virtual; abstract;

    // } else if (ACond) {
    function ElseIfStmt(const ACondExpr: string): TIRBase; virtual; abstract;

    // } else {
    function ElseStmt(): TIRBase; virtual; abstract;

    // }  — closes if/else chain
    function EndIf(): TIRBase; virtual; abstract;

    // while (ACond) {
    function WhileStmt(const ACondExpr: string): TIRBase; virtual; abstract;

    // }  — closes while
    function EndWhile(): TIRBase; virtual; abstract;

    // for (auto AVar = AInit; ACond; AStep) {
    function ForStmt(const AVarName, AInitExpr, ACondExpr,
      AStepExpr: string): TIRBase; virtual; abstract;

    // }  — closes for
    function EndFor(): TIRBase; virtual; abstract;

    // break;
    function BreakStmt(): TIRBase; virtual; abstract;

    // continue;
    function ContinueStmt(): TIRBase; virtual; abstract;

    // Emit a blank line
    function BlankLine(
      const ATarget: TSourceFile = sfSource): TIRBase; virtual; abstract;

    // ---- Expression builders (return string — C++23 text fragments) ----

    // Literals
    function Lit(const AValue: Integer): string; overload; virtual; abstract;
    function Lit(const AValue: Int64): string; overload; virtual; abstract;
    function Float(const AValue: Double): string; virtual; abstract;
    function Str(const AValue: string): string; virtual; abstract;
    function Bool(const AValue: Boolean): string; virtual; abstract;
    function Null(): string; virtual; abstract;

    // Variable / member access
    function Get(const AVarName: string): string; virtual; abstract;
    function Field(const AObj, AMember: string): string; virtual; abstract;
    function Deref(const APtr, AMember: string): string; overload; virtual; abstract;
    function Deref(const APtr: string): string; overload; virtual; abstract;
    function AddrOf(const AVarName: string): string; virtual; abstract;
    function Index(const AArr, AIndexExpr: string): string; virtual; abstract;
    function Cast(const ATypeName, AExpr: string): string; virtual; abstract;

    // Expression-form call:  AFunc(AArgs...)  — returns string, no semicolon
    function Invoke(const AFuncName: string;
      const AArgs: TArray<string>): string; virtual; abstract;

    // Arithmetic
    function Add(const ALeft, ARight: string): string; virtual; abstract;
    function Sub(const ALeft, ARight: string): string; virtual; abstract;
    function Mul(const ALeft, ARight: string): string; virtual; abstract;
    function DivExpr(const ALeft, ARight: string): string; virtual; abstract;
    function ModExpr(const ALeft, ARight: string): string; virtual; abstract;
    function Neg(const AExpr: string): string; virtual; abstract;

    // Comparison
    function Eq(const ALeft, ARight: string): string; virtual; abstract;
    function Ne(const ALeft, ARight: string): string; virtual; abstract;
    function Lt(const ALeft, ARight: string): string; virtual; abstract;
    function Le(const ALeft, ARight: string): string; virtual; abstract;
    function Gt(const ALeft, ARight: string): string; virtual; abstract;
    function Ge(const ALeft, ARight: string): string; virtual; abstract;

    // Logical
    function AndExpr(const ALeft, ARight: string): string; virtual; abstract;
    function OrExpr(const ALeft, ARight: string): string; virtual; abstract;
    function NotExpr(const AExpr: string): string; virtual; abstract;

    // Bitwise
    function BitAnd(const ALeft, ARight: string): string; virtual; abstract;
    function BitOr(const ALeft, ARight: string): string; virtual; abstract;
    function BitXor(const ALeft, ARight: string): string; virtual; abstract;
    function BitNot(const AExpr: string): string; virtual; abstract;
    function ShlExpr(const ALeft, ARight: string): string; virtual; abstract;
    function ShrExpr(const ALeft, ARight: string): string; virtual; abstract;

    // Key/value context store for emitter handlers to share state across
    // handler calls (e.g. tracking the current function name).
    procedure SetContext(const AKey, AValue: string); virtual; abstract;
    function  GetContext(const AKey: string;
      const ADefault: string = ''): string; virtual; abstract;
  end;

  { TCodeGenBase
    Abstract base for the code generation orchestrator. The compiler pipeline
    calls Generate() to walk the enriched AST and produce output. Concrete
    implementations (TCodeGen for C++23, future backends for C/LLVM/JS)
    extend this base. }
  TCodeGenBase = class(TErrorsObject)
  public
    function Generate(const ARoot: TASTNodeBase): Boolean; virtual; abstract;
  end;

  { TSemanticBase
    Abstract base for the semantic engine. Semantic handlers registered via
    TLangConfig.RegisterSemanticRule receive TSemanticBase and call
    back via these virtuals to drive analysis, manage scope, and declare/resolve
    symbols. Handlers write enrichment attributes onto nodes using the
    ATTR_* constants — the AST is the data store, not this base class. }
  TSemanticBase = class(TErrorsObject)
  private
    FCompileModule: TFunc<string, Boolean>;
  public
    // Module compilation — called by semantic handlers to trigger dependency
    // compilation. Delegates to TMetamorf.CompileModule via closure.
    procedure SetCompileModule(const AFunc: TFunc<string, Boolean>);
    function  CompileModule(const AModuleName: string): Boolean;

    // Push a named scope level. AOpenToken is the token that opened the scope
    // (e.g. 'begin', '{') — recorded on the scope for LSP range queries.
    procedure PushScope(const AScopeName: string;
      const AOpenToken: TToken); virtual; abstract;

    // Pop the current scope back to its parent. ACloseToken is the token
    // that closed the scope — recorded on the scope for LSP range queries.
    procedure PopScope(const ACloseToken: TToken); virtual; abstract;

    // Declare a symbol in the current scope.
    // Returns False if a symbol with AName already exists in the current scope
    // (duplicate declaration — the handler should report an error).
    function DeclareSymbol(const AName: string;
      const ANode: TASTNodeBase): Boolean; virtual; abstract;

    // Look up a name in the current scope and all parent scopes.
    // Returns True and sets ANode to the declaring AST node if found.
    // Returns False (ANode = nil) if not found.
    function LookupSymbol(const AName: string;
      out ANode: TASTNodeBase): Boolean; virtual; abstract;

    // Look up a name in the current scope only (does not walk up the chain).
    // Returns True and sets ANode to the declaring AST node if found.
    // Returns False (ANode = nil) if not found in the current scope.
    function LookupSymbolLocal(const AName: string;
      out ANode: TASTNodeBase): Boolean; virtual; abstract;
    // Returns True if any symbol in the current scope has a name starting with APrefix.
    // Used for overload detection: check SymbolExistsWithPrefix('Foo(') to see if
    // another overload of 'Foo' already exists.
    function SymbolExistsWithPrefix(const APrefix: string): Boolean; virtual; abstract;
    // For all symbols in the current scope whose name starts with APrefix,
    // if their DeclNode has decl.linkage = '"C"', strip it to '' and
    // report warning W200. Returns the number of demotions performed.
    function DemoteCLinkageForPrefix(const APrefix: string): Integer; virtual; abstract;

    // Recurse into a single node — dispatch its handler or auto-visit children.
    // Handlers call this to drive traversal into child nodes they care about.
    procedure VisitNode(const ANode: TASTNodeBase); virtual; abstract;

    // Recurse into all children of ANode in order.
    // Handlers use this when they want the engine to walk an unstructured block.
    procedure VisitChildren(const ANode: TASTNodeBase); virtual; abstract;

    // Report a semantic error at the source location of ANode.
    // ACode is a short error code string (e.g. 'S200'), AMsg is human-readable.
    procedure AddSemanticError(const ANode: TASTNodeBase;
      const ACode, AMsg: string); virtual; abstract;
    // Report a semantic warning at the source location of ANode.
    // ACode is a short warning code string (e.g. 'W200'), AMsg is human-readable.
    procedure AddSemanticWarning(const ANode: TASTNodeBase;
      const ACode, AMsg: string); virtual; abstract;

    // Returns True if currently inside a named scope (function/procedure body).
    // False at the root/global scope level.
    function IsInsideRoutine(): Boolean; virtual; abstract;
  end;

  // Handler types
  // Defined here so both TLangConfig and the concrete components can
  // reference them from a single shared location.

  TStatementHandler =
    reference to function(AParser: TParserBase): TASTNodeBase;

  TPrefixHandler =
    reference to function(AParser: TParserBase): TASTNodeBase;

  TInfixHandler =
    reference to function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase;

  TEmitHandler =
    reference to procedure(ANode: TASTNodeBase; AGen: TIRBase);

  // Semantic handler — called by the engine for each registered node kind.
  // The handler enriches ANode by writing ATTR_* attributes onto it,
  // declares/resolves symbols via ASem, and drives traversal of child nodes
  // by calling ASem.VisitNode() or ASem.VisitChildren() as appropriate.
  TSemanticHandler =
    reference to procedure(const ANode: TASTNodeBase; ASem: TSemanticBase);

  // Type compatibility function — registered once per language via
  // TLangConfig.RegisterTypeCompat(). Called by the engine when it
  // needs to determine whether AFromType is assignable to AToType.
  // Returns True if compatible. If an implicit coercion is needed,
  // ACoerceTo is set to the target type kind string (the engine then
  // writes ATTR_COERCE_TO onto the node). If no coercion is needed,
  // ACoerceTo is set to empty string.
  TTypeCompatFunc =
    reference to function(const AFromType, AToType: string;
      out ACoerceTo: string): Boolean;

  // ExprToString callback — passed to overrides to delegate child nodes.
  TExprToStringFunc =
    reference to function(const ANode: TASTNodeBase): string;

  // ExprToString override for a specific node kind.
  TExprOverride =
    reference to function(const ANode: TASTNodeBase;
      const ADefault: TExprToStringFunc): string;

  // Config file persistence base

  { TConfigFileObject
    Base class for any Metamorf component that needs TOML config file
    persistence. Handles the filename, file existence checks, and
    TConfig lifecycle. Subclasses override DoLoadConfig and
    DoSaveConfig to read and write their specific fields. }
  TConfigFileObject = class(TBaseObject)
  private
    FConfigFilename: string;
  protected
    // Called by LoadConfig() after successfully loading the TOML file.
    // Subclasses override this to read their fields from AConfig.
    procedure DoLoadConfig(const AConfig: TConfig); virtual;

    // Called by SaveConfig() with a fresh TConfig ready to populate.
    // Subclasses override this to write their fields into AConfig.
    procedure DoSaveConfig(const AConfig: TConfig); virtual;
  public
    constructor Create(); override;

    // Set the TOML file path used by LoadConfig() and SaveConfig()
    procedure SetConfigFilename(const AFilename: string);
    function  GetConfigFilename(): string;

    // Overrides TBaseObject virtuals.
    // LoadConfig: checks filename, loads TOML file, delegates to DoLoadConfig.
    // SaveConfig: checks filename, delegates to DoSaveConfig, saves TOML file.
    procedure LoadConfig(); override;
    procedure SaveConfig(); override;
  end;

implementation

{ TSemanticBase }

procedure TSemanticBase.SetCompileModule(const AFunc: TFunc<string, Boolean>);
begin
  FCompileModule := AFunc;
end;

function TSemanticBase.CompileModule(const AModuleName: string): Boolean;
begin
  if Assigned(FCompileModule) then
    Result := FCompileModule(AModuleName)
  else
    Result := True;
end;

{ TASTNode }

constructor TASTNode.Create();
begin
  inherited;
  FNodeKind         := '';
  FChildren         := TObjectList<TASTNode>.Create(True);
  FAttributes       := TDictionary<string, TValue>.Create();
  FLeadingComments  := nil;
  FTrailingComments := nil;
end;

destructor TASTNode.Destroy();
begin
  FreeAndNil(FAttributes);
  FreeAndNil(FLeadingComments);
  FreeAndNil(FTrailingComments);
  FreeAndNil(FChildren);
  inherited;
end;

class function TASTNode.CreateNode(const ANodeKind: string;
  const AToken: TToken): TASTNode;
begin
  Result           := TASTNode.Create();
  Result.FNodeKind := ANodeKind;
  Result.FToken    := AToken;
end;

function TASTNode.GetNodeKind(): string;
begin
  Result := FNodeKind;
end;

function TASTNode.GetToken(): TToken;
begin
  Result := FToken;
end;

function TASTNode.ChildCount(): Integer;
begin
  Result := FChildren.Count;
end;

function TASTNode.GetChild(const AIndex: Integer): TASTNodeBase;
begin
  if (AIndex >= 0) and (AIndex < FChildren.Count) then
    Result := FChildren[AIndex]
  else
    Result := nil;
end;

function TASTNode.GetAttr(const AKey: string;
  out AValue: TValue): Boolean;
begin
  Result := FAttributes.TryGetValue(AKey, AValue);
end;

procedure TASTNode.AddChild(const ANode: TASTNode);
begin
  if ANode <> nil then
    FChildren.Add(ANode);
end;

procedure TASTNode.SetAttr(const AKey: string; const AValue: TValue);
begin
  if AKey <> '' then
    FAttributes.AddOrSetValue(AKey, AValue);
end;

function TASTNode.GetChildNode(const AIndex: Integer): TASTNode;
begin
  if (AIndex >= 0) and (AIndex < FChildren.Count) then
    Result := FChildren[AIndex]
  else
    Result := nil;
end;

procedure TASTNode.AddLeadingComment(const ANode: TASTNode);
begin
  if ANode = nil then
    Exit;
  if FLeadingComments = nil then
    FLeadingComments := TObjectList<TASTNode>.Create(True);
  FLeadingComments.Add(ANode);
end;

procedure TASTNode.AddTrailingComment(const ANode: TASTNode);
begin
  if ANode = nil then
    Exit;
  if FTrailingComments = nil then
    FTrailingComments := TObjectList<TASTNode>.Create(True);
  FTrailingComments.Add(ANode);
end;

function TASTNode.LeadingCommentCount(): Integer;
begin
  if FLeadingComments <> nil then
    Result := FLeadingComments.Count
  else
    Result := 0;
end;

function TASTNode.TrailingCommentCount(): Integer;
begin
  if FTrailingComments <> nil then
    Result := FTrailingComments.Count
  else
    Result := 0;
end;

function TASTNode.GetLeadingComment(const AIndex: Integer): TASTNode;
begin
  if (FLeadingComments <> nil) and
     (AIndex >= 0) and (AIndex < FLeadingComments.Count) then
    Result := FLeadingComments[AIndex]
  else
    Result := nil;
end;

function TASTNode.GetTrailingComment(const AIndex: Integer): TASTNode;
begin
  if (FTrailingComments <> nil) and
     (AIndex >= 0) and (AIndex < FTrailingComments.Count) then
    Result := FTrailingComments[AIndex]
  else
    Result := nil;
end;

function TASTNode.DumpNode(const ADepth: Integer): string;
var
  LIndent: string;
  LPair:   TPair<string, TValue>;
  LI:      Integer;
  LChild:  TASTNode;
begin
  LIndent := StringOfChar(' ', ADepth * 2);

  // Node kind and triggering token location
  Result := LIndent + '[' + FNodeKind + ']';
  if FToken.Filename <> '' then
    Result := Result + ' @ ' + FToken.Filename +
              '(' + IntToStr(FToken.Line) + ':' + IntToStr(FToken.Column) + ')';
  if FToken.Text <> '' then
    Result := Result + ' text=' + FToken.Text;
  Result := Result + sLineBreak;

  // Attributes
  for LPair in FAttributes do
    Result := Result + LIndent + '  attr.' + LPair.Key +
              ' = ' + LPair.Value.ToString() + sLineBreak;

  // Leading comment decorations
  for LI := 0 to LeadingCommentCount() - 1 do
    Result := Result + FLeadingComments[LI].DumpNode(ADepth + 1);

  // Children
  for LI := 0 to FChildren.Count - 1 do
  begin
    LChild := FChildren[LI];
    Result := Result + LChild.DumpNode(ADepth + 1);
  end;

  // Trailing comment decorations
  for LI := 0 to TrailingCommentCount() - 1 do
    Result := Result + FTrailingComments[LI].DumpNode(ADepth + 1);
end;

function TASTNode.Dump(const AId: Integer): string;
begin
  Result := DumpNode(0);
end;

{ TConfigFileObject }

constructor TConfigFileObject.Create();
begin
  inherited;
  FConfigFilename := '';
end;

procedure TConfigFileObject.SetConfigFilename(const AFilename: string);
begin
  FConfigFilename := AFilename;
end;

function TConfigFileObject.GetConfigFilename(): string;
begin
  Result := FConfigFilename;
end;

procedure TConfigFileObject.DoLoadConfig(const AConfig: TConfig);
begin
  // Base does nothing — subclasses override to read their specific fields
end;

procedure TConfigFileObject.DoSaveConfig(const AConfig: TConfig);
begin
  // Base does nothing — subclasses override to write their specific fields
end;

procedure TConfigFileObject.LoadConfig();
var
  LConfig: TConfig;
begin
  if FConfigFilename = '' then
    Exit;

  if not TFile.Exists(FConfigFilename) then
    Exit;

  LConfig := TConfig.Create();
  try
    if LConfig.LoadFromFile(FConfigFilename) then
      DoLoadConfig(LConfig);
  finally
    LConfig.Free();
  end;
end;

procedure TConfigFileObject.SaveConfig();
var
  LConfig: TConfig;
begin
  if FConfigFilename = '' then
    Exit;

  LConfig := TConfig.Create();
  try
    DoSaveConfig(LConfig);
    LConfig.SaveToFile(FConfigFilename);
  finally
    LConfig.Free();
  end;
end;

end.
