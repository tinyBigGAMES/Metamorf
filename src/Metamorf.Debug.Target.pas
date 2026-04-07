{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug.Target;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Metamorf.Utils;

const
  // x64 trap flag (bit 8 of RFLAGS)
  MOR_TRAP_FLAG = $100;

  // INT3 opcode
  MOR_INT3_OPCODE = $CC;

type

  { TMorDebugStopReason }
  TMorDebugStopReason = (
    dsrNone,
    dsrBreakpoint,       // Hit an INT3 breakpoint
    dsrSingleStep,       // Completed a single-step (trap flag)
    dsrException,        // Unhandled exception in debuggee
    dsrProcessExit,      // Debuggee process exited
    dsrDllLoad           // Target DLL loaded (DLL debug mode)
  );

  { TMorDebugStopEvent }
  TMorDebugStopEvent = record
    Reason: TMorDebugStopReason;
    Address: UInt64;          // Address where stop occurred
    ThreadId: DWORD;
    ExitCode: Cardinal;       // Valid when Reason = dsrProcessExit
    ExceptionCode: Cardinal;  // Valid when Reason = dsrException
    ExceptionMessage: string; // Human-readable exception description
  end;

  { TMorResumeAction }
  TMorResumeAction = (
    raContinue,       // Resume normal execution
    raStepOver,       // Step to next source line (same function)
    raStepIn,         // Step into function call
    raStepOut         // Step out of current function
  );

  { TMorDebugTarget }
  TMorDebugTarget = class(TMorErrorsObject)
  protected
    FBreakOnExceptions: Boolean;
  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Memory operations
    function ReadByte(const AAddress: UInt64): Byte; virtual; abstract;
    procedure WriteByte(const AAddress: UInt64; const AValue: Byte); virtual; abstract;
    function ReadUInt64(const AAddress: UInt64): UInt64; virtual; abstract;
    function ReadBytes(const AAddress: UInt64; const ASize: Cardinal): TBytes; virtual;
    procedure FlushCode(const AAddress: UInt64; const ASize: Cardinal); virtual; abstract;

    // Execution control
    procedure Resume(); virtual; abstract;
    procedure SetTrapFlag(); virtual; abstract;
    procedure ClearTrapFlag(); virtual; abstract;

    // Thread context (captured at stop point)
    function GetContext(): TContext; virtual; abstract;
    procedure SetContext(const AContext: TContext); virtual; abstract;

    // Address queries
    function IsOurCode(const AAddress: UInt64): Boolean; virtual; abstract;

    // Single-step re-patch tracking (default: no-op / returns -1)
    // In PDB model, stores absolute virtual address (not code offset)
    procedure SetRepatchOffset(const AOffset: Int64); virtual;
    function GetRepatchOffset(): Int64; virtual;

    // Configuration done signal (default: no-op)
    // PE target overrides to unblock the process held at initial breakpoint
    procedure SignalConfigDone(); virtual;

    // Wait until target is ready for breakpoint patching (default: no-op)
    procedure WaitUntilReady(); virtual;

    // Unblock WaitForStop during shutdown (default: no-op)
    procedure UnblockWaitForStop(); virtual;

    // Lifecycle
    function Start(): Boolean; virtual; abstract;
    procedure Stop(); virtual; abstract;
    function WaitForStop(out AEvent: TMorDebugStopEvent): Boolean; virtual; abstract;
    function IsRunning(): Boolean; virtual; abstract;

    // Exception handling
    procedure SetBreakOnExceptions(const AEnabled: Boolean);
    function GetBreakOnExceptions(): Boolean;
  end;

  { TMorPEDebugTarget }
  TMorPEDebugTarget = class;

  { TMorPEDebugLoopThread }
  TMorPEDebugLoopThread = class(TThread)
  private
    FTarget: TMorPEDebugTarget;
    function IsTargetDll(const AEvent: TDebugEvent): Boolean;
  protected
    procedure Execute(); override;
  public
    constructor Create(const ATarget: TMorPEDebugTarget);
  end;

  { TPEDebugTarget }
  TMorPEDebugTarget = class(TMorDebugTarget)
  private
    FExePath: string;
    FProcessHandle: THandle;
    FMainThreadHandle: THandle;
    FProcessId: DWORD;
    FMainThreadId: DWORD;
    FActualImageBase: UInt64;
    FTextSectionRVA: Cardinal;
    FTextSectionSize: Cardinal;
    FStoppedEvent: THandle;
    FResumeEvent: THandle;
    FCapturedContext: TContext;
    FStoppedReason: TMorDebugStopReason;
    FStoppedAddress: UInt64;
    FStoppedThreadId: DWORD;
    FExceptionCode: Cardinal;
    FStarted: Boolean;
    FExitCode: Cardinal;
    FInitialBreakpointSeen: Boolean;
    FRepatchOffset: Int64;
    FConfigDoneEvent: THandle;
    FReadyEvent: THandle;
    FLaunchDoneEvent: THandle;
    FLaunchPath: string;
    FLaunchSucceeded: Boolean;
    FDebugLoopThread: TMorPEDebugLoopThread;

    // DLL debugging fields
    FDllPath: string;                  // Target DLL we're debugging
    FHostExePath: string;              // Host EXE that loads the DLL
    FIsAttachedToDll: Boolean;         // True = DLL mode, False = EXE mode
    FDllBaseAddress: UInt64;           // Actual load address of target DLL
    FDllFound: Boolean;                // Set when target DLL detected

    // Read .text section RVA and size from PE headers in debuggee memory
    procedure ReadTextSectionFromPE();

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Setup
    procedure SetExePath(const APath: string);
    procedure SetDllMode(const ADllPath: string; const AHostExePath: string);

    // Memory (via ReadProcessMemory/WriteProcessMemory)
    function ReadByte(const AAddress: UInt64): Byte; override;
    procedure WriteByte(const AAddress: UInt64; const AValue: Byte); override;
    function ReadUInt64(const AAddress: UInt64): UInt64; override;
    procedure FlushCode(const AAddress: UInt64; const ASize: Cardinal); override;

    // Execution control
    procedure Resume(); override;
    procedure SetTrapFlag(); override;
    procedure ClearTrapFlag(); override;

    // Context
    function GetContext(): TContext; override;
    procedure SetContext(const AContext: TContext); override;

    // Address queries
    function IsOurCode(const AAddress: UInt64): Boolean; override;

    // Lifecycle
    function Start(): Boolean; override;
    procedure Stop(); override;
    function WaitForStop(out AEvent: TMorDebugStopEvent): Boolean; override;
    function IsRunning(): Boolean; override;

    // Re-patch tracking
    procedure SetRepatchOffset(const AOffset: Int64); override;
    function GetRepatchOffset(): Int64; override;

    // Configuration done - releases process held at initial breakpoint
    procedure SignalConfigDone(); override;

    // Wait until debug loop has reached initial breakpoint
    procedure WaitUntilReady(); override;

    // Unblock stop watcher during shutdown
    procedure UnblockWaitForStop(); override;

    // Properties
    property ProcessHandle: THandle read FProcessHandle;
    property MainThreadHandle: THandle read FMainThreadHandle;
    property ExitCodeValue: Cardinal read FExitCode;
    property TextSectionRVA: Cardinal read FTextSectionRVA;
    property TextSectionSize: Cardinal read FTextSectionSize;
    property ActualImageBase: UInt64 read FActualImageBase;
    property DllBaseAddress: UInt64 read FDllBaseAddress;
    property DllFound: Boolean read FDllFound;
    property IsAttachedToDll: Boolean read FIsAttachedToDll;
  end;

implementation

const
  EXCEPTION_BREAKPOINT  = DWORD($80000003);
  EXCEPTION_SINGLE_STEP = DWORD($80000004);

//==============================================================================
// TDebugTarget - Base
//==============================================================================

constructor TMorDebugTarget.Create();
begin
  inherited Create();
  FBreakOnExceptions := False;
end;

destructor TMorDebugTarget.Destroy();
begin
  inherited Destroy();
end;

function TMorDebugTarget.ReadBytes(const AAddress: UInt64;
  const ASize: Cardinal): TBytes;
var
  LI: Cardinal;
begin
  SetLength(Result, ASize);
  for LI := 0 to ASize - 1 do
    Result[LI] := ReadByte(AAddress + LI);
end;

procedure TMorDebugTarget.SetRepatchOffset(const AOffset: Int64);
begin
  // Default no-op
end;

function TMorDebugTarget.GetRepatchOffset(): Int64;
begin
  Result := -1;
end;

procedure TMorDebugTarget.SignalConfigDone();
begin
  // Default no-op
end;

procedure TMorDebugTarget.WaitUntilReady();
begin
  // Default no-op
end;

procedure TMorDebugTarget.UnblockWaitForStop();
begin
  // Default no-op
end;

procedure TMorDebugTarget.SetBreakOnExceptions(const AEnabled: Boolean);
begin
  FBreakOnExceptions := AEnabled;
end;

function TMorDebugTarget.GetBreakOnExceptions(): Boolean;
begin
  Result := FBreakOnExceptions;
end;

//==============================================================================
// TPEDebugLoopThread
//==============================================================================

constructor TMorPEDebugLoopThread.Create(const ATarget: TMorPEDebugTarget);
begin
  inherited Create(True);  // Create suspended
  FreeOnTerminate := False;
  FTarget := ATarget;
end;

function TMorPEDebugLoopThread.IsTargetDll(
  const AEvent: TDebugEvent): Boolean;
var
  LNamePtr: Pointer;
  LNameBuf: array[0..259] of Word;
  LBytesRead: NativeUInt;
  LDllName: string;
  LTargetName: string;
begin
  Result := False;

  // Get pointer to DLL name string from the debug event
  LNamePtr := AEvent.LoadDll.lpImageName;
  if LNamePtr = nil then
    Exit;

  // The lpImageName field is a pointer-to-a-pointer in the debuggee's memory
  if not ReadProcessMemory(FTarget.FProcessHandle,
    LNamePtr, @LNamePtr, SizeOf(Pointer), LBytesRead) then
    Exit;

  if LNamePtr = nil then
    Exit;

  // Read the actual name string
  FillChar(LNameBuf, SizeOf(LNameBuf), 0);
  if not ReadProcessMemory(FTarget.FProcessHandle,
    LNamePtr, @LNameBuf[0], 520, LBytesRead) then
    Exit;

  // fUnicode flag indicates whether name is Unicode or ANSI
  if AEvent.LoadDll.fUnicode <> 0 then
    LDllName := PWideChar(@LNameBuf[0])
  else
    LDllName := string(PAnsiChar(@LNameBuf[0]));

  if LDllName = '' then
    Exit;

  // Compare filename portion (case-insensitive)
  LTargetName := ExtractFileName(FTarget.FDllPath);
  Result := SameText(ExtractFileName(LDllName), LTargetName);
end;

procedure TMorPEDebugLoopThread.Execute();
var
  LEvent: TDebugEvent;
  LContinueStatus: DWORD;
  LExCode: DWORD;
  LExAddr: UInt64;
  LContext: TContext;
  LRepatch: Int64;
  LSI: TStartupInfoW;
  LPI: TProcessInformation;
begin
  // CreateProcessW MUST be called on the same thread as WaitForDebugEvent
  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  FillChar(LPI, SizeOf(LPI), 0);

  if not CreateProcessW(
    PWideChar(FTarget.FLaunchPath),
    nil,
    nil, nil,
    False,
    DEBUG_ONLY_THIS_PROCESS or CREATE_UNICODE_ENVIRONMENT,
    nil,
    PWideChar(ExtractFilePath(FTarget.FLaunchPath)),
    LSI, LPI) then
  begin
    FTarget.FLaunchSucceeded := False;
    SetEvent(FTarget.FLaunchDoneEvent);
    Exit;
  end;

  FTarget.FProcessHandle := LPI.hProcess;
  FTarget.FMainThreadHandle := LPI.hThread;
  FTarget.FProcessId := LPI.dwProcessId;
  FTarget.FMainThreadId := LPI.dwThreadId;
  FTarget.FLaunchSucceeded := True;
  SetEvent(FTarget.FLaunchDoneEvent);

  while not Terminated do
  begin
    // Use a timeout so we can check Terminated periodically
    if not WaitForDebugEvent(LEvent, 200) then
      Continue;

    LContinueStatus := DBG_CONTINUE;

    case LEvent.dwDebugEventCode of
      CREATE_PROCESS_DEBUG_EVENT:
      begin
        // Capture actual image base (handles ASLR)
        FTarget.FActualImageBase :=
          UInt64(LEvent.CreateProcessInfo.lpBaseOfImage);
        FTarget.FProcessHandle := LEvent.CreateProcessInfo.hProcess;
        FTarget.FMainThreadHandle := LEvent.CreateProcessInfo.hThread;
        FTarget.FMainThreadId := LEvent.dwThreadId;

        // Close the image file handle (we don't need it)
        if LEvent.CreateProcessInfo.hFile <> 0 then
          CloseHandle(LEvent.CreateProcessInfo.hFile);
      end;

      EXCEPTION_DEBUG_EVENT:
      begin
        LExCode := LEvent.Exception.ExceptionRecord.ExceptionCode;
        LExAddr := UInt64(LEvent.Exception.ExceptionRecord.ExceptionAddress);

        if LExCode = EXCEPTION_BREAKPOINT then
        begin
          // Skip the initial loader breakpoint from ntdll
          if not FTarget.FInitialBreakpointSeen then
          begin
            FTarget.FInitialBreakpointSeen := True;

            // Read .text section info from PE headers now that process is loaded
            FTarget.ReadTextSectionFromPE();

            // Signal that we're ready for breakpoint patching
            SetEvent(FTarget.FReadyEvent);

            // Hold the process until configurationDone arrives
            WaitForSingleObject(FTarget.FConfigDoneEvent, INFINITE);

            if Terminated then
            begin
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Continue;
          end;

          // Check if this is within our code
          if FTarget.IsOurCode(LExAddr) then
          begin
            // Capture thread context
            FillChar(LContext, SizeOf(LContext), 0);
            LContext.ContextFlags := CONTEXT_FULL;
            GetThreadContext(FTarget.FMainThreadHandle, LContext);

            // INT3 advances RIP past 0xCC - back up by 1
            Dec(LContext.Rip);
            SetThreadContext(FTarget.FMainThreadHandle, LContext);

            FTarget.FCapturedContext := LContext;
            FTarget.FStoppedReason := dsrBreakpoint;
            FTarget.FStoppedAddress := LContext.Rip;
            FTarget.FStoppedThreadId := LEvent.dwThreadId;

            // Signal DAP thread that we stopped
            SetEvent(FTarget.FStoppedEvent);

            // Block until DAP tells us what to do
            WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

            if Terminated then
            begin
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;

            // Apply any context modifications (trap flag, RIP changes)
            SetThreadContext(FTarget.FMainThreadHandle,
              FTarget.FCapturedContext);

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Continue;
          end
          else
          begin
            // Not our breakpoint - let the process handle it
            LContinueStatus := DBG_EXCEPTION_NOT_HANDLED;
          end;
        end
        else if LExCode = EXCEPTION_SINGLE_STEP then
        begin
          // Re-patch breakpoint if we were stepping past one
          LRepatch := FTarget.FRepatchOffset;
          if LRepatch >= 0 then
          begin
            // Repatch uses absolute address (FRepatchOffset stores address)
            FTarget.WriteByte(UInt64(LRepatch), MOR_INT3_OPCODE);
            FTarget.FlushCode(UInt64(LRepatch), 1);
            FTarget.FRepatchOffset := -1;

            // Internal re-patch step - clear trap flag and resume silently
            FillChar(LContext, SizeOf(LContext), 0);
            LContext.ContextFlags := CONTEXT_FULL;
            GetThreadContext(FTarget.FMainThreadHandle, LContext);
            LContext.EFlags := LContext.EFlags and (not MOR_TRAP_FLAG);
            SetThreadContext(FTarget.FMainThreadHandle, LContext);

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Continue;
          end;

          // User-requested single step - report to DAP
          FillChar(LContext, SizeOf(LContext), 0);
          LContext.ContextFlags := CONTEXT_FULL;
          GetThreadContext(FTarget.FMainThreadHandle, LContext);

          // Clear trap flag
          LContext.EFlags := LContext.EFlags and (not MOR_TRAP_FLAG);
          SetThreadContext(FTarget.FMainThreadHandle, LContext);

          FTarget.FCapturedContext := LContext;
          FTarget.FStoppedReason := dsrSingleStep;
          FTarget.FStoppedAddress := LContext.Rip;
          FTarget.FStoppedThreadId := LEvent.dwThreadId;

          // Signal DAP thread
          SetEvent(FTarget.FStoppedEvent);

          // Block until DAP tells us what to do
          WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

          if Terminated then
          begin
            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Break;
          end;

          // Apply context
          SetThreadContext(FTarget.FMainThreadHandle,
            FTarget.FCapturedContext);

          ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
            DBG_CONTINUE);
          Continue;
        end
        else
        begin
          // Other exceptions - break into debugger if enabled
          if FTarget.FBreakOnExceptions and FTarget.IsOurCode(LExAddr) then
          begin
            FillChar(LContext, SizeOf(LContext), 0);
            LContext.ContextFlags := CONTEXT_FULL;
            GetThreadContext(FTarget.FMainThreadHandle, LContext);

            FTarget.FCapturedContext := LContext;
            FTarget.FStoppedReason := dsrException;
            FTarget.FStoppedAddress := LExAddr;
            FTarget.FStoppedThreadId := LEvent.dwThreadId;
            FTarget.FExceptionCode := LExCode;

            SetEvent(FTarget.FStoppedEvent);
            WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

            if Terminated then
            begin
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;

            SetThreadContext(FTarget.FMainThreadHandle,
              FTarget.FCapturedContext);

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_EXCEPTION_NOT_HANDLED);
            Continue;
          end
          else if LEvent.Exception.dwFirstChance = 1 then
            LContinueStatus := DBG_EXCEPTION_NOT_HANDLED;
        end;
      end;

      LOAD_DLL_DEBUG_EVENT:
      begin
        // Check if this is our target DLL (only in DLL debug mode)
        if FTarget.FIsAttachedToDll and (not FTarget.FDllFound) then
        begin
          if IsTargetDll(LEvent) then
          begin
            FTarget.FDllBaseAddress :=
              UInt64(LEvent.LoadDll.lpBaseOfDll);
            FTarget.FDllFound := True;

            // Signal the runtime so it can apply breakpoints
            FTarget.FStoppedReason := dsrDllLoad;
            FTarget.FStoppedAddress := 0;
            FTarget.FStoppedThreadId := LEvent.dwThreadId;

            SetEvent(FTarget.FStoppedEvent);

            // Block until runtime has applied breakpoints and tells us to go
            WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

            if Terminated then
            begin
              if LEvent.LoadDll.hFile <> 0 then
                CloseHandle(LEvent.LoadDll.hFile);
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;
          end;
        end;

        // Close the DLL file handle
        if LEvent.LoadDll.hFile <> 0 then
          CloseHandle(LEvent.LoadDll.hFile);
      end;

      EXIT_PROCESS_DEBUG_EVENT:
      begin
        FTarget.FExitCode := LEvent.ExitProcess.dwExitCode;
        FTarget.FStoppedReason := dsrProcessExit;
        FTarget.FStoppedAddress := 0;
        FTarget.FStarted := False;

        // Signal DAP thread that the process has exited
        SetEvent(FTarget.FStoppedEvent);

        ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
          DBG_CONTINUE);
        Break;
      end;
    end;

    ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
      LContinueStatus);
  end;
