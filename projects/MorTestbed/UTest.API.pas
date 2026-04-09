{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UTest.API;

{$I Metamorf.Defines.inc}

interface

procedure Test_CompileBuild();
procedure Test_CustomCodeGen();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Metamorf;

// ===========================================================================
// Shared callbacks
// ===========================================================================

procedure OnStatus(const AMessage: PUTF8Char; const AUserData: Pointer);
begin
  WriteLn(UTF8ToString(AMessage));
end;

procedure OnOutput(const ALine: PUTF8Char; const AUserData: Pointer);
begin
  Write(UTF8ToString(ALine));
end;

procedure PrintErrors(const AHandle: TMorHandle);
var
  LI: Integer;
  LFile: string;
begin
  for LI := 0 to mor_error_count(AHandle) - 1 do
  begin
    LFile := UTF8ToString(mor_error_get_filename(AHandle, LI));
    if LFile <> '' then
      WriteLn(Format('%s(%d,%d): %s', [
        LFile,
        mor_error_get_line(AHandle, LI),
        mor_error_get_col(AHandle, LI),
        UTF8ToString(mor_error_get_message(AHandle, LI))]))
    else
      WriteLn(Format('%s: %s', [
        UTF8ToString(mor_error_get_code(AHandle, LI)),
        UTF8ToString(mor_error_get_message(AHandle, LI))]));
  end;
end;

// ===========================================================================
// Test 1: One-shot compilation (CLI equivalent)
// ===========================================================================

procedure Test_CompileBuild();
var
  LHandle: TMorHandle;
begin
  WriteLn('');
  WriteLn('=== Test_CompileAll ===');
  WriteLn('');

  LHandle := mor_create();
  try
    mor_set_status_callback(LHandle, OnStatus, nil);
    mor_set_output_callback(LHandle, OnOutput, nil);

    if mor_compile(LHandle,
      PUTF8Char(UTF8Encode('..\tests\pascal.mor')),
      PUTF8Char(UTF8Encode('..\tests\hello.pas')),
      PUTF8Char(UTF8Encode('output')),
      MOR_RUN_EXECUTE) then
    begin
      WriteLn('');
      PrintErrors(LHandle);
      WriteLn('PASS');
    end
    else
    begin
      WriteLn('');
      PrintErrors(LHandle);
      WriteLn('FAIL');
    end;
  finally
    mor_destroy(LHandle);
  end;
end;

// ===========================================================================
// Test 2: Custom code generation
//
// Let Metamorf handle lexing, parsing, and semantic analysis. Then skip
// RunEmitters/Build entirely and walk the fully typed AST ourselves to
// produce custom output (plain C in this example).
// ===========================================================================

procedure WalkNode(const AHandle: TMorHandle; const ANode: TMorNode;
  const AIndent: Integer);
var
  LKind: string;
  LI: Integer;
  LChildCount: Integer;
begin
  if ANode = 0 then Exit;

  LKind := UTF8ToString(mor_node_kind(AHandle, ANode));
  LChildCount := mor_node_child_count(ANode);

  // Print this node
  Write(StringOfChar(' ', AIndent));
  Write('[', LKind, ']');

  // Show key attributes if present
  if mor_node_has_attr(ANode, 'identifier') then
    Write(' name=', UTF8ToString(
      mor_node_get_attr(AHandle, ANode, 'identifier')));
  if mor_node_has_attr(ANode, 'value') then
    Write(' value=', UTF8ToString(
      mor_node_get_attr(AHandle, ANode, 'value')));
  if mor_node_has_attr(ANode, 'type_name') then
    Write(' type=', UTF8ToString(
      mor_node_get_attr(AHandle, ANode, 'type_name')));
  if mor_node_has_attr(ANode, 'source_name') then
    Write(' src=', UTF8ToString(
      mor_node_get_attr(AHandle, ANode, 'source_name')));
  if mor_node_has_attr(ANode, 'operator') then
    Write(' op=', UTF8ToString(
      mor_node_get_attr(AHandle, ANode, 'operator')));

  if LChildCount > 0 then
    Write(' (', LChildCount, ' children)');
  WriteLn('');

  // Recurse into children
  for LI := 0 to LChildCount - 1 do
    WalkNode(AHandle, mor_node_child(ANode, LI), AIndent + 2);
end;

procedure Test_CustomCodeGen();
var
  LHandle: TMorHandle;
  LRoot: TMorNode;
  LBranch: TMorNode;
  LI: Integer;
begin
  WriteLn('');
  WriteLn('=== Test_CustomCodeGen ===');
  WriteLn('');

  LHandle := mor_create();
  try
    mor_set_status_callback(LHandle, OnStatus, nil);
    mor_set_output_callback(LHandle, OnOutput, nil);

    // Load grammar
    if not mor_load_mor(LHandle,
      PUTF8Char(UTF8Encode('..\tests\pascal.mor'))) then
    begin
      WriteLn('FAIL: LoadMor');
      Exit;
    end;

    // Parse source
    if not mor_parse_source(LHandle,
      PUTF8Char(UTF8Encode('..\tests\hello.pas'))) then
    begin
      WriteLn('FAIL: ParseSource');
      Exit;
    end;

    // Run semantics (gives us a fully typed AST)
    if not mor_run_semantics(LHandle) then
    begin
      WriteLn('FAIL: RunSemantics');
      Exit;
    end;

    // Skip RunEmitters and Build entirely.
    // Walk the AST ourselves and produce custom C output.
    WriteLn('');
    WriteLn('--- AST dump via opaque API ---');
    WriteLn('');

    LRoot := mor_get_master_root(LHandle);
    for LI := 0 to mor_node_child_count(LRoot) - 1 do
    begin
      LBranch := mor_node_child(LRoot, LI);
      WalkNode(LHandle, LBranch, 0);
    end;

    WriteLn('');
    PrintErrors(LHandle);
    if not mor_has_errors(LHandle) then
      WriteLn('PASS')
    else
      WriteLn('FAIL');
  finally
    mor_destroy(LHandle);
  end;
end;

end.
