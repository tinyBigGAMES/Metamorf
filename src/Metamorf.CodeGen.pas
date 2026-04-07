{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.CodeGen;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.AST;

type

  { TMorOutputTarget }
  TMorOutputTarget = (otHeader, otSource);

  { TMorEmitNodeProc }
  TMorEmitNodeProc = procedure(const ANode: TMorASTNode) of object;

  { TMorCodeOutput }
  TMorCodeOutput = class(TMorBaseObject)
  private
    FHeaderBuffer: TStringBuilder;
    FSourceBuffer: TStringBuilder;
    FIndentLevel: Integer;
    FInFuncSignature: Boolean;
    FContext: TDictionary<string, string>;
    FLineDirectives: Boolean;
    FLastLineFile: string;
    FLastLineNum: Integer;
    FPendingLineFile: string;
    FPendingLineNum: Integer;
    FCaptureStack: TList<TStringBuilder>;
    FEmitNodeCallback: TMorEmitNodeProc;

    function GetBuffer(const ATarget: TMorOutputTarget): TStringBuilder;
    {$HINTS OFF}
    function GetActiveBuffer(): TStringBuilder;
    {$HINTS ON}
    function GetIndent(): string;
    procedure CloseFuncSignature();
    procedure FlushPendingLineDirective();

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Capture mode for exprToString
    procedure BeginCapture();
    function EndCapture(): string;

    // Delegation to interpreter for node dispatch
    procedure SetEmitNodeCallback(const ACallback: TMorEmitNodeProc);
    procedure EmitNode(const ANode: TMorASTNode);
    procedure EmitChildren(const ANode: TMorASTNode);

    // Line directives
    procedure SetLineDirectives(const AEnabled: Boolean);
    procedure EmitLineDirective(const ANode: TMorASTNode);

    // Low-level output
    procedure EmitLine(const AText: string; const ATarget: TMorOutputTarget = otSource); overload;
    procedure EmitLine(const AText: string; const AArgs: array of const; const ATarget: TMorOutputTarget = otSource); overload;
    procedure Emit(const AText: string; const ATarget: TMorOutputTarget = otSource); overload;
    procedure Emit(const AText: string; const AArgs: array of const; const ATarget: TMorOutputTarget = otSource); overload;
    procedure EmitRaw(const AText: string; const ATarget: TMorOutputTarget = otSource); overload;
    procedure EmitRaw(const AText: string; const AArgs: array of const; const ATarget: TMorOutputTarget = otSource); overload;

    // Indentation
    procedure IndentIn();
    procedure IndentOut();

    // Top-level declarations
    procedure IncludeHeader(const AHeaderName: string; const ATarget: TMorOutputTarget = otHeader);
    procedure StructBegin(const AStructName: string; const ATarget: TMorOutputTarget = otHeader);
    procedure AddField(const AFieldName: string; const AFieldType: string);
    procedure StructEnd();
    procedure DeclConst(const AConstName: string; const AConstType: string; const AValueExpr: string; const ATarget: TMorOutputTarget = otHeader);
    procedure GlobalVar(const AGlobalName: string; const AGlobalType: string; const AInitExpr: string; const ATarget: TMorOutputTarget = otSource);
    procedure UsingDecl(const AAlias: string; const AOriginal: string; const ATarget: TMorOutputTarget = otHeader);
    procedure NamespaceBegin(const ANamespaceName: string; const ATarget: TMorOutputTarget = otHeader);
    procedure NamespaceEnd(const ATarget: TMorOutputTarget = otHeader);
    procedure ExternCDecl(const AFuncName: string; const AReturnType: string; const AParams: string; const ATarget: TMorOutputTarget = otHeader);

    // Function builder
    procedure Func(const AFuncName: string; const AReturnType: string);
    procedure Param(const AParamName: string; const AParamType: string);
    procedure EndFunc();

    // Statement methods
    procedure DeclVar(const AVarName: string; const AVarType: string); overload;
    procedure DeclVar(const AVarName: string; const AVarType: string; const AInitExpr: string); overload;
    procedure Assign(const ALhs: string; const AExpr: string);
    procedure AssignTo(const ATargetExpr: string; const AValueExpr: string);
    procedure CallStmt(const AFuncName: string; const AArgs: string);
    procedure Stmt(const ARawText: string); overload;
    procedure Stmt(const ARawText: string; const AArgs: array of const); overload;
    procedure ReturnStmt(); overload;
    procedure ReturnStmt(const AExpr: string); overload;
    procedure IfStmt(const ACondExpr: string);
    procedure ElseIfStmt(const ACondExpr: string);
    procedure ElseStmt();
    procedure EndIf();
    procedure WhileStmt(const ACondExpr: string);
    procedure EndWhile();
    procedure ForStmt(const AVarName: string; const AInitExpr: string; const ACondExpr: string; const AStepExpr: string);
    procedure EndFor();
    procedure BreakStmt();
    procedure ContinueStmt();
    procedure BlankLine(const ATarget: TMorOutputTarget = otSource);

    // Expression builders (return C++ text fragments)
    function Lit(const AValue: Integer): string; overload;
    function Lit(const AValue: Int64): string; overload;
    function FloatLit(const AValue: Double): string;
    function StrLit(const AValue: string): string;
    function BoolLit(const AValue: Boolean): string;
    function NullLit(): string;
    function Get(const AVarName: string): string;
    function Field(const AObj: string; const AMember: string): string;
    function Deref(const APtr: string; const AMember: string): string; overload;
    function Deref(const APtr: string): string; overload;
    function AddrOf(const AVarName: string): string;
    function IndexExpr(const AArr: string; const AIndexExpr: string): string;
    function CastExpr(const ATypeName: string; const AExpr: string): string;
    function Invoke(const AFuncName: string; const AArgs: string): string;
    function Add(const ALeft: string; const ARight: string): string;
    function Sub(const ALeft: string; const ARight: string): string;
    function Mul(const ALeft: string; const ARight: string): string;
    function DivExpr(const ALeft: string; const ARight: string): string;
    function ModExpr(const ALeft: string; const ARight: string): string;
    function Neg(const AExpr: string): string;

    // Comparison
    function Eq(const ALeft: string; const ARight: string): string;
    function Ne(const ALeft: string; const ARight: string): string;
    function Lt(const ALeft: string; const ARight: string): string;
    function Le(const ALeft: string; const ARight: string): string;
    function Gt(const ALeft: string; const ARight: string): string;
    function Ge(const ALeft: string; const ARight: string): string;

    // Logical
    function AndExpr(const ALeft: string; const ARight: string): string;
    function OrExpr(const ALeft: string; const ARight: string): string;
    function NotExpr(const AExpr: string): string;

    // Bitwise
    function BitAnd(const ALeft: string; const ARight: string): string;
    function BitOr(const ALeft: string; const ARight: string): string;
    function BitXor(const ALeft: string; const ARight: string): string;
    function BitNot(const AExpr: string): string;
    function ShlExpr(const ALeft: string; const ARight: string): string;
    function ShrExpr(const ALeft: string; const ARight: string): string;

    // Output
    procedure SaveToFiles(const AHeaderPath: string; const ASourcePath: string);
    function GetHeaderContent(): string;
    function GetSourceContent(): string;

    // Context store
    procedure SetContext(const AKey: string; const AValue: string);
    function GetContext(const AKey: string; const ADefault: string = ''): string;

    // Clear buffers
    procedure Clear();
  end;

implementation

{ TMorCodeOutput }

constructor TMorCodeOutput.Create();
begin
  inherited;
  FHeaderBuffer := TStringBuilder.Create();
  FSourceBuffer := TStringBuilder.Create();
  FIndentLevel := 0;
  FInFuncSignature := False;
  FContext := TDictionary<string, string>.Create();
  FLineDirectives := True;
  FLastLineFile := '';
  FLastLineNum := 0;
  FPendingLineFile := '';
  FPendingLineNum := 0;
  FCaptureStack := TList<TStringBuilder>.Create();
  FEmitNodeCallback := nil;
end;

destructor TMorCodeOutput.Destroy();
var
  LI: Integer;
begin
  for LI := 0 to FCaptureStack.Count - 1 do
    FCaptureStack[LI].Free();
  FreeAndNil(FCaptureStack);
  FreeAndNil(FContext);
  FreeAndNil(FSourceBuffer);
  FreeAndNil(FHeaderBuffer);
  inherited;
end;

function TMorCodeOutput.GetBuffer(const ATarget: TMorOutputTarget): TStringBuilder;
begin
  // If capturing, redirect ALL output to capture buffer
  if FCaptureStack.Count > 0 then
    Exit(FCaptureStack[FCaptureStack.Count - 1]);
  if ATarget = otHeader then
    Result := FHeaderBuffer
  else
    Result := FSourceBuffer;
end;

function TMorCodeOutput.GetActiveBuffer(): TStringBuilder;
begin
  Result := GetBuffer(otSource);
end;

function TMorCodeOutput.GetIndent(): string;
begin
  Result := StringOfChar(' ', FIndentLevel * 2);
end;

procedure TMorCodeOutput.CloseFuncSignature();
begin
  if FInFuncSignature then
  begin
    FInFuncSignature := False;
    GetBuffer(otSource).AppendLine(') {');
    IndentIn();
  end;
end;

{ Capture mode }

procedure TMorCodeOutput.BeginCapture();
begin
  FCaptureStack.Add(TStringBuilder.Create());
end;

function TMorCodeOutput.EndCapture(): string;
var
  LBuf: TStringBuilder;
begin
  if FCaptureStack.Count = 0 then
    Exit('');
  LBuf := FCaptureStack[FCaptureStack.Count - 1];
  FCaptureStack.Delete(FCaptureStack.Count - 1);
  Result := LBuf.ToString();
  LBuf.Free();
end;

{ Node dispatch delegation }

procedure TMorCodeOutput.SetEmitNodeCallback(const ACallback: TMorEmitNodeProc);
begin
  FEmitNodeCallback := ACallback;
end;

procedure TMorCodeOutput.EmitNode(const ANode: TMorASTNode);
begin
  if ANode = nil then
    Exit;

  if Assigned(FEmitNodeCallback) then
    FEmitNodeCallback(ANode)
  else
    EmitChildren(ANode);
end;

procedure TMorCodeOutput.EmitChildren(const ANode: TMorASTNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  for LI := 0 to ANode.ChildCount() - 1 do
    EmitNode(ANode.GetChild(LI));
end;

procedure TMorCodeOutput.SetLineDirectives(const AEnabled: Boolean);
begin
  FLineDirectives := AEnabled;
end;

procedure TMorCodeOutput.EmitLineDirective(const ANode: TMorASTNode);
var
  LRange: TMorSourceRange;
begin
  if not FLineDirectives then
    Exit;
  if ANode = nil then
    Exit;

  LRange := ANode.GetRange();
  if (LRange.StartLine > 0) and (LRange.Filename <> '') then
  begin
    // Set pending — will be flushed when actual code is emitted
    FPendingLineFile := LRange.Filename;
    FPendingLineNum := LRange.StartLine;
  end;
end;

procedure TMorCodeOutput.FlushPendingLineDirective();
var
  LFile: string;
begin
  if FPendingLineNum <= 0 then
    Exit;
  if FPendingLineFile = '' then
    Exit;
  // Don't emit during capture mode (exprToString etc.)
  if FCaptureStack.Count > 0 then
    Exit;

  // Only emit if different from last emitted
  if (FPendingLineFile <> FLastLineFile) or (FPendingLineNum <> FLastLineNum) then
  begin
    LFile := FPendingLineFile.Replace('\', '/');
    FSourceBuffer.AppendLine('#line ' + IntToStr(FPendingLineNum) + ' "' + LFile + '"');
    FLastLineFile := FPendingLineFile;
    FLastLineNum := FPendingLineNum;
  end;

  // Clear pending
  FPendingLineFile := '';
  FPendingLineNum := 0;
end;

{ Low-level output }

procedure TMorCodeOutput.EmitLine(const AText: string; const ATarget: TMorOutputTarget);
begin
  if ATarget = otSource then
    FlushPendingLineDirective();
  GetBuffer(ATarget).AppendLine(GetIndent() + AText);
end;

procedure TMorCodeOutput.EmitLine(const AText: string; const AArgs: array of const; const ATarget: TMorOutputTarget);
begin
  EmitLine(Format(AText, AArgs), ATarget);
end;

procedure TMorCodeOutput.Emit(const AText: string; const ATarget: TMorOutputTarget);
begin
  if ATarget = otSource then
    FlushPendingLineDirective();
  GetBuffer(ATarget).Append(AText);
end;

procedure TMorCodeOutput.Emit(const AText: string; const AArgs: array of const; const ATarget: TMorOutputTarget);
begin
  Emit(Format(AText, AArgs), ATarget);
end;

procedure TMorCodeOutput.EmitRaw(const AText: string; const ATarget: TMorOutputTarget);
begin
  GetBuffer(ATarget).Append(AText);
end;

procedure TMorCodeOutput.EmitRaw(const AText: string; const AArgs: array of const; const ATarget: TMorOutputTarget);
begin
  EmitRaw(Format(AText, AArgs), ATarget);
end;

procedure TMorCodeOutput.IndentIn();
begin
  Inc(FIndentLevel);
end;

procedure TMorCodeOutput.IndentOut();
begin
  if FIndentLevel > 0 then
    Dec(FIndentLevel);
end;

{ Top-level declarations }

procedure TMorCodeOutput.IncludeHeader(const AHeaderName: string; const ATarget: TMorOutputTarget);
begin
  if (AHeaderName <> '') and (AHeaderName[1] <> '"') and (AHeaderName[1] <> '<') then
    EmitLine('#include <' + AHeaderName + '>', ATarget)
  else
    EmitLine('#include ' + AHeaderName, ATarget);
end;

procedure TMorCodeOutput.StructBegin(const AStructName: string; const ATarget: TMorOutputTarget);
begin
  EmitLine('struct ' + AStructName + ' {', ATarget);
  IndentIn();
end;

procedure TMorCodeOutput.AddField(const AFieldName: string; const AFieldType: string);
begin
  EmitLine(AFieldType + ' ' + AFieldName + ';', otHeader);
end;

procedure TMorCodeOutput.StructEnd();
begin
  IndentOut();
  EmitLine('};', otHeader);
end;

procedure TMorCodeOutput.DeclConst(const AConstName: string; const AConstType: string; const AValueExpr: string; const ATarget: TMorOutputTarget);
begin
  if AConstType = '' then
    EmitLine('constexpr auto ' + AConstName + ' = ' + AValueExpr + ';', ATarget)
  else
    EmitLine('constexpr ' + AConstType + ' ' + AConstName + ' = ' + AValueExpr + ';', ATarget);
end;

procedure TMorCodeOutput.GlobalVar(const AGlobalName: string; const AGlobalType: string; const AInitExpr: string; const ATarget: TMorOutputTarget);
begin
  if AInitExpr = '' then
    EmitLine(AGlobalType + ' ' + AGlobalName + ';', ATarget)
  else
    EmitLine(AGlobalType + ' ' + AGlobalName + ' = ' + AInitExpr + ';', ATarget);
end;

procedure TMorCodeOutput.UsingDecl(const AAlias: string; const AOriginal: string; const ATarget: TMorOutputTarget);
begin
  EmitLine('using ' + AAlias + ' = ' + AOriginal + ';', ATarget);
end;

procedure TMorCodeOutput.NamespaceBegin(const ANamespaceName: string; const ATarget: TMorOutputTarget);
begin
  EmitLine('namespace ' + ANamespaceName + ' {', ATarget);
  IndentIn();
end;

procedure TMorCodeOutput.NamespaceEnd(const ATarget: TMorOutputTarget);
begin
  IndentOut();
  EmitLine('} // namespace', ATarget);
end;

procedure TMorCodeOutput.ExternCDecl(const AFuncName: string; const AReturnType: string; const AParams: string; const ATarget: TMorOutputTarget);
begin
  EmitLine('extern "C" ' + AReturnType + ' ' + AFuncName + '(' + AParams + ');', ATarget);
end;

{ Function builder }

procedure TMorCodeOutput.Func(const AFuncName: string; const AReturnType: string);
begin
  FInFuncSignature := True;
  Emit(GetIndent() + AReturnType + ' ' + AFuncName + '(', otSource);
end;

procedure TMorCodeOutput.Param(const AParamName: string; const AParamType: string);
var
  LBuf: TStringBuilder;
begin
  LBuf := GetBuffer(otSource);
  if LBuf.Length > 0 then
  begin
    if LBuf.Chars[LBuf.Length - 1] = '(' then
      Emit(AParamType + ' ' + AParamName, otSource)
    else
      Emit(', ' + AParamType + ' ' + AParamName, otSource);
  end;
end;

procedure TMorCodeOutput.EndFunc();
begin
  CloseFuncSignature();
  IndentOut();
  EmitLine('}', otSource);
  GetBuffer(otSource).AppendLine('');
end;

{ Statement methods }

procedure TMorCodeOutput.DeclVar(const AVarName: string; const AVarType: string);
begin
  CloseFuncSignature();
  EmitLine(AVarType + ' ' + AVarName + ';', otSource);
end;

procedure TMorCodeOutput.DeclVar(const AVarName: string; const AVarType: string; const AInitExpr: string);
begin
  CloseFuncSignature();
  EmitLine(AVarType + ' ' + AVarName + ' = ' + AInitExpr + ';', otSource);
end;

procedure TMorCodeOutput.Assign(const ALhs: string; const AExpr: string);
begin
  CloseFuncSignature();
  EmitLine(ALhs + ' = ' + AExpr + ';', otSource);
end;

procedure TMorCodeOutput.AssignTo(const ATargetExpr: string; const AValueExpr: string);
begin
  CloseFuncSignature();
  EmitLine(ATargetExpr + ' = ' + AValueExpr + ';', otSource);
end;

procedure TMorCodeOutput.CallStmt(const AFuncName: string; const AArgs: string);
begin
  CloseFuncSignature();
  EmitLine(AFuncName + '(' + AArgs + ');', otSource);
end;

procedure TMorCodeOutput.Stmt(const ARawText: string);
begin
  CloseFuncSignature();
  EmitLine(ARawText, otSource);
end;

procedure TMorCodeOutput.Stmt(const ARawText: string; const AArgs: array of const);
begin
  Stmt(Format(ARawText, AArgs));
end;

procedure TMorCodeOutput.ReturnStmt();
begin
  CloseFuncSignature();
  EmitLine('return;', otSource);
end;

procedure TMorCodeOutput.ReturnStmt(const AExpr: string);
begin
  CloseFuncSignature();
  EmitLine('return ' + AExpr + ';', otSource);
end;

procedure TMorCodeOutput.IfStmt(const ACondExpr: string);
begin
  CloseFuncSignature();
  EmitLine('if (' + ACondExpr + ') {', otSource);
  IndentIn();
end;

procedure TMorCodeOutput.ElseIfStmt(const ACondExpr: string);
begin
  IndentOut();
  EmitLine('} else if (' + ACondExpr + ') {', otSource);
  IndentIn();
end;

procedure TMorCodeOutput.ElseStmt();
begin
  IndentOut();
  EmitLine('} else {', otSource);
  IndentIn();
end;

procedure TMorCodeOutput.EndIf();
begin
  IndentOut();
  EmitLine('}', otSource);
end;

procedure TMorCodeOutput.WhileStmt(const ACondExpr: string);
begin
  CloseFuncSignature();
  EmitLine('while (' + ACondExpr + ') {', otSource);
  IndentIn();
end;

procedure TMorCodeOutput.EndWhile();
begin
  IndentOut();
  EmitLine('}', otSource);
end;

procedure TMorCodeOutput.ForStmt(const AVarName: string; const AInitExpr: string; const ACondExpr: string; const AStepExpr: string);
begin
  CloseFuncSignature();
  EmitLine('for (' + AVarName + ' = ' + AInitExpr + '; ' + ACondExpr + '; ' + AStepExpr + ') {', otSource);
  IndentIn();
end;

procedure TMorCodeOutput.EndFor();
begin
  IndentOut();
  EmitLine('}', otSource);
end;

procedure TMorCodeOutput.BreakStmt();
begin
  CloseFuncSignature();
  EmitLine('break;', otSource);
end;

procedure TMorCodeOutput.ContinueStmt();
begin
  CloseFuncSignature();
  EmitLine('continue;', otSource);
end;

procedure TMorCodeOutput.BlankLine(const ATarget: TMorOutputTarget);
begin
  GetBuffer(ATarget).AppendLine('');
end;

{ Expression builders }

function TMorCodeOutput.Lit(const AValue: Integer): string;
begin
  Result := IntToStr(AValue);
end;

function TMorCodeOutput.Lit(const AValue: Int64): string;
begin
  Result := IntToStr(AValue) + 'LL';
end;

function TMorCodeOutput.FloatLit(const AValue: Double): string;
var
  LFS: TFormatSettings;
begin
  LFS := TFormatSettings.Create();
  LFS.DecimalSeparator := '.';
  Result := FormatFloat('0.0###############', AValue, LFS);
end;

function TMorCodeOutput.StrLit(const AValue: string): string;
begin
  Result := '"' + AValue + '"';
end;

function TMorCodeOutput.BoolLit(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function TMorCodeOutput.NullLit(): string;
begin
  Result := 'nullptr';
end;

function TMorCodeOutput.Get(const AVarName: string): string;
begin
  Result := AVarName;
end;

function TMorCodeOutput.Field(const AObj: string; const AMember: string): string;
begin
  Result := AObj + '.' + AMember;
end;

function TMorCodeOutput.Deref(const APtr: string; const AMember: string): string;
begin
  Result := APtr + '->' + AMember;
end;

function TMorCodeOutput.Deref(const APtr: string): string;
begin
  Result := '*' + APtr;
end;

function TMorCodeOutput.AddrOf(const AVarName: string): string;
begin
  Result := '&' + AVarName;
end;

function TMorCodeOutput.IndexExpr(const AArr: string; const AIndexExpr: string): string;
begin
  Result := AArr + '[' + AIndexExpr + ']';
end;

function TMorCodeOutput.CastExpr(const ATypeName: string; const AExpr: string): string;
begin
  Result := '(' + ATypeName + ')(' + AExpr + ')';
end;

function TMorCodeOutput.Invoke(const AFuncName: string; const AArgs: string): string;
begin
  Result := AFuncName + '(' + AArgs + ')';
end;

function TMorCodeOutput.Add(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' + ' + ARight;
end;

function TMorCodeOutput.Sub(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' - ' + ARight;
end;

function TMorCodeOutput.Mul(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' * ' + ARight;
end;

function TMorCodeOutput.DivExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' / ' + ARight;
end;

function TMorCodeOutput.ModExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' % ' + ARight;
end;

function TMorCodeOutput.Neg(const AExpr: string): string;
begin
  Result := '-' + AExpr;
end;

function TMorCodeOutput.Eq(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' == ' + ARight;
end;

function TMorCodeOutput.Ne(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' != ' + ARight;
end;

function TMorCodeOutput.Lt(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' < ' + ARight;
end;

function TMorCodeOutput.Le(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' <= ' + ARight;
end;

function TMorCodeOutput.Gt(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' > ' + ARight;
end;

function TMorCodeOutput.Ge(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' >= ' + ARight;
end;

function TMorCodeOutput.AndExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' && ' + ARight;
end;

function TMorCodeOutput.OrExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' || ' + ARight;
end;

function TMorCodeOutput.NotExpr(const AExpr: string): string;
begin
  Result := '!' + AExpr;
end;

function TMorCodeOutput.BitAnd(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' & ' + ARight;
end;

function TMorCodeOutput.BitOr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' | ' + ARight;
end;

function TMorCodeOutput.BitXor(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' ^ ' + ARight;
end;

function TMorCodeOutput.BitNot(const AExpr: string): string;
begin
  Result := '~' + AExpr;
end;

function TMorCodeOutput.ShlExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' << ' + ARight;
end;

function TMorCodeOutput.ShrExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' >> ' + ARight;
end;

{ Output }

procedure TMorCodeOutput.SaveToFiles(const AHeaderPath: string; const ASourcePath: string);
var
  LHeaderDir: string;
  LSourceDir: string;
  LHeaderName: string;
begin
  LHeaderDir := ExtractFilePath(AHeaderPath);
  if (LHeaderDir <> '') and (not TDirectory.Exists(LHeaderDir)) then
    TDirectory.CreateDirectory(LHeaderDir);

  LSourceDir := ExtractFilePath(ASourcePath);
  if (LSourceDir <> '') and (not TDirectory.Exists(LSourceDir)) then
    TDirectory.CreateDirectory(LSourceDir);

  TFile.WriteAllText(AHeaderPath, FHeaderBuffer.ToString(), TEncoding.UTF8);

  LHeaderName := ExtractFileName(AHeaderPath);
  TFile.WriteAllText(ASourcePath,
    '#include "' + LHeaderName + '"' + sLineBreak + sLineBreak +
    FSourceBuffer.ToString(), TEncoding.UTF8);
end;

function TMorCodeOutput.GetHeaderContent(): string;
begin
  Result := FHeaderBuffer.ToString();
end;

function TMorCodeOutput.GetSourceContent(): string;
begin
  Result := FSourceBuffer.ToString();
end;

{ Context store }

procedure TMorCodeOutput.SetContext(const AKey: string; const AValue: string);
begin
  FContext.AddOrSetValue(AKey, AValue);
end;

function TMorCodeOutput.GetContext(const AKey: string; const ADefault: string): string;
begin
  if not FContext.TryGetValue(AKey, Result) then
    Result := ADefault;
end;

procedure TMorCodeOutput.Clear();
begin
  FHeaderBuffer.Clear();
  FSourceBuffer.Clear();
  FIndentLevel := 0;
  FInFuncSignature := False;
  FContext.Clear();
  FLastLineFile := '';
  FLastLineNum := 0;
end;

end.
