{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug.REPL;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.Debug.Server,
  Metamorf.Debug.Client;

const
  CDefaultDAPPort = 4711;
  CTimeoutContinueMS = 5000;
  CTimeoutStepMS = 2000;

type
  //============================================================================
  // TREPLBreakpoint - Local breakpoint tracking record
  //============================================================================
  TREPLBreakpoint = record
    SourceFile: string;
    SourceLine: Integer;
    Verified: Boolean;
  end;

  //============================================================================
  // TMetamorfDebugREPL - Interactive console debugger for Metamorf programs.
  // Drives TMetamorfDebugServer + TMetamorfDebugClient over DAP/TCP.
  //============================================================================

  { TMetamorfDebugREPL }
  TMetamorfDebugREPL = class(TBaseObject)
  private
    FServer: TMetamorfDebugServer;
    FClient: TMetamorfDebugClient;
    FServerThread: TThread;
    FBreakpoints: TList<TREPLBreakpoint>;
    FRunning: Boolean;
    FExePath: string;
    FPort: Integer;
    FPrompt: string;
    FTimeoutContinueMS: Integer;
    FTimeoutStepMS: Integer;

    // Command handlers
    procedure ProcessCommand(const ACommand: string);
    procedure ShowHelp();
    procedure HandleSetBreakpoint(const ACommand: string);
    procedure HandleListBreakpoints();
    procedure HandleDeleteBreakpoint(const ACommand: string);
    procedure HandleClearBreakpoints();
    procedure HandleBacktrace();
    procedure HandleLocals();
    procedure HandlePrint(const ACommand: string);
    procedure HandleContinue();
    procedure HandleNext();
    procedure HandleStepInto();
    procedure HandleStepOut();
    procedure HandleRestart();
    procedure HandleFile(const ACommand: string);
    procedure HandleVerbose(const ACommand: string);
    procedure HandleThreads();

    // Internal
    procedure StartSession();
    procedure StopSession();
    function DoDAHandshake(): Boolean;
    procedure ShowSourceContext();
    procedure SendBreakpointsForFile(const ASourceFile: string);
    procedure LoadBreakpointsFromFile(const APath: string);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Run(const AExePath: string; const APort: Integer = CDefaultDAPPort);
    procedure Stop();

    property TimeoutContinueMS: Integer read FTimeoutContinueMS write FTimeoutContinueMS;
    property TimeoutStepMS: Integer read FTimeoutStepMS write FTimeoutStepMS;
  end;

implementation

uses
  Metamorf.Config;


//==============================================================================
// TMetamorfDebugREPL
//==============================================================================

constructor TMetamorfDebugREPL.Create();
begin
  inherited Create();
  FServer := nil;
  FClient := nil;
  FServerThread := nil;
  FBreakpoints := TList<TREPLBreakpoint>.Create();
  FRunning := False;
  FExePath := '';
  FPort := CDefaultDAPPort;
  FPrompt := '(mor-dbg) ';
  FTimeoutContinueMS := CTimeoutContinueMS;
  FTimeoutStepMS := CTimeoutStepMS;
end;

destructor TMetamorfDebugREPL.Destroy();
begin
  StopSession();
  FBreakpoints.Free();
  inherited Destroy();
end;

procedure TMetamorfDebugREPL.StopSession();
begin
  if Assigned(FClient) then
  begin
    try
      FClient.DisconnectDAP();
    except
      // Ignore errors during shutdown
    end;
    FClient.Disconnect();
    FreeAndNil(FClient);
  end;

  if Assigned(FServer) then
  begin
    FServer.StopDebugging();
    FreeAndNil(FServer);
  end;

  if Assigned(FServerThread) then
  begin
    FServerThread.WaitFor();
    FreeAndNil(FServerThread);
  end;
end;

procedure TMetamorfDebugREPL.StartSession();
var
  LExePath: string;
  LPort: Integer;
begin
  LExePath := FExePath;
  LPort := FPort;

  FServer := TMetamorfDebugServer.Create();

  // Start server on background thread (DebugExe blocks on WaitForConnection)
  FServerThread := TThread.CreateAnonymousThread(
    procedure
    begin
      FServer.DebugExe(LExePath, LPort);
    end
  );
  FServerThread.FreeOnTerminate := False;
  FServerThread.Start();

  // Give server time to start listening
  Sleep(500);

  FClient := TMetamorfDebugClient.Create();
end;

function TMetamorfDebugREPL.DoDAHandshake(): Boolean;
begin
  Result := False;

  if not FClient.Connect('127.0.0.1', FPort) then
  begin
    TUtils.PrintLn(COLOR_RED + 'Connect failed: ' + FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;
  TUtils.PrintLn('Connected to debug server on port %d', [FPort]);

  if not FClient.Initialize() then
  begin
    TUtils.PrintLn(COLOR_RED + 'Initialize failed: ' + FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;

  if not FClient.Launch(FExePath, False) then
  begin
    TUtils.PrintLn(COLOR_RED + 'Launch failed: ' + FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;

  TUtils.PrintLn(COLOR_GREEN + 'DAP handshake complete' + COLOR_RESET);
  Result := True;
end;

procedure TMetamorfDebugREPL.ShowSourceContext();
var
  LFrames: TArray<TDAPClientStackFrame>;
  LSourceFile: string;
  LSourceLine: Integer;
  LLines: TStringList;
  LStart: Integer;
  LEnd: Integer;
  LI: Integer;
  LArrow: string;
begin
  LFrames := FClient.GetCallStack();
  if Length(LFrames) = 0 then
    Exit;

  LSourceFile := LFrames[0].SourceFile;
  LSourceLine := LFrames[0].SourceLine;

  if (LSourceFile = '') or (LSourceLine <= 0) then
    Exit;

  // Try to read the source file from disk
  if not TFile.Exists(LSourceFile) then
  begin
    TUtils.PrintLn('  Stopped at %s:%d (%s)',
      [ExtractFileName(LSourceFile), LSourceLine, LFrames[0].FunctionName]);
    Exit;
  end;

  LLines := TStringList.Create();
  try
    LLines.LoadFromFile(LSourceFile);

    LStart := LSourceLine - 3;
    if LStart < 0 then
      LStart := 0;
    LEnd := LSourceLine + 1;
    if LEnd >= LLines.Count then
      LEnd := LLines.Count - 1;

    TUtils.PrintLn('');
    for LI := LStart to LEnd do
    begin
      // Lines in TStringList are 0-based; source lines are 1-based
      if (LI + 1) = LSourceLine then
        LArrow := COLOR_YELLOW + '>>'
      else
        LArrow := '  ';
      TUtils.PrintLn('%s%4d: %s%s', [LArrow, LI + 1, LLines[LI], COLOR_RESET]);
    end;
    TUtils.PrintLn('');
  finally
    LLines.Free();
  end;
end;

procedure TMetamorfDebugREPL.SendBreakpointsForFile(const ASourceFile: string);
var
  LLines: TList<Integer>;
  LI: Integer;
  LBP: TREPLBreakpoint;
begin
  // Collect all lines for this file
  LLines := TList<Integer>.Create();
  try
    for LI := 0 to FBreakpoints.Count - 1 do
    begin
      LBP := FBreakpoints[LI];
      if SameText(LBP.SourceFile, ASourceFile) then
        LLines.Add(LBP.SourceLine);
    end;

    // Send to server (empty array clears breakpoints for that file)
    FClient.SetBreakpoints(ASourceFile, LLines.ToArray());
  finally
    LLines.Free();
  end;
end;

procedure TMetamorfDebugREPL.LoadBreakpointsFromFile(const APath: string);
var
  LConfig: TConfig;
  LCount: Integer;
  LI: Integer;
  LFile: string;
  LLine: Integer;
  LExeDir: string;
  LExpandedFile: string;
  LBP: TREPLBreakpoint;
begin
  if not TFile.Exists(APath) then
  begin
    TUtils.PrintLn(COLOR_RED + 'Breakpoint file not found: ' + APath + COLOR_RESET);
    Exit;
  end;

  // Get executable directory for expanding relative paths
  LExeDir := TPath.GetDirectoryName(FExePath);

  LConfig := TConfig.Create();
  try
    if not LConfig.LoadFromFile(APath) then
    begin
      TUtils.PrintLn(COLOR_RED + 'Failed to parse breakpoints file: ' +
        LConfig.GetLastError() + COLOR_RESET);
      Exit;
    end;

    LCount := LConfig.GetTableCount('breakpoints');
    if LCount = 0 then
      Exit;

    for LI := 0 to LCount - 1 do
    begin
      LFile := LConfig.GetTableString('breakpoints', LI, 'file');
      LLine := LConfig.GetTableInteger('breakpoints', LI, 'line');

      // Expand relative paths to absolute paths
      if not TPath.IsPathRooted(LFile) then
        LExpandedFile := TPath.GetFullPath(TPath.Combine(LExeDir, LFile))
      else
        LExpandedFile := LFile;

      LBP.SourceFile := LExpandedFile;
      LBP.SourceLine := LLine;
      LBP.Verified := False;

      if (LBP.SourceFile <> '') and (LBP.SourceLine > 0) then
        FBreakpoints.Add(LBP);
    end;

    TUtils.PrintLn('Loaded %d breakpoint(s) from %s',
      [FBreakpoints.Count, ExtractFileName(APath)]);
  finally
    LConfig.Free();
  end;
end;

procedure TMetamorfDebugREPL.Run(const AExePath: string; const APort: Integer);
var
  LCommand: string;
  LBreakpointFile: string;
  LFiles: TDictionary<string, Boolean>;
  LBP: TREPLBreakpoint;
  LKey: string;
begin
  FExePath := AExePath;
  FPort := APort;

  if not TFile.Exists(FExePath) then
  begin
    TUtils.PrintLn(COLOR_RED + 'Executable not found: ' + FExePath + COLOR_RESET);
    Exit;
  end;

  TUtils.PrintLn('');
  TUtils.PrintLn(COLOR_CYAN + '=== Metamorf Debug REPL ===' + COLOR_RESET);
  TUtils.PrintLn('Executable: %s', [FExePath]);
  TUtils.PrintLn('');

  // Start server + client
  StartSession();

  // DAP handshake
  if not DoDAHandshake() then
  begin
    StopSession();
    Exit;
  end;

  // Set up callbacks
  FClient.OnStopped :=
    procedure(const AReason: string; const AThreadId: Integer)
    begin
      TUtils.PrintLn('  [stopped] %s (thread %d)', [AReason, AThreadId]);
    end;
  FClient.OnExited :=
    procedure(const AExitCode: Integer)
    begin
      TUtils.PrintLn('  [exited] code %d', [AExitCode]);
    end;
  FClient.OnOutput :=
    procedure(const AOutput: string)
    begin
      TUtils.Print(AOutput);
    end;

  // Load breakpoints from sidecar file if it exists
  LBreakpointFile := TPath.ChangeExtension(FExePath, MOR_BREAKPOINT_EXT);
  if TFile.Exists(LBreakpointFile) then
    LoadBreakpointsFromFile(LBreakpointFile);

  // Send all breakpoints to server (grouped by file)
  if FBreakpoints.Count > 0 then
  begin
    LFiles := TDictionary<string, Boolean>.Create();
    try
      for LBP in FBreakpoints do
        LFiles.AddOrSetValue(LBP.SourceFile, True);
      for LKey in LFiles.Keys do
        SendBreakpointsForFile(LKey);
    finally
      LFiles.Free();
    end;
  end;

  // Start execution
  if not FClient.ConfigurationDone() then
  begin
    TUtils.PrintLn(COLOR_RED + 'ConfigurationDone failed: ' +
      FClient.GetLastError() + COLOR_RESET);
    StopSession();
    Exit;
  end;

  TUtils.PrintLn(COLOR_GREEN + 'Running...' + COLOR_RESET);

  // Wait for first stop (breakpoint or exit)
  FClient.ProcessPendingEvents(FTimeoutContinueMS);

  if FClient.State = dcsStopped then
  begin
    ShowSourceContext();
    TUtils.PrintLn(COLOR_CYAN + '=== INTERACTIVE REPL ===' + COLOR_RESET);
    ShowHelp();
    TUtils.PrintLn('');
  end
  else if FClient.State = dcsExited then
  begin
    TUtils.PrintLn(COLOR_YELLOW + 'Program exited without stopping.' + COLOR_RESET);
    StopSession();
    Exit;
  end;

  // Main REPL loop
  FRunning := True;
  while FRunning do
  begin
    Write(FPrompt);
    ReadLn(LCommand);
    LCommand := Trim(LCommand);
    ProcessCommand(LCommand);
  end;

  TUtils.PrintLn('');
  TUtils.PrintLn(COLOR_GREEN + 'REPL session complete.' + COLOR_RESET);
  StopSession();
end;

procedure TMetamorfDebugREPL.Stop();
begin
  FRunning := False;
end;

//------------------------------------------------------------------------------
// ProcessCommand - dispatch user input to handlers
//------------------------------------------------------------------------------

procedure TMetamorfDebugREPL.ProcessCommand(const ACommand: string);
begin
  if ACommand = '' then
    Exit;

  if ACommand = 'quit' then
    FRunning := False
  else if (ACommand = 'h') or (ACommand = 'help') then
    ShowHelp()
  else if ACommand.StartsWith('b ') then
    HandleSetBreakpoint(ACommand)
  else if ACommand = 'bl' then
    HandleListBreakpoints()
  else if ACommand.StartsWith('bd ') then
    HandleDeleteBreakpoint(ACommand)
  else if ACommand = 'bc' then
    HandleClearBreakpoints()
  else if ACommand = 'bt' then
    HandleBacktrace()
  else if ACommand = 'locals' then
    HandleLocals()
  else if ACommand.StartsWith('p ') then
    HandlePrint(ACommand)
  else if ACommand = 'c' then
    HandleContinue()
  else if ACommand = 'n' then
    HandleNext()
  else if ACommand = 's' then
    HandleStepInto()
  else if ACommand = 'finish' then
    HandleStepOut()
  else if ACommand = 'r' then
    HandleRestart()
  else if ACommand.StartsWith('file ') then
    HandleFile(ACommand)
  else if ACommand.StartsWith('verbose ') then
    HandleVerbose(ACommand)
  else if ACommand = 'threads' then
    HandleThreads()
  else if ACommand = 'src' then
    ShowSourceContext()
  else
    TUtils.PrintLn(COLOR_RED + 'Unknown command: ' + ACommand + COLOR_RESET);
end;

//------------------------------------------------------------------------------
// ShowHelp
//------------------------------------------------------------------------------

procedure TMetamorfDebugREPL.ShowHelp();
begin
  TUtils.PrintLn('Commands:');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'h, help' + COLOR_RESET + '         - Show this help');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'b <file>:<line>' + COLOR_RESET + ' - Set breakpoint');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'bl' + COLOR_RESET + '              - List breakpoints');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'bd <id>' + COLOR_RESET + '         - Delete breakpoint by ID');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'bc' + COLOR_RESET + '              - Clear all breakpoints');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'bt' + COLOR_RESET + '              - Show call stack (backtrace)');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'locals' + COLOR_RESET + '          - Show local variables');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'p <expr>' + COLOR_RESET + '        - Print/evaluate expression');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'c' + COLOR_RESET + '               - Continue execution');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'n' + COLOR_RESET + '               - Next (step over)');
  TUtils.PrintLn('  ' + COLOR_CYAN + 's' + COLOR_RESET + '               - Step into');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'finish' + COLOR_RESET + '          - Step out');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'r' + COLOR_RESET + '               - Restart program');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'file <path>' + COLOR_RESET + '     - Load different executable');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'src' + COLOR_RESET + '             - Show source context');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'threads' + COLOR_RESET + '         - Show threads');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'verbose on/off' + COLOR_RESET + '  - Toggle DAP message logging');
  TUtils.PrintLn('  ' + COLOR_CYAN + 'quit' + COLOR_RESET + '            - Exit REPL');
