{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug.Runtime;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Debug.PDB,
  Metamorf.Debug.Target;

type
  { TMorBreakpointInfo }
  TMorBreakpointInfo = record
    ID: Integer;
    SourceFile: string;
    SourceLine: Integer;
    Address: UInt64;              // Absolute virtual address in debuggee
    OriginalByte: Byte;
    IsTemporary: Boolean;         // Auto-removed on hit (used for stepping)
    IsEnabled: Boolean;
    IsPatched: Boolean;           // True when INT3 is actually written
    HitCount: Integer;
    Condition: string;            // Expression to evaluate; empty = unconditional
    HitCondition: Integer;        // Break only when HitCount >= this value (0 = ignore)
  end;

  { TMorDebugStackFrame }
  TMorDebugStackFrame = record
    FrameID: Integer;
    FunctionName: string;
    SourceFile: string;
    SourceLine: Integer;
    SourceColumn: Integer;
    Address: UInt64;
    RBP: UInt64;
    RIP: UInt64;
  end;

  { TMorBreakpointManager }
  TMorBreakpointManager = class(TMorErrorsObject)
  private
    FTarget: TMorDebugTarget;         // Reference (not owned)
    FSourceMap: TMorPDBSourceMap;     // Reference (not owned)
    FBreakpoints: TList<TMorBreakpointInfo>;
    FNextID: Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetTarget(const ATarget: TMorDebugTarget);
    procedure SetSourceMap(const ASourceMap: TMorPDBSourceMap);

    // Set/remove breakpoints
    function SetBreakpoint(const AFile: string; const ALine: Integer;
      const ACondition: string = ''; const AHitCondition: Integer = 0): Integer;
    function RemoveBreakpoint(const AID: Integer): Boolean;
    function SetTempBreakpoint(const AAddress: UInt64): Integer;
    procedure RemoveAllTemp();
    procedure RemoveAll();

    // Query
    function IsOurBreakpoint(const AAddress: UInt64): Boolean;
    function GetBreakpointAt(const AAddress: UInt64;
      out AInfo: TMorBreakpointInfo): Boolean;
    function GetBreakpointByID(const AID: Integer;
      out AInfo: TMorBreakpointInfo): Boolean;
    function GetBreakpointCount(): Integer;
    function GetBreakpoint(const AIndex: Integer): TMorBreakpointInfo;

    // Patching (applies/removes INT3 bytes)
    procedure ApplyAll();
    procedure PatchBreakpoint(const AIndex: Integer);
    procedure UnpatchBreakpoint(const AIndex: Integer);
  end;

  { TMorStackWalker }
  TMorStackWalker = class(TMorBaseObject)
  public
    function WalkStack(const ATarget: TMorDebugTarget;
      const ASourceMap: TMorPDBSourceMap;
      const AContext: TContext): TArray<TMorDebugStackFrame>;
  end;

  { TMorDebugRuntime }
  TMorDebugRuntime = class(TMorErrorsObject)
  private
    FTarget: TMorDebugTarget;              // Reference (not owned)
    FSourceMap: TMorPDBSourceMap;           // Reference (not owned)
    FBreakpoints: TMorBreakpointManager;   // Owned
    FStackWalker: TMorStackWalker;         // Owned
    FLastStopEvent: TMorDebugStopEvent;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetTarget(const ATarget: TMorDebugTarget);
    procedure SetSourceMap(const ASourceMap: TMorPDBSourceMap);

    // Breakpoint management (delegates to FBreakpoints)
    function SetBreakpoint(const AFile: string; const ALine: Integer;
      const ACondition: string = ''; const AHitCondition: Integer = 0): Integer;
    function RemoveBreakpoint(const AID: Integer): Boolean;

    // Execution control
    function DoContinue(const ASetTrapFlag: Boolean = False): Boolean;
    function StepOver(): Boolean;
    function StepIn(): Boolean;
    function StepOut(): Boolean;
    function WaitForStop(): Boolean;

    // DAP lifecycle
    procedure ConfigurationDone();

    // Inspection
    function GetCallStack(): TArray<TMorDebugStackFrame>;
    function GetLastStopEvent(): TMorDebugStopEvent;
    function GetVariables(): TArray<TMorDebugVariable>;
    function Evaluate(const AExpression: string): TMorDebugVariable;

    // Access
    function GetBreakpoints(): TMorBreakpointManager;
    function GetTarget(): TMorDebugTarget;
    function GetSourceMap(): TMorPDBSourceMap;
  end;

implementation

{ TMorBreakpointManager }
constructor TMorBreakpointManager.Create();
begin
  inherited Create();
  FTarget := nil;
  FSourceMap := nil;
  FBreakpoints := TList<TMorBreakpointInfo>.Create();
  FNextID := 1;
end;

destructor TMorBreakpointManager.Destroy();
begin
  RemoveAll();
  FBreakpoints.Free();
  inherited Destroy();
end;

procedure TMorBreakpointManager.SetTarget(const ATarget: TMorDebugTarget);
begin
  FTarget := ATarget;
end;

procedure TMorBreakpointManager.SetSourceMap(const ASourceMap: TMorPDBSourceMap);
begin
  FSourceMap := ASourceMap;
end;

function TMorBreakpointManager.SetBreakpoint(const AFile: string;
  const ALine: Integer; const ACondition: string;
  const AHitCondition: Integer): Integer;
var
  LInfo: TMorBreakpointInfo;
  LAddress: UInt64;
begin
  Result := -1;

  if FTarget = nil then
    Exit;

  // Resolve source line to absolute address via PDB (if source map loaded)
  LAddress := 0;
  if FSourceMap <> nil then
  begin
    if not FSourceMap.SourceLineToAddress(AFile, ALine, LAddress) then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esWarning, 'DBG010',
          'No code at %s:%d', [AFile, ALine]);
      Exit;
    end;
  end;
  // If FSourceMap is nil, store with Address=0 (resolved later in ApplyAll)

  // Create breakpoint record (don't patch yet -- ApplyAll handles that)
  LInfo.ID := FNextID;
  Inc(FNextID);
  LInfo.SourceFile := AFile;
  LInfo.SourceLine := ALine;
  LInfo.Address := LAddress;
  LInfo.OriginalByte := 0;
  LInfo.IsTemporary := False;
  LInfo.IsEnabled := True;
  LInfo.IsPatched := False;
  LInfo.HitCount := 0;
  LInfo.Condition := ACondition;
  LInfo.HitCondition := AHitCondition;

  FBreakpoints.Add(LInfo);
  Result := LInfo.ID;
