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

  { TOutputTarget }
  TOutputTarget = (otHeader, otSource);

  { TEmitNodeProc - callback to interpreter for node dispatch }
  TEmitNodeProc = procedure(const ANode: TASTNode) of object;

  { TCodeOutput }
  TCodeOutput = class(TBaseObject)
  private
    FHeaderBuffer: TStringBuilder;
    FSourceBuffer: TStringBuilder;
    FIndentLevel: Integer;
    FInFuncSignature: Boolean;
    FContext: TDictionary<string, string>;
    FLineDirectives: Boolean;
    FLastLineFile: string;
    FLastLineNum: Integer;
    FCaptureStack: TList<TStringBuilder>;
    FEmitNodeCallback: TEmitNodeProc;

    function GetBuffer(const ATarget: TOutputTarget): TStringBuilder;
    {$HINTS OFF}
    function GetActiveBuffer(): TStringBuilder;
    {$HINTS ON}
    function GetIndent(): string;
    procedure CloseFuncSignature();

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Capture mode for exprToString
    procedure BeginCapture();
    function EndCapture(): string;

    // Delegation to interpreter for node dispatch
    procedure SetEmitNodeCallback(const ACallback: TEmitNodeProc);
    procedure EmitNode(const ANode: TASTNode);
    procedure EmitChildren(const ANode: TASTNode);

    // Line directives
    procedure SetLineDirectives(const AEnabled: Boolean);

    // Low-level output
    procedure EmitLine(const AText: string; const ATarget: TOutputTarget = otSource); overload;
    procedure EmitLine(const AText: string; const AArgs: array of const; const ATarget: TOutputTarget = otSource); overload;
    procedure Emit(const AText: string; const ATarget: TOutputTarget = otSource); overload;
    procedure Emit(const AText: string; const AArgs: array of const; const ATarget: TOutputTarget = otSource); overload;
    procedure EmitRaw(const AText: string; const ATarget: TOutputTarget = otSource); overload;
    procedure EmitRaw(const AText: string; const AArgs: array of const; const ATarget: TOutputTarget = otSource); overload;

    // Indentation
    procedure IndentIn();
    procedure IndentOut();

    // Top-level declarations
    procedure IncludeHeader(const AHeaderName: string; const ATarget: TOutputTarget = otHeader);
    procedure StructBegin(const AStructName: string; const ATarget: TOutputTarget = otHeader);
    procedure AddField(const AFieldName: string; const AFieldType: string);
    procedure StructEnd();
    procedure DeclConst(const AConstName: string; const AConstType: string; const AValueExpr: string; const ATarget: TOutputTarget = otHeader);
    procedure GlobalVar(const AGlobalName: string; const AGlobalType: string; const AInitExpr: string; const ATarget: TOutputTarget = otSource);
    procedure UsingDecl(const AAlias: string; const AOriginal: string; const ATarget: TOutputTarget = otHeader);
    procedure NamespaceBegin(const ANamespaceName: string; const ATarget: TOutputTarget = otHeader);
    procedure NamespaceEnd(const ATarget: TOutputTarget = otHeader);
    procedure ExternCDecl(const AFuncName: string; const AReturnType: string; const AParams: string; const ATarget: TOutputTarget = otHeader);

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
    procedure BlankLine(const ATarget: TOutputTarget = otSource);

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

{ TCodeOutput }

constructor TCodeOutput.Create();
begin
  inherited;
  FHeaderBuffer := TStringBuilder.Create();
  FSourceBuffer := TStringBuilder.Create();
  FIndentLevel := 0;
  FInFuncSignature := False;
  FContext := TDictionary<string, string>.Create();
  FLineDirectives := False;
  FLastLineFile := '';
  FLastLineNum := 0;
  FCaptureStack := TList<TStringBuilder>.Create();
  FEmitNodeCallback := nil;
end;

destructor TCodeOutput.Destroy();
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

function TCodeOutput.GetBuffer(const ATarget: TOutputTarget): TStringBuilder;
begin
  // If capturing, redirect ALL output to capture buffer
  if FCaptureStack.Count > 0 then
    Exit(FCaptureStack[FCaptureStack.Count - 1]);
  if ATarget = otHeader then
    Result := FHeaderBuffer
  else
    Result := FSourceBuffer;
end;

function TCodeOutput.GetActiveBuffer(): TStringBuilder;
begin
  Result := GetBuffer(otSource);
end;

function TCodeOutput.GetIndent(): string;
begin
  Result := StringOfChar(' ', FIndentLevel * 2);
end;