end;

//------------------------------------------------------------------------------
// Breakpoint handlers
//------------------------------------------------------------------------------

procedure TMetamorfDebugREPL.HandleSetBreakpoint(const ACommand: string);
var
  LColonPos: Integer;
  LFile: string;
  LLine: Integer;
  LBP: TREPLBreakpoint;
begin
  // Format: b <file>:<line>
  LColonPos := Pos(':', ACommand);
  if LColonPos > 3 then
  begin
    LFile := Trim(Copy(ACommand, 3, LColonPos - 3));
    LLine := StrToIntDef(Trim(Copy(ACommand, LColonPos + 1, MaxInt)), -1);

    if (LFile <> '') and (LLine > 0) then
    begin
      LBP.SourceFile := LFile;
      LBP.SourceLine := LLine;
      LBP.Verified := False;
      FBreakpoints.Add(LBP);
      SendBreakpointsForFile(LFile);
      TUtils.PrintLn(COLOR_GREEN + 'Breakpoint set at %s:%d' + COLOR_RESET,
        [LFile, LLine]);
    end
    else
      TUtils.PrintLn(COLOR_RED + 'Invalid format. Use: b <file>:<line>' + COLOR_RESET);
  end
  else
    TUtils.PrintLn(COLOR_RED + 'Invalid format. Use: b <file>:<line>' + COLOR_RESET);