end;

function TMorBreakpointManager.RemoveBreakpoint(const AID: Integer): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].ID = AID then
    begin
      if FBreakpoints[LI].IsPatched then
        UnpatchBreakpoint(LI);
      FBreakpoints.Delete(LI);
      Result := True;
      Exit;
    end;
  end;
end;

function TMorBreakpointManager.SetTempBreakpoint(const AAddress: UInt64): Integer;
var
  LInfo: TMorBreakpointInfo;
begin
  if FTarget = nil then
    Exit(-1);

  LInfo.ID := FNextID;
  Inc(FNextID);
  LInfo.SourceFile := '';
  LInfo.SourceLine := 0;
  LInfo.Address := AAddress;
  LInfo.OriginalByte := FTarget.ReadByte(AAddress);
  LInfo.IsTemporary := True;
  LInfo.IsEnabled := True;
  LInfo.IsPatched := False;
  LInfo.HitCount := 0;
  LInfo.Condition := '';
  LInfo.HitCondition := 0;

  FBreakpoints.Add(LInfo);
  PatchBreakpoint(FBreakpoints.Count - 1);

  Result := LInfo.ID;
end;

procedure TMorBreakpointManager.RemoveAllTemp();
var
  LI: Integer;
begin
  for LI := FBreakpoints.Count - 1 downto 0 do
  begin
    if FBreakpoints[LI].IsTemporary then
    begin
      if FBreakpoints[LI].IsPatched then
        UnpatchBreakpoint(LI);
      FBreakpoints.Delete(LI);
    end;
  end;
end;

procedure TMorBreakpointManager.RemoveAll();
var
  LI: Integer;
