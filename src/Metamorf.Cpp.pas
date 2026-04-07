{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Cpp;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.Interpreter;

// Registers C++ passthrough tokens, grammar handlers, and emit handlers
// into the interpreter's dispatch tables. Must be called AFTER the .mor
// setup pass completes so custom language rules take priority.
procedure MorConfigCpp(const AInterp: TMorInterpreter);

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.AST,
  Metamorf.CodeGen;

const
  CppKW: array[0..61] of string = (
    'auto', 'bool', 'break', 'case', 'catch', 'char',
    'class', 'const', 'constexpr', 'continue', 'default',
    'delete', 'do', 'double', 'dynamic_cast', 'else',
    'enum', 'explicit', 'extern', 'false', 'float', 'for',
    'friend', 'goto', 'if', 'inline', 'int', 'long',
    'mutable', 'namespace', 'new', 'noexcept', 'nullptr',
    'operator', 'override', 'private', 'protected', 'public',
    'register', 'reinterpret_cast', 'return', 'short',
    'signed', 'sizeof', 'static', 'static_cast', 'struct',
    'switch', 'template', 'this', 'throw', 'true', 'try',
    'typedef', 'typename', 'union', 'unsigned', 'using',
    'virtual', 'void', 'volatile', 'while'
  );

procedure ConfigCppTokens(const AInterp: TMorInterpreter);
var
  LKeywords: TDictionary<string, string>;
  LOperators: TList<TMorOperatorEntryInterp>;
  LStyles: TList<TMorStringStyleEntry>;
  LEntry: TMorOperatorEntryInterp;
  LStyle: TMorStringStyleEntry;
  LI: Integer;
begin
  LKeywords := AInterp.GetKeywords();
  LOperators := AInterp.GetOperators();

  // C++ keywords -- registered as cpp.keyword.* so they don't collide
  // with custom language keywords. Only add if not already registered.
  for LI := 0 to High(CppKW) do
  begin
    if not LKeywords.ContainsKey(CppKW[LI]) then
      LKeywords.AddOrSetValue(CppKW[LI], 'cpp.keyword.' + CppKW[LI]);
  end;

  // C++ operators and delimiters -- always registered unconditionally.
  // Custom languages MUST NOT redefine these tokens. If a custom
  // language needs the same symbol (e.g. % for modulo), it should
  // reference the cpp.op.* kind in its grammar rules instead.
  LEntry.Text := '::'; LEntry.Kind := 'cpp.op.scope';
  LOperators.Add(LEntry);
  LEntry.Text := '->'; LEntry.Kind := 'cpp.op.arrow';
  LOperators.Add(LEntry);
  LEntry.Text := '++'; LEntry.Kind := 'cpp.op.increment';
  LOperators.Add(LEntry);
  LEntry.Text := '--'; LEntry.Kind := 'cpp.op.decrement';
  LOperators.Add(LEntry);
  LEntry.Text := '<<'; LEntry.Kind := 'cpp.op.shl';
  LOperators.Add(LEntry);
  LEntry.Text := '>>'; LEntry.Kind := 'cpp.op.shr';
  LOperators.Add(LEntry);
  LEntry.Text := '&&'; LEntry.Kind := 'cpp.op.logand';
  LOperators.Add(LEntry);
  LEntry.Text := '||'; LEntry.Kind := 'cpp.op.logor';
  LOperators.Add(LEntry);
  LEntry.Text := '=='; LEntry.Kind := 'cpp.op.eq';
  LOperators.Add(LEntry);
  LEntry.Text := '!='; LEntry.Kind := 'cpp.op.neq';
  LOperators.Add(LEntry);
  LEntry.Text := '%'; LEntry.Kind := 'cpp.op.modulo';
  LOperators.Add(LEntry);
  LEntry.Text := '~'; LEntry.Kind := 'cpp.op.bitnot';
  LOperators.Add(LEntry);
  LEntry.Text := '&'; LEntry.Kind := 'cpp.op.bitand';
  LOperators.Add(LEntry);
  LEntry.Text := '|'; LEntry.Kind := 'cpp.op.bitor';
  LOperators.Add(LEntry);
  LEntry.Text := '^'; LEntry.Kind := 'cpp.op.bitxor';
  LOperators.Add(LEntry);
  LEntry.Text := '!'; LEntry.Kind := 'cpp.op.lognot';
  LOperators.Add(LEntry);
  LEntry.Text := '#'; LEntry.Kind := 'cpp.op.hash';
  LOperators.Add(LEntry);
  LEntry.Text := '{'; LEntry.Kind := 'delimiter.lbrace';
  LOperators.Add(LEntry);
  LEntry.Text := '}'; LEntry.Kind := 'delimiter.rbrace';
  LOperators.Add(LEntry);
  LEntry.Text := '['; LEntry.Kind := 'delimiter.lbracket';
  LOperators.Add(LEntry);
  LEntry.Text := ']'; LEntry.Kind := 'delimiter.rbracket';
  LOperators.Add(LEntry);

  // C++ char literal: 'x'
  LStyles := AInterp.GetStringStyles();
  LStyle.OpenText := '''';
  LStyle.CloseText := '''';
  LStyle.Kind := 'cpp.string.char';
  LStyle.Flags := '';
  LStyles.Add(LStyle);

  // Re-sort operators longest-first after adding C++ ones
  LOperators.Sort(
    System.Generics.Defaults.TComparer<TMorOperatorEntryInterp>.Construct(
    function(const ALeft, ARight: TMorOperatorEntryInterp): Integer
    begin
      Result := Length(ARight.Text) - Length(ALeft.Text);
    end));
end;

{ Raw token collection: collects tokens as string with brace-depth
  tracking. Mode determines stop conditions. }
function CollectRaw(const AInterp: TMorInterpreter;
  const AStmtMode: Boolean): string;
var
  LDepth: Integer;
  LKind: string;
  LText: string;
  LNeedSpace: Boolean;
begin
  Result := '';
  LDepth := 0;
  LNeedSpace := False;

  while not AInterp.ParserAtEnd() do
  begin
    LKind := AInterp.ParserCurrentKind();
    LText := AInterp.ParserCurrentText();

    if LKind = 'eof' then
      Break;

    // Track depth for braces, parens, brackets
    if (LKind = 'delimiter.lbrace') or
       (LKind = 'delimiter.lparen') or
       (LKind = 'delimiter.lbracket') then
      Inc(LDepth)
    else if (LKind = 'delimiter.rbrace') or
            (LKind = 'delimiter.rparen') or
            (LKind = 'delimiter.rbracket') then
    begin
      Dec(LDepth);
      if AStmtMode and (LDepth < 0) then
        Break; // stop at unmatched }
      if AStmtMode and (LDepth <= 0) and (LKind = 'delimiter.rbrace') then
      begin
        // Include the closing brace in statement mode
        if LNeedSpace then Result := Result + ' ';
        Result := Result + LText;
        AInterp.ParserAdvance();
        Break;
      end;
    end;

    // Statement mode: stop at ; when depth <= 0
    if AStmtMode and (LKind = 'delimiter.semicolon') and (LDepth <= 0) then
    begin
      if LNeedSpace then Result := Result + ' ';
      Result := Result + LText;
      AInterp.ParserAdvance();
      Break;
    end;

    // Expression mode: stop at boundaries when depth <= 0
    // Expression mode: stop at boundaries
    if not AStmtMode then
    begin
      // Comma and semicolon stop at depth <= 0
      if (LDepth <= 0) and
         ((LKind = 'delimiter.comma') or
          (LKind = 'delimiter.semicolon')) then
        Break;
      // Closing delimiters stop only at depth < 0 (unmatched from outer context)
      if (LDepth < 0) and
         ((LKind = 'delimiter.rparen') or
          (LKind = 'delimiter.rbracket')) then
        Break;
      // Stop at any custom language keyword at depth <= 0
      if (LDepth <= 0) and LKind.StartsWith('keyword.') then
        Break;
    end;

    // Accumulate token text
    if LNeedSpace and (Result <> '') then
      Result := Result + ' ';
    if LKind.StartsWith('string.') then
      Result := Result + '"' + LText + '"'
    else if LKind = 'cpp.string.char' then
      Result := Result + '''' + LText + ''''
    else
      Result := Result + LText;
    LNeedSpace := True;
    AInterp.ParserAdvance();
  end;
end;

procedure ConfigCppGrammar(const AInterp: TMorInterpreter);
var
  LI: Integer;
  LKind: string;
  LNativeInfix: TMorNativeInfixEntry;
begin
  // Statement passthrough: every cpp.keyword.* gets a native stmt handler
  // that collects all raw tokens as a stmt.cpp_raw node
  for LI := 0 to High(CppKW) do
  begin
    LKind := 'cpp.keyword.' + CppKW[LI];
    // Only register if not already claimed by custom lang stmt rules
    if not AInterp.GetStmtRules().ContainsKey(LKind) then
    begin
      AInterp.RegisterNativeStmt(LKind,
        function: TMorASTNode
        var
          LNode: TMorASTNode;
        begin
          LNode := TMorASTNode.Create();
          LNode.SetKind('stmt.cpp_raw');
          LNode.SetAttr('cpp.raw', CollectRaw(AInterp, True));
          Result := LNode;
        end);
    end;
  end;

  // Expression prefix passthrough: subset of cpp keywords in expr position
  // collect raw tokens as expr.cpp_raw
  for LI := 0 to High(CppKW) do
  begin
    LKind := 'cpp.keyword.' + CppKW[LI];
    if not AInterp.GetPrefixRules().ContainsKey(LKind) then
    begin
      AInterp.RegisterNativePrefix(LKind,
        function: TMorASTNode
        var
          LNode: TMorASTNode;
        begin
          LNode := TMorASTNode.Create();
          LNode.SetKind('expr.cpp_raw');
          LNode.SetAttr('cpp.raw', CollectRaw(AInterp, False));
          Result := LNode;
        end);
    end;
  end;

  // Infix :: (scope resolution) at power 90
  LNativeInfix.Power := 90;
  LNativeInfix.Assoc := 'left';
  LNativeInfix.Handler :=
    function(const ALeft: TMorASTNode): TMorASTNode
    var
      LNode: TMorASTNode;
      LName: string;
    begin
      AInterp.ParserAdvance(); // skip ::
      // Build qualified name: left::right
      LName := ALeft.GetAttr('identifier');
      if LName = '' then
        LName := ALeft.GetAttr('qualified.name');
      if LName = '' then
        LName := ALeft.GetAttr('cpp.raw');
      LName := LName + '::' + AInterp.ParserCurrentText();
      AInterp.ParserAdvance(); // consume right identifier
      // Continue collecting :: chains
      while AInterp.ParserCurrentKind() = 'cpp.op.scope' do
      begin
        AInterp.ParserAdvance();
        LName := LName + '::' + AInterp.ParserCurrentText();
        AInterp.ParserAdvance();
      end;
      LNode := TMorASTNode.Create();
      LNode.SetKind('expr.cpp_qualified');
      LNode.SetAttr('qualified.name', LName);
      Result := LNode;
    end;
  AInterp.RegisterNativeInfix('cpp.op.scope', LNativeInfix);

  // Infix -> (arrow access) at power 85
  LNativeInfix.Power := 85;
  LNativeInfix.Assoc := 'left';
  LNativeInfix.Handler :=
    function(const ALeft: TMorASTNode): TMorASTNode
    var
      LNode: TMorASTNode;
    begin
      AInterp.ParserAdvance(); // skip ->
      LNode := TMorASTNode.Create();
      LNode.SetKind('expr.cpp_arrow');
      LNode.SetAttr('field.name', AInterp.ParserCurrentText());
      AInterp.ParserAdvance(); // consume field name
      LNode.AddChild(ALeft);
      Result := LNode;
    end;
  AInterp.RegisterNativeInfix('cpp.op.arrow', LNativeInfix);

  // Statement # (preprocessor)
  AInterp.RegisterNativeStmt('cpp.op.hash',
    function: TMorASTNode
    var
      LNode: TMorASTNode;
      LRaw: string;
      LInAngle: Boolean;
    begin
      AInterp.ParserAdvance(); // skip #
      LRaw := '#';
      LInAngle := False;
      // Collect until end of line (simplified: collect until ; or eof)
      while not AInterp.ParserAtEnd() do
      begin
        if AInterp.ParserCurrentText() = '<' then
          LInAngle := True;
        LRaw := LRaw + AInterp.ParserCurrentText();
        AInterp.ParserAdvance();
        // Stop after include "..." or include <...> forms
        if LRaw.Contains('>') or
           (LRaw.Contains('"') and (LRaw.CountChar('"') >= 2)) then
          Break;
        if not LInAngle then
          LRaw := LRaw + ' ';
      end;
      LNode := TMorASTNode.Create();
      LNode.SetKind('stmt.preprocessor');
      LNode.SetAttr('cpp.raw', LRaw.Trim());
      Result := LNode;
    end);
end;

procedure ConfigCppCodeGen(const AInterp: TMorInterpreter);
begin
  // stmt.cpp_raw -> emit raw text as line to source
  AInterp.RegisterNativeEmit('stmt.cpp_raw',
    procedure(const ANode: TMorASTNode)
    var
      LOutput: TMorCodeOutput;
    begin
      LOutput := AInterp.GetOutput();
      if LOutput <> nil then
        LOutput.EmitLine(ANode.GetAttr('cpp.raw'));
    end);

  // stmt.preprocessor -> emit raw text as line to HEADER
  AInterp.RegisterNativeEmit('stmt.preprocessor',
    procedure(const ANode: TMorASTNode)
    var
      LOutput: TMorCodeOutput;
    begin
      LOutput := AInterp.GetOutput();
      if LOutput <> nil then
        LOutput.EmitLine(ANode.GetAttr('cpp.raw'), otHeader);
    end);

  // expr.cpp_raw -> emit raw text inline
  AInterp.RegisterNativeEmit('expr.cpp_raw',
    procedure(const ANode: TMorASTNode)
    var
      LOutput: TMorCodeOutput;
    begin
      LOutput := AInterp.GetOutput();
      if LOutput <> nil then
        LOutput.Emit(ANode.GetAttr('cpp.raw'));
    end);

  // expr.cpp_qualified -> emit qualified name inline
  AInterp.RegisterNativeEmit('expr.cpp_qualified',
    procedure(const ANode: TMorASTNode)
    var
      LOutput: TMorCodeOutput;
    begin
      LOutput := AInterp.GetOutput();
      if LOutput <> nil then
        LOutput.Emit(ANode.GetAttr('qualified.name'));
    end);

  // expr.cpp_arrow -> emit child then ->field
  AInterp.RegisterNativeEmit('expr.cpp_arrow',
    procedure(const ANode: TMorASTNode)
    var
      LOutput: TMorCodeOutput;
    begin
      LOutput := AInterp.GetOutput();
      if LOutput <> nil then
      begin
        if ANode.ChildCount() > 0 then
          LOutput.EmitNode(ANode.GetChild(0));
        LOutput.Emit('->' + ANode.GetAttr('field.name'));
      end;
    end);

  // expr.cpp_cast -> emit (type)(operand)
  AInterp.RegisterNativeEmit('expr.cpp_cast',
    procedure(const ANode: TMorASTNode)
    var
      LOutput: TMorCodeOutput;
    begin
      LOutput := AInterp.GetOutput();
      if LOutput <> nil then
      begin
        LOutput.Emit('(' + ANode.GetAttr('cast.raw') + ')');
        if ANode.ChildCount() > 0 then
          LOutput.EmitNode(ANode.GetChild(0));
      end;
    end);
end;

procedure MorConfigCpp(const AInterp: TMorInterpreter);
begin
  ConfigCppTokens(AInterp);
  ConfigCppGrammar(AInterp);
  ConfigCppCodeGen(AInterp);
end;

end.