end;

//==============================================================================
// TPEDebugTarget
//==============================================================================

constructor TMorPEDebugTarget.Create();
begin
  inherited Create();
  FExePath := '';
  FProcessHandle := 0;
  FMainThreadHandle := 0;
  FProcessId := 0;
  FMainThreadId := 0;
  FActualImageBase := 0;
  FTextSectionRVA := 0;
  FTextSectionSize := 0;
  FStoppedEvent := 0;
  FResumeEvent := 0;
  FillChar(FCapturedContext, SizeOf(FCapturedContext), 0);
  FStoppedReason := dsrNone;
  FStoppedAddress := 0;
  FStoppedThreadId := 0;
  FStarted := False;
  FExitCode := 0;
  FExceptionCode := 0;
  FInitialBreakpointSeen := False;
  FRepatchOffset := -1;
  FConfigDoneEvent := 0;
  FReadyEvent := 0;
  FLaunchDoneEvent := 0;
  FLaunchPath := '';
  FLaunchSucceeded := False;
  FDebugLoopThread := nil;
  FDllPath := '';
  FHostExePath := '';
  FIsAttachedToDll := False;
  FDllBaseAddress := 0;
  FDllFound := False;
end;

destructor TMorPEDebugTarget.Destroy();
begin
  Stop();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Setup