procedure TCodeOutput.CloseFuncSignature();
begin
  if FInFuncSignature then
  begin
    FInFuncSignature := False;
    GetBuffer(otSource).AppendLine(') {');
    IndentIn();
  end;
end;

{ Capture mode }

procedure TCodeOutput.BeginCapture();
begin
  FCaptureStack.Add(TStringBuilder.Create());
end;

function TCodeOutput.EndCapture(): string;
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

procedure TCodeOutput.SetEmitNodeCallback(const ACallback: TEmitNodeProc);
begin
  FEmitNodeCallback := ACallback;
end;

procedure TCodeOutput.EmitNode(const ANode: TASTNode);
begin
  if ANode = nil then
    Exit;
  if Assigned(FEmitNodeCallback) then
    FEmitNodeCallback(ANode)
  else
    EmitChildren(ANode);
end;

procedure TCodeOutput.EmitChildren(const ANode: TASTNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  for LI := 0 to ANode.ChildCount() - 1 do
    EmitNode(ANode.GetChild(LI));
end;

procedure TCodeOutput.SetLineDirectives(const AEnabled: Boolean);
begin
  FLineDirectives := AEnabled;
end;

{ Low-level output }

procedure TCodeOutput.EmitLine(const AText: string; const ATarget: TOutputTarget);
begin
  GetBuffer(ATarget).AppendLine(GetIndent() + AText);
end;

procedure TCodeOutput.EmitLine(const AText: string; const AArgs: array of const; const ATarget: TOutputTarget);
begin
  EmitLine(Format(AText, AArgs), ATarget);
end;

procedure TCodeOutput.Emit(const AText: string; const ATarget: TOutputTarget);
begin
  GetBuffer(ATarget).Append(AText);
end;

procedure TCodeOutput.Emit(const AText: string; const AArgs: array of const; const ATarget: TOutputTarget);
begin
  Emit(Format(AText, AArgs), ATarget);
end;

procedure TCodeOutput.EmitRaw(const AText: string; const ATarget: TOutputTarget);
begin
  GetBuffer(ATarget).Append(AText);
end;

procedure TCodeOutput.EmitRaw(const AText: string; const AArgs: array of const; const ATarget: TOutputTarget);
begin
  EmitRaw(Format(AText, AArgs), ATarget);
end;

procedure TCodeOutput.IndentIn();
begin
  Inc(FIndentLevel);
end;

procedure TCodeOutput.IndentOut();
begin
  if FIndentLevel > 0 then
    Dec(FIndentLevel);
end;

{ Top-level declarations }

procedure TCodeOutput.IncludeHeader(const AHeaderName: string; const ATarget: TOutputTarget);
begin
  if (AHeaderName <> '') and (AHeaderName[1] <> '"') and (AHeaderName[1] <> '<') then
    EmitLine('#include <' + AHeaderName + '>', ATarget)
  else
    EmitLine('#include ' + AHeaderName, ATarget);
end;

procedure TCodeOutput.StructBegin(const AStructName: string; const ATarget: TOutputTarget);
begin
  EmitLine('struct ' + AStructName + ' {', ATarget);
  IndentIn();
end;

procedure TCodeOutput.AddField(const AFieldName: string; const AFieldType: string);
begin
  EmitLine(AFieldType + ' ' + AFieldName + ';', otHeader);
end;

procedure TCodeOutput.StructEnd();
begin
  IndentOut();
  EmitLine('};', otHeader);
end;

procedure TCodeOutput.DeclConst(const AConstName: string; const AConstType: string; const AValueExpr: string; const ATarget: TOutputTarget);
begin
  if AConstType = '' then
    EmitLine('constexpr auto ' + AConstName + ' = ' + AValueExpr + ';', ATarget)
  else
    EmitLine('constexpr ' + AConstType + ' ' + AConstName + ' = ' + AValueExpr + ';', ATarget);
end;

procedure TCodeOutput.GlobalVar(const AGlobalName: string; const AGlobalType: string; const AInitExpr: string; const ATarget: TOutputTarget);
begin
  if AInitExpr = '' then
    EmitLine(AGlobalType + ' ' + AGlobalName + ';', ATarget)
  else
    EmitLine(AGlobalType + ' ' + AGlobalName + ' = ' + AInitExpr + ';', ATarget);
end;

procedure TCodeOutput.UsingDecl(const AAlias: string; const AOriginal: string; const ATarget: TOutputTarget);
begin
  EmitLine('using ' + AAlias + ' = ' + AOriginal + ';', ATarget);
end;

procedure TCodeOutput.NamespaceBegin(const ANamespaceName: string; const ATarget: TOutputTarget);
begin
  EmitLine('namespace ' + ANamespaceName + ' {', ATarget);
  IndentIn();
end;

procedure TCodeOutput.NamespaceEnd(const ATarget: TOutputTarget);
begin
  IndentOut();
  EmitLine('} // namespace', ATarget);
end;

procedure TCodeOutput.ExternCDecl(const AFuncName: string; const AReturnType: string; const AParams: string; const ATarget: TOutputTarget);
begin
  EmitLine('extern "C" ' + AReturnType + ' ' + AFuncName + '(' + AParams + ');', ATarget);
end;

{ Function builder }

procedure TCodeOutput.Func(const AFuncName: string; const AReturnType: string);
begin
  FInFuncSignature := True;
  Emit(GetIndent() + AReturnType + ' ' + AFuncName + '(', otSource);
end;

procedure TCodeOutput.Param(const AParamName: string; const AParamType: string);
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

procedure TCodeOutput.EndFunc();
begin
  CloseFuncSignature();
  IndentOut();
  EmitLine('}', otSource);
  GetBuffer(otSource).AppendLine('');
end;

{ Statement methods }

procedure TCodeOutput.DeclVar(const AVarName: string; const AVarType: string);
begin
  CloseFuncSignature();
  EmitLine(AVarType + ' ' + AVarName + ';', otSource);
end;

procedure TCodeOutput.DeclVar(const AVarName: string; const AVarType: string; const AInitExpr: string);
begin
  CloseFuncSignature();
  EmitLine(AVarType + ' ' + AVarName + ' = ' + AInitExpr + ';', otSource);
end;

procedure TCodeOutput.Assign(const ALhs: string; const AExpr: string);
begin
  CloseFuncSignature();
  EmitLine(ALhs + ' = ' + AExpr + ';', otSource);
end;

procedure TCodeOutput.AssignTo(const ATargetExpr: string; const AValueExpr: string);
begin
  CloseFuncSignature();
  EmitLine(ATargetExpr + ' = ' + AValueExpr + ';', otSource);
end;

procedure TCodeOutput.CallStmt(const AFuncName: string; const AArgs: string);
begin
  CloseFuncSignature();
  EmitLine(AFuncName + '(' + AArgs + ');', otSource);
end;

procedure TCodeOutput.Stmt(const ARawText: string);
begin
  CloseFuncSignature();
  EmitLine(ARawText, otSource);
end;

procedure TCodeOutput.Stmt(const ARawText: string; const AArgs: array of const);
begin
  Stmt(Format(ARawText, AArgs));
end;

procedure TCodeOutput.ReturnStmt();
begin
  CloseFuncSignature();
  EmitLine('return;', otSource);
end;

procedure TCodeOutput.ReturnStmt(const AExpr: string);
begin
  CloseFuncSignature();
  EmitLine('return ' + AExpr + ';', otSource);
end;

procedure TCodeOutput.IfStmt(const ACondExpr: string);
begin
  CloseFuncSignature();
  EmitLine('if (' + ACondExpr + ') {', otSource);
  IndentIn();
end;

procedure TCodeOutput.ElseIfStmt(const ACondExpr: string);
begin
  IndentOut();
  EmitLine('} else if (' + ACondExpr + ') {', otSource);
  IndentIn();
end;

procedure TCodeOutput.ElseStmt();
begin
  IndentOut();
  EmitLine('} else {', otSource);
  IndentIn();
end;

procedure TCodeOutput.EndIf();
begin
  IndentOut();
  EmitLine('}', otSource);
end;

procedure TCodeOutput.WhileStmt(const ACondExpr: string);
begin
  CloseFuncSignature();
  EmitLine('while (' + ACondExpr + ') {', otSource);
  IndentIn();
end;

procedure TCodeOutput.EndWhile();
begin
  IndentOut();
  EmitLine('}', otSource);
end;

procedure TCodeOutput.ForStmt(const AVarName: string; const AInitExpr: string; const ACondExpr: string; const AStepExpr: string);
begin
  CloseFuncSignature();
  EmitLine('for (' + AVarName + ' = ' + AInitExpr + '; ' + ACondExpr + '; ' + AStepExpr + ') {', otSource);
  IndentIn();
end;

procedure TCodeOutput.EndFor();
begin
  IndentOut();
  EmitLine('}', otSource);
end;

procedure TCodeOutput.BreakStmt();
begin
  CloseFuncSignature();
  EmitLine('break;', otSource);
end;

procedure TCodeOutput.ContinueStmt();
begin
  CloseFuncSignature();
  EmitLine('continue;', otSource);
end;

procedure TCodeOutput.BlankLine(const ATarget: TOutputTarget);
begin
  GetBuffer(ATarget).AppendLine('');
end;

{ Expression builders }

function TCodeOutput.Lit(const AValue: Integer): string;
begin
  Result := IntToStr(AValue);
end;

function TCodeOutput.Lit(const AValue: Int64): string;
begin
  Result := IntToStr(AValue) + 'LL';
end;

function TCodeOutput.FloatLit(const AValue: Double): string;
var
  LFS: TFormatSettings;
begin
  LFS := TFormatSettings.Create();
  LFS.DecimalSeparator := '.';
  Result := FormatFloat('0.0###############', AValue, LFS);
end;

function TCodeOutput.StrLit(const AValue: string): string;
begin
  Result := '"' + AValue + '"';
end;

function TCodeOutput.BoolLit(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function TCodeOutput.NullLit(): string;
begin
  Result := 'nullptr';
end;

function TCodeOutput.Get(const AVarName: string): string;
begin
  Result := AVarName;
end;

function TCodeOutput.Field(const AObj: string; const AMember: string): string;
begin
  Result := AObj + '.' + AMember;
end;

function TCodeOutput.Deref(const APtr: string; const AMember: string): string;
begin
  Result := APtr + '->' + AMember;
end;

function TCodeOutput.Deref(const APtr: string): string;
begin
  Result := '*' + APtr;
end;

function TCodeOutput.AddrOf(const AVarName: string): string;
begin
  Result := '&' + AVarName;
end;

function TCodeOutput.IndexExpr(const AArr: string; const AIndexExpr: string): string;
begin
  Result := AArr + '[' + AIndexExpr + ']';
end;

function TCodeOutput.CastExpr(const ATypeName: string; const AExpr: string): string;
begin
  Result := '(' + ATypeName + ')(' + AExpr + ')';
end;

function TCodeOutput.Invoke(const AFuncName: string; const AArgs: string): string;
begin
  Result := AFuncName + '(' + AArgs + ')';
end;

function TCodeOutput.Add(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' + ' + ARight;
end;

function TCodeOutput.Sub(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' - ' + ARight;
end;

function TCodeOutput.Mul(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' * ' + ARight;
end;

function TCodeOutput.DivExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' / ' + ARight;
end;

function TCodeOutput.ModExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' % ' + ARight;
end;

function TCodeOutput.Neg(const AExpr: string): string;
begin
  Result := '-' + AExpr;
end;

function TCodeOutput.Eq(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' == ' + ARight;
end;

function TCodeOutput.Ne(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' != ' + ARight;
end;

function TCodeOutput.Lt(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' < ' + ARight;
end;

function TCodeOutput.Le(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' <= ' + ARight;
end;

function TCodeOutput.Gt(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' > ' + ARight;
end;

function TCodeOutput.Ge(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' >= ' + ARight;
end;

function TCodeOutput.AndExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' && ' + ARight;
end;

function TCodeOutput.OrExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' || ' + ARight;
end;

function TCodeOutput.NotExpr(const AExpr: string): string;
begin
  Result := '!' + AExpr;
end;

function TCodeOutput.BitAnd(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' & ' + ARight;
end;

function TCodeOutput.BitOr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' | ' + ARight;
end;

function TCodeOutput.BitXor(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' ^ ' + ARight;
end;

function TCodeOutput.BitNot(const AExpr: string): string;
begin
  Result := '~' + AExpr;
end;

function TCodeOutput.ShlExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' << ' + ARight;
end;

function TCodeOutput.ShrExpr(const ALeft: string; const ARight: string): string;
begin
  Result := ALeft + ' >> ' + ARight;
end;

{ Output }

procedure TCodeOutput.SaveToFiles(const AHeaderPath: string; const ASourcePath: string);
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

function TCodeOutput.GetHeaderContent(): string;
begin
  Result := FHeaderBuffer.ToString();
end;

function TCodeOutput.GetSourceContent(): string;
begin
  Result := FSourceBuffer.ToString();
end;

{ Context store }

procedure TCodeOutput.SetContext(const AKey: string; const AValue: string);
begin
  FContext.AddOrSetValue(AKey, AValue);
end;

function TCodeOutput.GetContext(const AKey: string; const ADefault: string): string;
begin
  if not FContext.TryGetValue(AKey, Result) then
    Result := ADefault;
end;

procedure TCodeOutput.Clear();
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