end;

procedure TMetamorfDebugREPL.HandleListBreakpoints();
var
  LI: Integer;
  LBP: TREPLBreakpoint;
begin
  if FBreakpoints.Count = 0 then
  begin
    TUtils.PrintLn('No breakpoints set');
    Exit;
  end;

  TUtils.PrintLn('Breakpoints (%d):', [FBreakpoints.Count]);
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    LBP := FBreakpoints[LI];
    TUtils.PrintLn('  #%d: %s:%d', [LI + 1, LBP.SourceFile, LBP.SourceLine]);
  end;
end;

procedure TMetamorfDebugREPL.HandleDeleteBreakpoint(const ACommand: string);
var
  LIndex: Integer;
  LBP: TREPLBreakpoint;
  LFile: string;
begin
  // Format: bd <id> (1-based)
  LIndex := StrToIntDef(Trim(Copy(ACommand, 4, MaxInt)), -1);
  if (LIndex < 1) or (LIndex > FBreakpoints.Count) then
  begin
    TUtils.PrintLn(COLOR_RED + 'Invalid breakpoint ID' + COLOR_RESET);
    Exit;
  end;

  LBP := FBreakpoints[LIndex - 1];
  LFile := LBP.SourceFile;
  FBreakpoints.Delete(LIndex - 1);

  // Re-send remaining breakpoints for that file
  SendBreakpointsForFile(LFile);
  TUtils.PrintLn(COLOR_GREEN + 'Breakpoint #%d deleted' + COLOR_RESET, [LIndex]);
