{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Cpp.Lexer;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigCppTokens(const AMetamorf: TMetamorf);

implementation

procedure ConfigCppTokens(const AMetamorf: TMetamorf);
begin
  // C++ keywords — registered as cpp.keyword.* for boundary detection.
  // The parser uses the cpp.keyword.* prefix to identify C++ passthrough
  // boundaries at both statement and expression level.
  AMetamorf.Config()
    .AddKeyword('auto',             'cpp.keyword.auto')
    .AddKeyword('bool',             'cpp.keyword.bool')
    .AddKeyword('break',            'cpp.keyword.break')
    .AddKeyword('case',             'cpp.keyword.case')
    .AddKeyword('catch',            'cpp.keyword.catch')
    .AddKeyword('char',             'cpp.keyword.char')
    .AddKeyword('class',            'cpp.keyword.class')
    .AddKeyword('concept',          'cpp.keyword.concept')
    .AddKeyword('const_cast',       'cpp.keyword.const_cast')
    .AddKeyword('consteval',        'cpp.keyword.consteval')
    .AddKeyword('constexpr',        'cpp.keyword.constexpr')
    .AddKeyword('constinit',        'cpp.keyword.constinit')
    .AddKeyword('continue',         'cpp.keyword.continue')
    .AddKeyword('co_await',         'cpp.keyword.co_await')
    .AddKeyword('co_return',        'cpp.keyword.co_return')
    .AddKeyword('co_yield',         'cpp.keyword.co_yield')
    .AddKeyword('decltype',         'cpp.keyword.decltype')
    .AddKeyword('default',          'cpp.keyword.default')
    .AddKeyword('delete',           'cpp.keyword.delete')
    .AddKeyword('double',           'cpp.keyword.double')
    .AddKeyword('dynamic_cast',     'cpp.keyword.dynamic_cast')
    .AddKeyword('enum',             'cpp.keyword.enum')
    .AddKeyword('explicit',         'cpp.keyword.explicit')
    .AddKeyword('export',           'cpp.keyword.export')
    .AddKeyword('extern',           'cpp.keyword.extern')
    .AddKeyword('float',            'cpp.keyword.float')
    .AddKeyword('friend',           'cpp.keyword.friend')
    .AddKeyword('goto',             'cpp.keyword.goto')
    .AddKeyword('inline',           'cpp.keyword.inline')
    .AddKeyword('int',              'cpp.keyword.int')
    .AddKeyword('long',             'cpp.keyword.long')
    .AddKeyword('mutable',          'cpp.keyword.mutable')
    .AddKeyword('namespace',        'cpp.keyword.namespace')
    .AddKeyword('new',              'cpp.keyword.new')
    .AddKeyword('noexcept',         'cpp.keyword.noexcept')
    .AddKeyword('nullptr',          'cpp.keyword.nullptr')
    .AddKeyword('operator',         'cpp.keyword.operator')
    .AddKeyword('override',         'cpp.keyword.override')
    .AddKeyword('private',          'cpp.keyword.private')
    .AddKeyword('protected',        'cpp.keyword.protected')
    .AddKeyword('public',           'cpp.keyword.public')
    .AddKeyword('register',         'cpp.keyword.register')
    .AddKeyword('reinterpret_cast', 'cpp.keyword.reinterpret_cast')
    .AddKeyword('requires',         'cpp.keyword.requires')
    .AddKeyword('short',            'cpp.keyword.short')
    .AddKeyword('signed',           'cpp.keyword.signed')
    .AddKeyword('sizeof',           'cpp.keyword.sizeof')
    .AddKeyword('static',           'cpp.keyword.static')
    .AddKeyword('static_assert',    'cpp.keyword.static_assert')
    .AddKeyword('static_cast',      'cpp.keyword.static_cast')
    .AddKeyword('struct',           'cpp.keyword.struct')
    .AddKeyword('switch',           'cpp.keyword.switch')
    .AddKeyword('template',         'cpp.keyword.template')
    .AddKeyword('this',             'cpp.keyword.this')
    .AddKeyword('throw',            'cpp.keyword.throw')
    .AddKeyword('try',              'cpp.keyword.try')
    .AddKeyword('typedef',          'cpp.keyword.typedef')
    .AddKeyword('typeid',           'cpp.keyword.typeid')
    .AddKeyword('typename',         'cpp.keyword.typename')
    .AddKeyword('union',            'cpp.keyword.union')
    .AddKeyword('unsigned',         'cpp.keyword.unsigned')
    .AddKeyword('using',            'cpp.keyword.using')
    .AddKeyword('virtual',          'cpp.keyword.virtual')
    .AddKeyword('void',             'cpp.keyword.void')
    .AddKeyword('volatile',         'cpp.keyword.volatile')
    .AddKeyword('wchar_t',          'cpp.keyword.wchar_t');

  // C++ operators — multi-character operators that differ from or extend
  // the custom language's operator set.
  AMetamorf.Config()
    .AddOperator('::',  'cpp.op.scope')
    .AddOperator('->',  'cpp.op.arrow')
    .AddOperator('++',  'cpp.op.inc')
    .AddOperator('--',  'cpp.op.dec')
    .AddOperator('<<',  'cpp.op.shl')
    .AddOperator('>>',  'cpp.op.shr')
    .AddOperator('==',  'cpp.op.eq')
    .AddOperator('!=',  'cpp.op.neq')
    .AddOperator('&&',  'cpp.op.and')
    .AddOperator('||',  'cpp.op.or');

  // C++ single-character operators that have no custom language equivalent
  AMetamorf.Config()
    .AddOperator('!',   'cpp.op.not')
    .AddOperator('~',   'cpp.op.bitnot')
    .AddOperator('%',   'cpp.op.modulo');

  // C++ braces — tracked separately from language delimiters for
  // depth-aware raw token collection in passthrough handlers.
  AMetamorf.Config()
    .AddOperator('{',   'cpp.delimiter.lbrace')
    .AddOperator('}',   'cpp.delimiter.rbrace');

  // C++ preprocessor hash — triggers #include, #define, etc.
  AMetamorf.Config()
    .AddOperator('#',   'cpp.op.hash');
end;

end.
