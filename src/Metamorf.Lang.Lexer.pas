{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lang.Lexer;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigLexer(const AMetamorf: TMetamorf);

implementation

uses
  System.SysUtils,
  Metamorf.Common;

// ---------------------------------------------------------------------------
// Meta-Language Reserved Words
// ---------------------------------------------------------------------------

procedure RegisterKeywords(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config()
    .CaseSensitiveKeywords(True)

    // ---- Top-level structure ----
    .AddKeyword('language',    'keyword.language')
    .AddKeyword('version',     'keyword.version')
    .AddKeyword('tokens',      'keyword.tokens')
    .AddKeyword('grammar',     'keyword.grammar')
    .AddKeyword('semantics',   'keyword.semantics')
    .AddKeyword('emit',        'keyword.emit')
    .AddKeyword('emitters',    'keyword.emitters')
    .AddKeyword('types',       'keyword.types')
    .AddKeyword('const',       'keyword.const')
    .AddKeyword('enum',        'keyword.enum')
    .AddKeyword('fragment',    'keyword.fragment')
    .AddKeyword('import',      'keyword.import')
    .AddKeyword('include',     'keyword.include')
    .AddKeyword('routine',     'keyword.routine')

    // ---- Token declarations ----
    .AddKeyword('token',       'keyword.token')
    .AddKeyword('mode',        'keyword.mode')
    .AddKeyword('push',        'keyword.push')
    .AddKeyword('pop',         'keyword.pop')
    .AddKeyword('priority',    'keyword.priority')
    .AddKeyword('caseless',    'keyword.caseless')
    .AddKeyword('hidden',      'keyword.hidden')

    // ---- Grammar rules ----
    .AddKeyword('rule',        'keyword.rule')
    .AddKeyword('precedence',  'keyword.precedence')
    //.AddKeyword('left',        'keyword.left')   // context-sensitive, not a global keyword
    //.AddKeyword('right',       'keyword.right')  // context-sensitive, not a global keyword
    .AddKeyword('expect',      'keyword.expect')
    .AddKeyword('consume',     'keyword.consume')
    .AddKeyword('parse',       'keyword.parse')
    .AddKeyword('many',        'keyword.many')
    .AddKeyword('optional',    'keyword.optional')
    .AddKeyword('sync',        'keyword.sync')

    // ---- Handler constructs ----
    .AddKeyword('on',          'keyword.on')
    .AddKeyword('section',     'keyword.section')
    .AddKeyword('visit',       'keyword.visit')
    .AddKeyword('declare',     'keyword.declare')
    .AddKeyword('lookup',      'keyword.lookup')
    .AddKeyword('scope',       'keyword.scope')
    .AddKeyword('set',         'keyword.set')
    .AddKeyword('get',         'keyword.get')
    .AddKeyword('indent',      'keyword.indent')
    .AddKeyword('dedent',      'keyword.dedent')
    .AddKeyword('to',          'keyword.to')
    .AddKeyword('as',          'keyword.as')
    .AddKeyword('where',       'keyword.where')
    .AddKeyword('typed',       'keyword.typed')
    .AddKeyword('compatible',  'keyword.compatible')
    .AddKeyword('pass',        'keyword.pass')

    // ---- Control flow ----
    .AddKeyword('if',          'keyword.if')
    .AddKeyword('else',        'keyword.else')
    .AddKeyword('for',         'keyword.for')
    .AddKeyword('in',          'keyword.in')
    .AddKeyword('while',       'keyword.while')
    .AddKeyword('match',       'keyword.match')
    .AddKeyword('guard',       'keyword.guard')
    .AddKeyword('return',      'keyword.return')
    .AddKeyword('try',         'keyword.try')
    .AddKeyword('recover',     'keyword.recover')
    .AddKeyword('before',      'keyword.before')
    .AddKeyword('after',       'keyword.after')

    // ---- Logical operators ----
    .AddKeyword('and',         'keyword.and')
    .AddKeyword('or',          'keyword.or')
    .AddKeyword('not',         'keyword.not')

    // ---- Literals ----
    .AddKeyword('true',        'keyword.true')
    .AddKeyword('false',       'keyword.false')
    .AddKeyword('nil',         'keyword.nil')

    // ---- Collection operations ----
    .AddKeyword('collect',     'keyword.collect')
    .AddKeyword('filter',      'keyword.filter')
    .AddKeyword('map',         'keyword.map')
    .AddKeyword('any',         'keyword.any')
    .AddKeyword('all',         'keyword.all')
    .AddKeyword('count',       'keyword.count')

    // ---- Diagnostics ----
    .AddKeyword('error',       'keyword.error')
    .AddKeyword('warning',     'keyword.warning')
    .AddKeyword('hint',        'keyword.hint')
    .AddKeyword('note',        'keyword.note')
    .AddKeyword('info',        'keyword.info')

    // ---- Node navigation ----
    .AddKeyword('children',    'keyword.children')
    .AddKeyword('child',       'keyword.child')
    .AddKeyword('parent',      'keyword.parent')

    // ---- Variables ----
    .AddKeyword('let',         'keyword.let')
    .AddKeyword('typeof',      'keyword.typeof')

    // ---- Parse control ----
    .AddKeyword('until',       'keyword.until');
end;

// ---------------------------------------------------------------------------
// Operators and Delimiters
// ---------------------------------------------------------------------------

procedure RegisterOperators(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config()
    // Multi-character operators first for longest-match priority
    .AddOperator('=>', 'op.fat_arrow')
    .AddOperator('->', 'op.arrow')
    .AddOperator('==', 'op.eq')
    .AddOperator('!=', 'op.neq')
    .AddOperator('<=', 'op.lte')
    .AddOperator('>=', 'op.gte')
    // Single-character operators
    .AddOperator('=',  'op.assign')
    .AddOperator('<',  'op.lt')
    .AddOperator('>',  'op.gt')
    .AddOperator('+',  'op.plus')
    .AddOperator('-',  'op.minus')
    .AddOperator('*',  'op.multiply')
    .AddOperator('/',  'op.divide')
    .AddOperator('%',  'op.modulo')
    // Delimiters
    .AddOperator(';',  'delimiter.semicolon')
    .AddOperator(':',  'delimiter.colon')
    .AddOperator('.',  'delimiter.dot')
    .AddOperator(',',  'delimiter.comma')
    .AddOperator('(',  'delimiter.lparen')
    .AddOperator(')',  'delimiter.rparen')
    .AddOperator('{',  'delimiter.lbrace')
    .AddOperator('}',  'delimiter.rbrace')
    .AddOperator('[',  'delimiter.lbracket')
    .AddOperator(']',  'delimiter.rbracket')
    .AddOperator('@',  'delimiter.at')
    .AddOperator('|',  'delimiter.pipe');
end;

// ---------------------------------------------------------------------------
// String Styles
// ---------------------------------------------------------------------------

procedure RegisterStringStyles(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config()
    // Double-quoted strings with escape sequences
    .AddStringStyle('"', '"', KIND_STRING, True);
end;

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

procedure RegisterComments(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config()
    .AddLineComment('//')
    .AddBlockComment('/*', '*/');
end;

// ---------------------------------------------------------------------------
// Structural Tokens
// ---------------------------------------------------------------------------

procedure RegisterStructural(const AMetamorf: TMetamorf);
begin
  AMetamorf.Config()
    .SetStatementTerminator('delimiter.semicolon')
    .SetBlockOpen('delimiter.lbrace')
    .SetBlockClose('delimiter.rbrace');
end;

// ---------------------------------------------------------------------------
// PUBLIC ENTRY POINT
// ---------------------------------------------------------------------------

procedure ConfigLexer(const AMetamorf: TMetamorf);
begin
  RegisterKeywords(AMetamorf);
  RegisterOperators(AMetamorf);
  RegisterStringStyles(AMetamorf);
  RegisterComments(AMetamorf);
  RegisterStructural(AMetamorf);
end;

end.