end;

procedure TMetamorfDebugREPL.HandleClearBreakpoints();
var
  LFiles: TDictionary<string, Boolean>;
  LBP: TREPLBreakpoint;
  LKey: string;
begin
  // Collect unique files before clearing
  LFiles := TDictionary<string, Boolean>.Create();
  try
    for LBP in FBreakpoints do
      LFiles.AddOrSetValue(LBP.SourceFile, True);

    FBreakpoints.Clear();

    // Send empty breakpoint sets for each file
    for LKey in LFiles.Keys do
      FClient.SetBreakpoints(LKey, []);
  finally
    LFiles.Free();
  end;

  TUtils.PrintLn(COLOR_GREEN + 'All breakpoints cleared' + COLOR_RESET);
end;

//------------------------------------------------------------------------------
// Inspection handlers
//------------------------------------------------------------------------------

procedure TMetamorfDebugREPL.HandleBacktrace();
var
  LFrames: TArray<TDAPClientStackFrame>;
  LI: Integer;
begin
  if FClient.State <> dcsStopped then
  begin
    TUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  LFrames := FClient.GetCallStack();
  if Length(LFrames) = 0 then
  begin
    TUtils.PrintLn('No stack frames');
    Exit;
  end;

  TUtils.PrintLn('Call stack (%d frames):', [Length(LFrames)]);
  for LI := 0 to High(LFrames) do
    TUtils.PrintLn('  #%d: %s at %s:%d',
      [LI, LFrames[LI].FunctionName, LFrames[LI].SourceFile, LFrames[LI].SourceLine]);
