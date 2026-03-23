{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit Myra.Lexer;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigMyraLexer(const APax: TMetamorf);

implementation

uses
  System.SysUtils,
  Metamorf.Build,
  Metamorf.Common;

// ---------------------------------------------------------------------------
// Myra Reserved Words (BNF §2)
// ---------------------------------------------------------------------------

procedure RegisterKeywords(const APax: TMetamorf);
begin
  APax.Config()
    .CaseSensitiveKeywords(True)

    // Module structure
    .AddKeyword('module',     'keyword.module')
    .AddKeyword('import',     'keyword.import')
    .AddKeyword('exported',   'keyword.exported')
    .AddKeyword('external',   'keyword.external')

    // Control flow
    .AddKeyword('begin',      'keyword.begin')
    .AddKeyword('end',        'keyword.end')
    .AddKeyword('if',         'keyword.if')
    .AddKeyword('then',       'keyword.then')
    .AddKeyword('else',       'keyword.else')
    .AddKeyword('while',      'keyword.while')
    .AddKeyword('do',         'keyword.do')
    .AddKeyword('for',        'keyword.for')
    .AddKeyword('to',         'keyword.to')
    .AddKeyword('downto',     'keyword.downto')
    .AddKeyword('repeat',     'keyword.repeat')
    .AddKeyword('until',      'keyword.until')
    .AddKeyword('return',     'keyword.return')
    .AddKeyword('match',      'keyword.match')

    // Declarations
    .AddKeyword('var',        'keyword.var')
    .AddKeyword('const',      'keyword.const')
    .AddKeyword('type',       'keyword.type')
    .AddKeyword('routine',    'keyword.routine')
    .AddKeyword('method',     'keyword.method')

    // Type definitions
    .AddKeyword('record',     'keyword.record')
    .AddKeyword('object',     'keyword.object')
    .AddKeyword('overlay',    'keyword.overlay')
    .AddKeyword('choices',    'keyword.choices')
    .AddKeyword('packed',     'keyword.packed')
    .AddKeyword('align',      'keyword.align')
    .AddKeyword('array',      'keyword.array')
    .AddKeyword('of',         'keyword.of')
    .AddKeyword('set',        'keyword.set')
    .AddKeyword('pointer',    'keyword.pointer')

    // Logical / bitwise operators
    .AddKeyword('and',        'keyword.and')
    .AddKeyword('or',         'keyword.or')
    .AddKeyword('not',        'keyword.not')
    .AddKeyword('xor',        'keyword.xor')
    .AddKeyword('div',        'keyword.div')
    .AddKeyword('mod',        'keyword.mod')
    .AddKeyword('shl',        'keyword.shl')
    .AddKeyword('shr',        'keyword.shr')
    .AddKeyword('in',         'keyword.in')
    .AddKeyword('is',         'keyword.is')

    // Literals
    .AddKeyword('true',       'keyword.true')
    .AddKeyword('false',      'keyword.false')
    .AddKeyword('nil',        'keyword.nil')

    // Pointer / address
    .AddKeyword('address',    'keyword.address')

    // Self / parent
    .AddKeyword('self',       'keyword.self')
    .AddKeyword('parent',     'keyword.parent')

    // Exception handling
    .AddKeyword('guard',               'keyword.guard')
    .AddKeyword('except',              'keyword.except')
    .AddKeyword('finally',             'keyword.finally')
    .AddKeyword('raiseexception',      'keyword.raiseexception')
    .AddKeyword('raiseexceptioncode',  'keyword.raiseexceptioncode')
    .AddKeyword('getexceptioncode',    'keyword.getexceptioncode')
    .AddKeyword('getexceptionmessage', 'keyword.getexceptionmessage')

    // Memory management
    .AddKeyword('create',     'keyword.create')
    .AddKeyword('destroy',    'keyword.destroy')
    .AddKeyword('getmem',     'keyword.getmem')
    .AddKeyword('freemem',    'keyword.freemem')
    .AddKeyword('resizemem',  'keyword.resizemem')
    .AddKeyword('setlength',  'keyword.setlength')

    // I/O
    .AddKeyword('write',      'keyword.write')
    .AddKeyword('writeln',    'keyword.writeln')

    // Intrinsics
    .AddKeyword('len',        'keyword.len')
    .AddKeyword('size',       'keyword.size')
    .AddKeyword('utf8',       'keyword.utf8')
    .AddKeyword('paramcount', 'keyword.paramcount')
    .AddKeyword('paramstr',   'keyword.paramstr')

    // Variadic
    .AddKeyword('varargs',    'keyword.varargs');
end;

// ---------------------------------------------------------------------------
// Contextual Keywords (not reserved — special only in ModuleKind position)
// ---------------------------------------------------------------------------

procedure RegisterContextualKeywords(const APax: TMetamorf);
begin
  APax.Config()
    .AddKeyword('exe',  'keyword.exe')
    .AddKeyword('dll',  'keyword.dll')
    .AddKeyword('lib',  'keyword.lib');
end;

// ---------------------------------------------------------------------------
// Operators and Delimiters (BNF §4)
// ---------------------------------------------------------------------------

procedure RegisterOperators(const APax: TMetamorf);
begin
  APax.Config()
    // Multi-char operators first (longest-match)
    .AddOperator(':=',  'op.assign')
    .AddOperator('+=',  'op.plus_assign')
    .AddOperator('-=',  'op.minus_assign')
    .AddOperator('*=',  'op.mul_assign')
    .AddOperator('/=',  'op.div_assign')
    .AddOperator('<>',  'op.neq')
    .AddOperator('<=',  'op.lte')
    .AddOperator('>=',  'op.gte')
    .AddOperator('...', 'op.ellipsis')
    .AddOperator('..',  'op.range')

    // Single-char Myra operators
    .AddOperator('=',   'op.eq')
    .AddOperator('<',   'op.lt')
    .AddOperator('>',   'op.gt')
    .AddOperator('+',   'op.plus')
    .AddOperator('-',   'op.minus')
    .AddOperator('*',   'op.multiply')
    .AddOperator('/',   'op.divide')
    .AddOperator('^',   'op.deref')
    .AddOperator('|',   'op.pipe')
    .AddOperator('&',   'op.ampersand');
end;

// ---------------------------------------------------------------------------
// String Styles (BNF §1)
// ---------------------------------------------------------------------------

procedure RegisterStringStyles(const APax: TMetamorf);
begin
  APax.Config()
    // "..." C-string literal — escape sequences processed
    .AddStringStyle('"', '"', 'literal.cstring', True)
    // '...' Pascal string literal — '' inside means one literal '
    .AddStringStyle('''', '''', 'literal.string', False)

    // w"..." wide-string literal — escape sequences processed
    .AddStringStyle('w"', '"', 'literal.wstring', True);
end;

// ---------------------------------------------------------------------------
// Comments (BNF §5)
// ---------------------------------------------------------------------------

procedure RegisterComments(const APax: TMetamorf);
begin
  APax.Config()
    .AddLineComment('//')
    .AddBlockComment('/*', '*/');
end;

// ---------------------------------------------------------------------------
// Structural Tokens
// ---------------------------------------------------------------------------

procedure RegisterStructural(const APax: TMetamorf);
begin
  APax.Config()
    .SetStatementTerminator('delimiter.semicolon')
    .SetBlockOpen('keyword.begin')
    .SetBlockClose('keyword.end');
end;

// ---------------------------------------------------------------------------
// Directives (BNF §6, §7)
// ---------------------------------------------------------------------------

procedure RegisterDirectives(const APax: TMetamorf);
var
  LConfig: TLangConfig;
begin
  LConfig := APax.Config();
  LConfig
    .SetDirectivePrefix('@', 'directive')

    // Conditional compilation (BNF §7)
    .AddDirective('define',         'directive.define',         crDefine)
    .AddDirective('undef',          'directive.undef',          crUndef)
    .AddDirective('ifdef',          'directive.ifdef',          crIfDef)
    .AddDirective('ifndef',         'directive.ifndef',         crIfNDef)
    .AddDirective('elseif',         'directive.elseif',         crElseIf)
    .AddDirective('else',           'directive.else',           crElse)
    .AddDirective('endif',          'directive.endif',          crEndIf)

    // Module-level directives (BNF §6)
    .AddDirective('exeicon',        'directive.exeicon')
    .AddDirective('copydll',        'directive.copydll')
    .AddDirective('linklibrary',    'directive.linklibrary')
    .AddDirective('librarypath',    'directive.librarypath')
    .AddDirective('modulepath',     'directive.modulepath')
    .AddDirective('includepath',    'directive.includepath')
    .AddDirective('subsystem',      'directive.subsystem',      crNone,
      function(const ALexer: TLexerBase): string
      var
        LArg: string;
      begin
        Result := '';
        // Skip whitespace
        while not ALexer.IsEOF() and CharInSet(ALexer.Peek(), [' ', #9]) do
          ALexer.Advance();
        // Read identifier argument
        LArg := '';
        while not ALexer.IsEOF() and ALexer.IsIdentifierPart(ALexer.Peek()) do
        begin
          LArg := LArg + ALexer.Peek();
          ALexer.Advance();
        end;
        // Consume semicolon if present
        while not ALexer.IsEOF() and CharInSet(ALexer.Peek(), [' ', #9]) do
          ALexer.Advance();
        if not ALexer.IsEOF() and (ALexer.Peek() = ';') then
          ALexer.Advance();
        // Process
        if SameText(LArg, 'console') then
        begin
          ALexer.GetBuild().SetSubsystem(stConsole);
          ALexer.GetBuild().RemoveDefine('GUI_APP');
          ALexer.GetBuild().SetDefine('CONSOLE_APP');
        end
        else if SameText(LArg, 'gui') then
        begin
          ALexer.GetBuild().SetSubsystem(stGUI);
          ALexer.GetBuild().RemoveDefine('CONSOLE_APP');
          ALexer.GetBuild().SetDefine('GUI_APP');
        end
        else
          Result := 'Unknown subsystem: ' + LArg +
            '. Valid values: console, gui';
      end)
    .AddDirective('target',         'directive.target',         crNone,
      function(const ALexer: TLexerBase): string
      var
        LArg: string;
      begin
        Result := '';
        // Skip whitespace
        while not ALexer.IsEOF() and CharInSet(ALexer.Peek(), [' ', #9]) do
          ALexer.Advance();
        // Read identifier argument
        LArg := '';
        while not ALexer.IsEOF() and ALexer.IsIdentifierPart(ALexer.Peek()) do
        begin
          LArg := LArg + ALexer.Peek();
          ALexer.Advance();
        end;
        // Consume semicolon if present
        while not ALexer.IsEOF() and CharInSet(ALexer.Peek(), [' ', #9]) do
          ALexer.Advance();
        if not ALexer.IsEOF() and (ALexer.Peek() = ';') then
          ALexer.Advance();
        // Process
        if SameText(LArg, 'win64') then
          ALexer.GetBuild().SetTarget(tpWin64)
        else if SameText(LArg, 'linux64') then
          ALexer.GetBuild().SetTarget(tpLinux64)
        else
          Result := 'Unknown target platform: ' + LArg +
            '. Valid values: win64, linux64';
      end)
    .AddDirective('optimize',       'directive.optimize')
    .AddDirective('addverinfo',     'directive.addverinfo')
    .AddDirective('vimajor',        'directive.vimajor')
    .AddDirective('viminor',        'directive.viminor')
    .AddDirective('vipatch',        'directive.vipatch')
    .AddDirective('viproductname',  'directive.viproductname')
    .AddDirective('videscription',  'directive.videscription')
    .AddDirective('vifilename',     'directive.vifilename')
    .AddDirective('vicompanyname',  'directive.vicompanyname')
    .AddDirective('vicopyright',    'directive.vicopyright')

    // Statement-level directives
    .AddDirective('breakpoint',     'directive.breakpoint')
    .AddDirective('message',        'directive.message');
end;

// ---------------------------------------------------------------------------
// Built-in Types (BNF §3) and Literal Type Mappings
// ---------------------------------------------------------------------------

procedure RegisterTypes(const APax: TMetamorf);
begin
  APax.Config()
    // Integer types
    .AddTypeKeyword('int8',     'type.int8')
    .AddTypeKeyword('int16',    'type.int16')
    .AddTypeKeyword('int32',    'type.int32')
    .AddTypeKeyword('int64',    'type.int64')
    .AddTypeKeyword('uint8',    'type.uint8')
    .AddTypeKeyword('uint16',   'type.uint16')
    .AddTypeKeyword('uint32',   'type.uint32')
    .AddTypeKeyword('uint64',   'type.uint64')
    // Float types
    .AddTypeKeyword('float32',  'type.float32')
    .AddTypeKeyword('float64',  'type.float64')
    // Boolean
    .AddTypeKeyword('boolean',  'type.boolean')
    // Character types
    .AddTypeKeyword('char',     'type.char')
    .AddTypeKeyword('wchar',    'type.wchar')
    // String types
    .AddTypeKeyword('string',   'type.string')
    .AddTypeKeyword('wstring',  'type.wstring')
    // Pointer
    .AddTypeKeyword('pointer',  'type.pointer')

    // Literal node -> type mappings
    .AddLiteralType('expr.integer',  'type.int32')
    .AddLiteralType('expr.float',    'type.float64')
    .AddLiteralType('expr.string',   'type.string')
    .AddLiteralType('expr.cstring',  'type.cstring')
    .AddLiteralType('expr.wstring',  'type.wstring')
    .AddLiteralType('expr.bool',     'type.boolean');
end;

// ---------------------------------------------------------------------------
// Number Literal Prefixes
// ---------------------------------------------------------------------------

procedure RegisterNumberPrefixes(const APax: TMetamorf);
begin
  APax.Config()
    .SetHexPrefix('0x', 'literal.hex')
    .SetHexPrefix('0X', 'literal.hex');
end;

// ===========================================================================
// Public Entry Point
// ===========================================================================

procedure ConfigMyraLexer(const APax: TMetamorf);
begin
  RegisterKeywords(APax);
  RegisterContextualKeywords(APax);
  RegisterOperators(APax);
  RegisterStringStyles(APax);
  RegisterComments(APax);
  RegisterStructural(APax);
  RegisterDirectives(APax);
  RegisterTypes(APax);
  RegisterNumberPrefixes(APax);
end;

end.
