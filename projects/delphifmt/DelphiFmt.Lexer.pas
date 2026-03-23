{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit DelphiFmt.Lexer;

{$I DelphiFmt.Defines.inc}

interface

uses
  System.SysUtils,
  Metamorf.API,
  Metamorf.Common;

procedure ConfigLexer(const APax: TMetamorf);

implementation

// =============================================================================
//  Keywords
// =============================================================================
//
//  Every Delphi reserved word AND context-sensitive directive is registered
//  here. The grammar layer is responsible for disambiguating directives that
//  can also appear as identifiers (e.g. "name", "read", "write", "index").
//
//  Kind strings follow the convention:  keyword.<lowercase_text>
//
//  Reserved words are grouped by category for maintainability. Contextual
//  directives that can legally appear as identifiers are marked with a
//  trailing comment.
// =============================================================================

procedure RegisterKeywords(const APax: TMetamorf);
begin
  APax.Config()
    .CaseSensitiveKeywords(False)

    // --- Program structure ---
    .AddKeyword('program',        'keyword.program')
    .AddKeyword('unit',           'keyword.unit')
    .AddKeyword('library',        'keyword.library')
    .AddKeyword('package',        'keyword.package')       // directive
    .AddKeyword('uses',           'keyword.uses')
    .AddKeyword('interface',      'keyword.interface')
    .AddKeyword('implementation', 'keyword.implementation')
    .AddKeyword('initialization', 'keyword.initialization')
    .AddKeyword('finalization',   'keyword.finalization')
    .AddKeyword('exports',        'keyword.exports')
    .AddKeyword('requires',       'keyword.requires')      // directive
    .AddKeyword('contains',       'keyword.contains')      // directive

    // --- Blocks and flow ---
    .AddKeyword('begin',     'keyword.begin')
    .AddKeyword('end',       'keyword.end')
    .AddKeyword('if',        'keyword.if')
    .AddKeyword('then',      'keyword.then')
    .AddKeyword('else',      'keyword.else')
    .AddKeyword('case',      'keyword.case')
    .AddKeyword('of',        'keyword.of')
    .AddKeyword('for',       'keyword.for')
    .AddKeyword('to',        'keyword.to')
    .AddKeyword('downto',    'keyword.downto')
    .AddKeyword('do',        'keyword.do')
    .AddKeyword('while',     'keyword.while')
    .AddKeyword('repeat',    'keyword.repeat')
    .AddKeyword('until',     'keyword.until')
    .AddKeyword('with',      'keyword.with')
    .AddKeyword('goto',      'keyword.goto')
    .AddKeyword('label',     'keyword.label')
    .AddKeyword('break',     'keyword.break')
    .AddKeyword('continue',  'keyword.continue')
    .AddKeyword('exit',      'keyword.exit')
    .AddKeyword('raise',     'keyword.raise')

    // --- Exception handling ---
    .AddKeyword('try',       'keyword.try')
    .AddKeyword('except',    'keyword.except')
    .AddKeyword('finally',   'keyword.finally')
    .AddKeyword('on',        'keyword.on')               // directive

    // --- Declarations ---
    .AddKeyword('var',             'keyword.var')
    .AddKeyword('const',           'keyword.const')
    .AddKeyword('type',            'keyword.type')
    .AddKeyword('threadvar',       'keyword.threadvar')
    .AddKeyword('resourcestring',  'keyword.resourcestring')

    // --- Routines ---
    .AddKeyword('procedure',   'keyword.procedure')
    .AddKeyword('function',    'keyword.function')
    .AddKeyword('constructor', 'keyword.constructor')
    .AddKeyword('destructor',  'keyword.destructor')
    .AddKeyword('operator',    'keyword.operator')        // directive

    // --- OOP structure ---
    .AddKeyword('class',            'keyword.class')
    .AddKeyword('object',           'keyword.object')
    .AddKeyword('record',           'keyword.record')
    .AddKeyword('dispinterface',    'keyword.dispinterface')
    .AddKeyword('inherited',        'keyword.inherited')
    .AddKeyword('property',         'keyword.property')
    .AddKeyword('set',              'keyword.set')
    .AddKeyword('file',             'keyword.file')
    .AddKeyword('string',           'keyword.string')
    .AddKeyword('array',            'keyword.array')
    .AddKeyword('packed',           'keyword.packed')

    // --- Visibility modifiers (directives) ---
    .AddKeyword('private',    'keyword.private')          // directive
    .AddKeyword('protected',  'keyword.protected')        // directive
    .AddKeyword('public',     'keyword.public')           // directive
    .AddKeyword('published',  'keyword.published')        // directive
    .AddKeyword('automated',  'keyword.automated')        // directive
    .AddKeyword('strict',     'keyword.strict')           // directive

    // --- OOP directives ---
    .AddKeyword('abstract',     'keyword.abstract')       // directive
    .AddKeyword('sealed',       'keyword.sealed')         // directive
    .AddKeyword('final',        'keyword.final')          // directive
    .AddKeyword('helper',       'keyword.helper')         // directive
    .AddKeyword('reintroduce',  'keyword.reintroduce')    // directive
    .AddKeyword('overload',     'keyword.overload')       // directive
    .AddKeyword('override',     'keyword.override')       // directive
    .AddKeyword('virtual',      'keyword.virtual')        // directive
    .AddKeyword('dynamic',      'keyword.dynamic')        // directive
    .AddKeyword('static',       'keyword.static')         // directive
    .AddKeyword('inline',       'keyword.inline')         // directive

    // --- Property specifiers (directives) ---
    .AddKeyword('read',       'keyword.read')             // directive
    .AddKeyword('write',      'keyword.write')            // directive
    .AddKeyword('default',    'keyword.default')          // directive
    .AddKeyword('nodefault',  'keyword.nodefault')        // directive
    .AddKeyword('stored',     'keyword.stored')           // directive
    .AddKeyword('index',      'keyword.index')            // directive
    .AddKeyword('readonly',   'keyword.readonly')         // directive
    .AddKeyword('writeonly',  'keyword.writeonly')         // directive
    .AddKeyword('implements', 'keyword.implements')        // directive
    .AddKeyword('dispid',     'keyword.dispid')           // directive

    // --- Calling conventions (directives) ---
    .AddKeyword('cdecl',     'keyword.cdecl')             // directive
    .AddKeyword('pascal',    'keyword.pascal')             // directive
    .AddKeyword('register',  'keyword.register')          // directive
    .AddKeyword('safecall',  'keyword.safecall')          // directive
    .AddKeyword('stdcall',   'keyword.stdcall')           // directive
    .AddKeyword('winapi',    'keyword.winapi')            // directive

    // --- Linkage directives ---
    .AddKeyword('external',  'keyword.external')          // directive
    .AddKeyword('forward',   'keyword.forward')           // directive
    .AddKeyword('export',    'keyword.export')            // directive
    .AddKeyword('name',      'keyword.name')              // directive
    .AddKeyword('local',     'keyword.local')             // directive
    .AddKeyword('varargs',   'keyword.varargs')           // directive
    .AddKeyword('delayed',   'keyword.delayed')           // directive
    .AddKeyword('far',       'keyword.far')               // directive
    .AddKeyword('near',      'keyword.near')              // directive
    .AddKeyword('resident',  'keyword.resident')          // directive

    // --- Hint directives ---
    .AddKeyword('deprecated',   'keyword.deprecated')     // directive
    .AddKeyword('experimental', 'keyword.experimental')   // directive
    .AddKeyword('platform',     'keyword.platform')       // directive

    // --- Method resolution / binding ---
    .AddKeyword('absolute',   'keyword.absolute')         // directive
    .AddKeyword('assembler',  'keyword.assembler')        // directive
    .AddKeyword('message',    'keyword.message')          // directive
    .AddKeyword('reference',  'keyword.reference')        // directive

    // --- Operators as keywords ---
    .AddKeyword('and',  'keyword.and')
    .AddKeyword('or',   'keyword.or')
    .AddKeyword('xor',  'keyword.xor')
    .AddKeyword('not',  'keyword.not')
    .AddKeyword('div',  'keyword.div')
    .AddKeyword('mod',  'keyword.mod')
    .AddKeyword('shl',  'keyword.shl')
    .AddKeyword('shr',  'keyword.shr')
    .AddKeyword('in',   'keyword.in')
    .AddKeyword('is',   'keyword.is')
    .AddKeyword('as',   'keyword.as')

    // --- Literals ---
    .AddKeyword('nil',   'keyword.nil')
    .AddKeyword('true',  'keyword.true')
    .AddKeyword('false', 'keyword.false')

    // --- Parameter modifier / assembly ---
    .AddKeyword('out',   'keyword.out')
    .AddKeyword('asm',   'keyword.asm');
end;

// =============================================================================
//  Operators and delimiters
// =============================================================================
//
//  Registered longest-first so the lexer's longest-match rule works
//  correctly (e.g. ':=' is matched before ':').
// =============================================================================

procedure RegisterOperators(const APax: TMetamorf);
begin
  APax.Config()
    // Multi-char operators (longest first)
    .AddOperator(':=', 'op.assign')
    .AddOperator('<>', 'op.neq')
    .AddOperator('<=', 'op.lte')
    .AddOperator('>=', 'op.gte')
    .AddOperator('..', 'op.range')

    // Single-char comparison / arithmetic
    .AddOperator('=',  'op.eq')
    .AddOperator('<',  'op.lt')
    .AddOperator('>',  'op.gt')
    .AddOperator('+',  'op.plus')
    .AddOperator('-',  'op.minus')
    .AddOperator('*',  'op.multiply')
    .AddOperator('/',  'op.divide')

    // Delimiters
    .AddOperator(':',  'delimiter.colon')
    .AddOperator(';',  'delimiter.semicolon')
    .AddOperator('.',  'delimiter.dot')
    .AddOperator(',',  'delimiter.comma')
    .AddOperator('(',  'delimiter.lparen')
    .AddOperator(')',  'delimiter.rparen')
    .AddOperator('[',  'delimiter.lbracket')
    .AddOperator(']',  'delimiter.rbracket')

    // Pointer / address
    .AddOperator('^',  'op.deref')
    .AddOperator('@',  'op.addr')

    // Character literal prefix: #13, #$0D
    .AddOperator('#',  'op.hash');
end;

// =============================================================================
//  Number literals
// =============================================================================
//
//  Delphi hex literals use $ prefix ($FF, $0A).
//  SetHexPrefix causes the lexer to consume $XX as a single hex token
//  in the number-scanning phase, before the operator scan.
// =============================================================================

procedure RegisterNumbers(const APax: TMetamorf);
begin
  APax.Config()
    .SetHexPrefix('$', KIND_INTEGER);
end;

// =============================================================================
//  String styles
// =============================================================================
//
//  Delphi strings are single-quoted with '' as the escape for embedded
//  quotes. ParseKit's string scanner with AllowEscape=False terminates
//  at the first unescaped closing quote. For 'it''s', this produces two
//  adjacent string tokens ('it' and 's') which the grammar or emitter
//  concatenates. Since the formatter emits raw token text, adjacent string
//  tokens reassemble correctly.
// =============================================================================

procedure RegisterStringStyles(const APax: TMetamorf);
begin
  APax.Config()
    .AddStringStyle('''', '''', KIND_STRING, False);
end;

// =============================================================================
//  Comments and compiler directives
// =============================================================================
//
//  IMPORTANT: Registration order matters. Block comments are checked in
//  the order they are registered. We register '{$' BEFORE '{' so that
//  compiler directives like {$IFDEF FOO} are captured as a single token
//  with kind 'literal.directive' rather than being swallowed as ordinary
//  block comments.
//
//  This uses the same mechanism NitroPascal employs for cppstart/cppend
//  blocks: a custom TokenKind on AddBlockComment makes the token survive
//  past the parser's automatic comment-skipping (which only skips the
//  default comment/block-comment kinds). The grammar layer then registers
//  'literal.directive' as a statement so directives become AST nodes
//  whose raw text passes through the emitter verbatim.
//
//  The '(*$' variant handles the rare (* *) directive syntax.
// =============================================================================

procedure RegisterComments(const APax: TMetamorf);
begin
  APax.Config()
    // Compiler directives — MUST be registered before plain block comments
    .AddBlockComment('{$',  '}',  'literal.directive')
    .AddBlockComment('(*$', '*)', 'literal.directive')

    // Regular comments
    .AddLineComment('//')
    .AddBlockComment('{',  '}')
    .AddBlockComment('(*', '*)');
end;

// =============================================================================
//  Structural tokens
// =============================================================================
//
//  These tell the parser's generic infrastructure which tokens terminate
//  statements and delimit blocks. The parser uses them for error recovery
//  (Synchronize) and block-level parsing.
// =============================================================================

procedure RegisterStructural(const APax: TMetamorf);
begin
  APax.Config()
    .SetStatementTerminator('delimiter.semicolon')
    .SetBlockOpen('keyword.begin')
    .SetBlockClose('keyword.end');
end;

// =============================================================================
//  Identifier character sets
// =============================================================================
//
//  Delphi identifiers: start with A-Z, a-z, or underscore; continue with
//  those plus digits. These are ParseKit's defaults, but we set them
//  explicitly for clarity.
// =============================================================================

procedure RegisterIdentifiers(const APax: TMetamorf);
begin
  APax.Config()
    .IdentifierStart('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_')
    .IdentifierPart('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789');
end;

// =============================================================================
//  Public entry point
// =============================================================================

procedure ConfigLexer(const APax: TMetamorf);
begin
  RegisterIdentifiers(APax);
  RegisterKeywords(APax);
  RegisterOperators(APax);
  RegisterNumbers(APax);
  RegisterStringStyles(APax);
  RegisterComments(APax);
  RegisterStructural(APax);
end;

end.