begin
  for LI := FBreakpoints.Count - 1 downto 0 do
  begin
    if FBreakpoints[LI].IsPatched then
      UnpatchBreakpoint(LI);
  end;
  FBreakpoints.Clear();
end;

function TMorBreakpointManager.IsOurBreakpoint(const AAddress: UInt64): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].IsEnabled and (FBreakpoints[LI].Address = AAddress) then
      Exit(True);
  end;
end;

function TMorBreakpointManager.GetBreakpointAt(const AAddress: UInt64;
  out AInfo: TMorBreakpointInfo): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].Address = AAddress then
    begin
      AInfo := FBreakpoints[LI];
      Result := True;
      Exit;
    end;
  end;
end;

function TMorBreakpointManager.GetBreakpointByID(const AID: Integer;
  out AInfo: TMorBreakpointInfo): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].ID = AID then
    begin
      AInfo := FBreakpoints[LI];
      Result := True;
      Exit;
    end;
  end;
end;

function TMorBreakpointManager.GetBreakpointCount(): Integer;
begin
  Result := FBreakpoints.Count;
end;

function TMorBreakpointManager.GetBreakpoint(const AIndex: Integer): TMorBreakpointInfo;
begin
  Result := FBreakpoints[AIndex];
end;

//------------------------------------------------------------------------------
// Breakpoint Patching
//------------------------------------------------------------------------------

procedure TMorBreakpointManager.ApplyAll();
var
  LI: Integer;
  LInfo: TMorBreakpointInfo;
  LAddress: UInt64;
  LHasPending: Boolean;
  LWaitCount: Integer;
begin
  // Check if we have pending (unresolved) breakpoints
  LHasPending := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].IsEnabled and (FBreakpoints[LI].Address = 0) then
    begin
      LHasPending := True;
      Break;
    end;
  end;

  // Wait for source map if needed (server main thread may still be loading PDB)
  if LHasPending and (FSourceMap = nil) then
  begin
    LWaitCount := 0;
    while (FSourceMap = nil) and (LWaitCount < 500) do
    begin
      Sleep(10);
      Inc(LWaitCount);
    end;
  end;

  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    // Resolve pending breakpoints that were registered before PDB was loaded
    if FBreakpoints[LI].IsEnabled and (FBreakpoints[LI].Address = 0) and
       (FSourceMap <> nil) then
    begin
      if FSourceMap.SourceLineToAddress(FBreakpoints[LI].SourceFile,
           FBreakpoints[LI].SourceLine, LAddress) then
      begin
        LInfo := FBreakpoints[LI];
        LInfo.Address := LAddress;
        FBreakpoints[LI] := LInfo;
      end;
    end;

    if FBreakpoints[LI].IsEnabled and (not FBreakpoints[LI].IsPatched) and
       (FBreakpoints[LI].Address <> 0) then
      PatchBreakpoint(LI);
  end;
end;

procedure TMorBreakpointManager.PatchBreakpoint(const AIndex: Integer);
var
  LInfo: TMorBreakpointInfo;
begin
  LInfo := FBreakpoints[AIndex];
  if LInfo.IsPatched then
    Exit;

  // Save original byte and write INT3 at absolute address
  LInfo.OriginalByte := FTarget.ReadByte(LInfo.Address);
  FTarget.WriteByte(LInfo.Address, MOR_INT3_OPCODE);
  FTarget.FlushCode(LInfo.Address, 1);
  LInfo.IsPatched := True;

  FBreakpoints[AIndex] := LInfo;
end;

procedure TMorBreakpointManager.UnpatchBreakpoint(const AIndex: Integer);
var
  LInfo: TMorBreakpointInfo;
begin
  LInfo := FBreakpoints[AIndex];
  if not LInfo.IsPatched then
    Exit;

  // Restore original byte at absolute address
  FTarget.WriteByte(LInfo.Address, LInfo.OriginalByte);
  FTarget.FlushCode(LInfo.Address, 1);
  LInfo.IsPatched := False;

  FBreakpoints[AIndex] := LInfo;
end;

//==============================================================================
// TStackWalker
//==============================================================================

function TMorStackWalker.WalkStack(const ATarget: TMorDebugTarget;
  const ASourceMap: TMorPDBSourceMap;
  const AContext: TContext): TArray<TMorDebugStackFrame>;