//------------------------------------------------------------------------------

procedure TMorPEDebugTarget.SetExePath(const APath: string);
begin
  FExePath := APath;
end;

procedure TMorPEDebugTarget.SetDllMode(const ADllPath: string;
  const AHostExePath: string);
begin
  FDllPath := ADllPath;
  FHostExePath := AHostExePath;
  FIsAttachedToDll := True;
  FDllBaseAddress := 0;
  FDllFound := False;
end;

//------------------------------------------------------------------------------
// ReadTextSectionFromPE - Read .text RVA and size from PE headers
//------------------------------------------------------------------------------

procedure TMorPEDebugTarget.ReadTextSectionFromPE();
var
  LDosHeader: IMAGE_DOS_HEADER;
  LNTHeaders: IMAGE_NT_HEADERS64;
  LSectionHeader: IMAGE_SECTION_HEADER;
  LBytesRead: NativeUInt;
  LI: Integer;
  LSectionOffset: UInt64;
  LSectionName: AnsiString;
begin
  FTextSectionRVA := 0;
  FTextSectionSize := 0;

  // Read DOS header from debuggee memory
  if not ReadProcessMemory(FProcessHandle, Pointer(FActualImageBase),
    @LDosHeader, SizeOf(LDosHeader), LBytesRead) then
    Exit;

  // Read NT headers
  if not ReadProcessMemory(FProcessHandle,
    Pointer(FActualImageBase + UInt64(LDosHeader._lfanew)),
    @LNTHeaders, SizeOf(LNTHeaders), LBytesRead) then
    Exit;

  // Walk section headers to find .text
  LSectionOffset := FActualImageBase + UInt64(LDosHeader._lfanew)
    + SizeOf(DWORD) + SizeOf(IMAGE_FILE_HEADER)
    + LNTHeaders.FileHeader.SizeOfOptionalHeader;

  for LI := 0 to LNTHeaders.FileHeader.NumberOfSections - 1 do
  begin
    if not ReadProcessMemory(FProcessHandle, Pointer(LSectionOffset),
      @LSectionHeader, SizeOf(LSectionHeader), LBytesRead) then
      Break;

    SetString(LSectionName, PAnsiChar(@LSectionHeader.Name[0]), 5);
    if LSectionName = '.text' then
    begin
      FTextSectionRVA := LSectionHeader.VirtualAddress;
      FTextSectionSize := LSectionHeader.Misc.VirtualSize;
      Break;
    end;

    LSectionOffset := LSectionOffset + SizeOf(IMAGE_SECTION_HEADER);
  end;
