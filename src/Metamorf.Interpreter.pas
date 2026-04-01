{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Interpreter;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Defaults,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.AST,
  Metamorf.Common,
  Metamorf.Environment,
  Metamorf.Scopes,
  Metamorf.CodeGen;

const
  // .mor Interpreter Error Codes (MI001-MI099)
  ERR_MORINTERP_UNDEFINED_VAR    = 'MI001';
  ERR_MORINTERP_UNDEFINED_ROUTINE= 'MI002';
  ERR_MORINTERP_UNKNOWN_BUILTIN  = 'MI003';
  ERR_MORINTERP_TYPE_MISMATCH    = 'MI004';
  ERR_MORINTERP_NIL_NODE         = 'MI005';
  ERR_MORINTERP_CHILD_BOUNDS     = 'MI006';
  ERR_MORINTERP_DIV_ZERO         = 'MI007';
  ERR_MORINTERP_ATTR_NOT_FOUND   = 'MI008';
  ERR_MORINTERP_UNKNOWN_NODE     = 'MI009';
  ERR_MORINTERP_EMITTER_CRASH    = 'MI010';
  ERR_MORINTERP_BUILTIN_CRASH    = 'MI011';
  ERR_MORINTERP_BAD_INDEX_TYPE   = 'MI012';

type

  { EReturnSignal - exception used to unwind stack on 'return' }
  EReturnSignal = class(Exception)
  public
    ReturnValue: TValue;
    constructor Create(const AValue: TValue);
  end;

  { TOperatorEntryInterp }
  TOperatorEntryInterp = record
    Text: string;
    Kind: string;
  end;

  { TStringStyleEntry }
  TStringStyleEntry = record
    OpenText: string;
    Kind: string;
    Flags: string;
  end;

  { TLexerConfig }
  TLexerConfig = record
    CaseSensitive: Boolean;
    Terminator: string;
    BlockOpen: string;
    BlockClose: string;
    DirectivePrefix: string;
  end;

  { TInfixEntry }
  TInfixEntry = record
    Power: Integer;
    Assoc: string;
    RuleAST: TASTNode;
  end;

  { TSemanticPass }
  TSemanticPass = record
    PassNumber: Integer;
    PassName: string;
    Handlers: TDictionary<string, TASTNode>;
  end;

  { TSectionEntry }
  TSectionEntry = record
    SectionName: string;
    SectionAST: TASTNode;
  end;

  { TCompatEntry }
  TCompatEntry = record
    FromType: string;
    ToType: string;
    CoerceExpr: string;
  end;

  { Native handler types for C++ passthrough and external registration }
  TNativePrefixHandler = reference to function: TASTNode;
  TNativeInfixHandler = reference to function(const ALeft: TASTNode): TASTNode;
  TNativeStmtHandler = reference to function: TASTNode;
  TNativeEmitHandler = reference to procedure(const ANode: TASTNode);

  { TNativeInfixEntry }
  TNativeInfixEntry = record
    Power: Integer;
    Assoc: string;
    Handler: TNativeInfixHandler;
  end;

  { TCompileModuleFunc - callback to engine for module compilation }
  TCompileModuleFunc = function(const AModuleName: string): Boolean of object;

  { TImportMorFunc - callback to engine for .mor file import }
  TImportMorFunc = function(const AMorPath: string): TASTNode of object;

  { TMorInterpreter }
  TMorInterpreter = class(TErrorsObject)
  private
    // From tokens {} block
    FKeywords: TDictionary<string, string>;
    FOperators: TList<TOperatorEntryInterp>;
    FStringStyles: TList<TStringStyleEntry>;
    FLineComments: TList<string>;
    FBlockComments: TList<TPair<string, string>>;
    FDirectives: TDictionary<string, string>;
    FLexerConfig: TLexerConfig;

    // From types {} block
    FTypeKeywords: TDictionary<string, string>;
    FTypeMappings: TDictionary<string, string>;
    FLiteralTypes: TDictionary<string, string>;
    FCompatRules: TList<TCompatEntry>;
    FDeclKinds: TList<string>;
    FCallKinds: TList<string>;
    FCallNameAttr: string;

    // From grammar {} block
    FPrefixRules: TDictionary<string, TASTNode>;
    FInfixRules: TDictionary<string, TInfixEntry>;
    FStmtRules: TDictionary<string, TASTNode>;

    // From semantics {} block
    FSemanticHandlers: TDictionary<string, TASTNode>;
    FSemanticPasses: TList<TSemanticPass>;

    // From emitters {} block
    FEmitHandlers: TDictionary<string, TASTNode>;
    FBeforeBlock: TASTNode;
    FAfterBlock: TASTNode;
    FSections: TList<TSectionEntry>;

    // From routine/const/enum/fragment declarations
    FRoutines: TDictionary<string, TASTNode>;
    FConstants: TDictionary<string, TValue>;
    FFragments: TDictionary<string, TASTNode>;

    // Runtime state
    FEnv: TEnvironment;
    FCurrentNode: TASTNode;
    FResultNode: TASTNode;

    // Subcomponents wired by TMorEngine
    FScopes: TScopeManager;
    FOutput: TCodeOutput;
    FBuild: TObject;
    FActiveParser: TObject;
    FRuleErrorSnapshot: Integer;
    FModuleExtension: string;
    FCompileModuleFunc: TCompileModuleFunc;
    FImportMorFunc: TImportMorFunc;

    // Native handler dictionaries (for C++ passthrough)
    FNativePrefixRules: TDictionary<string, TNativePrefixHandler>;
    FNativeInfixRules: TDictionary<string, TNativeInfixEntry>;
    FNativeStmtRules: TDictionary<string, TNativeStmtHandler>;
    FNativeEmitHandlers: TDictionary<string, TNativeEmitHandler>;

    // Setup pass methods
    procedure WalkMorRoot(const ARoot: TASTNode);
    procedure WalkTokensBlock(const ABlock: TASTNode);
    procedure WalkTypesBlock(const ABlock: TASTNode);
    procedure WalkGrammarBlock(const ABlock: TASTNode);
    procedure WalkSemanticsBlock(const ABlock: TASTNode);
    procedure WalkEmittersBlock(const ABlock: TASTNode);
    procedure WalkRoutineDecl(const ANode: TASTNode);
    procedure WalkConstBlock(const ABlock: TASTNode);
    procedure WalkEnumDecl(const ANode: TASTNode);
    procedure WalkFragmentDecl(const ANode: TASTNode);
    function FindTriggerToken(const ARuleAST: TASTNode): string;
    function FindAllTriggerTokens(const ARuleAST: TASTNode): TArray<string>;

    // Core execution
    procedure ExecStmt(const ANode: TASTNode);
    procedure ExecBlock(const ABlock: TASTNode);
    function EvalExpr(const ANode: TASTNode): TValue;

    // Expression helpers
    function ApplyBinaryOp(const AOp: string;
      const ALeft: TValue; const ARight: TValue): TValue;
    function Interpolate(const ARawText: string): string;

    // Built-in function dispatch
    function CallBuiltin(const AName: string;
      const AArgs: TArray<TValue>): TValue;

    // User routine calls
    function CallRoutine(const AName: string;
      const AArgs: TArray<TValue>): TValue;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Setup pass: populate dispatch tables from .mor AST
    procedure RunSetup(const AMorRoot: TASTNode);

    // Accessors for dispatch tables (used by GenericLexer/GenericParser)
    function GetKeywords(): TDictionary<string, string>;
    function GetOperators(): TList<TOperatorEntryInterp>;
    function GetStringStyles(): TList<TStringStyleEntry>;
    function GetLineComments(): TList<string>;
    function GetBlockComments(): TList<TPair<string, string>>;
    function GetLexerConfig(): TLexerConfig;
    function GetDirectives(): TDictionary<string, string>;
    function GetPrefixRules(): TDictionary<string, TASTNode>;
    function GetInfixRules(): TDictionary<string, TInfixEntry>;
    function GetStmtRules(): TDictionary<string, TASTNode>;
    function GetSemanticHandlers(): TDictionary<string, TASTNode>;
    function GetEmitHandlers(): TDictionary<string, TASTNode>;
    function GetRoutines(): TDictionary<string, TASTNode>;
    function GetConstants(): TDictionary<string, TValue>;
    function GetEnvironment(): TEnvironment;

    // Subcomponent setters (called by TMorEngine)
    procedure SetBuild(const ABuild: TObject);
    procedure SetScopes(const AScopes: TScopeManager);
    procedure SetOutput(const AOutput: TCodeOutput);
    procedure SetActiveParser(const AParser: TObject);
    function GetOutput(): TCodeOutput;
    function GetActiveParser(): TObject;
    procedure SetCompileModuleFunc(const AFunc: TCompileModuleFunc);
    procedure SetImportMorFunc(const AFunc: TImportMorFunc);
    function GetModuleExtension(): string;

    // Native handler registration (called by Mor.Cpp)
    procedure RegisterNativePrefix(const AKind: string;
      const AHandler: TNativePrefixHandler);
    procedure RegisterNativeInfix(const AKind: string;
      const AEntry: TNativeInfixEntry);
    procedure RegisterNativeStmt(const AKind: string;
      const AHandler: TNativeStmtHandler);
    procedure RegisterNativeEmit(const AKind: string;
      const AHandler: TNativeEmitHandler);

    // Parser thin wrappers (called by Mor.Cpp closures)
    function ParserCurrentKind(): string;
    function ParserCurrentText(): string;
    procedure ParserAdvance();
    function ParserAtEnd(): Boolean;
    function ParserCurrentToken(): TToken;

    // Grammar rule execution (called by GenericParser)
    function ExecuteGrammarRule(const ARuleAST: TASTNode;
      const ALeft: TASTNode = nil): TASTNode;

    // Pipeline entry points (called by TMorEngine)
    procedure RunSemanticHandler(const AUserNode: TASTNode);
    procedure RunEmitHandler(const AUserNode: TASTNode);
    procedure RunSemantics(const AMasterRoot: TASTNode);
    procedure RunEmitters(const AMasterRoot: TASTNode);

    // Native handler accessors (used by GenericParser)
    function GetNativePrefixRules(): TDictionary<string, TNativePrefixHandler>;
    function GetNativeInfixRules(): TDictionary<string, TNativeInfixEntry>;
    function GetNativeStmtRules(): TDictionary<string, TNativeStmtHandler>;
    function GetNativeEmitHandlers(): TDictionary<string, TNativeEmitHandler>;
  end;

implementation

uses
  Metamorf.Lexer,
  Metamorf.Parser,
  Metamorf.GenericParser,
  Metamorf.Build;

{ EReturnSignal }

constructor EReturnSignal.Create(const AValue: TValue);
begin
  inherited Create('return');
  ReturnValue := AValue;
end;

{ TMorInterpreter }

constructor TMorInterpreter.Create();
begin
  inherited;

  // Tokens block
  FKeywords := TDictionary<string, string>.Create();
  FOperators := TList<TOperatorEntryInterp>.Create();
  FStringStyles := TList<TStringStyleEntry>.Create();
  FLineComments := TList<string>.Create();
  FBlockComments := TList<TPair<string, string>>.Create();
  FDirectives := TDictionary<string, string>.Create();
  FLexerConfig.CaseSensitive := True;
  FLexerConfig.Terminator := '';
  FLexerConfig.BlockOpen := '';
  FLexerConfig.BlockClose := '';
  FLexerConfig.DirectivePrefix := '';

  // Types block
  FTypeKeywords := TDictionary<string, string>.Create();
  FTypeMappings := TDictionary<string, string>.Create();
  FLiteralTypes := TDictionary<string, string>.Create();
  FCompatRules := TList<TCompatEntry>.Create();
  FDeclKinds := TList<string>.Create();
  FCallKinds := TList<string>.Create();
  FCallNameAttr := '';

  // Grammar block
  FPrefixRules := TDictionary<string, TASTNode>.Create();
  FInfixRules := TDictionary<string, TInfixEntry>.Create();
  FStmtRules := TDictionary<string, TASTNode>.Create();

  // Semantics block
  FSemanticHandlers := TDictionary<string, TASTNode>.Create();
  FSemanticPasses := TList<TSemanticPass>.Create();

  // Emitters block
  FEmitHandlers := TDictionary<string, TASTNode>.Create();
  FBeforeBlock := nil;
  FAfterBlock := nil;
  FSections := TList<TSectionEntry>.Create();

  // Routines/consts/fragments
  FRoutines := TDictionary<string, TASTNode>.Create();
  FConstants := TDictionary<string, TValue>.Create();
  FFragments := TDictionary<string, TASTNode>.Create();

  // Runtime
  FEnv := TEnvironment.Create();
  FCurrentNode := nil;
  FResultNode := nil;

  // Subcomponents (wired externally, not owned)
  FScopes := nil;
  FOutput := nil;
  FBuild := nil;
  FActiveParser := nil;
  FModuleExtension := '';

  // Native handler dictionaries
  FNativePrefixRules := TDictionary<string, TNativePrefixHandler>.Create();
  FNativeInfixRules := TDictionary<string, TNativeInfixEntry>.Create();
  FNativeStmtRules := TDictionary<string, TNativeStmtHandler>.Create();
  FNativeEmitHandlers := TDictionary<string, TNativeEmitHandler>.Create();
end;

destructor TMorInterpreter.Destroy();
var
  LI: Integer;
begin
  FreeAndNil(FNativeEmitHandlers);
  FreeAndNil(FNativeStmtRules);
  FreeAndNil(FNativeInfixRules);
  FreeAndNil(FNativePrefixRules);
  FreeAndNil(FEnv);
  FreeAndNil(FFragments);
  FreeAndNil(FConstants);
  FreeAndNil(FRoutines);
  FreeAndNil(FSections);
  FreeAndNil(FEmitHandlers);
  // Free per-pass handler dictionaries before freeing the list
  if Assigned(FSemanticPasses) then
  begin
    for LI := 0 to FSemanticPasses.Count - 1 do
      FSemanticPasses[LI].Handlers.Free();
  end;
  FreeAndNil(FSemanticPasses);
  FreeAndNil(FSemanticHandlers);
  FreeAndNil(FStmtRules);
  FreeAndNil(FInfixRules);
  FreeAndNil(FPrefixRules);
  FreeAndNil(FCallKinds);
  FreeAndNil(FDeclKinds);
  FreeAndNil(FCompatRules);
  FreeAndNil(FLiteralTypes);
  FreeAndNil(FTypeMappings);
  FreeAndNil(FTypeKeywords);
  FreeAndNil(FBlockComments);
  FreeAndNil(FDirectives);
  FreeAndNil(FLineComments);
  FreeAndNil(FStringStyles);
  FreeAndNil(FOperators);
  FreeAndNil(FKeywords);
  inherited;
end;

{ Setup Pass }

procedure TMorInterpreter.RunSetup(const AMorRoot: TASTNode);
begin
  WalkMorRoot(AMorRoot);
end;

procedure TMorInterpreter.WalkMorRoot(const ARoot: TASTNode);
var
  LI: Integer;
  LChild: TASTNode;
  LKind: string;
  LImportAST: TASTNode;
  LFragAST: TASTNode;
begin
  for LI := 0 to ARoot.ChildCount() - 1 do
  begin
    LChild := ARoot.GetChild(LI);
    LKind := LChild.GetKind();

    if LKind = 'meta.language_decl' then
      // Nothing to do, informational only
    else if LKind = 'meta.tokens_block' then
      WalkTokensBlock(LChild)
    else if LKind = 'meta.types_block' then
      WalkTypesBlock(LChild)
    else if LKind = 'meta.grammar_block' then
      WalkGrammarBlock(LChild)
    else if LKind = 'meta.semantics_block' then
      WalkSemanticsBlock(LChild)
    else if LKind = 'meta.emitters_block' then
      WalkEmittersBlock(LChild)
    else if LKind = 'meta.routine' then
      WalkRoutineDecl(LChild)
    else if LKind = 'meta.const_block' then
      WalkConstBlock(LChild)
    else if LKind = 'meta.enum' then
      WalkEnumDecl(LChild)
    else if LKind = 'meta.fragment' then
      WalkFragmentDecl(LChild)
    else if LKind = 'meta.import' then
    begin
      // Import external .mor file: lex/parse via engine callback, walk its declarations
      if Assigned(FImportMorFunc) then
      begin
        LImportAST := FImportMorFunc(LChild.GetAttr('path'));
        if Assigned(LImportAST) then
          WalkMorRoot(LImportAST);
      end;
    end
    else if LKind = 'meta.include' then
    begin
      // Top-level fragment expansion
      if FFragments.TryGetValue(LChild.GetAttr('path'), LFragAST) then
        if LFragAST.ChildCount() > 0 then
          WalkMorRoot(LFragAST.GetChild(0));
    end
    else if LKind = 'meta.guard' then
    begin
      // Conditional feature inclusion: evaluate condition, walk body if true
      if MorIsTrue(EvalExpr(LChild.GetChild(0))) then
        if LChild.ChildCount() > 1 then
          WalkMorRoot(LChild.GetChild(1));
    end
    ;
  end;
end;

procedure TMorInterpreter.WalkTokensBlock(const ABlock: TASTNode);
var
  LI: Integer;
  LChild: TASTNode;
  LFragAST: TASTNode;
  LKind: string;
  LTokenKind: string;
  LText: string;
  LFlags: string;
  LEntry: TOperatorEntryInterp;
  LStyle: TStringStyleEntry;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
  begin
    LChild := ABlock.GetChild(LI);
    LKind := LChild.GetKind();

    // Fragment include expansion
    if LKind = 'meta.include' then
    begin
      if FFragments.TryGetValue(LChild.GetAttr('path'), LFragAST) then
        if LFragAST.ChildCount() > 0 then
          WalkTokensBlock(LFragAST.GetChild(0));
      Continue;
    end;

    if LKind = 'meta.token_decl' then
    begin
      LTokenKind := LChild.GetAttr('kind');
      LText := LChild.GetAttr('text');
      LFlags := LChild.GetAttr('flags');

      // Route by kind prefix
      if LTokenKind.StartsWith('keyword.') then
        FKeywords.AddOrSetValue(LText, LTokenKind)
      else if LTokenKind.StartsWith('op.') or LTokenKind.StartsWith('delimiter.') then
      begin
        LEntry.Text := LText;
        LEntry.Kind := LTokenKind;
        FOperators.Add(LEntry);
      end
      else if LTokenKind.StartsWith('comment.line') then
        FLineComments.Add(LText)
      else if LTokenKind.StartsWith('comment.block_open') then
        FBlockComments.Add(TPair<string, string>.Create(LText, ''))
      else if LTokenKind.StartsWith('comment.block_close') then
      begin
        // Pair with last block_open
        if FBlockComments.Count > 0 then
          FBlockComments[FBlockComments.Count - 1] :=
            TPair<string, string>.Create(
              FBlockComments[FBlockComments.Count - 1].Key, LText);
      end
      else if LTokenKind.StartsWith('string.') then
      begin
        LStyle.OpenText := LText;
        LStyle.Kind := LTokenKind;
        LStyle.Flags := LFlags;
        FStringStyles.Add(LStyle);
      end
      else if LTokenKind.StartsWith('directive.') then
        FDirectives.AddOrSetValue(LText, LTokenKind);
    end
    else if LKind = 'meta.config_entry' then
    begin
      // Handle lexer config entries like casesensitive, terminator, etc.
      if LChild.GetAttr('key') = 'casesensitive' then
        FLexerConfig.CaseSensitive := LChild.GetAttr('value') = 'true'
      else if LChild.GetAttr('key') = 'terminator' then
        FLexerConfig.Terminator := LChild.GetAttr('value')
      else if LChild.GetAttr('key') = 'block_open' then
        FLexerConfig.BlockOpen := LChild.GetAttr('value')
      else if LChild.GetAttr('key') = 'block_close' then
        FLexerConfig.BlockClose := LChild.GetAttr('value')
      else if LChild.GetAttr('key') = 'directive_prefix' then
        FLexerConfig.DirectivePrefix := LChild.GetAttr('value');
    end;
  end;

  // Sort operators longest-first for correct matching
  FOperators.Sort(TComparer<TOperatorEntryInterp>.Construct(
    function(const ALeft, ARight: TOperatorEntryInterp): Integer
    begin
      Result := Length(ARight.Text) - Length(ALeft.Text);
    end));
end;

procedure TMorInterpreter.WalkTypesBlock(const ABlock: TASTNode);
var
  LI: Integer;
  LChild: TASTNode;
  LFragAST: TASTNode;
  LKind: string;
  LKey: string;
  LValue: string;
  LEntry: TCompatEntry;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
  begin
    LChild := ABlock.GetChild(LI);
    LKind := LChild.GetKind();
    LKey := LChild.GetAttr('key');
    LValue := LChild.GetAttr('value');

    // Fragment include expansion
    if LKind = 'meta.include' then
    begin
      if FFragments.TryGetValue(LChild.GetAttr('path'), LFragAST) then
        if LFragAST.ChildCount() > 0 then
          WalkTypesBlock(LFragAST.GetChild(0));
      Continue;
    end;

    if LKind = 'meta.type_map' then
      FTypeMappings.AddOrSetValue(LKey, LValue)
    else if LKind = 'meta.literal_type' then
      FLiteralTypes.AddOrSetValue(LKey, LValue)
    else if LKind = 'meta.compatible' then
    begin
      LEntry.FromType := LKey;
      LEntry.ToType := LValue;
      LEntry.CoerceExpr := LChild.GetAttr('coerce');
      FCompatRules.Add(LEntry);
    end
    else if LKind = 'meta.decl_kind' then
      FDeclKinds.Add(LValue)
    else if LKind = 'meta.call_kind' then
      FCallKinds.Add(LValue)
    else if LKind = 'meta.call_name_attr' then
      FCallNameAttr := LValue
    else if LKind = 'meta.name_mangler' then
      // Store name mangler info if needed
    else if LKind = 'meta.config_entry' then
      FTypeKeywords.AddOrSetValue(LKey, LValue);
  end;
end;

procedure TMorInterpreter.WalkGrammarBlock(const ABlock: TASTNode);
var
  LI: Integer;
  LChild: TASTNode;
  LFragAST: TASTNode;
  LNodeKind: string;
  LTrigger: string;
  LTriggers: TArray<string>;
  LTriggerItem: string;
  LInfix: TInfixEntry;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
  begin
    LChild := ABlock.GetChild(LI);

    // Fragment include expansion
    if LChild.GetKind() = 'meta.include' then
    begin
      if FFragments.TryGetValue(LChild.GetAttr('path'), LFragAST) then
        if LFragAST.ChildCount() > 0 then
          WalkGrammarBlock(LFragAST.GetChild(0));
      Continue;
    end;

    if LChild.GetKind() <> 'meta.rule' then
      Continue;

    LNodeKind := LChild.GetAttr('node_kind');
    LTrigger := FindTriggerToken(LChild);

    // If FindTriggerToken couldn't determine a real trigger (returned node_kind
    // as fallback), default to 'identifier' for statement rules. This handles
    // identifier-led statements like assignments and expression-statements
    // whose rules start with parseExpr() instead of expect/consume.
    if (LTrigger = LNodeKind) and LNodeKind.StartsWith('stmt.') then
      LTrigger := 'identifier';

    if LChild.HasAttr('power') then
    begin
      // Infix rule -- register for ALL trigger tokens from multi-consume lists
      // so that operators like <=, >=, <>, -, / all get registered, not just
      // the first operator in the consume list.
      LInfix.Power := StrToIntDef(LChild.GetAttr('power'), 0);
      LInfix.Assoc := LChild.GetAttr('assoc');
      LInfix.RuleAST := LChild;
      LTriggers := FindAllTriggerTokens(LChild);
      for LTriggerItem in LTriggers do
        FInfixRules.AddOrSetValue(LTriggerItem, LInfix);
    end
    else if LNodeKind.StartsWith('stmt.') then
      FStmtRules.AddOrSetValue(LTrigger, LChild)
    else
      FPrefixRules.AddOrSetValue(LTrigger, LChild);
  end;
end;

function TMorInterpreter.FindTriggerToken(const ARuleAST: TASTNode): string;
var
  LI: Integer;
  LChild: TASTNode;
  LKind: string;
  LKinds: string;
begin
  // Scan rule body for first expect or consume node to determine trigger token
  for LI := 0 to ARuleAST.ChildCount() - 1 do
  begin
    LChild := ARuleAST.GetChild(LI);
    LKind := LChild.GetKind();

    if LKind = 'meta.expect' then
      Exit(LChild.GetAttr('token_kind'));

    if LKind = 'meta.consume' then
    begin
      // Single kind or list
      if LChild.HasAttr('token_kind') then
        Exit(LChild.GetAttr('token_kind'));
      if LChild.HasAttr('token_kinds') then
      begin
        LKinds := LChild.GetAttr('token_kinds');
        // Return first kind from comma-separated list
        if Pos(',', LKinds) > 0 then
          Exit(Copy(LKinds, 1, Pos(',', LKinds) - 1))
        else
          Exit(LKinds);
      end;
    end;
  end;

  // Fallback: use the node_kind as trigger (shouldn't happen in well-formed .mor)
  Result := ARuleAST.GetAttr('node_kind');
end;

function TMorInterpreter.FindAllTriggerTokens(
  const ARuleAST: TASTNode): TArray<string>;
var
  LI: Integer;
  LChild: TASTNode;
  LKind: string;
  LKinds: string;
  LParts: TArray<string>;
  LJ: Integer;
begin
  // Scan rule body for first expect or consume node to determine all trigger
  // tokens. For multi-consume rules (e.g. consume [op.eq, op.neq, op.lt]),
  // returns all token kinds so that each can be registered as an infix trigger.
  for LI := 0 to ARuleAST.ChildCount() - 1 do
  begin
    LChild := ARuleAST.GetChild(LI);
    LKind := LChild.GetKind();

    if LKind = 'meta.expect' then
      Exit(TArray<string>.Create(LChild.GetAttr('token_kind')));

    if LKind = 'meta.consume' then
    begin
      // Single kind
      if LChild.HasAttr('token_kind') then
        Exit(TArray<string>.Create(LChild.GetAttr('token_kind')));
      // Multi-kind list: split by comma and return all
      if LChild.HasAttr('token_kinds') then
      begin
        LKinds := LChild.GetAttr('token_kinds');
        LParts := LKinds.Split([',']);
        // Trim whitespace from each part
        for LJ := 0 to Length(LParts) - 1 do
          LParts[LJ] := Trim(LParts[LJ]);
        Exit(LParts);
      end;
    end;
  end;

  // Fallback: use the node_kind as trigger
  Result := TArray<string>.Create(ARuleAST.GetAttr('node_kind'));
end;

procedure TMorInterpreter.WalkSemanticsBlock(const ABlock: TASTNode);
var
  LI: Integer;
  LChild: TASTNode;
  LFragAST: TASTNode;
  LKind: string;
  LPass: TSemanticPass;
  LJ: Integer;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
  begin
    LChild := ABlock.GetChild(LI);
    LKind := LChild.GetKind();

    // Fragment include expansion
    if LKind = 'meta.include' then
    begin
      if FFragments.TryGetValue(LChild.GetAttr('path'), LFragAST) then
        if LFragAST.ChildCount() > 0 then
          WalkSemanticsBlock(LFragAST.GetChild(0));
      Continue;
    end;

    if LKind = 'meta.on_handler' then
      FSemanticHandlers.AddOrSetValue(LChild.GetAttr('node_kind'), LChild)
    else if LKind = 'meta.pass' then
    begin
      LPass.PassNumber := StrToIntDef(LChild.GetAttr('pass_number'), 0);
      LPass.PassName := LChild.GetAttr('pass_name');
      LPass.Handlers := TDictionary<string, TASTNode>.Create();
      // Collect handlers within this pass
      for LJ := 0 to LChild.ChildCount() - 1 do
      begin
        if LChild.GetChild(LJ).GetKind() = 'meta.on_handler' then
          LPass.Handlers.AddOrSetValue(
            LChild.GetChild(LJ).GetAttr('node_kind'),
            LChild.GetChild(LJ));
      end;
      FSemanticPasses.Add(LPass);
    end;
  end;
end;

procedure TMorInterpreter.WalkEmittersBlock(const ABlock: TASTNode);
var
  LI: Integer;
  LChild: TASTNode;
  LFragAST: TASTNode;
  LKind: string;
  LSection: TSectionEntry;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
  begin
    LChild := ABlock.GetChild(LI);
    LKind := LChild.GetKind();

    // Fragment include expansion
    if LKind = 'meta.include' then
    begin
      if FFragments.TryGetValue(LChild.GetAttr('path'), LFragAST) then
        if LFragAST.ChildCount() > 0 then
          WalkEmittersBlock(LFragAST.GetChild(0));
      Continue;
    end;

    if LKind = 'meta.on_handler' then
      FEmitHandlers.AddOrSetValue(LChild.GetAttr('node_kind'), LChild)
    else if LKind = 'meta.section' then
    begin
      LSection.SectionName := LChild.GetAttr('identifier');
      LSection.SectionAST := LChild;
      FSections.Add(LSection);
    end
    else if LKind = 'meta.before' then
      FBeforeBlock := LChild
    else if LKind = 'meta.after' then
      FAfterBlock := LChild;
  end;
end;

procedure TMorInterpreter.WalkRoutineDecl(const ANode: TASTNode);
begin
  FRoutines.AddOrSetValue(ANode.GetAttr('identifier'), ANode);
end;

procedure TMorInterpreter.WalkConstBlock(const ABlock: TASTNode);
var
  LI: Integer;
  LChild: TASTNode;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
  begin
    LChild := ABlock.GetChild(LI);
    if LChild.GetKind() = 'meta.const_decl' then
    begin
      if LChild.ChildCount() > 0 then
        FConstants.AddOrSetValue(LChild.GetAttr('identifier'),
          EvalExpr(LChild.GetChild(0)));
    end;
  end;
end;

procedure TMorInterpreter.WalkEnumDecl(const ANode: TASTNode);
var
  LCount: Integer;
  LI: Integer;
  LMemberName: string;
begin
  LCount := StrToIntDef(ANode.GetAttr('member_count'), 0);
  for LI := 0 to LCount - 1 do
  begin
    LMemberName := ANode.GetAttr('member_' + IntToStr(LI));
    if LMemberName <> '' then
      FConstants.AddOrSetValue(LMemberName, TValue.From<Int64>(LI));
  end;
end;

procedure TMorInterpreter.WalkFragmentDecl(const ANode: TASTNode);
begin
  FFragments.AddOrSetValue(ANode.GetAttr('identifier'), ANode);
end;

{ Core Execution }

procedure TMorInterpreter.ExecBlock(const ABlock: TASTNode);
var
  LI: Integer;
begin
  for LI := 0 to ABlock.ChildCount() - 1 do
  begin
    if Assigned(FErrors) and FErrors.ReachedMaxErrors() then
      Break;
    ExecStmt(ABlock.GetChild(LI));
  end;
end;

procedure TMorInterpreter.ExecStmt(const ANode: TASTNode);
var
  LKind: string;
  LCond: TValue;
  LCount: Int64;
  LI: Int64;
  LVarName: string;
  LValue: TValue;
  LMatchVal: TValue;
  LArm: TASTNode;
  LArmVal: TValue;
  LMatched: Boolean;
  LJ: Integer;
  LGenParser: TGenericParser;
  LTargetStr: string;
  LScopeName: string;
  LSym: TSymbol;
  LMode: string;
  LAttrName: string;
  LChildNode: TASTNode;
  LTokenKind: string;
  LExprNode: TASTNode;
  LBlock: TASTNode;
  LSavedPos: Integer;
  LKindsList: string;
  LKindsArr: TArray<string>;
  LFoundKind: Boolean;
  LChildIdx: Integer;
begin
  LKind := ANode.GetKind();

  // let var = expr;
  if LKind = 'meta.let' then
  begin
    LVarName := ANode.GetAttr('var_name');
    if ANode.ChildCount() > 0 then
      LValue := EvalExpr(ANode.GetChild(0))
    else
      LValue := TValue.Empty;
    FEnv.SetVar(LVarName, LValue);
  end

  // set var to expr;
  else if LKind = 'meta.set' then
  begin
    LVarName := ANode.GetAttr('var_name');
    if ANode.ChildCount() > 0 then
      LValue := EvalExpr(ANode.GetChild(0))
    else
      LValue := TValue.Empty;
    FEnv.UpdateVar(LVarName, LValue);
  end

  // assignment: expr = expr;
  else if LKind = 'meta.assign' then
  begin
    // Child 0 should be an ident or attr
    if (ANode.ChildCount() >= 2) and
       (ANode.GetChild(0).GetKind() = 'expr.ident') then
    begin
      LVarName := ANode.GetChild(0).GetAttr('identifier');
      LValue := EvalExpr(ANode.GetChild(1));
      FEnv.UpdateVar(LVarName, LValue);
    end;
  end

  // if cond { ... } else { ... }
  else if LKind = 'meta.if' then
  begin
    LCond := EvalExpr(ANode.GetChild(0));
    if MorIsTrue(LCond) then
      ExecBlock(ANode.GetChild(1))
    else if ANode.ChildCount() > 2 then
    begin
      // else block or else-if
      if ANode.GetChild(2).GetKind() = 'meta.if' then
        ExecStmt(ANode.GetChild(2))
      else
        ExecBlock(ANode.GetChild(2));
    end;
  end

  // while cond { ... }
  else if LKind = 'meta.while' then
  begin
    LCount := 0;
    while True do
    begin
      LCond := EvalExpr(ANode.GetChild(0));
      if not MorIsTrue(LCond) then Break;
      ExecBlock(ANode.GetChild(1));
      if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
      Inc(LCount);
      if LCount > 100000 then
      begin
        if Assigned(FErrors) then
          FErrors.Add(esError, ERR_MORINTERP_UNKNOWN_NODE,
            'Infinite loop detected (exceeded 100000 iterations)');
        Break;
      end;
    end;
  end

  // for var in count { ... }
  else if LKind = 'meta.for_in' then
  begin
    LVarName := ANode.GetAttr('var_name');
    LValue := EvalExpr(ANode.GetChild(0));
    if (LValue.Kind = tkInt64) then
      LCount := LValue.AsInt64()
    else if (LValue.Kind = tkInteger) then
      LCount := LValue.AsInteger()
    else
      LCount := 0;
    for LI := 0 to LCount - 1 do
    begin
      FEnv.SetVar(LVarName, TValue.From<Int64>(LI));
      ExecBlock(ANode.GetChild(1));
      if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
    end;
  end

  // match expr { pattern => { ... } }
  else if LKind = 'meta.match' then
  begin
    LMatchVal := EvalExpr(ANode.GetChild(0));
    LMatched := False;
    for LJ := 1 to ANode.ChildCount() - 1 do
    begin
      LArm := ANode.GetChild(LJ);
      if LArm.GetKind() = 'meta.match_else' then
      begin
        if not LMatched then
          ExecBlock(LArm.GetChild(0));
        Break;
      end
      else if LArm.GetKind() = 'meta.match_arm' then
      begin
        // Check each pattern (all children except last are patterns, last is body)
        for LI := 0 to LArm.ChildCount() - 2 do
        begin
          LArmVal := EvalExpr(LArm.GetChild(LI));
          if MorToString(LMatchVal) = MorToString(LArmVal) then
          begin
            LMatched := True;
            ExecBlock(LArm.GetChild(LArm.ChildCount() - 1));
            Break;
          end;
        end;
        if LMatched then Break;
      end;
    end;
  end

  // guard cond { ... }
  else if LKind = 'meta.guard' then
  begin
    LCond := EvalExpr(ANode.GetChild(0));
    if MorIsTrue(LCond) then
      ExecBlock(ANode.GetChild(1));
  end

  // return expr;
  else if LKind = 'meta.return' then
  begin
    if ANode.ChildCount() > 0 then
      LValue := EvalExpr(ANode.GetChild(0))
    else
      LValue := TValue.Empty;
    raise EReturnSignal.Create(LValue);
  end

  // try { ... } recover { ... }
  else if LKind = 'meta.try_recover' then
  begin
    try
      ExecBlock(ANode.GetChild(0));
    except
      on E: EReturnSignal do
        raise; // re-raise return signals
      on E: Exception do
      begin
        if ANode.ChildCount() > 1 then
          ExecBlock(ANode.GetChild(1));
      end;
    end;
  end

  // expression statement
  else if LKind = 'meta.expr_stmt' then
  begin
    if ANode.ChildCount() > 0 then
      EvalExpr(ANode.GetChild(0));
  end

  // block
  else if LKind = 'meta.block' then
    ExecBlock(ANode)

  // emit expr;
  else if LKind = 'meta.emit' then
  begin
    if ANode.ChildCount() > 0 then
    begin
      LValue := EvalExpr(ANode.GetChild(0));
      if Assigned(FOutput) then
      begin
        LTargetStr := ANode.GetAttr('target');
        if LTargetStr = 'header' then
          FOutput.Emit(MorToString(LValue), otHeader)
        else
          FOutput.Emit(MorToString(LValue), otSource);
      end;
    end;
  end

  // indent { ... }
  else if LKind = 'meta.indent_block' then
  begin
    if Assigned(FOutput) then
      FOutput.IndentIn();
    try
      if ANode.ChildCount() > 0 then
        ExecBlock(ANode.GetChild(0));
    finally
      if Assigned(FOutput) then
        FOutput.IndentOut();
    end;
  end

  // expect token_kind; (grammar context)
  else if LKind = 'meta.expect' then
  begin
    if Assigned(FActiveParser) then
    begin
      LGenParser := TGenericParser(FActiveParser);
      LTokenKind := ANode.GetAttr('token_kind');
      LGenParser.Expect(LTokenKind);
    end;
  end

  // consume kind -> @attr; (grammar context)
  else if LKind = 'meta.consume' then
  begin
    if Assigned(FActiveParser) then
    begin
      LGenParser := TGenericParser(FActiveParser);
      LAttrName := ANode.GetAttr('target_attr');
      LKindsList := ANode.GetAttr('token_kinds');
      if LKindsList <> '' then
      begin
        // Multiple acceptable kinds: [kind1, kind2, ...]
        LKindsArr := LKindsList.Split([',']);
        LFoundKind := False;
        for LJ := 0 to Length(LKindsArr) - 1 do
        begin
          if LGenParser.Check(Trim(LKindsArr[LJ])) then
          begin
            LFoundKind := True;
            Break;
          end;
        end;
        if LFoundKind then
        begin
          if Assigned(FResultNode) then
            FResultNode.SetAttr(LAttrName, LGenParser.Current().Text);
          LGenParser.DoAdvance();
        end
        else if Assigned(FErrors) then
          FErrors.Add(esError, ERR_MORINTERP_TYPE_MISMATCH,
            RSMorInterpTypeMismatch, [LKindsList, LGenParser.Current().Kind]);
      end
      else
      begin
        // Single kind
        LTokenKind := ANode.GetAttr('token_kind');
        if LGenParser.Check(LTokenKind) then
        begin
          if Assigned(FResultNode) then
            FResultNode.SetAttr(LAttrName, LGenParser.Current().Text);
          LGenParser.DoAdvance();
        end
        else if Assigned(FErrors) then
          FErrors.Add(esError, ERR_MORINTERP_TYPE_MISMATCH,
            RSMorInterpTypeMismatch, [LTokenKind, LGenParser.Current().Kind]);
      end;
    end;
  end

  // parse expr/many -> @attr; (grammar context)
  else if LKind = 'meta.parse_directive' then
  begin
    if Assigned(FActiveParser) then
    begin
      LGenParser := TGenericParser(FActiveParser);
      LMode := ANode.GetAttr('mode');
      LAttrName := ANode.GetAttr('target_attr');
      if LMode = 'expr' then
      begin
        LExprNode := LGenParser.ParseExpression(0);
        if Assigned(FResultNode) then
        begin
          FResultNode.AddChild(LExprNode);
          FResultNode.SetNamedChild(LAttrName, LExprNode);
        end;;
      end
      else if LMode = 'many' then
      begin
        LBlock := TASTNode.Create();
        LBlock.SetKind('meta.block');
        LKindsList := ANode.GetAttr('until_kinds');
        if LKindsList = '' then
          LKindsList := ANode.GetAttr('until_kind');
        LKindsArr := LKindsList.Split([',']);
        while not LGenParser.AtEnd() do
        begin
          // Check if current token matches any until kind
          LFoundKind := False;
          for LJ := 0 to Length(LKindsArr) - 1 do
          begin
            if LGenParser.Check(Trim(LKindsArr[LJ])) then
            begin
              LFoundKind := True;
              Break;
            end;
          end;
          if LFoundKind then Break;
          if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
          LSavedPos := LGenParser.Current().Line * 10000 + LGenParser.Current().Col;
          LBlock.AddChild(LGenParser.ParseStatement());
          // Stuck detection: if parser didn't advance, skip token
          if (LGenParser.Current().Line * 10000 + LGenParser.Current().Col) = LSavedPos then
          begin
            if not LGenParser.AtEnd() then
              LGenParser.DoAdvance();
            Break;
          end;
        end;
        if Assigned(FResultNode) then
        begin
          FResultNode.AddChild(LBlock);
          FResultNode.SetNamedChild(LAttrName, LBlock);
        end;
      end;
    end;
  end

  // optional { ... } (grammar context)
  else if LKind = 'meta.optional' then
  begin
    if Assigned(FActiveParser) then
    begin
      LGenParser := TGenericParser(FActiveParser);
      LSavedPos := LGenParser.GetPos();
      try
        ExecBlock(ANode.GetChild(0));
      except
        on E: EReturnSignal do
          raise;
        on E: Exception do
        begin
          // Parse failed, restore parser position and silently ignore
          LGenParser.SetPos(LSavedPos);
        end;
      end;
    end
    else if ANode.ChildCount() > 0 then
    begin
      try
        ExecBlock(ANode.GetChild(0));
      except
        on E: EReturnSignal do
          raise;
        on E: Exception do
        begin
          // Optional block failed, silently ignore
        end;
      end;
    end;
  end

  // scope name { ... } (semantics context)
  else if LKind = 'meta.scope' then
  begin
    if ANode.HasAttr('scope_attr') then
      LScopeName := FCurrentNode.GetAttr(ANode.GetAttr('scope_attr'))
    else
      LScopeName := ANode.GetAttr('scope_name');
    if Assigned(FScopes) then
      FScopes.Push(LScopeName);
    try
      if ANode.ChildCount() > 0 then
        ExecBlock(ANode.GetChild(0));
    finally
      if Assigned(FScopes) then
        FScopes.Pop();
    end;
  end

  // declare @name as kind; (semantics context)
  else if LKind = 'meta.declare' then
  begin
    if Assigned(FScopes) and Assigned(FCurrentNode) then
    begin
      LAttrName := ANode.GetAttr('name_attr');
      LVarName := FCurrentNode.GetAttr(LAttrName);
      LMode := ANode.GetAttr('sym_kind');
      FScopes.Declare(LVarName, LMode, FCurrentNode);
      // Optional typed declaration
      if ANode.HasAttr('type_attr') then
      begin
        LSym := FScopes.Lookup(LVarName);
        if Assigned(LSym) then
          LSym.SetTypeName(FCurrentNode.GetAttr(ANode.GetAttr('type_attr')));
      end;
    end;
  end

  // visit children/attr/index; (semantics context)
  else if LKind = 'meta.visit' then
  begin
    LMode := ANode.GetAttr('mode');
    if Assigned(FCurrentNode) then
    begin
      if LMode = 'children' then
      begin
        for LJ := 0 to FCurrentNode.ChildCount() - 1 do
        begin
          if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
          RunSemanticHandler(FCurrentNode.GetChild(LJ));
        end;
      end
      else if LMode = 'attr' then
      begin
        LAttrName := ANode.GetAttr('attr_name');
        LChildNode := FCurrentNode.GetNamedChild(LAttrName);
        if Assigned(LChildNode) then
          RunSemanticHandler(LChildNode);
      end
      else if LMode = 'index' then
      begin
        LChildIdx := StrToIntDef(ANode.GetAttr('child_index'), -1);
        if (LChildIdx >= 0) and (LChildIdx < FCurrentNode.ChildCount()) then
          RunSemanticHandler(FCurrentNode.GetChild(LChildIdx));
      end;
    end;
  end

  // lookup @name -> let var; or lookup @name or { ... }
  else if LKind = 'meta.lookup' then
  begin
    if Assigned(FScopes) and Assigned(FCurrentNode) then
    begin
      LAttrName := ANode.GetAttr('name_attr');
      LVarName := FCurrentNode.GetAttr(LAttrName);
      LMode := ANode.GetAttr('mode');
      LSym := FScopes.Lookup(LVarName);
      if LMode = 'bind' then
      begin
        if Assigned(LSym) then
          FEnv.SetVar(ANode.GetAttr('bind_var'), TValue.From<TObject>(LSym))
        else
          FEnv.SetVar(ANode.GetAttr('bind_var'), TValue.Empty);
      end
      else if LMode = 'or_block' then
      begin
        if not Assigned(LSym) then
        begin
          if ANode.ChildCount() > 0 then
            ExecBlock(ANode.GetChild(0));
        end;
      end;
    end;
  end

  // section name { ... }
  else if LKind = 'meta.section' then
  begin
    if ANode.ChildCount() > 0 then
      ExecBlock(ANode.GetChild(0));
  end

  // before { ... }
  else if LKind = 'meta.before' then
  begin
    if ANode.ChildCount() > 0 then
      ExecBlock(ANode.GetChild(0));
  end

  // after { ... }
  else if LKind = 'meta.after' then
  begin
    if ANode.ChildCount() > 0 then
      ExecBlock(ANode.GetChild(0));
  end

  // sync token_kind { ... } (grammar context -- error recovery)
  else if LKind = 'meta.sync' then
  begin
    if Assigned(FActiveParser) and Assigned(FErrors) and
       (FErrors.ErrorCount() > FRuleErrorSnapshot) then
    begin
      LGenParser := TGenericParser(FActiveParser);
      LTokenKind := ANode.GetAttr('token_kind');
      // Skip tokens until we find the sync point
      while not LGenParser.AtEnd() do
      begin
        if LGenParser.Check(LTokenKind) then Break;
        LGenParser.DoAdvance();
      end;
      // Consume the sync token itself
      if not LGenParser.AtEnd() then
        LGenParser.DoAdvance();
    end;
    if ANode.ChildCount() > 0 then
      ExecBlock(ANode.GetChild(0));
  end;

  // Unknown node kinds are silently ignored for forward compatibility
end;

{ Triple-Quoted String Indent Trimming }

function TrimCommonIndent(const AText: string): string;
var
  LLines: TArray<string>;
  LMinIndent: Integer;
  LIndent: Integer;
  LI: Integer;
  LJ: Integer;
  LLine: string;
  LFirst: Integer;
  LLast: Integer;
begin
  LLines := AText.Split([#10]);

  // Find first and last non-empty line boundaries
  LFirst := 0;
  LLast := Length(LLines) - 1;

  // Strip leading empty line (newline right after opening ''')
  if (LFirst <= LLast) and (Trim(LLines[LFirst]) = '') then
    Inc(LFirst);

  // Strip trailing whitespace-only line (indent before closing ''')
  if (LLast >= LFirst) and (Trim(LLines[LLast]) = '') then
    Dec(LLast);

  if LFirst > LLast then
  begin
    Result := '';
    Exit;
  end;

  // Find minimum indent across non-empty lines
  LMinIndent := MaxInt;
  for LI := LFirst to LLast do
  begin
    LLine := LLines[LI];
    if Trim(LLine) = '' then
      Continue;
    LIndent := 0;
    for LJ := 1 to Length(LLine) do
    begin
      if (LLine[LJ] = ' ') or (LLine[LJ] = #9) then
        Inc(LIndent)
      else
        Break;
    end;
    if LIndent < LMinIndent then
      LMinIndent := LIndent;
  end;

  if LMinIndent = MaxInt then
    LMinIndent := 0;

  // Strip common indent and rebuild
  Result := '';
  for LI := LFirst to LLast do
  begin
    LLine := LLines[LI];
    if Length(LLine) > LMinIndent then
      LLine := Copy(LLine, LMinIndent + 1, Length(LLine) - LMinIndent)
    else if Trim(LLine) = '' then
      LLine := '';
    if LI > LFirst then
      Result := Result + #10;
    Result := Result + LLine;
  end;
end;

{ Expression Evaluator }

function TMorInterpreter.EvalExpr(const ANode: TASTNode): TValue;
var
  LKind: string;
  LLeft: TValue;
  LRight: TValue;
  LOp: string;
  LName: string;
  LArgs: TArray<TValue>;
  LI: Integer;
  LCallee: TASTNode;
begin
  if ANode = nil then
    Exit(TValue.Empty);

  LKind := ANode.GetKind();

  // Integer literal
  if LKind = 'expr.integer' then
    Result := TValue.From<Int64>(StrToInt64Def(ANode.GetAttr('value'), 0))

  // Float literal
  else if LKind = 'expr.float' then
    Result := TValue.From<Double>(StrToFloatDef(ANode.GetAttr('value'), 0.0))

  // String literal (with interpolation)
  else if LKind = 'expr.string' then
    Result := TValue.From<string>(Interpolate(ANode.GetAttr('value')))

  // Triple-quoted string (no interpolation, common indent trimmed)
  else if LKind = 'expr.triplestring' then
    Result := TValue.From<string>(TrimCommonIndent(ANode.GetAttr('value')))

  // Boolean
  else if LKind = 'expr.bool' then
    Result := TValue.From<Boolean>(ANode.GetAttr('value') = 'true')

  // Nil
  else if LKind = 'expr.nil' then
    Result := TValue.Empty

  // Identifier (variable lookup)
  else if LKind = 'expr.ident' then
  begin
    LName := ANode.GetAttr('identifier');
    // Check constants first
    if FConstants.ContainsKey(LName) then
      Result := FConstants[LName]
    else if FEnv.HasVar(LName) then
      Result := FEnv.GetVar(LName)
    else
    begin
      if Assigned(FErrors) then
        FErrors.Add(esError, ERR_MORINTERP_UNDEFINED_VAR,
          RSMorInterpUndefinedVar, [LName]);
      Result := TValue.Empty;
    end;
  end

  // @ attribute access
  else if LKind = 'expr.attr' then
  begin
    if FCurrentNode <> nil then
      Result := TValue.From<string>(
        FCurrentNode.GetAttr(ANode.GetAttr('attr_name')))
    else
      Result := TValue.From<string>('');
  end

  // Binary operator
  else if LKind = 'expr.binary' then
  begin
    LOp := ANode.GetAttr('op');
    LLeft := EvalExpr(ANode.GetChild(0));
    // Short-circuit for and/or
    if LOp = 'and' then
    begin
      if not MorIsTrue(LLeft) then
        Exit(TValue.From<Boolean>(False));
      LRight := EvalExpr(ANode.GetChild(1));
      Result := TValue.From<Boolean>(MorIsTrue(LRight));
    end
    else if LOp = 'or' then
    begin
      if MorIsTrue(LLeft) then
        Exit(TValue.From<Boolean>(True));
      LRight := EvalExpr(ANode.GetChild(1));
      Result := TValue.From<Boolean>(MorIsTrue(LRight));
    end
    else
    begin
      LRight := EvalExpr(ANode.GetChild(1));
      Result := ApplyBinaryOp(LOp, LLeft, LRight);
    end;
  end

  // Unary not
  else if LKind = 'expr.unary_not' then
    Result := TValue.From<Boolean>(not MorIsTrue(EvalExpr(ANode.GetChild(0))))

  // Unary negate
  else if LKind = 'expr.negate' then
  begin
    LLeft := EvalExpr(ANode.GetChild(0));
    if (LLeft.Kind = tkInt64) then
      Result := TValue.From<Int64>(-LLeft.AsInt64())
    else if (LLeft.Kind = tkFloat) then
      Result := TValue.From<Double>(-LLeft.AsExtended())
    else
      Result := TValue.From<Int64>(0);
  end

  // Grouped expression
  else if LKind = 'expr.grouped' then
    Result := EvalExpr(ANode.GetChild(0))

  // Function call
  else if LKind = 'expr.call' then
  begin
    LCallee := ANode.GetChild(0);
    // Build args array
    SetLength(LArgs, ANode.ChildCount() - 1);
    for LI := 1 to ANode.ChildCount() - 1 do
      LArgs[LI - 1] := EvalExpr(ANode.GetChild(LI));

    // Determine function name
    if LCallee.GetKind() = 'expr.ident' then
    begin
      LName := LCallee.GetAttr('identifier');
      // Try user routine first, then built-in
      if FRoutines.ContainsKey(LName) then
        Result := CallRoutine(LName, LArgs)
      else
      begin
        try
          Result := CallBuiltin(LName, LArgs);
        except
          on E: Exception do
          begin
            ReportNodeError(FErrors, FCurrentNode, ERR_MORINTERP_BUILTIN_CRASH,
              RSMorInterpBuiltinCrash, [LName, FCurrentNode.GetKind(),
              E.Message]);
            Result := TValue.Empty;
          end;
        end;
      end;
    end
    else
      Result := TValue.Empty;
  end

  // Member access (expr.member)
  else if LKind = 'expr.member' then
  begin
    // For now evaluate the object expression and return empty
    // Full member access wired when needed
    EvalExpr(ANode.GetChild(0));
    Result := TValue.Empty;
  end

  // Index access (expr.index)
  else if LKind = 'expr.index' then
  begin
    EvalExpr(ANode.GetChild(0));
    EvalExpr(ANode.GetChild(1));
    Result := TValue.Empty;
  end

  // Error node
  else if LKind = 'expr.error' then
    Result := TValue.Empty

  else
    Result := TValue.Empty;
end;

{ Binary Operator }

function TMorInterpreter.ApplyBinaryOp(const AOp: string;
  const ALeft: TValue; const ARight: TValue): TValue;
var
  LLeftStr: string;
  LRightStr: string;
  LLeftInt: Int64;
  LRightInt: Int64;
  LLeftFloat: Double;
  LRightFloat: Double;
begin
  // String concatenation: if + and either is string
  if (AOp = '+') and
     (ALeft.IsType<string>() or ARight.IsType<string>()) then
  begin
    LLeftStr := MorToString(ALeft);
    LRightStr := MorToString(ARight);
    Exit(TValue.From<string>(LLeftStr + LRightStr));
  end;

  // Float arithmetic if either is float
  if (ALeft.Kind = tkFloat) or (ARight.Kind = tkFloat) then
  begin
    if (ALeft.Kind = tkFloat) then LLeftFloat := ALeft.AsExtended()
    else if (ALeft.Kind = tkInt64) then LLeftFloat := ALeft.AsInt64()
    else LLeftFloat := 0;

    if (ARight.Kind = tkFloat) then LRightFloat := ARight.AsExtended()
    else if (ARight.Kind = tkInt64) then LRightFloat := ARight.AsInt64()
    else LRightFloat := 0;

    if AOp = '+' then Exit(TValue.From<Double>(LLeftFloat + LRightFloat))
    else if AOp = '-' then Exit(TValue.From<Double>(LLeftFloat - LRightFloat))
    else if AOp = '*' then Exit(TValue.From<Double>(LLeftFloat * LRightFloat))
    else if AOp = '/' then
    begin
      if LRightFloat = 0 then Exit(TValue.From<Double>(0));
      Exit(TValue.From<Double>(LLeftFloat / LRightFloat));
    end
    else if AOp = '==' then Exit(TValue.From<Boolean>(LLeftFloat = LRightFloat))
    else if AOp = '!=' then Exit(TValue.From<Boolean>(LLeftFloat <> LRightFloat))
    else if AOp = '<' then Exit(TValue.From<Boolean>(LLeftFloat < LRightFloat))
    else if AOp = '>' then Exit(TValue.From<Boolean>(LLeftFloat > LRightFloat))
    else if AOp = '<=' then Exit(TValue.From<Boolean>(LLeftFloat <= LRightFloat))
    else if AOp = '>=' then Exit(TValue.From<Boolean>(LLeftFloat >= LRightFloat));
  end;

  // Integer arithmetic
  if (ALeft.Kind = tkInt64) then LLeftInt := ALeft.AsInt64()
  else if (ALeft.Kind = tkInteger) then LLeftInt := ALeft.AsInteger()
  else LLeftInt := 0;

  if (ARight.Kind = tkInt64) then LRightInt := ARight.AsInt64()
  else if (ARight.Kind = tkInteger) then LRightInt := ARight.AsInteger()
  else LRightInt := 0;

  if AOp = '+' then Result := TValue.From<Int64>(LLeftInt + LRightInt)
  else if AOp = '-' then Result := TValue.From<Int64>(LLeftInt - LRightInt)
  else if AOp = '*' then Result := TValue.From<Int64>(LLeftInt * LRightInt)
  else if AOp = '/' then
  begin
    if LRightInt = 0 then Exit(TValue.From<Int64>(0));
    Result := TValue.From<Int64>(LLeftInt div LRightInt);
  end
  else if AOp = '%' then
  begin
    if LRightInt = 0 then Exit(TValue.From<Int64>(0));
    Result := TValue.From<Int64>(LLeftInt mod LRightInt);
  end
  // Comparisons (works for int and string via string fallback)
  else if AOp = '==' then
    Result := TValue.From<Boolean>(MorToString(ALeft) = MorToString(ARight))
  else if AOp = '!=' then
    Result := TValue.From<Boolean>(MorToString(ALeft) <> MorToString(ARight))
  else if AOp = '<' then
    Result := TValue.From<Boolean>(LLeftInt < LRightInt)
  else if AOp = '>' then
    Result := TValue.From<Boolean>(LLeftInt > LRightInt)
  else if AOp = '<=' then
    Result := TValue.From<Boolean>(LLeftInt <= LRightInt)
  else if AOp = '>=' then
    Result := TValue.From<Boolean>(LLeftInt >= LRightInt)
  else
    Result := TValue.Empty;
end;

{ String Interpolation }

function TMorInterpreter.Interpolate(const ARawText: string): string;
var
  LI: Integer;
  LLen: Integer;
  LCh: Char;
  LExprText: string;
  LDepth: Integer;
  LTempLexer: TMorLexer;
  LTempParser: TMorParser;
  LTempTokens: TList<TToken>;
  LTempExpr: TASTNode;
begin
  Result := '';
  LI := 1;
  LLen := Length(ARawText);

  while LI <= LLen do
  begin
    LCh := ARawText[LI];

    // Check for escaped interpolation
    if (LCh = '\') and (LI + 1 <= LLen) and (ARawText[LI + 1] = '{') then
    begin
      Result := Result + '{';
      Inc(LI, 2);
      Continue;
    end;

    // Check for interpolation start
    if (LCh = '{') and (LI + 1 <= LLen) then
    begin
      Inc(LI); // skip {

      // Check for @attr access
      if (LI <= LLen) and (ARawText[LI] = '@') then
      begin
        Inc(LI); // skip @
        LExprText := '';
        while (LI <= LLen) and (ARawText[LI] <> '}') do
        begin
          LExprText := LExprText + ARawText[LI];
          Inc(LI);
        end;
        if (LI <= LLen) then Inc(LI); // skip }
        // Resolve attribute from current node
        if FCurrentNode <> nil then
          Result := Result + FCurrentNode.GetAttr(LExprText)
        else
          Result := Result + '';
      end
      else
      begin
        // Expression interpolation: collect until matching }
        LExprText := '';
        LDepth := 1;
        while (LI <= LLen) and (LDepth > 0) do
        begin
          if ARawText[LI] = '{' then Inc(LDepth)
          else if ARawText[LI] = '}' then
          begin
            Dec(LDepth);
            if LDepth = 0 then
            begin
              Inc(LI); // skip closing }
              Break;
            end;
          end;
          if LDepth > 0 then
            LExprText := LExprText + ARawText[LI];
          Inc(LI);
        end;
        // Full expression interpolation: lex, parse, evaluate
        try
          LTempLexer := TMorLexer.Create();
          try
            LTempParser := TMorParser.Create();
            try
              LTempTokens := LTempLexer.Tokenize(LExprText);
              try
                LTempExpr := LTempParser.ParseSingleExpr(LTempTokens);
                if LTempExpr <> nil then
                  Result := Result + MorToString(EvalExpr(LTempExpr))
                else
                  Result := Result + '{' + LExprText + '}';
              finally
                LTempTokens.Free();
              end;
            finally
              LTempParser.Free();
            end;
          finally
            LTempLexer.Free();
          end;
        except
          // Fallback: variable/constant lookup on parse failure
          if FEnv.HasVar(LExprText) then
            Result := Result + MorToString(FEnv.GetVar(LExprText))
          else if FConstants.ContainsKey(LExprText) then
            Result := Result + MorToString(FConstants[LExprText])
          else
            Result := Result + '{' + LExprText + '}';
        end;      end;
      Continue;
    end;

    // Regular character
    Result := Result + LCh;
    Inc(LI);
  end;
end;

{ Built-in Functions }

function TMorInterpreter.CallBuiltin(const AName: string;
  const AArgs: TArray<TValue>): TValue;
var
  LNode: TASTNode;
  LS: string;
  LIdx: Int64;
  LGenParser: TGenericParser;
  LTargetStr: string;
  LTokenKind: string;
  LDepth: Int64;
  LRawAccum: string;
begin
  // Common functions

  // nodeKind(node) -> string / nodeKind() -> string
  if AName = 'nodeKind' then
  begin
    if (Length(AArgs) > 0) and AArgs[0].IsObject() then
      Result := TValue.From<string>(TASTNode(AArgs[0].AsObject()).GetKind())
    else if FCurrentNode <> nil then
      Result := TValue.From<string>(FCurrentNode.GetKind())
    else
      Result := TValue.From<string>('');
  end

  // getAttr(key) / getAttr(node, key) -> string
  else if AName = 'getAttr' then
  begin
    if (Length(AArgs) = 2) and AArgs[0].IsObject() then
      Result := TValue.From<string>(
        TASTNode(AArgs[0].AsObject()).GetAttr(AArgs[1].AsString()))
    else if (Length(AArgs) = 1) and (FCurrentNode <> nil) then
      Result := TValue.From<string>(FCurrentNode.GetAttr(AArgs[0].AsString()))
    else
      Result := TValue.From<string>('');
  end

  // setAttr(key, value) / setAttr(node, key, value)
  else if AName = 'setAttr' then
  begin
    if (Length(AArgs) = 3) and AArgs[0].IsObject() then
      TASTNode(AArgs[0].AsObject()).SetAttr(
        AArgs[1].AsString(), MorToString(AArgs[2]))
    else if (Length(AArgs) = 2) and (FCurrentNode <> nil) then
      FCurrentNode.SetAttr(AArgs[0].AsString(), MorToString(AArgs[1]));
    Result := TValue.Empty;
  end

  // has_attr(name) -> bool
  else if AName = 'has_attr' then
  begin
    if (Length(AArgs) = 1) and (FCurrentNode <> nil) then
      Result := TValue.From<Boolean>(FCurrentNode.HasAttr(AArgs[0].AsString()))
    else
      Result := TValue.From<Boolean>(False);
  end

  // childCount(node) / child_count() / child_count(node)
  else if (AName = 'childCount') or (AName = 'child_count') then
  begin
    if (Length(AArgs) > 0) and AArgs[0].IsObject() then
      Result := TValue.From<Int64>(TASTNode(AArgs[0].AsObject()).ChildCount())
    else if FCurrentNode <> nil then
      Result := TValue.From<Int64>(FCurrentNode.ChildCount())
    else
      Result := TValue.From<Int64>(0);
  end

  // getChild(node, index) / getChild(index) -> node
  else if AName = 'getChild' then
  begin
    if (Length(AArgs) = 2) and AArgs[0].IsObject() then
    begin
      LNode := TASTNode(AArgs[0].AsObject());
      if (AArgs[1].Kind = tkInt64) then
        LIdx := AArgs[1].AsInt64()
      else if (AArgs[1].Kind = tkInteger) then
        LIdx := AArgs[1].AsInteger()
      else
      begin
        ReportNodeError(FErrors, FCurrentNode, ERR_MORINTERP_BAD_INDEX_TYPE,
          RSMorInterpBadIndexType, [AArgs[1].TypeInfo.Name,
          MorToString(AArgs[1]), FCurrentNode.GetKind()]);
        Result := TValue.Empty;
        Exit;
      end;
      if (LIdx >= 0) and (LIdx < LNode.ChildCount()) then
        Result := TValue.From<TASTNode>(LNode.GetChild(LIdx))
      else
        Result := TValue.Empty;
    end
    else if (Length(AArgs) = 1) and (FCurrentNode <> nil) then
    begin
      if (AArgs[0].Kind = tkInt64) then
        LIdx := AArgs[0].AsInt64()
      else if (AArgs[0].Kind = tkInteger) then
        LIdx := AArgs[0].AsInteger()
      else
      begin
        ReportNodeError(FErrors, FCurrentNode, ERR_MORINTERP_BAD_INDEX_TYPE,
          RSMorInterpBadIndexType, [AArgs[0].TypeInfo.Name,
          MorToString(AArgs[0]), FCurrentNode.GetKind()]);
        Result := TValue.Empty;
        Exit;
      end;
      if (LIdx >= 0) and (LIdx < FCurrentNode.ChildCount()) then
        Result := TValue.From<TASTNode>(FCurrentNode.GetChild(LIdx))
      else
        Result := TValue.Empty;
    end
    else
      Result := TValue.Empty;
  end

  // createNode(kind) -> node
  else if AName = 'createNode' then
  begin
    if Length(AArgs) > 0 then
    begin
      LNode := TASTNode.Create();
      LNode.SetKind(AArgs[0].AsString());
      Result := TValue.From<TASTNode>(LNode);
    end
    else
      Result := TValue.Empty;
  end

  // addChild(parent, child)
  else if AName = 'addChild' then
  begin
    if (Length(AArgs) = 2) and AArgs[0].IsObject() and AArgs[1].IsObject() then
      TASTNode(AArgs[0].AsObject()).AddChild(TASTNode(AArgs[1].AsObject()));
    Result := TValue.Empty;
  end

  // getResultNode() -> node
  else if AName = 'getResultNode' then
    Result := TValue.From<TASTNode>(FResultNode)

  // concat(a, b, ...) -> string
  else if AName = 'concat' then
  begin
    LS := '';
    for LIdx := 0 to Length(AArgs) - 1 do
      LS := LS + MorToString(AArgs[LIdx]);
    Result := TValue.From<string>(LS);
  end

  // upper(s) -> string
  else if AName = 'upper' then
  begin
    if Length(AArgs) > 0 then
      Result := TValue.From<string>(UpperCase(MorToString(AArgs[0])))
    else
      Result := TValue.From<string>('');
  end

  // lower(s) -> string
  else if AName = 'lower' then
  begin
    if Length(AArgs) > 0 then
      Result := TValue.From<string>(LowerCase(MorToString(AArgs[0])))
    else
      Result := TValue.From<string>('');
  end

  // trim(s) -> string
  else if AName = 'trim' then
  begin
    if Length(AArgs) > 0 then
      Result := TValue.From<string>(Trim(MorToString(AArgs[0])))
    else
      Result := TValue.From<string>('');
  end

  // replace(s, find, repl) -> string
  else if AName = 'replace' then
  begin
    if Length(AArgs) >= 3 then
      Result := TValue.From<string>(
        StringReplace(MorToString(AArgs[0]),
          MorToString(AArgs[1]), MorToString(AArgs[2]),
          [rfReplaceAll]))
    else
      Result := TValue.From<string>('');
  end

  // len(s) -> int
  else if AName = 'len' then
  begin
    if Length(AArgs) > 0 then
      Result := TValue.From<Int64>(Length(MorToString(AArgs[0])))
    else
      Result := TValue.From<Int64>(0);
  end

  // substr(s, start, len) -> string
  else if AName = 'substr' then
  begin
    if Length(AArgs) >= 3 then
      Result := TValue.From<string>(
        Copy(MorToString(AArgs[0]),
          AArgs[1].AsInt64() + 1,
          AArgs[2].AsInt64()))
    else
      Result := TValue.From<string>('');
  end

  // startsWith(s, prefix) -> bool
  else if AName = 'startsWith' then
  begin
    if Length(AArgs) >= 2 then
      Result := TValue.From<Boolean>(
        MorToString(AArgs[0]).StartsWith(MorToString(AArgs[1])))
    else
      Result := TValue.From<Boolean>(False);
  end

  // endsWith(s, suffix) -> bool
  else if AName = 'endsWith' then
  begin
    if Length(AArgs) >= 2 then
      Result := TValue.From<Boolean>(
        MorToString(AArgs[0]).EndsWith(MorToString(AArgs[1])))
    else
      Result := TValue.From<Boolean>(False);
  end

  // contains(s, sub) -> bool
  else if AName = 'contains' then
  begin
    if Length(AArgs) >= 2 then
      Result := TValue.From<Boolean>(
        MorToString(AArgs[0]).Contains(MorToString(AArgs[1])))
    else
      Result := TValue.From<Boolean>(False);
  end

  // intToStr(n) -> string
  else if AName = 'intToStr' then
  begin
    if Length(AArgs) > 0 then
      Result := TValue.From<string>(MorToString(AArgs[0]))
    else
      Result := TValue.From<string>('0');
  end

  // strToInt(s) -> int
  else if AName = 'strToInt' then
  begin
    if Length(AArgs) > 0 then
      Result := TValue.From<Int64>(
        StrToInt64Def(MorToString(AArgs[0]), 0))
    else
      Result := TValue.From<Int64>(0);
  end

  // Diagnostics
  // error(msg)
  else if AName = 'error' then
  begin
    if Assigned(FErrors) and (Length(AArgs) > 0) then
      FErrors.Add(esError, ERR_MORINTERP_UNKNOWN_NODE,
        MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // warning(msg)
  else if AName = 'warning' then
  begin
    if Assigned(FErrors) and (Length(AArgs) > 0) then
      FErrors.Add(esWarning, ERR_MORINTERP_UNKNOWN_NODE,
        MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // hint(msg), note(msg), info(msg)
  else if (AName = 'hint') or (AName = 'note') or (AName = 'info') then
  begin
    if Assigned(FErrors) and (Length(AArgs) > 0) then
      FErrors.Add(esHint, ERR_MORINTERP_UNKNOWN_NODE,
        MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // Parse context (grammar rule bodies)
  // checkToken(kind) -> bool
  else if AName = 'checkToken' then
  begin
    if Assigned(FActiveParser) and (Length(AArgs) > 0) then
      Result := TValue.From<Boolean>(
        TGenericParser(FActiveParser).Check(MorToString(AArgs[0])))
    else
      Result := TValue.From<Boolean>(False);
  end

  // matchToken(kind) -> bool
  else if AName = 'matchToken' then
  begin
    if Assigned(FActiveParser) and (Length(AArgs) > 0) then
      Result := TValue.From<Boolean>(
        TGenericParser(FActiveParser).Match(MorToString(AArgs[0])))
    else
      Result := TValue.From<Boolean>(False);
  end

  // advance() -> string
  else if AName = 'advance' then
  begin
    if Assigned(FActiveParser) then
    begin
      Result := TValue.From<string>(
        TGenericParser(FActiveParser).Current().Text);
      TGenericParser(FActiveParser).DoAdvance();
    end
    else
      Result := TValue.From<string>('');
  end

  // requireToken(kind)
  else if AName = 'requireToken' then
  begin
    if Assigned(FActiveParser) and (Length(AArgs) > 0) then
      TGenericParser(FActiveParser).Expect(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // currentText() -> string
  else if AName = 'currentText' then
  begin
    if Assigned(FActiveParser) then
      Result := TValue.From<string>(
        TGenericParser(FActiveParser).Current().Text)
    else
      Result := TValue.From<string>('');
  end

  // currentKind() -> string
  else if AName = 'currentKind' then
  begin
    if Assigned(FActiveParser) then
      Result := TValue.From<string>(
        TGenericParser(FActiveParser).Current().Kind)
    else
      Result := TValue.From<string>('');
  end

  // peekKind() -> string
  else if AName = 'peekKind' then
  begin
    if Assigned(FActiveParser) then
      Result := TValue.From<string>(
        TGenericParser(FActiveParser).Peek().Kind)
    else
      Result := TValue.From<string>('');
  end

  // parseExpr(power) -> node
  else if AName = 'parseExpr' then
  begin
    if Assigned(FActiveParser) then
    begin
      if Length(AArgs) > 0 then
        Result := TValue.From<TASTNode>(
          TGenericParser(FActiveParser).ParseExpression(AArgs[0].AsInt64()))
      else
        Result := TValue.From<TASTNode>(
          TGenericParser(FActiveParser).ParseExpression(0));
    end
    else
      Result := TValue.Empty;
  end

  // parseStmt() -> node
  else if AName = 'parseStmt' then
  begin
    if Assigned(FActiveParser) then
      Result := TValue.From<TASTNode>(
        TGenericParser(FActiveParser).ParseStatement())
    else
      Result := TValue.Empty;
  end

  // collectUntil(kind) -> string : collect raw tokens until kind at depth 0
  else if AName = 'collectUntil' then
  begin
    if Assigned(FActiveParser) and (Length(AArgs) > 0) then
    begin
      LGenParser := TGenericParser(FActiveParser);
      LTargetStr := MorToString(AArgs[0]);
      LRawAccum := '';
      LDepth := 0;
      while not LGenParser.AtEnd() do
      begin
        LTokenKind := LGenParser.Current().Kind;
        // Track depth
        if (LTokenKind = 'delimiter.lparen') or
           (LTokenKind = 'delimiter.lbracket') or
           (LTokenKind = 'delimiter.lbrace') then
          Inc(LDepth)
        else if (LTokenKind = 'delimiter.rparen') or
                (LTokenKind = 'delimiter.rbracket') or
                (LTokenKind = 'delimiter.rbrace') then
        begin
          if (LTokenKind = LTargetStr) and (LDepth <= 0) then
            Break;
          Dec(LDepth);
        end;
        // Append token text (preserve quotes for strings)
        if LTokenKind.StartsWith('string.') then
          LRawAccum := LRawAccum + '"' + LGenParser.Current().Text + '"'
        else
        begin
          if (LRawAccum <> '') and
             (not LRawAccum.EndsWith('(')) and
             (not LRawAccum.EndsWith(' ')) and
             (LTokenKind <> 'delimiter.comma') and
             (LTokenKind <> 'delimiter.rparen') then
            LRawAccum := LRawAccum + ' ';
          LRawAccum := LRawAccum + LGenParser.Current().Text;
        end;
        if LTokenKind = 'delimiter.comma' then
          LRawAccum := LRawAccum + ' ';
        LGenParser.DoAdvance();
      end;
      Result := TValue.From<string>(LRawAccum);
    end
    else
      Result := TValue.From<string>('');
  end

  // collectRaw() -> string : collect raw tokens until ; or balanced close at depth 0
  else if AName = 'collectRaw' then
  begin
    if Assigned(FActiveParser) then
    begin
      LGenParser := TGenericParser(FActiveParser);
      LRawAccum := '';
      LDepth := 0;
      while not LGenParser.AtEnd() do
      begin
        LTokenKind := LGenParser.Current().Kind;
        LS := LGenParser.Current().Text;

        if LTokenKind = 'eof' then
          Break;

        // Track depth
        if (LTokenKind = 'delimiter.lparen') or
           (LTokenKind = 'delimiter.lbrace') or
           (LTokenKind = 'delimiter.lbracket') then
          Inc(LDepth)
        else if (LTokenKind = 'delimiter.rparen') or
                (LTokenKind = 'delimiter.rbrace') or
                (LTokenKind = 'delimiter.rbracket') then
        begin
          Dec(LDepth);
          if LDepth < 0 then
            Break;
          // Balanced close: include token and stop
          if LDepth <= 0 then
          begin
            if LRawAccum <> '' then LRawAccum := LRawAccum + ' ';
            LRawAccum := LRawAccum + LS;
            LGenParser.DoAdvance();
            Break;
          end;
        end;

        // Stop at ; when depth <= 0
        if (LTokenKind = 'delimiter.semicolon') and (LDepth <= 0) then
        begin
          if LRawAccum <> '' then LRawAccum := LRawAccum + ' ';
          LRawAccum := LRawAccum + LS;
          LGenParser.DoAdvance();
          Break;
        end;

        // Accumulate token text
        if LRawAccum <> '' then LRawAccum := LRawAccum + ' ';
        if LTokenKind.StartsWith('string.') then
          LRawAccum := LRawAccum + '"' + LS + '"'
        else
          LRawAccum := LRawAccum + LS;
        LGenParser.DoAdvance();
      end;
      Result := TValue.From<string>(LRawAccum);
    end
    else
      Result := TValue.From<string>('');
  end

  // Emit context (emitter handler bodies)
  // emitLine(text) / emitLine(text, target)
  else if AName = 'emitLine' then
  begin
    if Assigned(FOutput) and (Length(AArgs) > 0) then
    begin
      if (Length(AArgs) >= 2) and (MorToString(AArgs[1]) = 'header') then
        FOutput.EmitLine(MorToString(AArgs[0]), otHeader)
      else
        FOutput.EmitLine(MorToString(AArgs[0]), otSource);
    end;
    Result := TValue.Empty;
  end

  // emitNode(node)
  else if AName = 'emitNode' then
  begin
    if (Length(AArgs) > 0) and AArgs[0].IsObject() then
      RunEmitHandler(TASTNode(AArgs[0].AsObject()));
    Result := TValue.Empty;
  end

  // emitChildren(node)
  else if AName = 'emitChildren' then
  begin
    if (Length(AArgs) > 0) and AArgs[0].IsObject() then
    begin
      LNode := TASTNode(AArgs[0].AsObject());
      for LIdx := 0 to LNode.ChildCount() - 1 do
      begin
        if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
        RunEmitHandler(LNode.GetChild(LIdx));
      end;
    end;
    Result := TValue.Empty;
  end

  // exprToString(node) -> string
  else if AName = 'exprToString' then
  begin
    if Assigned(FOutput) and (Length(AArgs) > 0) and AArgs[0].IsObject() then
    begin
      FOutput.BeginCapture();
      try
        RunEmitHandler(TASTNode(AArgs[0].AsObject()));
        Result := TValue.From<string>(FOutput.EndCapture());
      except
        FOutput.EndCapture();
        raise;
      end;
    end
    else
      Result := TValue.From<string>('');
  end

  // blankLine()
  else if AName = 'blankLine' then
  begin
    if Assigned(FOutput) then
      FOutput.BlankLine();
    Result := TValue.Empty;
  end

  // indentIn()
  else if AName = 'indentIn' then
  begin
    if Assigned(FOutput) then
      FOutput.IndentIn();
    Result := TValue.Empty;
  end

  // indentOut()
  else if AName = 'indentOut' then
  begin
    if Assigned(FOutput) then
      FOutput.IndentOut();
    Result := TValue.Empty;
  end

  // include(path)
  else if AName = 'include' then
  begin
    if Assigned(FOutput) and (Length(AArgs) > 0) then
      FOutput.IncludeHeader(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // IR builder (emit context)
  // func(name, returnType)
  else if AName = 'func' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 2) then
      FOutput.Func(MorToString(AArgs[0]), MorToString(AArgs[1]));
    Result := TValue.Empty;
  end

  // param(name, type)
  else if AName = 'param' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 2) then
      FOutput.Param(MorToString(AArgs[0]), MorToString(AArgs[1]));
    Result := TValue.Empty;
  end

  // endFunc()
  else if AName = 'endFunc' then
  begin
    if Assigned(FOutput) then
      FOutput.EndFunc();
    Result := TValue.Empty;
  end

  // declVar(name, type) / declVar(name, type, init)
  else if AName = 'declVar' then
  begin
    if Assigned(FOutput) then
    begin
      if Length(AArgs) >= 3 then
        FOutput.DeclVar(MorToString(AArgs[0]),
          MorToString(AArgs[1]), MorToString(AArgs[2]))
      else if Length(AArgs) >= 2 then
        FOutput.DeclVar(MorToString(AArgs[0]), MorToString(AArgs[1]));
    end;
    Result := TValue.Empty;
  end

  // assign(lhs, rhs)
  else if AName = 'assign' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 2) then
      FOutput.Assign(MorToString(AArgs[0]), MorToString(AArgs[1]));
    Result := TValue.Empty;
  end

  // ifStmt(cond)
  else if AName = 'ifStmt' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 1) then
      FOutput.IfStmt(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // elseStmt()
  else if AName = 'elseStmt' then
  begin
    if Assigned(FOutput) then
      FOutput.ElseStmt();
    Result := TValue.Empty;
  end

  // endIf()
  else if AName = 'endIf' then
  begin
    if Assigned(FOutput) then
      FOutput.EndIf();
    Result := TValue.Empty;
  end

  // whileStmt(cond)
  else if AName = 'whileStmt' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 1) then
      FOutput.WhileStmt(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // endWhile()
  else if AName = 'endWhile' then
  begin
    if Assigned(FOutput) then
      FOutput.EndWhile();
    Result := TValue.Empty;
  end

  // forStmt(init, cond, step)
  else if AName = 'forStmt' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 4) then
      FOutput.ForStmt(MorToString(AArgs[0]),
        MorToString(AArgs[1]), MorToString(AArgs[2]),
        MorToString(AArgs[3]));
    Result := TValue.Empty;
  end

  // endFor()
  else if AName = 'endFor' then
  begin
    if Assigned(FOutput) then
      FOutput.EndFor();
    Result := TValue.Empty;
  end

  // elseIfStmt(cond)
  else if AName = 'elseIfStmt' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 1) then
      FOutput.ElseIfStmt(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // breakStmt()
  else if AName = 'breakStmt' then
  begin
    if Assigned(FOutput) then
      FOutput.BreakStmt();
    Result := TValue.Empty;
  end

  // continueStmt()
  else if AName = 'continueStmt' then
  begin
    if Assigned(FOutput) then
      FOutput.ContinueStmt();
    Result := TValue.Empty;
  end

  // returnVoid()
  else if AName = 'returnVoid' then
  begin
    if Assigned(FOutput) then
      FOutput.ReturnStmt();
    Result := TValue.Empty;
  end

  // returnVal(expr)
  else if AName = 'returnVal' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 1) then
      FOutput.ReturnStmt(MorToString(AArgs[0]))
    else if Assigned(FOutput) then
      FOutput.ReturnStmt();
    Result := TValue.Empty;
  end

  // stmt(text)
  else if AName = 'stmt' then
  begin
    if Assigned(FOutput) and (Length(AArgs) >= 1) then
      FOutput.Stmt(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  // Semantic context
  // symbolExistsWithPrefix(prefix) -> bool
  else if AName = 'symbolExistsWithPrefix' then
  begin
    if Assigned(FScopes) and (Length(AArgs) > 0) then
      Result := TValue.From<Boolean>(
        FScopes.SymbolExistsWithPrefix(MorToString(AArgs[0])))
    else
      Result := TValue.From<Boolean>(False);
  end

  // demoteCLinkageForPrefix(prefix) -> int
  else if AName = 'demoteCLinkageForPrefix' then
  begin
    if Assigned(FScopes) and (Length(AArgs) > 0) then
      Result := TValue.From<Int64>(
        FScopes.DemoteCLinkageForPrefix(MorToString(AArgs[0])))
    else
      Result := TValue.From<Int64>(0);
  end

  // compileModule(name) -> bool
  else if AName = 'compileModule' then
  begin
    if (Length(AArgs) > 0) and Assigned(FCompileModuleFunc) then
      Result := TValue.From<Boolean>(FCompileModuleFunc(MorToString(AArgs[0])))
    else
      Result := TValue.From<Boolean>(False);
  end

  // setModuleExtension(ext)
  else if AName = 'setModuleExtension' then
  begin
    if Length(AArgs) > 0 then
      FModuleExtension := MorToString(AArgs[0]);
    Result := TValue.Empty;
  end

  // Compiler control
  // setBuildMode(mode)
  else if AName = 'setBuildMode' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
    begin
      LS := LowerCase(MorToString(AArgs[0]));
      if LS = 'exe' then
        TBuild(FBuild).SetBuildMode(bmExe)
      else if LS = 'lib' then
        TBuild(FBuild).SetBuildMode(bmLib)
      else if LS = 'dll' then
        TBuild(FBuild).SetBuildMode(bmDll);
    end;
    Result := TValue.Empty;
  end

  // setPlatform(platform)
  else if AName = 'setPlatform' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
    begin
      LS := LowerCase(MorToString(AArgs[0]));
      if LS = 'win64' then
        TBuild(FBuild).SetTarget(tpWin64)
      else if LS = 'linux64' then
        TBuild(FBuild).SetTarget(tpLinux64);
    end;
    Result := TValue.Empty;
  end

  // setOptimize(level)
  else if AName = 'setOptimize' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
    begin
      LS := LowerCase(MorToString(AArgs[0]));
      if LS = 'debug' then
        TBuild(FBuild).SetOptimizeLevel(olDebug)
      else if LS = 'releasesafe' then
        TBuild(FBuild).SetOptimizeLevel(olReleaseSafe)
      else if (LS = 'release') or (LS = 'releasefast') then
        TBuild(FBuild).SetOptimizeLevel(olReleaseFast)
      else if LS = 'releasesmall' then
        TBuild(FBuild).SetOptimizeLevel(olReleaseSmall);
    end;
    Result := TValue.Empty;
  end

  // setSubsystem(sub)
  else if AName = 'setSubsystem' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
    begin
      LS := LowerCase(MorToString(AArgs[0]));
      if LS = 'console' then
        TBuild(FBuild).SetSubsystem(stConsole)
      else if LS = 'gui' then
        TBuild(FBuild).SetSubsystem(stGUI);
    end;
    Result := TValue.Empty;
  end

  // Type system builtins
  else if AName = 'typeTextToKind' then
  begin
    if not FTypeKeywords.TryGetValue(MorToString(AArgs[0]), LS) then
      LS := '';
    Result := TValue.From<string>(LS);
  end

  else if AName = 'typeToIR' then
  begin
    if not FTypeMappings.TryGetValue(MorToString(AArgs[0]), LS) then
      LS := '';
    Result := TValue.From<string>(LS);
  end

  // Version info builtins
  else if AName = 'setAddVerInfo' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetAddVersionInfo(MorIsTrue(AArgs[0]));
    Result := TValue.Empty;
  end

  else if AName = 'setExeIcon' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetExeIcon(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  else if AName = 'setVersionMajor' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVIMajor(Word(StrToIntDef(MorToString(AArgs[0]), 0)));
    Result := TValue.Empty;
  end

  else if AName = 'setVersionMinor' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVIMinor(Word(StrToIntDef(MorToString(AArgs[0]), 0)));
    Result := TValue.Empty;
  end

  else if AName = 'setVersionPatch' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVIPatch(Word(StrToIntDef(MorToString(AArgs[0]), 0)));
    Result := TValue.Empty;
  end

  else if AName = 'setProductName' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVIProductName(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  else if AName = 'setFileDescription' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVIDescription(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  else if AName = 'setVIFilename' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVIFilename(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  else if AName = 'setCompanyName' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVICompanyName(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  else if AName = 'setLegalCopyright' then
  begin
    if Assigned(FBuild) and (Length(AArgs) > 0) then
      TBuild(FBuild).SetVICopyright(MorToString(AArgs[0]));
    Result := TValue.Empty;
  end

  else
  begin
    // Unknown built-in
    if Assigned(FErrors) then
    begin
      if Assigned(FCurrentNode) then
        ReportNodeError(FErrors, FCurrentNode, ERR_MORINTERP_UNKNOWN_BUILTIN,
          RSMorInterpUnknownBuiltin, [AName])
      else
        FErrors.Add(esError, ERR_MORINTERP_UNKNOWN_BUILTIN,
          RSMorInterpUnknownBuiltin, [AName]);
    end;
    Result := TValue.Empty;
  end;
end;

{ User Routine Calls }

function TMorInterpreter.CallRoutine(const AName: string;
  const AArgs: TArray<TValue>): TValue;
var
  LRoutineAST: TASTNode;
  LParamCount: Integer;
  LI: Integer;
  LParamName: string;
begin
  Result := TValue.Empty;

  if not FRoutines.TryGetValue(AName, LRoutineAST) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_MORINTERP_UNDEFINED_ROUTINE,
        RSMorInterpUndefinedRoutine, [AName]);
    Exit;
  end;

  LParamCount := StrToIntDef(LRoutineAST.GetAttr('param_count'), 0);

  // Push scope
  FEnv.Push();
  try
    // Bind parameters
    for LI := 0 to LParamCount - 1 do
    begin
      LParamName := LRoutineAST.GetAttr('param_' + IntToStr(LI) + '_name');
      if (LI < Length(AArgs)) then
        FEnv.SetVar(LParamName, AArgs[LI])
      else
        FEnv.SetVar(LParamName, TValue.Empty);
    end;

    // Execute body (child 0 of routine AST)
    try
      if LRoutineAST.ChildCount() > 0 then
        ExecBlock(LRoutineAST.GetChild(0));
    except
      on E: EReturnSignal do
        Result := E.ReturnValue;
    end;
  finally
    FEnv.Pop();
  end;
end;

{ Public Accessors }

function TMorInterpreter.GetKeywords(): TDictionary<string, string>;
begin
  Result := FKeywords;
end;

function TMorInterpreter.GetOperators(): TList<TOperatorEntryInterp>;
begin
  Result := FOperators;
end;

function TMorInterpreter.GetStringStyles(): TList<TStringStyleEntry>;
begin
  Result := FStringStyles;
end;

function TMorInterpreter.GetLineComments(): TList<string>;
begin
  Result := FLineComments;
end;

function TMorInterpreter.GetBlockComments(): TList<TPair<string, string>>;
begin
  Result := FBlockComments;
end;

function TMorInterpreter.GetLexerConfig(): TLexerConfig;
begin
  Result := FLexerConfig;
end;

function TMorInterpreter.GetDirectives(): TDictionary<string, string>;
begin
  Result := FDirectives;
end;

function TMorInterpreter.GetPrefixRules(): TDictionary<string, TASTNode>;
begin
  Result := FPrefixRules;
end;

function TMorInterpreter.GetInfixRules(): TDictionary<string, TInfixEntry>;
begin
  Result := FInfixRules;
end;

function TMorInterpreter.GetStmtRules(): TDictionary<string, TASTNode>;
begin
  Result := FStmtRules;
end;

function TMorInterpreter.GetSemanticHandlers(): TDictionary<string, TASTNode>;
begin
  Result := FSemanticHandlers;
end;

function TMorInterpreter.GetEmitHandlers(): TDictionary<string, TASTNode>;
begin
  Result := FEmitHandlers;
end;

function TMorInterpreter.GetRoutines(): TDictionary<string, TASTNode>;
begin
  Result := FRoutines;
end;

function TMorInterpreter.GetConstants(): TDictionary<string, TValue>;
begin
  Result := FConstants;
end;

function TMorInterpreter.GetEnvironment(): TEnvironment;
begin
  Result := FEnv;
end;

{ Subcomponent Setters }

procedure TMorInterpreter.SetBuild(const ABuild: TObject);
begin
  FBuild := ABuild;
end;

procedure TMorInterpreter.SetScopes(const AScopes: TScopeManager);
begin
  FScopes := AScopes;
end;

procedure TMorInterpreter.SetOutput(const AOutput: TCodeOutput);
begin
  FOutput := AOutput;
  if Assigned(FOutput) then
    FOutput.SetEmitNodeCallback(RunEmitHandler);
end;

procedure TMorInterpreter.SetActiveParser(const AParser: TObject);
begin
  FActiveParser := AParser;
end;

function TMorInterpreter.GetOutput(): TCodeOutput;
begin
  Result := FOutput;
end;

function TMorInterpreter.GetActiveParser(): TObject;
begin
  Result := FActiveParser;
end;

procedure TMorInterpreter.SetCompileModuleFunc(const AFunc: TCompileModuleFunc);
begin
  FCompileModuleFunc := AFunc;
end;

procedure TMorInterpreter.SetImportMorFunc(const AFunc: TImportMorFunc);
begin
  FImportMorFunc := AFunc;
end;

function TMorInterpreter.GetModuleExtension(): string;
begin
  Result := FModuleExtension;
end;

{ Native Handler Registration }

procedure TMorInterpreter.RegisterNativePrefix(const AKind: string;
  const AHandler: TNativePrefixHandler);
begin
  FNativePrefixRules.AddOrSetValue(AKind, AHandler);
end;

procedure TMorInterpreter.RegisterNativeInfix(const AKind: string;
  const AEntry: TNativeInfixEntry);
begin
  FNativeInfixRules.AddOrSetValue(AKind, AEntry);
end;

procedure TMorInterpreter.RegisterNativeStmt(const AKind: string;
  const AHandler: TNativeStmtHandler);
begin
  FNativeStmtRules.AddOrSetValue(AKind, AHandler);
end;

procedure TMorInterpreter.RegisterNativeEmit(const AKind: string;
  const AHandler: TNativeEmitHandler);
begin
  FNativeEmitHandlers.AddOrSetValue(AKind, AHandler);
end;

{ Parser Thin Wrappers }

function TMorInterpreter.ParserCurrentKind(): string;
begin
  if Assigned(FActiveParser) then
    Result := TGenericParser(FActiveParser).Current().Kind
  else
    Result := '';
end;

function TMorInterpreter.ParserCurrentText(): string;
begin
  if Assigned(FActiveParser) then
    Result := TGenericParser(FActiveParser).Current().Text
  else
    Result := '';
end;

procedure TMorInterpreter.ParserAdvance();
begin
  if Assigned(FActiveParser) then
    TGenericParser(FActiveParser).DoAdvance();
end;

function TMorInterpreter.ParserAtEnd(): Boolean;
begin
  if Assigned(FActiveParser) then
    Result := TGenericParser(FActiveParser).AtEnd()
  else
    Result := True;
end;

function TMorInterpreter.ParserCurrentToken(): TToken;
begin
  if Assigned(FActiveParser) then
    Result := TGenericParser(FActiveParser).Current()
  else
  begin
    Result.Kind := '';
    Result.Text := '';
    Result.Filename := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

{ Grammar Rule Execution }

function TMorInterpreter.ExecuteGrammarRule(const ARuleAST: TASTNode;
  const ALeft: TASTNode): TASTNode;
var
  LNodeKind: string;
  LSavedResultNode: TASTNode;
  LSavedSnapshot: Integer;
  LI: Integer;
begin
  LNodeKind := ARuleAST.GetAttr('node_kind');

  // Create the user AST node this rule will build
  Result := TASTNode.Create();
  Result.SetKind(LNodeKind);
  Result.SetToken(ParserCurrentToken());

  // Save and set context
  LSavedResultNode := FResultNode;
  LSavedSnapshot := FRuleErrorSnapshot;
  FResultNode := Result;
  if Assigned(FErrors) then
    FRuleErrorSnapshot := FErrors.ErrorCount()
  else
    FRuleErrorSnapshot := 0;

  // If this is an infix rule, the left operand is child 0
  if Assigned(ALeft) then
    Result.AddChild(ALeft);

  // Execute the rule body
  FEnv.Push();
  try
    // Execute all statements in the rule body
    // Rule children are individual statements, not wrapped in a block
    for LI := 0 to ARuleAST.ChildCount() - 1 do
    begin
      if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
      ExecStmt(ARuleAST.GetChild(LI));
    end;
  finally
    FEnv.Pop();
    FResultNode := LSavedResultNode;
    FRuleErrorSnapshot := LSavedSnapshot;
  end;
end;

{ Semantic Handler Dispatch }

procedure TMorInterpreter.RunSemanticHandler(const AUserNode: TASTNode);
var
  LHandler: TASTNode;
  LSavedNode: TASTNode;
  LI: Integer;
begin
  if AUserNode = nil then Exit;
  if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Exit;

  // Look up handler by user AST node kind
  if FSemanticHandlers.TryGetValue(AUserNode.GetKind(), LHandler) then
  begin
    LSavedNode := FCurrentNode;
    FCurrentNode := AUserNode;
    FEnv.Push();
    try
      FEnv.SetVar('node', TValue.From<TASTNode>(AUserNode));
      ExecBlock(LHandler);
    finally
      FEnv.Pop();
      FCurrentNode := LSavedNode;
    end;
  end
  else
  begin
    // No handler: auto-visit all children (default behavior)
    for LI := 0 to AUserNode.ChildCount() - 1 do
    begin
      if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
      RunSemanticHandler(AUserNode.GetChild(LI));
    end;
  end;
end;

{ Emit Handler Dispatch }

procedure TMorInterpreter.RunEmitHandler(const AUserNode: TASTNode);
var
  LHandler: TASTNode;
  LNativeHandler: TNativeEmitHandler;
  LSavedNode: TASTNode;
  LI: Integer;
begin
  if AUserNode = nil then Exit;
  if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Exit;

  // Check native emit handlers first (C++ passthrough)
  if FNativeEmitHandlers.TryGetValue(AUserNode.GetKind(), LNativeHandler) then
  begin
    LNativeHandler(AUserNode);
    Exit;
  end;

  // Check interpreted emit handlers
  if FEmitHandlers.TryGetValue(AUserNode.GetKind(), LHandler) then
  begin
    LSavedNode := FCurrentNode;
    FCurrentNode := AUserNode;
    FEnv.Push();
    try
      FEnv.SetVar('node', TValue.From<TASTNode>(AUserNode));
      try
        ExecBlock(LHandler);
      except
        on E: Exception do
          ReportNodeError(FErrors, AUserNode, ERR_MORINTERP_EMITTER_CRASH,
            RSMorInterpEmitterCrash, [AUserNode.GetKind(), E.Message]);
      end;
    finally
      FEnv.Pop();
      FCurrentNode := LSavedNode;
    end;
  end
  else if AUserNode.GetKind() = 'meta.block' then
  begin
    // Transparent block: emit each child
    for LI := 0 to AUserNode.ChildCount() - 1 do
    begin
      if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
      RunEmitHandler(AUserNode.GetChild(LI));
    end;
  end
  else if AUserNode.HasAttr('operator') and (AUserNode.ChildCount() = 2) then
  begin
    // Default binary expression fallback: left op right
    RunEmitHandler(AUserNode.GetChild(0));
    if Assigned(FOutput) then
      FOutput.Emit(' ' + AUserNode.GetAttr('operator') + ' ');
    RunEmitHandler(AUserNode.GetChild(1));
  end;
  // No handler and no default fallback: silently skip
end;

{ Pipeline Entry Points }

procedure TMorInterpreter.RunSemantics(const AMasterRoot: TASTNode);
var
  LI: Integer;
  LPass: TSemanticPass;
  LJ: Integer;
  LSavedHandlers: TDictionary<string, TASTNode>;
begin
  if AMasterRoot = nil then Exit;

  if FSemanticPasses.Count > 0 then
  begin
    // Multi-pass semantic analysis
    LSavedHandlers := FSemanticHandlers;
    try
      for LI := 0 to FSemanticPasses.Count - 1 do
      begin
        LPass := FSemanticPasses[LI];
        // Temporarily swap handler map (do NOT free the original)
        FSemanticHandlers := LPass.Handlers;
        if Assigned(FScopes) then
          FScopes.Reset();
        for LJ := 0 to AMasterRoot.ChildCount() - 1 do
        begin
          if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
          RunSemanticHandler(AMasterRoot.GetChild(LJ));
        end;
        if Assigned(FErrors) and FErrors.HasErrors() then Break;
      end;
    finally
      FSemanticHandlers := LSavedHandlers;
    end;
  end
  else
  begin
    // Single-pass semantic analysis
    for LI := 0 to AMasterRoot.ChildCount() - 1 do
    begin
      if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
      RunSemanticHandler(AMasterRoot.GetChild(LI));
    end;
  end;
end;

procedure TMorInterpreter.RunEmitters(const AMasterRoot: TASTNode);
var
  LI: Integer;
begin
  if AMasterRoot = nil then Exit;

  // Execute before block if present
  if Assigned(FBeforeBlock) then
  begin
    FEnv.Push();
    try
      ExecBlock(FBeforeBlock);
    finally
      FEnv.Pop();
    end;
  end;

  // Emit each branch
  for LI := 0 to AMasterRoot.ChildCount() - 1 do
  begin
    if Assigned(FErrors) and FErrors.ReachedMaxErrors() then Break;
    RunEmitHandler(AMasterRoot.GetChild(LI));
  end;

  // Execute after block if present
  if Assigned(FAfterBlock) then
  begin
    FEnv.Push();
    try
      ExecBlock(FAfterBlock);
    finally
      FEnv.Pop();
    end;
  end;
end;

{ Native Handler Accessors }

function TMorInterpreter.GetNativePrefixRules(): TDictionary<string, TNativePrefixHandler>;
begin
  Result := FNativePrefixRules;
end;

function TMorInterpreter.GetNativeInfixRules(): TDictionary<string, TNativeInfixEntry>;
begin
  Result := FNativeInfixRules;
end;

function TMorInterpreter.GetNativeStmtRules(): TDictionary<string, TNativeStmtHandler>;
begin
  Result := FNativeStmtRules;
end;

function TMorInterpreter.GetNativeEmitHandlers(): TDictionary<string, TNativeEmitHandler>;
begin
  Result := FNativeEmitHandlers;
end;

end.