var
  LFrame: TMorDebugStackFrame;
  LFrameID: Integer;
  LRIP: UInt64;
  LRBP: UInt64;
  LFile: string;
  LLine: Integer;
  LFuncName: string;
  LFuncStart: UInt64;
  LFuncSize: DWORD;
begin
  SetLength(Result, 0);
  LFrameID := 0;
  LRIP := AContext.Rip;
  LRBP := AContext.Rbp;

  while ATarget.IsOurCode(LRIP) do
  begin
    LFrame.FrameID := LFrameID;
    LFrame.Address := LRIP;
    LFrame.RBP := LRBP;
    LFrame.RIP := LRIP;
    LFrame.SourceColumn := 0;

    // Map address to source line via PDB
    if ASourceMap.AddressToSourceLine(LRIP, LFile, LLine) then
    begin
      LFrame.SourceFile := LFile;
      LFrame.SourceLine := LLine;
    end
    else
    begin
      LFrame.SourceFile := '';
      LFrame.SourceLine := 0;
    end;

    // Get function name via PDB
    if ASourceMap.GetFunctionAtAddress(LRIP, LFuncName, LFuncStart, LFuncSize) then
      LFrame.FunctionName := LFuncName
    else
      LFrame.FunctionName := Format('0x%x', [LRIP]);

    Result := Result + [LFrame];
    Inc(LFrameID);

    // Walk up one frame via RBP chain
    // Standard x64 frame: [RBP] = saved RBP, [RBP+8] = return address
    // Requires -fno-omit-frame-pointer in compile flags
    if LRBP = 0 then
      Break;

    try
      LRIP := ATarget.ReadUInt64(LRBP + 8);  // Saved return address
      LRBP := ATarget.ReadUInt64(LRBP);       // Saved RBP
    except
      // Memory read failed -- end of valid stack
      Break;
    end;

    // Safety: stop if we've gone too deep or RBP is zero/invalid
    if (LRBP = 0) or (LFrameID > 256) then
      Break;
  end;
end;

{ TMorDebugRuntime }
constructor TMorDebugRuntime.Create();
begin
  inherited Create();
  FTarget := nil;
  FSourceMap := nil;
  FBreakpoints := TMorBreakpointManager.Create();
  FStackWalker := TMorStackWalker.Create();
  FillChar(FLastStopEvent, SizeOf(FLastStopEvent), 0);
end;

destructor TMorDebugRuntime.Destroy();
begin
  FStackWalker.Free();
  FBreakpoints.Free();
  inherited Destroy();
end;

procedure TMorDebugRuntime.SetTarget(const ATarget: TMorDebugTarget);
begin
  FTarget := ATarget;
  FBreakpoints.SetTarget(ATarget);
end;

procedure TMorDebugRuntime.SetSourceMap(const ASourceMap: TMorPDBSourceMap);
begin
  FSourceMap := ASourceMap;
  FBreakpoints.SetSourceMap(ASourceMap);
end;

function TMorDebugRuntime.SetBreakpoint(const AFile: string;
  const ALine: Integer; const ACondition: string;
  const AHitCondition: Integer): Integer;
begin
  Result := FBreakpoints.SetBreakpoint(AFile, ALine, ACondition, AHitCondition);
end;

function TMorDebugRuntime.RemoveBreakpoint(const AID: Integer): Boolean;
begin
  Result := FBreakpoints.RemoveBreakpoint(AID);
end;

procedure TMorDebugRuntime.ConfigurationDone();
begin
  // Wait until the debug loop thread has reached the initial breakpoint
  // (FActualImageBase is set, process memory is accessible)
  if FTarget <> nil then
    FTarget.WaitUntilReady();

  // Apply all breakpoints while the process is still held at the loader BP
  FBreakpoints.ApplyAll();

  // Signal the target to release the process
  if FTarget <> nil then
    FTarget.SignalConfigDone();
end;

function TMorDebugRuntime.DoContinue(const ASetTrapFlag: Boolean): Boolean;
var
  LBPInfo: TMorBreakpointInfo;
  LContext: TContext;
  LAddress: UInt64;