end;

procedure TMetamorfDebugREPL.HandleLocals();
var
  LFrames: TArray<TDAPClientStackFrame>;
  LScopes: TArray<TDAPClientScope>;
  LVars: TArray<TDAPClientVariable>;
  LI: Integer;
  LJ: Integer;
begin
  if FClient.State <> dcsStopped then
  begin
    TUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  LFrames := FClient.GetCallStack();
  if Length(LFrames) = 0 then
  begin
    TUtils.PrintLn(COLOR_RED + 'No stack frames' + COLOR_RESET);
    Exit;
  end;

  // Get scopes for top frame
  LScopes := FClient.GetScopes(LFrames[0].FrameID);
  if Length(LScopes) = 0 then
  begin
    TUtils.PrintLn('No scopes available');
    Exit;
  end;

  // Get variables for each scope
  for LI := 0 to High(LScopes) do
  begin
    TUtils.PrintLn('%s:', [LScopes[LI].ScopeName]);
    LVars := FClient.GetVariables(LScopes[LI].VariablesReference);
    if Length(LVars) = 0 then
      TUtils.PrintLn('  (none)')
    else
    begin
      for LJ := 0 to High(LVars) do
      begin
        if LVars[LJ].VarType <> '' then
          TUtils.PrintLn('  %s (%s) = %s',
            [LVars[LJ].VarName, LVars[LJ].VarType, LVars[LJ].VarValue])
        else
          TUtils.PrintLn('  %s = %s',
            [LVars[LJ].VarName, LVars[LJ].VarValue]);
      end;
    end;
  end;
