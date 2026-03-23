{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit DelphiFmt.Grammar;

{$I DelphiFmt.Defines.inc}

interface

uses
  Metamorf.API,
  Metamorf.Common;

procedure ConfigGrammar(const AParse: TMetamorf);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Rtti;

// =============================================================================
//  Forward declarations for helper procedures
// =============================================================================
//
//  These helpers are called by multiple grammar handlers to parse common
//  Delphi sub-constructs (type references, parameter lists, routine
//  directives, uses clauses).  They receive the parser instance and
//  produce AST subtrees.
// =============================================================================

function  ParseTypeReference(const AParser: TParserBase): TASTNode; forward;
function  ParseParamList(const AParser: TParserBase): TASTNode; forward;
procedure ParseRoutineDirectives(const AParser: TParserBase;
  const ANode: TASTNode); forward;
function  ParseUsesClause(const AParser: TParserBase; const AUsesKW: string): TASTNode; forward;
function  ParseRoutineSignature(const AParser: TParserBase;
  const AIsFunction: Boolean; const ANodeKind: string): TASTNode; forward;
procedure ParseRoutineBody(const AParser: TParserBase;
  const ANode: TASTNode); forward;
function  ParseFieldDecl(const AParser: TParserBase): TASTNode; forward;
function  ParsePropertyDecl(const AParser: TParserBase): TASTNode; forward;
function  ParseParamList_Bracket(const AParser: TParserBase): TASTNode; forward;
function  ParseRecordCase(const AParser: TParserBase): TASTNode; forward;

// =============================================================================
//  Helper: IsDeclarationStart
// =============================================================================
//
//  Returns True if the current token starts a declaration block (var,
//  const, type, threadvar, resourcestring, label) or a routine
//  (procedure, function, constructor, destructor, class). Used by
//  section-level parsers to know when to keep looping.
// =============================================================================

function IsDeclarationStart(const AParser: TParserBase): Boolean;
begin
  Result :=
    AParser.Check('keyword.var') or
    AParser.Check('keyword.const') or
    AParser.Check('keyword.type') or
    AParser.Check('keyword.threadvar') or
    AParser.Check('keyword.resourcestring') or
    AParser.Check('keyword.label') or
    AParser.Check('keyword.procedure') or
    AParser.Check('keyword.function') or
    AParser.Check('keyword.constructor') or
    AParser.Check('keyword.destructor') or
    AParser.Check('keyword.class') or       // class procedure/function
    AParser.Check('keyword.exports') or
    AParser.Check('literal.directive');
end;

// =============================================================================
//  Helper: IsRoutineDirective
// =============================================================================
//
//  Returns True if the current token is a routine directive keyword
//  (virtual, override, abstract, etc.). These appear after the
//  procedure/function signature, separated by semicolons.
// =============================================================================

function IsRoutineDirective(const AParser: TParserBase): Boolean;
begin
  Result :=
    // Calling conventions
    AParser.Check('keyword.cdecl') or
    AParser.Check('keyword.pascal') or
    AParser.Check('keyword.register') or
    AParser.Check('keyword.safecall') or
    AParser.Check('keyword.stdcall') or
    AParser.Check('keyword.winapi') or
    // Binding
    AParser.Check('keyword.virtual') or
    AParser.Check('keyword.dynamic') or
    AParser.Check('keyword.override') or
    AParser.Check('keyword.abstract') or
    AParser.Check('keyword.final') or
    AParser.Check('keyword.reintroduce') or
    AParser.Check('keyword.static') or
    // Linkage
    AParser.Check('keyword.overload') or
    AParser.Check('keyword.inline') or
    AParser.Check('keyword.forward') or
    AParser.Check('keyword.external') or
    AParser.Check('keyword.export') or
    AParser.Check('keyword.far') or
    AParser.Check('keyword.near') or
    AParser.Check('keyword.local') or
    AParser.Check('keyword.varargs') or
    AParser.Check('keyword.delayed') or
    AParser.Check('keyword.resident') or
    AParser.Check('keyword.assembler') or
    // Hint
    AParser.Check('keyword.deprecated') or
    AParser.Check('keyword.experimental') or
    AParser.Check('keyword.platform') or
    // Message
    AParser.Check('keyword.message') or
    // Dispid
    AParser.Check('keyword.dispid');
end;

// =============================================================================
//  Helper: ParseTypeReference
// =============================================================================
//
//  Parses a Delphi type reference and returns a type_ref.* AST node.
//  Handles:
//    - Simple identifiers: Integer, TMyClass
//    - Qualified names: System.SysUtils.TObject
//    - Generics: TList<Integer>, TDictionary<string, TList<Integer>>
//    - Array types: array of T, array[0..9] of T
//    - Set types: set of TEnum
//    - Pointer types: ^T
//    - String with length: string[255]
//    - File types: file of T
//    - Procedure/function types: procedure(A: Integer) of object
//    - Reference to procedure/function
//    - Range types: 0..255
//    - Packed prefix
//    - class of TBase
// =============================================================================

function ParseTypeReference(const AParser: TParserBase): TASTNode;
var
  LNode:     TASTNode;
  LParamList: TASTNode;
  LName:     string;
  LSrictKW:  string;
begin
  // Distinct type alias prefix: type T = type Integer;
  if AParser.Check('keyword.type') then
  begin
    LNode := AParser.CreateNode('type_ref.type');
    AParser.Consume();
    LNode.AddChild(ParseTypeReference(AParser));
    Result := LNode;
    Exit;
  end;

  // Packed prefix
  if AParser.Check('keyword.packed') then
  begin
    LNode := AParser.CreateNode('type_ref.packed');
    AParser.Consume();
    LNode.AddChild(ParseTypeReference(AParser));
    Result := LNode;
    Exit;
  end;

  // Array type
  if AParser.Check('keyword.array') then
  begin
    LNode := AParser.CreateNode('type_ref.array');
    AParser.Consume();  // consume 'array'
    // Optional bounds: array[low..high] or array[low..high, low2..high2]
    if AParser.Match('delimiter.lbracket') then
    begin
      LNode.SetAttr('array.kind', TValue.From<string>('static'));
      // Parse index type(s) — could be expressions with ranges
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      while AParser.Match('delimiter.comma') do
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rbracket');
    end
    else
      LNode.SetAttr('array.kind', TValue.From<string>('dynamic'));
    LNode.SetAttr('kw.of', TValue.From<string>(AParser.CurrentToken().Text));
    AParser.Expect('keyword.of');
    LNode.AddChild(ParseTypeReference(AParser));
    Result := LNode;
    Exit;
  end;

  // Set type
  if AParser.Check('keyword.set') then
  begin
    LNode := AParser.CreateNode('type_ref.set');
    AParser.Consume();  // consume 'set'
    LNode.SetAttr('kw.of', TValue.From<string>(AParser.CurrentToken().Text));
    AParser.Expect('keyword.of');
    LNode.AddChild(ParseTypeReference(AParser));
    Result := LNode;
    Exit;
  end;

  // File type
  if AParser.Check('keyword.file') then
  begin
    LNode := AParser.CreateNode('type_ref.file');
    AParser.Consume();  // consume 'file'
    if AParser.Check('keyword.of') then
    begin
      LNode.SetAttr('kw.of', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      LNode.AddChild(ParseTypeReference(AParser));
    end;
    // bare 'file' is also valid (untyped file)
    Result := LNode;
    Exit;
  end;

  // Pointer type: ^T
  if AParser.Check('op.deref') then
  begin
    LNode := AParser.CreateNode('type_ref.pointer');
    AParser.Consume();  // consume '^'
    LNode.AddChild(ParseTypeReference(AParser));
    Result := LNode;
    Exit;
  end;

  // String type with optional length: string[255]
  if AParser.Check('keyword.string') then
  begin
    LNode := AParser.CreateNode('type_ref.string', AParser.CurrentToken());
    AParser.Consume();  // consume 'string'
    if AParser.Match('delimiter.lbracket') then
    begin
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rbracket');
    end;
    Result := LNode;
    Exit;
  end;

  // Procedure type: procedure(params) [of object]
  if AParser.Check('keyword.procedure') then
  begin
    LNode := AParser.CreateNode('type_ref.procedure', AParser.CurrentToken());
    AParser.Consume();  // consume 'procedure'
    if AParser.Check('delimiter.lparen') then
    begin
      LParamList := ParseParamList(AParser);
      LNode.AddChild(LParamList);
    end;
    // Optional 'of object'
    if AParser.Check('keyword.of') then
    begin
      LNode.SetAttr('kw.of', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      LNode.SetAttr('kw.object', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.object');
      LNode.SetAttr('type.method_pointer', TValue.From<Boolean>(True));
    end;
    // Optional calling convention directive on procedure type (e.g. stdcall)
    while IsRoutineDirective(AParser) do
    begin
      LNode.SetAttr('type.directive', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
    end;
    Result := LNode;
    Exit;
  end;

  // Function type: function(params): ReturnType [of object]
  if AParser.Check('keyword.function') then
  begin
    LNode := AParser.CreateNode('type_ref.function', AParser.CurrentToken());
    AParser.Consume();  // consume 'function'
    if AParser.Check('delimiter.lparen') then
    begin
      LParamList := ParseParamList(AParser);
      LNode.AddChild(LParamList);
    end;
    AParser.Expect('delimiter.colon');
    LNode.AddChild(ParseTypeReference(AParser));
    // Optional 'of object'
    if AParser.Check('keyword.of') then
    begin
      LNode.SetAttr('kw.of', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      LNode.SetAttr('kw.object', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.object');
      LNode.SetAttr('type.method_pointer', TValue.From<Boolean>(True));
    end;
    // Optional calling convention directive on function type (e.g. stdcall)
    while IsRoutineDirective(AParser) do
    begin
      LNode.SetAttr('type.directive', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
    end;
    Result := LNode;
    Exit;
  end;

  // Reference to procedure/function
  if AParser.Check('keyword.reference') then
  begin
    LNode := AParser.CreateNode('type_ref.reference', AParser.CurrentToken());
    AParser.Consume();  // consume 'reference'
    LNode.SetAttr('kw.to', TValue.From<string>(AParser.CurrentToken().Text));
    AParser.Expect('keyword.to');
    // Must be followed by procedure or function type
    LNode.AddChild(ParseTypeReference(AParser));
    Result := LNode;
    Exit;
  end;

  // Enumeration type: (item1, item2, item3)
  if AParser.Check('delimiter.lparen') then
  begin
    LNode := AParser.CreateNode('type_ref.enum', AParser.CurrentToken());
    AParser.Consume();  // consume '('
    LNode.SetAttr('enum.count', TValue.From<Integer>(0));
    if not AParser.Check('delimiter.rparen') then
    begin
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      while AParser.Match('delimiter.comma') do
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
    end;
    AParser.Expect('delimiter.rparen');
    Result := LNode;
    Exit;
  end;

  // Record type: record [field declarations] end
  if AParser.Check('keyword.record') then
  begin
    LNode := AParser.CreateNode('type_ref.record', AParser.CurrentToken());
    AParser.Consume();  // consume 'record'
    // Parse fields until 'end'
    while not AParser.Check('keyword.end') and
          not AParser.Check(KIND_EOF) do
    begin
      // Visibility modifiers inside records (Delphi advanced records)
      if AParser.Check('keyword.private') or
         AParser.Check('keyword.public') or
         AParser.Check('keyword.protected') or
         AParser.Check('keyword.published') then
      begin
        LNode.AddChild(AParser.CreateNode('stmt.visibility',
          AParser.CurrentToken()));
        AParser.Consume();
      end
      // Methods inside records
      else if AParser.Check('keyword.procedure') or
              AParser.Check('keyword.function') or
              AParser.Check('keyword.constructor') or
              AParser.Check('keyword.destructor') or
              AParser.Check('keyword.class') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end
      // Compiler directives
      else if AParser.Check('literal.directive') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end
      // Property declarations
      else if AParser.Check('keyword.property') then
      begin
        LNode.AddChild(ParsePropertyDecl(AParser));
      end
      // Case variant part
      else if AParser.Check('keyword.case') then
      begin
        LNode.AddChild(ParseRecordCase(AParser));
      end
      // Field declarations: anything else must be a field name
      else
        LNode.AddChild(ParseFieldDecl(AParser));
    end;
    LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
    AParser.Expect('keyword.end');
    Result := LNode;
    Exit;
  end;

  // Class type: class [(BaseClass, IFace1)] [visibility sections] end
  if AParser.Check('keyword.class') then
  begin
    LNode := AParser.CreateNode('type_ref.class', AParser.CurrentToken());
    AParser.Consume();  // consume 'class'

    // class of T — metaclass reference
    if AParser.Check('keyword.of') then
    begin
      // LNode currently holds the 'class' token — preserve it before overwriting
      LNode := AParser.CreateNode('type_ref.class_of', LNode.GetToken());
      LNode.SetAttr('kw.of', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume 'of'
      LNode.AddChild(ParseTypeReference(AParser));
      Result := LNode;
      Exit;
    end;

    // Forward declaration: TFoo = class;  (no body, semicolon follows)
    if AParser.Check('delimiter.semicolon') then
    begin
      LNode.SetAttr('class.forward', TValue.From<Boolean>(True));
      Result := LNode;
      Exit;
    end;

    // Abstract/sealed modifier
    if AParser.Check('keyword.abstract') then
    begin
      LNode.SetAttr('class.modifier', TValue.From<string>('abstract'));
      AParser.Consume();
    end
    else if AParser.Check('keyword.sealed') then
    begin
      LNode.SetAttr('class.modifier', TValue.From<string>('sealed'));
      AParser.Consume();
    end;

    // Inheritance list: (TBase, IInterface1, IInterface2)
    if AParser.Match('delimiter.lparen') then
    begin
      LName := AParser.CurrentToken().Text;
      AParser.Consume();
      while AParser.Check('delimiter.dot') do
      begin
        AParser.Consume();
        LName := LName + '.' + AParser.CurrentToken().Text;
        AParser.Consume();
      end;
      LNode.SetAttr('class.parent', TValue.From<string>(LName));

      while AParser.Match('delimiter.comma') do
      begin
        // Additional ancestors (interfaces) — store as children
        LNode.AddChild(ParseTypeReference(AParser));
      end;
      AParser.Expect('delimiter.rparen');
    end;

    // Parse class body: visibility sections, fields, methods, properties
    while not AParser.Check('keyword.end') and
          not AParser.Check(KIND_EOF) do
    begin
      if AParser.Check('keyword.private') or
         AParser.Check('keyword.protected') or
         AParser.Check('keyword.public') or
         AParser.Check('keyword.published') or
         AParser.Check('keyword.strict') then
      begin
        // Strict private/protected
        if AParser.Check('keyword.strict') then
        begin
          // Save 'strict' token text before consuming
          LSrictKW := AParser.CurrentToken().Text;
          AParser.Consume();  // consume 'strict'
          LNode.AddChild(AParser.CreateNode('stmt.visibility',
            AParser.CurrentToken()));
          // Node token is now the visibility keyword (private/protected)
          TASTNode(LNode.GetChild(LNode.ChildCount() - 1)).SetAttr(
            'kw.strict', TValue.From<string>(LSrictKW));
          TASTNode(LNode.GetChild(LNode.ChildCount() - 1)).SetAttr(
            'visibility.strict', TValue.From<Boolean>(True));
          AParser.Consume();  // consume visibility keyword
        end
        else
        begin
          LNode.AddChild(AParser.CreateNode('stmt.visibility',
            AParser.CurrentToken()));
          AParser.Consume();
        end;
      end
      else if AParser.Check('keyword.procedure') or
              AParser.Check('keyword.function') or
              AParser.Check('keyword.constructor') or
              AParser.Check('keyword.destructor') or
              AParser.Check('keyword.class') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end
      else if AParser.Check('literal.directive') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end
      else if AParser.Check('keyword.property') then
      begin
        LNode.AddChild(ParsePropertyDecl(AParser));
      end
      // Field declarations: anything else must be a field name
      else
        LNode.AddChild(ParseFieldDecl(AParser));
    end;
    LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
    AParser.Expect('keyword.end');
    Result := LNode;
    Exit;
  end;

  // Interface type: interface [(IParent)] [GUID] methods end
  if AParser.Check('keyword.interface') then
  begin
    LNode := AParser.CreateNode('type_ref.interface_type', AParser.CurrentToken());
    AParser.Consume();  // consume 'interface'

    // Forward declaration: IFoo = interface;
    if AParser.Check('delimiter.semicolon') then
    begin
      LNode.SetAttr('intf.forward', TValue.From<Boolean>(True));
      Result := LNode;
      Exit;
    end;

    // Parent interface: (IParent)
    if AParser.Match('delimiter.lparen') then
    begin
      LName := AParser.CurrentToken().Text;
      AParser.Consume();
      while AParser.Check('delimiter.dot') do
      begin
        AParser.Consume();
        LName := LName + '.' + AParser.CurrentToken().Text;
        AParser.Consume();
      end;
      LNode.SetAttr('intf.parent', TValue.From<string>(LName));
      AParser.Expect('delimiter.rparen');
    end;

    // Optional GUID: ['{...}']
    if AParser.Check('delimiter.lbracket') then
    begin
      AParser.Consume();
      LNode.SetAttr('intf.guid',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      AParser.Expect('delimiter.rbracket');
    end;

    // Interface members: methods and properties
    while not AParser.Check('keyword.end') and
          not AParser.Check(KIND_EOF) do
    begin
      if AParser.Check('keyword.procedure') or
         AParser.Check('keyword.function') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end
      else if AParser.Check('keyword.property') then
      begin
        LNode.AddChild(ParsePropertyDecl(AParser));
      end
      else if AParser.Check('literal.directive') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end
      else
      begin
        AParser.Consume();  // skip unknown
      end;
    end;
    LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
    AParser.Expect('keyword.end');
    Result := LNode;
    Exit;
  end;

  // Object type (legacy): object ... end
  if AParser.Check('keyword.object') then
  begin
    LNode := AParser.CreateNode('type_ref.object', AParser.CurrentToken());
    AParser.Consume();  // consume 'object'
    // Parse like record — fields and methods until end
    while not AParser.Check('keyword.end') and
          not AParser.Check(KIND_EOF) do
    begin
      if AParser.Check('keyword.procedure') or
         AParser.Check('keyword.function') or
         AParser.Check('keyword.constructor') or
         AParser.Check('keyword.destructor') then
        LNode.AddChild(TASTNode(AParser.ParseStatement()))
      // Field declarations: anything else must be a field name
      else
        LNode.AddChild(ParseFieldDecl(AParser));
    end;
    LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
    AParser.Expect('keyword.end');
    Result := LNode;
    Exit;
  end;

  // Default: qualified identifier with optional generic parameters
  // Handles: Integer, TObject, System.SysUtils.TObject, TList<Integer>
  LNode := AParser.CreateNode('type_ref.name', AParser.CurrentToken());
  LName := AParser.CurrentToken().Text;
  AParser.Consume();  // consume first identifier/keyword

  // Qualified name: consume .Ident chains
  while AParser.Check('delimiter.dot') do
  begin
    AParser.Consume();  // consume '.'
    LName := LName + '.' + AParser.CurrentToken().Text;
    AParser.Consume();  // consume next part
  end;

  LNode.SetAttr('type.name', TValue.From<string>(LName));

  // Generic parameters: <T1, T2>
  // We use op.lt for '<' — only consume as generic open when in type-ref context
  if AParser.Check('op.lt') then
  begin
    AParser.Consume();  // consume '<'
    LNode.SetAttr('type.generic', TValue.From<Boolean>(True));
    LNode.AddChild(ParseTypeReference(AParser));
    while AParser.Match('delimiter.comma') do
      LNode.AddChild(ParseTypeReference(AParser));
    AParser.Expect('op.gt');
  end;

  Result := LNode;
end;

// =============================================================================
//  Helper: ParseParamList
// =============================================================================
//
//  Parses a parenthesised parameter list: (const A, B: Integer; var C: string)
//  Returns a stmt.param_list node containing stmt.param_group children.
//  Each param_group preserves the original grouping of names sharing a
//  modifier and type, which is essential for correct formatting.
//
//  Expects the opening '(' to be the current token. Consumes through ')'.
// =============================================================================

function ParseParamList(const AParser: TParserBase): TASTNode;
var
  LListNode:  TASTNode;
  LGroupNode: TASTNode;
  LModifier:  string;
  LNames:     string;
  LNameCount: Integer;
begin
  LListNode := AParser.CreateNode('stmt.param_list', AParser.CurrentToken());
  AParser.Consume();  // consume '('

  while not AParser.Check('delimiter.rparen') and
        not AParser.Check(KIND_EOF) do
  begin
    LGroupNode := AParser.CreateNode('stmt.param_group', AParser.CurrentToken());

    // Optional modifier: const, var, out
    LModifier := '';
    if AParser.Match('keyword.const') then
      LModifier := 'const'
    else if AParser.Match('keyword.var') then
      LModifier := 'var'
    else if AParser.Match('keyword.out') then
      LModifier := 'out';

    LGroupNode.SetAttr('param.modifier', TValue.From<string>(LModifier));

    // Collect comma-separated parameter names
    LNames := AParser.CurrentToken().Text;
    LNameCount := 1;
    AParser.Consume();  // consume first name

    while AParser.Match('delimiter.comma') do
    begin
      LNames := LNames + ',' + AParser.CurrentToken().Text;
      Inc(LNameCount);
      AParser.Consume();  // consume next name
    end;

    LGroupNode.SetAttr('param.names', TValue.From<string>(LNames));
    LGroupNode.SetAttr('param.name_count', TValue.From<Integer>(LNameCount));

    // Colon + type reference
    if AParser.Match('delimiter.colon') then
      LGroupNode.AddChild(ParseTypeReference(AParser));

    // Optional default value: = expr
    if AParser.Match('op.eq') then
      LGroupNode.AddChild(TASTNode(AParser.ParseExpression(0)));

    LListNode.AddChild(LGroupNode);

    // Parameter groups are separated by semicolons
    if not AParser.Check('delimiter.rparen') then
      AParser.Expect('delimiter.semicolon');
  end;

  AParser.Expect('delimiter.rparen');
  Result := LListNode;
end;

// =============================================================================
//  Helper: ParseRoutineDirectives
// =============================================================================
//
//  After a routine signature's terminating semicolon, parses trailing
//  directives (virtual; override; stdcall; etc.) and attaches them to
//  the given routine node as stmt.directive children.
//
//  Each directive is consumed along with its trailing semicolon.
//  Some directives take arguments (external 'lib' name 'func',
//  message WM_FOO, deprecated 'text').
// =============================================================================

procedure ParseRoutineDirectives(const AParser: TParserBase;
  const ANode: TASTNode);
var
  LDirNode: TASTNode;
begin
  while IsRoutineDirective(AParser) do
  begin
    LDirNode := AParser.CreateNode('stmt.routine_directive', AParser.CurrentToken());
    LDirNode.SetAttr('directive.text',
      TValue.From<string>(AParser.CurrentToken().Text));

    // External directive can have: external 'lib' [name 'func']
    if AParser.Check('keyword.external') then
    begin
      AParser.Consume();
      // Optional library name (string literal or identifier)
      if AParser.Check(KIND_STRING) or
         AParser.Check(KIND_IDENTIFIER) then
      begin
        LDirNode.SetAttr('directive.lib',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
      end;
      // Optional 'name' specifier
      if AParser.Match('keyword.name') then
      begin
        LDirNode.SetAttr('directive.ext_name',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
      end;
      // Optional 'delayed'
      AParser.Match('keyword.delayed');
    end
    // Message directive takes an argument: message WM_PAINT
    else if AParser.Check('keyword.message') then
    begin
      AParser.Consume();
      LDirNode.AddChild(TASTNode(AParser.ParseExpression(0)));
    end
    // Deprecated can take an optional string: deprecated 'Use NewProc'
    else if AParser.Check('keyword.deprecated') then
    begin
      AParser.Consume();
      if AParser.Check(KIND_STRING) then
      begin
        LDirNode.SetAttr('directive.msg',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
      end;
    end
    // Dispid takes an integer argument
    else if AParser.Check('keyword.dispid') then
    begin
      AParser.Consume();
      LDirNode.AddChild(TASTNode(AParser.ParseExpression(0)));
    end
    else
      AParser.Consume();  // consume the simple directive keyword

    ANode.AddChild(LDirNode);
    AParser.Match('delimiter.semicolon');
  end;
end;

// =============================================================================
//  Helper: ParseUsesClause
// =============================================================================
//
//  Parses: uses UnitA, UnitB in 'path', UnitC;
//  Returns a stmt.uses_clause node with stmt.uses_item children.
//  Expects 'uses' has already been consumed by the caller.
// =============================================================================

function ParseUsesClause(const AParser: TParserBase; const AUsesKW: string): TASTNode;
var
  LNode:     TASTNode;
  LItemNode: TASTNode;
  LName:     string;
begin
  LNode := AParser.CreateNode('stmt.uses_clause', AParser.CurrentToken());
  LNode.SetAttr('kw.uses', TValue.From<string>(AUsesKW));
  repeat
    LItemNode := AParser.CreateNode('stmt.uses_item', AParser.CurrentToken());
    // Unit name may be dotted: System.SysUtils
    LName := AParser.CurrentToken().Text;
    AParser.Consume();  // consume first part of name

    // Qualified unit name: System.SysUtils
    while AParser.Check('delimiter.dot') do
    begin
      AParser.Consume();  // consume '.'
      LName := LName + '.' + AParser.CurrentToken().Text;
      AParser.Consume();  // consume next part
    end;

    LItemNode.SetAttr('decl.name', TValue.From<string>(LName));

    // Optional 'in' clause: uses MyUnit in 'path\MyUnit.pas'
    if AParser.Check('keyword.in') then
    begin
      LItemNode.SetAttr('kw.in', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume 'in'
      LItemNode.SetAttr('uses.path',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume the path string
    end;

    LNode.AddChild(LItemNode);
  until not AParser.Match('delimiter.comma');
  AParser.Expect('delimiter.semicolon');
  Result := LNode;
end;

// =============================================================================
//  Helper: ParseRoutineSignature
// =============================================================================
//
//  Parses a routine signature (name, params, return type) after the
//  keyword (procedure/function/constructor/destructor) has been consumed.
//  Sets attrs on the returned node: decl.name, optional decl.return_type.
//  Adds param_list as child if params exist.
//
//  Handles qualified names: TMyClass.DoSomething
// =============================================================================

function ParseRoutineSignature(const AParser: TParserBase;
  const AIsFunction: Boolean; const ANodeKind: string): TASTNode;
var
  LNode:      TASTNode;
  LName:      string;
begin
  LNode := AParser.CreateNode(ANodeKind, AParser.CurrentToken());

  // Routine name, possibly qualified: TMyClass.Method or TMyClass<T>.Method
  LName := AParser.CurrentToken().Text;
  AParser.Consume();

  // Handle dotted qualification
  while AParser.Check('delimiter.dot') do
  begin
    AParser.Consume();
    LName := LName + '.' + AParser.CurrentToken().Text;
    AParser.Consume();
  end;

  // Handle generic suffix on class name: TMyClass<T>.Method
  // (the <T> part after class name in implementation)
  if AParser.Check('op.lt') then
  begin
    LName := LName + '<';
    AParser.Consume();
    LName := LName + AParser.CurrentToken().Text;
    AParser.Consume();
    while AParser.Match('delimiter.comma') do
    begin
      LName := LName + ',' + AParser.CurrentToken().Text;
      AParser.Consume();
    end;
    AParser.Expect('op.gt');
    LName := LName + '>';
    // May be followed by .Method
    while AParser.Check('delimiter.dot') do
    begin
      AParser.Consume();
      LName := LName + '.' + AParser.CurrentToken().Text;
      AParser.Consume();
    end;
  end;

  LNode.SetAttr('decl.name', TValue.From<string>(LName));

  // Optional parameter list
  if AParser.Check('delimiter.lparen') then
    LNode.AddChild(ParseParamList(AParser));

  // Return type for functions
  if AIsFunction then
  begin
    AParser.Expect('delimiter.colon');
    LNode.AddChild(ParseTypeReference(AParser));
  end;

  Result := LNode;
end;

// =============================================================================
//  Helper: ParseRoutineBody
// =============================================================================
//
//  After a routine signature and directives, parses the optional body:
//  local var/const/type/label blocks followed by begin..end.
//  Adds all children to ANode.
// =============================================================================

procedure ParseRoutineBody(const AParser: TParserBase;
  const ANode: TASTNode);
begin
  // Local declarations before begin
  while AParser.Check('keyword.var') or
        AParser.Check('keyword.const') or
        AParser.Check('keyword.type') or
        AParser.Check('keyword.label') or
        AParser.Check('keyword.threadvar') or
        AParser.Check('literal.directive') do
    ANode.AddChild(TASTNode(AParser.ParseStatement()));

  // Body: begin..end or asm..end
  if AParser.Check('keyword.begin') or AParser.Check('keyword.asm') then
    ANode.AddChild(TASTNode(AParser.ParseStatement()));
end;

// =============================================================================
//  Helper: ParseFieldDecl
// =============================================================================
//
//  Parses a record/class field declaration: Name1, Name2: Type;
//  Returns a stmt.field_decl node.
// =============================================================================

function ParseFieldDecl(const AParser: TParserBase): TASTNode;
var
  LNode:  TASTNode;
  LNames: string;
  LCount: Integer;
begin
  LNode := AParser.CreateNode('stmt.field_decl', AParser.CurrentToken());
  LNames := AParser.CurrentToken().Text;
  LCount := 1;
  AParser.Consume();

  while AParser.Match('delimiter.comma') do
  begin
    LNames := LNames + ',' + AParser.CurrentToken().Text;
    Inc(LCount);
    AParser.Consume();
  end;

  LNode.SetAttr('field.names', TValue.From<string>(LNames));
  LNode.SetAttr('field.name_count', TValue.From<Integer>(LCount));

  AParser.Expect('delimiter.colon');
  LNode.AddChild(ParseTypeReference(AParser));
  AParser.Match('delimiter.semicolon');
  Result := LNode;
end;

// =============================================================================
//  Helper: ParsePropertyDecl
// =============================================================================
//
//  Parses a property declaration:
//    property Name: Type read GetName write SetName [default Value];
//    property Items[Index: Integer]: string read GetItem write SetItem; default;
//  Returns a stmt.property_decl node with raw specifier text.
// =============================================================================

function ParsePropertyDecl(const AParser: TParserBase): TASTNode;
var
  LNode:     TASTNode;
  LPropName: string;
begin
  LNode := AParser.CreateNode('stmt.property_decl', AParser.CurrentToken());
  AParser.Consume();  // consume 'property'

  LPropName := AParser.CurrentToken().Text;
  AParser.Consume();
  LNode.SetAttr('prop.name', TValue.From<string>(LPropName));

  // Optional array property index: [Index: Type]
  if AParser.Check('delimiter.lbracket') then
  begin
    LNode.SetAttr('prop.indexed', TValue.From<Boolean>(True));
    LNode.AddChild(ParseParamList_Bracket(AParser));
  end;

  // Optional colon + type (not present on redeclared/override properties)
  if AParser.Match('delimiter.colon') then
    LNode.AddChild(ParseTypeReference(AParser));

  // Property specifiers: read, write, stored, default, nodefault, implements
  while not AParser.Check('delimiter.semicolon') and
        not AParser.Check(KIND_EOF) do
  begin
    if AParser.Check('keyword.read') or
       AParser.Check('keyword.write') then
    begin
      // Store '1' (not '') so the emitter's <> '' presence check works
      // Store actual token text (preserves original casing for capAsIs)
      LNode.SetAttr('prop.' + LowerCase(AParser.CurrentToken().Text),
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      // Store the specifier value as a child expression
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
    end
    else
    begin
      // Other specifiers: stored, default, nodefault, implements, dispid
      // Just consume them with their values
      AParser.Consume();
    end;
  end;

  AParser.Match('delimiter.semicolon');

  // Check for 'default;' after semicolon (array property default marker)
  if AParser.Check('keyword.default') then
  begin
    LNode.SetAttr('prop.is_default', TValue.From<Boolean>(True));
    AParser.Consume();
    AParser.Match('delimiter.semicolon');
  end;

  Result := LNode;
end;

// =============================================================================
//  Helper: ParseParamList_Bracket  (for array property indices)
// =============================================================================
//
//  Like ParseParamList but uses [ ] instead of ( ).
// =============================================================================

function ParseParamList_Bracket(const AParser: TParserBase): TASTNode;
var
  LListNode:  TASTNode;
  LGroupNode: TASTNode;
  LModifier:  string;
  LNames:     string;
begin
  LListNode := AParser.CreateNode('stmt.param_list', AParser.CurrentToken());
  AParser.Consume();  // consume '['

  while not AParser.Check('delimiter.rbracket') and
        not AParser.Check(KIND_EOF) do
  begin
    LGroupNode := AParser.CreateNode('stmt.param_group', AParser.CurrentToken());

    LModifier := '';
    if AParser.Match('keyword.const') then
      LModifier := 'const'
    else if AParser.Match('keyword.var') then
      LModifier := 'var';

    LGroupNode.SetAttr('param.modifier', TValue.From<string>(LModifier));

    LNames := AParser.CurrentToken().Text;
    AParser.Consume();

    while AParser.Match('delimiter.comma') do
    begin
      LNames := LNames + ',' + AParser.CurrentToken().Text;
      AParser.Consume();
    end;

    LGroupNode.SetAttr('param.names', TValue.From<string>(LNames));

    if AParser.Match('delimiter.colon') then
      LGroupNode.AddChild(ParseTypeReference(AParser));

    LListNode.AddChild(LGroupNode);

    if not AParser.Check('delimiter.rbracket') then
      AParser.Expect('delimiter.semicolon');
  end;

  AParser.Expect('delimiter.rbracket');
  Result := LListNode;
end;

// =============================================================================
//  Helper: ParseRecordCase  (variant record part)
// =============================================================================
//
//  Parses: case [TagName:] TagType of
//            Value1: (fields);
//            Value2: (fields);
//          end  (optional, some records close with outer end)
// =============================================================================

function ParseRecordCase(const AParser: TParserBase): TASTNode;
var
  LNode:    TASTNode;
  LVarNode: TASTNode;
  LTagName: string;
begin
  LNode := AParser.CreateNode('stmt.record_case', AParser.CurrentToken());
  AParser.Consume();  // consume 'case'

  // Tag: either "TagName: Type" or just "Type"
  LTagName := AParser.CurrentToken().Text;
  AParser.Consume();

  if AParser.Match('delimiter.colon') then
  begin
    LNode.SetAttr('case.tag_name', TValue.From<string>(LTagName));
    LNode.AddChild(ParseTypeReference(AParser));
  end
  else
    LNode.SetAttr('case.tag_type', TValue.From<string>(LTagName));

  AParser.Expect('keyword.of');

  // Variant arms: Value: (field1: Type1; field2: Type2);
  while not AParser.Check('keyword.end') and
        not AParser.Check(KIND_EOF) do
  begin
    LVarNode := AParser.CreateNode('stmt.record_variant', AParser.CurrentToken());
    // Label(s)
    LVarNode.AddChild(TASTNode(AParser.ParseExpression(0)));
    while AParser.Match('delimiter.comma') do
      LVarNode.AddChild(TASTNode(AParser.ParseExpression(0)));
    AParser.Expect('delimiter.colon');
    // Fields in parens
    AParser.Expect('delimiter.lparen');
    while not AParser.Check('delimiter.rparen') and
          not AParser.Check(KIND_EOF) do
    begin
      if AParser.Check(KIND_IDENTIFIER) then
        LVarNode.AddChild(ParseFieldDecl(AParser))
      else if AParser.Check('keyword.case') then
        LVarNode.AddChild(ParseRecordCase(AParser))
      else
        AParser.Consume();
    end;
    AParser.Expect('delimiter.rparen');
    AParser.Match('delimiter.semicolon');
    LNode.AddChild(LVarNode);
  end;

  // The 'end' is consumed by the outer record parser
  Result := LNode;
end;

// =========================================================================
//  PREFIX EXPRESSION HANDLERS
// =========================================================================

// --- Standard literal prefixes (identifier, integer, real, string) ---

procedure RegisterLiteralPrefixes(const AParse: TMetamorf);
begin
  AParse.Config().RegisterLiteralPrefixes();
end;

// --- Nil literal ---

procedure RegisterNilLiteral(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('keyword.nil', 'expr.nil',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

// --- Boolean literals: true, false ---

procedure RegisterBooleanLiterals(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('keyword.true', 'expr.bool',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);

  AParse.Config().RegisterPrefix('keyword.false', 'expr.bool',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      Result := LNode;
    end);
end;

// --- Unary operators: not, -, + ---

procedure RegisterUnaryOps(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('keyword.not', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('not'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(50)));
      Result := LNode;
    end);

  AParse.Config().RegisterPrefix('op.minus', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('-'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(50)));
      Result := LNode;
    end);

  AParse.Config().RegisterPrefix('op.plus', 'expr.unary',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>('+'));
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(50)));
      Result := LNode;
    end);
end;

// --- Grouped expression: (expr) ---

procedure RegisterGroupedExpr(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('delimiter.lparen', 'expr.grouped',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume '('
      LNode := AParser.CreateNode('expr.grouped');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rparen');
      Result := LNode;
    end);
end;

// --- Address-of: @expr ---

procedure RegisterAddrOf(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('op.addr', 'expr.addr',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      Result := LNode;
    end);
end;

// --- Char literal: #65, #$0D ---

procedure RegisterCharLiteral(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('op.hash', 'expr.char_literal',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume '#'
      // Next token is the ordinal value (integer or hex literal)
      LNode.SetAttr('char.ordinal',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      Result := LNode;
    end);
end;

// --- Set literal: [a, b, c..d] ---

procedure RegisterSetLiteral(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('delimiter.lbracket', 'expr.set_literal',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume '['
      if not AParser.Check('delimiter.rbracket') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        while AParser.Match('delimiter.comma') do
          LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      end;
      AParser.Expect('delimiter.rbracket');
      Result := LNode;
    end);
end;

// --- Inherited expression: inherited or inherited Name(args) ---

procedure RegisterInheritedExpr(const AParse: TMetamorf);
begin
  AParse.Config().RegisterPrefix('keyword.inherited', 'expr.inherited',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'inherited'
      // If followed by an identifier, it names a specific ancestor method
      if AParser.Check(KIND_IDENTIFIER) then
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      // bare 'inherited;' calls the matching ancestor method with same args
      Result := LNode;
    end);
end;

// =========================================================================
//  INFIX EXPRESSION HANDLERS
// =========================================================================

// --- Assignment: := ---

procedure RegisterAssignment(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixRight('op.assign', 2, 'expr.assign',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('op', TValue.From<string>(':='));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPowerRight())));
      Result := LNode;
    end);
end;

// --- Arithmetic: + - * / ---

procedure RegisterArithmeticOps(const AParse: TMetamorf);
begin
  AParse.Config().RegisterBinaryOp('op.plus',     20, '+');
  AParse.Config().RegisterBinaryOp('op.minus',    20, '-');
  AParse.Config().RegisterBinaryOp('op.multiply', 30, '*');
  AParse.Config().RegisterBinaryOp('op.divide',   30, '/');

  // div (power 30)
  AParse.Config().RegisterInfixLeft('keyword.div', 30, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('div'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  // mod (power 30)
  AParse.Config().RegisterInfixLeft('keyword.mod', 30, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('mod'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

// --- Comparison: = <> < > <= >= ---

procedure RegisterComparisonOps(const AParse: TMetamorf);
begin
  AParse.Config().RegisterBinaryOp('op.eq',  10, '=');
  AParse.Config().RegisterBinaryOp('op.neq', 10, '<>');
  // op.lt is registered as a custom infix handler (not a simple binary op)
  // so that it can distinguish generic specialisation from less-than comparison.
  // e.g.  TList<STRING>.Create()  vs  X < Y
  AParse.Config().RegisterInfixLeft('op.lt', 10, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LOffset:    Integer;
      LTok:       TToken;
      LIsGeneric: Boolean;
      LGenNode:   TASTNode;
      LTypeArg:   TASTNode;
    begin
      // Heuristic: treat as generic open bracket when:
      //   1. Left is an identifier leaf
      //   2. Lookahead finds <ident[,ident]*> followed by '.' or '('
      LIsGeneric := False;
      if TASTNode(ALeft).GetNodeKind() = 'expr.ident' then
      begin
        // Scan ahead to check the pattern without consuming
        LOffset := 1;  // offset 0 is current '<' already being dispatched
        LTok    := AParser.PeekToken(LOffset);
        // Expect at least one identifier or keyword type name (e.g. STRING, INTEGER)
        if (LTok.Kind = KIND_IDENTIFIER) or
           LTok.Kind.StartsWith('keyword.') then
        begin
          Inc(LOffset);
          LTok := AParser.PeekToken(LOffset);
          // Skip over comma-separated additional type args
          while LTok.Kind = 'delimiter.comma' do
          begin
            Inc(LOffset);
            LTok := AParser.PeekToken(LOffset);
            if (LTok.Kind = KIND_IDENTIFIER) or
               LTok.Kind.StartsWith('keyword.') then
              Inc(LOffset)
            else
            begin
              LOffset := 0;  // signal: not a valid generic pattern
              Break;
            end;
            LTok := AParser.PeekToken(LOffset);
          end;
          // Now we should be at '>'
          if (LOffset > 0) and (LTok.Kind = 'op.gt') then
          begin
            // Check that after '>' comes '.' or '('
            LTok := AParser.PeekToken(LOffset + 1);
            if (LTok.Kind = 'delimiter.dot') or
               (LTok.Kind = 'delimiter.lparen') then
              LIsGeneric := True;
          end;
        end;
      end;

      if LIsGeneric then
      begin
        // Build expr.generic_inst node: left child = base name, remaining
        // children = type argument identifier/keyword leaves.
        // We consume type arg tokens directly rather than calling
        // ParseExpression, because keywords like STRING, INTEGER have no
        // prefix expression handler and would return nil.
        LGenNode := AParser.CreateNode('expr.generic_inst', ALeft.GetToken());
        LGenNode.AddChild(TASTNode(ALeft));
        AParser.Consume();  // consume '<'
        // Consume first type argument as a leaf node
        LTypeArg := AParser.CreateNode(AParser.CurrentToken().Kind,
          AParser.CurrentToken());
        AParser.Consume();
        LGenNode.AddChild(LTypeArg);
        while AParser.Match('delimiter.comma') do
        begin
          LTypeArg := AParser.CreateNode(AParser.CurrentToken().Kind,
            AParser.CurrentToken());
          AParser.Consume();
          LGenNode.AddChild(LTypeArg);
        end;
        AParser.Expect('op.gt');  // consume '>'
        Result := LGenNode;
      end
      else
      begin
        // Plain less-than comparison
        AParser.Consume();  // consume '<'
        LNode := AParser.CreateNode('expr.binary', ALeft.GetToken());
        LNode.SetAttr('op', TValue.From<string>('<'));
        LNode.AddChild(TASTNode(ALeft));
        LNode.AddChild(TASTNode(AParser.ParseExpression(10)));
        Result := LNode;
      end;
    end);
  AParse.Config().RegisterBinaryOp('op.gt',  10, '>');
  AParse.Config().RegisterBinaryOp('op.lte', 10, '<=');
  AParse.Config().RegisterBinaryOp('op.gte', 10, '>=');
end;

// --- Logical: and, or, xor ---

procedure RegisterLogicalOps(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixLeft('keyword.and', 8, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('and'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  AParse.Config().RegisterInfixLeft('keyword.or', 6, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('or'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  AParse.Config().RegisterInfixLeft('keyword.xor', 8, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('xor'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

// --- Bitwise shift: shl, shr ---

procedure RegisterBitwiseShiftOps(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixLeft('keyword.shl', 25, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('shl'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  AParse.Config().RegisterInfixLeft('keyword.shr', 25, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('shr'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

// --- Type-testing operators: in, is, as ---

procedure RegisterTypeTestOps(const AParse: TMetamorf);
begin
  // in (set membership, power 10)
  AParse.Config().RegisterInfixLeft('keyword.in', 10, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('in'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  // is (type test, power 10)
  AParse.Config().RegisterInfixLeft('keyword.is', 10, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('is'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);

  // as (type cast, power 10)
  AParse.Config().RegisterInfixLeft('keyword.as', 10, 'expr.binary',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.binary', AParser.CurrentToken());
      LNode.SetAttr('op', TValue.From<string>('as'));
      AParser.Consume();
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

// --- Function/procedure call: ident(args) ---
//
//  Also handles Delphi write/writeln format specifiers: expr:width[:decimals]
//  These appear only inside argument lists and are attached as expr.fmt_arg
//  nodes with 'fmt.width' and 'fmt.decimals' attributes so the emitter can
//  reconstruct them verbatim.

procedure RegisterCallExpr(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixLeft('delimiter.lparen', 40, 'expr.call',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode:    TASTNode;
      LArgNode: TASTNode;
      LFmtNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.call', ALeft.GetToken());
      AParser.Consume();  // consume '('
      LNode.AddChild(TASTNode(ALeft));  // callee as first child

      if not AParser.Check('delimiter.rparen') then
      begin
        LArgNode := TASTNode(AParser.ParseExpression(0));
        // Check for format specifier: expr:width[:decimals]
        if AParser.Check('delimiter.colon') and
           (AParser.PeekToken(1).Kind = KIND_INTEGER) then
        begin
          LFmtNode := AParser.CreateNode('expr.fmt_arg', LArgNode.GetToken());
          LFmtNode.AddChild(LArgNode);
          AParser.Consume();  // consume first ':'
          LFmtNode.SetAttr('fmt.width',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();  // consume width
          if AParser.Check('delimiter.colon') and
             (AParser.PeekToken(1).Kind = KIND_INTEGER) then
          begin
            AParser.Consume();  // consume second ':'
            LFmtNode.SetAttr('fmt.decimals',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();  // consume decimals
          end;
          LNode.AddChild(LFmtNode);
        end
        else
          LNode.AddChild(LArgNode);

        while AParser.Match('delimiter.comma') do
        begin
          LArgNode := TASTNode(AParser.ParseExpression(0));
          if AParser.Check('delimiter.colon') and
             (AParser.PeekToken(1).Kind = KIND_INTEGER) then
          begin
            LFmtNode := AParser.CreateNode('expr.fmt_arg', LArgNode.GetToken());
            LFmtNode.AddChild(LArgNode);
            AParser.Consume();  // consume first ':'
            LFmtNode.SetAttr('fmt.width',
              TValue.From<string>(AParser.CurrentToken().Text));
            AParser.Consume();  // consume width
            if AParser.Check('delimiter.colon') and
               (AParser.PeekToken(1).Kind = KIND_INTEGER) then
            begin
              AParser.Consume();  // consume second ':'
              LFmtNode.SetAttr('fmt.decimals',
                TValue.From<string>(AParser.CurrentToken().Text));
              AParser.Consume();  // consume decimals
            end;
            LNode.AddChild(LFmtNode);
          end
          else
            LNode.AddChild(LArgNode);
        end;
      end;

      AParser.Expect('delimiter.rparen');
      Result := LNode;
    end);
end;

// --- Array index: arr[i] ---

procedure RegisterArrayIndex(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixLeft('delimiter.lbracket', 45,
    'expr.array_index',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.array_index', ALeft.GetToken());
      AParser.Consume();  // consume '['
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      while AParser.Match('delimiter.comma') do
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Expect('delimiter.rbracket');
      Result := LNode;
    end);
end;

// --- Field access: rec.field ---

procedure RegisterFieldAccess(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixLeft('delimiter.dot', 45,
    'expr.field_access',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LFieldTok: TToken;
    begin
      AParser.Consume();  // consume '.'
      LFieldTok := AParser.CurrentToken();
      LNode := AParser.CreateNode('expr.field_access', LFieldTok);
      LNode.SetAttr('field.name', TValue.From<string>(LFieldTok.Text));
      LNode.AddChild(TASTNode(ALeft));
      AParser.Consume();  // consume field name
      Result := LNode;
    end);
end;

// --- Pointer dereference: p^ (postfix) ---

procedure RegisterPointerDeref(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixLeft('op.deref', 50, 'expr.deref',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume '^'
      LNode := AParser.CreateNode('expr.deref', ALeft.GetToken());
      LNode.AddChild(TASTNode(ALeft));
      Result := LNode;
    end);
end;

// --- Range operator: a..b (for case labels, subrange types) ---

procedure RegisterRangeOp(const AParse: TMetamorf);
begin
  AParse.Config().RegisterInfixLeft('op.range', 5, 'expr.range',
    function(AParser: TParserBase;
      ALeft: TASTNodeBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode('expr.range', AParser.CurrentToken());
      AParser.Consume();  // consume '..'
      LNode.AddChild(TASTNode(ALeft));
      LNode.AddChild(TASTNode(
        AParser.ParseExpression(AParser.CurrentInfixPower())));
      Result := LNode;
    end);
end;

// =========================================================================
//  STATEMENT HANDLERS
// =========================================================================

// --- Begin..End block ---

procedure RegisterBeginBlock(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.begin', 'stmt.begin_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LChild:     TASTNodeBase;
      LLabelNode: TASTNode;
      LLabelTok:  TToken;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'begin'
      while not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
      begin
        // Inline label marker: identifier followed by ':' (but not ':=')
        // Example: MainLoop:  or  Cleanup:
        if AParser.Check(KIND_IDENTIFIER) and
           (AParser.PeekToken(1).Kind = 'delimiter.colon') then
        begin
          LLabelTok  := AParser.CurrentToken();
          LLabelNode := AParser.CreateNode('stmt.label_mark', LLabelTok);
          LLabelNode.SetAttr('label.name', TValue.From<string>(LLabelTok.Text));
          AParser.Consume();  // consume label identifier
          AParser.Consume();  // consume ':'
          LNode.AddChild(LLabelNode);
          Continue;
        end;

        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LNode.AddChild(TASTNode(LChild));
      end;
      LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.end');
      Result := LNode;
    end);
end;

// --- If/Then/Else ---

procedure RegisterIfStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.if', 'stmt.if',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'if'
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      LNode.SetAttr('kw.then', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.then');
      LNode.AddChild(TASTNode(AParser.ParseStatement()));
      if AParser.Check('keyword.else') then
      begin
        LNode.SetAttr('kw.else', TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
        LNode.AddChild(TASTNode(AParser.ParseStatement()));
      end;
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- While/Do ---

procedure RegisterWhileStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.while', 'stmt.while',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'while'
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      LNode.SetAttr('kw.do', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.do');
      LNode.AddChild(TASTNode(AParser.ParseStatement()));
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- For/To/Downto/Do and For/In/Do ---

procedure RegisterForStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.for', 'stmt.for',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'for'
      LNode.SetAttr('for.var',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume loop variable

      // for..in loop
      if AParser.Check('keyword.in') then
      begin
        LNode.SetAttr('for.kind', TValue.From<string>('in'));
        LNode.SetAttr('kw.in', TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();  // consume 'in'
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));  // collection
      end
      else
      begin
        // Standard for/to/downto
        LNode.SetAttr('for.kind', TValue.From<string>('range'));
        AParser.Expect('op.assign');
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));  // start
        // Store actual token text for capAsIs support
        LNode.SetAttr('for.dir', TValue.From<string>(AParser.CurrentToken().Text));
        if AParser.Check('keyword.to') then
          AParser.Consume()
        else
          AParser.Expect('keyword.downto');
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));  // end
      end;

      LNode.SetAttr('kw.do', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.do');
      LNode.AddChild(TASTNode(AParser.ParseStatement()));
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Repeat/Until ---

procedure RegisterRepeatStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.repeat', 'stmt.repeat',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:  TASTNode;
      LChild: TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'repeat'
      while not AParser.Check('keyword.until') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LNode.AddChild(TASTNode(LChild));
      end;
      LNode.SetAttr('kw.until', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.until');
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Case/Of/End ---

procedure RegisterCaseStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.case', 'stmt.case',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:       TASTNode;
      LArmNode:    TASTNode;
      LElseNode:   TASTNode;
      LLabelCount: Integer;
      LChild:      TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'case'
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      LNode.SetAttr('kw.of', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.of');

      // Parse case arms
      while not AParser.Check('keyword.else') and
            not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
      begin
        LArmNode := AParser.CreateNode('stmt.case_arm', AParser.CurrentToken());
        LLabelCount := 0;
        // Parse labels: expr { ',' expr } ':'
        LArmNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        Inc(LLabelCount);
        while AParser.Match('delimiter.comma') do
        begin
          LArmNode.AddChild(TASTNode(AParser.ParseExpression(0)));
          Inc(LLabelCount);
        end;
        AParser.Expect('delimiter.colon');
        LArmNode.SetAttr('case.label_count',
          TValue.From<Integer>(LLabelCount));
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LArmNode.AddChild(TASTNode(LChild));
        AParser.Match('delimiter.semicolon');
        LNode.AddChild(LArmNode);
      end;

      // Optional else - create node BEFORE consuming so token = 'else'
      if AParser.Check('keyword.else') then
      begin
        LElseNode := AParser.CreateNode('stmt.case_else', AParser.CurrentToken());
        AParser.Consume();  // consume 'else'
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LElseNode.AddChild(TASTNode(LChild));
          AParser.Match('delimiter.semicolon');
        end;
        LNode.AddChild(LElseNode);
      end;

      LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- With/Do ---

procedure RegisterWithStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.with', 'stmt.with',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'with'
      // Expression list: with A, B, C do
      LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      while AParser.Match('delimiter.comma') do
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
      LNode.SetAttr('kw.do', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.do');
      LNode.AddChild(TASTNode(AParser.ParseStatement()));
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Try/Except/Finally/End ---

procedure RegisterTryStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.try', 'stmt.try',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:        TASTNode;
      LTryBody:     TASTNode;
      LExceptBody:  TASTNode;
      LFinallyBody: TASTNode;
      LChild:       TASTNodeBase;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'try'

      // Try body
      LTryBody := AParser.CreateNode('stmt.try_body', AParser.CurrentToken());
      while not AParser.Check('keyword.except') and
            not AParser.Check('keyword.finally') and
            not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
      begin
        LChild := AParser.ParseStatement();
        if LChild <> nil then
          LTryBody.AddChild(TASTNode(LChild));
      end;
      LNode.AddChild(LTryBody);

      // Except block - create node BEFORE consuming so token = 'except'
      if AParser.Check('keyword.except') then
      begin
        LExceptBody := AParser.CreateNode('stmt.except_body',
          AParser.CurrentToken());
        AParser.Consume();  // consume 'except'
        while not AParser.Check('keyword.finally') and
              not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LExceptBody.AddChild(TASTNode(LChild));
        end;
        LNode.AddChild(LExceptBody);
      end;

      // Finally block - create node BEFORE consuming so token = 'finally'
      if AParser.Check('keyword.finally') then
      begin
        LFinallyBody := AParser.CreateNode('stmt.finally_body',
          AParser.CurrentToken());
        AParser.Consume();  // consume 'finally'
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LChild := AParser.ParseStatement();
          if LChild <> nil then
            LFinallyBody.AddChild(TASTNode(LChild));
        end;
        LNode.AddChild(LFinallyBody);
      end;

      LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- On E: ExceptionType do (inside except blocks) ---

procedure RegisterOnStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.on', 'stmt.on',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:    TASTNode;
      LVarName: string;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'on'
      // on [VarName :] ExceptionType do Statement
      LVarName := AParser.CurrentToken().Text;
      AParser.Consume();
      if AParser.Match('delimiter.colon') then
      begin
        LNode.SetAttr('on.var_name', TValue.From<string>(LVarName));
        LNode.AddChild(ParseTypeReference(AParser));
      end
      else
      begin
        // No variable name — what we consumed was the type name
        LNode.SetAttr('on.type_name', TValue.From<string>(LVarName));
      end;
      LNode.SetAttr('kw.do', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.do');
      LNode.AddChild(TASTNode(AParser.ParseStatement()));
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Raise ---

procedure RegisterRaiseStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.raise', 'stmt.raise',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'raise'
      // Optional expression (bare 'raise;' re-raises in except block)
      if not AParser.Check('delimiter.semicolon') and
         not AParser.Check('keyword.end') and
         not AParser.Check(KIND_EOF) then
      begin
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        // Optional 'at' address expression (not a keyword, just an identifier)
        if AParser.Check(KIND_IDENTIFIER) and
           SameText(AParser.CurrentToken().Text, 'at') then
        begin
          AParser.Consume();  // consume 'at'
          LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        end;
      end;
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Exit (with optional value) ---

procedure RegisterExitStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.exit', 'stmt.exit',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'exit'
      if AParser.Match('delimiter.lparen') then
      begin
        LNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        AParser.Expect('delimiter.rparen');
      end;
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Break ---

procedure RegisterBreakStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.break', 'stmt.break',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Continue ---

procedure RegisterContinueStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.continue', 'stmt.continue',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Goto ---

procedure RegisterGotoStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.goto', 'stmt.goto',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'goto'
      LNode.SetAttr('goto.label',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume label
      AParser.Match('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Label declaration ---

procedure RegisterLabelDecl(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.label', 'stmt.label_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'label'
      // One or more label names separated by commas
      LNode.SetAttr('label.name',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      while AParser.Match('delimiter.comma') do
      begin
        // Additional labels — store as children
        AParser.Consume();
      end;
      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

// --- Asm..End block (passthrough — preserve all tokens verbatim) ---

procedure RegisterAsmBlock(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.asm', 'stmt.asm_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'asm'
      // Consume everything until 'end'
      while not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
        AParser.Consume();
      LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.end');
      Result := LNode;
    end);
end;

// =========================================================================
//  DECLARATION HANDLERS
// =========================================================================

// --- Var Block ---

procedure RegisterVarBlock(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.var', 'stmt.var_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LDeclNode: TASTNode;
      LNames:    string;
      LCount:    Integer;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'var'

      // Parse var declarations until a non-identifier is reached
      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LDeclNode := AParser.CreateNode('stmt.var_decl', AParser.CurrentToken());
        LNames := AParser.CurrentToken().Text;
        LCount := 1;
        AParser.Consume();

        while AParser.Match('delimiter.comma') do
        begin
          LNames := LNames + ',' + AParser.CurrentToken().Text;
          Inc(LCount);
          AParser.Consume();
        end;

        LDeclNode.SetAttr('var.names', TValue.From<string>(LNames));
        LDeclNode.SetAttr('var.name_count', TValue.From<Integer>(LCount));

        AParser.Expect('delimiter.colon');
        LDeclNode.AddChild(ParseTypeReference(AParser));

        // Optional initializer: = expr
        if AParser.Match('op.eq') then
          LDeclNode.AddChild(TASTNode(AParser.ParseExpression(0)));

        // Optional absolute directive
        if AParser.Match('keyword.absolute') then
        begin
          LDeclNode.SetAttr('var.absolute',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
        end;

        AParser.Expect('delimiter.semicolon');

        // Optional hint directives after semicolon
        if AParser.Check('keyword.deprecated') or
           AParser.Check('keyword.platform') or
           AParser.Check('keyword.experimental') then
        begin
          AParser.Consume();
          if AParser.Check(KIND_STRING) then
            AParser.Consume();
          AParser.Match('delimiter.semicolon');
        end;

        LNode.AddChild(LDeclNode);
      end;

      Result := LNode;
    end);
end;

// --- Threadvar Block ---

procedure RegisterThreadvarBlock(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.threadvar', 'stmt.threadvar_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LDeclNode: TASTNode;
      LNames:    string;
      LCount:    Integer;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'threadvar'

      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LDeclNode := AParser.CreateNode('stmt.var_decl', AParser.CurrentToken());
        LNames := AParser.CurrentToken().Text;
        LCount := 1;
        AParser.Consume();

        while AParser.Match('delimiter.comma') do
        begin
          LNames := LNames + ',' + AParser.CurrentToken().Text;
          Inc(LCount);
          AParser.Consume();
        end;

        LDeclNode.SetAttr('var.names', TValue.From<string>(LNames));
        LDeclNode.SetAttr('var.name_count', TValue.From<Integer>(LCount));
        AParser.Expect('delimiter.colon');
        LDeclNode.AddChild(ParseTypeReference(AParser));
        AParser.Expect('delimiter.semicolon');
        LNode.AddChild(LDeclNode);
      end;

      Result := LNode;
    end);
end;

// --- Const Block ---

procedure RegisterConstBlock(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.const', 'stmt.const_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:      TASTNode;
      LConstNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'const'

      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LConstNode := AParser.CreateNode('stmt.const_decl', AParser.CurrentToken());
        LConstNode.SetAttr('const.name',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();

        // Optional type annotation: Name : Type = Value
        if AParser.Match('delimiter.colon') then
          LConstNode.AddChild(ParseTypeReference(AParser));

        AParser.Expect('op.eq');
        LConstNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        AParser.Expect('delimiter.semicolon');
        LNode.AddChild(LConstNode);
      end;

      Result := LNode;
    end);
end;

// --- Resourcestring Block ---

procedure RegisterResourcestringBlock(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.resourcestring',
    'stmt.resourcestring_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:    TASTNode;
      LRSNode:  TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'resourcestring'

      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LRSNode := AParser.CreateNode('stmt.resourcestring_decl',
          AParser.CurrentToken());
        LRSNode.SetAttr('rs.name',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
        AParser.Expect('op.eq');
        LRSNode.AddChild(TASTNode(AParser.ParseExpression(0)));
        AParser.Expect('delimiter.semicolon');
        LNode.AddChild(LRSNode);
      end;

      Result := LNode;
    end);
end;

// --- Type Block ---

procedure RegisterTypeBlock(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.type', 'stmt.type_block',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LDeclNode: TASTNode;
      LNameTok:  TToken;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'type'

      while AParser.Check(KIND_IDENTIFIER) do
      begin
        LNameTok := AParser.CurrentToken();
        AParser.Consume();  // consume type name

        // Optional generic params: TMyClass<T>
        // (store raw text for formatter)

        LDeclNode := AParser.CreateNode('stmt.type_decl', LNameTok);
        LDeclNode.SetAttr('decl.name', TValue.From<string>(LNameTok.Text));
        AParser.Expect('op.eq');

        // The type body — delegate to ParseTypeReference which handles
        // all type forms including class, record, interface
        LDeclNode.AddChild(ParseTypeReference(AParser));

        AParser.Expect('delimiter.semicolon');
        // Optional trailing directives on type decl: e.g. TCallback = procedure(...); stdcall;
        while IsRoutineDirective(AParser) do
        begin
          LDeclNode.SetAttr('type.directive', TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
          AParser.Match('delimiter.semicolon');
        end;
        LNode.AddChild(LDeclNode);
      end;

      Result := LNode;
    end);
end;

// =========================================================================
//  ROUTINE DECLARATIONS
// =========================================================================

// --- Procedure declaration ---

procedure RegisterProcDecl(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.procedure', 'stmt.proc_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume 'procedure'
      LNode := ParseRoutineSignature(AParser, False, 'stmt.proc_decl');
      LNode.SetAttr('decl.kind', TValue.From<string>('procedure'));
      AParser.Expect('delimiter.semicolon');

      // Trailing directives
      ParseRoutineDirectives(AParser, LNode);

      // Body — only present if a body-starting token follows.
      // Forward and external routines have no body, so the next token
      // will be something else and this block is simply skipped.
      if AParser.Check('keyword.var') or
         AParser.Check('keyword.const') or
         AParser.Check('keyword.type') or
         AParser.Check('keyword.label') or
         AParser.Check('keyword.threadvar') or
         AParser.Check('keyword.begin') or
         AParser.Check('keyword.asm') or
         AParser.Check('literal.directive') then
      begin
        ParseRoutineBody(AParser, LNode);
        AParser.Expect('delimiter.semicolon');
      end;

      Result := LNode;
    end);
end;

// --- Function declaration ---

procedure RegisterFuncDecl(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.function', 'stmt.func_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume 'function'
      LNode := ParseRoutineSignature(AParser, True, 'stmt.func_decl');
      LNode.SetAttr('decl.kind', TValue.From<string>('function'));
      AParser.Expect('delimiter.semicolon');
      ParseRoutineDirectives(AParser, LNode);

      if AParser.Check('keyword.var') or
         AParser.Check('keyword.const') or
         AParser.Check('keyword.type') or
         AParser.Check('keyword.label') or
         AParser.Check('keyword.threadvar') or
         AParser.Check('keyword.begin') or
         AParser.Check('keyword.asm') or
         AParser.Check('literal.directive') then
      begin
        ParseRoutineBody(AParser, LNode);
        AParser.Expect('delimiter.semicolon');
      end;

      Result := LNode;
    end);
end;

// --- Constructor declaration ---

procedure RegisterConstructorDecl(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.constructor', 'stmt.constructor_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume 'constructor'
      LNode := ParseRoutineSignature(AParser, False, 'stmt.constructor_decl');
      LNode.SetAttr('decl.kind', TValue.From<string>('constructor'));
      AParser.Expect('delimiter.semicolon');
      ParseRoutineDirectives(AParser, LNode);

      if AParser.Check('keyword.var') or
         AParser.Check('keyword.const') or
         AParser.Check('keyword.type') or
         AParser.Check('keyword.label') or
         AParser.Check('keyword.begin') or
         AParser.Check('keyword.asm') or
         AParser.Check('literal.directive') then
      begin
        ParseRoutineBody(AParser, LNode);
        AParser.Expect('delimiter.semicolon');
      end;

      Result := LNode;
    end);
end;

// --- Destructor declaration ---

procedure RegisterDestructorDecl(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.destructor', 'stmt.destructor_decl',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      AParser.Consume();  // consume 'destructor'
      LNode := ParseRoutineSignature(AParser, False, 'stmt.destructor_decl');
      LNode.SetAttr('decl.kind', TValue.From<string>('destructor'));
      AParser.Expect('delimiter.semicolon');
      ParseRoutineDirectives(AParser, LNode);

      if AParser.Check('keyword.var') or
         AParser.Check('keyword.const') or
         AParser.Check('keyword.type') or
         AParser.Check('keyword.label') or
         AParser.Check('keyword.begin') or
         AParser.Check('keyword.asm') or
         AParser.Check('literal.directive') then
      begin
        ParseRoutineBody(AParser, LNode);
        AParser.Expect('delimiter.semicolon');
      end;

      Result := LNode;
    end);
end;

// =========================================================================
//  COMPILER DIRECTIVE HANDLER
// =========================================================================

// --- Compiler directive: {$IFDEF FOO}, {$R+}, etc. ---
//
//  These survive the lexer as 'literal.directive' tokens (see Lexer unit).
//  We register them as statements so they become proper AST nodes with
//  their raw text preserved for verbatim emission.

procedure RegisterDirectiveStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('literal.directive', 'stmt.directive',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      LNode.SetAttr('directive.raw',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      Result := LNode;
    end);
end;

// =========================================================================
//  TOP-LEVEL STRUCTURES
// =========================================================================

// --- Program ---

procedure RegisterProgramStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.program', 'stmt.program',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LBodyNode: TASTNode;
      LUsesKW:   string;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'program'
      LNode.SetAttr('decl.name',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();  // consume program name

      // Optional program parameter list: program Foo(Input, Output);
      if AParser.Match('delimiter.lparen') then
      begin
        while not AParser.Check('delimiter.rparen') and
              not AParser.Check(KIND_EOF) do
        begin
          AParser.Consume();
          AParser.Match('delimiter.comma');
        end;
        AParser.Expect('delimiter.rparen');
      end;

      AParser.Expect('delimiter.semicolon');

      // Uses clause
      if AParser.Check('keyword.uses') then
      begin
        LUsesKW := AParser.CurrentToken().Text;
        AParser.Consume();  // consume 'uses'
        LNode.AddChild(ParseUsesClause(AParser, LUsesKW));
      end;

      // Declarations
      while not AParser.Check('keyword.begin') and
            not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
        LNode.AddChild(TASTNode(AParser.ParseStatement()));

      // Main block — parse manually so program node owns begin/end tokens
      if AParser.Check('keyword.begin') then
      begin
        LNode.SetAttr('kw.begin', TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();  // consume 'begin'
        LBodyNode := AParser.CreateNode('stmt.program_body', AParser.CurrentToken());
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
          LBodyNode.AddChild(TASTNode(AParser.ParseStatement()));
        LNode.AddChild(LBodyNode);
      end;

      LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.dot');
      Result := LNode;
    end);
end;

// --- Unit ---

procedure RegisterUnitStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.unit', 'stmt.unit',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LIntfNode: TASTNode;
      LImplNode: TASTNode;
      LInitNode: TASTNode;
      LFinNode:  TASTNode;
      LUnitName: string;
      LUsesKW:   string;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'unit'
      LUnitName := AParser.CurrentToken().Text;
      AParser.Consume();  // consume unit name

      // Unit name may be dotted: MyCompany.MyUnit
      while AParser.Check('delimiter.dot') do
      begin
        AParser.Consume();
        LUnitName := LUnitName + '.' + AParser.CurrentToken().Text;
        AParser.Consume();
      end;

      LNode.SetAttr('decl.name', TValue.From<string>(LUnitName));

      // Handle hint directives after unit name (deprecated, platform, etc.)
      if AParser.Check('keyword.deprecated') or
         AParser.Check('keyword.platform') or
         AParser.Check('keyword.experimental') then
      begin
        LNode.SetAttr('unit.hint',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();
        if AParser.Check(KIND_STRING) then
          AParser.Consume();
      end;

      AParser.Expect('delimiter.semicolon');

      // Consume any compiler directives before interface keyword
      while AParser.Check('literal.directive') do
        LNode.AddChild(TASTNode(AParser.ParseStatement()));

      // === Interface section ===
      LNode.SetAttr('kw.interface', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.interface');
      LIntfNode := AParser.CreateNode('stmt.unit_interface',
        AParser.CurrentToken());

      // Consume any compiler directives before uses clause
      while AParser.Check('literal.directive') do
        LIntfNode.AddChild(TASTNode(AParser.ParseStatement()));

      // Optional uses clause
      if AParser.Check('keyword.uses') then
      begin
        LUsesKW := AParser.CurrentToken().Text;
        AParser.Consume();  // consume 'uses'
        LIntfNode.AddChild(ParseUsesClause(AParser, LUsesKW));
      end;

      // Interface declarations
      while not AParser.Check('keyword.implementation') and
            not AParser.Check(KIND_EOF) do
        LIntfNode.AddChild(TASTNode(AParser.ParseStatement()));

      LNode.AddChild(LIntfNode);

      // Consume any compiler directives before implementation keyword
      while AParser.Check('literal.directive') do
        LIntfNode.AddChild(TASTNode(AParser.ParseStatement()));

      // === Implementation section ===
      LNode.SetAttr('kw.implementation', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.implementation');
      LImplNode := AParser.CreateNode('stmt.unit_implementation',
        AParser.CurrentToken());

      // Consume any compiler directives before uses clause
      while AParser.Check('literal.directive') do
        LImplNode.AddChild(TASTNode(AParser.ParseStatement()));

      // Optional uses clause
      if AParser.Check('keyword.uses') then
      begin
        LUsesKW := AParser.CurrentToken().Text;
        AParser.Consume();  // consume 'uses'
        LImplNode.AddChild(ParseUsesClause(AParser, LUsesKW));
      end;

      // Implementation declarations
      while not AParser.Check('keyword.initialization') and
            not AParser.Check('keyword.finalization') and
            not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
        LImplNode.AddChild(TASTNode(AParser.ParseStatement()));

      LNode.AddChild(LImplNode);

      // === Optional initialization section ===
      if AParser.Check('keyword.initialization') then
      begin
        LNode.SetAttr('kw.initialization', TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();  // consume 'initialization'
        LInitNode := AParser.CreateNode('stmt.unit_initialization',
          AParser.CurrentToken());
        while not AParser.Check('keyword.finalization') and
              not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LInitNode.AddChild(TASTNode(AParser.ParseStatement()));
        end;
        LNode.AddChild(LInitNode);
      end;

      // === Optional finalization section ===
      if AParser.Check('keyword.finalization') then
      begin
        LNode.SetAttr('kw.finalization', TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();  // consume 'finalization'
        LFinNode := AParser.CreateNode('stmt.unit_finalization',
          AParser.CurrentToken());
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
        begin
          LFinNode.AddChild(TASTNode(AParser.ParseStatement()));
        end;
        LNode.AddChild(LFinNode);
      end;

      // Consume any compiler directives before closing end
      while AParser.Check('literal.directive') do
        LNode.AddChild(TASTNode(AParser.ParseStatement()));

      // Closing end.
      LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.dot');
      Result := LNode;
    end);
end;

// --- Library ---

procedure RegisterLibraryStmt(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.library', 'stmt.library',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LBodyNode: TASTNode;
      LUsesKW:   string;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'library'
      LNode.SetAttr('decl.name',
        TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Consume();
      AParser.Expect('delimiter.semicolon');

      // Uses
      if AParser.Check('keyword.uses') then
      begin
        LUsesKW := AParser.CurrentToken().Text;
        AParser.Consume();  // consume 'uses'
        LNode.AddChild(ParseUsesClause(AParser, LUsesKW));
      end;

      // Declarations
      while not AParser.Check('keyword.exports') and
            not AParser.Check('keyword.begin') and
            not AParser.Check('keyword.end') and
            not AParser.Check(KIND_EOF) do
        LNode.AddChild(TASTNode(AParser.ParseStatement()));

      // Exports clause
      if AParser.Check('keyword.exports') then
      begin
        LUsesKW := AParser.CurrentToken().Text;
        AParser.Consume();  // consume 'exports'
        LNode.AddChild(ParseUsesClause(AParser, LUsesKW));
      end;

      // Main block — parse manually so library node owns begin/end tokens
      if AParser.Check('keyword.begin') then
      begin
        LNode.SetAttr('kw.begin', TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();  // consume 'begin'
        LBodyNode := AParser.CreateNode('stmt.program_body', AParser.CurrentToken());
        while not AParser.Check('keyword.end') and
              not AParser.Check(KIND_EOF) do
          LBodyNode.AddChild(TASTNode(AParser.ParseStatement()));
        LNode.AddChild(LBodyNode);
      end;

      LNode.SetAttr('kw.end', TValue.From<string>(AParser.CurrentToken().Text));
      AParser.Expect('keyword.end');
      AParser.Match('delimiter.dot');
      Result := LNode;
    end);
end;

// --- Exports clause (standalone) ---

procedure RegisterExportsClause(const AParse: TMetamorf);
begin
  AParse.Config().RegisterStatement('keyword.exports', 'stmt.exports_clause',
    function(AParser: TParserBase): TASTNodeBase
    var
      LNode:     TASTNode;
      LItemNode: TASTNode;
    begin
      LNode := AParser.CreateNode();
      AParser.Consume();  // consume 'exports'

      repeat
        LItemNode := AParser.CreateNode('stmt.exports_item',
          AParser.CurrentToken());
        LItemNode.SetAttr('decl.name',
          TValue.From<string>(AParser.CurrentToken().Text));
        AParser.Consume();

        // Optional: name 'ExternalName'
        if AParser.Match('keyword.name') then
        begin
          LItemNode.SetAttr('export.name',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
        end;

        // Optional: index N
        if AParser.Match('keyword.index') then
        begin
          LItemNode.SetAttr('export.index',
            TValue.From<string>(AParser.CurrentToken().Text));
          AParser.Consume();
        end;

        LNode.AddChild(LItemNode);
      until not AParser.Match('delimiter.comma');

      AParser.Expect('delimiter.semicolon');
      Result := LNode;
    end);
end;

// =========================================================================
//  PUBLIC ENTRY POINT
// =========================================================================

procedure ConfigGrammar(const AParse: TMetamorf);
begin
  // --- Prefix expression handlers ---
  RegisterLiteralPrefixes(AParse);
  RegisterNilLiteral(AParse);
  RegisterBooleanLiterals(AParse);
  RegisterUnaryOps(AParse);
  RegisterGroupedExpr(AParse);
  RegisterAddrOf(AParse);
  RegisterCharLiteral(AParse);
  RegisterSetLiteral(AParse);
  RegisterInheritedExpr(AParse);

  // --- Infix expression handlers ---
  RegisterAssignment(AParse);
  RegisterArithmeticOps(AParse);
  RegisterComparisonOps(AParse);
  RegisterLogicalOps(AParse);
  RegisterBitwiseShiftOps(AParse);
  RegisterTypeTestOps(AParse);
  RegisterCallExpr(AParse);
  RegisterArrayIndex(AParse);
  RegisterFieldAccess(AParse);
  RegisterPointerDeref(AParse);
  RegisterRangeOp(AParse);

  // --- Control flow statements ---
  RegisterBeginBlock(AParse);
  RegisterIfStmt(AParse);
  RegisterWhileStmt(AParse);
  RegisterForStmt(AParse);
  RegisterRepeatStmt(AParse);
  RegisterCaseStmt(AParse);
  RegisterWithStmt(AParse);
  RegisterTryStmt(AParse);
  RegisterOnStmt(AParse);
  RegisterRaiseStmt(AParse);
  RegisterExitStmt(AParse);
  RegisterBreakStmt(AParse);
  RegisterContinueStmt(AParse);
  RegisterGotoStmt(AParse);
  RegisterLabelDecl(AParse);
  RegisterAsmBlock(AParse);

  // --- Declaration blocks ---
  RegisterVarBlock(AParse);
  RegisterThreadvarBlock(AParse);
  RegisterConstBlock(AParse);
  RegisterResourcestringBlock(AParse);
  RegisterTypeBlock(AParse);

  // --- Routine declarations ---
  RegisterProcDecl(AParse);
  RegisterFuncDecl(AParse);
  RegisterConstructorDecl(AParse);
  RegisterDestructorDecl(AParse);

  // --- Top-level structures ---
  RegisterProgramStmt(AParse);
  RegisterUnitStmt(AParse);
  RegisterLibraryStmt(AParse);
  RegisterExportsClause(AParse);

  // --- Compiler directives ---
  RegisterDirectiveStmt(AParse);
end;

end.