end;

//------------------------------------------------------------------------------
// Lifecycle
//------------------------------------------------------------------------------

function TMorPEDebugTarget.Start(): Boolean;
begin
  Result := False;

  // In DLL mode, we launch the host EXE (not the DLL itself)
  if FIsAttachedToDll then
  begin
    if FHostExePath = '' then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG010',
          'Host EXE path not set for DLL debugging');
      Exit;
    end;
    if not FileExists(FHostExePath) then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG011',
          'Host EXE not found: %s', [FHostExePath]);
      Exit;
    end;
    FLaunchPath := FHostExePath;
  end
  else
  begin
    if FExePath = '' then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG010', 'EXE path not set before Start()');
      Exit;
    end;
    if not FileExists(FExePath) then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG011', 'EXE not found: %s', [FExePath]);
      Exit;
    end;
    FLaunchPath := FExePath;
  end;

  // Store launch path for the debug loop thread
  FLaunchSucceeded := False;

  // Create synchronization events
  FStoppedEvent := CreateEvent(nil, False, False, nil);     // Auto-reset
  FResumeEvent := CreateEvent(nil, False, False, nil);      // Auto-reset
  FConfigDoneEvent := CreateEvent(nil, True, False, nil);   // Manual-reset
  FReadyEvent := CreateEvent(nil, True, False, nil);        // Manual-reset
  FLaunchDoneEvent := CreateEvent(nil, True, False, nil);   // Manual-reset

  if (FStoppedEvent = 0) or (FResumeEvent = 0) or
     (FConfigDoneEvent = 0) or (FReadyEvent = 0) or
     (FLaunchDoneEvent = 0) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DBG012', 'Failed to create synchronization events');
    Exit;
  end;

  FInitialBreakpointSeen := False;

  // Start the debug loop thread (CreateProcessW must be on same thread
  // as WaitForDebugEvent per Windows Debug API requirement)
  FDebugLoopThread := TMorPEDebugLoopThread.Create(Self);
  FDebugLoopThread.Start();

  // Wait for the thread to finish launching the process
  WaitForSingleObject(FLaunchDoneEvent, INFINITE);

  if not FLaunchSucceeded then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DBG013', 'Debug loop failed to launch process');
    Exit;
  end;

  FStarted := True;
  Result := True;