begin
  Result := False;
  if FTarget = nil then
    Exit;

  LContext := FTarget.GetContext();

  // Guard: if no valid stop context yet (Rip=0), just resume
  if LContext.Rip = 0 then
  begin
    if ASetTrapFlag then
      FTarget.SetTrapFlag();
    FTarget.Resume();
    Result := True;
    Exit;
  end;

  LAddress := LContext.Rip;

  // If stopped at a breakpoint, step past it first:
  // 1. Restore original byte
  // 2. Set trap flag for single-step
  // 3. Tell target to re-patch after the single-step
  if FBreakpoints.GetBreakpointAt(LAddress, LBPInfo) and LBPInfo.IsPatched then
  begin
    // Restore original byte so we can execute the real instruction
    FTarget.WriteByte(LAddress, LBPInfo.OriginalByte);
    FTarget.FlushCode(LAddress, 1);

    // Set trap flag -- after one instruction, single-step fires
    // and the debug loop re-patches the INT3
    FTarget.SetTrapFlag();

    // Tell target to re-patch at this address after single-step
    FTarget.SetRepatchOffset(Int64(LAddress));
  end
  else if ASetTrapFlag then
    FTarget.SetTrapFlag();

  // Resume execution
  FTarget.Resume();
  Result := True;
end;

function TMorDebugRuntime.StepOver(): Boolean;
var
  LContext: TContext;
  LCurrentFile: string;
  LCurrentLine: Integer;
  LNextAddress: UInt64;
  LI: Integer;
  LFuncName: string;
  LFuncStart: UInt64;
  LFuncSize: DWORD;
  LProbeFuncName: string;
  LProbeFuncStart: UInt64;
  LProbeFuncSize: DWORD;
begin
  Result := False;
  if (FTarget = nil) or (FSourceMap = nil) then
    Exit;

  LContext := FTarget.GetContext();

  // Get current source position via PDB
  if not FSourceMap.AddressToSourceLine(LContext.Rip, LCurrentFile, LCurrentLine) then
  begin
    // Can't determine current line -- fall back to step out
    Result := StepOut();
    Exit;
  end;

  // Get current function name and boundaries to avoid crossing into another function
  LFuncStart := 0;
  LFuncSize := 0;
  LFuncName := '';
  FSourceMap.GetFunctionAtAddress(LContext.Rip, LFuncName, LFuncStart, LFuncSize);

  // Probe ahead for the next executable source line (line+1 through line+20)
  LNextAddress := 0;
  for LI := 1 to 20 do
  begin
    if FSourceMap.SourceLineToAddress(LCurrentFile,
      LCurrentLine + LI, LNextAddress) then
    begin
      // Reject addresses that are the same as current RIP (no forward progress)
      if LNextAddress = LContext.Rip then
      begin
        LNextAddress := 0;
        Continue;
      end;
      // Reject addresses outside the current function
      if (LFuncName <> '') then
      begin
        if (LFuncSize > 0) then
        begin
          // Use address range when size is known
          if (LNextAddress < LFuncStart) or
             (LNextAddress >= LFuncStart + UInt64(LFuncSize)) then
          begin
            LNextAddress := 0;
            Continue;
          end;
        end
        else
        begin
          // Size unknown -- compare function names as fallback
          LProbeFuncName := '';
          LProbeFuncStart := 0;
          LProbeFuncSize := 0;
          if FSourceMap.GetFunctionAtAddress(LNextAddress,
            LProbeFuncName, LProbeFuncStart, LProbeFuncSize) and
             (LProbeFuncName <> LFuncName) then
          begin
            LNextAddress := 0;
            Continue;
          end;
        end;
      end;
      Break;
    end;
    LNextAddress := 0;
  end;

  if LNextAddress = 0 then
  begin
    // No next line in this function -- step out to caller
    Result := StepOut();
    Exit;
  end;

  // Set a temporary breakpoint at the next line
  FBreakpoints.SetTempBreakpoint(LNextAddress);

  // Continue execution (handles stepping past current breakpoint)
  Result := DoContinue();
end;

