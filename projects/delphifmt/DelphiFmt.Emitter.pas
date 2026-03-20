{===============================================================================
  DelphiFmt™ - Delphi Source Code Formatter

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit DelphiFmt.Emitter;

{$I DelphiFmt.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.Math,
  Metamorf.API,
  DelphiFmt;

type

  { TDelphiFmtEmitter }
  TDelphiFmtEmitter = class
  private
    FOutput      : TStringBuilder;
    FOptions     : TDelphiFmtOptions;
    FLineBreak   : string;
    FIndent      : Integer;
    FAtLineStart : Boolean;

    // ---- output primitives (ONLY methods that touch FOutput) ----
    procedure Append(const AText: string);
    procedure NL();
    procedure BlankLines(const ACount: Integer);

    // ---- indent ----
    procedure IndentIn();
    procedure IndentOut();
    function  IndentStr(): string;

    // ---- keyword capitalisation ----
    function KW(const AWord: string): string;

    // ---- attribute helpers ----
    function AttrStr(const ANode: TASTNode; const AKey: string): string;
    function AttrBool(const ANode: TASTNode; const AKey: string): Boolean;
    function AttrInt(const ANode: TASTNode; const AKey: string): Integer;

    // ---- safe child accessor ----
    function Ch(const ANode: TASTNode; const AIdx: Integer): TASTNode;

    // ---- spacing strings from FOptions ----
    function SpBeforeColon(): string;
    function SpAfterColon(): string;
    function SpAroundAssign(): string;
    function SpAroundBinOp(): string;
    function SpAfterComma(): string;
    function SpAfterSemi(): string;

    // ---- blank-line counts from FOptions ----
    function BLSection(): Integer;
    function BLDirective(): Integer;
    function BLVisibility(): Integer;
    function BLRoutines(const AInIntf: Boolean): Integer;

    // ---- node kind predicates ----
    function IsComplexTypeRef(const AKind: string): Boolean;
    function IsRoutineDecl(const AKind: string): Boolean;

    // ---- expression emitter (returns string, never writes FOutput) ----
    function EmitExpr(const ANode: TASTNode): string;

    // ---- type-reference emitter (returns string, never writes FOutput) ----
    function EmitTypeRef(const ANode: TASTNode): string;

    // ---- param list emitter (returns string) ----
    function EmitParamList(const ANode: TASTNode): string;

    // ---- statement visitors (write to FOutput) ----
    procedure VisitStmt(const ANode: TASTNode);
    procedure VisitStmtCore(const ANode: TASTNode);

    // ---- comment decoration emitters ----
    procedure EmitLeadingComments(const ANode: TASTNode);
    procedure EmitTrailingComment(const ANode: TASTNode);

    procedure VisitUnit(const ANode: TASTNode);
    procedure VisitProgram(const ANode: TASTNode);
    procedure VisitLibrary(const ANode: TASTNode);
    procedure VisitSection(const ANode: TASTNode;
      const AInIntf: Boolean);
    procedure VisitUsesClause(const ANode: TASTNode);

    procedure VisitConstBlock(const ANode: TASTNode);
    procedure VisitVarBlock(const ANode: TASTNode);
    procedure VisitTypeBlock(const ANode: TASTNode);
    procedure VisitTypeDecl(const ANode: TASTNode);
    procedure VisitClassBody(const ATypeNode: TASTNode;
      const AKeyword: string; const ADeclName: string);

    procedure VisitVisibility(const ANode: TASTNode);
    procedure VisitFieldDecl(const ANode: TASTNode);
    procedure VisitPropertyDecl(const ANode: TASTNode);

    procedure VisitRoutineDecl(const ANode: TASTNode);
    procedure VisitRoutineSigLine(const ANode: TASTNode);

    procedure VisitBeginBlock(const ANode: TASTNode;
      const ATrailSemi: Boolean);
    procedure VisitBody(const ANode: TASTNode);

    procedure VisitIfStmt(const ANode: TASTNode);
    procedure VisitWhileStmt(const ANode: TASTNode);
    procedure VisitForStmt(const ANode: TASTNode);
    procedure VisitRepeatStmt(const ANode: TASTNode);
    procedure VisitCaseStmt(const ANode: TASTNode);
    procedure VisitWithStmt(const ANode: TASTNode);
    procedure VisitTryStmt(const ANode: TASTNode);
    procedure VisitOnStmt(const ANode: TASTNode);
    procedure VisitRaiseStmt(const ANode: TASTNode);
    procedure VisitDirective(const ANode: TASTNode);
    procedure VisitExprStmt(const ANode: TASTNode);

  public
    constructor Create();
    destructor  Destroy(); override;

    function FormatTree(const ARoot: TASTNode;
      const AOptions: TDelphiFmtOptions): string;
  end;

implementation

// =============================================================================
constructor TDelphiFmtEmitter.Create();
begin
  inherited Create();
  FOutput      := TStringBuilder.Create();
  FIndent      := 0;
  FAtLineStart := True;
end;

destructor TDelphiFmtEmitter.Destroy();
begin
  FOutput.Free();
  inherited Destroy();
end;

// =============================================================================
function TDelphiFmtEmitter.FormatTree(const ARoot: TASTNode;
  const AOptions: TDelphiFmtOptions): string;
begin
  FOutput.Clear();
  FOptions     := AOptions;
  FIndent      := 0;
  FAtLineStart := True;

  case FOptions.LineBreaks.LineBreakCharacters of
    lbcCRLF : FLineBreak := #13#10;
    lbcLF   : FLineBreak := #10;
    lbcCR   : FLineBreak := #13;
  else
    FLineBreak := sLineBreak;
  end;

  if ARoot <> nil then
    VisitStmt(ARoot);

  Result := FOutput.ToString();
end;

// =============================================================================
//  Output primitives
// =============================================================================

procedure TDelphiFmtEmitter.Append(const AText: string);
begin
  if AText = '' then
    Exit;
  if FAtLineStart then
    FOutput.Append(IndentStr());
  FOutput.Append(AText);
  FAtLineStart := False;
end;

procedure TDelphiFmtEmitter.NL();
begin
  FOutput.Append(FLineBreak);
  FAtLineStart := True;
end;

procedure TDelphiFmtEmitter.BlankLines(const ACount: Integer);
var
  LClamped : Integer;
  LI       : Integer;
begin
  if not FAtLineStart then
    NL();
  LClamped := Min(ACount, FOptions.LineBreaks.MaxAdjacentEmptyLines);
  for LI := 1 to LClamped do
    NL();
end;

// =============================================================================
//  Indent helpers
// =============================================================================

procedure TDelphiFmtEmitter.IndentIn();
begin
  Inc(FIndent);
end;

procedure TDelphiFmtEmitter.IndentOut();
begin
  if FIndent > 0 then
    Dec(FIndent);
end;

function TDelphiFmtEmitter.IndentStr(): string;
var
  LStep : Integer;
begin
  LStep := FOptions.Indentation.ContinuationIndent;
  if LStep <= 0 then
    LStep := 2;
  Result := StringOfChar(' ', FIndent * LStep);
end;

// =============================================================================
//  Keyword capitalisation
// =============================================================================

function TDelphiFmtEmitter.KW(const AWord: string): string;
begin
  case FOptions.Capitalization.ReservedWordsAndDirectives of
    capUpperCase : Result := UpperCase(AWord);
    capLowerCase : Result := LowerCase(AWord);
  else
    Result := AWord;
  end;
end;

// =============================================================================
//  Attribute helpers
// =============================================================================

function TDelphiFmtEmitter.AttrStr(const ANode: TASTNode;
  const AKey: string): string;
var
  LVal : TValue;
begin
  Result := '';
  if (ANode <> nil) and ANode.GetAttr(AKey, LVal) then
    Result := LVal.ToString();
end;

function TDelphiFmtEmitter.AttrBool(const ANode: TASTNode;
  const AKey: string): Boolean;
var
  LVal : TValue;
begin
  Result := False;
  if (ANode <> nil) and ANode.GetAttr(AKey, LVal) then
    Result := LVal.AsBoolean;
end;

function TDelphiFmtEmitter.AttrInt(const ANode: TASTNode;
  const AKey: string): Integer;
var
  LVal : TValue;
begin
  Result := 0;
  if (ANode <> nil) and ANode.GetAttr(AKey, LVal) then
    Result := LVal.AsInteger;
end;

// =============================================================================
//  Child accessor
// =============================================================================

function TDelphiFmtEmitter.Ch(const ANode: TASTNode;
  const AIdx: Integer): TASTNode;
begin
  if (ANode = nil) or (AIdx < 0) or (AIdx >= ANode.ChildCount()) then
    Result := nil
  else
    Result := TASTNode(ANode.GetChild(AIdx));
end;

// =============================================================================
//  Spacing strings from FOptions
// =============================================================================

function TDelphiFmtEmitter.SpBeforeColon(): string;
begin
  if FOptions.Spacing.AroundColons in [spBeforeOnly, spBeforeAndAfter] then
    Result := ' '
  else
    Result := '';
end;

function TDelphiFmtEmitter.SpAfterColon(): string;
begin
  if FOptions.Spacing.AroundColons in [spAfterOnly, spBeforeAndAfter] then
    Result := ' '
  else
    Result := '';
end;

function TDelphiFmtEmitter.SpAroundAssign(): string;
begin
  if FOptions.Spacing.AroundAssignmentOperators in
     [spBeforeOnly, spAfterOnly, spBeforeAndAfter] then
    Result := ' '
  else
    Result := '';
end;

function TDelphiFmtEmitter.SpAroundBinOp(): string;
begin
  if FOptions.Spacing.AroundBinaryOperators in
     [spBeforeOnly, spAfterOnly, spBeforeAndAfter] then
    Result := ' '
  else
    Result := '';
end;

function TDelphiFmtEmitter.SpAfterComma(): string;
begin
  if FOptions.Spacing.AroundCommas in [spAfterOnly, spBeforeAndAfter] then
    Result := ' '
  else
    Result := '';
end;

function TDelphiFmtEmitter.SpAfterSemi(): string;
begin
  if FOptions.Spacing.AroundSemicolons in [spAfterOnly, spBeforeAndAfter] then
    Result := ' '
  else
    Result := '';
end;

// =============================================================================
//  Blank-line counts
// =============================================================================

function TDelphiFmtEmitter.BLSection(): Integer;
begin
  Result := FOptions.LineBreaks.EmptyLinesAroundSectionKeywords;
end;

function TDelphiFmtEmitter.BLDirective(): Integer;
begin
  Result := FOptions.LineBreaks.EmptyLinesAroundCompilerDirectives;
end;

function TDelphiFmtEmitter.BLVisibility(): Integer;
begin
  Result := FOptions.LineBreaks.EmptyLinesBeforeVisibilityModifiers;
end;

function TDelphiFmtEmitter.BLRoutines(const AInIntf: Boolean): Integer;
begin
  if AInIntf then
    Result := FOptions.LineBreaks.EmptyLinesSeparatorInInterface
  else
    Result := FOptions.LineBreaks.EmptyLinesSeparatorInImplementation;
end;

// =============================================================================
//  Node kind predicates
// =============================================================================

function TDelphiFmtEmitter.IsComplexTypeRef(const AKind: string): Boolean;
begin
  Result := (AKind = 'type_ref.class') or
            (AKind = 'type_ref.record') or
            (AKind = 'type_ref.interface_type') or
            (AKind = 'type_ref.object');
end;

function TDelphiFmtEmitter.IsRoutineDecl(const AKind: string): Boolean;
begin
  Result := (AKind = 'stmt.proc_decl') or
            (AKind = 'stmt.func_decl') or
            (AKind = 'stmt.constructor_decl') or
            (AKind = 'stmt.destructor_decl');
end;

// =============================================================================
//  Expression emitter — returns string, never writes FOutput
// =============================================================================

function TDelphiFmtEmitter.EmitExpr(const ANode: TASTNode): string;
var
  LKind  : string;
  LParts : TStringBuilder;
  LI     : Integer;
  LSep   : string;
  LChild : TASTNode;
  LOp    : string;
  LFmt   : string;
begin
  Result := '';
  if ANode = nil then
    Exit;

  LKind := ANode.GetNodeKind();

  // --- literals and identifiers ---
  if (LKind = 'expr.ident') or
     (LKind = 'literal.identifier') or
     LKind.StartsWith('keyword.') then
  begin
    Result := ANode.GetToken().Text;
    Exit;
  end;

  if (LKind = 'literal.integer') or
     (LKind = 'literal.real') or
     (LKind = 'literal.string') then
  begin
    Result := ANode.GetToken().Text;
    Exit;
  end;

  if LKind = 'expr.nil' then
  begin
    Result := KW(ANode.GetToken().Text);
    Exit;
  end;

  if LKind = 'expr.bool' then
  begin
    Result := KW(ANode.GetToken().Text);
    Exit;
  end;

  if LKind = 'expr.char_literal' then
  begin
    Result := '#' + AttrStr(ANode, 'char.ordinal');
    Exit;
  end;

  // --- unary ---
  if LKind = 'expr.unary' then
  begin
    LOp := AttrStr(ANode, 'op');
    if LOp = 'not' then
      Result := KW(ANode.GetToken().Text) + ' ' + EmitExpr(Ch(ANode, 0))
    else
      Result := LOp + EmitExpr(Ch(ANode, 0));
    Exit;
  end;

  // --- binary ---
  if LKind = 'expr.binary' then
  begin
    LOp := AttrStr(ANode, 'op');
    if (LOp = 'and') or (LOp = 'or') or (LOp = 'xor') or
       (LOp = 'div') or (LOp = 'mod') or (LOp = 'shl') or
       (LOp = 'shr') or (LOp = 'in') or (LOp = 'is') or (LOp = 'as') then
      Result := EmitExpr(Ch(ANode, 0)) + ' ' + KW(LOp) + ' ' +
                EmitExpr(Ch(ANode, 1))
    else
      Result := EmitExpr(Ch(ANode, 0)) + SpAroundBinOp() + LOp +
                SpAroundBinOp() + EmitExpr(Ch(ANode, 1));
    Exit;
  end;

  // --- is / as (registered separately in grammar) ---
  if (LKind = 'expr.is') or (LKind = 'expr.as') then
  begin
    LOp := AttrStr(ANode, 'op');
    if LOp = '' then
    begin
      if LKind = 'expr.is' then LOp := 'is'
                            else LOp := 'as';
    end;
    Result := EmitExpr(Ch(ANode, 0)) + ' ' + KW(LOp) + ' ' +
              EmitExpr(Ch(ANode, 1));
    Exit;
  end;

  // --- assignment ---
  if LKind = 'expr.assign' then
  begin
    Result := EmitExpr(Ch(ANode, 0)) + SpAroundAssign() +
              ':=' + SpAroundAssign() + EmitExpr(Ch(ANode, 1));
    Exit;
  end;

  // --- grouped ---
  if LKind = 'expr.grouped' then
  begin
    Result := '(' + EmitExpr(Ch(ANode, 0)) + ')';
    Exit;
  end;

  // --- address-of ---
  if LKind = 'expr.addr' then
  begin
    Result := '@' + EmitExpr(Ch(ANode, 0));
    Exit;
  end;

  // --- dereference ---
  if LKind = 'expr.deref' then
  begin
    Result := EmitExpr(Ch(ANode, 0)) + '^';
    Exit;
  end;

  // --- field access ---
  if LKind = 'expr.field_access' then
  begin
    Result := EmitExpr(Ch(ANode, 0)) + '.' + AttrStr(ANode, 'field.name');
    Exit;
  end;

  // --- array index ---
  if LKind = 'expr.array_index' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append(EmitExpr(Ch(ANode, 0)));
      LParts.Append('[');
      LSep := '';
      for LI := 1 to ANode.ChildCount() - 1 do
      begin
        LParts.Append(LSep);
        LParts.Append(EmitExpr(Ch(ANode, LI)));
        LSep := ',' + SpAfterComma();
      end;
      LParts.Append(']');
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  // --- call ---
  if LKind = 'expr.call' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append(EmitExpr(Ch(ANode, 0)));
      LParts.Append('(');
      LSep := '';
      for LI := 1 to ANode.ChildCount() - 1 do
      begin
        LChild := Ch(ANode, LI);
        if LChild.GetNodeKind() = 'expr.fmt_arg' then
        begin
          LFmt := EmitExpr(Ch(LChild, 0));
          if AttrStr(LChild, 'fmt.width') <> '' then
            LFmt := LFmt + ':' + AttrStr(LChild, 'fmt.width');
          if AttrStr(LChild, 'fmt.decimals') <> '' then
            LFmt := LFmt + ':' + AttrStr(LChild, 'fmt.decimals');
          LParts.Append(LSep + LFmt);
        end
        else
          LParts.Append(LSep + EmitExpr(LChild));
        LSep := ',' + SpAfterComma();
      end;
      LParts.Append(')');
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  // --- generic instantiation ---
  if LKind = 'expr.generic_inst' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append(EmitExpr(Ch(ANode, 0)));
      LParts.Append('<');
      LSep := '';
      for LI := 1 to ANode.ChildCount() - 1 do
      begin
        LParts.Append(LSep + Ch(ANode, LI).GetToken().Text);
        LSep := ',' + SpAfterComma();
      end;
      LParts.Append('>');
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  // --- set literal ---
  if LKind = 'expr.set_literal' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append('[');
      LSep := '';
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        LParts.Append(LSep + EmitExpr(Ch(ANode, LI)));
        LSep := ',' + SpAfterComma();
      end;
      LParts.Append(']');
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  // --- range ---
  if LKind = 'expr.range' then
  begin
    Result := EmitExpr(Ch(ANode, 0)) + '..' + EmitExpr(Ch(ANode, 1));
    Exit;
  end;

  // --- inherited ---
  if LKind = 'expr.inherited' then
  begin
    if ANode.ChildCount() > 0 then
      Result := KW(ANode.GetToken().Text) + ' ' + EmitExpr(Ch(ANode, 0))
    else
      Result := KW(ANode.GetToken().Text);
    Exit;
  end;

  // fallback: raw token text
  Result := ANode.GetToken().Text;
end;

// =============================================================================
//  Type-reference emitter — returns string, never writes FOutput
// =============================================================================

function TDelphiFmtEmitter.EmitTypeRef(const ANode: TASTNode): string;
var
  LKind  : string;
  LParts : TStringBuilder;
  LI     : Integer;
  LSep   : string;
begin
  Result := '';
  if ANode = nil then
    Exit;

  LKind := ANode.GetNodeKind();

  if LKind = 'type_ref.name' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append(AttrStr(ANode, 'type.name'));
      if AttrBool(ANode, 'type.generic') then
      begin
        LParts.Append('<');
        LSep := '';
        for LI := 0 to ANode.ChildCount() - 1 do
        begin
          LParts.Append(LSep + EmitTypeRef(Ch(ANode, LI)));
          LSep := ',' + SpAfterComma();
        end;
        LParts.Append('>');
      end;
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  if LKind = 'type_ref.string' then
  begin
    if ANode.ChildCount() > 0 then
      Result := KW(ANode.GetToken().Text) + '[' + EmitExpr(Ch(ANode, 0)) + ']'
    else
      Result := KW(ANode.GetToken().Text);
    Exit;
  end;

  if LKind = 'type_ref.pointer' then
  begin
    Result := '^' + EmitTypeRef(Ch(ANode, 0));
    Exit;
  end;

  if LKind = 'type_ref.packed' then
  begin
    Result := KW(ANode.GetToken().Text) + ' ' + EmitTypeRef(Ch(ANode, 0));
    Exit;
  end;

  if LKind = 'type_ref.type' then
  begin
    Result := KW(ANode.GetToken().Text) + ' ' + EmitTypeRef(Ch(ANode, 0));
    Exit;
  end;

  if LKind = 'type_ref.set' then
  begin
    Result := KW(ANode.GetToken().Text) + ' ' + KW(AttrStr(ANode, 'kw.of')) + ' ' + EmitTypeRef(Ch(ANode, 0));
    Exit;
  end;

  if LKind = 'type_ref.file' then
  begin
    if ANode.ChildCount() > 0 then
      Result := KW(ANode.GetToken().Text) + ' ' + KW(AttrStr(ANode, 'kw.of')) + ' ' + EmitTypeRef(Ch(ANode, 0))
    else
      Result := KW(ANode.GetToken().Text);
    Exit;
  end;

  if LKind = 'type_ref.array' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append(KW(ANode.GetToken().Text));
      if AttrStr(ANode, 'array.kind') = 'static' then
      begin
        // index types are children 0..N-2; element type is child N-1
        LParts.Append('[');
        LSep := '';
        for LI := 0 to ANode.ChildCount() - 2 do
        begin
          LParts.Append(LSep + EmitExpr(Ch(ANode, LI)));
          LSep := ',' + SpAfterComma();
        end;
        LParts.Append(']');
      end;
      LParts.Append(' ' + KW(AttrStr(ANode, 'kw.of')) + ' ');
      LParts.Append(EmitTypeRef(Ch(ANode, ANode.ChildCount() - 1)));
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  if LKind = 'type_ref.class_of' then
  begin
    Result := KW(ANode.GetToken().Text) + ' ' + KW(AttrStr(ANode, 'kw.of')) + ' ' + EmitTypeRef(Ch(ANode, 0));
    Exit;
  end;

  if LKind = 'type_ref.enum' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append('(');
      LSep := '';
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        LParts.Append(LSep + EmitExpr(Ch(ANode, LI)));
        LSep := ',' + SpAfterComma();
      end;
      LParts.Append(')');
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  if LKind = 'type_ref.procedure' then
  begin
    Result := KW(ANode.GetToken().Text);
    if (ANode.ChildCount() > 0) and
       (Ch(ANode, 0).GetNodeKind() = 'stmt.param_list') then
      Result := Result + EmitParamList(Ch(ANode, 0));
    if AttrBool(ANode, 'type.method_pointer') then
      Result := Result + ' ' + KW(AttrStr(ANode, 'kw.of')) + ' ' + KW(AttrStr(ANode, 'kw.object'));
    if AttrStr(ANode, 'type.directive') <> '' then
      Result := Result + ' ' + KW(AttrStr(ANode, 'type.directive'));
    Exit;
  end;

  if LKind = 'type_ref.function' then
  begin
    LParts := TStringBuilder.Create();
    try
      LParts.Append(KW(ANode.GetToken().Text));
      if (ANode.ChildCount() > 0) and
         (Ch(ANode, 0).GetNodeKind() = 'stmt.param_list') then
      begin
        LParts.Append(EmitParamList(Ch(ANode, 0)));
        if ANode.ChildCount() > 1 then
        begin
          LParts.Append(SpBeforeColon() + ':' + SpAfterColon());
          LParts.Append(EmitTypeRef(Ch(ANode, 1)));
        end;
      end
      else if ANode.ChildCount() > 0 then
      begin
        LParts.Append(SpBeforeColon() + ':' + SpAfterColon());
        LParts.Append(EmitTypeRef(Ch(ANode, 0)));
      end;
      if AttrBool(ANode, 'type.method_pointer') then
        LParts.Append(' ' + KW(AttrStr(ANode, 'kw.of')) + ' ' + KW(AttrStr(ANode, 'kw.object')));
      if AttrStr(ANode, 'type.directive') <> '' then
        LParts.Append(' ' + KW(AttrStr(ANode, 'type.directive')));
      Result := LParts.ToString();
    finally
      LParts.Free();
    end;
    Exit;
  end;

  if LKind = 'type_ref.reference' then
  begin
    Result := KW(ANode.GetToken().Text) + ' ' + KW(AttrStr(ANode, 'kw.to')) + ' ' +
              EmitTypeRef(Ch(ANode, 0));
    Exit;
  end;

  // class / record / interface / object — complex multi-line types;
  // these are only reached via EmitTypeRef when used inside another type ref
  // (e.g. procedure parameter typed as inline record).  Emit a placeholder
  // since full bodies are handled by VisitTypeDecl.
  Result := ANode.GetToken().Text;
end;

// =============================================================================
//  Parameter list emitter — returns string like (const A: Integer; var B: T)
// =============================================================================

function TDelphiFmtEmitter.EmitParamList(const ANode: TASTNode): string;
var
  LParts    : TStringBuilder;
  LI        : Integer;
  LGroup    : TASTNode;
  LMod      : string;
  LNames    : string;
  LNamesArr : TArray<string>;
  LJ        : Integer;
  LSep      : string;
begin
  Result := '';
  if ANode = nil then
    Exit;

  LParts := TStringBuilder.Create();
  try
    LParts.Append('(');
    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LGroup := Ch(ANode, LI);
      if LI > 0 then
        LParts.Append(';' + SpAfterSemi());

      LMod := AttrStr(LGroup, 'param.modifier');
      if LMod <> '' then
        LParts.Append(KW(LMod) + ' ');

      LNames    := AttrStr(LGroup, 'param.names');
      LNamesArr := LNames.Split([',']);
      LSep      := '';
      for LJ := 0 to High(LNamesArr) do
      begin
        LParts.Append(LSep + LNamesArr[LJ]);
        LSep := ',' + SpAfterComma();
      end;

      if LGroup.ChildCount() > 0 then
      begin
        LParts.Append(SpBeforeColon() + ':' + SpAfterColon());
        LParts.Append(EmitTypeRef(Ch(LGroup, 0)));
      end;
    end;
    LParts.Append(')');
    Result := LParts.ToString();
  finally
    LParts.Free();
  end;
end;

// =============================================================================
//  Statement dispatcher
// =============================================================================

procedure TDelphiFmtEmitter.VisitStmt(const ANode: TASTNode);
begin
  if ANode = nil then
    Exit;
  EmitLeadingComments(ANode);
  VisitStmtCore(ANode);
  // Routine declarations emit trailing comments after the signature line
  // (before the body), so skip them here to avoid duplication.
  if not IsRoutineDecl(ANode.GetNodeKind()) then
    EmitTrailingComment(ANode);
end;

procedure TDelphiFmtEmitter.EmitLeadingComments(const ANode: TASTNode);
var
  LI:      Integer;
  LComment: TASTNode;
begin
  for LI := 0 to ANode.LeadingCommentCount() - 1 do
  begin
    LComment := ANode.GetLeadingComment(LI);
    Append(LComment.GetToken().Text);
    NL();
  end;
end;

procedure TDelphiFmtEmitter.EmitTrailingComment(const ANode: TASTNode);
var
  LI:       Integer;
  LComment: TASTNode;
  LGapValue: TValue;
begin
  for LI := 0 to ANode.TrailingCommentCount() - 1 do
  begin
    LComment := ANode.GetTrailingComment(LI);
    if LComment.GetAttr('comment.gap', LGapValue) then
    begin
      if FAtLineStart and (FOutput.Length >= Length(FLineBreak)) then
      begin
        FOutput.Remove(FOutput.Length - Length(FLineBreak), Length(FLineBreak));
        FAtLineStart := False;
      end;
      Append(StringOfChar(' ', LGapValue.AsInteger()) + LComment.GetToken().Text);
    end
    else
      Append(LComment.GetToken().Text);
    NL();
  end;
end;

procedure TDelphiFmtEmitter.VisitStmtCore(const ANode: TASTNode);
var
  LKind : string;
  LI    : Integer;
begin
  if ANode = nil then
    Exit;

  LKind := ANode.GetNodeKind();

  if      LKind = 'stmt.unit'               then VisitUnit(ANode)
  else if LKind = 'stmt.program'             then VisitProgram(ANode)
  else if LKind = 'stmt.library'             then VisitLibrary(ANode)
  else if LKind = 'stmt.uses_clause'        then VisitUsesClause(ANode)
  else if LKind = 'stmt.const_block'        then VisitConstBlock(ANode)
  else if LKind = 'stmt.var_block'          then VisitVarBlock(ANode)
  else if LKind = 'stmt.threadvar_block'    then VisitVarBlock(ANode)
  else if LKind = 'stmt.type_block'         then VisitTypeBlock(ANode)
  else if IsRoutineDecl(LKind)              then VisitRoutineDecl(ANode)
  else if LKind = 'stmt.begin_block'        then VisitBeginBlock(ANode, False)
  else if LKind = 'stmt.if'                 then VisitIfStmt(ANode)
  else if LKind = 'stmt.while'              then VisitWhileStmt(ANode)
  else if LKind = 'stmt.for'                then VisitForStmt(ANode)
  else if LKind = 'stmt.repeat'             then VisitRepeatStmt(ANode)
  else if LKind = 'stmt.case'               then VisitCaseStmt(ANode)
  else if LKind = 'stmt.with'               then VisitWithStmt(ANode)
  else if LKind = 'stmt.try'                then VisitTryStmt(ANode)
  else if LKind = 'stmt.on'                 then VisitOnStmt(ANode)
  else if LKind = 'stmt.raise'              then VisitRaiseStmt(ANode)
  else if LKind = 'stmt.break'              then begin Append(KW(ANode.GetToken().Text) + ';'); NL(); end
  else if LKind = 'stmt.continue'           then begin Append(KW(ANode.GetToken().Text) + ';'); NL(); end
  else if LKind = 'stmt.exit' then
  begin
    if ANode.ChildCount() > 0 then
      Append(KW(ANode.GetToken().Text) + '(' + EmitExpr(Ch(ANode, 0)) + ');')
    else
      Append(KW(ANode.GetToken().Text) + '();');
    NL();
  end
  else if LKind = 'stmt.goto' then
  begin
    Append(KW(ANode.GetToken().Text) + ' ' + AttrStr(ANode, 'goto.label') + ';');
    NL();
  end
  else if LKind = 'stmt.label_decl' then
  begin
    Append(KW(ANode.GetToken().Text) + ' ' + AttrStr(ANode, 'label.name') + ';');
    NL();
  end
  else if LKind = 'stmt.label_mark' then
  begin
    case FOptions.Indentation.IndentLabels of
      liDecreaseOneIndent:
      begin
        IndentOut();
        Append(AttrStr(ANode, 'label.name') + ':');
        NL();
        IndentIn();
      end;
      liNoIndent:
      begin
        if not FAtLineStart then
          NL();
        FOutput.Append(AttrStr(ANode, 'label.name') + ':' + FLineBreak);
        FAtLineStart := True;
      end;
    else
      Append(AttrStr(ANode, 'label.name') + ':');
      NL();
    end;
  end
  else if LKind = 'stmt.directive'          then VisitDirective(ANode)
  else if LKind = 'stmt.visibility'         then VisitVisibility(ANode)
  else if LKind = 'stmt.field_decl'         then VisitFieldDecl(ANode)
  else if LKind = 'stmt.property_decl'      then VisitPropertyDecl(ANode)
  else if LKind = 'stmt.asm_block' then
  begin
    Append(KW(ANode.GetToken().Text));
    NL();
    Append(KW(AttrStr(ANode, 'kw.end')) + ';');
    NL();
  end
  else if LKind = 'program.root' then
  begin
    for LI := 0 to ANode.ChildCount() - 1 do
      VisitStmt(Ch(ANode, LI));
  end
  else
    VisitExprStmt(ANode);
end;

// =============================================================================
//  Unit structure
// =============================================================================

procedure TDelphiFmtEmitter.VisitUnit(const ANode: TASTNode);
var
  LUnitName : string;
  LI        : Integer;
  LChild    : TASTNode;
  LKind     : string;
begin
  LUnitName := AttrStr(ANode, 'decl.name');
  Append(KW(ANode.GetToken().Text) + ' ' + LUnitName + ';');
  NL();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := Ch(ANode, LI);
    LKind  := LChild.GetNodeKind();

    if LKind = 'stmt.directive' then
    begin
      BlankLines(BLDirective());
      EmitLeadingComments(LChild);
      VisitDirective(LChild);
      EmitTrailingComment(LChild);
    end
    else if LKind = 'stmt.unit_interface' then
    begin
      BlankLines(BLSection());
      EmitLeadingComments(LChild);
      Append(KW(AttrStr(ANode, 'kw.interface')));
      NL();
      NL();
      VisitSection(LChild, True);
      EmitTrailingComment(LChild);
    end
    else if LKind = 'stmt.unit_implementation' then
    begin
      BlankLines(BLSection());
      EmitLeadingComments(LChild);
      Append(KW(AttrStr(ANode, 'kw.implementation')));
      NL();
      NL();
      VisitSection(LChild, False);
      EmitTrailingComment(LChild);
    end
    else if LKind = 'stmt.unit_initialization' then
    begin
      BlankLines(BLSection());
      EmitLeadingComments(LChild);
      Append(KW(AttrStr(ANode, 'kw.initialization')));
      NL();
      IndentIn();
      VisitSection(LChild, False);
      IndentOut();
      EmitTrailingComment(LChild);
    end
    else if LKind = 'stmt.unit_finalization' then
    begin
      BlankLines(BLSection());
      EmitLeadingComments(LChild);
      Append(KW(AttrStr(ANode, 'kw.finalization')));
      NL();
      IndentIn();
      VisitSection(LChild, False);
      IndentOut();
      EmitTrailingComment(LChild);
    end;
  end;

  BlankLines(BLSection());
  Append(KW(AttrStr(ANode, 'kw.end')) + '.');
  NL();
end;

// =============================================================================
//  Program file
// =============================================================================

procedure TDelphiFmtEmitter.VisitProgram(const ANode: TASTNode);
var
  LName  : string;
  LI     : Integer;
  LJ     : Integer;
  LChild : TASTNode;
  LKind  : string;
begin
  LName := AttrStr(ANode, 'decl.name');
  Append(KW(ANode.GetToken().Text) + ' ' + LName + ';');
  NL();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := Ch(ANode, LI);
    LKind  := LChild.GetNodeKind();

    if LKind = 'stmt.program_body' then
    begin
      BlankLines(BLSection());
      Append(KW(AttrStr(ANode, 'kw.begin')));
      NL();
      IndentIn();
      for LJ := 0 to LChild.ChildCount() - 1 do
        VisitStmt(Ch(LChild, LJ));
      IndentOut();
    end
    else
    begin
      BlankLines(BLSection());
      VisitStmt(LChild);
    end;
  end;

  Append(KW(AttrStr(ANode, 'kw.end')) + '.');
  NL();
end;

// =============================================================================
//  Library file
// =============================================================================

procedure TDelphiFmtEmitter.VisitLibrary(const ANode: TASTNode);
var
  LName  : string;
  LI     : Integer;
  LJ     : Integer;
  LChild : TASTNode;
  LKind  : string;
begin
  LName := AttrStr(ANode, 'decl.name');
  Append(KW(ANode.GetToken().Text) + ' ' + LName + ';');
  NL();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := Ch(ANode, LI);
    LKind  := LChild.GetNodeKind();

    if LKind = 'stmt.program_body' then
    begin
      BlankLines(BLSection());
      Append(KW(AttrStr(ANode, 'kw.begin')));
      NL();
      IndentIn();
      for LJ := 0 to LChild.ChildCount() - 1 do
        VisitStmt(Ch(LChild, LJ));
      IndentOut();
    end
    else
    begin
      BlankLines(BLSection());
      VisitStmt(LChild);
    end;
  end;

  Append(KW(AttrStr(ANode, 'kw.end')) + '.');
  NL();
end;

// =============================================================================
//  Section content — drives blank-line insertion between children based on
//  node kinds from the AST (never from what was written).
// =============================================================================

procedure TDelphiFmtEmitter.VisitSection(const ANode: TASTNode;
  const AInIntf: Boolean);
var
  LI        : Integer;
  LChild    : TASTNode;
  LKind     : string;
  LPrevKind : string;
  LBlanks   : Integer;
begin
  LPrevKind := '';

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := Ch(ANode, LI);
    LKind  := LChild.GetNodeKind();

    LBlanks := 0;
    if LI > 0 then
    begin
      if LKind = 'stmt.directive' then
        LBlanks := BLDirective()
      else if IsRoutineDecl(LKind) then
        LBlanks := BLRoutines(AInIntf)
      else if (LKind = 'stmt.type_block') or
              (LKind = 'stmt.var_block') or
              (LKind = 'stmt.threadvar_block') or
              (LKind = 'stmt.const_block') or
              (LKind = 'stmt.uses_clause') then
        LBlanks := FOptions.LineBreaks.EmptyLinesSeparatorInInterface
      else
        LBlanks := 1;
    end;

    if LBlanks > 0 then
      BlankLines(LBlanks)
    else if (LI > 0) and (not FAtLineStart) then
      NL();

    VisitStmt(LChild);
    LPrevKind := LKind;
  end;
end;

// =============================================================================
//  Uses clause
// =============================================================================

procedure TDelphiFmtEmitter.VisitUsesClause(const ANode: TASTNode);
var
  LI    : Integer;
  LItem : TASTNode;
  LName : string;
  LPath : string;
begin
  Append(KW(AttrStr(ANode, 'kw.uses')));
  NL();
  IndentIn();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LItem := Ch(ANode, LI);
    LName := AttrStr(LItem, 'decl.name');
    LPath := AttrStr(LItem, 'uses.path');

    if LI < ANode.ChildCount() - 1 then
    begin
      if LPath <> '' then
        Append(LName + ' ' + KW(AttrStr(LItem, 'kw.in')) + ' ' + LPath + ',')
      else
        Append(LName + ',');
    end
    else
    begin
      if LPath <> '' then
        Append(LName + ' ' + KW(AttrStr(LItem, 'kw.in')) + ' ' + LPath + ';')
      else
        Append(LName + ';');
    end;
    NL();
  end;

  IndentOut();
end;

// =============================================================================
//  Const block
// =============================================================================

procedure TDelphiFmtEmitter.VisitConstBlock(const ANode: TASTNode);
var
  LI        : Integer;
  LDecl     : TASTNode;
  LName     : string;
  LTypeStr  : string;
  LValStr   : string;
begin
  Append(KW(ANode.GetToken().Text));
  NL();
  IndentIn();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LDecl   := Ch(ANode, LI);
    LName   := AttrStr(LDecl, 'const.name');

    if LDecl.ChildCount() = 2 then
    begin
      // Typed constant: Name: Type = Value
      LTypeStr := EmitTypeRef(Ch(LDecl, 0));
      LValStr  := EmitExpr(Ch(LDecl, 1));
      Append(LName + SpBeforeColon() + ':' + SpAfterColon() +
             LTypeStr + SpAroundBinOp() + '=' + SpAroundBinOp() + LValStr + ';');
    end
    else if LDecl.ChildCount() = 1 then
    begin
      // Untyped constant: Name = Value
      LValStr := EmitExpr(Ch(LDecl, 0));
      Append(LName + SpAroundBinOp() + '=' + SpAroundBinOp() + LValStr + ';');
    end
    else
      Append(LName + ';');

    NL();
  end;

  IndentOut();
end;

// =============================================================================
//  Var block  (also handles threadvar via same structure)
// =============================================================================

procedure TDelphiFmtEmitter.VisitVarBlock(const ANode: TASTNode);
var
  LI       : Integer;
  LDecl    : TASTNode;
  LNames   : string;
  LArr     : TArray<string>;
  LJ       : Integer;
  LSep     : string;
  LTypeStr : string;
  LKW      : string;
  LLine    : string;
begin
  if ANode.GetNodeKind() = 'stmt.threadvar_block' then
    LKW := KW(ANode.GetToken().Text)
  else
    LKW := KW(ANode.GetToken().Text);

  Append(LKW);
  NL();
  IndentIn();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LDecl    := Ch(ANode, LI);
    LNames   := AttrStr(LDecl, 'var.names');
    LArr     := LNames.Split([',']);
    LTypeStr := EmitTypeRef(Ch(LDecl, 0));

    // Build the full declaration line then emit in one Append call
    LSep  := '';
    LLine := '';
    for LJ := 0 to High(LArr) do
    begin
      LLine := LLine + LSep + LArr[LJ];
      LSep  := ',' + SpAfterComma();
    end;
    LLine := LLine + SpBeforeColon() + ':' + SpAfterColon() + LTypeStr + ';';
    Append(LLine);
    NL();
  end;

  IndentOut();
end;

// =============================================================================
//  Type block
// =============================================================================

procedure TDelphiFmtEmitter.VisitTypeBlock(const ANode: TASTNode);
var
  LI           : Integer;
  LDecl        : TASTNode;
  LTypeRef     : TASTNode;
  LCurComplex  : Boolean;
  LPrevComplex : Boolean;
  LBlanks      : Integer;
begin
  Append(KW(ANode.GetToken().Text));
  NL();
  IndentIn();

  LPrevComplex := False;

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LDecl       := Ch(ANode, LI);
    LTypeRef    := Ch(LDecl, 0);
    LCurComplex := (LTypeRef <> nil) and
                   IsComplexTypeRef(LTypeRef.GetNodeKind());

    if LI > 0 then
    begin
      if LCurComplex or LPrevComplex then
        LBlanks := FOptions.LineBreaks.EmptyLinesSeparatorInInterface
      else
        LBlanks := 0;

      if LBlanks > 0 then
        BlankLines(LBlanks)
      else if not FAtLineStart then
        NL();
    end;

    VisitTypeDecl(LDecl);
    LPrevComplex := LCurComplex;
  end;

  IndentOut();
end;

// =============================================================================
//  Single type declaration
// =============================================================================

procedure TDelphiFmtEmitter.VisitTypeDecl(const ANode: TASTNode);
var
  LName    : string;
  LTypeRef : TASTNode;
  LKind    : string;
begin
  LName    := AttrStr(ANode, 'decl.name');
  LTypeRef := Ch(ANode, 0);

  if LTypeRef = nil then
  begin
    Append(LName + ';');
    NL();
    Exit;
  end;

  LKind := LTypeRef.GetNodeKind();

  if LKind = 'type_ref.class' then
  begin
    if AttrBool(LTypeRef, 'class.forward') then
    begin
      Append(LName + SpAroundBinOp() + '=' + SpAroundBinOp() +
             KW(ANode.GetToken().Text) + ';');
      NL();
    end
    else
      VisitClassBody(LTypeRef, 'class', LName);
    Exit;
  end;

  if LKind = 'type_ref.interface_type' then
  begin
    if AttrBool(LTypeRef, 'intf.forward') then
    begin
      Append(LName + SpAroundBinOp() + '=' + SpAroundBinOp() +
             KW(ANode.GetToken().Text) + ';');
      NL();
    end
    else
      VisitClassBody(LTypeRef, 'interface', LName);
    Exit;
  end;

  if LKind = 'type_ref.record' then
  begin
    VisitClassBody(LTypeRef, 'record', LName);
    Exit;
  end;

  if LKind = 'type_ref.object' then
  begin
    VisitClassBody(LTypeRef, 'object', LName);
    Exit;
  end;

  // Simple single-line type
  if AttrStr(ANode, 'type.directive') <> '' then
    Append(LName + SpAroundBinOp() + '=' + SpAroundBinOp() +
           EmitTypeRef(LTypeRef) + '; ' + KW(AttrStr(ANode, 'type.directive')) + ';')
  else
    Append(LName + SpAroundBinOp() + '=' + SpAroundBinOp() +
           EmitTypeRef(LTypeRef) + ';');
  NL();
end;

// =============================================================================
//  Class / record / interface / object body
// =============================================================================

procedure TDelphiFmtEmitter.VisitClassBody(const ATypeNode: TASTNode;
  const AKeyword: string; const ADeclName: string);
var
  LI         : Integer;
  LChild     : TASTNode;
  LKind      : string;
  LPrevKind  : string;
  LParent    : string;
  LGuid      : string;
  LMod       : string;
  LInherList : string;
begin
  // --- header line ---
  Append(ADeclName + SpAroundBinOp() + '=' + SpAroundBinOp() + KW(AKeyword));

  LMod := AttrStr(ATypeNode, 'class.modifier');
  if LMod <> '' then
    FOutput.Append(' ' + KW(LMod));

  // Inheritance / parent
  if AKeyword = 'interface' then
    LParent := AttrStr(ATypeNode, 'intf.parent')
  else
    LParent := AttrStr(ATypeNode, 'class.parent');

  // Collect any extra interface/ancestor children that are type_ref nodes
  LInherList := LParent;
  for LI := 0 to ATypeNode.ChildCount() - 1 do
  begin
    LChild := Ch(ATypeNode, LI);
    if LChild.GetNodeKind().StartsWith('type_ref.') then
    begin
      if LInherList <> '' then
        LInherList := LInherList + ',' + SpAfterComma();
      LInherList := LInherList + EmitTypeRef(LChild);
    end;
  end;

  if LInherList <> '' then
    FOutput.Append('(' + LInherList + ')');

  LGuid := AttrStr(ATypeNode, 'intf.guid');
  if LGuid <> '' then
    FOutput.Append(' [' + LGuid + ']');

  FAtLineStart := False;
  NL();

  // --- body ---
  IndentIn();
  LPrevKind := '';

  for LI := 0 to ATypeNode.ChildCount() - 1 do
  begin
    LChild := Ch(ATypeNode, LI);
    LKind  := LChild.GetNodeKind();

    // Skip type_ref children already handled in inheritance list
    if LKind.StartsWith('type_ref.') then
    begin
      LPrevKind := LKind;
      Continue;
    end;

    // Spacing before this member (decided from AST node kinds only)
    if LI > 0 then
    begin
      if LKind = 'stmt.visibility' then
      begin
        if BLVisibility() > 0 then
          BlankLines(BLVisibility())
        else if not FAtLineStart then
          NL();
      end
      else if not FAtLineStart then
        NL();
    end;

    VisitStmt(LChild);
    LPrevKind := LKind;
  end;

  IndentOut();
  Append(KW(AttrStr(ATypeNode, 'kw.end')) + ';');
  NL();
end;

// =============================================================================
//  Visibility modifier
// =============================================================================

procedure TDelphiFmtEmitter.VisitVisibility(const ANode: TASTNode);
var
  LVis    : string;
  LStrict : Boolean;
begin
  LVis    := ANode.GetToken().Text;
  LStrict := AttrBool(ANode, 'visibility.strict');

  // Visibility sits one indent step lower than members
  IndentOut();
  if LStrict then
    Append(KW(AttrStr(ANode, 'kw.strict')) + ' ' + KW(LVis))
  else
    Append(KW(LVis));
  NL();
  IndentIn();
end;

// =============================================================================
//  Field declaration
// =============================================================================

procedure TDelphiFmtEmitter.VisitFieldDecl(const ANode: TASTNode);
var
  LNames : string;
  LArr   : TArray<string>;
  LJ     : Integer;
  LSep   : string;
  LType  : string;
  LLine  : string;
begin
  LNames := AttrStr(ANode, 'field.names');
  LArr   := LNames.Split([',']);
  LType  := EmitTypeRef(Ch(ANode, 0));

  LSep  := '';
  LLine := '';
  for LJ := 0 to High(LArr) do
  begin
    LLine := LLine + LSep + LArr[LJ];
    LSep  := ',' + SpAfterComma();
  end;
  LLine := LLine + SpBeforeColon() + ':' + SpAfterColon() + LType + ';';
  Append(LLine);
  NL();
end;

// =============================================================================
//  Property declaration
// =============================================================================

procedure TDelphiFmtEmitter.VisitPropertyDecl(const ANode: TASTNode);
var
  LPropName  : string;
  LLine      : TStringBuilder;
  LI         : Integer;
  LChild     : TASTNode;
  LKind      : string;
  LTypeIdx   : Integer;
  LReadExpr  : string;
  LWriteExpr : string;
  LHasRead   : Boolean;
  LHasWrite  : Boolean;
  LIndexed   : Boolean;
  LParamStr  : string;
begin
  LPropName := AttrStr(ANode, 'prop.name');
  LLine     := TStringBuilder.Create();
  try
    LLine.Append(KW(ANode.GetToken().Text) + ' ' + LPropName);

    LIndexed := AttrBool(ANode, 'prop.indexed');
    LTypeIdx := 0;

    if LIndexed and (ANode.ChildCount() > 0) and
       (Ch(ANode, 0).GetNodeKind() = 'stmt.param_list') then
    begin
      // Strip outer parens from param list and wrap in [ ]
      LParamStr := EmitParamList(Ch(ANode, 0));
      LLine.Append('[' + Copy(LParamStr, 2, Length(LParamStr) - 2) + ']');
      LTypeIdx := 1;
    end;

    // Type child
    if (LTypeIdx < ANode.ChildCount()) then
    begin
      LChild := Ch(ANode, LTypeIdx);
      LKind  := LChild.GetNodeKind();
      if LKind.StartsWith('type_ref.') then
      begin
        LLine.Append(SpBeforeColon() + ':' + SpAfterColon());
        LLine.Append(EmitTypeRef(LChild));
        Inc(LTypeIdx);
      end;
    end;

    // read / write specifiers are expression children after the type
    LHasRead  := AttrStr(ANode, 'prop.read') <> '';
    LHasWrite := AttrStr(ANode, 'prop.write') <> '';
    LReadExpr  := '';
    LWriteExpr := '';

    for LI := LTypeIdx to ANode.ChildCount() - 1 do
    begin
      LChild := Ch(ANode, LI);
      if LHasRead and (LReadExpr = '') then
        LReadExpr := EmitExpr(LChild)
      else if LHasWrite and (LWriteExpr = '') then
        LWriteExpr := EmitExpr(LChild);
    end;

    if LReadExpr <> '' then
      LLine.Append(' ' + KW(AttrStr(ANode, 'prop.read')) + ' ' + LReadExpr);
    if LWriteExpr <> '' then
      LLine.Append(' ' + KW(AttrStr(ANode, 'prop.write')) + ' ' + LWriteExpr);

    LLine.Append(';');
    Append(LLine.ToString());
    NL();
  finally
    LLine.Free();
  end;
end;

// =============================================================================
//  Routine declaration
// =============================================================================

procedure TDelphiFmtEmitter.VisitRoutineDecl(const ANode: TASTNode);
var
  LI         : Integer;
  LChild     : TASTNode;
  LKind      : string;
  LBodyIdx   : Integer;
begin
  VisitRoutineSigLine(ANode);
  EmitTrailingComment(ANode);

  LBodyIdx := -1;

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := Ch(ANode, LI);
    LKind  := LChild.GetNodeKind();

    if LKind = 'stmt.routine_directive' then
    begin
      // Directive: inline on same line as signature
      FOutput.Append(' ' + KW(AttrStr(LChild, 'directive.text')));
      // External lib/name specifiers
      if AttrStr(LChild, 'directive.lib') <> '' then
        FOutput.Append(' ' + AttrStr(LChild, 'directive.lib'));
      if AttrStr(LChild, 'directive.ext_name') <> '' then
        FOutput.Append(' ' + KW(ANode.GetToken().Text) + ' ' +
                       AttrStr(LChild, 'directive.ext_name'));
      FOutput.Append(';');
      FAtLineStart := False;
    end
    else if (LKind = 'stmt.var_block') or
            (LKind = 'stmt.threadvar_block') or
            (LKind = 'stmt.const_block') or
            (LKind = 'stmt.type_block') or
            (LKind = 'stmt.label_decl') or
            (LKind = 'stmt.directive') then
    begin
      if not FAtLineStart then
        NL();
      VisitStmt(LChild);
    end
    else if (LKind = 'stmt.begin_block') or (LKind = 'stmt.asm_block') then
    begin
      LBodyIdx := LI;
    end;
  end;

  // Ensure signature/directives line is closed before body
  if not FAtLineStart then
    NL();

  // Emit begin..end body with trailing semicolon
  if LBodyIdx >= 0 then
    VisitBeginBlock(Ch(ANode, LBodyIdx), True);
end;

// =============================================================================
//  Routine signature line
// =============================================================================

procedure TDelphiFmtEmitter.VisitRoutineSigLine(const ANode: TASTNode);
var
  LKind     : string;
  LDeclKind : string;
  LName     : string;
  LLine     : TStringBuilder;
  LI        : Integer;
  LChild    : TASTNode;
  LRetType  : TASTNode;
begin
  LKind     := ANode.GetNodeKind();
  LDeclKind := AttrStr(ANode, 'decl.kind');
  LName     := AttrStr(ANode, 'decl.name');

  LLine := TStringBuilder.Create();
  try
    LLine.Append(KW(LDeclKind) + ' ' + LName);

    LRetType := nil;
    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LChild := Ch(ANode, LI);
      if LChild.GetNodeKind() = 'stmt.param_list' then
        LLine.Append(EmitParamList(LChild))
      else if LChild.GetNodeKind().StartsWith('type_ref.') then
        LRetType := LChild;
    end;

    if (LKind = 'stmt.func_decl') and (LRetType <> nil) then
    begin
      LLine.Append(SpBeforeColon() + ':' + SpAfterColon());
      LLine.Append(EmitTypeRef(LRetType));
    end;

    LLine.Append(';');
    Append(LLine.ToString());
  finally
    LLine.Free();
  end;
end;

// =============================================================================
//  Begin..end block
// =============================================================================

procedure TDelphiFmtEmitter.VisitBeginBlock(const ANode: TASTNode;
  const ATrailSemi: Boolean);
var
  LI    : Integer;
begin
  Append(KW(ANode.GetToken().Text));
  NL();
  IndentIn();

  for LI := 0 to ANode.ChildCount() - 1 do
    VisitStmt(Ch(ANode, LI));

  IndentOut();

  if ATrailSemi then
  begin
    Append(KW(AttrStr(ANode, 'kw.end')) + ';');
    NL();
  end
  else
  begin
    // Caller decides whether to add ';' via VisitBody
    Append(KW(AttrStr(ANode, 'kw.end')));
    FAtLineStart := False;
  end;
end;

// =============================================================================
//  Body helper: emit a control-flow body and add ';' after end when it is
//  a begin..end block (required by Delphi syntax).
// =============================================================================

procedure TDelphiFmtEmitter.VisitBody(const ANode: TASTNode);
begin
  if ANode = nil then
    Exit;

  if ANode.GetNodeKind() = 'stmt.begin_block' then
  begin
    VisitBeginBlock(ANode, False);
    FOutput.Append(';');
    FAtLineStart := False;
    NL();
  end
  else
  begin
    IndentIn();
    VisitStmt(ANode);
    IndentOut();
  end;
end;

// =============================================================================
//  Control flow statements
// =============================================================================

procedure TDelphiFmtEmitter.VisitIfStmt(const ANode: TASTNode);
var
  LCond     : TASTNode;
  LThen     : TASTNode;
  LElse     : TASTNode;
  LThenKind : string;
  LElseKind : string;
begin
  LCond := Ch(ANode, 0);
  LThen := Ch(ANode, 1);
  LElse := nil;
  if ANode.ChildCount() > 2 then
    LElse := Ch(ANode, 2);

  Append(KW(ANode.GetToken().Text) + ' ' + EmitExpr(LCond) + ' ' + KW(AttrStr(ANode, 'kw.then')));

  // --- then branch ---
  LThenKind := LThen.GetNodeKind();
  if LThenKind = 'stmt.begin_block' then
  begin
    NL();
    VisitBeginBlock(LThen, False);
  end
  else
  begin
    NL();
    IndentIn();
    VisitStmt(LThen);
    IndentOut();
  end;

  // --- else branch ---
  if LElse <> nil then
  begin
    LElseKind := LElse.GetNodeKind();
    // Ensure we are on a fresh line before 'else'
    if not FAtLineStart then
      NL();

    if LElseKind = 'stmt.if' then
    begin
      // else if — emit on the same line, recurse
      Append(KW(AttrStr(ANode, 'kw.else')) + ' ');
      VisitIfStmt(LElse);
    end
    else if LElseKind = 'stmt.begin_block' then
    begin
      Append(KW(AttrStr(ANode, 'kw.else')));
      NL();
      VisitBeginBlock(LElse, False);
      FOutput.Append(';');
      FAtLineStart := False;
      NL();
    end
    else
    begin
      // single-statement else — indent one level
      Append(KW(AttrStr(ANode, 'kw.else')));
      NL();
      IndentIn();
      VisitStmt(LElse);
      IndentOut();
    end;
  end
  else
  begin
    // No else — close the then branch
    if LThenKind = 'stmt.begin_block' then
    begin
      FOutput.Append(';');
      FAtLineStart := False;
      NL();
    end;
  end;
end;

procedure TDelphiFmtEmitter.VisitWhileStmt(const ANode: TASTNode);
begin
  Append(KW(ANode.GetToken().Text) + ' ' + EmitExpr(Ch(ANode, 0)) + ' ' + KW(AttrStr(ANode, 'kw.do')));
  NL();
  VisitBody(Ch(ANode, 1));
end;

procedure TDelphiFmtEmitter.VisitForStmt(const ANode: TASTNode);
var
  LVar   : string;
  LKind  : string;
  LDir   : string;
  LBody  : TASTNode;
begin
  LVar  := AttrStr(ANode, 'for.var');
  LKind := AttrStr(ANode, 'for.kind');

  if LKind = 'in' then
  begin
    Append(KW(ANode.GetToken().Text) + ' ' + LVar + ' ' + KW(AttrStr(ANode, 'kw.in')) + ' ' +
           EmitExpr(Ch(ANode, 0)) + ' ' + KW(AttrStr(ANode, 'kw.do')));
    LBody := Ch(ANode, 1);
  end
  else
  begin
    LDir := AttrStr(ANode, 'for.dir');
    Append(KW(ANode.GetToken().Text) + ' ' + LVar + SpAroundAssign() +
           ':=' + SpAroundAssign() +
           EmitExpr(Ch(ANode, 0)) + ' ' + KW(LDir) + ' ' +
           EmitExpr(Ch(ANode, 1)) + ' ' + KW(AttrStr(ANode, 'kw.do')));
    LBody := Ch(ANode, 2);
  end;

  NL();
  VisitBody(LBody);
end;

procedure TDelphiFmtEmitter.VisitRepeatStmt(const ANode: TASTNode);
var
  LI     : Integer;
  LUntil : TASTNode;
begin
  Append(KW(ANode.GetToken().Text));
  NL();
  IndentIn();

  for LI := 0 to ANode.ChildCount() - 2 do
    VisitStmt(Ch(ANode, LI));

  IndentOut();
  LUntil := Ch(ANode, ANode.ChildCount() - 1);
  Append(KW(AttrStr(ANode, 'kw.until')) + ' ' + EmitExpr(LUntil) + ';');
  NL();
end;

procedure TDelphiFmtEmitter.VisitCaseStmt(const ANode: TASTNode);
var
  LI        : Integer;
  LChild    : TASTNode;
  LKind     : string;
  LLabelCnt : Integer;
  LLabelStr : string;
  LJ        : Integer;
  LSep      : string;
  LBody     : TASTNode;
  LHasElse  : Boolean;
begin
  Append(KW(ANode.GetToken().Text) + ' ' + EmitExpr(Ch(ANode, 0)) + ' ' + KW(AttrStr(ANode, 'kw.of')));
  NL();
  IndentIn();

  LHasElse := False;

  for LI := 1 to ANode.ChildCount() - 1 do
  begin
    LChild := Ch(ANode, LI);
    LKind  := LChild.GetNodeKind();

    if LKind = 'stmt.case_arm' then
    begin
      LLabelCnt := AttrInt(LChild, 'case.label_count');
      if LLabelCnt = 0 then
        LLabelCnt := LChild.ChildCount() - 1;

      LSep      := '';
      LLabelStr := '';
      for LJ := 0 to LLabelCnt - 1 do
      begin
        LLabelStr := LLabelStr + LSep + EmitExpr(Ch(LChild, LJ));
        LSep := ',' + SpAfterComma();
      end;

      LBody := Ch(LChild, LLabelCnt);
      Append(LLabelStr + ':');
      NL();
      IndentIn();
      VisitBody(LBody);
      IndentOut();
    end
    else if LKind = 'stmt.case_else' then
    begin
      LHasElse := True;
      IndentOut();
      Append(KW(LChild.GetToken().Text));
      NL();
      IndentIn();
      for LJ := 0 to LChild.ChildCount() - 1 do
        VisitBody(Ch(LChild, LJ));
      IndentOut();
    end;
  end;

  if not LHasElse then
    IndentOut();
  Append(KW(AttrStr(ANode, 'kw.end')) + ';');
  NL();
end;

procedure TDelphiFmtEmitter.VisitWithStmt(const ANode: TASTNode);
var
  LLine : TStringBuilder;
  LI    : Integer;
  LBody : TASTNode;
begin
  LLine := TStringBuilder.Create();
  try
    LLine.Append(KW(ANode.GetToken().Text) + ' ');
    for LI := 0 to ANode.ChildCount() - 2 do
    begin
      if LI > 0 then
        LLine.Append(',' + SpAfterComma());
      LLine.Append(EmitExpr(Ch(ANode, LI)));
    end;
    LLine.Append(' ' + KW(AttrStr(ANode, 'kw.do')));
    Append(LLine.ToString());
  finally
    LLine.Free();
  end;

  NL();
  LBody := Ch(ANode, ANode.ChildCount() - 1);
  VisitBody(LBody);
end;

procedure TDelphiFmtEmitter.VisitTryStmt(const ANode: TASTNode);
var
  LI     : Integer;
  LChild : TASTNode;
  LKind  : string;
  LJ     : Integer;
begin
  Append(KW(ANode.GetToken().Text));
  NL();
  IndentIn();

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := Ch(ANode, LI);
    LKind  := LChild.GetNodeKind();

    if LKind = 'stmt.try_body' then
    begin
      for LJ := 0 to LChild.ChildCount() - 1 do
        VisitStmt(Ch(LChild, LJ));
    end
    else if LKind = 'stmt.except_body' then
    begin
      IndentOut();
      Append(KW(LChild.GetToken().Text));
      NL();
      IndentIn();
      for LJ := 0 to LChild.ChildCount() - 1 do
        VisitStmt(Ch(LChild, LJ));
    end
    else if LKind = 'stmt.finally_body' then
    begin
      IndentOut();
      Append(KW(LChild.GetToken().Text));
      NL();
      IndentIn();
      for LJ := 0 to LChild.ChildCount() - 1 do
        VisitStmt(Ch(LChild, LJ));
    end;
  end;

  IndentOut();
  Append(KW(AttrStr(ANode, 'kw.end')) + ';');
  NL();
end;

procedure TDelphiFmtEmitter.VisitOnStmt(const ANode: TASTNode);
var
  LVarName  : string;
  LTypeName : string;
  LTypeRef  : TASTNode;
  LBody     : TASTNode;
begin
  LVarName  := AttrStr(ANode, 'on.var_name');
  LTypeName := AttrStr(ANode, 'on.type_name');

  LTypeRef := nil;
  LBody    := nil;

  if ANode.ChildCount() = 2 then
  begin
    LTypeRef := Ch(ANode, 0);
    LBody    := Ch(ANode, 1);
  end
  else if ANode.ChildCount() = 1 then
    LBody := Ch(ANode, 0);

  if LVarName <> '' then
    Append(KW(ANode.GetToken().Text) + ' ' + LVarName + SpBeforeColon() + ':' +
           SpAfterColon() + EmitTypeRef(LTypeRef) + ' ' + KW(AttrStr(ANode, 'kw.do')))
  else
    Append(KW(ANode.GetToken().Text) + ' ' + LTypeName + ' ' + KW(AttrStr(ANode, 'kw.do')));

  NL();
  if LBody <> nil then
    VisitBody(LBody);
end;

procedure TDelphiFmtEmitter.VisitRaiseStmt(const ANode: TASTNode);
begin
  if ANode.ChildCount() > 0 then
    Append(KW(ANode.GetToken().Text) + ' ' + EmitExpr(Ch(ANode, 0)) + ';')
  else
    Append(KW(ANode.GetToken().Text) + ';');
  NL();
end;

// =============================================================================
//  Compiler directive
// =============================================================================

procedure TDelphiFmtEmitter.VisitDirective(const ANode: TASTNode);
var
  LRaw : string;
begin
  LRaw := AttrStr(ANode, 'directive.raw');

  case FOptions.Capitalization.CompilerDirectives of
    capUpperCase : LRaw := UpperCase(LRaw);
    capLowerCase : LRaw := LowerCase(LRaw);
  else
    // capAsIs / capAsFirstOccurrence — leave as-is
  end;

  if FOptions.Indentation.IndentCompilerDirectives then
    Append(LRaw)
  else
  begin
    // Directives at column 0 regardless of indent
    if not FAtLineStart then
      NL();
    FOutput.Append(LRaw + FLineBreak);
    FAtLineStart := True;
  end;
end;

// =============================================================================
//  Expression statement
// =============================================================================

procedure TDelphiFmtEmitter.VisitExprStmt(const ANode: TASTNode);
begin
  if (ANode.GetNodeKind() = 'stmt.expr') and (ANode.ChildCount() > 0) then
    Append(EmitExpr(Ch(ANode, 0)) + ';')
  else
    Append(EmitExpr(ANode) + ';');
  NL();
end;

end.