end;

procedure TMorPEDebugTarget.Stop();
begin
  // Always clean up the debug loop thread, even if the process already exited
  // (EXIT_PROCESS_DEBUG_EVENT sets FStarted := False before we get here)
  if FDebugLoopThread <> nil then
  begin
    FDebugLoopThread.Terminate();
    if FConfigDoneEvent <> 0 then
      SetEvent(FConfigDoneEvent);
    if FReadyEvent <> 0 then
      SetEvent(FReadyEvent);
    if FLaunchDoneEvent <> 0 then
      SetEvent(FLaunchDoneEvent);
    if FResumeEvent <> 0 then
      SetEvent(FResumeEvent);
    FDebugLoopThread.WaitFor();
    FreeAndNil(FDebugLoopThread);
  end;

  if not FStarted then
  begin
    // Process already exited -- skip termination, still close handles below
  end
  else
  begin
    FStarted := False;

    // Terminate the debuggee process if still running
    if FProcessHandle <> 0 then
    begin
      TerminateProcess(FProcessHandle, 1);
    end;
  end;

  if FProcessHandle <> 0 then
  begin
    CloseHandle(FProcessHandle);
    FProcessHandle := 0;
  end;

  if FMainThreadHandle <> 0 then
  begin
    CloseHandle(FMainThreadHandle);
    FMainThreadHandle := 0;
  end;

  // Close events
  if FStoppedEvent <> 0 then
  begin
    CloseHandle(FStoppedEvent);
    FStoppedEvent := 0;
  end;
  if FResumeEvent <> 0 then
  begin
    CloseHandle(FResumeEvent);
    FResumeEvent := 0;
  end;
  if FConfigDoneEvent <> 0 then
  begin
    CloseHandle(FConfigDoneEvent);
    FConfigDoneEvent := 0;
  end;
  if FReadyEvent <> 0 then
  begin
    CloseHandle(FReadyEvent);
    FReadyEvent := 0;
  end;
  if FLaunchDoneEvent <> 0 then
  begin
    CloseHandle(FLaunchDoneEvent);
    FLaunchDoneEvent := 0;
  end;