function TMorDebugRuntime.StepIn(): Boolean;
var
  LContext: TContext;
  LAddr: UInt64;
  LOpcode: Byte;
  LRel32: Int32;
  LCallTarget: UInt64;
begin
  Result := False;
  if (FTarget = nil) or (FSourceMap = nil) then
    Exit;

  LContext := FTarget.GetContext();
  LAddr := LContext.Rip;

  // Check if current instruction is a CALL rel32 (opcode E8)
  // This is the most common call form in compiled x64 code
  LOpcode := FTarget.ReadByte(LAddr);
  if LOpcode = $E8 then
  begin
    // Read the 32-bit relative displacement
    LRel32 := Int32(FTarget.ReadByte(LAddr + 1)) or
              (Int32(FTarget.ReadByte(LAddr + 2)) shl 8) or
              (Int32(FTarget.ReadByte(LAddr + 3)) shl 16) or
              (Int32(FTarget.ReadByte(LAddr + 4)) shl 24);

    // CALL rel32: target = RIP + 5 + rel32
    LCallTarget := LAddr + 5 + UInt64(LRel32);

    // Only step into if the target is within our code
    if FTarget.IsOurCode(LCallTarget) then
    begin
      FBreakpoints.SetTempBreakpoint(LCallTarget);
      Result := DoContinue();
      Exit;
    end;
  end;

  // Not a CALL we can decode, or target is external -- fall back to StepOver
  Result := StepOver();
end;

function TMorDebugRuntime.StepOut(): Boolean;
var
  LContext: TContext;
  LReturnAddr: UInt64;
begin
  Result := False;
  if FTarget = nil then
    Exit;

  LContext := FTarget.GetContext();

  // Read return address from [RBP+8] (standard x64 frame)
  // Requires -fno-omit-frame-pointer in compile flags
  if LContext.Rbp = 0 then
    Exit;

  try
    LReturnAddr := FTarget.ReadUInt64(LContext.Rbp + 8);
  except
    Exit;
  end;

  // Only set breakpoint if return address is in our code
  if not FTarget.IsOurCode(LReturnAddr) then
  begin
    // Returning to non-user code -- just continue
    Result := DoContinue();
    Exit;
  end;

  FBreakpoints.SetTempBreakpoint(LReturnAddr);
  Result := DoContinue();
end;

function TMorDebugRuntime.WaitForStop(): Boolean;
var
  LEvent: TMorDebugStopEvent;
  LBPInfo: TMorBreakpointInfo;
  LI: Integer;
  LFound: Boolean;
  LShouldBreak: Boolean;
  LCondVar: TMorDebugVariable;
begin
  Result := False;
  if FTarget = nil then
    Exit;

  while True do
  begin
    if not FTarget.WaitForStop(LEvent) then
      Exit;

    // DLL load event: apply breakpoints and resume transparently
    if LEvent.Reason = dsrDllLoad then
    begin
      FBreakpoints.ApplyAll();
      FTarget.Resume();
      Continue;  // Loop back to wait for the next stop
    end;

    FLastStopEvent := LEvent;

    // If we stopped at a breakpoint, update hit count and check conditions
    if LEvent.Reason = dsrBreakpoint then
    begin
      LFound := False;
      LShouldBreak := True;

      for LI := 0 to FBreakpoints.GetBreakpointCount() - 1 do
      begin
        if FBreakpoints.GetBreakpoint(LI).Address = LEvent.Address then
        begin
          LBPInfo := FBreakpoints.GetBreakpoint(LI);
          Inc(LBPInfo.HitCount);
          FBreakpoints.FBreakpoints[LI] := LBPInfo;
          LFound := True;

          // Check hit condition (break only when HitCount >= threshold)
          if (LBPInfo.HitCondition > 0) and
             (LBPInfo.HitCount < LBPInfo.HitCondition) then
            LShouldBreak := False;

          // Check expression condition (evaluate variable, skip if falsy)
          if LShouldBreak and (LBPInfo.Condition <> '') then
          begin
            LCondVar := Evaluate(LBPInfo.Condition);
            if (LCondVar.VarValue = '') or
               (LCondVar.VarValue = '0') or
               SameText(LCondVar.VarValue, 'false') then
              LShouldBreak := False;
          end;

          Break;
        end;
      end;

      // Condition not met -- silently resume and wait for next stop
      if LFound and (not LShouldBreak) then
      begin
        FBreakpoints.RemoveAllTemp();
        Self.DoContinue();
        Continue;  // Loop back to WaitForStop
      end;
    end;

    // All conditions met (or not a conditional breakpoint) -- stop here
    Break;
  end;

  // Remove temporary breakpoints (used by stepping)
  FBreakpoints.RemoveAllTemp();

  Result := True;
