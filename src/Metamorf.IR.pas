{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.IR;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.Common,
  Metamorf.LangConfig;

type

  { TIR }
  TIR = class(TIRBase)
  private
    FHeaderBuffer:     TStringBuilder;
    FSourceBuffer:     TStringBuilder;
    FIndentLevel:      Integer;
    FConfig:           TLangConfig;  // not owned
    FInFuncSignature:  Boolean;  // True between Func() and first statement/EndFunc
    FContext:          TDictionary<string, string>;  // key/value context store for emitters
    FLineDirectives:   Boolean;  // When True, #line directives are emitted before each node
    FLastLineFile:     string;   // Filename of the last emitted #line directive
    FLastLineNum:      Integer;  // Line number of the last emitted #line directive

    // Returns the buffer for the given target
    function GetBuffer(const ATarget: TSourceFile): TStringBuilder;

    // Returns the current indentation string (2 spaces per level)
    function GetIndent(): string;

    // Closes the function signature with ) { if still open
    procedure CloseFuncSignature();

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Configuration — must be set before Generate()
    procedure SetConfig(const AConfig: TLangConfig);

    // Enable or disable #line directive emission into the source buffer.
    // When enabled, a #line N "file" is written before each dispatched node.
    procedure SetLineDirectives(const AEnabled: Boolean);

    // ---- TIRBase virtuals (low-level primitives) ----

    // Append indent + AText + newline
    procedure EmitLine(const AText: string; const ATarget: TSourceFile = sfSource); overload; override;
    procedure EmitLine(const AText: string; const AArgs: array of const; const ATarget: TSourceFile = sfSource); overload; override;

    // Append AText verbatim — no indent, no newline
    procedure Emit(const AText: string; const ATarget: TSourceFile = sfSource); overload; override;
    procedure Emit(const AText: string; const AArgs: array of const; const ATarget: TSourceFile = sfSource); overload; override;

    // Append AText truly verbatim (for $cppstart/$cpp escape hatch blocks)
    procedure EmitRaw(const AText: string; const ATarget: TSourceFile = sfSource); overload; override;
    procedure EmitRaw(const AText: string; const AArgs: array of const; const ATarget: TSourceFile = sfSource); overload; override;

    // Indentation control
    procedure IndentIn(); override;
    procedure IndentOut(); override;

    // AST dispatch — walks tree via registered TEmitHandler callbacks
    procedure EmitNode(const ANode: TASTNodeBase); override;
    procedure EmitChildren(const ANode: TASTNodeBase); override;

    // ---- Top-level declarations (fluent) ----

    // #include <AName> or #include "AName"
    function Include(const AHeaderName: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; override;

    // struct AName { ... };
    function Struct(const AStructName: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; override;

    // Field inside a Struct context
    function AddField(const AFieldName, AFieldType: string): TIRBase; override;

    // };  — closes Struct
    function EndStruct(): TIRBase; override;

    // constexpr auto AName = AValueExpr;
    function DeclConst(const AConstName, AConstType, AValueExpr: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; override;

    // static AType AName = AInitExpr;
    function Global(const AGlobalName, AGlobalType, AInitExpr: string;
      const ATarget: TSourceFile = sfSource): TIRBase; override;

    // using AAlias = AOriginal;
    function Using(const AAlias, AOriginal: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; override;

    // namespace AName {
    function Namespace(const ANamespaceName: string;
      const ATarget: TSourceFile = sfHeader): TIRBase; override;

    // } // namespace
    function EndNamespace(
      const ATarget: TSourceFile = sfHeader): TIRBase; override;

    // extern "C" AReturnType AName(AParams...);
    function ExternC(const AFuncName, AReturnType: string;
      const AParams: TArray<TArray<string>>;
      const ATarget: TSourceFile = sfHeader): TIRBase; override;

    // ---- Function / method builder (fluent) ----

    // AReturnType AName(...)  {
    function Func(const AFuncName, AReturnType: string): TIRBase; override;

    // Parameter inside Func context
    function Param(const AParamName, AParamType: string): TIRBase; override;

    // }  — closes Func, emits the complete function
    function EndFunc(): TIRBase; override;

    // ---- Statement methods inside Func context (fluent) ----

    // Local variable:  AType AName;
    function DeclVar(const AVarName, AVarType: string): TIRBase; overload; override;
    // Local variable:  AType AName = AInitExpr;
    function DeclVar(const AVarName, AVarType, AInitExpr: string): TIRBase; overload; override;

    // Assignment:  ALhs = AExpr;
    function Assign(const ALhs, AExpr: string): TIRBase; override;

    // Expression lhs assignment:  ATargetExpr = AValueExpr;
    function AssignTo(const ATargetExpr, AValueExpr: string): TIRBase; override;

    // Statement-form call:  AFunc(AArgs...);
    function Call(const AFuncName: string;
      const AArgs: TArray<string>): TIRBase; override;

    // Verbatim C++ statement line
    function Stmt(const ARawText: string): TIRBase; overload; override;
    function Stmt(const ARawText: string; const AArgs: array of const): TIRBase; overload; override;

    // return;
    function Return(): TIRBase; overload; override;
    // return AExpr;
    function Return(const AExpr: string): TIRBase; overload; override;

    // if (ACond) {
    function IfStmt(const ACondExpr: string): TIRBase; override;

    // } else if (ACond) {
    function ElseIfStmt(const ACondExpr: string): TIRBase; override;

    // } else {
    function ElseStmt(): TIRBase; override;

    // }  — closes if/else chain
    function EndIf(): TIRBase; override;

    // while (ACond) {
    function WhileStmt(const ACondExpr: string): TIRBase; override;

    // }  — closes while
    function EndWhile(): TIRBase; override;

    // for (auto AVar = AInit; ACond; AStep) {
    function ForStmt(const AVarName, AInitExpr, ACondExpr,
      AStepExpr: string): TIRBase; override;

    // }  — closes for
    function EndFor(): TIRBase; override;

    // break;
    function BreakStmt(): TIRBase; override;

    // continue;
    function ContinueStmt(): TIRBase; override;

    // Emit a blank line
    function BlankLine(
      const ATarget: TSourceFile = sfSource): TIRBase; override;

    // ---- Expression builders (return string — C++23 text fragments) ----

    // Literals
    function Lit(const AValue: Integer): string; overload; override;
    function Lit(const AValue: Int64): string; overload; override;
    function Float(const AValue: Double): string; override;
    function Str(const AValue: string): string; override;
    function Bool(const AValue: Boolean): string; override;
    function Null(): string; override;

    // Variable / member access
    function Get(const AVarName: string): string; override;
    function Field(const AObj, AMember: string): string; override;
    function Deref(const APtr, AMember: string): string; overload; override;
    function Deref(const APtr: string): string; overload; override;
    function AddrOf(const AVarName: string): string; override;
    function Index(const AArr, AIndexExpr: string): string; override;
    function Cast(const ATypeName, AExpr: string): string; override;

    // Expression-form call:  AFunc(AArgs...)  — returns string, no semicolon
    function Invoke(const AFuncName: string;
      const AArgs: TArray<string>): string; override;

    // Arithmetic
    function Add(const ALeft, ARight: string): string; override;
    function Sub(const ALeft, ARight: string): string; override;
    function Mul(const ALeft, ARight: string): string; override;
    function DivExpr(const ALeft, ARight: string): string; override;
    function ModExpr(const ALeft, ARight: string): string; override;
    function Neg(const AExpr: string): string; override;

    // Comparison
    function Eq(const ALeft, ARight: string): string; override;
    function Ne(const ALeft, ARight: string): string; override;
    function Lt(const ALeft, ARight: string): string; override;
    function Le(const ALeft, ARight: string): string; override;
    function Gt(const ALeft, ARight: string): string; override;
    function Ge(const ALeft, ARight: string): string; override;

    // Logical
    function AndExpr(const ALeft, ARight: string): string; override;
    function OrExpr(const ALeft, ARight: string): string; override;
    function NotExpr(const AExpr: string): string; override;

    // Bitwise
    function BitAnd(const ALeft, ARight: string): string; override;
    function BitOr(const ALeft, ARight: string): string; override;
    function BitXor(const ALeft, ARight: string): string; override;
    function BitNot(const AExpr: string): string; override;
    function ShlExpr(const ALeft, ARight: string): string; override;
    function ShrExpr(const ALeft, ARight: string): string; override;

    // ---- AST walk entry point ----

    // Walks the enriched AST and dispatches registered TEmitHandler
    // callbacks from TLangConfig. Called by the compiler pipeline
    // after TSemantics.Analyze().
    function Generate(const ARoot: TASTNodeBase): Boolean;

    // ---- Output ----

    // Write header and source buffers to disk.
    // The .cpp automatically receives:  #include "headerfilename.h"
    procedure SaveToFiles(const AHeaderPath, ASourcePath: string);

    // Direct access to generated content
    function GetHeaderContent(): string;
    function GetSourceContent(): string;

    // Context store — for emitter handlers to share state (e.g. current function name)
    procedure SetContext(const AKey, AValue: string); override;
    function  GetContext(const AKey: string; const ADefault: string = ''): string; override;

    // Debug
    function Dump(const AId: Integer = 0): string; override;
  end;

implementation

{ TIR }

constructor TIR.Create();
begin
  inherited;
  FHeaderBuffer    := TStringBuilder.Create();
  FSourceBuffer    := TStringBuilder.Create();
  FIndentLevel     := 0;
  FConfig          := nil;
  FInFuncSignature := False;
  FContext         := TDictionary<string, string>.Create();
  FLineDirectives  := False;
  FLastLineFile     := '';
  FLastLineNum      := 0;
end;

destructor TIR.Destroy();
begin
  FreeAndNil(FContext);
  FreeAndNil(FSourceBuffer);
  FreeAndNil(FHeaderBuffer);
  inherited;
end;

procedure TIR.SetConfig(const AConfig: TLangConfig);
begin
  FConfig := AConfig;
end;

procedure TIR.SetLineDirectives(const AEnabled: Boolean);
begin
  FLineDirectives := AEnabled;
end;

function TIR.GetBuffer(
  const ATarget: TSourceFile): TStringBuilder;
begin
  if ATarget = sfHeader then
    Result := FHeaderBuffer
  else
    Result := FSourceBuffer;
end;

function TIR.GetIndent(): string;
begin
  Result := StringOfChar(' ', FIndentLevel * 2);
end;

procedure TIR.CloseFuncSignature();
begin
  if FInFuncSignature then
  begin
    FInFuncSignature := False;
    FSourceBuffer.AppendLine(') {');
    IndentIn();
  end;
end;

// ---- TIRBase virtuals (low-level primitives) ----

procedure TIR.EmitLine(const AText: string;
  const ATarget: TSourceFile);
begin
  GetBuffer(ATarget).AppendLine(GetIndent() + AText);
end;

procedure TIR.EmitLine(const AText: string;
  const AArgs: array of const; const ATarget: TSourceFile);
begin
  EmitLine(Format(AText, AArgs), ATarget);
end;

procedure TIR.Emit(const AText: string;
  const ATarget: TSourceFile);
begin
  GetBuffer(ATarget).Append(AText);
end;

procedure TIR.Emit(const AText: string;
  const AArgs: array of const; const ATarget: TSourceFile);
begin
  Emit(Format(AText, AArgs), ATarget);
end;

procedure TIR.EmitRaw(const AText: string;
  const ATarget: TSourceFile);
begin
  GetBuffer(ATarget).Append(AText);
end;

procedure TIR.EmitRaw(const AText: string;
  const AArgs: array of const; const ATarget: TSourceFile);
begin
  EmitRaw(Format(AText, AArgs), ATarget);
end;

procedure TIR.IndentIn();
begin
  Inc(FIndentLevel);
end;

procedure TIR.IndentOut();
begin
  if FIndentLevel > 0 then
    Dec(FIndentLevel);
end;

procedure TIR.EmitNode(const ANode: TASTNodeBase);
var
  LHandler:  TEmitHandler;
  LTok:      TToken;
  LFilename: string;
begin
  if ANode = nil then
    Exit;

  // Emit a #line directive so debuggers map generated C++ back to the Pascal source.
  // Written directly to the buffer at column 0 — preprocessor directives must
  // never be indented.
  if FLineDirectives and not FInFuncSignature then
  begin
    LTok := ANode.GetToken();
    if (LTok.Filename <> '') and (LTok.Line > 0) then
    begin
      LFilename := LTok.Filename.Replace('\', '/');
      // Only emit when the location actually changes — avoids duplicate
      // #line directives from container nodes sharing the same source position.
      if (LFilename <> FLastLineFile) or (LTok.Line <> FLastLineNum) then
      begin
        FLastLineFile := LFilename;
        FLastLineNum  := LTok.Line;
        FSourceBuffer.AppendLine('#line ' + IntToStr(LTok.Line) +
          ' "' + LFilename + '"');
      end;
    end;
  end;

  // Look up a registered handler for this node kind
  if (FConfig <> nil) and FConfig.GetEmitHandler(ANode.GetNodeKind(), LHandler) then
    LHandler(ANode, Self)
  else
    // No handler registered — auto-walk children
    EmitChildren(ANode);
end;

procedure TIR.EmitChildren(const ANode: TASTNodeBase);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;

  for LI := 0 to ANode.ChildCount() - 1 do
    EmitNode(ANode.GetChild(LI));
end;

// ---- Top-level declarations ----

function TIR.Include(const AHeaderName: string;
  const ATarget: TSourceFile): TIRBase;
begin
  // Standard library headers use <>, everything else uses ""
  if (AHeaderName <> '') and (AHeaderName[1] <> '"') and (AHeaderName[1] <> '<') then
    EmitLine('#include <' + AHeaderName + '>', ATarget)
  else
    EmitLine('#include ' + AHeaderName, ATarget);
  Result := Self;
end;

function TIR.Struct(const AStructName: string;
  const ATarget: TSourceFile): TIRBase;
begin
  EmitLine('struct ' + AStructName + ' {', ATarget);
  IndentIn();
  Result := Self;
end;

function TIR.AddField(const AFieldName,
  AFieldType: string): TIRBase;
begin
  // Fields always go to whatever target the Struct was opened on.
  // Since we don't track target stack, fields emit to sfHeader (struct default).
  EmitLine(AFieldType + ' ' + AFieldName + ';', sfHeader);
  Result := Self;
end;

function TIR.EndStruct(): TIRBase;
begin
  IndentOut();
  EmitLine('};', sfHeader);
  Result := Self;
end;

function TIR.DeclConst(const AConstName, AConstType,
  AValueExpr: string; const ATarget: TSourceFile): TIRBase;
begin
  if AConstType = '' then
    EmitLine('constexpr auto ' + AConstName + ' = ' + AValueExpr + ';', ATarget)
  else
    EmitLine('constexpr ' + AConstType + ' ' + AConstName + ' = ' + AValueExpr + ';', ATarget);
  Result := Self;
end;

function TIR.Global(const AGlobalName, AGlobalType,
  AInitExpr: string; const ATarget: TSourceFile): TIRBase;
begin
  if AInitExpr = '' then
    EmitLine(AGlobalType + ' ' + AGlobalName + ';', ATarget)
  else
    EmitLine(AGlobalType + ' ' + AGlobalName + ' = ' + AInitExpr + ';', ATarget);
  Result := Self;
end;

function TIR.Using(const AAlias, AOriginal: string;
  const ATarget: TSourceFile): TIRBase;
begin
  EmitLine('using ' + AAlias + ' = ' + AOriginal + ';', ATarget);
  Result := Self;
end;

function TIR.Namespace(const ANamespaceName: string;
  const ATarget: TSourceFile): TIRBase;
begin
  EmitLine('namespace ' + ANamespaceName + ' {', ATarget);
  IndentIn();
  Result := Self;
end;

function TIR.EndNamespace(
  const ATarget: TSourceFile): TIRBase;
begin
  IndentOut();
  EmitLine('} // namespace', ATarget);
  Result := Self;
end;

function TIR.ExternC(const AFuncName, AReturnType: string;
  const AParams: TArray<TArray<string>>;
  const ATarget: TSourceFile): TIRBase;
var
  LParamList: string;
  LI: Integer;
begin
  LParamList := '';
  for LI := 0 to Length(AParams) - 1 do
  begin
    if LI > 0 then
      LParamList := LParamList + ', ';
    // Each param is [name, type]
    LParamList := LParamList + AParams[LI][1] + ' ' + AParams[LI][0];
  end;

  EmitLine('extern "C" ' + AReturnType + ' ' + AFuncName +
    '(' + LParamList + ');', ATarget);
  Result := Self;
end;

// ---- Function / method builder ----

function TIR.Func(const AFuncName,
  AReturnType: string): TIRBase;
begin
  // Emit the function signature opening — params follow via Param() calls.
  // We buffer the signature and emit the opening brace at the first
  // statement or at EndFunc if no params.
  // Simple approach: emit return type + name, then track state.
  // For simplicity, we emit the signature line-by-line.
  FInFuncSignature := True;
  Emit(GetIndent() + AReturnType + ' ' + AFuncName + '(', sfSource);
  Result := Self;
end;

function TIR.Param(const AParamName,
  AParamType: string): TIRBase;
begin
  // Params are accumulated inline on the signature line.
  // First param has no comma, subsequent ones do.
  if FSourceBuffer.Length > 0 then
  begin
    if FSourceBuffer.Chars[FSourceBuffer.Length - 1] = '(' then
      Emit(AParamType + ' ' + AParamName, sfSource)
    else
      Emit(', ' + AParamType + ' ' + AParamName, sfSource);
  end;
  Result := Self;
end;

function TIR.EndFunc(): TIRBase;
begin
  CloseFuncSignature();
  IndentOut();
  EmitLine('}', sfSource);
  GetBuffer(sfSource).AppendLine('');
  Result := Self;
end;

// ---- Statement methods inside Func context ----

function TIR.DeclVar(const AVarName,
  AVarType: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine(AVarType + ' ' + AVarName + ';', sfSource);
  Result := Self;
end;

function TIR.DeclVar(const AVarName, AVarType,
  AInitExpr: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine(AVarType + ' ' + AVarName + ' = ' + AInitExpr + ';', sfSource);
  Result := Self;
end;

function TIR.Assign(const ALhs, AExpr: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine(ALhs + ' = ' + AExpr + ';', sfSource);
  Result := Self;
end;

function TIR.AssignTo(const ATargetExpr,
  AValueExpr: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine(ATargetExpr + ' = ' + AValueExpr + ';', sfSource);
  Result := Self;
end;

function TIR.Call(const AFuncName: string;
  const AArgs: TArray<string>): TIRBase;
var
  LArgList: string;
  LI: Integer;
begin
  CloseFuncSignature();
  LArgList := '';
  for LI := 0 to Length(AArgs) - 1 do
  begin
    if LI > 0 then
      LArgList := LArgList + ', ';
    LArgList := LArgList + AArgs[LI];
  end;
  EmitLine(AFuncName + '(' + LArgList + ');', sfSource);
  Result := Self;
end;

function TIR.Stmt(const ARawText: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine(ARawText, sfSource);
  Result := Self;
end;

function TIR.Stmt(const ARawText: string;
  const AArgs: array of const): TIRBase;
begin
  Result := Stmt(Format(ARawText, AArgs));
end;

function TIR.Return(): TIRBase;
begin
  CloseFuncSignature();
  EmitLine('return;', sfSource);
  Result := Self;
end;

function TIR.Return(const AExpr: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine('return ' + AExpr + ';', sfSource);
  Result := Self;
end;

function TIR.IfStmt(const ACondExpr: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine('if (' + ACondExpr + ') {', sfSource);
  IndentIn();
  Result := Self;
end;

function TIR.ElseIfStmt(const ACondExpr: string): TIRBase;
begin
  IndentOut();
  EmitLine('} else if (' + ACondExpr + ') {', sfSource);
  IndentIn();
  Result := Self;
end;

function TIR.ElseStmt(): TIRBase;
begin
  IndentOut();
  EmitLine('} else {', sfSource);
  IndentIn();
  Result := Self;
end;

function TIR.EndIf(): TIRBase;
begin
  IndentOut();
  EmitLine('}', sfSource);
  Result := Self;
end;

function TIR.WhileStmt(const ACondExpr: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine('while (' + ACondExpr + ') {', sfSource);
  IndentIn();
  Result := Self;
end;

function TIR.EndWhile(): TIRBase;
begin
  IndentOut();
  EmitLine('}', sfSource);
  Result := Self;
end;

function TIR.ForStmt(const AVarName, AInitExpr, ACondExpr,
  AStepExpr: string): TIRBase;
begin
  CloseFuncSignature();
  EmitLine('for (' + AVarName + ' = ' + AInitExpr + '; ' +
    ACondExpr + '; ' + AStepExpr + ') {', sfSource);
  IndentIn();
  Result := Self;
end;

function TIR.EndFor(): TIRBase;
begin
  IndentOut();
  EmitLine('}', sfSource);
  Result := Self;
end;

function TIR.BreakStmt(): TIRBase;
begin
  CloseFuncSignature();
  EmitLine('break;', sfSource);
  Result := Self;
end;

function TIR.ContinueStmt(): TIRBase;
begin
  CloseFuncSignature();
  EmitLine('continue;', sfSource);
  Result := Self;
end;

function TIR.BlankLine(
  const ATarget: TSourceFile): TIRBase;
begin
  GetBuffer(ATarget).AppendLine('');
  Result := Self;
end;

// ---- Expression builders ----

function TIR.Lit(const AValue: Integer): string;
begin
  Result := IntToStr(AValue);
end;

function TIR.Lit(const AValue: Int64): string;
begin
  Result := IntToStr(AValue) + 'LL';
end;

function TIR.Float(const AValue: Double): string;
var
  LFS: TFormatSettings;
begin
  LFS := TFormatSettings.Create();
  LFS.DecimalSeparator := '.';
  Result := FormatFloat('0.0###############', AValue, LFS);
end;

function TIR.Str(const AValue: string): string;
begin
  // C++ string literal — basic escaping
  Result := '"' + AValue + '"';
end;

function TIR.Bool(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function TIR.Null(): string;
begin
  Result := 'nullptr';
end;

function TIR.Get(const AVarName: string): string;
begin
  Result := AVarName;
end;

function TIR.Field(const AObj, AMember: string): string;
begin
  Result := AObj + '.' + AMember;
end;

function TIR.Deref(const APtr, AMember: string): string;
begin
  Result := APtr + '->' + AMember;
end;

function TIR.Deref(const APtr: string): string;
begin
  Result := '*' + APtr;
end;

function TIR.AddrOf(const AVarName: string): string;
begin
  Result := '&' + AVarName;
end;

function TIR.Index(const AArr, AIndexExpr: string): string;
begin
  Result := AArr + '[' + AIndexExpr + ']';
end;

function TIR.Cast(const ATypeName, AExpr: string): string;
begin
  Result := '(' + ATypeName + ')(' + AExpr + ')';
end;

function TIR.Invoke(const AFuncName: string;
  const AArgs: TArray<string>): string;
var
  LArgList: string;
  LI: Integer;
begin
  LArgList := '';
  for LI := 0 to Length(AArgs) - 1 do
  begin
    if LI > 0 then
      LArgList := LArgList + ', ';
    LArgList := LArgList + AArgs[LI];
  end;
  Result := AFuncName + '(' + LArgList + ')';
end;

// Arithmetic

function TIR.Add(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' + ' + ARight;
end;

function TIR.Sub(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' - ' + ARight;
end;

function TIR.Mul(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' * ' + ARight;
end;

function TIR.DivExpr(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' / ' + ARight;
end;

function TIR.ModExpr(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' % ' + ARight;
end;

function TIR.Neg(const AExpr: string): string;
begin
  Result := '-' + AExpr;
end;

// Comparison

function TIR.Eq(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' == ' + ARight;
end;

function TIR.Ne(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' != ' + ARight;
end;

function TIR.Lt(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' < ' + ARight;
end;

function TIR.Le(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' <= ' + ARight;
end;

function TIR.Gt(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' > ' + ARight;
end;

function TIR.Ge(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' >= ' + ARight;
end;

// Logical

function TIR.AndExpr(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' && ' + ARight;
end;

function TIR.OrExpr(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' || ' + ARight;
end;

function TIR.NotExpr(const AExpr: string): string;
begin
  Result := '!' + AExpr;
end;

// Bitwise

function TIR.BitAnd(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' & ' + ARight;
end;

function TIR.BitOr(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' | ' + ARight;
end;

function TIR.BitXor(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' ^ ' + ARight;
end;

function TIR.BitNot(const AExpr: string): string;
begin
  Result := '~' + AExpr;
end;

function TIR.ShlExpr(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' << ' + ARight;
end;

function TIR.ShrExpr(const ALeft, ARight: string): string;
begin
  Result := ALeft + ' >> ' + ARight;
end;

// ---- AST walk entry point ----

function TIR.Generate(const ARoot: TASTNodeBase): Boolean;
var
  LErrors: TErrors;
begin
  Result := False;
  LErrors := GetErrors();

  if ARoot = nil then
  begin
    if LErrors <> nil then
      LErrors.Add(esError, ERR_CODEGEN_NIL_ROOT, RSCodeGenNilRoot);
    Exit;
  end;

  if FConfig = nil then
  begin
    if LErrors <> nil then
      LErrors.Add(esError, ERR_CODEGEN_NO_CONFIG, RSCodeGenNoConfig);
    Exit;
  end;

  EmitNode(ARoot);

  if (LErrors <> nil) and LErrors.HasErrors() then
    Exit;

  Result := True;
end;

// ---- Output ----

procedure TIR.SaveToFiles(const AHeaderPath,
  ASourcePath: string);
var
  LHeaderDir:  string;
  LSourceDir:  string;
  LHeaderName: string;
begin
  // Ensure output directories exist
  LHeaderDir := ExtractFilePath(AHeaderPath);
  if (LHeaderDir <> '') and (not TDirectory.Exists(LHeaderDir)) then
    TDirectory.CreateDirectory(LHeaderDir);

  LSourceDir := ExtractFilePath(ASourcePath);
  if (LSourceDir <> '') and (not TDirectory.Exists(LSourceDir)) then
    TDirectory.CreateDirectory(LSourceDir);

  // Write header
  TFile.WriteAllText(AHeaderPath, FHeaderBuffer.ToString(), TEncoding.UTF8);

  // Write source — prepend #include "header.h"
  LHeaderName := ExtractFileName(AHeaderPath);
  TFile.WriteAllText(ASourcePath,
    '#include "' + LHeaderName + '"' + sLineBreak + sLineBreak +
    FSourceBuffer.ToString(), TEncoding.UTF8);
end;

function TIR.GetHeaderContent(): string;
begin
  Result := FHeaderBuffer.ToString();
end;

function TIR.GetSourceContent(): string;
begin
  Result := FSourceBuffer.ToString();
end;

procedure TIR.SetContext(const AKey, AValue: string);
begin
  FContext.AddOrSetValue(AKey, AValue);
end;

function TIR.GetContext(const AKey: string; const ADefault: string): string;
begin
  if not FContext.TryGetValue(AKey, Result) then
    Result := ADefault;
end;

function TIR.Dump(const AId: Integer): string;
begin
  Result := '--- HEADER ---' + sLineBreak +
            FHeaderBuffer.ToString() + sLineBreak +
            '--- SOURCE ---' + sLineBreak +
            FSourceBuffer.ToString();
end;

end.
