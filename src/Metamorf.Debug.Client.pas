{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug.Client;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  WinApi.WinSock,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  Metamorf.Utils;

type
  //============================================================================
  // TDAPClientState - Client-side debug session states
  //============================================================================
  TDAPClientState = (
    dcsDisconnected,   // Not connected to server
    dcsConnected,      // TCP connected, not yet initialized
    dcsInitialized,    // Initialize handshake done
    dcsLaunched,       // Launch sent, program running
    dcsStopped,        // Program stopped (breakpoint, step, etc.)
    dcsExited          // Program exited
  );

  //============================================================================
  // TDAPClientVariable - Variable info returned from server
  //============================================================================
  TDAPClientVariable = record
    VarName: string;
    VarValue: string;
    VarType: string;
    VariablesReference: Integer;
  end;

  //============================================================================
  // TDAPClientStackFrame - Stack frame info returned from server
  //============================================================================
  TDAPClientStackFrame = record
    FrameID: Integer;
    FunctionName: string;
    SourceFile: string;
    SourceLine: Integer;
  end;

  //============================================================================
  // TDAPClientScope - Scope info returned from server
  //============================================================================
  TDAPClientScope = record
    ScopeName: string;
    VariablesReference: Integer;
    Expensive: Boolean;
  end;

  //============================================================================
  // Callback types
  //============================================================================
  TDAPClientStoppedCallback = reference to procedure(const AReason: string; const AThreadId: Integer);
  TDAPClientOutputCallback = reference to procedure(const AOutput: string);
  TDAPClientExitedCallback = reference to procedure(const AExitCode: Integer);

  //============================================================================
  // TMetamorfDebugClient - DAP client that connects to a Metamorf DAP server
  // over TCP. Sends DAP requests, receives responses and events.
  //============================================================================

  { TMetamorfDebugClient }
  TMetamorfDebugClient = class(TBaseObject)
  private
    FSocket: TSocket;
    FState: TDAPClientState;
    FNextSeq: Integer;
    FLastError: string;
    FCurrentThreadId: Integer;
    FVerboseLogging: Boolean;
    FReadBuffer: TBytes;       // Accumulates partial TCP reads
    FReadBufferLen: Integer;   // Valid bytes in FReadBuffer

    // Callbacks
    FOnStopped: TDAPClientStoppedCallback;
    FOnOutput: TDAPClientOutputCallback;
    FOnExited: TDAPClientExitedCallback;

    // Internal helpers
    function GetNextSeq(): Integer;
    procedure SetError(const AError: string);

    // TCP transport
    function SendRaw(const AData: string): Boolean;
    function ReadDAPMessage(out AJson: string; const ATimeoutMS: Integer = 5000): Boolean;
    procedure SendDAPMessage(const AJson: string);

    // DAP protocol
    function SendRequest(const ACommand: string; const AArgs: TJSONObject = nil): TJSONObject;
    procedure ProcessEvent(const AEvent: TJSONObject);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Connection
    function Connect(const AHost: string; const APort: Integer): Boolean;
    procedure Disconnect();

    // DAP session lifecycle
    function Initialize(): Boolean;
    function Launch(const AProgram: string; const AStopOnEntry: Boolean = False): Boolean;
    function ConfigurationDone(): Boolean;

    // Breakpoints
    function SetBreakpoints(const ASourcePath: string;
      const ALines: array of Integer): Boolean; overload;
    function SetBreakpoints(const ASourcePath: string;
      const ALines: array of Integer;
      const AHitConditions: array of Integer): Boolean; overload;

    // Execution control
    function Continue(): Boolean;
    function StepOver(): Boolean;
    function StepIn(): Boolean;
    function StepOut(): Boolean;

    // Inspection
    function GetCallStack(const AThreadId: Integer = 0): TArray<TDAPClientStackFrame>;
    function GetScopes(const AFrameId: Integer): TArray<TDAPClientScope>;
    function GetVariables(const AVariablesReference: Integer): TArray<TDAPClientVariable>;
    function Evaluate(const AExpression: string;
      const AFrameId: Integer = 0): string;

    // Event processing
    procedure ProcessPendingEvents(const ATimeoutMS: Integer = 1000);

    // Shutdown
    function DisconnectDAP(): Boolean;

    // State
    function HasError(): Boolean;
    function GetLastError(): string;
    function GetState(): TDAPClientState;
    function GetCurrentThreadId(): Integer;

    // Properties
    property State: TDAPClientState read FState;
    property VerboseLogging: Boolean read FVerboseLogging write FVerboseLogging;
    property OnStopped: TDAPClientStoppedCallback read FOnStopped write FOnStopped;
    property OnOutput: TDAPClientOutputCallback read FOnOutput write FOnOutput;
    property OnExited: TDAPClientExitedCallback read FOnExited write FOnExited;
  end;

implementation

//==============================================================================
// TMetamorfDebugClient
//==============================================================================

constructor TMetamorfDebugClient.Create();
begin
  inherited Create();
  FSocket := INVALID_SOCKET;
  FState := dcsDisconnected;
  FNextSeq := 1;
  FLastError := '';
  FCurrentThreadId := 0;
  FVerboseLogging := False;
  SetLength(FReadBuffer, 65536);
  FReadBufferLen := 0;
  FOnStopped := nil;
  FOnOutput := nil;
  FOnExited := nil;
end;

destructor TMetamorfDebugClient.Destroy();
begin
  Disconnect();
  inherited Destroy();
end;

function TMetamorfDebugClient.GetNextSeq(): Integer;
begin
  Result := FNextSeq;
  Inc(FNextSeq);
end;

procedure TMetamorfDebugClient.SetError(const AError: string);
begin
  FLastError := AError;
end;

function TMetamorfDebugClient.HasError(): Boolean;
begin
  Result := FLastError <> '';
end;

function TMetamorfDebugClient.GetLastError(): string;
begin
  Result := FLastError;
end;

function TMetamorfDebugClient.GetState(): TDAPClientState;
begin
  Result := FState;
end;

function TMetamorfDebugClient.GetCurrentThreadId(): Integer;
begin
  Result := FCurrentThreadId;
end;

//------------------------------------------------------------------------------
// TCP Transport
//------------------------------------------------------------------------------

function TMetamorfDebugClient.Connect(const AHost: string; const APort: Integer): Boolean;
var
  LWSAData: TWSAData;
  LAddr: TSockAddrIn;
  LHostEnt: PHostEnt;
begin
  Result := False;
  FLastError := '';

  if WSAStartup(MakeWord(2, 2), LWSAData) <> 0 then
  begin
    SetError('WSAStartup failed');
    Exit;
  end;

  FSocket := WinApi.WinSock.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if FSocket = INVALID_SOCKET then
  begin
    SetError('Failed to create socket');
    WSACleanup();
    Exit;
  end;

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  LAddr.sin_addr.S_addr := inet_addr(PAnsiChar(AnsiString(AHost)));

  if LAddr.sin_addr.S_addr = u_long($FFFFFFFF) then
  begin
    LHostEnt := gethostbyname(PAnsiChar(AnsiString(AHost)));
    if LHostEnt = nil then
    begin
      SetError('Cannot resolve host: ' + AHost);
      closesocket(FSocket);
      FSocket := INVALID_SOCKET;
      WSACleanup();
      Exit;
    end;
    LAddr.sin_addr := PInAddr(LHostEnt^.h_addr_list^)^;
  end;

  if WinApi.WinSock.connect(FSocket, LAddr, SizeOf(LAddr)) = SOCKET_ERROR then
  begin
    SetError(Format('Cannot connect to %s:%d', [AHost, APort]));
    closesocket(FSocket);
    FSocket := INVALID_SOCKET;
    WSACleanup();
    Exit;
  end;

  FState := dcsConnected;
  FReadBufferLen := 0;
  Result := True;
end;

procedure TMetamorfDebugClient.Disconnect();
begin
  if FSocket <> INVALID_SOCKET then
  begin
    closesocket(FSocket);
    FSocket := INVALID_SOCKET;
    WSACleanup();
  end;
  FState := dcsDisconnected;
  FReadBufferLen := 0;
end;

function TMetamorfDebugClient.SendRaw(const AData: string): Boolean;
var
  LBytes: TBytes;
  LSent: Integer;
  LTotal: Integer;
  LRemaining: Integer;
begin
  Result := False;
  if FSocket = INVALID_SOCKET then Exit;

  LBytes := TEncoding.UTF8.GetBytes(AData);
  LTotal := 0;
  LRemaining := Length(LBytes);

  while LRemaining > 0 do
  begin
    LSent := send(FSocket, LBytes[LTotal], LRemaining, 0);
    if LSent = SOCKET_ERROR then
    begin
      SetError('Send failed');
      Exit;
    end;
    Inc(LTotal, LSent);
    Dec(LRemaining, LSent);
  end;
  Result := True;
end;

procedure TMetamorfDebugClient.SendDAPMessage(const AJson: string);
var
  LMsg: string;
begin
  LMsg := Format('Content-Length: %d'#13#10#13#10'%s',
    [Length(TEncoding.UTF8.GetBytes(AJson)), AJson]);
  if FVerboseLogging then
    TUtils.PrintLn('[DAP-C] >> ' + AJson);
  SendRaw(LMsg);
end;

function TMetamorfDebugClient.ReadDAPMessage(out AJson: string;
  const ATimeoutMS: Integer): Boolean;
var
  LHeaderEnd: Integer;
  LHeader: string;
  LContentLength: Integer;
  LI: Integer;
  LReceived: Integer;
  LNeeded: Integer;
  LFD: TFDSet;
  LTimeout: TTimeVal;
  LSelectResult: Integer;
begin
  Result := False;
  AJson := '';

  if FSocket = INVALID_SOCKET then Exit;

  // Read until we have a complete Content-Length header + body
  while True do
  begin
    // Check if we have a complete header in the buffer
    LHeaderEnd := -1;
    for LI := 0 to FReadBufferLen - 4 do
    begin
      if (FReadBuffer[LI] = 13) and (FReadBuffer[LI+1] = 10) and
         (FReadBuffer[LI+2] = 13) and (FReadBuffer[LI+3] = 10) then
      begin
        LHeaderEnd := LI;
        Break;
      end;
    end;

    if LHeaderEnd >= 0 then
    begin
      // Parse Content-Length from header
      LHeader := TEncoding.UTF8.GetString(FReadBuffer, 0, LHeaderEnd);
      LContentLength := 0;
      if Pos('Content-Length:', LHeader) > 0 then
        LContentLength := StrToIntDef(Trim(Copy(LHeader,
          Pos(':', LHeader) + 1, MaxInt)), 0);

      if LContentLength <= 0 then
      begin
        SetError('Invalid Content-Length in DAP message');
        Exit;
      end;

      // Check if we have the full body
      LNeeded := (LHeaderEnd + 4) + LContentLength;
      if FReadBufferLen >= LNeeded then
      begin
        // Extract JSON body
        AJson := TEncoding.UTF8.GetString(FReadBuffer,
          LHeaderEnd + 4, LContentLength);

        // Shift remaining data to front of buffer
        if FReadBufferLen > LNeeded then
          Move(FReadBuffer[LNeeded], FReadBuffer[0], FReadBufferLen - LNeeded);
        Dec(FReadBufferLen, LNeeded);

        if FVerboseLogging then
          TUtils.PrintLn('[DAP-C] << ' + AJson);

        Result := True;
        Exit;
      end;
    end;

    // Need more data -- use select() with timeout
    FD_ZERO(LFD);
    FD_SET(FSocket, LFD);
    LTimeout.tv_sec := ATimeoutMS div 1000;
    LTimeout.tv_usec := (ATimeoutMS mod 1000) * 1000;

    LSelectResult := select(0, @LFD, nil, nil, @LTimeout);
    if LSelectResult <= 0 then
    begin
      if LSelectResult = 0 then
        SetError('Timeout reading DAP message')
      else
        SetError('Select failed');
      Exit;
    end;

    // Grow buffer if needed
    if FReadBufferLen >= Length(FReadBuffer) - 4096 then
      SetLength(FReadBuffer, Length(FReadBuffer) * 2);

    LReceived := recv(FSocket, FReadBuffer[FReadBufferLen],
      Length(FReadBuffer) - FReadBufferLen, 0);
    if LReceived <= 0 then
    begin
      SetError('Connection closed');
      Exit;
    end;

    Inc(FReadBufferLen, LReceived);
  end;
end;

//------------------------------------------------------------------------------
// DAP Protocol -- SendRequest + Event Processing
//------------------------------------------------------------------------------

function TMetamorfDebugClient.SendRequest(const ACommand: string;
  const AArgs: TJSONObject): TJSONObject;
var
  LRequest: TJSONObject;
  LRequestJson: string;
  LResponseJson: string;
  LResponse: TJSONObject;
  LMsgType: string;
  LSuccess: Boolean;
  LMessage: string;
begin
  Result := nil;
  FLastError := '';

  if FSocket = INVALID_SOCKET then
  begin
    SetError('Not connected');
    Exit;
  end;

  // Build DAP request
  LRequest := TJSONObject.Create();
  try
    LRequest.AddPair('seq', TJSONNumber.Create(GetNextSeq()));
    LRequest.AddPair('type', 'request');
    LRequest.AddPair('command', ACommand);
    if Assigned(AArgs) then
      LRequest.AddPair('arguments', AArgs.Clone() as TJSONObject);
    LRequestJson := LRequest.ToString();
  finally
    LRequest.Free();
  end;

  SendDAPMessage(LRequestJson);

  // Read responses (processing events in between)
  while True do
  begin
    if not ReadDAPMessage(LResponseJson, 10000) then
      Exit;

    LResponse := nil;
    try
      LResponse := TJSONObject.ParseJSONValue(LResponseJson) as TJSONObject;
    except
      SetError('Invalid JSON response');
      Exit;
    end;

    if not Assigned(LResponse) then
    begin
      SetError('Failed to parse DAP response');
      Exit;
    end;

    try
      LMsgType := LResponse.GetValue<string>('type');

      if LMsgType = 'event' then
      begin
        // Process event and keep waiting for actual response
        ProcessEvent(LResponse);
        FreeAndNil(LResponse);
        Continue;
      end
      else if LMsgType = 'response' then
      begin
        LSuccess := LResponse.GetValue<Boolean>('success');
        if not LSuccess then
        begin
          LMessage := LResponse.GetValue<string>('message', 'Unknown error');
          SetError('DAP error: ' + LMessage);
          LResponse.Free();
          Exit;
        end;

        // Return the full response (caller frees)
        Result := LResponse;
        Exit;
      end;
    except
      on E: Exception do
      begin
        SetError('Error processing response: ' + E.Message);
        LResponse.Free();
        Exit;
      end;
    end;
  end;
end;

procedure TMetamorfDebugClient.ProcessEvent(const AEvent: TJSONObject);
var
  LEventName: string;
  LBody: TJSONObject;
  LReason: string;
  LThreadId: Integer;
  LExitCode: Integer;
  LOutput: string;
begin
  try
    LEventName := AEvent.GetValue<string>('event');

    if LEventName = 'stopped' then
    begin
      LBody := AEvent.GetValue<TJSONObject>('body');
      if Assigned(LBody) then
      begin
        LReason := LBody.GetValue<string>('reason', '');
        LThreadId := LBody.GetValue<Integer>('threadId', 0);
        FCurrentThreadId := LThreadId;
        FState := dcsStopped;
        if Assigned(FOnStopped) then
          FOnStopped(LReason, LThreadId);
      end;
    end
    else if LEventName = 'exited' then
    begin
      LBody := AEvent.GetValue<TJSONObject>('body');
      LExitCode := 0;
      if Assigned(LBody) then
        LExitCode := LBody.GetValue<Integer>('exitCode', 0);
      FState := dcsExited;
      if Assigned(FOnExited) then
        FOnExited(LExitCode);
    end
    else if LEventName = 'terminated' then
    begin
      FState := dcsExited;
    end
    else if LEventName = 'output' then
    begin
      LBody := AEvent.GetValue<TJSONObject>('body');
      if Assigned(LBody) then
      begin
        LOutput := LBody.GetValue<string>('output', '');
        if Assigned(FOnOutput) and (LOutput <> '') then
          FOnOutput(LOutput);
      end;
    end;
  except
    // Silently ignore malformed events
  end;
end;

procedure TMetamorfDebugClient.ProcessPendingEvents(const ATimeoutMS: Integer);
var
  LJson: string;
  LObj: TJSONObject;
  LMsgType: string;
begin
  while ReadDAPMessage(LJson, ATimeoutMS) do
  begin
    LObj := nil;
    try
      LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
      if Assigned(LObj) then
      begin
        LMsgType := LObj.GetValue<string>('type', '');
        if LMsgType = 'event' then
          ProcessEvent(LObj);
      end;
    finally
      LObj.Free();
    end;
  end;
end;

//------------------------------------------------------------------------------
// DAP Session Lifecycle
//------------------------------------------------------------------------------

function TMetamorfDebugClient.Initialize(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;
  LArgs := TJSONObject.Create();
  LArgs.AddPair('clientID', 'metamorf-test');
  LArgs.AddPair('adapterID', 'metamorf');
  LArgs.AddPair('linesStartAt1', TJSONBool.Create(True));
  LArgs.AddPair('columnsStartAt1', TJSONBool.Create(True));
  LArgs.AddPair('pathFormat', 'path');

  LResponse := SendRequest('initialize', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    FState := dcsInitialized;
    Result := True;
  end;
end;

function TMetamorfDebugClient.Launch(const AProgram: string;
  const AStopOnEntry: Boolean): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;
  LArgs := TJSONObject.Create();
  LArgs.AddPair('program', AProgram);
  LArgs.AddPair('stopOnEntry', TJSONBool.Create(AStopOnEntry));

  LResponse := SendRequest('launch', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    FState := dcsLaunched;
    Result := True;
  end;
end;

function TMetamorfDebugClient.ConfigurationDone(): Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;
  LResponse := SendRequest('configurationDone', nil);
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

//------------------------------------------------------------------------------
// Breakpoints
//------------------------------------------------------------------------------

function TMetamorfDebugClient.SetBreakpoints(const ASourcePath: string;
  const ALines: array of Integer): Boolean;
var
  LArgs: TJSONObject;
  LSource: TJSONObject;
  LBPs: TJSONArray;
  LBP: TJSONObject;
  LI: Integer;
  LResponse: TJSONObject;
begin
  Result := False;

  LSource := TJSONObject.Create();
  LSource.AddPair('path', ASourcePath);

  LBPs := TJSONArray.Create();
  for LI := 0 to High(ALines) do
  begin
    LBP := TJSONObject.Create();
    LBP.AddPair('line', TJSONNumber.Create(ALines[LI]));
    LBPs.Add(LBP);
  end;

  LArgs := TJSONObject.Create();
  LArgs.AddPair('source', LSource);
  LArgs.AddPair('breakpoints', LBPs);

  LResponse := SendRequest('setBreakpoints', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

function TMetamorfDebugClient.SetBreakpoints(const ASourcePath: string;
  const ALines: array of Integer;
  const AHitConditions: array of Integer): Boolean;
var
  LArgs: TJSONObject;
  LSource: TJSONObject;
  LBPs: TJSONArray;
  LBP: TJSONObject;
  LI: Integer;
  LResponse: TJSONObject;
begin
  Result := False;

  LSource := TJSONObject.Create();
  LSource.AddPair('path', ASourcePath);

  LBPs := TJSONArray.Create();
  for LI := 0 to High(ALines) do
  begin
    LBP := TJSONObject.Create();
    LBP.AddPair('line', TJSONNumber.Create(ALines[LI]));
    // Add hitCondition if provided for this index
    if (LI <= High(AHitConditions)) and (AHitConditions[LI] > 0) then
      LBP.AddPair('hitCondition', IntToStr(AHitConditions[LI]));
    LBPs.Add(LBP);
  end;

  LArgs := TJSONObject.Create();
  LArgs.AddPair('source', LSource);
  LArgs.AddPair('breakpoints', LBPs);

  LResponse := SendRequest('setBreakpoints', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

//------------------------------------------------------------------------------
// Execution Control
//------------------------------------------------------------------------------

function TMetamorfDebugClient.Continue(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;
  LArgs := TJSONObject.Create();
  LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadId));
  LResponse := SendRequest('continue', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    FState := dcsLaunched;
    Result := True;
  end;
end;

function TMetamorfDebugClient.StepOver(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;
  LArgs := TJSONObject.Create();
  LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadId));
  LResponse := SendRequest('next', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

function TMetamorfDebugClient.StepIn(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;
  LArgs := TJSONObject.Create();
  LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadId));
  LResponse := SendRequest('stepIn', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

function TMetamorfDebugClient.StepOut(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;
  LArgs := TJSONObject.Create();
  LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadId));
  LResponse := SendRequest('stepOut', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

//------------------------------------------------------------------------------
// Inspection
//------------------------------------------------------------------------------

function TMetamorfDebugClient.GetCallStack(const AThreadId: Integer): TArray<TDAPClientStackFrame>;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LFrames: TJSONArray;
  LFrame: TJSONObject;
  LSource: TJSONObject;
  LI: Integer;
  LThreadId: Integer;
begin
  Result := nil;

  LThreadId := AThreadId;
  if LThreadId = 0 then
    LThreadId := FCurrentThreadId;
  if LThreadId = 0 then
    LThreadId := 1;

  LArgs := TJSONObject.Create();
  LArgs.AddPair('threadId', TJSONNumber.Create(LThreadId));
  LArgs.AddPair('startFrame', TJSONNumber.Create(0));
  LArgs.AddPair('levels', TJSONNumber.Create(20));

  LResponse := SendRequest('stackTrace', LArgs);
  LArgs.Free();
  if not Assigned(LResponse) then Exit;

  try
    LBody := LResponse.GetValue<TJSONObject>('body');
    if not Assigned(LBody) then Exit;

    LFrames := LBody.GetValue<TJSONArray>('stackFrames');
    if not Assigned(LFrames) then Exit;

    SetLength(Result, LFrames.Count);
    for LI := 0 to LFrames.Count - 1 do
    begin
      LFrame := LFrames.Items[LI] as TJSONObject;
      Result[LI].FrameID := LFrame.GetValue<Integer>('id', 0);
      Result[LI].FunctionName := LFrame.GetValue<string>('name', '');
      Result[LI].SourceLine := LFrame.GetValue<Integer>('line', 0);

      LSource := nil;
      try
        LSource := LFrame.GetValue<TJSONObject>('source');
      except
      end;
      if Assigned(LSource) then
        Result[LI].SourceFile := LSource.GetValue<string>('path', '')
      else
        Result[LI].SourceFile := '';
    end;
  finally
    LResponse.Free();
  end;
end;

function TMetamorfDebugClient.GetScopes(const AFrameId: Integer): TArray<TDAPClientScope>;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LScopes: TJSONArray;
  LScope: TJSONObject;
  LI: Integer;
begin
  Result := nil;

  LArgs := TJSONObject.Create();
  LArgs.AddPair('frameId', TJSONNumber.Create(AFrameId));

  LResponse := SendRequest('scopes', LArgs);
  LArgs.Free();
  if not Assigned(LResponse) then Exit;

  try
    LBody := LResponse.GetValue<TJSONObject>('body');
    if not Assigned(LBody) then Exit;

    LScopes := LBody.GetValue<TJSONArray>('scopes');
    if not Assigned(LScopes) then Exit;

    SetLength(Result, LScopes.Count);
    for LI := 0 to LScopes.Count - 1 do
    begin
      LScope := LScopes.Items[LI] as TJSONObject;
      Result[LI].ScopeName := LScope.GetValue<string>('name', '');
      Result[LI].VariablesReference := LScope.GetValue<Integer>('variablesReference', 0);
      Result[LI].Expensive := LScope.GetValue<Boolean>('expensive', False);
    end;
  finally
    LResponse.Free();
  end;
end;

function TMetamorfDebugClient.GetVariables(const AVariablesReference: Integer): TArray<TDAPClientVariable>;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LVars: TJSONArray;
  LVar: TJSONObject;
  LI: Integer;
begin
  Result := nil;

  LArgs := TJSONObject.Create();
  LArgs.AddPair('variablesReference', TJSONNumber.Create(AVariablesReference));

  LResponse := SendRequest('variables', LArgs);
  LArgs.Free();
  if not Assigned(LResponse) then Exit;

  try
    LBody := LResponse.GetValue<TJSONObject>('body');
    if not Assigned(LBody) then Exit;

    LVars := LBody.GetValue<TJSONArray>('variables');
    if not Assigned(LVars) then Exit;

    SetLength(Result, LVars.Count);
    for LI := 0 to LVars.Count - 1 do
    begin
      LVar := LVars.Items[LI] as TJSONObject;
      Result[LI].VarName := LVar.GetValue<string>('name', '');
      Result[LI].VarValue := LVar.GetValue<string>('value', '');
      Result[LI].VarType := LVar.GetValue<string>('type', '');
      Result[LI].VariablesReference := LVar.GetValue<Integer>('variablesReference', 0);
    end;
  finally
    LResponse.Free();
  end;
end;

function TMetamorfDebugClient.Evaluate(const AExpression: string;
  const AFrameId: Integer): string;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
begin
  Result := '';
  FLastError := '';

  LArgs := TJSONObject.Create();
  LArgs.AddPair('expression', AExpression);
  LArgs.AddPair('frameId', TJSONNumber.Create(AFrameId));
  LArgs.AddPair('context', 'repl');

  LResponse := SendRequest('evaluate', LArgs);
  LArgs.Free();
  if not Assigned(LResponse) then
    Exit;

  try
    LBody := LResponse.GetValue<TJSONObject>('body');
    if Assigned(LBody) then
      Result := LBody.GetValue<string>('result', '');
  finally
    LResponse.Free();
  end;
end;

//------------------------------------------------------------------------------
// Shutdown
//------------------------------------------------------------------------------

function TMetamorfDebugClient.DisconnectDAP(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  LArgs := TJSONObject.Create();
  LArgs.AddPair('terminateDebuggee', TJSONBool.Create(True));

  LResponse := SendRequest('disconnect', LArgs);
  LArgs.Free();
  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

end.