end;

function TMorDebugRuntime.GetCallStack(): TArray<TMorDebugStackFrame>;
var
  LContext: TContext;
begin
  if (FTarget = nil) or (FSourceMap = nil) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LContext := FTarget.GetContext();
  Result := FStackWalker.WalkStack(FTarget, FSourceMap, LContext);
end;

function TMorDebugRuntime.GetLastStopEvent(): TMorDebugStopEvent;
begin
  Result := FLastStopEvent;
end;

function TMorDebugRuntime.GetVariables(): TArray<TMorDebugVariable>;
var
  LVars: TArray<TMorDebugVariable>;
  LContext: TContext;
  LAddress: UInt64;
  LBytes: TBytes;
  LI: Integer;
  LVar: TMorDebugVariable;
  LResultList: TList<TMorDebugVariable>;
begin
  Result := nil;
  if (FTarget = nil) or (FSourceMap = nil) then
    Exit;

  // Get variables at the current stop address via PDB
  LVars := FSourceMap.GetVariablesAtAddress(FLastStopEvent.Address);
  if Length(LVars) = 0 then
    Exit;

  // Capture thread context for RBP
  LContext := FTarget.GetContext();

  LResultList := TList<TMorDebugVariable>.Create();
  try
    for LI := 0 to High(LVars) do
    begin
      LVar := LVars[LI];

      // Read value from debuggee stack memory
      // PDB variables with SYMFLAG_REGREL have Address = RBP offset
      LVar.VarValue := '???';

      // Default to 8 bytes if PDB doesn't report size (common for locals)
      if LVar.Size = 0 then
        LVar.Size := 8;

      LAddress := UInt64(Int64(LContext.Rbp) + Int64(LVar.Address));
      try
        LBytes := FTarget.ReadBytes(LAddress, LVar.Size);
        if Cardinal(Length(LBytes)) = LVar.Size then
        begin
          // Format based on size (decimal for standard integer widths)
          case LVar.Size of
            1: LVar.VarValue := IntToStr(ShortInt(LBytes[0]));
            2: LVar.VarValue := IntToStr(SmallInt(PWord(@LBytes[0])^));
            4: LVar.VarValue := IntToStr(PInteger(@LBytes[0])^);
            8: LVar.VarValue := IntToStr(PInt64(@LBytes[0])^);
          else
            LVar.VarValue := IntToStr(PInt64(@LBytes[0])^);
          end;
        end;
      except
        LVar.VarValue := '<unreadable>';
      end;

      LResultList.Add(LVar);
    end;

    Result := LResultList.ToArray();
  finally
    LResultList.Free();
  end;
end;

function TMorDebugRuntime.Evaluate(const AExpression: string): TMorDebugVariable;
var
  LVars: TArray<TMorDebugVariable>;
  LI: Integer;
  LExpr: string;
begin
  // Default: not found
  Result := Default(TMorDebugVariable);
  Result.VarName := AExpression;

  LExpr := Trim(AExpression);
  if LExpr = '' then
    Exit;

  // Get all variables for the current frame, then filter by name
  LVars := GetVariables();
  for LI := 0 to High(LVars) do
  begin
    if SameText(LVars[LI].VarName, LExpr) then
    begin
      Result := LVars[LI];
      Exit;
    end;
  end;
end;

function TMorDebugRuntime.GetBreakpoints(): TMorBreakpointManager;
begin
  Result := FBreakpoints;
end;

function TMorDebugRuntime.GetTarget(): TMorDebugTarget;
begin
  Result := FTarget;
end;

function TMorDebugRuntime.GetSourceMap(): TMorPDBSourceMap;
begin
  Result := FSourceMap;
end;

end.
