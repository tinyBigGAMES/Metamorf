{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug.DAP;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  WinApi.WinSock,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Debug.PDB,
  Metamorf.Debug.Target,
  Metamorf.Debug.Runtime;

type
  //============================================================================
  // TDAPState - DAP session lifecycle states
  //============================================================================
  TDAPState = (
    dsIdle,              // Server created, not yet listening
    dsListening,         // TCP socket listening, awaiting connection
    dsConnected,         // Client connected, awaiting initialize
    dsInitialized,       // Initialize handshake complete
    dsConfiguring,       // SetBreakpoints etc. before configurationDone
    dsRunning,           // Debuggee is running
    dsStopped,           // Debuggee is stopped at breakpoint/step
    dsTerminated         // Debug session ended
  );

  //============================================================================
  // TDAPServer - Debug Adapter Protocol server over TCP/JSON.
  // Speaks the standard DAP protocol that VS Code and other editors use.
  //============================================================================

  { TDAPServer }
  TDAPServer = class(TErrorsObject)
  private
    FRuntime: TDebugRuntime;        // Reference (not owned)
    FSourceMap: TPDBSourceMap;      // Reference (not owned)
    FPort: Integer;
    FState: TDAPState;
    FSeq: Integer;                  // Outgoing message sequence counter

    // WinSock
    FListenSocket: TSocket;
    FClientSocket: TSocket;
    FWSAData: TWSAData;
    FWSAInitialized: Boolean;

    // Source root for path mapping
    FSourceRoot: string;

    // Launch configuration fields
    FProgram: string;
    FStopOnEntry: Boolean;

    // Message I/O
    function ReadMessage(): TJSONObject;
    procedure SendMessage(const AMsg: TJSONObject);
    procedure SendResponse(const ARequestSeq: Integer;
      const ACommand: string; const ASuccess: Boolean;
      const ABody: TJSONObject = nil; const AMessage: string = '');
    procedure SendEvent(const AEventName: string;
      const ABody: TJSONObject = nil);

    // DAP command handlers
    procedure HandleInitialize(const ASeq: Integer; const AArgs: TJSONObject);
    procedure HandleLaunch(const ASeq: Integer; const AArgs: TJSONObject);
    procedure HandleSetBreakpoints(const ASeq: Integer; const AArgs: TJSONObject);
    procedure HandleConfigurationDone(const ASeq: Integer);
    procedure HandleThreads(const ASeq: Integer);
    procedure HandleStackTrace(const ASeq: Integer; const AArgs: TJSONObject);
    procedure HandleScopes(const ASeq: Integer; const AArgs: TJSONObject);
    procedure HandleVariables(const ASeq: Integer; const AArgs: TJSONObject);
    procedure HandleContinue(const ASeq: Integer);
    procedure HandleNext(const ASeq: Integer);
    procedure HandleStepIn(const ASeq: Integer);
    procedure HandleStepOut(const ASeq: Integer);
    procedure HandlePause(const ASeq: Integer);
    procedure HandleDisconnect(const ASeq: Integer);
    procedure HandleEvaluate(const ASeq: Integer; const AArgs: TJSONObject);
    procedure HandleSetExceptionBreakpoints(const ASeq: Integer;
      const AArgs: TJSONObject);

    // Internal
    procedure DispatchRequest(const AMsg: TJSONObject);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetRuntime(const ARuntime: TDebugRuntime);
    procedure SetSourceMap(const ASourceMap: TPDBSourceMap);

    // Lifecycle
    function StartListening(const APort: Integer): Boolean;
    function WaitForConnection(): Boolean;
    procedure RunMessageLoop();
    procedure StopServer();
    procedure ProcessStopEvent();

    // Properties
    function GetPort(): Integer;
    function GetState(): TDAPState;
  end;

implementation

//==============================================================================
// TDAPServer -- Constructor / Destructor
//==============================================================================

constructor TDAPServer.Create();
begin
  inherited Create();
  FRuntime := nil;
  FSourceMap := nil;
  FPort := 0;
  FState := dsIdle;
  FSeq := 1;
  FListenSocket := INVALID_SOCKET;
  FClientSocket := INVALID_SOCKET;
  FWSAInitialized := False;
  FSourceRoot := '';
  FProgram := '';
  FStopOnEntry := False;
end;

destructor TDAPServer.Destroy();
begin
  StopServer();
  inherited Destroy();
end;

procedure TDAPServer.SetRuntime(const ARuntime: TDebugRuntime);
begin
  FRuntime := ARuntime;
end;

procedure TDAPServer.SetSourceMap(const ASourceMap: TPDBSourceMap);
begin
  FSourceMap := ASourceMap;
end;

function TDAPServer.GetPort(): Integer;
begin
  Result := FPort;
end;

function TDAPServer.GetState(): TDAPState;
begin
  Result := FState;
end;

//==============================================================================
// TDAPServer -- TCP Lifecycle
//==============================================================================

function TDAPServer.StartListening(const APort: Integer): Boolean;
var
  LAddr: TSockAddrIn;
  LOptVal: Integer;
begin
  Result := False;
  FPort := APort;

  // Initialize WinSock
  if WSAStartup($0202, FWSAData) <> 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DAP001', 'WSAStartup failed');
    Exit;
  end;
  FWSAInitialized := True;

  // Create TCP socket
  FListenSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if FListenSocket = INVALID_SOCKET then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DAP002', 'Failed to create socket');
    Exit;
  end;

  // Allow port reuse
  LOptVal := 1;
  setsockopt(FListenSocket, SOL_SOCKET, SO_REUSEADDR,
    PAnsiChar(@LOptVal), SizeOf(LOptVal));

  // Bind to localhost
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_addr.S_addr := inet_addr('127.0.0.1');
  LAddr.sin_port := htons(Word(APort));

  if bind(FListenSocket, TSockAddr(LAddr), SizeOf(LAddr)) = SOCKET_ERROR then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DAP003', 'Failed to bind to port %d', [APort]);
    Exit;
  end;

  // Listen (backlog of 1 -- only one client at a time)
  if listen(FListenSocket, 1) = SOCKET_ERROR then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DAP004', 'Failed to listen on port %d', [APort]);
    Exit;
  end;

  FState := dsListening;
  Result := True;
end;

function TDAPServer.WaitForConnection(): Boolean;
begin
  Result := False;
  if FState <> dsListening then
    Exit;

  // Blocking accept -- waits until VS Code connects
  FClientSocket := accept(FListenSocket, nil, nil);
  if FClientSocket = INVALID_SOCKET then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DAP005', 'Accept failed');
    Exit;
  end;

  FState := dsConnected;
  Result := True;
end;

procedure TDAPServer.StopServer();
begin
  if FClientSocket <> INVALID_SOCKET then
  begin
    closesocket(FClientSocket);
    FClientSocket := INVALID_SOCKET;
  end;
  if FListenSocket <> INVALID_SOCKET then
  begin
    closesocket(FListenSocket);
    FListenSocket := INVALID_SOCKET;
  end;
  if FWSAInitialized then
  begin
    WSACleanup();
    FWSAInitialized := False;
  end;
  FState := dsIdle;
end;

//==============================================================================
// TDAPServer -- Message I/O (Content-Length framing)
//==============================================================================

function TDAPServer.ReadMessage(): TJSONObject;
var
  LBuf: AnsiChar;
  LHeader: AnsiString;
  LContentLength: Integer;
  LBody: TBytes;
  LBodyStr: string;
  LRead: Integer;
  LTotal: Integer;
  LRecv: Integer;
begin
  Result := nil;
  LContentLength := 0;

  // Read headers line by line until empty line (\r\n\r\n)
  LHeader := '';
  while True do
  begin
    LRecv := recv(FClientSocket, LBuf, 1, 0);
    if LRecv <= 0 then
      Exit;  // Connection closed or error

    LHeader := LHeader + LBuf;

    // Check for end of headers
    if (Length(LHeader) >= 4) and
       (LHeader[Length(LHeader) - 3] = #13) and
       (LHeader[Length(LHeader) - 2] = #10) and
       (LHeader[Length(LHeader) - 1] = #13) and
       (LHeader[Length(LHeader)] = #10) then
      Break;
  end;

  // Parse Content-Length from headers
  LRead := Pos('Content-Length:', string(LHeader));
  if LRead > 0 then
  begin
    LBodyStr := Trim(Copy(string(LHeader), LRead + 15,
      Pos(#13, string(LHeader), LRead + 15) - LRead - 15));
    LContentLength := StrToIntDef(LBodyStr, 0);
  end;

  if LContentLength <= 0 then
    Exit;

  // Read exactly LContentLength bytes of body
  SetLength(LBody, LContentLength);
  LTotal := 0;
  while LTotal < LContentLength do
  begin
    LRecv := recv(FClientSocket, LBody[LTotal],
      LContentLength - LTotal, 0);
    if LRecv <= 0 then
      Exit;
    Inc(LTotal, LRecv);
  end;

  // Parse JSON
  LBodyStr := TEncoding.UTF8.GetString(LBody);
  try
    Result := TJSONObject.ParseJSONValue(LBodyStr) as TJSONObject;
  except
    Result := nil;
  end;
end;

procedure TDAPServer.SendMessage(const AMsg: TJSONObject);
var
  LBody: TBytes;
  LHeader: AnsiString;
begin
  LBody := TEncoding.UTF8.GetBytes(AMsg.ToJSON());
  LHeader := AnsiString(Format('Content-Length: %d'#13#10#13#10, [Length(LBody)]));

  send(FClientSocket, LHeader[1], Length(LHeader), 0);
  send(FClientSocket, LBody[0], Length(LBody), 0);
end;

procedure TDAPServer.SendResponse(const ARequestSeq: Integer;
  const ACommand: string; const ASuccess: Boolean;
  const ABody: TJSONObject; const AMessage: string);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('seq', TJSONNumber.Create(FSeq));
    Inc(FSeq);
    LMsg.AddPair('type', 'response');
    LMsg.AddPair('request_seq', TJSONNumber.Create(ARequestSeq));
    LMsg.AddPair('command', ACommand);
    LMsg.AddPair('success', TJSONBool.Create(ASuccess));

    if ABody <> nil then
      LMsg.AddPair('body', ABody)
    else
      LMsg.AddPair('body', TJSONObject.Create());

    if AMessage <> '' then
      LMsg.AddPair('message', AMessage);

    SendMessage(LMsg);
  finally
    // Don't free ABody -- it's now owned by LMsg
    LMsg.Free();
  end;
end;

procedure TDAPServer.SendEvent(const AEventName: string;
  const ABody: TJSONObject);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('seq', TJSONNumber.Create(FSeq));
    Inc(FSeq);
    LMsg.AddPair('type', 'event');
    LMsg.AddPair('event', AEventName);

    if ABody <> nil then
      LMsg.AddPair('body', ABody)
    else
      LMsg.AddPair('body', TJSONObject.Create());

    SendMessage(LMsg);
  finally
    LMsg.Free();
  end;
end;

//==============================================================================
// TDAPServer -- Message Loop + Dispatch
//==============================================================================

procedure TDAPServer.RunMessageLoop();
var
  LMsg: TJSONObject;
  LCommand: string;
  LSeq: Integer;
begin
  while FState <> dsTerminated do
  begin
    LMsg := ReadMessage();
    if LMsg = nil then
    begin
      // Connection closed
      FState := dsTerminated;
      Break;
    end;

    try
      try
        DispatchRequest(LMsg);
      except
        on E: Exception do
        begin
          LCommand := LMsg.GetValue<string>('command', '');
          LSeq := LMsg.GetValue<Integer>('seq', 0);

          if (LCommand <> '') and (LSeq > 0) then
            SendResponse(LSeq, LCommand, False, nil,
              Format('Internal error: %s', [E.Message]));

          if Assigned(FErrors) then
            FErrors.Add(esFatal, 'DAP900',
              'Exception in DAP handler [%s]: %s', [LCommand, E.Message]);
        end;
      end;
    finally
      LMsg.Free();
    end;
  end;
end;

procedure TDAPServer.DispatchRequest(const AMsg: TJSONObject);
var
  LCommand: string;
  LSeq: Integer;
  LArgs: TJSONObject;
  LType: string;
begin
  LType := AMsg.GetValue<string>('type', '');
  if LType <> 'request' then
    Exit;

  LCommand := AMsg.GetValue<string>('command', '');
  LSeq := AMsg.GetValue<Integer>('seq', 0);
  LArgs := AMsg.GetValue<TJSONObject>('arguments', nil);

  if LCommand = 'initialize' then
    HandleInitialize(LSeq, LArgs)
  else if LCommand = 'launch' then
    HandleLaunch(LSeq, LArgs)
  else if LCommand = 'setBreakpoints' then
    HandleSetBreakpoints(LSeq, LArgs)
  else if LCommand = 'setExceptionBreakpoints' then
    HandleSetExceptionBreakpoints(LSeq, LArgs)
  else if LCommand = 'configurationDone' then
    HandleConfigurationDone(LSeq)
  else if LCommand = 'threads' then
    HandleThreads(LSeq)
  else if LCommand = 'stackTrace' then
    HandleStackTrace(LSeq, LArgs)
  else if LCommand = 'scopes' then
    HandleScopes(LSeq, LArgs)
  else if LCommand = 'variables' then
    HandleVariables(LSeq, LArgs)
  else if LCommand = 'continue' then
    HandleContinue(LSeq)
  else if LCommand = 'next' then
    HandleNext(LSeq)
  else if LCommand = 'stepIn' then
    HandleStepIn(LSeq)
  else if LCommand = 'stepOut' then
    HandleStepOut(LSeq)
  else if LCommand = 'pause' then
    HandlePause(LSeq)
  else if LCommand = 'evaluate' then
    HandleEvaluate(LSeq, LArgs)
  else if LCommand = 'disconnect' then
    HandleDisconnect(LSeq)
  else
    SendResponse(LSeq, LCommand, False, nil, 'Unknown command: ' + LCommand);
end;

//==============================================================================
// TDAPServer -- DAP Command Handlers
//==============================================================================

procedure TDAPServer.HandleInitialize(const ASeq: Integer;
  const AArgs: TJSONObject);
var
  LBody: TJSONObject;
  LFilters: TJSONArray;
  LFilter: TJSONObject;
begin
  // Report capabilities
  LBody := TJSONObject.Create();
  LBody.AddPair('supportsConfigurationDoneRequest', TJSONBool.Create(True));
  LBody.AddPair('supportsFunctionBreakpoints', TJSONBool.Create(False));
  LBody.AddPair('supportsConditionalBreakpoints', TJSONBool.Create(True));
  LBody.AddPair('supportsHitConditionalBreakpoints', TJSONBool.Create(True));
  LBody.AddPair('supportsEvaluateForHovers', TJSONBool.Create(True));
  LBody.AddPair('supportsStepBack', TJSONBool.Create(False));
  LBody.AddPair('supportsSetVariable', TJSONBool.Create(False));
  LBody.AddPair('supportsRestartFrame', TJSONBool.Create(False));
  LBody.AddPair('supportsModulesRequest', TJSONBool.Create(False));
  LBody.AddPair('supportsExceptionInfoRequest', TJSONBool.Create(False));

  LFilters := TJSONArray.Create();
  LFilter := TJSONObject.Create();
  LFilter.AddPair('filter', 'all');
  LFilter.AddPair('label', 'All Exceptions');
  LFilter.AddPair('default', TJSONBool.Create(False));
  LFilters.Add(LFilter);
  LBody.AddPair('exceptionBreakpointFilters', LFilters);

  SendResponse(ASeq, 'initialize', True, LBody);

  // Send initialized event (tells client we're ready for breakpoint config)
  SendEvent('initialized');
  FState := dsInitialized;
end;

procedure TDAPServer.HandleLaunch(const ASeq: Integer;
  const AArgs: TJSONObject);
begin
  // Extract launch configuration fields
  if AArgs <> nil then
  begin
    FSourceRoot := AArgs.GetValue<string>('sourceRoot', '');
    FProgram := AArgs.GetValue<string>('program', '');
    FStopOnEntry := AArgs.GetValue<Boolean>('stopOnEntry', False);
  end;

  FState := dsConfiguring;
  SendResponse(ASeq, 'launch', True);
end;

procedure TDAPServer.HandleSetBreakpoints(const ASeq: Integer;
  const AArgs: TJSONObject);
var
  LSource: TJSONObject;
  LSourcePath: string;
  LBreakpointsArr: TJSONArray;
  LResultArr: TJSONArray;
  LBody: TJSONObject;
  LBP: TJSONObject;
  LBPObj: TJSONObject;
  LLine: Integer;
  LID: Integer;
  LI: Integer;
  LCondition: string;
  LHitCondition: Integer;
begin
  LResultArr := TJSONArray.Create();

  if AArgs <> nil then
  begin
    LSource := AArgs.GetValue<TJSONObject>('source', nil);
    if LSource <> nil then
      LSourcePath := LSource.GetValue<string>('path', '')
    else
      LSourcePath := '';

    LBreakpointsArr := AArgs.GetValue<TJSONArray>('breakpoints', nil);
    if LBreakpointsArr <> nil then
    begin
      for LI := 0 to LBreakpointsArr.Count - 1 do
      begin
        LBPObj := LBreakpointsArr.Items[LI] as TJSONObject;
        LLine := LBPObj.GetValue<Integer>('line', 0);
        LCondition := LBPObj.GetValue<string>('condition', '');
        LHitCondition := StrToIntDef(
          LBPObj.GetValue<string>('hitCondition', ''), 0);

        LID := FRuntime.SetBreakpoint(LSourcePath, LLine,
          LCondition, LHitCondition);

        LBP := TJSONObject.Create();
        LBP.AddPair('verified', TJSONBool.Create(LID >= 0));
        LBP.AddPair('line', TJSONNumber.Create(LLine));
        if LID >= 0 then
          LBP.AddPair('id', TJSONNumber.Create(LID));
        LResultArr.Add(LBP);
      end;
    end;
  end;

  LBody := TJSONObject.Create();
  LBody.AddPair('breakpoints', LResultArr);
  SendResponse(ASeq, 'setBreakpoints', True, LBody);
end;

procedure TDAPServer.HandleSetExceptionBreakpoints(const ASeq: Integer;
  const AArgs: TJSONObject);
var
  LFilters: TJSONArray;
  LI: Integer;
  LEnabled: Boolean;
  LTarget: TDebugTarget;
begin
  LEnabled := False;

  // Check if 'all' filter is in the filters array
  if AArgs <> nil then
  begin
    LFilters := AArgs.GetValue<TJSONArray>('filters', nil);
    if LFilters <> nil then
    begin
      for LI := 0 to LFilters.Count - 1 do
      begin
        if LFilters.Items[LI].Value = 'all' then
        begin
          LEnabled := True;
          Break;
        end;
      end;
    end;
  end;

  // Set the flag on the debug target
  if Assigned(FRuntime) then
  begin
    LTarget := FRuntime.GetTarget();
    if Assigned(LTarget) then
      LTarget.SetBreakOnExceptions(LEnabled);
  end;

  SendResponse(ASeq, 'setExceptionBreakpoints', True);
end;

procedure TDAPServer.HandleConfigurationDone(const ASeq: Integer);
begin
  // Client has finished sending initial breakpoints -- start the debuggee
  FState := dsRunning;
  SendResponse(ASeq, 'configurationDone', True);

  // Apply breakpoints and release the held process
  FRuntime.ConfigurationDone();
end;

procedure TDAPServer.HandleThreads(const ASeq: Integer);
var
  LBody: TJSONObject;
  LThreads: TJSONArray;
  LThread: TJSONObject;
begin
  // Metamorf-compiled programs are single-threaded -- report one thread
  LThreads := TJSONArray.Create();
  LThread := TJSONObject.Create();
  LThread.AddPair('id', TJSONNumber.Create(1));
  LThread.AddPair('name', 'Main Thread');
  LThreads.Add(LThread);

  LBody := TJSONObject.Create();
  LBody.AddPair('threads', LThreads);
  SendResponse(ASeq, 'threads', True, LBody);
end;

procedure TDAPServer.HandleStackTrace(const ASeq: Integer;
  const AArgs: TJSONObject);
var
  LBody: TJSONObject;
  LFrames: TJSONArray;
  LFrameObj: TJSONObject;
  LSourceObj: TJSONObject;
  LStack: TArray<TDebugStackFrame>;
  LI: Integer;
begin
  LStack := FRuntime.GetCallStack();

  LFrames := TJSONArray.Create();
  for LI := 0 to High(LStack) do
  begin
    LFrameObj := TJSONObject.Create();
    LFrameObj.AddPair('id', TJSONNumber.Create(LStack[LI].FrameID));
    LFrameObj.AddPair('name', LStack[LI].FunctionName);
    LFrameObj.AddPair('line', TJSONNumber.Create(LStack[LI].SourceLine));
    LFrameObj.AddPair('column', TJSONNumber.Create(LStack[LI].SourceColumn));

    if LStack[LI].SourceFile <> '' then
    begin
      LSourceObj := TJSONObject.Create();
      LSourceObj.AddPair('name', ExtractFileName(LStack[LI].SourceFile));
      LSourceObj.AddPair('path', LStack[LI].SourceFile);
      LFrameObj.AddPair('source', LSourceObj);
    end;

    LFrames.Add(LFrameObj);
  end;

  LBody := TJSONObject.Create();
  LBody.AddPair('stackFrames', LFrames);
  LBody.AddPair('totalFrames', TJSONNumber.Create(Length(LStack)));
  SendResponse(ASeq, 'stackTrace', True, LBody);
end;

procedure TDAPServer.HandleScopes(const ASeq: Integer;
  const AArgs: TJSONObject);
var
  LBody: TJSONObject;
  LScopes: TJSONArray;
  LScope: TJSONObject;
begin
  // Return a single "Locals" scope
  LScopes := TJSONArray.Create();
  LScope := TJSONObject.Create();
  LScope.AddPair('name', 'Locals');
  LScope.AddPair('variablesReference', TJSONNumber.Create(1));
  LScope.AddPair('expensive', TJSONBool.Create(False));
  LScopes.Add(LScope);

  LBody := TJSONObject.Create();
  LBody.AddPair('scopes', LScopes);
  SendResponse(ASeq, 'scopes', True, LBody);
end;

procedure TDAPServer.HandleVariables(const ASeq: Integer;
  const AArgs: TJSONObject);
var
  LBody: TJSONObject;
  LVarsArray: TJSONArray;
  LVarObj: TJSONObject;
  LVars: TArray<TDebugVariable>;
  LI: Integer;
begin
  LVarsArray := TJSONArray.Create();

  // Read variables from the runtime (reads from target memory)
  LVars := FRuntime.GetVariables();
  for LI := 0 to High(LVars) do
  begin
    LVarObj := TJSONObject.Create();
    LVarObj.AddPair('name', LVars[LI].VarName);
    LVarObj.AddPair('value', LVars[LI].VarValue);
    LVarObj.AddPair('type', LVars[LI].VarType);
    LVarObj.AddPair('variablesReference', TJSONNumber.Create(0));
    LVarsArray.Add(LVarObj);
  end;

  LBody := TJSONObject.Create();
  LBody.AddPair('variables', LVarsArray);
  SendResponse(ASeq, 'variables', True, LBody);
end;

//------------------------------------------------------------------------------
// Execution control handlers
//------------------------------------------------------------------------------

procedure TDAPServer.HandleContinue(const ASeq: Integer);
var
  LBody: TJSONObject;
begin
  // Guard: only continue when actually stopped
  if FState <> dsStopped then
  begin
    LBody := TJSONObject.Create();
    LBody.AddPair('allThreadsContinued', TJSONBool.Create(True));
    SendResponse(ASeq, 'continue', True, LBody);
    Exit;
  end;

  LBody := TJSONObject.Create();
  LBody.AddPair('allThreadsContinued', TJSONBool.Create(True));
  SendResponse(ASeq, 'continue', True, LBody);

  FState := dsRunning;
  FRuntime.DoContinue();
end;

procedure TDAPServer.HandleNext(const ASeq: Integer);
begin
  if FState <> dsStopped then
  begin
    SendResponse(ASeq, 'next', True);
    Exit;
  end;
  SendResponse(ASeq, 'next', True);
  FState := dsRunning;
  FRuntime.StepOver();
end;

procedure TDAPServer.HandleStepIn(const ASeq: Integer);
begin
  if FState <> dsStopped then
  begin
    SendResponse(ASeq, 'stepIn', True);
    Exit;
  end;
  SendResponse(ASeq, 'stepIn', True);
  FState := dsRunning;
  FRuntime.StepIn();
end;

procedure TDAPServer.HandleStepOut(const ASeq: Integer);
begin
  if FState <> dsStopped then
  begin
    SendResponse(ASeq, 'stepOut', True);
    Exit;
  end;
  SendResponse(ASeq, 'stepOut', True);
  FState := dsRunning;
  FRuntime.StepOut();
end;

procedure TDAPServer.HandlePause(const ASeq: Integer);
begin
  // Not fully supported in v1 -- would need to inject INT3
  SendResponse(ASeq, 'pause', True);
end;

procedure TDAPServer.HandleEvaluate(const ASeq: Integer;
  const AArgs: TJSONObject);
var
  LExpression: string;
  LBody: TJSONObject;
  LVar: TDebugVariable;
begin
  LExpression := '';
  if AArgs <> nil then
    LExpression := AArgs.GetValue<string>('expression', '');

  if LExpression = '' then
  begin
    SendResponse(ASeq, 'evaluate', False, nil, 'Empty expression');
    Exit;
  end;

  // Look up the variable through the runtime
  LVar := FRuntime.Evaluate(LExpression);

  LBody := TJSONObject.Create();
  if LVar.VarValue <> '' then
  begin
    LBody.AddPair('result', LVar.VarValue);
    LBody.AddPair('type', LVar.VarType);
    LBody.AddPair('variablesReference', TJSONNumber.Create(0));
    SendResponse(ASeq, 'evaluate', True, LBody);
  end
  else
  begin
    LBody.Free();
    SendResponse(ASeq, 'evaluate', False, nil,
      Format('Variable ''%s'' not found in current scope', [LExpression]));
  end;
end;

procedure TDAPServer.HandleDisconnect(const ASeq: Integer);
begin
  SendResponse(ASeq, 'disconnect', True);
  SendEvent('terminated');
  FState := dsTerminated;
end;

//------------------------------------------------------------------------------
// Stop event handling -- sends DAP stopped event to client
//------------------------------------------------------------------------------

procedure TDAPServer.ProcessStopEvent();
var
  LBody: TJSONObject;
  LEvent: TDebugStopEvent;
begin
  LEvent := FRuntime.GetLastStopEvent();

  LBody := TJSONObject.Create();
  LBody.AddPair('threadId', TJSONNumber.Create(1));
  LBody.AddPair('allThreadsStopped', TJSONBool.Create(True));

  case LEvent.Reason of
    dsrBreakpoint:
    begin
      LBody.AddPair('reason', 'breakpoint');
      FState := dsStopped;
    end;
    dsrSingleStep:
    begin
      LBody.AddPair('reason', 'step');
      FState := dsStopped;
    end;
    dsrException:
    begin
      LBody.AddPair('reason', 'exception');
      if LEvent.ExceptionMessage <> '' then
        LBody.AddPair('description', LEvent.ExceptionMessage)
      else
        LBody.AddPair('description',
          Format('Exception 0x%x', [LEvent.ExceptionCode]));
      LBody.AddPair('text', Format('0x%x', [LEvent.ExceptionCode]));
      FState := dsStopped;
    end;
    dsrProcessExit:
    begin
      // DAP spec: send exited (with exit code) then terminated
      LBody.Free();
      LBody := TJSONObject.Create();
      LBody.AddPair('exitCode', TJSONNumber.Create(LEvent.ExitCode));
      SendEvent('exited', LBody);
      SendEvent('terminated');
      FState := dsTerminated;
      Exit;
    end;
    dsrDllLoad:
    begin
      // DLL load is handled internally by the runtime -- should not reach here.
      // If it does, just ignore it.
      LBody.Free();
      Exit;
    end;
  else
    LBody.AddPair('reason', 'pause');
    FState := dsStopped;
  end;

  SendEvent('stopped', LBody);
end;

end.