end;

procedure TMetamorfDebugREPL.HandlePrint(const ACommand: string);
var
  LExpr: string;
  LResult: string;
begin
  // Extract expression after 'p '
  LExpr := Trim(Copy(ACommand, 3, MaxInt));
  if LExpr = '' then
  begin
    TUtils.PrintLn(COLOR_YELLOW + 'Usage: p <variable>' + COLOR_RESET);
    Exit;
  end;

  if FClient.State <> dcsStopped then
  begin
    TUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  LResult := FClient.Evaluate(LExpr);
  if LResult <> '' then
    TUtils.PrintLn('%s = %s', [LExpr, LResult])
  else
  begin
    if FClient.HasError() then
      TUtils.PrintLn(COLOR_RED + '%s' + COLOR_RESET, [FClient.GetLastError()])
    else
      TUtils.PrintLn(COLOR_YELLOW + 'Variable ''%s'' not found' + COLOR_RESET, [LExpr]);
  end;
end;

//------------------------------------------------------------------------------
// Execution control handlers
//------------------------------------------------------------------------------

procedure TMetamorfDebugREPL.HandleContinue();
begin
  if FClient.State <> dcsStopped then
  begin
    TUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TUtils.PrintLn('Continuing...');
  if FClient.DoContinue() then
  begin
    FClient.ProcessPendingEvents(FTimeoutContinueMS);
    if FClient.State = dcsStopped then
    begin
      TUtils.PrintLn(COLOR_GREEN + 'Stopped' + COLOR_RESET);
      ShowSourceContext();
    end
    else if FClient.State = dcsExited then
      TUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TUtils.PrintLn(COLOR_RED + 'Continue failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

procedure TMetamorfDebugREPL.HandleNext();
begin
  if FClient.State <> dcsStopped then
  begin
    TUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TUtils.PrintLn('Stepping over...');
  if FClient.StepOver() then
  begin
    FClient.ProcessPendingEvents(FTimeoutStepMS);
    if FClient.State = dcsStopped then
      ShowSourceContext()
    else if FClient.State = dcsExited then
      TUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TUtils.PrintLn(COLOR_RED + 'Step failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

procedure TMetamorfDebugREPL.HandleStepInto();
begin
  if FClient.State <> dcsStopped then
  begin
    TUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TUtils.PrintLn('Stepping into...');
  if FClient.StepIn() then
  begin
    FClient.ProcessPendingEvents(FTimeoutStepMS);
    if FClient.State = dcsStopped then
      ShowSourceContext()
    else if FClient.State = dcsExited then
      TUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TUtils.PrintLn(COLOR_RED + 'Step failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

procedure TMetamorfDebugREPL.HandleStepOut();
begin
  if FClient.State <> dcsStopped then
  begin
    TUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TUtils.PrintLn('Stepping out...');
  if FClient.StepOut() then
  begin
    FClient.ProcessPendingEvents(FTimeoutStepMS);
    if FClient.State = dcsStopped then
      ShowSourceContext()
    else if FClient.State = dcsExited then
      TUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TUtils.PrintLn(COLOR_RED + 'Step failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

//------------------------------------------------------------------------------
// Restart, File, Verbose, Threads
//------------------------------------------------------------------------------

procedure TMetamorfDebugREPL.HandleRestart();
var
  LSavedBreakpoints: TList<TREPLBreakpoint>;
  LBP: TREPLBreakpoint;
  LFiles: TDictionary<string, Boolean>;
  LKey: string;
begin
  TUtils.PrintLn('Restarting program...');

  // Save breakpoints before teardown
  LSavedBreakpoints := TList<TREPLBreakpoint>.Create();
  try
    for LBP in FBreakpoints do
      LSavedBreakpoints.Add(LBP);

    // Full teardown
    StopSession();

    // Restore breakpoints
    FBreakpoints.Clear();
    for LBP in LSavedBreakpoints do
      FBreakpoints.Add(LBP);
  finally
    LSavedBreakpoints.Free();
  end;

  // Re-create server + client
  StartSession();

  // Re-do DAP handshake
  if not DoDAHandshake() then
  begin
    TUtils.PrintLn(COLOR_RED + 'Restart failed during handshake' + COLOR_RESET);
    StopSession();
    Exit;
  end;

  // Re-set callbacks
  FClient.OnStopped :=
    procedure(const AReason: string; const AThreadId: Integer)
    begin
      TUtils.PrintLn('  [stopped] %s (thread %d)', [AReason, AThreadId]);
    end;
  FClient.OnExited :=
    procedure(const AExitCode: Integer)
    begin
      TUtils.PrintLn('  [exited] code %d', [AExitCode]);
    end;
  FClient.OnOutput :=
    procedure(const AOutput: string)
    begin
      TUtils.Print(AOutput);
    end;

  // Re-send all breakpoints (grouped by file)
  if FBreakpoints.Count > 0 then
  begin
    LFiles := TDictionary<string, Boolean>.Create();
    try
      for LBP in FBreakpoints do
        LFiles.AddOrSetValue(LBP.SourceFile, True);
      for LKey in LFiles.Keys do
        SendBreakpointsForFile(LKey);
    finally
      LFiles.Free();
    end;
    TUtils.PrintLn('Restored %d breakpoint(s)', [FBreakpoints.Count]);
  end;

  // Start execution
  if not FClient.ConfigurationDone() then
  begin
    TUtils.PrintLn(COLOR_RED + 'ConfigurationDone failed: ' +
      FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;

  TUtils.PrintLn(COLOR_GREEN + 'Program restarted!' + COLOR_RESET);

  // Wait for first stop
  FClient.ProcessPendingEvents(FTimeoutContinueMS);

  if FClient.State = dcsStopped then
    ShowSourceContext()
  else if FClient.State = dcsExited then
    TUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
end;

procedure TMetamorfDebugREPL.HandleFile(const ACommand: string);
var
  LPath: string;
begin
  LPath := Trim(Copy(ACommand, 6, MaxInt));

  if not TFile.Exists(LPath) then
  begin
    TUtils.PrintLn(COLOR_RED + 'File not found: ' + LPath + COLOR_RESET);
    Exit;
  end;

  FExePath := LPath;
  FBreakpoints.Clear();
  TUtils.PrintLn(COLOR_GREEN + 'Loaded: ' + FExePath + COLOR_RESET);
  TUtils.PrintLn('Breakpoints cleared. Use ''r'' to run.');
end;

procedure TMetamorfDebugREPL.HandleVerbose(const ACommand: string);
begin
  if ACommand = 'verbose on' then
  begin
    FClient.VerboseLogging := True;
    TUtils.PrintLn(COLOR_GREEN + 'Verbose logging enabled' + COLOR_RESET);
  end
  else if ACommand = 'verbose off' then
  begin
    FClient.VerboseLogging := False;
    TUtils.PrintLn(COLOR_GREEN + 'Verbose logging disabled' + COLOR_RESET);
  end
  else
    TUtils.PrintLn(COLOR_RED + 'Usage: verbose on|off' + COLOR_RESET);
end;

procedure TMetamorfDebugREPL.HandleThreads();
begin
  // Single-threaded - hardcode response
  TUtils.PrintLn('Threads (1):');
  TUtils.PrintLn('  Thread 1: main');
end;

end.