end;

function TMorPEDebugTarget.IsRunning(): Boolean;
begin
  Result := FStarted;
end;

function TMorPEDebugTarget.WaitForStop(out AEvent: TMorDebugStopEvent): Boolean;
begin
  // Block until the debug loop thread signals a stop
  Result := WaitForSingleObject(FStoppedEvent, INFINITE) = WAIT_OBJECT_0;
  if Result then
  begin
    AEvent.Reason := FStoppedReason;
    AEvent.Address := FStoppedAddress;
    AEvent.ThreadId := FStoppedThreadId;
    AEvent.ExitCode := FExitCode;
    AEvent.ExceptionCode := FExceptionCode;
    if FStoppedReason = dsrException then
      AEvent.ExceptionMessage := Format('Exception 0x%x at 0x%x',
        [FExceptionCode, FStoppedAddress])
    else
      AEvent.ExceptionMessage := '';
  end;
end;

//------------------------------------------------------------------------------
// Execution Control
//------------------------------------------------------------------------------

procedure TMorPEDebugTarget.Resume();
begin
  SetEvent(FResumeEvent);
end;

procedure TMorPEDebugTarget.SetTrapFlag();
begin
  FCapturedContext.EFlags := FCapturedContext.EFlags or MOR_TRAP_FLAG;
