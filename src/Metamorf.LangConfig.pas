{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.LangConfig;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Rtti,
  Metamorf.Utils,
  Metamorf.Config,
  Metamorf.Common;

type

  { TInfixEntry }
  TInfixEntry = record
    NodeKind:     string;
    BindingPower: Integer;
    Assoc:        TAssociativity;
    Handler:      TInfixHandler;
  end;

  { TStatementEntry }
  TStatementEntry = record
    NodeKind: string;
    Handler:  TStatementHandler;
  end;

  { TPrefixEntry }
  TPrefixEntry = record
    NodeKind: string;
    Handler:  TPrefixHandler;
  end;

  { TStructuralConfig }
  TStructuralConfig = record
    StatementTerminator: string;
    BlockOpen:           string;
    BlockClose:          string;
  end;

  // Callback for directives processed at lexer level.
  // Returns '' on success, or an error message string.
  TDirectiveCallback = reference to function(const ALexer: TLexerBase): string;

  { TDirectiveEntry }
  TDirectiveEntry = record
    TokenKind: string;            // e.g. 'directive.ifdef'
    Role:      TConditionalRole;  // crNone for non-conditional directives
    Callback:  TDirectiveCallback; // nil = token passes to parser
  end;

  // Name mangling: maps a source identifier to a C++ identifier.
  TNameMangler = reference to function(const AName: string): string;

  // Type-to-IR mapping: maps a type kind string to a C++ type string.
  TTypeToIR    = reference to function(const ATypeKind: string): string;

  { TLangConfig }
  TLangConfig = class(TConfigFileObject)
  private
    // Lexer surface
    FCaseSensitive:    Boolean;
    FIdentStartChars:  TSysCharSet;
    FIdentPartChars:   TSysCharSet;
    FLineComments:     TList<string>;
    FBlockComments:    TList<TBlockCommentDef>;
    FStringStyles:     TList<TStringStyleDef>;
    FOperators:        TList<TOperatorDef>;
    FKeywords:         TDictionary<string, string>;
    FHexPrefixes:      TList<string>;
    FBinaryPrefixes:   TList<string>;
    FHexKind:          string;
    FBinaryKind:       string;
    FIntegerKind:      string;
    FFloatKind:        string;
    FIdentifierKind:   string;
    FEOFKind:          string;
    FUnknownKind:      string;
    FLineCommentKind:  string;
    FBlockCommentKind: string;
    FDirectivePrefix:  string;
    FDirectiveKind:    string;
    FDirectives:       TDictionary<string, TDirectiveEntry>;  // directive name → entry
    FModuleExtension:  string;  // file extension for module resolution

    // Grammar surface
    FStatementHandlers: TDictionary<string, TStatementEntry>;
    FPrefixHandlers:    TDictionary<string, TPrefixEntry>;
    FInfixHandlers:     TDictionary<string, TInfixEntry>;
    FStructural:        TStructuralConfig;

    // Emit surface
    FEmitHandlers: TDictionary<string, TEmitHandler>;

    // Semantic surface
    FSemanticHandlers: TDictionary<string, TSemanticHandler>;
    FTypeCompatFunc:   TTypeCompatFunc;

    // Type inference surface
    FLiteralTypes: TDictionary<string, string>;   // node kind → type kind
    FDeclKinds:    TList<string>;                 // node kinds that declare vars
    FCallKinds:    TList<string>;                 // node kinds that are call sites
    FCallNameAttr: string;                        // attr holding callee name
    FTypeKeywords: TDictionary<string, string>;   // type keyword text → type kind

    // Post-scan results — cleared and repopulated each ScanAll call
    FDeclTypes:    TDictionary<string, string>;           // var name → type kind
    FCallArgTypes: TDictionary<string, TArray<string>>;   // func name → arg types

    // Name mangling and type mapping
    FNameMangler: TNameMangler;
    FTypeToIR:      TTypeToIR;
    FTypeMappings:  TDictionary<string, string>;

    // ExprToString overrides: node kind → override handler
    FExprOverrides: TDictionary<string, TExprOverride>;

    // Parse a character-class pattern like 'a-zA-Z_' into a TSysCharSet
    procedure ParseCharSet(const APattern: string; out ASet: TSysCharSet);

    // Re-sort operators longest-first after each addition
    procedure SortOperators();

    // Reset all data back to construction defaults
    procedure ResetToDefaults();

    // Convert a TSysCharSet back to a compact range-notation pattern string
    function CharSetToPattern(const ASet: TSysCharSet): string;

  protected
    procedure DoLoadConfig(const AConfig: TConfig); override;
    procedure DoSaveConfig(const AConfig: TConfig); override;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Lexer surface — fluent

    // Whether keyword lookup is case-sensitive (default: false)
    function CaseSensitiveKeywords(const AValue: Boolean): TLangConfig;

    // Character classes for identifiers, using range notation e.g. 'a-zA-Z_'
    function IdentifierStart(const AChars: string): TLangConfig;
    function IdentifierPart(const AChars: string): TLangConfig;

    // Comment styles
    function AddLineComment(const APrefix: string): TLangConfig;
    function AddBlockComment(const AOpen, AClose: string;
      const ATokenKind: string = ''): TLangConfig;

    // String literal styles; AAllowEscape controls backslash escape processing
    function AddStringStyle(const AOpen, AClose, AKind: string;
      const AAllowEscape: Boolean = True): TLangConfig;

    // Keywords: text → kind string, e.g. 'begin' → 'keyword.begin'
    function AddKeyword(const AText, AKind: string): TLangConfig;

    // Operators/delimiters: text → kind string; longest-match is automatic
    function AddOperator(const AText, AKind: string): TLangConfig;

    // Number literal prefixes
    function SetHexPrefix(const APrefix, AKind: string): TLangConfig;
    function SetBinaryPrefix(const APrefix, AKind: string): TLangConfig;

    // Directive prefix (e.g. '$' for '$ifdef')
    function SetDirectivePrefix(const APrefix, AKind: string): TLangConfig;

    // Named directives: name → kind + conditional role
    function AddDirective(const AName, AKind: string;
      const ARole: TConditionalRole = crNone;
      const ACallback: TDirectiveCallback = nil): TLangConfig;
    function LookupDirective(const AName: string; out AKind: string): Boolean;
    function GetConditionalRole(const ATokenKind: string): TConditionalRole;
    function GetDirectiveCallback(const ATokenKind: string): TDirectiveCallback;
    function IsDirectiveKind(const AKind: string): Boolean;

    // Module resolution
    function SetModuleExtension(const AExt: string): TLangConfig;
    function GetModuleExtension(): string;

    // Override default kind strings for built-in token categories
    function SetIntegerKind(const AKind: string): TLangConfig;
    function SetFloatKind(const AKind: string): TLangConfig;
    function SetIdentifierKind(const AKind: string): TLangConfig;

    // Grammar surface — fluent

    // Register a statement handler — ANodeKind is the AST node kind the handler produces
    function RegisterStatement(const AKind, ANodeKind: string;
      const AHandler: TStatementHandler): TLangConfig;

    // Register a prefix expression handler — ANodeKind is the AST node kind produced
    function RegisterPrefix(const AKind, ANodeKind: string;
      const AHandler: TPrefixHandler): TLangConfig;

    // Register a left-associative infix operator — ANodeKind is the AST node kind produced
    function RegisterInfixLeft(const AKind: string;
      const ABindingPower: Integer; const ANodeKind: string;
      const AHandler: TInfixHandler): TLangConfig;

    // Register a right-associative infix operator — ANodeKind is the AST node kind produced
    function RegisterInfixRight(const AKind: string;
      const ABindingPower: Integer; const ANodeKind: string;
      const AHandler: TInfixHandler): TLangConfig;

    // Structural tokens the parser engine itself needs to operate
    function SetStatementTerminator(const AKind: string): TLangConfig;
    function SetBlockOpen(const AKind: string): TLangConfig;
    function SetBlockClose(const AKind: string): TLangConfig;

    // Emit surface — fluent

    // Register a code emitter for a given AST node kind string
    function RegisterEmitter(const ANodeKind: string;
      const AHandler: TEmitHandler): TLangConfig;

    // Semantic surface — fluent

    // Register a semantic analysis handler for a given AST node kind string.
    // The handler receives the node and the semantic engine base, enriches
    // the node with ATTR_* attributes, and drives child traversal.
    function RegisterSemanticRule(const ANodeKind: string;
      const AHandler: TSemanticHandler): TLangConfig;

    // Register the language type compatibility function.
    // Called by the engine to resolve assignment/argument type compatibility
    // and to determine when an implicit coercion attribute must be written.
    function RegisterTypeCompat(
      const AFunc: TTypeCompatFunc): TLangConfig;

    // ---- Type inference surface — fluent ----

    // Map a literal node kind to a type kind string.
    function AddLiteralType(const ANodeKind, ATypeKind: string): TLangConfig;

    // Register a node kind as a variable declaration site.
    function AddDeclKind(const ANodeKind: string): TLangConfig;

    // Register a node kind as a call site.
    function AddCallKind(const ANodeKind: string): TLangConfig;

    // Set the attribute name that holds the callee name on call nodes.
    function SetCallNameAttr(const AAttr: string): TLangConfig;

    // Map a type keyword text (case-insensitive) to a type kind string.
    // e.g. AddTypeKeyword('integer', 'type.integer')
    function AddTypeKeyword(const AText, ATypeKind: string): TLangConfig;

    // Set the name mangling function.
    function SetNameMangler(const AFunc: TNameMangler): TLangConfig;

    // Set the type-to-IR mapping function.
    function SetTypeToIR(const AFunc: TTypeToIR): TLangConfig;
    function AddTypeMapping(const ASource, ATarget: string): TLangConfig;

    // Register an ExprToString override for a specific node kind.
    function RegisterExprOverride(const ANodeKind: string;
      const AHandler: TExprOverride): TLangConfig;

    // Convenience: register a standard left-associative binary operator handler.
    // Creates an 'expr.binary' node with attr 'op' = ACppOp.
    function RegisterBinaryOp(const ATokenKind: string;
      const ABindingPower: Integer;
      const ACppOp: string): TLangConfig;

    // Convenience: register standard literal prefix handlers for the four
    // universal token kinds: identifier, integer, real, string.
    function RegisterLiteralPrefixes(): TLangConfig;

    // ---- Type inference behaviour methods ----

    // Infer type kind from a literal node using FLiteralTypes.
    // Returns 'type.double' if not found.
    function InferLiteralType(const ANode: TASTNodeBase): string;

    // Walk ARoot collecting variable name → type kind into FDeclTypes.
    procedure ScanDeclTypes(const ARoot: TASTNodeBase);

    // Walk ARoot collecting call-site arg types into FCallArgTypes.
    procedure ScanCallSites(const ARoot: TASTNodeBase);

    // Clear FDeclTypes and FCallArgTypes, then run ScanDeclTypes + ScanCallSites.
    procedure ScanAll(const ARoot: TASTNodeBase);

    // Read accessors for post-scan results.
    function GetDeclTypes(): TDictionary<string, string>;
    function GetCallArgTypes(): TDictionary<string, TArray<string>>;

    // Scan last child of ABodyNode for implicit return type.
    // Returns 'type.void' if last child kind is not in AValueKinds.
    function ScanReturnType(const ABodyNode: TASTNodeBase;
      const AValueKinds: array of string): string;

    // Scan ABodyNode recursively for a node of kind AReturnNodeKind.
    // Returns type kind of child[0] of the first match, or '' if none.
    function ScanReturnTypeRecursive(const ABodyNode: TASTNodeBase;
      const AReturnNodeKind: string): string;

    // ---- Type keyword lookup ----

    // Map a type keyword text to a type kind string (case-insensitive).
    // Returns 'type.unknown' if not registered.
    function TypeTextToKind(const AText: string): string;

    // ---- TypeToIR ----

    // Map a type kind string to a C++ type string.
    // Uses FTypeToIR if set; otherwise uses built-in defaults.
    function TypeToIR(const ATypeKind: string): string;

    // ---- Name mangling ----

    // Apply FNameMangler to AName. Returns AName unchanged if nil.
    function MangleName(const AName: string): string;

    // ---- ExprToString ----

    // Recursive node → C++ expression string.
    // Languages call RegisterExprOverride for node kinds that differ.
    function ExprToString(const ANode: TASTNodeBase): string;

    // Lexer surface — read accessors (used by TLexer)
    function GetCaseSensitive(): Boolean;
    function GetIdentStartChars(): TSysCharSet;
    function GetIdentPartChars(): TSysCharSet;
    function GetLineComments(): TList<string>;
    function GetBlockComments(): TList<TBlockCommentDef>;
    function GetStringStyles(): TList<TStringStyleDef>;
    function GetOperators(): TList<TOperatorDef>;
    function GetKeywords(): TDictionary<string, string>;
    function GetHexPrefixes(): TList<string>;
    function GetHexKind(): string;
    function GetBinaryPrefixes(): TList<string>;
    function GetBinaryKind(): string;
    function GetIntegerKind(): string;
    function GetFloatKind(): string;
    function GetIdentifierKind(): string;
    function GetEOFKind(): string;
    function GetUnknownKind(): string;
    function GetLineCommentKind(): string;
    function GetBlockCommentKind(): string;
    function GetDirectivePrefix(): string;
    function GetDirectiveKind(): string;
    function GetCommentPrefixes(): TArray<string>;

    // Grammar surface — read accessors (used by TParser)
    function GetStatementEntry(const AKind: string;
      out AEntry: TStatementEntry): Boolean;
    function GetPrefixEntry(const AKind: string;
      out AEntry: TPrefixEntry): Boolean;
    function GetInfixEntry(const AKind: string;
      out AEntry: TInfixEntry): Boolean;
    function GetStructural(): TStructuralConfig;

    // Emit surface — read accessors (used by TCodeGen)
    function GetEmitHandler(const ANodeKind: string;
      out AHandler: TEmitHandler): Boolean;

    // Semantic surface — read accessors (used by TSemantics)
    function GetSemanticHandler(const ANodeKind: string;
      out AHandler: TSemanticHandler): Boolean;
    function GetTypeCompatFunc(): TTypeCompatFunc;
  end;

implementation

{ TLangConfig }

procedure TLangConfig.ResetToDefaults();
begin
  FCaseSensitive    := False;
  FIntegerKind      := KIND_INTEGER;
  FFloatKind        := KIND_FLOAT;
  FIdentifierKind   := KIND_IDENTIFIER;
  FEOFKind          := KIND_EOF;
  FUnknownKind      := KIND_UNKNOWN;
  FLineCommentKind  := KIND_COMMENT_LINE;
  FBlockCommentKind := KIND_COMMENT_BLOCK;
  FDirectiveKind    := KIND_DIRECTIVE;
  FDirectivePrefix  := '';
  //FBuild            := nil;
  FHexKind          := KIND_INTEGER;
  FBinaryKind       := KIND_INTEGER;

  FLineComments.Clear();
  FBlockComments.Clear();
  FStringStyles.Clear();
  FOperators.Clear();
  FKeywords.Clear();
  FHexPrefixes.Clear();
  FBinaryPrefixes.Clear();
  FDirectives.Clear();

  FStatementHandlers.Clear();
  FPrefixHandlers.Clear();
  FInfixHandlers.Clear();
  FEmitHandlers.Clear();
  FSemanticHandlers.Clear();
  FTypeCompatFunc := nil;

  // Clear type inference surface
  if FLiteralTypes  <> nil then FLiteralTypes.Clear();
  if FDeclKinds     <> nil then FDeclKinds.Clear();
  if FCallKinds     <> nil then FCallKinds.Clear();
  if FTypeKeywords  <> nil then FTypeKeywords.Clear();
  if FDeclTypes     <> nil then FDeclTypes.Clear();
  if FCallArgTypes  <> nil then FCallArgTypes.Clear();
  if FExprOverrides <> nil then FExprOverrides.Clear();
  FCallNameAttr := 'call.name';
  FNameMangler  := nil;
  FTypeToIR     := nil;
  if FTypeMappings <> nil then FTypeMappings.Clear();

  FStructural.StatementTerminator := '';
  FStructural.BlockOpen           := '';
  FStructural.BlockClose          := '';

  // Default identifier character classes: standard ASCII letters + underscore
  ParseCharSet('a-zA-Z_',    FIdentStartChars);
  ParseCharSet('a-zA-Z0-9_', FIdentPartChars);
end;

function TLangConfig.CharSetToPattern(const ASet: TSysCharSet): string;
var
  LI:     Integer;
  LStart: Integer;
  LEnd:   Integer;
begin
  Result := '';
  LI     := 32; // start from printable ASCII

  while LI <= 127 do
  begin
    if AnsiChar(LI) in ASet then
    begin
      LStart := LI;
      LEnd   := LI;
      while (LEnd + 1 <= 127) and (AnsiChar(LEnd + 1) in ASet) do
        Inc(LEnd);

      if LEnd - LStart >= 2 then
      begin
        Result := Result + Char(LStart) + '-' + Char(LEnd);
        LI     := LEnd + 1;
      end
      else
      begin
        Result := Result + Char(LStart);
        LI     := LStart + 1;
      end;
    end
    else
      Inc(LI);
  end;
end;

constructor TLangConfig.Create();
begin
  inherited;

  FLineComments      := TList<string>.Create();
  FBlockComments     := TList<TBlockCommentDef>.Create();
  FStringStyles      := TList<TStringStyleDef>.Create();
  FOperators         := TList<TOperatorDef>.Create();
  FKeywords          := TDictionary<string, string>.Create();
  FHexPrefixes       := TList<string>.Create();
  FBinaryPrefixes    := TList<string>.Create();
  FDirectives        := TDictionary<string, TDirectiveEntry>.Create();
  FStatementHandlers := TDictionary<string, TStatementEntry>.Create();
  FPrefixHandlers    := TDictionary<string, TPrefixEntry>.Create();
  FInfixHandlers     := TDictionary<string, TInfixEntry>.Create();
  FEmitHandlers      := TDictionary<string, TEmitHandler>.Create();
  FSemanticHandlers  := TDictionary<string, TSemanticHandler>.Create();
  FTypeCompatFunc    := nil;

  // Type inference surface
  FLiteralTypes  := TDictionary<string, string>.Create();
  FDeclKinds     := TList<string>.Create();
  FCallKinds     := TList<string>.Create();
  FCallNameAttr  := 'call.name';
  FTypeKeywords  := TDictionary<string, string>.Create();
  FDeclTypes     := TDictionary<string, string>.Create();
  FCallArgTypes  := TDictionary<string, TArray<string>>.Create();
  FExprOverrides := TDictionary<string, TExprOverride>.Create();
  FNameMangler   := nil;
  FTypeToIR      := nil;
  FTypeMappings  := TDictionary<string, string>.Create();

  ResetToDefaults();
end;

destructor TLangConfig.Destroy();
begin
  FreeAndNil(FTypeMappings);
  FreeAndNil(FExprOverrides);
  FreeAndNil(FCallArgTypes);
  FreeAndNil(FDeclTypes);
  FreeAndNil(FTypeKeywords);
  FreeAndNil(FCallKinds);
  FreeAndNil(FDeclKinds);
  FreeAndNil(FLiteralTypes);
  FreeAndNil(FSemanticHandlers);
  FreeAndNil(FEmitHandlers);
  FreeAndNil(FInfixHandlers);
  FreeAndNil(FPrefixHandlers);
  FreeAndNil(FStatementHandlers);
  FreeAndNil(FBinaryPrefixes);
  FreeAndNil(FDirectives);
  FreeAndNil(FHexPrefixes);
  FreeAndNil(FKeywords);
  FreeAndNil(FOperators);
  FreeAndNil(FStringStyles);
  FreeAndNil(FBlockComments);
  FreeAndNil(FLineComments);
  inherited;
end;

procedure TLangConfig.ParseCharSet(const APattern: string;
  out ASet: TSysCharSet);
var
  LI:     Integer;
  LCh:    AnsiChar;
  LStart: Integer;
  LEnd:   Integer;
  LC:     Integer;
begin
  ASet := [];
  LI   := 1;
  while LI <= Length(APattern) do
  begin
    LCh := AnsiChar(APattern[LI]);
    if (LI + 2 <= Length(APattern)) and (APattern[LI + 1] = '-') then
    begin
      LStart := Ord(LCh);
      LEnd   := Ord(AnsiChar(APattern[LI + 2]));
      for LC := LStart to LEnd do
        Include(ASet, AnsiChar(LC));
      Inc(LI, 3);
    end
    else
    begin
      Include(ASet, LCh);
      Inc(LI);
    end;
  end;
end;

procedure TLangConfig.SortOperators();
begin
  // Operators must be sorted longest-first so that multi-char tokens like
  // ':=' are always tried before single-char tokens like ':'
  FOperators.Sort(TComparer<TOperatorDef>.Construct(
    function(const A, B: TOperatorDef): Integer
    begin
      Result := Length(B.Text) - Length(A.Text);
    end));
end;

// Lexer surface — fluent

function TLangConfig.CaseSensitiveKeywords(
  const AValue: Boolean): TLangConfig;
begin
  FCaseSensitive := AValue;
  Result := Self;
end;

function TLangConfig.IdentifierStart(
  const AChars: string): TLangConfig;
begin
  ParseCharSet(AChars, FIdentStartChars);
  Result := Self;
end;

function TLangConfig.IdentifierPart(
  const AChars: string): TLangConfig;
begin
  ParseCharSet(AChars, FIdentPartChars);
  Result := Self;
end;

function TLangConfig.AddLineComment(
  const APrefix: string): TLangConfig;
begin
  if APrefix <> '' then
    FLineComments.Add(APrefix);
  Result := Self;
end;

function TLangConfig.AddBlockComment(const AOpen, AClose: string;
  const ATokenKind: string): TLangConfig;
var
  LEntry: TBlockCommentDef;
begin
  if (AOpen <> '') and (AClose <> '') then
  begin
    LEntry.OpenStr   := AOpen;
    LEntry.CloseStr  := AClose;
    LEntry.TokenKind := ATokenKind;
    FBlockComments.Add(LEntry);
  end;
  Result := Self;
end;

function TLangConfig.AddStringStyle(const AOpen, AClose, AKind: string;
  const AAllowEscape: Boolean): TLangConfig;
var
  LEntry: TStringStyleDef;
begin
  if (AOpen <> '') and (AClose <> '') and (AKind <> '') then
  begin
    LEntry.OpenStr     := AOpen;
    LEntry.CloseStr    := AClose;
    LEntry.TokenKind   := AKind;
    LEntry.AllowEscape := AAllowEscape;
    FStringStyles.Add(LEntry);
  end;
  Result := Self;
end;

function TLangConfig.AddKeyword(const AText,
  AKind: string): TLangConfig;
var
  LKey: string;
begin
  if (AText <> '') and (AKind <> '') then
  begin
    if FCaseSensitive then
      LKey := AText
    else
      LKey := AText.ToLower();
    FKeywords.AddOrSetValue(LKey, AKind);
  end;
  Result := Self;
end;

function TLangConfig.AddOperator(const AText,
  AKind: string): TLangConfig;
var
  LEntry: TOperatorDef;
begin
  if (AText <> '') and (AKind <> '') then
  begin
    LEntry.Text      := AText;
    LEntry.TokenKind := AKind;
    FOperators.Add(LEntry);
    SortOperators();
  end;
  Result := Self;
end;

function TLangConfig.SetHexPrefix(const APrefix,
  AKind: string): TLangConfig;
begin
  if APrefix <> '' then
  begin
    FHexPrefixes.Add(APrefix);
    if AKind <> '' then
      FHexKind := AKind;
  end;
  Result := Self;
end;

function TLangConfig.SetBinaryPrefix(const APrefix,
  AKind: string): TLangConfig;
begin
  if APrefix <> '' then
  begin
    FBinaryPrefixes.Add(APrefix);
    if AKind <> '' then
      FBinaryKind := AKind;
  end;
  Result := Self;
end;

function TLangConfig.SetDirectivePrefix(const APrefix,
  AKind: string): TLangConfig;
begin
  FDirectivePrefix := APrefix;
  if AKind <> '' then
    FDirectiveKind := AKind;
  Result := Self;
end;

function TLangConfig.AddDirective(const AName, AKind: string;
  const ARole: TConditionalRole;
  const ACallback: TDirectiveCallback): TLangConfig;
var
  LKey:   string;
  LEntry: TDirectiveEntry;
begin
  if (AName <> '') and (AKind <> '') then
  begin
    if FCaseSensitive then
      LKey := AName
    else
      LKey := AName.ToLower();
    LEntry.TokenKind := AKind;
    LEntry.Role      := ARole;
    LEntry.Callback  := ACallback;
    FDirectives.AddOrSetValue(LKey, LEntry);
  end;
  Result := Self;
end;

function TLangConfig.LookupDirective(const AName: string;
  out AKind: string): Boolean;
var
  LKey:   string;
  LEntry: TDirectiveEntry;
begin
  if FCaseSensitive then
    LKey := AName
  else
    LKey := AName.ToLower();
  Result := FDirectives.TryGetValue(LKey, LEntry);
  if Result then
    AKind := LEntry.TokenKind;
end;

function TLangConfig.GetConditionalRole(
  const ATokenKind: string): TConditionalRole;
var
  LPair: TPair<string, TDirectiveEntry>;
begin
  // Search by token kind (not by name) — the lexer has the token kind
  for LPair in FDirectives do
  begin
    if LPair.Value.TokenKind = ATokenKind then
    begin
      Result := LPair.Value.Role;
      Exit;
    end;
  end;
  Result := crNone;
end;

function TLangConfig.GetDirectiveCallback(
  const ATokenKind: string): TDirectiveCallback;
var
  LPair: TPair<string, TDirectiveEntry>;
begin
  for LPair in FDirectives do
  begin
    if LPair.Value.TokenKind = ATokenKind then
    begin
      Result := LPair.Value.Callback;
      Exit;
    end;
  end;
  Result := nil;
end;

function TLangConfig.IsDirectiveKind(const AKind: string): Boolean;
begin
  // Matches the generic directive kind and any registered specific kind
  // (e.g. 'directive', 'directive.ifdef', 'directive.exeicon')
  Result := (AKind = FDirectiveKind) or
            AKind.StartsWith(FDirectiveKind + '.');
end;

// Module resolution

function TLangConfig.SetModuleExtension(const AExt: string): TLangConfig;
begin
  FModuleExtension := AExt;
  Result := Self;
end;

function TLangConfig.GetModuleExtension(): string;
begin
  Result := FModuleExtension;
end;

function TLangConfig.SetIntegerKind(
  const AKind: string): TLangConfig;
begin
  if AKind <> '' then
    FIntegerKind := AKind;
  Result := Self;
end;

function TLangConfig.SetFloatKind(const AKind: string): TLangConfig;
begin
  if AKind <> '' then
    FFloatKind := AKind;
  Result := Self;
end;

function TLangConfig.SetIdentifierKind(
  const AKind: string): TLangConfig;
begin
  if AKind <> '' then
    FIdentifierKind := AKind;
  Result := Self;
end;

// Grammar surface — fluent

function TLangConfig.RegisterStatement(const AKind, ANodeKind: string;
  const AHandler: TStatementHandler): TLangConfig;
var
  LEntry: TStatementEntry;
begin
  if (AKind <> '') and (ANodeKind <> '') then
  begin
    LEntry.NodeKind := ANodeKind;
    LEntry.Handler  := AHandler;
    FStatementHandlers.AddOrSetValue(AKind, LEntry);
  end;
  Result := Self;
end;

function TLangConfig.RegisterPrefix(const AKind, ANodeKind: string;
  const AHandler: TPrefixHandler): TLangConfig;
var
  LEntry: TPrefixEntry;
begin
  if (AKind <> '') and (ANodeKind <> '') then
  begin
    LEntry.NodeKind := ANodeKind;
    LEntry.Handler  := AHandler;
    FPrefixHandlers.AddOrSetValue(AKind, LEntry);
  end;
  Result := Self;
end;

function TLangConfig.RegisterInfixLeft(const AKind: string;
  const ABindingPower: Integer; const ANodeKind: string;
  const AHandler: TInfixHandler): TLangConfig;
var
  LEntry: TInfixEntry;
begin
  if (AKind <> '') and (ANodeKind <> '') then
  begin
    LEntry.NodeKind     := ANodeKind;
    LEntry.BindingPower := ABindingPower;
    LEntry.Assoc        := aoLeft;
    LEntry.Handler      := AHandler;
    FInfixHandlers.AddOrSetValue(AKind, LEntry);
  end;
  Result := Self;
end;

function TLangConfig.RegisterInfixRight(const AKind: string;
  const ABindingPower: Integer; const ANodeKind: string;
  const AHandler: TInfixHandler): TLangConfig;
var
  LEntry: TInfixEntry;
begin
  if (AKind <> '') and (ANodeKind <> '') then
  begin
    LEntry.NodeKind     := ANodeKind;
    LEntry.BindingPower := ABindingPower;
    LEntry.Assoc        := aoRight;
    LEntry.Handler      := AHandler;
    FInfixHandlers.AddOrSetValue(AKind, LEntry);
  end;
  Result := Self;
end;

function TLangConfig.SetStatementTerminator(
  const AKind: string): TLangConfig;
begin
  FStructural.StatementTerminator := AKind;
  Result := Self;
end;

function TLangConfig.SetBlockOpen(const AKind: string): TLangConfig;
begin
  FStructural.BlockOpen := AKind;
  Result := Self;
end;

function TLangConfig.SetBlockClose(const AKind: string): TLangConfig;
begin
  FStructural.BlockClose := AKind;
  Result := Self;
end;

// Emit surface — fluent

function TLangConfig.RegisterEmitter(const ANodeKind: string;
  const AHandler: TEmitHandler): TLangConfig;
begin
  if ANodeKind <> '' then
    FEmitHandlers.AddOrSetValue(ANodeKind, AHandler);
  Result := Self;
end;

// Semantic surface — fluent

function TLangConfig.RegisterSemanticRule(const ANodeKind: string;
  const AHandler: TSemanticHandler): TLangConfig;
begin
  if ANodeKind <> '' then
    FSemanticHandlers.AddOrSetValue(ANodeKind, AHandler);
  Result := Self;
end;

function TLangConfig.RegisterTypeCompat(
  const AFunc: TTypeCompatFunc): TLangConfig;
begin
  FTypeCompatFunc := AFunc;
  Result := Self;
end;

// Lexer surface — read accessors

function TLangConfig.GetCaseSensitive(): Boolean;
begin
  Result := FCaseSensitive;
end;

function TLangConfig.GetIdentStartChars(): TSysCharSet;
begin
  Result := FIdentStartChars;
end;

function TLangConfig.GetIdentPartChars(): TSysCharSet;
begin
  Result := FIdentPartChars;
end;

function TLangConfig.GetLineComments(): TList<string>;
begin
  Result := FLineComments;
end;

function TLangConfig.GetBlockComments(): TList<TBlockCommentDef>;
begin
  Result := FBlockComments;
end;

function TLangConfig.GetStringStyles(): TList<TStringStyleDef>;
begin
  Result := FStringStyles;
end;

function TLangConfig.GetOperators(): TList<TOperatorDef>;
begin
  Result := FOperators;
end;

function TLangConfig.GetKeywords(): TDictionary<string, string>;
begin
  Result := FKeywords;
end;

function TLangConfig.GetHexPrefixes(): TList<string>;
begin
  Result := FHexPrefixes;
end;

function TLangConfig.GetHexKind(): string;
begin
  Result := FHexKind;
end;

function TLangConfig.GetBinaryPrefixes(): TList<string>;
begin
  Result := FBinaryPrefixes;
end;

function TLangConfig.GetBinaryKind(): string;
begin
  Result := FBinaryKind;
end;

function TLangConfig.GetIntegerKind(): string;
begin
  Result := FIntegerKind;
end;

function TLangConfig.GetFloatKind(): string;
begin
  Result := FFloatKind;
end;

function TLangConfig.GetIdentifierKind(): string;
begin
  Result := FIdentifierKind;
end;

function TLangConfig.GetEOFKind(): string;
begin
  Result := FEOFKind;
end;

function TLangConfig.GetUnknownKind(): string;
begin
  Result := FUnknownKind;
end;

function TLangConfig.GetLineCommentKind(): string;
begin
  Result := FLineCommentKind;
end;

function TLangConfig.GetBlockCommentKind(): string;
begin
  Result := FBlockCommentKind;
end;

function TLangConfig.GetDirectivePrefix(): string;
begin
  Result := FDirectivePrefix;
end;

function TLangConfig.GetDirectiveKind(): string;
begin
  Result := FDirectiveKind;
end;

function TLangConfig.GetCommentPrefixes(): TArray<string>;
var
  LI: Integer;
  LIdx: Integer;
begin
  SetLength(Result, FLineComments.Count + FBlockComments.Count);
  LIdx := 0;
  for LI := 0 to FLineComments.Count - 1 do
  begin
    Result[LIdx] := FLineComments[LI];
    Inc(LIdx);
  end;
  for LI := 0 to FBlockComments.Count - 1 do
  begin
    Result[LIdx] := FBlockComments[LI].OpenStr;
    Inc(LIdx);
  end;
end;

// Grammar surface — read accessors

function TLangConfig.GetStatementEntry(const AKind: string;
  out AEntry: TStatementEntry): Boolean;
begin
  Result := FStatementHandlers.TryGetValue(AKind, AEntry);
end;

function TLangConfig.GetPrefixEntry(const AKind: string;
  out AEntry: TPrefixEntry): Boolean;
begin
  Result := FPrefixHandlers.TryGetValue(AKind, AEntry);
end;

function TLangConfig.GetInfixEntry(const AKind: string;
  out AEntry: TInfixEntry): Boolean;
begin
  Result := FInfixHandlers.TryGetValue(AKind, AEntry);
end;

function TLangConfig.GetStructural(): TStructuralConfig;
begin
  Result := FStructural;
end;

// Emit surface — read accessors

function TLangConfig.GetEmitHandler(const ANodeKind: string;
  out AHandler: TEmitHandler): Boolean;
begin
  Result := FEmitHandlers.TryGetValue(ANodeKind, AHandler);
end;

// Semantic surface — read accessors

function TLangConfig.GetSemanticHandler(const ANodeKind: string;
  out AHandler: TSemanticHandler): Boolean;
begin
  Result := FSemanticHandlers.TryGetValue(ANodeKind, AHandler);
end;

function TLangConfig.GetTypeCompatFunc(): TTypeCompatFunc;
begin
  Result := FTypeCompatFunc;
end;

// ---- Type inference surface — fluent ----

function TLangConfig.AddLiteralType(const ANodeKind,
  ATypeKind: string): TLangConfig;
begin
  if (ANodeKind <> '') and (ATypeKind <> '') then
    FLiteralTypes.AddOrSetValue(ANodeKind, ATypeKind);
  Result := Self;
end;

function TLangConfig.AddDeclKind(const ANodeKind: string): TLangConfig;
begin
  if (ANodeKind <> '') and (not FDeclKinds.Contains(ANodeKind)) then
    FDeclKinds.Add(ANodeKind);
  Result := Self;
end;

function TLangConfig.AddCallKind(const ANodeKind: string): TLangConfig;
begin
  if (ANodeKind <> '') and (not FCallKinds.Contains(ANodeKind)) then
    FCallKinds.Add(ANodeKind);
  Result := Self;
end;

function TLangConfig.SetCallNameAttr(
  const AAttr: string): TLangConfig;
begin
  if AAttr <> '' then
    FCallNameAttr := AAttr;
  Result := Self;
end;

function TLangConfig.AddTypeKeyword(const AText,
  ATypeKind: string): TLangConfig;
begin
  // Store keys lowercase for case-insensitive lookup
  if (AText <> '') and (ATypeKind <> '') then
    FTypeKeywords.AddOrSetValue(LowerCase(AText), ATypeKind);
  Result := Self;
end;

function TLangConfig.SetNameMangler(
  const AFunc: TNameMangler): TLangConfig;
begin
  FNameMangler := AFunc;
  Result := Self;
end;

function TLangConfig.SetTypeToIR(
  const AFunc: TTypeToIR): TLangConfig;
begin
  FTypeToIR := AFunc;
  Result := Self;
end;

function TLangConfig.AddTypeMapping(
  const ASource, ATarget: string): TLangConfig;
begin
  if (ASource <> '') and (ATarget <> '') then
    FTypeMappings.AddOrSetValue(ASource, ATarget);
  Result := Self;
end;

function TLangConfig.RegisterExprOverride(const ANodeKind: string;
  const AHandler: TExprOverride): TLangConfig;
begin
  if ANodeKind <> '' then
    FExprOverrides.AddOrSetValue(ANodeKind, AHandler);
  Result := Self;
end;

function TLangConfig.RegisterBinaryOp(const ATokenKind: string;
  const ABindingPower: Integer;
  const ACppOp: string): TLangConfig;
begin
  // Capture ACppOp in the anonymous handler closure
  RegisterInfixLeft(ATokenKind, ABindingPower, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>(ACppOp));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
  Result := Self;
end;

function TLangConfig.RegisterLiteralPrefixes(): TLangConfig;
begin
  // identifier
  RegisterPrefix(KIND_IDENTIFIER, 'expr.ident',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);

  // integer literal
  RegisterPrefix(KIND_INTEGER, 'expr.integer',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);

  // real literal
  RegisterPrefix(KIND_FLOAT, 'expr.float',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);

  // string literal
  RegisterPrefix(KIND_STRING, 'expr.string',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);

  Result := Self;
end;

// ---- Type inference behaviour methods ----

function TLangConfig.InferLiteralType(
  const ANode: TASTNodeBase): string;
begin
  if not FLiteralTypes.TryGetValue(ANode.GetNodeKind(), Result) then
    Result := 'type.double';
end;

procedure TLangConfig.ScanDeclTypes(const ARoot: TASTNodeBase);
var
  LI:    Integer;
  LKind: string;
begin
  if ARoot = nil then
    Exit;
  LKind := ARoot.GetNodeKind();
  // If this node is a declaration site, record var name → type kind
  if FDeclKinds.Contains(LKind) then
    FDeclTypes.AddOrSetValue(ARoot.GetToken().Text,
      InferLiteralType(ARoot.GetChild(0)));
  // Always recurse into children
  for LI := 0 to ARoot.ChildCount() - 1 do
    ScanDeclTypes(ARoot.GetChild(LI));
end;

procedure TLangConfig.ScanCallSites(const ARoot: TASTNodeBase);
var
  LI:       Integer;
  LKind:    string;
  LName:    TValue;
  LFuncName: string;
  LArgTypes: TArray<string>;
  LArgNode:  TASTNodeBase;
  LArgKind:  string;
  LArgType:  string;
begin
  if ARoot = nil then
    Exit;
  LKind := ARoot.GetNodeKind();
  if FCallKinds.Contains(LKind) then
  begin
    // Get callee name from the designated attribute
    if ARoot.GetAttr(FCallNameAttr, LName) then
    begin
      LFuncName := LName.AsString;
      SetLength(LArgTypes, ARoot.ChildCount());
      for LI := 0 to ARoot.ChildCount() - 1 do
      begin
        LArgNode := ARoot.GetChild(LI);
        LArgKind := LArgNode.GetNodeKind();
        // Try to resolve type from literal kinds first, then from declared vars
        if FLiteralTypes.TryGetValue(LArgKind, LArgType) then
          LArgTypes[LI] := LArgType
        else if LArgKind = 'expr.ident' then
        begin
          if not FDeclTypes.TryGetValue(LArgNode.GetToken().Text, LArgTypes[LI]) then
            LArgTypes[LI] := 'type.double';
        end
        else
          LArgTypes[LI] := 'type.double';
      end;
      FCallArgTypes.AddOrSetValue(LFuncName, LArgTypes);
    end;
  end;
  // Always recurse
  for LI := 0 to ARoot.ChildCount() - 1 do
    ScanCallSites(ARoot.GetChild(LI));
end;

procedure TLangConfig.ScanAll(const ARoot: TASTNodeBase);
begin
  FDeclTypes.Clear();
  FCallArgTypes.Clear();
  ScanDeclTypes(ARoot);
  ScanCallSites(ARoot);
end;

function TLangConfig.GetDeclTypes(): TDictionary<string, string>;
begin
  Result := FDeclTypes;
end;

function TLangConfig.GetCallArgTypes(): TDictionary<string, TArray<string>>;
begin
  Result := FCallArgTypes;
end;

function TLangConfig.ScanReturnType(const ABodyNode: TASTNodeBase;
  const AValueKinds: array of string): string;
var
  LLast:     TASTNodeBase;
  LLastKind: string;
  LKind:     string;
  LFound:    Boolean;
begin
  Result := 'type.void';
  if (ABodyNode = nil) or (ABodyNode.ChildCount() = 0) then
    Exit;
  LLast     := ABodyNode.GetChild(ABodyNode.ChildCount() - 1);
  LLastKind := LLast.GetNodeKind();
  LFound    := False;
  for LKind in AValueKinds do
    if LKind = LLastKind then
    begin
      LFound := True;
      Break;
    end;
  if LFound then
    Result := InferLiteralType(LLast);
end;

function TLangConfig.ScanReturnTypeRecursive(
  const ABodyNode: TASTNodeBase;
  const AReturnNodeKind: string): string;
var
  LI:    Integer;
  LChild: TASTNodeBase;
begin
  Result := '';
  if ABodyNode = nil then
    Exit;
  if ABodyNode.GetNodeKind() = AReturnNodeKind then
  begin
    // Found a return node — get type kind of child[0]
    if ABodyNode.ChildCount() > 0 then
      Result := InferLiteralType(ABodyNode.GetChild(0));
    Exit;
  end;
  // Recurse into children
  for LI := 0 to ABodyNode.ChildCount() - 1 do
  begin
    LChild := ABodyNode.GetChild(LI);
    Result := ScanReturnTypeRecursive(LChild, AReturnNodeKind);
    if Result <> '' then
      Exit;
  end;
end;

// ---- Type keyword lookup ----

function TLangConfig.TypeTextToKind(const AText: string): string;
begin
  if not FTypeKeywords.TryGetValue(LowerCase(AText), Result) then
    Result := 'type.unknown';
end;

// ---- TypeToIR ----

function TLangConfig.TypeToIR(const ATypeKind: string): string;
begin
  // Check language-defined type mappings first
  if FTypeMappings.TryGetValue(ATypeKind, Result) then
    Exit;
  // Delegate to language-specific override if set
  if Assigned(FTypeToIR) then
  begin
    Result := FTypeToIR(ATypeKind);
    Exit;
  end;
  // No mapping found — return the type name unchanged
  Result := ATypeKind;
end;

// ---- Name mangling ----

function TLangConfig.MangleName(const AName: string): string;
begin
  if Assigned(FNameMangler) then
    Result := FNameMangler(AName)
  else
    Result := AName;
end;

// ---- ExprToString ----

function TLangConfig.ExprToString(const ANode: TASTNodeBase): string;
var
  LOverride:  TExprOverride;
  LKind:      string;
  LText:      string;
  LAttr:      TValue;
  LOp:        string;
  LArgs:      string;
  LI:         Integer;
  LDefault:   TExprToStringFunc;
begin
  Result := '';
  if ANode = nil then
    Exit;

  LKind := ANode.GetNodeKind();

  // Build the default function reference for overrides to call
  LDefault := function(const AChild: TASTNodeBase): string
    begin
      Result := ExprToString(AChild);
    end;

  // Check for a language-specific override first
  if FExprOverrides.TryGetValue(LKind, LOverride) then
  begin
    Result := LOverride(ANode, LDefault);
    Exit;
  end;

  // Default handling
  if LKind = 'expr.ident' then
    Result := MangleName(ANode.GetToken().Text)
  else if (LKind = 'expr.integer') or (LKind = 'expr.float') then
    Result := ANode.GetToken().Text
  else if LKind = 'expr.bool' then
    // Default: pass through token text (override for language-specific True/False)
    Result := ANode.GetToken().Text
  else if LKind = 'expr.string' then
  begin
    // Strip outer quotes and re-wrap in double quotes
    LText := ANode.GetToken().Text;
    if (Length(LText) >= 2) and
       ((LText[1] = '"') or (LText[1] = '''')) and
       (LText[Length(LText)] = LText[1]) then
      Result := '"' + Copy(LText, 2, Length(LText) - 2) + '"'
    else
      Result := '"' + LText + '"';
  end
  else if LKind = 'expr.unary' then
  begin
    ANode.GetAttr('op', LAttr);
    LOp    := LAttr.AsString;
    Result := LOp + ExprToString(ANode.GetChild(0));
  end
  else if LKind = 'expr.binary' then
  begin
    ANode.GetAttr('op', LAttr);
    LOp    := LAttr.AsString;
    Result := ExprToString(ANode.GetChild(0)) + ' ' + LOp + ' ' +
              ExprToString(ANode.GetChild(1));
  end
  else if LKind = 'expr.grouped' then
    Result := '(' + ExprToString(ANode.GetChild(0)) + ')'
  else if LKind = 'expr.call' then
  begin
    ANode.GetAttr('call.name', LAttr);
    LArgs := '';
    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      if LI > 0 then
        LArgs := LArgs + ', ';
      LArgs := LArgs + ExprToString(ANode.GetChild(LI));
    end;
    Result := MangleName(LAttr.AsString) + '(' + LArgs + ')';
  end;
  // else: return '' for unrecognised node kinds
end;

// TOML persistence

procedure TLangConfig.DoLoadConfig(const AConfig: TConfig);
var
  LCount:    Integer;
  LI:        Integer;
  LOpen:     string;
  LClose:    string;
  LKind:     string;
  LText:     string;
  LAllowEsc: Boolean;
  LPrefix:   string;
  LPrefixes: TArray<string>;
begin
  ResetToDefaults();

  // Scalar fields
  FCaseSensitive    := AConfig.GetBoolean('case_sensitive',     False);
  FIntegerKind      := AConfig.GetString('integer_kind',        KIND_INTEGER);
  FFloatKind        := AConfig.GetString('float_kind',          KIND_FLOAT);
  FIdentifierKind   := AConfig.GetString('identifier_kind',     KIND_IDENTIFIER);
  FLineCommentKind  := AConfig.GetString('line_comment_kind',   KIND_COMMENT_LINE);
  FBlockCommentKind := AConfig.GetString('block_comment_kind',  KIND_COMMENT_BLOCK);
  FDirectivePrefix  := AConfig.GetString('directive_prefix',    '');
  FDirectiveKind    := AConfig.GetString('directive_kind',      KIND_DIRECTIVE);
  FModuleExtension  := AConfig.GetString('module_extension',    '');
  FHexKind          := AConfig.GetString('hex_kind',            KIND_INTEGER);
  FBinaryKind       := AConfig.GetString('binary_kind',         KIND_INTEGER);

  LText := AConfig.GetString('identifier_start', '');
  if LText <> '' then
    ParseCharSet(LText, FIdentStartChars);

  LText := AConfig.GetString('identifier_part', '');
  if LText <> '' then
    ParseCharSet(LText, FIdentPartChars);

  LPrefixes := AConfig.GetStringArray('line_comments');
  for LPrefix in LPrefixes do
    AddLineComment(LPrefix);

  LPrefixes := AConfig.GetStringArray('hex_prefixes');
  for LPrefix in LPrefixes do
    if LPrefix <> '' then
      FHexPrefixes.Add(LPrefix);

  LPrefixes := AConfig.GetStringArray('binary_prefixes');
  for LPrefix in LPrefixes do
    if LPrefix <> '' then
      FBinaryPrefixes.Add(LPrefix);

  LCount := AConfig.GetTableCount('block_comments');
  for LI := 0 to LCount - 1 do
  begin
    LOpen  := AConfig.GetTableString('block_comments', LI, 'open',       '');
    LClose := AConfig.GetTableString('block_comments', LI, 'close',      '');
    LKind  := AConfig.GetTableString('block_comments', LI, 'token_kind', '');
    AddBlockComment(LOpen, LClose, LKind);
  end;

  LCount := AConfig.GetTableCount('string_styles');
  for LI := 0 to LCount - 1 do
  begin
    LOpen     := AConfig.GetTableString('string_styles',  LI, 'open',         '');
    LClose    := AConfig.GetTableString('string_styles',  LI, 'close',        '');
    LKind     := AConfig.GetTableString('string_styles',  LI, 'kind',         '');
    LAllowEsc := AConfig.GetTableBoolean('string_styles', LI, 'allow_escape', True);
    AddStringStyle(LOpen, LClose, LKind, LAllowEsc);
  end;

  LCount := AConfig.GetTableCount('operators');
  for LI := 0 to LCount - 1 do
  begin
    LText := AConfig.GetTableString('operators', LI, 'text', '');
    LKind := AConfig.GetTableString('operators', LI, 'kind', '');
    AddOperator(LText, LKind);
  end;

  LCount := AConfig.GetTableCount('keywords');
  for LI := 0 to LCount - 1 do
  begin
    LText := AConfig.GetTableString('keywords', LI, 'text', '');
    LKind := AConfig.GetTableString('keywords', LI, 'kind', '');
    AddKeyword(LText, LKind);
  end;

  // Grammar surface structural tokens
  FStructural.StatementTerminator :=
    AConfig.GetString('structural.statement_terminator', '');
  FStructural.BlockOpen  :=
    AConfig.GetString('structural.block_open',  '');
  FStructural.BlockClose :=
    AConfig.GetString('structural.block_close', '');
end;

procedure TLangConfig.DoSaveConfig(const AConfig: TConfig);
var
  LPair:     TPair<string, string>;
  LBC:       TBlockCommentDef;
  LSS:       TStringStyleDef;
  LOp:       TOperatorDef;
  LIdx:      Integer;
  LPrefixes: TArray<string>;
  LI:        Integer;
begin
  AConfig.SetBoolean('case_sensitive',    FCaseSensitive);
  AConfig.SetString('identifier_start',   CharSetToPattern(FIdentStartChars));
  AConfig.SetString('identifier_part',    CharSetToPattern(FIdentPartChars));
  AConfig.SetString('integer_kind',       FIntegerKind);
  AConfig.SetString('float_kind',         FFloatKind);
  AConfig.SetString('identifier_kind',    FIdentifierKind);
  AConfig.SetString('line_comment_kind',  FLineCommentKind);
  AConfig.SetString('block_comment_kind', FBlockCommentKind);
  AConfig.SetString('directive_prefix',   FDirectivePrefix);
  AConfig.SetString('directive_kind',     FDirectiveKind);
  AConfig.SetString('module_extension',   FModuleExtension);
  AConfig.SetString('hex_kind',           FHexKind);
  AConfig.SetString('binary_kind',        FBinaryKind);

  SetLength(LPrefixes, FLineComments.Count);
  for LI := 0 to FLineComments.Count - 1 do
    LPrefixes[LI] := FLineComments[LI];
  AConfig.SetStringArray('line_comments', LPrefixes);

  SetLength(LPrefixes, FHexPrefixes.Count);
  for LI := 0 to FHexPrefixes.Count - 1 do
    LPrefixes[LI] := FHexPrefixes[LI];
  AConfig.SetStringArray('hex_prefixes', LPrefixes);

  SetLength(LPrefixes, FBinaryPrefixes.Count);
  for LI := 0 to FBinaryPrefixes.Count - 1 do
    LPrefixes[LI] := FBinaryPrefixes[LI];
  AConfig.SetStringArray('binary_prefixes', LPrefixes);

  for LBC in FBlockComments do
  begin
    LIdx := AConfig.AddTableEntry('block_comments');
    AConfig.SetTableString('block_comments', LIdx, 'open',       LBC.OpenStr);
    AConfig.SetTableString('block_comments', LIdx, 'close',      LBC.CloseStr);
    AConfig.SetTableString('block_comments', LIdx, 'token_kind', LBC.TokenKind);
  end;

  for LSS in FStringStyles do
  begin
    LIdx := AConfig.AddTableEntry('string_styles');
    AConfig.SetTableString('string_styles',  LIdx, 'open',         LSS.OpenStr);
    AConfig.SetTableString('string_styles',  LIdx, 'close',        LSS.CloseStr);
    AConfig.SetTableString('string_styles',  LIdx, 'kind',         LSS.TokenKind);
    AConfig.SetTableBoolean('string_styles', LIdx, 'allow_escape', LSS.AllowEscape);
  end;

  for LOp in FOperators do
  begin
    LIdx := AConfig.AddTableEntry('operators');
    AConfig.SetTableString('operators', LIdx, 'text', LOp.Text);
    AConfig.SetTableString('operators', LIdx, 'kind', LOp.TokenKind);
  end;

  for LPair in FKeywords do
  begin
    LIdx := AConfig.AddTableEntry('keywords');
    AConfig.SetTableString('keywords', LIdx, 'text', LPair.Key);
    AConfig.SetTableString('keywords', LIdx, 'kind', LPair.Value);
  end;

  AConfig.SetString('structural.statement_terminator',
    FStructural.StatementTerminator);
  AConfig.SetString('structural.block_open',  FStructural.BlockOpen);
  AConfig.SetString('structural.block_close', FStructural.BlockClose);
end;

end.
