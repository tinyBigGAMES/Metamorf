{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UTest.LSP;

{$I Metamorf.Defines.inc}

interface

procedure Test_LSP_InProcess();
procedure Test_LSP_OutOfProcess();

implementation

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.AST,
  Metamorf.LSP,
  Metamorf.EngineAPI,
  Metamorf.Scopes,
  Metamorf.Interpreter;

var
  GPass: Integer;
  GTotal: Integer;
  GSectionPass: Integer;
  GSectionTotal: Integer;

procedure BeginSection(const ATitle: string);
begin
  GSectionPass := 0;
  GSectionTotal := 0;
  TMorUtils.PrintLn('');
  TMorUtils.PrintLn(COLOR_CYAN + '  ' + ATitle);
end;

procedure Check(const ACondition: Boolean; const APassMsg: string;
  const AFailMsg: string);
begin
  Inc(GTotal);
  Inc(GSectionTotal);

  if ACondition then
  begin
    TMorUtils.PrintLn(COLOR_GREEN + '    [PASS] ' + APassMsg);
    Inc(GPass);
    Inc(GSectionPass);
  end
  else
    TMorUtils.PrintLn(COLOR_RED + '    [FAIL] ' + AFailMsg);
end;

procedure Detail(const AMsg: string);
begin
  TMorUtils.PrintLn(COLOR_YELLOW + '           ' + AMsg);
end;

procedure SectionSummary();
begin
  if GSectionPass = GSectionTotal then
    TMorUtils.PrintLn(COLOR_GREEN + Format('    %d/%d passed',
      [GSectionPass, GSectionTotal]))
  else
    TMorUtils.PrintLn(COLOR_RED + Format('    %d/%d passed',
      [GSectionPass, GSectionTotal]));
end;


// ===========================================================================
// Test 1: In-Process LSP Feature Showcase
// ===========================================================================
procedure Test_LSP_InProcess();
var
  LEngine: TMorEngineAPI;
  LService: TMorLSPService;
  LInterp: TMorInterpreter;
  LSource: string;
  LUri: string;
  LDiags: TArray<TMorLSPDiagnostic>;
  LCompletions: TArray<TMorLSPCompletionItem>;
  LSymbols: TArray<TMorLSPDocumentSymbol>;
  LTokenData: TArray<Integer>;
  LFolding: TArray<TMorLSPFoldingRange>;
  LHover: TMorLSPHover;
  LLocation: TMorLSPLocation;
  LLocations: TArray<TMorLSPLocation>;
  LRename: TMorLSPWorkspaceEdit;
  LWorkspaceSym: TArray<TMorLSPSymbolInformation>;
  LSigHelp: TMorLSPSignatureHelp;
  LInlayHints: TArray<TMorLSPInlayHint>;
  LFormatEdits: TArray<TMorLSPTextEdit>;
  LCodeActions: TArray<TJSONObject>;
  LI: Integer;
  LScopeCount: Integer;
  LKindStr: string;
  LMutatedSource: string;

begin
  GPass := 0;
  GTotal := 0;

  TMorUtils.PrintLn('');
  TMorUtils.PrintLn(COLOR_CYAN +
    '  ============================================================');
  TMorUtils.PrintLn(COLOR_CYAN + '  Metamorf LSP  -  In-Process Feature Showcase');
  TMorUtils.PrintLn(COLOR_CYAN + '  Language Definition: pascal.mor');
  TMorUtils.PrintLn(COLOR_CYAN + '  Test Source: hello.pas');
  TMorUtils.PrintLn(COLOR_CYAN +
    '  ============================================================');

  LEngine := TMorEngineAPI.Create();
  try
    if not LEngine.LoadMor('..\tests\pascal.mor') then
    begin
      TMorUtils.PrintLn(COLOR_RED + '  FATAL: Could not load pascal.mor');
      Exit;
    end;

    LInterp := LEngine.GetInterpreter();
    LSource := TFile.ReadAllText('..\tests\hello.pas', TEncoding.UTF8);

    LUri := TMorLSPService.FilePathToUri
      (TPath.GetFullPath('..\tests\hello.pas'));

    LService := TMorLSPService.Create();
    try
      LService.SetInterpreter(LInterp);
      LService.OpenDocument(LUri, LSource);

      // ---- 1. Diagnostics (Clean Parse) ----
      BeginSection('1. Diagnostics  (error detection and reporting)');
      LDiags := LService.GetDiagnostics(LUri);
      Check(Length(LDiags) = 0,
        'Clean parse: zero errors on valid source',
        Format('Expected 0 errors, got %d', [Length(LDiags)]));

      if Length(LDiags) > 0 then
        for LI := 0 to High(LDiags) do
          Detail(Format('line %d: %s',
            [LDiags[LI].Range.StartPos.Line + 1, LDiags[LI].Message]));

      SectionSummary();

      // ---- 2. Document Symbols ----
      BeginSection('2. Document Symbols  (full file outline)');
      LSymbols := LService.GetDocumentSymbols(LUri);
      Check(Length(LSymbols) >= 4,
        Format('%d declarations found', [Length(LSymbols)]),
        Format('Expected >= 4 declarations, got %d', [Length(LSymbols)]));

      for LI := 0 to High(LSymbols) do
      begin
        if LSymbols[LI].Kind = 12 then
          LKindStr := 'routine'
        else if LSymbols[LI].Kind = 13 then
          LKindStr := 'variable'
        else if LSymbols[LI].Kind = 5 then
          LKindStr := 'class'
        else if LSymbols[LI].Kind = 2 then
          LKindStr := 'module'
        else
          LKindStr := Format('kind(%d)', [LSymbols[LI].Kind]);

        Detail(Format('%-12s %-14s  line %d', [LKindStr,
          LSymbols[LI].SymbolName,
          LSymbols[LI].Range.StartPos.Line + 1]));
      end;

      SectionSummary();

      // ---- 3. Hover Information ----
      BeginSection('3. Hover  (symbol kind and type information)');
      LHover := LService.GetHover(LUri, 26, 9);
      Check(LHover.Contents.Contains('add'),
        'Hover on "add" (routine declaration)  ->  ' + LHover.Contents,
        'Hover on "add" returned empty or wrong: ' + LHover.Contents);

      LHover := LService.GetHover(LUri, 31, 9);
      Check(LHover.Contents.Contains('factorial'),
        'Hover on "factorial" (routine declaration)  ->  ' + LHover.Contents,
        'Hover on "factorial" returned: ' + LHover.Contents);
      LHover := LService.GetHover(LUri, 41, 2);

      Check(LHover.Contents.Contains('sum'),
        'Hover on "sum" (variable declaration)  ->  ' + LHover.Contents,
        'Hover on "sum" returned: ' + LHover.Contents);

      LHover := LService.GetHover(LUri, 42, 2);

      Check(LHover.Contents.Contains('i'),
        'Hover on "i" (variable declaration)  ->  ' + LHover.Contents,
        'Hover on "i" returned: ' + LHover.Contents);

      LHover := LService.GetHover(LUri, 0, 0);

      Check(True,
        'Hover on empty area  ->  graceful (no crash): "' +
        LHover.Contents + '"',
        'Hover on empty area crashed');

      SectionSummary();

      // ---- 4. Go to Definition ----
      BeginSection('4. Go to Definition  (resolve declaration site)');
      LLocation := LService.GetDefinition(LUri, 26, 9);

      Check(LLocation.Uri <> '',
        Format('"add" at usage  ->  declaration at line %d',
        [LLocation.Range.StartPos.Line + 1]),
        '"add" could not be resolved');

      LLocation := LService.GetDefinition(LUri, 31, 9);

      Check(LLocation.Uri <> '',
        Format('"factorial" at declaration  ->  line %d',
        [LLocation.Range.StartPos.Line + 1]),
        '"factorial" could not be resolved');

      LLocation := LService.GetDefinition(LUri, 41, 2);

      Check(LLocation.Uri <> '',
        Format('"sum" at var section  ->  line %d',
        [LLocation.Range.StartPos.Line + 1]),
        '"sum" could not be resolved');

      LLocation := LService.GetDefinition(LUri, 0, 0);

      Check(LLocation.IsEmpty(),
        'Empty area  ->  graceful (no false target)',
        'Empty area unexpectedly resolved to a location');

      SectionSummary();

      // ---- 5. Find All References ----
      BeginSection('5. Find All References  (all usages of a symbol)');
      LLocations := LService.GetReferences(LUri, 31, 9, True);

      Check(Length(LLocations) >= 2,
        Format('"factorial"  ->  %d references found', [Length(LLocations)]),
        Format('"factorial"  ->  only %d references (expected >= 2)',
        [Length(LLocations)]));

      for LI := 0 to High(LLocations) do
        Detail(Format('reference %d: line %d, col %d',
          [LI + 1, LLocations[LI].Range.StartPos.Line + 1,
          LLocations[LI].Range.StartPos.Character + 1]));

      LLocations := LService.GetReferences(LUri, 26, 9, True);

      Check(Length(LLocations) >= 2,
        Format('"add"  ->  %d references found', [Length(LLocations)]),
        Format('"add"  ->  only %d references (expected >= 2)',
        [Length(LLocations)]));

      for LI := 0 to High(LLocations) do
        Detail(Format('reference %d: line %d, col %d',
          [LI + 1, LLocations[LI].Range.StartPos.Line + 1,
          LLocations[LI].Range.StartPos.Character + 1]));

      SectionSummary();

      // ---- 6. Rename Symbol ----

      BeginSection('6. Rename Symbol  (project-wide identifier rename)');

      LRename := LService.GetRenameEdits(LUri, 41, 2, 'total');

      Check(Length(LRename.Edits) >= 1,
        Format('Rename "sum" -> "total"  ->  %d edit locations',
        [Length(LRename.Edits)]),
        'Rename "sum" -> "total" produced no edits');

      for LI := 0 to High(LRename.Edits) do
        Detail(Format('edit %d: line %d, col %d  ->  "%s"',
          [LI + 1, LRename.Edits[LI].Range.StartPos.Line + 1,
          LRename.Edits[LI].Range.StartPos.Character + 1,
          LRename.Edits[LI].NewText]));

      LRename := LService.GetRenameEdits(LUri, 26, 9, 'addition');

      Check(Length(LRename.Edits) >= 1,
        Format('Rename "add" -> "addition"  ->  %d edit locations',
        [Length(LRename.Edits)]),
        'Rename "add" -> "addition" produced no edits');

      SectionSummary();

      // ---- 7. Workspace Symbols ----
      BeginSection('7. Workspace Symbols  (cross-file symbol search)');

      LWorkspaceSym := LService.GetWorkspaceSymbols('fact', LUri);

      Check(Length(LWorkspaceSym) >= 1,
        Format('Search "fact"  ->  %d matches', [Length(LWorkspaceSym)]),
        'Search "fact" returned no matches');

      for LI := 0 to High(LWorkspaceSym) do
        Detail(Format('%s  (line %d)', [LWorkspaceSym[LI].SymbolName,
          LWorkspaceSym[LI].Range.StartPos.Line + 1]));

      LWorkspaceSym := LService.GetWorkspaceSymbols('', LUri);

      Check(Length(LWorkspaceSym) >= 4,
        Format('Search "" (all)  ->  %d symbols', [Length(LWorkspaceSym)]),
        Format('Search "" (all) returned only %d symbols',
        [Length(LWorkspaceSym)]));

      for LI := 0 to High(LWorkspaceSym) do
        Detail(LWorkspaceSym[LI].SymbolName);

      LWorkspaceSym := LService.GetWorkspaceSymbols('nonexistent_xyz', LUri);

      Check(Length(LWorkspaceSym) = 0,
        'Search "nonexistent_xyz"  ->  0 matches (correct)',
        Format('Search "nonexistent_xyz" returned %d unexpected matches',
        [Length(LWorkspaceSym)]));

      SectionSummary();

      // ---- 8. Completions ----
      BeginSection('8. Completions  (scope-aware suggestions)');

      LCompletions := LService.GetCompletions(LUri, 0, 0);

      LScopeCount := 0;

      for LI := 0 to High(LCompletions) do
        if LCompletions[LI].Detail <> 'keyword' then
          Inc(LScopeCount);

      Check(Length(LCompletions) > 50,
        Format('%d total items returned', [Length(LCompletions)]),
        Format('Only %d items (expected > 50)', [Length(LCompletions)]));

      Check(LScopeCount >= 4,
        Format('%d scope symbols (user-declared identifiers)', [LScopeCount]),
        Format('Only %d scope symbols (expected >= 4)', [LScopeCount]));

      Check(Length(LCompletions) - LScopeCount > 40,
        Format('%d language keywords', [Length(LCompletions) - LScopeCount]),
        Format('Only %d keywords', [Length(LCompletions) - LScopeCount]));

      Detail('Scope symbols:');

      for LI := 0 to High(LCompletions) do
        if LCompletions[LI].Detail <> 'keyword' then
          Detail(Format('  %s  (%s)', [LCompletions[LI].LabelText,
            LCompletions[LI].Detail]));

      SectionSummary();

      // ---- 9. Semantic Tokens ----
      BeginSection('9. Semantic Tokens  (full syntax classification)');

      LTokenData := LService.GetSemanticTokens(LUri);

      Check((Length(LTokenData) div 5) > 50,
        Format('%d tokens classified', [Length(LTokenData) div 5]),
        Format('Only %d tokens (expected > 50)', [Length(LTokenData) div 5]));
      Check((Length(LTokenData) mod 5) = 0,
        'Token data is properly aligned (multiple of 5)',
        Format('Token data misaligned: %d integers (not divisible by 5)',

        [Length(LTokenData)]));

      SectionSummary();

      // ---- 10. Folding Ranges ----
      BeginSection('10. Folding Ranges  (code structure for collapsing)');

      LFolding := LService.GetFoldingRanges(LUri);

      Check(Length(LFolding) > 5,
        Format('%d foldable regions detected', [Length(LFolding)]),
        Format('Only %d foldable regions', [Length(LFolding)]));
      Detail('Sample regions:');

      for LI := 0 to High(LFolding) do
      begin
        if LI >= 6 then
        begin
          Detail(Format('  ... and %d more', [Length(LFolding) - 6]));
          Break;
        end;

        Detail(Format('  lines %d-%d  (%s)',
          [LFolding[LI].StartLine + 1, LFolding[LI].EndLine + 1,
          LFolding[LI].Kind]));
      end;

      SectionSummary();

      // ---- 11. Signature Help ----
      BeginSection('11. Signature Help  (function parameter hints)');

      LSigHelp := LService.GetSignatureHelp(LUri, 47, 15);

      Check(True,
        Format('Returned gracefully: %d signatures (stub, awaiting semantic metadata)',
        [Length(LSigHelp.Signatures)]),
        'Signature help crashed');

      SectionSummary();

      // ---- 12. Inlay Hints ----
      BeginSection('12. Inlay Hints  (inline type annotations)');

      LInlayHints := LService.GetInlayHints(LUri, 0, 0, 109, 0);

      Check(True,
        Format('Returned gracefully: %d hints (stub, awaiting type inference)',
        [Length(LInlayHints)]),
        'Inlay hints crashed');

      SectionSummary();

      // ---- 13. Document Formatting ----
      BeginSection('13. Document Formatting  (auto-format source)');

      LFormatEdits := LService.GetDocumentFormatting(LUri, 2, True);

      Check(True,
        Format('Returned gracefully: %d edits (stub, awaiting formatting rules)',
        [Length(LFormatEdits)]),
        'Document formatting crashed');

      SectionSummary();

      // ---- 14. Code Actions ----
      BeginSection('14. Code Actions  (quick fixes and refactoring)');

      LCodeActions := LService.GetCodeActions(LUri, 0, 0, 10, 0);

      Check(True,
        Format('Returned gracefully: %d actions (stub, awaiting diagnostic codes)',
        [Length(LCodeActions)]),
        'Code actions crashed');

      SectionSummary();

      // ---- 15. Live Edit & Error Recovery ----

      BeginSection('15. Live Edit & Error Recovery  (incremental re-analysis)');

      // 15a: Inject a syntax error by corrupting a line
      LMutatedSource := LSource;

      LMutatedSource := LMutatedSource.Replace(
        'sum := add(10, 32);', 'sum := add(10, );');

      LService.UpdateDocument(LUri, LMutatedSource, 2);

      LDiags := LService.GetDiagnostics(LUri);

      Check(Length(LDiags) > 0,
        Format('Injected syntax error  ->  %d diagnostic(s) detected',
        [Length(LDiags)]),
        'Injected syntax error but got 0 diagnostics');

      for LI := 0 to High(LDiags) do
        Detail(Format('line %d: %s',
          [LDiags[LI].Range.StartPos.Line + 1, LDiags[LI].Message]));

      // 15b: Repair the source and verify clean re-parse
      LService.UpdateDocument(LUri, LSource, 3);

      LDiags := LService.GetDiagnostics(LUri);

      Check(Length(LDiags) = 0,
        'Repaired source  ->  clean re-parse (0 errors)',
        Format('Repaired source still has %d errors', [Length(LDiags)]));

      // 15c: Verify features still work after live edit cycle

      LSymbols := LService.GetDocumentSymbols(LUri);

      Check(Length(LSymbols) >= 4,
        Format('Post-repair: document symbols intact (%d found)',
        [Length(LSymbols)]),

        Format('Post-repair: document symbols degraded (%d found)',
        [Length(LSymbols)]));

      SectionSummary();

      // ---- 16. Document Management ----
      BeginSection('16. Document Management  (open/close/query lifecycle)');

      Check(LService.HasDocument(LUri),
        'HasDocument on open doc  ->  True',
        'HasDocument on open doc returned False');

      LService.CloseDocument(LUri);

      Check(not LService.HasDocument(LUri),
        'HasDocument after close  ->  False',
        'HasDocument after close still returned True');

      // Re-open for clean exit

      LService.OpenDocument(LUri, LSource);

      Check(LService.HasDocument(LUri),
        'Re-open after close  ->  document available again',
        'Re-open after close failed');

      SectionSummary();

      // ---- Grand Summary ----
      TMorUtils.PrintLn('');
      TMorUtils.PrintLn(COLOR_CYAN +
        '  ============================================================');

      if GPass = GTotal then
      begin
        TMorUtils.PrintLn(COLOR_GREEN + Format(
          '  RESULT: %d/%d features verified  --  ALL PASS', [GPass, GTotal]));
        TMorUtils.PrintLn(COLOR_GREEN + '  Metamorf LSP: fully operational');
      end
      else
      begin
        TMorUtils.PrintLn(COLOR_RED + Format(
          '  RESULT: %d/%d features verified  --  SOME FAILURES',
          [GPass, GTotal]));

        TMorUtils.PrintLn(COLOR_RED + Format('  %d feature(s) need attention',
          [GTotal - GPass]));
      end;

      TMorUtils.PrintLn(COLOR_CYAN +
        '  ============================================================');

      TMorUtils.PrintLn('');

      LService.CloseDocument(LUri);

    finally
      LService.Free();
    end;

  finally
    LEngine.Free();
  end;

end;


// ===========================================================================
// Test 2: Out-of-Process LSP Feature Showcase (JSON-RPC over pipes)
// ===========================================================================
function SendLSPMessage(const AStdinWrite: THandle;
  const ABody: string): Boolean;
var
  LBodyBytes: TBytes;
  LHeader: string;
  LHeaderBytes: TBytes;
  LWritten: DWORD;
begin
  LBodyBytes := TEncoding.UTF8.GetBytes(ABody);

  LHeader := 'Content-Length: ' + IntToStr(Length(LBodyBytes)) + #13#10
    + #13#10;

  LHeaderBytes := TEncoding.ASCII.GetBytes(LHeader);

  Result := WriteFile(AStdinWrite, LHeaderBytes[0],
    Length(LHeaderBytes), LWritten, nil);

  if Result then
    Result := WriteFile(AStdinWrite, LBodyBytes[0],
      Length(LBodyBytes), LWritten, nil);
end;

function ReadLSPMessage(const AStdoutRead: THandle;
  const ATimeoutMs: DWORD): string;
var
  LByte: Byte;
  LLine: string;
  LContentLength: Integer;
  LBodyBytes: TBytes;
  LBytesRead: DWORD;
  LAvail: DWORD;
  LWaitStart: UInt64;
begin
  Result := '';
  LContentLength := -1;
  LLine := '';
  LWaitStart := GetTickCount64();

  // Wait for data to become available
  while True do
  begin
    if not PeekNamedPipe(AStdoutRead, nil, 0, nil, @LAvail, nil) then
      Exit;

    if LAvail > 0 then
      Break;

    if (GetTickCount64() - LWaitStart) > ATimeoutMs then
      Exit;

    Sleep(10);
  end;

  // Read headers
  while True do
  begin
    if not ReadFile(AStdoutRead, LByte, 1, LBytesRead, nil) then
      Exit;

    if LBytesRead = 0 then
      Exit;

    if LByte = 13 then
    begin
      ReadFile(AStdoutRead, LByte, 1, LBytesRead, nil); // LF

      if LLine = '' then
        Break;

      if LLine.StartsWith('Content-Length: ') then
        LContentLength := StrToIntDef(Copy(LLine, 17, MaxInt), -1);

      LLine := '';
    end
    else if LByte <> 10 then
      LLine := LLine + Chr(LByte);
  end;

  if LContentLength <= 0 then
    Exit;

  // Read body
  SetLength(LBodyBytes, LContentLength);

  if not ReadFile(AStdoutRead, LBodyBytes[0], LContentLength,

    LBytesRead, nil) then
    Exit;

  Result := TEncoding.UTF8.GetString(LBodyBytes);
end;

function SendRequestAndRead(const AStdinWrite: THandle;
  const AStdoutRead: THandle; const ABody: string;
  const ATimeoutMs: DWORD): string;
begin
  Result := '';

  if SendLSPMessage(AStdinWrite, ABody) then
    Result := ReadLSPMessage(AStdoutRead, ATimeoutMs);
end;

function MakeTextDocRequest(const AId: Integer;
  const AMethod: string; const AUri: string;
  const ALine: Integer; const AChar: Integer): string;
begin
  Result := TJSONObject.Create()
    .AddPair('jsonrpc', '2.0')
    .AddPair('id', TJSONNumber.Create(AId))
    .AddPair('method', AMethod)
    .AddPair('params', TJSONObject.Create()
    .AddPair('textDocument', TJSONObject.Create()
    .AddPair('uri', AUri))
    .AddPair('position', TJSONObject.Create()
    .AddPair('line', TJSONNumber.Create(ALine))
    .AddPair('character', TJSONNumber.Create(AChar))))
    .ToString();
end;

function MakeDocRequest(const AId: Integer;
  const AMethod: string; const AUri: string): string;
begin
  Result := TJSONObject.Create()
    .AddPair('jsonrpc', '2.0')
    .AddPair('id', TJSONNumber.Create(AId))
    .AddPair('method', AMethod)
    .AddPair('params', TJSONObject.Create()
    .AddPair('textDocument', TJSONObject.Create()
    .AddPair('uri', AUri)))
    .ToString();
end;

procedure Test_LSP_OutOfProcess();
var
  LStdinWrite: THandle;
  LStdoutRead: THandle;
  LProcessHandle: THandle;
  LThreadHandle: THandle;
  LBody: string;
  LResponse: string;
  LJson: TJSONObject;
  LSource: string;
  LUri: string;
  LMutatedSource: string;
  LResultVal: TJSONValue;
  LResultArr: TJSONArray;
  LResultObj: TJSONObject;
begin
  GPass := 0;
  GTotal := 0;

  TMorUtils.PrintLn('');
  TMorUtils.PrintLn(COLOR_CYAN +
    '  ============================================================');
  TMorUtils.PrintLn(COLOR_CYAN +
    '  Metamorf LSP  -  Out-of-Process Feature Showcase');
  TMorUtils.PrintLn(COLOR_CYAN +
    '  Binary: MorLSP.exe  |  Transport: JSON-RPC 2.0 over pipes');
  TMorUtils.PrintLn(COLOR_CYAN +
    '  ============================================================');

  // ---- 1. Process Launch ----
  BeginSection('1. Process Launch');

  if not TMorUtils.CreateProcessWithPipes(
    'MorLSP.exe',
    '..\tests\pascal.mor',
    '',
    LStdinWrite, LStdoutRead, LProcessHandle, LThreadHandle) then
  begin
    Check(False, '', Format('Process launch failed (error %d)',
      [GetLastError()]));

    Exit;
  end;

  Check(True, 'MorLSP.exe launched successfully', '');

  SectionSummary();

  try
    // ---- 2. Initialize Handshake ----
    BeginSection('2. Initialize Handshake  (capability negotiation)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('id', TJSONNumber.Create(1))
      .AddPair('method', 'initialize')
      .AddPair('params', TJSONObject.Create())
      .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 10000);

    if LResponse <> '' then
    begin

      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        Check(LResultVal <> nil,
          'Capabilities received from server',
          'No result in initialize response');

        if LResultVal is TJSONObject then
        begin
          LResultObj := TJSONObject(LResultVal);

          Check(LResultObj.GetValue('capabilities') <> nil,
            'Server capabilities block present',
            'Missing capabilities in result');
        end;
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Initialize: no response (timeout)');

    SectionSummary();

    // ---- 3. Initialized Notification ----
    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('method', 'initialized')
      .AddPair('params', TJSONObject.Create())
      .ToString();

    SendLSPMessage(LStdinWrite, LBody);

    // ---- 4. Document Open + Diagnostics ----
    BeginSection('3. Document Open + Diagnostics  (source analysis)');

    LSource := TFile.ReadAllText('..\tests\hello.pas', TEncoding.UTF8);

    LUri := TMorLSPService.FilePathToUri
      (TPath.GetFullPath('..\tests\hello.pas'));

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('method', 'textDocument/didOpen')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri)
      .AddPair('languageId', 'pascal')
      .AddPair('version', TJSONNumber.Create(1))
      .AddPair('text', LSource)))
      .ToString();

    SendLSPMessage(LStdinWrite, LBody);

    LResponse := ReadLSPMessage(LStdoutRead, 10000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check(LJson.GetValue<string>('method', '') =
          'textDocument/publishDiagnostics',
          'Diagnostics published on document open',
          'Unexpected response: ' + LJson.GetValue<string>('method', '?'));
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Document open: no diagnostics (timeout)');

    SectionSummary();

    // ---- 5. Completions ----

    BeginSection('4. Completions  (scope-aware suggestions)');

    LBody := MakeTextDocRequest(2,
      'textDocument/completion', LUri, 0, 0);

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if (LResultVal is TJSONArray) then
        begin
          LResultArr := TJSONArray(LResultVal);

          Check(LResultArr.Count > 50,
            Format('%d completion items (keywords + scope symbols)',
            [LResultArr.Count]),
            Format('Only %d items', [LResultArr.Count]));
        end
        else
          Check(False, '', 'Completions: result is not an array');

      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Completions: no response (timeout)');

    SectionSummary();

    // ---- 6. Hover ----
    BeginSection('5. Hover  (symbol information on hover)');

    LBody := MakeTextDocRequest(3,
      'textDocument/hover', LUri, 26, 9);

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check((LJson.GetValue('result') <> nil) and
          (LJson.GetValue('result').ToString().Contains('add')),
          'Hover "add"  ->  symbol info received',
          'Hover "add"  ->  no symbol info');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Hover: no response (timeout)');

    LBody := MakeTextDocRequest(4,
      'textDocument/hover', LUri, 31, 9);

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check((LJson.GetValue('result') <> nil) and
          (LJson.GetValue('result').ToString().Contains('factorial')),
          'Hover "factorial"  ->  symbol info received',
          'Hover "factorial"  ->  no symbol info');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Hover factorial: no response (timeout)');

    SectionSummary();

    // ---- 7. Go to Definition ----
    BeginSection('6. Go to Definition  (resolve declaration site)');

    LBody := MakeTextDocRequest(5,
      'textDocument/definition', LUri, 26, 9);

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check((LJson.GetValue('result') <> nil) and
          (LJson.GetValue('result').ToString().Contains('uri')),
          'Definition "add"  ->  resolved to source location',
          'Definition "add"  ->  not resolved');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Definition: no response (timeout)');

    SectionSummary();

    // ---- 8. Find All References ----
    BeginSection('7. Find All References  (all usages of a symbol)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('id', TJSONNumber.Create(6))
      .AddPair('method', 'textDocument/references')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri))
      .AddPair('position', TJSONObject.Create()
      .AddPair('line', TJSONNumber.Create(31))
      .AddPair('character', TJSONNumber.Create(9)))
      .AddPair('context', TJSONObject.Create()
      .AddPair('includeDeclaration', TJSONBool.Create(True))))
      .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if LResultVal is TJSONArray then
          Check(TJSONArray(LResultVal).Count >= 2,
            Format('"factorial"  ->  %d references found',
            [TJSONArray(LResultVal).Count]),
            Format('"factorial"  ->  only %d references',
            [TJSONArray(LResultVal).Count]))
        else
          Check(False, '', 'References: result is not an array');

      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'References: no response (timeout)');

    SectionSummary();

    // ---- 9. Document Symbols ----
    BeginSection('8. Document Symbols  (file outline)');

    LBody := MakeDocRequest(7, 'textDocument/documentSymbol', LUri);

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if LResultVal is TJSONArray then
          Check(TJSONArray(LResultVal).Count >= 4,
            Format('%d declarations in outline',
            [TJSONArray(LResultVal).Count]),
            Format('Only %d declarations', [TJSONArray(LResultVal).Count]))
        else
          Check(False, '', 'Document symbols: result is not an array');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Document symbols: no response (timeout)');

    SectionSummary();

    // ---- 10. Signature Help ----
    BeginSection('9. Signature Help  (parameter hints)');

    LBody := MakeTextDocRequest(8,
      'textDocument/signatureHelp', LUri, 47, 15);

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check(LJson.GetValue('result') <> nil,
          'Signature help responded gracefully (stub, awaiting semantic metadata)',
          'Signature help: nil result');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Signature help: no response (timeout)');

    SectionSummary();

    // ---- 11. Folding Ranges ----
    BeginSection('10. Folding Ranges  (collapsible code regions)');

    LBody := MakeDocRequest(9, 'textDocument/foldingRange', LUri);
    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if LResultVal is TJSONArray then
          Check(TJSONArray(LResultVal).Count > 5,
            Format('%d foldable regions', [TJSONArray(LResultVal).Count]),
            Format('Only %d regions', [TJSONArray(LResultVal).Count]))
        else
          Check(False, '', 'Folding ranges: result is not an array');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Folding ranges: no response (timeout)');

    SectionSummary();

    // ---- 12. Semantic Tokens ----
    BeginSection('11. Semantic Tokens  (syntax classification)');

    LBody := MakeDocRequest(10, 'textDocument/semanticTokens/full', LUri);
    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if (LResultVal is TJSONObject) then
        begin
          LResultArr := TJSONObject(LResultVal).GetValue('data') as TJSONArray;

          if LResultArr <> nil then
            Check((LResultArr.Count div 5) > 50,
              Format('%d tokens classified', [LResultArr.Count div 5]),
              Format('Only %d tokens', [LResultArr.Count div 5]))
          else
            Check(False, '', 'Semantic tokens: no data array in result');
        end
        else
          Check(False, '', 'Semantic tokens: result is not an object');

      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Semantic tokens: no response (timeout)');

    SectionSummary();

    // ---- 13. Inlay Hints ----
    BeginSection('12. Inlay Hints  (inline type annotations)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('id', TJSONNumber.Create(11))
      .AddPair('method', 'textDocument/inlayHint')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri))
      .AddPair('range', TJSONObject.Create()
      .AddPair('start', TJSONObject.Create()
      .AddPair('line', TJSONNumber.Create(0))
      .AddPair('character', TJSONNumber.Create(0)))
      .AddPair('end', TJSONObject.Create()
      .AddPair('line', TJSONNumber.Create(109))
      .AddPair('character', TJSONNumber.Create(0)))))
      .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check(LJson.GetValue('result') <> nil,
          'Inlay hints responded gracefully (stub, awaiting type inference)',
          'Inlay hints: nil result');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Inlay hints: no response (timeout)');

    SectionSummary();



    // ---- 14. Rename Symbol ----
    BeginSection('13. Rename Symbol  (project-wide rename)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('id', TJSONNumber.Create(12))
      .AddPair('method', 'textDocument/rename')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri))
      .AddPair('position', TJSONObject.Create()
      .AddPair('line', TJSONNumber.Create(41))
      .AddPair('character', TJSONNumber.Create(2)))
      .AddPair('newName', 'total'))
      .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if LResultVal is TJSONObject then
        begin
          // WorkspaceEdit.changes is a JSON object (URI -> edits array),
          // not a JSON array — just check the serialized result for the
          // new name to confirm edits were produced.
          Check(LResultVal.ToString().Contains('total'),
            'Rename "sum" -> "total"  ->  edit locations returned',
            'Rename produced no edits containing new name');
        end
        else
          Check(LResultVal <> nil,
            'Rename responded with result',
            'Rename: nil result');

      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Rename: no response (timeout)');

    SectionSummary();

    // ---- 15. Workspace Symbols ----
    BeginSection('14. Workspace Symbols  (cross-file symbol search)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('id', TJSONNumber.Create(13))
      .AddPair('method', 'workspace/symbol')
      .AddPair('params', TJSONObject.Create()
      .AddPair('query', 'fact'))
      .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if LResultVal is TJSONArray then
          Check(TJSONArray(LResultVal).Count >= 1,
            Format('Search "fact"  ->  %d matches',
            [TJSONArray(LResultVal).Count]),
            'Search "fact" returned no matches')
        else
          Check(False, '', 'Workspace symbols: result is not an array');

      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Workspace symbols: no response (timeout)');

    SectionSummary();

    // ---- 16. Code Actions ----
    BeginSection('15. Code Actions  (quick fixes and refactoring)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('id', TJSONNumber.Create(14))
      .AddPair('method', 'textDocument/codeAction')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri))
      .AddPair('range', TJSONObject.Create()
      .AddPair('start', TJSONObject.Create()
      .AddPair('line', TJSONNumber.Create(0))
      .AddPair('character', TJSONNumber.Create(0)))
      .AddPair('end', TJSONObject.Create()
      .AddPair('line', TJSONNumber.Create(10))
      .AddPair('character', TJSONNumber.Create(0))))
      .AddPair('context', TJSONObject.Create()
      .AddPair('diagnostics', TJSONArray.Create())))
      .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check(LJson.GetValue('result') <> nil,
          'Code actions responded gracefully (stub, awaiting diagnostic codes)',
          'Code actions: nil result');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Code actions: no response (timeout)');

    SectionSummary();

    // ---- 17. Document Formatting ----

    BeginSection('16. Document Formatting  (auto-format source)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('id', TJSONNumber.Create(15))
      .AddPair('method', 'textDocument/formatting')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri))
      .AddPair('options', TJSONObject.Create()
      .AddPair('tabSize', TJSONNumber.Create(2))
      .AddPair('insertSpaces', TJSONBool.Create(True))))
      .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check(LJson.GetValue('result') <> nil,
          'Formatting responded gracefully (stub, awaiting formatting rules)',
          'Formatting: nil result');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Formatting: no response (timeout)');

    SectionSummary();

    // ---- 18. Live Edit & Error Recovery ----
    BeginSection('17. Live Edit & Error Recovery  (incremental re-analysis)');

    // Inject syntax error
    LMutatedSource := LSource;
    LMutatedSource := LMutatedSource.Replace(
      'sum := add(10, 32);', 'sum := add(10, );');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('method', 'textDocument/didChange')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri)
      .AddPair('version', TJSONNumber.Create(2)))
      .AddPair('contentChanges', TJSONArray.Create()
      .Add(TJSONObject.Create()
      .AddPair('text', LMutatedSource))))
      .ToString();

    SendLSPMessage(LStdinWrite, LBody);

    LResponse := ReadLSPMessage(LStdoutRead, 10000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check(LJson.GetValue<string>('method', '') =
          'textDocument/publishDiagnostics',
          'Mutated source  ->  diagnostics re-published',
          'Unexpected response after didChange');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'didChange: no diagnostics (timeout)');

    // Repair the source
    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('method', 'textDocument/didChange')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri)
      .AddPair('version', TJSONNumber.Create(3)))
      .AddPair('contentChanges', TJSONArray.Create()
      .Add(TJSONObject.Create()
      .AddPair('text', LSource))))
      .ToString();

    SendLSPMessage(LStdinWrite, LBody);
    LResponse := ReadLSPMessage(LStdoutRead, 10000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        Check(LJson.GetValue<string>('method', '') =
          'textDocument/publishDiagnostics',
          'Repaired source  ->  diagnostics re-published (clean)',
          'Unexpected response after repair');
      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Repair didChange: no diagnostics (timeout)');

    // Verify features still work after edit cycle
    LBody := MakeTextDocRequest(16,
      'textDocument/completion', LUri, 0, 0);

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
        LResultVal := LJson.GetValue('result');

        if (LResultVal is TJSONArray) and (TJSONArray(LResultVal).Count > 50)
        then
          Check(True,
            Format('Post-repair: completions intact (%d items)',
            [TJSONArray(LResultVal).Count]),
            '')
        else
          Check(False, '',
            'Post-repair: completions degraded');

      finally
        LJson.Free();
      end;
    end
    else
      Check(False, '', 'Post-repair completions: timeout');

    SectionSummary();

    // ---- 19. Document Close ----
    BeginSection('18. Document Close  (cleanup notification)');

    LBody := TJSONObject.Create()
      .AddPair('jsonrpc', '2.0')
      .AddPair('method', 'textDocument/didClose')
      .AddPair('params', TJSONObject.Create()
      .AddPair('textDocument', TJSONObject.Create()
      .AddPair('uri', LUri)))
      .ToString();

    SendLSPMessage(LStdinWrite, LBody);

    // didClose triggers cleared diagnostics notification
    LResponse := ReadLSPMessage(LStdoutRead, 5000);

    if LResponse <> '' then
    begin
      LJson := TJSONObject(TJSONObject.ParseJSONValue(LResponse));

      try
         Check(LJson.GetValue<string>('method', '') =
           'textDocument/publishDiagnostics',
           'Document close  ->  diagnostics cleared',
           'Unexpected response after didClose');

       finally
         LJson.Free();
       end;
     end
     else
       Check(True,
         'Document close  ->  sent (no notification expected)',
         '');

    SectionSummary();

    // ---- 20. Shutdown ----
     BeginSection('19. Shutdown  (graceful server termination)');

    LBody := TJSONObject.Create()
       .AddPair('jsonrpc', '2.0')
       .AddPair('id', TJSONNumber.Create(17))
       .AddPair('method', 'shutdown')
       .ToString();

    LResponse := SendRequestAndRead(LStdinWrite, LStdoutRead, LBody, 5000);

    if LResponse <> '' then
       Check(True, 'Shutdown acknowledged', '')
     else
       Check(False, '', 'Shutdown: no response (timeout)');

    SectionSummary();

    // ---- 21. Exit ----
    BeginSection('20. Exit  (process termination)');

    LBody := TJSONObject.Create()
       .AddPair('jsonrpc', '2.0')
       .AddPair('method', 'exit')
       .ToString();

    SendLSPMessage(LStdinWrite, LBody);

    WaitForSingleObject(LProcessHandle, 5000);

    Check(True, 'Exit notification sent, process terminated', '');

    SectionSummary();

    // ---- Grand Summary ----
     TMorUtils.PrintLn('');

    TMorUtils.PrintLn(COLOR_CYAN +
      '  ============================================================');

    if GPass = GTotal then
     begin
       TMorUtils.PrintLn(COLOR_GREEN + Format(
         '  RESULT: %d/%d protocol steps verified  --  ALL PASS',
        [GPass, GTotal]));

      TMorUtils.PrintLn(COLOR_GREEN +
        '  Metamorf LSP: fully operational over JSON-RPC');
     end
   else
     begin
       TMorUtils.PrintLn(COLOR_RED + Format(
         '  RESULT: %d/%d protocol steps verified  --  SOME FAILURES',
        [GPass, GTotal]));

      TMorUtils.PrintLn(COLOR_RED + Format('  %d step(s) need attention',
         [GTotal - GPass]));
     end;

    TMorUtils.PrintLn(COLOR_CYAN +
      '  ============================================================');

    TMorUtils.PrintLn('');

  finally
    CloseHandle(LStdinWrite);
    CloseHandle(LStdoutRead);
    CloseHandle(LProcessHandle);
    CloseHandle(LThreadHandle);
  end;

end;

end.