end;

procedure TMorPEDebugTarget.ClearTrapFlag();
begin
  FCapturedContext.EFlags := FCapturedContext.EFlags and (not MOR_TRAP_FLAG);
end;

//------------------------------------------------------------------------------
// Memory Operations (via ReadProcessMemory / WriteProcessMemory)
//------------------------------------------------------------------------------

function TMorPEDebugTarget.ReadByte(const AAddress: UInt64): Byte;
var
  LBytesRead: NativeUInt;
begin
  Result := 0;
  if not ReadProcessMemory(FProcessHandle, Pointer(AAddress),
    @Result, 1, LBytesRead) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, 'DBG020',
        'ReadProcessMemory failed at $%x: %s',
        [AAddress, SysErrorMessage(GetLastError())]);
  end;
end;

procedure TMorPEDebugTarget.WriteByte(const AAddress: UInt64;
  const AValue: Byte);
var
  LBytesWritten: NativeUInt;
begin
  if not WriteProcessMemory(FProcessHandle, Pointer(AAddress),
    @AValue, 1, LBytesWritten) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, 'DBG021',
        'WriteProcessMemory failed at $%x: %s',
        [AAddress, SysErrorMessage(GetLastError())]);
  end;
end;

function TMorPEDebugTarget.ReadUInt64(const AAddress: UInt64): UInt64;
var
  LBytesRead: NativeUInt;
