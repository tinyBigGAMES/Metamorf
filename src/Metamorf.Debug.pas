{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug;

{$I Metamorf.Defines.inc}

interface

uses
  WinAPI.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Config;

type
  { TDebugState }
  TDebugState = (
    dsNotStarted,   // DAP not started
    dsInitializing, // Sent initialize request
    dsReady,        // Initialized, ready for launch
    dsLaunched,     // Program launched
    dsRunning,      // Program is executing
    dsStopped,      // Stopped at breakpoint or after step
    dsExited,       // Program exited
    dsError         // Error state
  );

  { TBreakpoint }
  TBreakpoint = record
    ID: Integer;            // DAP breakpoint ID
    FileName: string;       // Absolute path to source file
    LineNumber: Integer;    // Line number in source
    Verified: Boolean;      // Is breakpoint verified by debugger?
  end;

  { TStackFrame }
  TStackFrame = record
    ID: Integer;            // Frame ID for DAP
    FunctionName: string;   // Function/routine name
    FileName: string;       // Source file
    LineNumber: Integer;    // Line in source
  end;

  { TScope }
  TScope = record
    ScopeName: string;              // Scope name (e.g., "Locals", "Arguments")
    VariablesReference: Integer;    // Reference to get variables
    Expensive: Boolean;             // If true, might be slow to retrieve
  end;

  { TVariable }
  TVariable = record
    VarName: string;        // Variable name
    VarType: string;        // Type
    Value: string;          // Current value as string
    VariablesReference: Integer; // For nested structures
  end;

  { TThreadInfo }
  TThreadInfo = record
    ID: Integer;
    ThreadName: string;
  end;

  { Callback Types }
  TDebugErrorCallback = reference to procedure(const ASender: TObject; const AError: string);
  TDebugOutputCallback = reference to procedure(const ASender: TObject; const AOutput: string);
  TBreakpointHitCallback = reference to procedure(const ASender: TObject; const AFile: string; ALine: Integer);
  TStateChangeCallback = reference to procedure(const ASender: TObject; const AOldState, ANewState: TDebugState);

  { TDAPProcess }
  TDAPProcess = class
  private
    FProcessInfo: TProcessInformation;
    FStdInWrite: THandle;
    FStdOutRead: THandle;
    FStdErrRead: THandle;
    FRunning: Boolean;
    FExecutablePath: string;
    FWorkDir: string;

    function CreatePipePair(out AReadHandle, AWriteHandle: THandle): Boolean;
    function ReadBytes(const ACount: Integer; out AData: TBytes): Boolean;
    function ReadLine(out ALine: string): Boolean;

  public
    constructor Create(const AExecutable: string; const AWorkDir: string);
    destructor Destroy(); override;

    function Start(): Boolean;
    function HasDataAvailable(): Boolean;
    function ReadDAPMessage(out AJson: string): Boolean;
    procedure SendDAPMessage(const AJson: string);
    function IsRunning(): Boolean;
    procedure Terminate();

    property Running: Boolean read FRunning;
  end;

  { TMorDebug }
  TMorDebug = class(TBaseObject)
  private
    FDAPProcess: TDAPProcess;
    FLLDBDAPPath: string;
    FWorkDir: string;
    FState: TDebugState;
    FExecutablePath: string;
    FBreakpoints: TDictionary<string, TList<TBreakpoint>>;  // Key = filename
    FNextSeq: Integer;
    FLastError: string;
    FCurrentThreadID: Integer;
    FVerboseLogging: Boolean;
    FBreakpointFile: string;

    // Events
    FOnError: TDebugErrorCallback;
    FOnOutput: TDebugOutputCallback;
    FOnBreakpointHit: TBreakpointHitCallback;
    FOnStateChange: TStateChangeCallback;

    // Internal helpers
    procedure SetError(const AError: string);
    procedure SetState(const ANewState: TDebugState);
    function GetNextSeq(): Integer;
    function SendDAPRequest(const ACommand: string; const AArguments: TJSONObject): TJSONObject;
    procedure ProcessDAPEvent(const AEvent: TJSONObject);

    // JSON helpers
    function JsonEscape(const AText: string): string;
    function ParseDAPResponse(const AJson: string): TJSONObject;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Session management
    function Start(): Boolean;
    procedure Stop();
    procedure ResetForRelaunch();

    // Executable management
    function Initialize(): Boolean;
    function Launch(const AExePath: string; const AArguments: string = ''): Boolean;
    function ConfigurationDone(): Boolean;

    // Execution control
    function ContinueExecution(): Boolean;
    function StepInto(): Boolean;
    function StepOver(): Boolean;
    function StepOut(): Boolean;
    function Pause(): Boolean;
    function TerminateProcess(): Boolean;
    function Disconnect(): Boolean;

    // Breakpoint management
    function SetBreakpoint(const AFile: string; const ALine: Integer): Boolean;
    function SetBreakpoints(const AFile: string; const ALines: array of Integer): Boolean;
    function RemoveBreakpoint(const AFile: string; const ALine: Integer): Boolean;
    function ClearAllBreakpoints(): Boolean;
    function GetBreakpoints(const AFile: string): TArray<TBreakpoint>;
    function GetAllBreakpoints(): TArray<TBreakpoint>;

    // Inspection
    function GetThreads(): TArray<TThreadInfo>;
    function GetCallStack(const AThreadID: Integer): TArray<TStackFrame>;
    function GetScopes(const AFrameID: Integer): TArray<TScope>;
    function GetVariables(const AVariablesReference: Integer): TArray<TVariable>;
    function GetLocalVariables(const AFrameID: Integer): TArray<TVariable>;
    function EvaluateExpression(const AExpression: string; const AFrameID: Integer; out AResult: string; const AContext: string = 'watch'): Boolean;
    function GetCurrentLocation(out AFile: string; out ALine: Integer): Boolean;
    function GetSourceContext(const ALinesBefore: Integer = 2; const ALinesAfter: Integer = 2): string;

    function LoadBreakpointsFromFile(const AFilePath: string): Boolean;
    function SetBreakpointsFromFile(): Boolean;

    // State queries
    function HasError(): Boolean;
    function GetLastError(): string;
    procedure ProcessPendingEvents(const ATimeoutMS: Integer = 100);

    // Properties
    property State: TDebugState read FState;
    property LLDBDAPPath: string read FLLDBDAPPath write FLLDBDAPPath;
    property ExecutablePath: string read FExecutablePath;
    property CurrentThreadID: Integer read FCurrentThreadID;
    property VerboseLogging: Boolean read FVerboseLogging write FVerboseLogging;
    property BreakpointFile: string read FBreakpointFile write FBreakpointFile;

    // Events
    property OnError: TDebugErrorCallback read FOnError write FOnError;
    property OnOutput: TDebugOutputCallback read FOnOutput write FOnOutput;
    property OnBreakpointHit: TBreakpointHitCallback read FOnBreakpointHit write FOnBreakpointHit;
    property OnStateChange: TStateChangeCallback read FOnStateChange write FOnStateChange;
  end;

implementation

{ TDAPProcess }

constructor TDAPProcess.Create(const AExecutable: string; const AWorkDir: string);
begin
  inherited Create();

  FExecutablePath := AExecutable;
  FWorkDir := AWorkDir;
  FRunning := False;
  FStdInWrite := 0;
  FStdOutRead := 0;
  FStdErrRead := 0;
  ZeroMemory(@FProcessInfo, SizeOf(FProcessInfo));
end;

destructor TDAPProcess.Destroy();
begin
  Terminate();
  inherited;
end;

function TDAPProcess.CreatePipePair(out AReadHandle, AWriteHandle: THandle): Boolean;
var
  LSecurity: TSecurityAttributes;
begin
  LSecurity.nLength := SizeOf(TSecurityAttributes);
  LSecurity.bInheritHandle := True;
  LSecurity.lpSecurityDescriptor := nil;

  Result := CreatePipe(AReadHandle, AWriteHandle, @LSecurity, 0);
end;

function TDAPProcess.Start(): Boolean;
var
  LStdInRead: THandle;
  LStdOutWrite: THandle;
  LStdErrWrite: THandle;
  LStartupInfo: TStartupInfo;
  LCmdLine: string;
  LWorkDirPtr: PChar;
begin
  Result := False;

  if FRunning then
    Exit;

  if not TFile.Exists(FExecutablePath) then
    Exit;

  // Create pipes for stdin, stdout, stderr
  if not CreatePipePair(LStdInRead, FStdInWrite) then
    Exit;

  if not CreatePipePair(FStdOutRead, LStdOutWrite) then
  begin
    CloseHandle(LStdInRead);
    CloseHandle(FStdInWrite);
    Exit;
  end;

  if not CreatePipePair(FStdErrRead, LStdErrWrite) then
  begin
    CloseHandle(LStdInRead);
    CloseHandle(FStdInWrite);
    CloseHandle(FStdOutRead);
    CloseHandle(LStdOutWrite);
    Exit;
  end;

  // Setup startup info
  ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
  LStartupInfo.cb := SizeOf(LStartupInfo);
  LStartupInfo.hStdInput := LStdInRead;
  LStartupInfo.hStdOutput := LStdOutWrite;
  LStartupInfo.hStdError := LStdErrWrite;
  LStartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  LStartupInfo.wShowWindow := SW_HIDE;

  // Build command line
  LCmdLine := '"' + FExecutablePath + '"';
  UniqueString(LCmdLine);

  // Set working directory
  if FWorkDir <> '' then
    LWorkDirPtr := PChar(FWorkDir)
  else
    LWorkDirPtr := nil;

  // Create process
  if WinAPI.Windows.CreateProcess(
    PChar(FExecutablePath),
    PChar(LCmdLine),
    nil,
    nil,
    True,  // Inherit handles
    CREATE_NO_WINDOW,
    nil,
    LWorkDirPtr,
    LStartupInfo,
    FProcessInfo
  ) then
  begin
    FRunning := True;
    Result := True;
  end;

  // Close the child's ends of the pipes
  CloseHandle(LStdInRead);
  CloseHandle(LStdOutWrite);
  CloseHandle(LStdErrWrite);
end;

function TDAPProcess.HasDataAvailable(): Boolean;
var
  LBytesAvail: DWORD;
begin
  Result := PeekNamedPipe(FStdOutRead, nil, 0, nil, @LBytesAvail, nil) and (LBytesAvail > 0);
end;

function TDAPProcess.ReadBytes(const ACount: Integer; out AData: TBytes): Boolean;
var
  LRead: DWORD;
  LTotal: DWORD;
  LCountDW: DWORD;
begin
  Result := False;

  if ACount <= 0 then
    Exit;

  SetLength(AData, ACount);
  LTotal := 0;
  LCountDW := DWORD(ACount);

  while LTotal < LCountDW do
  begin
    if not ReadFile(FStdOutRead, AData[LTotal], LCountDW - LTotal, LRead, nil) or (LRead = 0) then
      Exit;
    Inc(LTotal, LRead);
  end;

  Result := True;
end;

function TDAPProcess.ReadLine(out ALine: string): Boolean;
var
  LBuf: AnsiChar;
  LBytesRead: DWORD;
  LAnsi: AnsiString;
begin
  Result := False;
  LAnsi := '';

  while True do
  begin
    if not ReadFile(FStdOutRead, LBuf, 1, LBytesRead, nil) or (LBytesRead = 0) then
      Exit;

    if LBuf = #10 then
      Break;

    if LBuf <> #13 then
      LAnsi := LAnsi + LBuf;
  end;

  ALine := string(LAnsi);
  Result := True;
end;

function TDAPProcess.ReadDAPMessage(out AJson: string): Boolean;
var
  LLine: string;
  LContentLen: Integer;
  LBody: TBytes;
begin
  Result := False;
  LContentLen := 0;

  // Read headers until blank line
  repeat
    if not ReadLine(LLine) then
      Exit;

    if LLine = '' then
      Break;

    if LLine.StartsWith('Content-Length:', True) then
      LContentLen := StrToIntDef(Trim(Copy(LLine, Length('Content-Length:') + 1, MaxInt)), 0);
  until False;

  if LContentLen <= 0 then
    Exit;

  // Read JSON body
  if not ReadBytes(LContentLen, LBody) then
    Exit;

  AJson := TEncoding.UTF8.GetString(LBody);
  Result := True;
end;

procedure TDAPProcess.SendDAPMessage(const AJson: string);
var
  LBody: TBytes;
  LHeader: AnsiString;
  LBytesWritten: DWORD;
begin
  if not FRunning then
    Exit;

  LBody := TEncoding.UTF8.GetBytes(AJson);
  LHeader := AnsiString(Format('Content-Length: %d'#13#10#13#10, [Length(LBody)]));

  WriteFile(FStdInWrite, LHeader[1], Length(LHeader), LBytesWritten, nil);
  if Length(LBody) > 0 then
    WriteFile(FStdInWrite, LBody[0], Length(LBody), LBytesWritten, nil);

  FlushFileBuffers(FStdInWrite);
end;

function TDAPProcess.IsRunning(): Boolean;
var
  LExitCode: DWORD;
begin
  if not FRunning then
    Exit(False);

  if GetExitCodeProcess(FProcessInfo.hProcess, LExitCode) then
    Result := (LExitCode = STILL_ACTIVE)
  else
    Result := False;

  if not Result then
    FRunning := False;
end;

procedure TDAPProcess.Terminate();
begin
  if not FRunning then
    Exit;

  // Force terminate
  if IsRunning() then
    WinAPI.Windows.TerminateProcess(FProcessInfo.hProcess, 0);

  // Close handles
  if FStdInWrite <> 0 then
  begin
    CloseHandle(FStdInWrite);
    FStdInWrite := 0;
  end;

  if FStdOutRead <> 0 then
  begin
    CloseHandle(FStdOutRead);
    FStdOutRead := 0;
  end;

  if FStdErrRead <> 0 then
  begin
    CloseHandle(FStdErrRead);
    FStdErrRead := 0;
  end;

  if FProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FProcessInfo.hProcess);
    CloseHandle(FProcessInfo.hThread);
    ZeroMemory(@FProcessInfo, SizeOf(FProcessInfo));
  end;

  FRunning := False;
end;

{ TMorDebug }

constructor TMorDebug.Create();
var
  LBase: string;
  LRelativePath: string;
begin
  inherited;

  // Build path to lldb-dap.exe
  LBase := TPath.GetDirectoryName(ParamStr(0));
  LRelativePath := TPath.Combine(
    LBase,
    TPath.Combine('res', TPath.Combine('lldb', TPath.Combine('bin', 'lldb-dap.exe')))
  );

  FLLDBDAPPath := TPath.GetFullPath(LRelativePath);
  FWorkDir := LBase;
  FState := dsNotStarted;
  FBreakpoints := TDictionary<string, TList<TBreakpoint>>.Create();
  FNextSeq := 0;
  FLastError := '';
  FCurrentThreadID := 0;
  FDAPProcess := nil;
  FVerboseLogging := False;
end;

destructor TMorDebug.Destroy();
var
  LKey: string;
begin
  Stop();

  // Free breakpoint lists
  for LKey in FBreakpoints.Keys do
    FBreakpoints[LKey].Free();

  FreeAndNil(FBreakpoints);
  inherited;
end;

procedure TMorDebug.SetError(const AError: string);
begin
  FLastError := AError;

  if Assigned(FOnError) then
    FOnError(Self, AError);
end;

procedure TMorDebug.SetState(const ANewState: TDebugState);
var
  LOldState: TDebugState;
begin
  if FState = ANewState then
    Exit;

  LOldState := FState;
  FState := ANewState;

  if Assigned(FOnStateChange) then
    FOnStateChange(Self, LOldState, ANewState);
end;

function TMorDebug.GetNextSeq(): Integer;
begin
  Inc(FNextSeq);
  Result := FNextSeq;
end;

function TMorDebug.JsonEscape(const AText: string): string;
var
  LI: Integer;
  LChar: Char;
begin
  Result := '';

  for LI := 1 to Length(AText) do
  begin
    LChar := AText[LI];

    case LChar of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      '/':  Result := Result + '\/';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
    else
      Result := Result + LChar;
    end;
  end;
end;

function TMorDebug.ParseDAPResponse(const AJson: string): TJSONObject;
begin
  try
    Result := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  except
    on E: Exception do
    begin
      SetError('Failed to parse DAP response: ' + E.Message);
      Result := nil;
    end;
  end;
end;

function TMorDebug.SendDAPRequest(const ACommand: string; const AArguments: TJSONObject): TJSONObject;
var
  LRequest: TJSONObject;
  LRequestJson: string;
  LResponseJson: string;
  LResponse: TJSONObject;
  LType: string;
  LSuccess: Boolean;
  LMessage: string;
begin
  Result := nil;

  if not Assigned(FDAPProcess) or not FDAPProcess.Running then
  begin
    SetError('DAP process not running');
    Exit;
  end;

  // Build DAP request
  LRequest := TJSONObject.Create();
  try
    LRequest.AddPair('seq', TJSONNumber.Create(GetNextSeq()));
    LRequest.AddPair('type', 'request');
    LRequest.AddPair('command', ACommand);

    if Assigned(AArguments) then
      LRequest.AddPair('arguments', AArguments);

    LRequestJson := LRequest.ToString();
    if FVerboseLogging then
      TUtils.PrintLn('[DAP] >> ' + LRequestJson);

    // Send request
    FDAPProcess.SendDAPMessage(LRequestJson);

  finally
    // Don't free AArguments - caller owns it or it's added to LRequest
    LRequest.Free();
  end;

  // Read response (and process any events along the way)
  while True do
  begin
    if not FDAPProcess.ReadDAPMessage(LResponseJson) then
    begin
      SetError('Failed to read DAP response');
      Exit;
    end;

    if FVerboseLogging then
      TUtils.PrintLn('[DAP] << ' + LResponseJson);

    LResponse := ParseDAPResponse(LResponseJson);
    if not Assigned(LResponse) then
      Exit;

    try
      LType := LResponse.GetValue<string>('type');

      if LType = 'event' then
      begin
        // Process event and continue waiting for response
        ProcessDAPEvent(LResponse);
        LResponse.Free();
        Continue;
      end
      else if LType = 'response' then
      begin
        // Check if successful
        LSuccess := LResponse.GetValue<Boolean>('success');

        if not LSuccess then
        begin
          LMessage := LResponse.GetValue<string>('message', 'Unknown error');
          SetError('DAP command failed: ' + LMessage);
          LResponse.Free();
          Exit;
        end;

        // Return the response body
        Result := LResponse;
        Exit;
      end;

    except
      on E: Exception do
      begin
        SetError('Error processing DAP response: ' + E.Message);
        LResponse.Free();
        Exit;
      end;
    end;
  end;
end;

procedure TMorDebug.ProcessDAPEvent(const AEvent: TJSONObject);
var
  LEventName: string;
  LBody: TJSONObject;
  LReason: string;
  LThreadID: Integer;
begin
  try
    LEventName := AEvent.GetValue<string>('event');

    if LEventName = 'stopped' then
    begin
      // Program stopped (breakpoint, step, pause)
      LBody := AEvent.GetValue<TJSONObject>('body');
      if Assigned(LBody) then
      begin
        LReason := LBody.GetValue<string>('reason', '');
        LThreadID := LBody.GetValue<Integer>('threadId', 0);
        FCurrentThreadID := LThreadID;

        SetState(dsStopped);

        TUtils.PrintLn(Format('[EVENT] Stopped: %s (thread %d)', [LReason, LThreadID]));
      end;
    end
    else if LEventName = 'continued' then
    begin
      SetState(dsRunning);
      TUtils.PrintLn('[EVENT] Continued');
    end
    else if LEventName = 'terminated' then
    begin
      SetState(dsExited);
      TUtils.PrintLn('[EVENT] Terminated');
    end
    else if LEventName = 'exited' then
    begin
      SetState(dsExited);
      LBody := AEvent.GetValue<TJSONObject>('body');
      if Assigned(LBody) then
        TUtils.PrintLn('[EVENT] Exited with code: ' + IntToStr(LBody.GetValue<Integer>('exitCode', 0)));
    end
    else if LEventName = 'output' then
    begin
      LBody := AEvent.GetValue<TJSONObject>('body');
      if Assigned(LBody) and Assigned(FOnOutput) then
        FOnOutput(Self, LBody.GetValue<string>('output', ''));
    end
    else if LEventName = 'initialized' then
    begin
      // Only transition to Ready if we're initializing
      if FState = dsInitializing then
        SetState(dsReady);
      TUtils.PrintLn('[EVENT] Initialized');
    end;

  except
    on E: Exception do
      TUtils.PrintLn('[ERROR] Processing event: ' + E.Message);
  end;
end;

function TMorDebug.Start(): Boolean;
begin
  Result := False;

  if FState <> dsNotStarted then
  begin
    SetError('DAP already started');
    Exit;
  end;

  if not TFile.Exists(FLLDBDAPPath) then
  begin
    SetError('LLDB-DAP not found: ' + FLLDBDAPPath);
    Exit;
  end;

  FDAPProcess := TDAPProcess.Create(FLLDBDAPPath, FWorkDir);

  if not FDAPProcess.Start() then
  begin
    SetError('Failed to start LLDB-DAP process');
    FreeAndNil(FDAPProcess);
    Exit;
  end;

  SetState(dsInitializing);
  Result := True;
end;

procedure TMorDebug.Stop();
var
  LKey: string;
begin
  if Assigned(FDAPProcess) then
  begin
    FDAPProcess.Terminate();
    FreeAndNil(FDAPProcess);
  end;

  for LKey in FBreakpoints.Keys do
    FBreakpoints[LKey].Free();
  FBreakpoints.Clear();
  SetState(dsNotStarted);
end;

procedure TMorDebug.ResetForRelaunch();
var
  LKey: string;
begin
  // Clear all internal state for relaunch
  // Note: Breakpoint lists are cleared, caller should save them externally first
  for LKey in FBreakpoints.Keys do
    FBreakpoints[LKey].Free();
  FBreakpoints.Clear();

  FCurrentThreadID := 0;
  FLastError := '';

  // Transition from Exited to Ready for relaunch
  if FState = dsExited then
    SetState(dsReady);
end;

function TMorDebug.Initialize(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  if FState <> dsInitializing then
  begin
    SetError('Cannot initialize: not in initializing state');
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('clientID', 'metamorf');
    LArgs.AddPair('adapterID', 'lldb');
    LArgs.AddPair('pathFormat', 'path');
    LArgs.AddPair('linesStartAt1', TJSONBool.Create(True));
    LArgs.AddPair('columnsStartAt1', TJSONBool.Create(True));

    LResponse := SendDAPRequest('initialize', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      SetState(dsReady);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Initialize failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.Launch(const AExePath: string; const AArguments: string): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LArgsArray: TJSONArray;
  LArgList: TStringList;
  LI: Integer;
  LExeDir: string;
begin
  Result := False;

  if not (FState in [dsReady, dsExited]) then
  begin
    SetError('Cannot launch: not ready or already running');
    Exit;
  end;

  if not TFile.Exists(AExePath) then
  begin
    SetError('Executable not found: ' + AExePath);
    Exit;
  end;

  FExecutablePath := AExePath;

  // Use executable's directory as working directory so PDB can be found
  LExeDir := TPath.GetDirectoryName(AExePath);

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('program', JsonEscape(AExePath));
    LArgs.AddPair('cwd', JsonEscape(LExeDir));
    LArgs.AddPair('stopOnEntry', TJSONBool.Create(False));

    if AArguments <> '' then
    begin
      LArgsArray := TJSONArray.Create();
      LArgList := TStringList.Create();
      try
        LArgList.Delimiter := ' ';
        LArgList.DelimitedText := AArguments;

        for LI := 0 to LArgList.Count - 1 do
          LArgsArray.Add(LArgList[LI]);

        LArgs.AddPair('args', LArgsArray);
      finally
        LArgList.Free();
      end;
    end;

    LResponse := SendDAPRequest('launch', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      SetState(dsLaunched);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Launch failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.ConfigurationDone(): Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;

  if not (FState in [dsLaunched, dsStopped]) then
  begin
    SetError('Cannot send configurationDone: not launched or stopped');
    Exit;
  end;

  LResponse := SendDAPRequest('configurationDone', nil);

  if Assigned(LResponse) then
  begin
    LResponse.Free();
    SetState(dsRunning);
    Result := True;
  end;
end;

function TMorDebug.ContinueExecution(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  if FState <> dsStopped then
  begin
    if FState <> dsReady then
      SetError(Format('Cannot continue: not stopped (current state: %d)', [Ord(FState)]));
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadID));

    LResponse := SendDAPRequest('continue', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      SetState(dsRunning);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Continue failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.StepOver(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  if FState <> dsStopped then
  begin
    SetError('Cannot step: not stopped');
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadID));

    LResponse := SendDAPRequest('next', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      SetState(dsRunning);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Step over failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.StepInto(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  if FState <> dsStopped then
  begin
    SetError('Cannot step: not stopped');
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadID));

    LResponse := SendDAPRequest('stepIn', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      SetState(dsRunning);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Step into failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.StepOut(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  if FState <> dsStopped then
  begin
    SetError('Cannot step: not stopped');
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadID));

    LResponse := SendDAPRequest('stepOut', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      SetState(dsRunning);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Step out failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.Pause(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  if FState <> dsRunning then
  begin
    SetError('Cannot pause: not running');
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('threadId', TJSONNumber.Create(FCurrentThreadID));

    LResponse := SendDAPRequest('pause', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Pause failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.TerminateProcess(): Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;

  if not (FState in [dsRunning, dsStopped, dsLaunched]) then
  begin
    SetError('No process to terminate');
    Exit;
  end;

  LResponse := SendDAPRequest('terminate', nil);

  if Assigned(LResponse) then
  begin
    LResponse.Free();
    Result := True;
  end;
end;

function TMorDebug.Disconnect(): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;

  if not (FState in [dsRunning, dsStopped, dsLaunched]) then
  begin
    Result := True;
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('terminateDebuggee', TJSONBool.Create(True));

    LResponse := SendDAPRequest('disconnect', LArgs);

    if Assigned(LResponse) then
    begin
      LResponse.Free();
      SetState(dsExited);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      SetError('Disconnect failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.SetBreakpoint(const AFile: string; const ALine: Integer): Boolean;
var
  LArgs: TJSONObject;
  LSource: TJSONObject;
  LBreakpointsArray: TJSONArray;
  LBreakpoint: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LResponseBreakpoints: TJSONArray;
  LResponseBP: TJSONObject;
  LBPRec: TBreakpoint;
  LList: TList<TBreakpoint>;
begin
  Result := False;

  if not (FState in [dsReady, dsLaunched, dsStopped]) then
  begin
    SetError('Cannot set breakpoint in current state');
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LSource := TJSONObject.Create();
    LSource.AddPair('path', JsonEscape(AFile));
    LArgs.AddPair('source', LSource);

    LBreakpointsArray := TJSONArray.Create();
    LBreakpoint := TJSONObject.Create();
    LBreakpoint.AddPair('line', TJSONNumber.Create(ALine));
    LBreakpointsArray.Add(LBreakpoint);
    LArgs.AddPair('breakpoints', LBreakpointsArray);

    LResponse := SendDAPRequest('setBreakpoints', LArgs);

    if Assigned(LResponse) then
    begin
      try
        LBody := LResponse.GetValue<TJSONObject>('body');
        if Assigned(LBody) then
        begin
          LResponseBreakpoints := LBody.GetValue<TJSONArray>('breakpoints');
          if Assigned(LResponseBreakpoints) and (LResponseBreakpoints.Count > 0) then
          begin
            LResponseBP := LResponseBreakpoints.Items[0] as TJSONObject;

            LBPRec.ID := LResponseBP.GetValue<Integer>('id', -1);
            LBPRec.FileName := AFile;
            LBPRec.LineNumber := ALine;
            LBPRec.Verified := LResponseBP.GetValue<Boolean>('verified', False);

            // Store breakpoint
            if not FBreakpoints.ContainsKey(AFile) then
              FBreakpoints.Add(AFile, TList<TBreakpoint>.Create());

            LList := FBreakpoints[AFile];
            LList.Add(LBPRec);

            Result := True;
          end;
        end;
      finally
        LResponse.Free();
      end;
    end;

  except
    on E: Exception do
    begin
      SetError('Set breakpoint failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.SetBreakpoints(const AFile: string; const ALines: array of Integer): Boolean;
var
  LArgs: TJSONObject;
  LSource: TJSONObject;
  LBreakpointsArray: TJSONArray;
  LBreakpoint: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LResponseBreakpoints: TJSONArray;
  LResponseBP: TJSONObject;
  LBPRec: TBreakpoint;
  LList: TList<TBreakpoint>;
  LI: Integer;
begin
  Result := False;

  if not (FState in [dsReady, dsLaunched, dsStopped]) then
  begin
    SetError('Cannot set breakpoints in current state');
    Exit;
  end;

  if Length(ALines) = 0 then
  begin
    SetError('No breakpoints provided');
    Exit;
  end;

  LArgs := TJSONObject.Create();
  try
    LSource := TJSONObject.Create();
    LSource.AddPair('path', JsonEscape(AFile));
    LArgs.AddPair('source', LSource);

    // Add ALL breakpoints for this file in ONE request
    LBreakpointsArray := TJSONArray.Create();
    for LI := 0 to High(ALines) do
    begin
      LBreakpoint := TJSONObject.Create();
      LBreakpoint.AddPair('line', TJSONNumber.Create(ALines[LI]));
      LBreakpointsArray.Add(LBreakpoint);
    end;
    LArgs.AddPair('breakpoints', LBreakpointsArray);

    LResponse := SendDAPRequest('setBreakpoints', LArgs);

    if Assigned(LResponse) then
    begin
      try
        LBody := LResponse.GetValue<TJSONObject>('body');
        if Assigned(LBody) then
        begin
          LResponseBreakpoints := LBody.GetValue<TJSONArray>('breakpoints');
          if Assigned(LResponseBreakpoints) and (LResponseBreakpoints.Count > 0) then
          begin
            // Create/get list for this file
            if not FBreakpoints.ContainsKey(AFile) then
              FBreakpoints.Add(AFile, TList<TBreakpoint>.Create());

            LList := FBreakpoints[AFile];
            LList.Clear(); // Clear existing breakpoints for this file

            // Store all breakpoints from response
            for LI := 0 to LResponseBreakpoints.Count - 1 do
            begin
              LResponseBP := LResponseBreakpoints.Items[LI] as TJSONObject;

              LBPRec.ID := LResponseBP.GetValue<Integer>('id', -1);
              LBPRec.FileName := AFile;
              LBPRec.LineNumber := LResponseBP.GetValue<Integer>('line', 0);
              LBPRec.Verified := LResponseBP.GetValue<Boolean>('verified', False);

              LList.Add(LBPRec);
            end;

            Result := True;
          end;
        end;
      finally
        LResponse.Free();
      end;
    end;

  except
    on E: Exception do
    begin
      SetError('Set breakpoints failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.RemoveBreakpoint(const AFile: string; const ALine: Integer): Boolean;
var
  LArgs: TJSONObject;
  LSource: TJSONObject;
  LBreakpointsArray: TJSONArray;
  LBreakpoint: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LResponseBreakpoints: TJSONArray;
  LResponseBP: TJSONObject;
  LList: TList<TBreakpoint>;
  LBP: TBreakpoint;
  LI: Integer;
  LBPRec: TBreakpoint;
begin
  Result := False;

  if not (FState in [dsReady, dsLaunched, dsStopped, dsExited]) then
  begin
    SetError('Cannot remove breakpoint in current state');
    Exit;
  end;

  // Check if we have breakpoints for this file
  if not FBreakpoints.ContainsKey(AFile) then
  begin
    SetError('No breakpoints set for file: ' + AFile);
    Exit;
  end;

  LList := FBreakpoints[AFile];

  // Find and remove the breakpoint from our internal list
  for LI := LList.Count - 1 downto 0 do
  begin
    if LList[LI].LineNumber = ALine then
    begin
      LList.Delete(LI);
      Break;
    end;
  end;

  // Build new breakpoint list for DAP (all remaining breakpoints for this file)
  LArgs := TJSONObject.Create();
  try
    LSource := TJSONObject.Create();
    LSource.AddPair('path', JsonEscape(AFile));
    LArgs.AddPair('source', LSource);

    LBreakpointsArray := TJSONArray.Create();
    for LBP in LList do
    begin
      LBreakpoint := TJSONObject.Create();
      LBreakpoint.AddPair('line', TJSONNumber.Create(LBP.LineNumber));
      LBreakpointsArray.Add(LBreakpoint);
    end;
    LArgs.AddPair('breakpoints', LBreakpointsArray);

    LResponse := SendDAPRequest('setBreakpoints', LArgs);

    if Assigned(LResponse) then
    begin
      try
        // Update our internal list with new IDs from response
        LList.Clear();

        LBody := LResponse.GetValue<TJSONObject>('body');
        if Assigned(LBody) then
        begin
          LResponseBreakpoints := LBody.GetValue<TJSONArray>('breakpoints');
          if Assigned(LResponseBreakpoints) then
          begin
            for LI := 0 to LResponseBreakpoints.Count - 1 do
            begin
              LResponseBP := LResponseBreakpoints.Items[LI] as TJSONObject;

              LBPRec.ID := LResponseBP.GetValue<Integer>('id', -1);
              LBPRec.FileName := AFile;
              LBPRec.LineNumber := LResponseBP.GetValue<Integer>('line', 0);
              LBPRec.Verified := LResponseBP.GetValue<Boolean>('verified', False);

              LList.Add(LBPRec);
            end;
          end;
        end;

        Result := True;
      finally
        LResponse.Free();
      end;
    end;

  except
    on E: Exception do
    begin
      SetError('Remove breakpoint failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.ClearAllBreakpoints(): Boolean;
var
  LKey: string;
begin
  for LKey in FBreakpoints.Keys do
    FBreakpoints[LKey].Free();
  FBreakpoints.Clear();
  Result := True;
end;

function TMorDebug.GetBreakpoints(const AFile: string): TArray<TBreakpoint>;
begin
  if FBreakpoints.ContainsKey(AFile) then
    Result := FBreakpoints[AFile].ToArray()
  else
    SetLength(Result, 0);
end;

function TMorDebug.GetAllBreakpoints(): TArray<TBreakpoint>;
var
  LKey: string;
  LList: TList<TBreakpoint>;
  LResult: TList<TBreakpoint>;
  LBP: TBreakpoint;
begin
  LResult := TList<TBreakpoint>.Create();
  try
    for LKey in FBreakpoints.Keys do
    begin
      LList := FBreakpoints[LKey];
      for LBP in LList do
        LResult.Add(LBP);
    end;

    Result := LResult.ToArray();
  finally
    LResult.Free();
  end;
end;

function TMorDebug.GetThreads(): TArray<TThreadInfo>;
var
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LThreadsArray: TJSONArray;
  LThread: TJSONObject;
  LList: TList<TThreadInfo>;
  LI: Integer;
  LThreadInfo: TThreadInfo;
begin
  SetLength(Result, 0);

  LResponse := SendDAPRequest('threads', nil);

  if Assigned(LResponse) then
  begin
    try
      LBody := LResponse.GetValue<TJSONObject>('body');
      if Assigned(LBody) then
      begin
        LThreadsArray := LBody.GetValue<TJSONArray>('threads');
        if Assigned(LThreadsArray) then
        begin
          LList := TList<TThreadInfo>.Create();
          try
            for LI := 0 to LThreadsArray.Count - 1 do
            begin
              LThread := LThreadsArray.Items[LI] as TJSONObject;
              LThreadInfo.ID := LThread.GetValue<Integer>('id', 0);
              LThreadInfo.ThreadName := LThread.GetValue<string>('name', '');
              LList.Add(LThreadInfo);
            end;

            Result := LList.ToArray();
          finally
            LList.Free();
          end;
        end;
      end;
    finally
      LResponse.Free();
    end;
  end;
end;

function TMorDebug.GetCallStack(const AThreadID: Integer): TArray<TStackFrame>;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LFramesArray: TJSONArray;
  LFrame: TJSONObject;
  LSource: TJSONObject;
  LList: TList<TStackFrame>;
  LI: Integer;
  LFrameRec: TStackFrame;
begin
  SetLength(Result, 0);

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('threadId', TJSONNumber.Create(AThreadID));

    LResponse := SendDAPRequest('stackTrace', LArgs);

    if Assigned(LResponse) then
    begin
      try
        LBody := LResponse.GetValue<TJSONObject>('body');
        if Assigned(LBody) then
        begin
          LFramesArray := LBody.GetValue<TJSONArray>('stackFrames');
          if Assigned(LFramesArray) then
          begin
            LList := TList<TStackFrame>.Create();
            try
              for LI := 0 to LFramesArray.Count - 1 do
              begin
                LFrame := LFramesArray.Items[LI] as TJSONObject;

                LFrameRec.ID := LFrame.GetValue<Integer>('id', 0);
                LFrameRec.FunctionName := LFrame.GetValue<string>('name', '');
                LFrameRec.LineNumber := LFrame.GetValue<Integer>('line', 0);

                LSource := LFrame.GetValue<TJSONObject>('source');
                if Assigned(LSource) then
                  LFrameRec.FileName := LSource.GetValue<string>('path', '');

                LList.Add(LFrameRec);
              end;

              Result := LList.ToArray();
            finally
              LList.Free();
            end;
          end;
        end;
      finally
        LResponse.Free();
      end;
    end;

  except
    on E: Exception do
    begin
      SetError('Get call stack failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.GetScopes(const AFrameID: Integer): TArray<TScope>;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LScopesArray: TJSONArray;
  LScopeObj: TJSONObject;
  LList: TList<TScope>;
  LI: Integer;
  LScopeRec: TScope;
begin
  SetLength(Result, 0);

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('frameId', TJSONNumber.Create(AFrameID));

    LResponse := SendDAPRequest('scopes', LArgs);

    if Assigned(LResponse) then
    begin
      try
        LBody := LResponse.GetValue<TJSONObject>('body');
        if Assigned(LBody) then
        begin
          LScopesArray := LBody.GetValue<TJSONArray>('scopes');
          if Assigned(LScopesArray) then
          begin
            LList := TList<TScope>.Create();
            try
              for LI := 0 to LScopesArray.Count - 1 do
              begin
                LScopeObj := LScopesArray.Items[LI] as TJSONObject;

                LScopeRec.ScopeName := LScopeObj.GetValue<string>('name', '');
                LScopeRec.VariablesReference := LScopeObj.GetValue<Integer>('variablesReference', 0);
                LScopeRec.Expensive := LScopeObj.GetValue<Boolean>('expensive', False);

                LList.Add(LScopeRec);
              end;

              Result := LList.ToArray();
            finally
              LList.Free();
            end;
          end;
        end;
      finally
        LResponse.Free();
      end;
    end;

  except
    on E: Exception do
    begin
      SetError('Get scopes failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.GetVariables(const AVariablesReference: Integer): TArray<TVariable>;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LVariablesArray: TJSONArray;
  LVarObj: TJSONObject;
  LList: TList<TVariable>;
  LI: Integer;
  LVarRec: TVariable;
begin
  SetLength(Result, 0);

  if AVariablesReference = 0 then
    Exit;  // 0 means no variables

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('variablesReference', TJSONNumber.Create(AVariablesReference));

    LResponse := SendDAPRequest('variables', LArgs);

    if Assigned(LResponse) then
    begin
      try
        LBody := LResponse.GetValue<TJSONObject>('body');
        if Assigned(LBody) then
        begin
          LVariablesArray := LBody.GetValue<TJSONArray>('variables');
          if Assigned(LVariablesArray) then
          begin
            LList := TList<TVariable>.Create();
            try
              for LI := 0 to LVariablesArray.Count - 1 do
              begin
                LVarObj := LVariablesArray.Items[LI] as TJSONObject;

                LVarRec.VarName := LVarObj.GetValue<string>('name', '');
                LVarRec.Value := LVarObj.GetValue<string>('value', '');
                LVarRec.VarType := LVarObj.GetValue<string>('type', '');
                LVarRec.VariablesReference := LVarObj.GetValue<Integer>('variablesReference', 0);

                LList.Add(LVarRec);
              end;

              Result := LList.ToArray();
            finally
              LList.Free();
            end;
          end;
        end;
      finally
        LResponse.Free();
      end;
    end;

  except
    on E: Exception do
    begin
      SetError('Get variables failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.GetLocalVariables(const AFrameID: Integer): TArray<TVariable>;
var
  LScopes: TArray<TScope>;
  LScope: TScope;
  LVars: TArray<TVariable>;
  LResult: TList<TVariable>;
  LVar: TVariable;
begin
  // Get all scopes for the frame
  LScopes := GetScopes(AFrameID);

  LResult := TList<TVariable>.Create();
  try
    // Collect variables from all scopes
    for LScope in LScopes do
    begin
      if LScope.VariablesReference > 0 then
      begin
        LVars := GetVariables(LScope.VariablesReference);
        for LVar in LVars do
          LResult.Add(LVar);
      end;
    end;

    Result := LResult.ToArray();
  finally
    LResult.Free();
  end;
end;

function TMorDebug.EvaluateExpression(const AExpression: string; const AFrameID: Integer; out AResult: string; const AContext: string): Boolean;
var
  LArgs: TJSONObject;
  LResponse: TJSONObject;
  LBody: TJSONObject;
begin
  Result := False;
  AResult := '';

  LArgs := TJSONObject.Create();
  try
    LArgs.AddPair('expression', JsonEscape(AExpression));
    LArgs.AddPair('frameId', TJSONNumber.Create(AFrameID));
    LArgs.AddPair('context', AContext);

    LResponse := SendDAPRequest('evaluate', LArgs);

    if Assigned(LResponse) then
    begin
      try
        LBody := LResponse.GetValue<TJSONObject>('body');
        if Assigned(LBody) then
        begin
          AResult := LBody.GetValue<string>('result', '');
          Result := True;
        end;
      finally
        LResponse.Free();
      end;
    end;

  except
    on E: Exception do
    begin
      SetError('Evaluate failed: ' + E.Message);
      LArgs.Free();
    end;
  end;
end;

function TMorDebug.HasError(): Boolean;
begin
  Result := FLastError <> '';
end;

function TMorDebug.GetLastError(): string;
begin
  Result := FLastError;
end;

function TMorDebug.GetCurrentLocation(out AFile: string; out ALine: Integer): Boolean;
var
  LStack: TArray<TStackFrame>;
begin
  Result := False;
  AFile := '';
  ALine := 0;

  if FState <> dsStopped then
    Exit;

  LStack := GetCallStack(FCurrentThreadID);
  if Length(LStack) > 0 then
  begin
    AFile := LStack[0].FileName;
    ALine := LStack[0].LineNumber;
    Result := True;
  end;
end;

function TMorDebug.GetSourceContext(const ALinesBefore: Integer; const ALinesAfter: Integer): string;
var
  LStack: TArray<TStackFrame>;
  LCommand: string;
  LRawOutput: string;
  LLines: TStringList;
  LCurrentLine: Integer;
  LI: Integer;
  LLine: string;
  LLineNum: Integer;
  LPos: Integer;
  LLineNumStr: string;
begin
  Result := '';

  if FState <> dsStopped then
  begin
    SetError('Cannot get source context: not stopped');
    Exit;
  end;

  // Get current stack frame
  LStack := GetCallStack(FCurrentThreadID);
  if Length(LStack) = 0 then
  begin
    SetError('No stack frames available');
    Exit;
  end;

  LCurrentLine := LStack[0].LineNumber;

  // Use LLDB's source list command through evaluate
  LCommand := Format('source list -l %d -c %d', [LCurrentLine - ALinesBefore, ALinesBefore + 1 + ALinesAfter]);

  if not EvaluateExpression(LCommand, LStack[0].ID, LRawOutput, 'repl') then
    Exit;

  // Parse output and highlight current line
  LLines := TStringList.Create();
  try
    LLines.Text := LRawOutput;

    for LI := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[LI];

      // Skip empty lines
      if Trim(LLine) = '' then
        Continue;

      // Try to extract line number from start of line
      LPos := 1;
      while (LPos <= Length(LLine)) and (LLine[LPos] = ' ') do
        Inc(LPos);

      // Extract line number
      LLineNumStr := '';
      while (LPos <= Length(LLine)) and CharInSet(LLine[LPos], ['0'..'9']) do
      begin
        LLineNumStr := LLineNumStr + LLine[LPos];
        Inc(LPos);
      end;

      if TryStrToInt(LLineNumStr, LLineNum) then
      begin
        // Replace tabs with spaces for consistent formatting
        LLine := LLine.Replace(#9, '  ', [rfReplaceAll]);

        // Add leading space to all lines for consistent formatting
        LLine := ' ' + LLine;

        // Check if this is the current line
        if LLineNum = LCurrentLine then
        begin
          // Replace leading spaces with arrow: " -> "
          LLine[2] := '-';
          LLine[3] := '>';

          // Color the entire line (auto-reset handled by PrintLn)
          Result := Result + COLOR_YELLOW + LLine + #13#10;
        end
        else
        begin
          // Regular line: keep as-is
          Result := Result + LLine + #13#10;
        end;
      end
      else
      begin
        // Not a source line (maybe header/footer), just include it
        Result := Result + LLine + #13#10;
      end;
    end;

    Result := TrimRight(Result);

  finally
    LLines.Free();
  end;
end;

procedure TMorDebug.ProcessPendingEvents(const ATimeoutMS: Integer);
var
  LStartTime: Cardinal;
  LMessageJson: string;
  LMessage: TJSONObject;
  LType: string;
begin
  if not Assigned(FDAPProcess) or not FDAPProcess.Running then
    Exit;

  LStartTime := GetTickCount();

  while (GetTickCount() - LStartTime) < DWORD(ATimeoutMS) do
  begin
    if FDAPProcess.HasDataAvailable() then
    begin
      if FDAPProcess.ReadDAPMessage(LMessageJson) then
      begin
        if FVerboseLogging then
          TUtils.PrintLn('[DAP] << ' + LMessageJson);

        LMessage := ParseDAPResponse(LMessageJson);
        if Assigned(LMessage) then
        begin
          try
            LType := LMessage.GetValue<string>('type');

            if LType = 'event' then
              ProcessDAPEvent(LMessage);

          finally
            LMessage.Free();
          end;
        end;
      end;
    end
    else
    begin
      // No data available - check state before sleeping
      if (FState in [dsStopped, dsExited]) and ((GetTickCount() - LStartTime) > 100) then
        Break;

      Sleep(1);
    end;
  end;
end;

function TMorDebug.LoadBreakpointsFromFile(const AFilePath: string): Boolean;
var
  LConfig: TConfig;
  LCount: Integer;
  LI: Integer;
  LFile: string;
  LLine: Integer;
  LBreakpointsByFile: TDictionary<string, TList<Integer>>;
  LLinesList: TList<Integer>;
  LLinesArray: TArray<Integer>;
  LKey: string;
  LExeDir: string;
  LExpandedFile: string;
begin
  Result := False;

  if not TFile.Exists(AFilePath) then
  begin
    SetError('Breakpoint file not found: ' + AFilePath);
    Exit;
  end;

  // Get executable directory for expanding relative paths
  LExeDir := TPath.GetDirectoryName(ParamStr(0));

  LBreakpointsByFile := TDictionary<string, TList<Integer>>.Create();
  try
    LConfig := TConfig.Create();
    try
      if not LConfig.LoadFromFile(AFilePath) then
      begin
        SetError('Failed to parse breakpoints file: ' + LConfig.GetLastError());
        Exit;
      end;

      LCount := LConfig.GetTableCount('breakpoints');
      if LCount = 0 then
        Exit;

      TUtils.PrintLn(Format('Loading %d breakpoint(s)...', [LCount]));

      // Group breakpoints by file
      for LI := 0 to LCount - 1 do
      begin
        LFile := LConfig.GetTableString('breakpoints', LI, 'file');
        LLine := LConfig.GetTableInteger('breakpoints', LI, 'line');

        // Expand relative paths to absolute paths
        if not TPath.IsPathRooted(LFile) then
          LExpandedFile := TPath.GetFullPath(TPath.Combine(LExeDir, LFile))
        else
          LExpandedFile := LFile;

        if not LBreakpointsByFile.ContainsKey(LExpandedFile) then
          LBreakpointsByFile.Add(LExpandedFile, TList<Integer>.Create());

        LBreakpointsByFile[LExpandedFile].Add(LLine);
      end;

      // Set breakpoints per file (ONE request per file with ALL lines)
      for LKey in LBreakpointsByFile.Keys do
      begin
        LLinesList := LBreakpointsByFile[LKey];
        LLinesArray := LLinesList.ToArray();

        if SetBreakpoints(LKey, LLinesArray) then
        begin
          for LLine in LLinesArray do
            TUtils.PrintLn(COLOR_GREEN + Format('  Breakpoint at %s:%d',
                                                [ExtractFileName(LKey), LLine]));
        end
        else
          TUtils.PrintLn(COLOR_YELLOW + Format('  Warning: Failed to set breakpoints for %s',
                                              [ExtractFileName(LKey)]));
      end;

      Result := True;
    finally
      LConfig.Free();
    end;
  finally
    // Free all lists in dictionary
    for LLinesList in LBreakpointsByFile.Values do
      LLinesList.Free();
    LBreakpointsByFile.Free();
  end;
end;

function TMorDebug.SetBreakpointsFromFile(): Boolean;
begin
  Result := False;

  if FBreakpointFile = '' then
    Exit;

  Result := LoadBreakpointsFromFile(FBreakpointFile);
end;

end.
