{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug.Server;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Debug.PDB,
  Metamorf.Debug.Target,
  Metamorf.Debug.Runtime,
  Metamorf.Debug.DAP;

type
  //============================================================================
  // TDebugMode - Which output mode we're debugging
  //============================================================================
  TDebugMode = (
    dmExe,     // Out-of-process EXE debugging
    dmDll      // Out-of-process DLL debugging
  );

  TMetamorfDebugServer = class;

  //============================================================================
  // TDAPListenerThread - Runs the DAP message loop on a background thread
  //============================================================================

  { TDAPListenerThread }
  TDAPListenerThread = class(TThread)
  private
    FServer: TDAPServer;
  protected
    procedure Execute(); override;
  public
    constructor Create(const AServer: TDAPServer);
  end;

  //============================================================================
  // TStopWatcherThread - Waits for debug stops and notifies DAP server
  //============================================================================

  { TStopWatcherThread }
  TStopWatcherThread = class(TThread)
  private
    FDebugger: TMetamorfDebugServer;
  protected
    procedure Execute(); override;
  public
    constructor Create(const ADebugger: TMetamorfDebugServer);
  end;

  //============================================================================
  // TMetamorfDebugServer - Public API for the Metamorf debugger.
  // Owns TErrors, creates and wires all debug components.
  // Entry points for EXE and DLL debugging.
  //============================================================================

  { TMetamorfDebugServer }
  TMetamorfDebugServer = class(TStatusObject)
  private
    FErrors: TErrors;
    FSourceMap: TPDBSourceMap;
    FTarget: TDebugTarget;
    FRuntime: TDebugRuntime;
    FDAPServer: TDAPServer;
    FDAPThread: TDAPListenerThread;
    FStopWatcher: TStopWatcherThread;
    FPort: Integer;
    FMode: TDebugMode;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // EXE debugging: pass EXE path, loads PDB sidecar automatically
    function DebugExe(const AExePath: string;
      const APort: Integer = 4711): Boolean;

    // DLL debugging: pass DLL path and host EXE
    function DebugDll(const ADllPath: string;
      const AHostExe: string;
      const APort: Integer = 4711): Boolean;

    // Shutdown
    procedure StopDebugging();

    // Error reporting -- delegates to FErrors
    function HasErrors(): Boolean;
    function HasWarnings(): Boolean;
    function HasFatal(): Boolean;
    function ErrorCount(): Integer;
    function WarningCount(): Integer;
    function GetErrorItems(): TList<TError>;
    function GetErrorText(): string;

    // Access to internals (for advanced use)
    function GetRuntime(): TDebugRuntime;
    function GetDAPServer(): TDAPServer;
    function GetSourceMap(): TPDBSourceMap;

    // Properties
    property Port: Integer read FPort;
    property Mode: TDebugMode read FMode;
  end;

implementation

//==============================================================================
// TDAPListenerThread
//==============================================================================

constructor TDAPListenerThread.Create(const AServer: TDAPServer);
begin
  inherited Create(True);  // Create suspended
  FreeOnTerminate := False;
  FServer := AServer;
end;

procedure TDAPListenerThread.Execute();
begin
  FServer.RunMessageLoop();
end;

//==============================================================================
// TStopWatcherThread -- waits for runtime stops, notifies DAP
//==============================================================================

constructor TStopWatcherThread.Create(const ADebugger: TMetamorfDebugServer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FDebugger := ADebugger;
end;

procedure TStopWatcherThread.Execute();
begin
  while not Terminated do
  begin
    // Block until the debug runtime reports a stop
    if FDebugger.FRuntime.WaitForStop() then
    begin
      if Terminated then
        Break;
      // Notify the DAP server about the stop
      FDebugger.FDAPServer.ProcessStopEvent();
    end
    else
      Break;  // WaitForStop failed -- target gone
  end;
end;

//==============================================================================
// TMetamorfDebugServer
//==============================================================================

constructor TMetamorfDebugServer.Create();
begin
  inherited Create();
  FErrors := TErrors.Create();
  FSourceMap := nil;
  FTarget := nil;
  FRuntime := nil;
  FDAPServer := nil;
  FDAPThread := nil;
  FStopWatcher := nil;
  FPort := 0;
  FMode := dmExe;
end;

destructor TMetamorfDebugServer.Destroy();
begin
  StopDebugging();
  FErrors.Free();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// DebugExe -- PE EXE mode entry point
//------------------------------------------------------------------------------

function TMetamorfDebugServer.DebugExe(const AExePath: string;
  const APort: Integer): Boolean;
var
  LPETarget: TPEDebugTarget;
  LPDBPath: string;
begin
  Result := False;
  FPort := APort;
  FMode := dmExe;

  // Validate EXE exists
  if not FileExists(AExePath) then
  begin
    FErrors.Add(esError, 'DBG200', 'EXE not found: %s', [AExePath]);
    Exit;
  end;

  // Derive PDB path from EXE path
  LPDBPath := ChangeFileExt(AExePath, '.pdb');
  if not FileExists(LPDBPath) then
  begin
    FErrors.Add(esError, 'DBG202',
      'PDB debug info not found: %s -- rebuild with debug mode enabled',
      [LPDBPath]);
    Exit;
  end;

  // Create PE debug target
  LPETarget := TPEDebugTarget.Create();
  LPETarget.SetErrors(FErrors);
  LPETarget.SetExePath(AExePath);
  FTarget := LPETarget;

  // Create debug runtime (breakpoints, stepping, stack walker)
  FRuntime := TDebugRuntime.Create();
  FRuntime.SetErrors(FErrors);
  FRuntime.SetTarget(FTarget);

  // Create PDB source map (initialized after process launch)
  FSourceMap := TPDBSourceMap.Create();

  // Create DAP server
  FDAPServer := TDAPServer.Create();
  FDAPServer.SetErrors(FErrors);
  FDAPServer.SetRuntime(FRuntime);
  FDAPServer.SetSourceMap(FSourceMap);

  // Start TCP listener
  if not FDAPServer.StartListening(APort) then
  begin
    FErrors.Add(esFatal, 'DBG100',
      'Failed to start DAP server on port %d', [APort]);
    Exit;
  end;

  Status('DAP server listening on port %d -- attach your debugger', [APort]);

  // Wait for client connection (blocking)
  if not FDAPServer.WaitForConnection() then
  begin
    FErrors.Add(esFatal, 'DBG101', 'No client connected');
    Exit;
  end;

  Status('Debugger client connected');

  // Start the PE debug target (launches the process with DEBUG_ONLY_THIS_PROCESS)
  if not FTarget.Start() then
  begin
    FErrors.Add(esFatal, 'DBG102', 'Failed to start debug target');
    Exit;
  end;

  Status('Debuggee launched: %s', [AExePath]);

  // Start DAP message loop on background thread (must be running before
  // WaitUntilReady/PDB init so client can complete DAP handshake)
  FDAPThread := TDAPListenerThread.Create(FDAPServer);
  FDAPThread.Start();

  // Start stop watcher thread (bridges runtime stops -> DAP events)
  FStopWatcher := TStopWatcherThread.Create(Self);
  FStopWatcher.Start();

  // Wait for initial breakpoint so process handle is valid
  FTarget.WaitUntilReady();

  // Initialize PDB source map with the live process handle
  if not FSourceMap.Initialize(LPETarget.ProcessHandle, AExePath, LPDBPath,
    LPETarget.ActualImageBase) then
  begin
    FErrors.Add(esFatal, 'DBG103', 'Failed to initialize PDB: %s', [LPDBPath]);
    Exit;
  end;

  // Now wire source map into runtime (deferred until PDB is loaded)
  FRuntime.SetSourceMap(FSourceMap);

  Status('Debug session active -- waiting for configurationDone');
  Result := True;
end;

//------------------------------------------------------------------------------
// DebugDll -- DLL mode entry point
//------------------------------------------------------------------------------

function TMetamorfDebugServer.DebugDll(const ADllPath: string;
  const AHostExe: string; const APort: Integer): Boolean;
var
  LPETarget: TPEDebugTarget;
  LPDBPath: string;
begin
  Result := False;
  FPort := APort;
  FMode := dmDll;

  // Validate DLL exists
  if not FileExists(ADllPath) then
  begin
    FErrors.Add(esError, 'DBG200', 'DLL not found: %s', [ADllPath]);
    Exit;
  end;

  // Validate host EXE is provided and exists
  if AHostExe = '' then
  begin
    FErrors.Add(esError, 'DBG204',
      'Host EXE required for DLL debugging');
    Exit;
  end;

  if not FileExists(AHostExe) then
  begin
    FErrors.Add(esError, 'DBG205', 'Host EXE not found: %s', [AHostExe]);
    Exit;
  end;

  // Derive PDB path from DLL path
  LPDBPath := ChangeFileExt(ADllPath, '.pdb');
  if not FileExists(LPDBPath) then
  begin
    FErrors.Add(esError, 'DBG202',
      'PDB debug info not found: %s -- rebuild with debug mode enabled',
      [LPDBPath]);
    Exit;
  end;

  // Create PE debug target in DLL mode
  LPETarget := TPEDebugTarget.Create();
  LPETarget.SetErrors(FErrors);
  LPETarget.SetDllMode(ADllPath, AHostExe);
  FTarget := LPETarget;

  // Create debug runtime (breakpoints, stepping, stack walker)
  FRuntime := TDebugRuntime.Create();
  FRuntime.SetErrors(FErrors);
  FRuntime.SetTarget(FTarget);

  // Create PDB source map (initialized after process launch)
  FSourceMap := TPDBSourceMap.Create();

  // Create DAP server
  FDAPServer := TDAPServer.Create();
  FDAPServer.SetErrors(FErrors);
  FDAPServer.SetRuntime(FRuntime);
  FDAPServer.SetSourceMap(FSourceMap);

  // Start TCP listener
  if not FDAPServer.StartListening(APort) then
  begin
    FErrors.Add(esFatal, 'DBG100',
      'Failed to start DAP server on port %d', [APort]);
    Exit;
  end;

  Status('DAP server listening on port %d -- attach your debugger', [APort]);

  // Wait for client connection (blocking)
  if not FDAPServer.WaitForConnection() then
  begin
    FErrors.Add(esFatal, 'DBG101', 'No client connected');
    Exit;
  end;

  Status('Debugger client connected');

  // Start the PE debug target (launches the host EXE with DEBUG_ONLY_THIS_PROCESS)
  if not FTarget.Start() then
  begin
    FErrors.Add(esFatal, 'DBG102', 'Failed to start debug target');
    Exit;
  end;

  Status('Host launched: %s -- waiting for DLL: %s',
    [AHostExe, ExtractFileName(ADllPath)]);

  // Start DAP message loop on background thread (must be running before
  // WaitUntilReady/PDB init so client can complete DAP handshake)
  FDAPThread := TDAPListenerThread.Create(FDAPServer);
  FDAPThread.Start();

  // Start stop watcher thread (bridges runtime stops -> DAP events)
  // The runtime handles dsrDllLoad internally (applies breakpoints + resumes)
  FStopWatcher := TStopWatcherThread.Create(Self);
  FStopWatcher.Start();

  // Wait for initial breakpoint so process handle is valid
  FTarget.WaitUntilReady();

  // Initialize PDB source map with the live process handle
  if not FSourceMap.Initialize(LPETarget.ProcessHandle, ADllPath, LPDBPath,
    LPETarget.ActualImageBase) then
  begin
    FErrors.Add(esFatal, 'DBG103', 'Failed to initialize PDB: %s', [LPDBPath]);
    Exit;
  end;

  // Now wire source map into runtime (deferred until PDB is loaded)
  FRuntime.SetSourceMap(FSourceMap);

  Status('Debug session active -- waiting for configurationDone');
  Result := True;
end;

//------------------------------------------------------------------------------
// Shutdown
//------------------------------------------------------------------------------

procedure TMetamorfDebugServer.StopDebugging();
begin
  // Stop watcher thread first (it reads from runtime)
  if FStopWatcher <> nil then
  begin
    FStopWatcher.Terminate();
    // Signal FStoppedEvent so WaitForStop unblocks
    if FTarget <> nil then
      FTarget.UnblockWaitForStop();
    FStopWatcher.WaitFor();
    FreeAndNil(FStopWatcher);
  end;

  // Close sockets first -- this causes recv() in the DAP thread to return -1,
  // which makes ReadMessage return nil, which exits RunMessageLoop
  if FDAPServer <> nil then
    FDAPServer.StopServer();

  // Now the DAP thread can be safely joined
  if FDAPThread <> nil then
  begin
    FDAPThread.Terminate();
    FDAPThread.WaitFor();
    FreeAndNil(FDAPThread);
  end;

  // Free the DAP server object (sockets already closed above)
  FreeAndNil(FDAPServer);

  // Stop runtime (removes breakpoints)
  FreeAndNil(FRuntime);

  // Cleanup PDB source map before target stop
  if FSourceMap <> nil then
  begin
    FSourceMap.Cleanup();
    FreeAndNil(FSourceMap);
  end;

  // Stop target (terminates process)
  if FTarget <> nil then
  begin
    FTarget.Stop();
    FreeAndNil(FTarget);
  end;
end;

//------------------------------------------------------------------------------
// Error Reporting -- delegates to FErrors
//------------------------------------------------------------------------------

function TMetamorfDebugServer.HasErrors(): Boolean;
begin
  Result := FErrors.HasErrors();
end;

function TMetamorfDebugServer.HasWarnings(): Boolean;
begin
  Result := FErrors.HasWarnings();
end;

function TMetamorfDebugServer.HasFatal(): Boolean;
begin
  Result := FErrors.HasFatal();
end;

function TMetamorfDebugServer.ErrorCount(): Integer;
begin
  Result := FErrors.ErrorCount();
end;

function TMetamorfDebugServer.WarningCount(): Integer;
begin
  Result := FErrors.WarningCount();
end;

function TMetamorfDebugServer.GetErrorItems(): TList<TError>;
begin
  Result := FErrors.GetItems();
end;

function TMetamorfDebugServer.GetErrorText(): string;
begin
  Result := FErrors.Dump();
end;

//------------------------------------------------------------------------------
// Accessors
//------------------------------------------------------------------------------

function TMetamorfDebugServer.GetRuntime(): TDebugRuntime;
begin
  Result := FRuntime;
end;

function TMetamorfDebugServer.GetDAPServer(): TDAPServer;
begin
  Result := FDAPServer;
end;

function TMetamorfDebugServer.GetSourceMap(): TPDBSourceMap;
begin
  Result := FSourceMap;
end;

end.