begin
  Result := 0;
  if not ReadProcessMemory(FProcessHandle, Pointer(AAddress),
    @Result, 8, LBytesRead) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, 'DBG022',
        'ReadProcessMemory (UInt64) failed at $%x: %s',
        [AAddress, SysErrorMessage(GetLastError())]);
  end;
end;

procedure TMorPEDebugTarget.FlushCode(const AAddress: UInt64;
  const ASize: Cardinal);
begin
  FlushInstructionCache(FProcessHandle, Pointer(AAddress), ASize);
end;

//------------------------------------------------------------------------------
// Thread Context
//------------------------------------------------------------------------------

function TMorPEDebugTarget.GetContext(): TContext;
begin
  Result := FCapturedContext;
end;

procedure TMorPEDebugTarget.SetContext(const AContext: TContext);
begin
  FCapturedContext := AContext;
end;

//------------------------------------------------------------------------------
// Address Queries
//------------------------------------------------------------------------------

function TMorPEDebugTarget.IsOurCode(const AAddress: UInt64): Boolean;
var
  LTextStart: UInt64;
begin
  LTextStart := FActualImageBase + UInt64(FTextSectionRVA);

  // If we know the .text size, use it for precise bounds
  if FTextSectionSize > 0 then
    Result := (AAddress >= LTextStart) and
              (AAddress < LTextStart + UInt64(FTextSectionSize))
  else
    // Without size info, check within a reasonable range (16 MB)
    Result := (AAddress >= LTextStart) and
              (AAddress < LTextStart + $1000000);
end;

//------------------------------------------------------------------------------
// Re-patch tracking
//------------------------------------------------------------------------------

procedure TMorPEDebugTarget.SetRepatchOffset(const AOffset: Int64);
begin
  FRepatchOffset := AOffset;
end;

function TMorPEDebugTarget.GetRepatchOffset(): Int64;
begin
  Result := FRepatchOffset;
end;

procedure TMorPEDebugTarget.SignalConfigDone();
begin
  if FConfigDoneEvent <> 0 then
    SetEvent(FConfigDoneEvent);
end;

procedure TMorPEDebugTarget.WaitUntilReady();
begin
  // Wait for the debug loop thread to process CREATE_PROCESS_DEBUG_EVENT
  // and reach the initial breakpoint (where ReadTextSectionFromPE runs)
  if FReadyEvent <> 0 then
    WaitForSingleObject(FReadyEvent, 10000);
end;

procedure TMorPEDebugTarget.UnblockWaitForStop();
begin
  if FStoppedEvent <> 0 then
    SetEvent(FStoppedEvent);
end;

end.
