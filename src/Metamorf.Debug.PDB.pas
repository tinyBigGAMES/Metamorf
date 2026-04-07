{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Debug.PDB;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  Metamorf.Utils;

type
  { TMorDebugVariable }
  TMorDebugVariable = record
    VarName: string;
    VarValue: string;        // Formatted value string
    VarType: string;         // Type name (v2: from PDB type info)
    IsParameter: Boolean;    // True = parameter, False = local
    Address: UInt64;         // Stack address or register
    Size: DWORD;             // Size in bytes
  end;

  { TMorPDBSourceMap }
  TMorPDBSourceMap = class(TMorBaseObject)
  private
    FProcessHandle: THandle;
    FModuleBase: UInt64;
    FInitialized: Boolean;
    FPDBPath: string;
    FLock: TCriticalSection;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Initialization (called after process created, before breakpoints set)
    function Initialize(const AProcessHandle: THandle;
      const AExePath: string;
      const APDBPath: string;
      const ABaseAddress: UInt64 = 0): Boolean;
    procedure Cleanup();

    // Address <-> source line mapping
    function AddressToSourceLine(const AAddress: UInt64;
      out AFile: string; out ALine: Integer): Boolean;
    function SourceLineToAddress(const AFile: string;
      const ALine: Integer; out AAddress: UInt64): Boolean;

    // Function info at address
    function GetFunctionAtAddress(const AAddress: UInt64;
      out AFuncName: string; out AFuncStart: UInt64;
      out AFuncSize: DWORD): Boolean;

    // Variable enumeration at address
    function GetVariablesAtAddress(const AAddress: UInt64): TArray<TMorDebugVariable>;

    // Stack unwinding via StackWalk64 (works with -fomit-frame-pointer)
    function GetCallerReturnAddress(const AThreadHandle: THandle;
      const AContext: TContext; out AReturnAddr: UInt64): Boolean;

    // State
    function IsInitialized(): Boolean;
    function GetModuleBase(): UInt64;
    function GetProcessHandle(): THandle;
  end;

implementation

const
  DbgHelpDLL = 'dbghelp.dll';

  // SymSetOptions flags
  SYMOPT_LOAD_LINES     = $00000010;
  SYMOPT_UNDNAME        = $00000002;
  SYMOPT_DEFERRED_LOADS = $00000004;

  // Maximum symbol name length
  MAX_SYM_NAME = 2000;

  // StackWalk64 constants
  IMAGE_FILE_MACHINE_AMD64 = $8664;
  AddrModeFlat = 3;

  // SYMBOL_INFO flags
  SYMFLAG_PARAMETER = $00000008;
  SYMFLAG_LOCAL     = $00000020;
  SYMFLAG_REGREL    = $00000200;

type
  //============================================================================
  // DbgHelp record types
  //============================================================================

  PSYMBOL_INFO = ^SYMBOL_INFO;
  SYMBOL_INFO = record
    SizeOfStruct: ULONG;
    TypeIndex: ULONG;
    Reserved: array[0..1] of UInt64;
    Index: ULONG;
    Size: ULONG;
    ModBase: UInt64;
    Flags: ULONG;
    Value: UInt64;
    Address: UInt64;
    Register_: ULONG;
    Scope: ULONG;
    Tag: ULONG;
    NameLen: ULONG;
    MaxNameLen: ULONG;
    SymName: array[0..0] of AnsiChar;  // Variable-length
  end;

  PIMAGEHLP_LINE64 = ^IMAGEHLP_LINE64;
  IMAGEHLP_LINE64 = record
    SizeOfStruct: DWORD;
    Key: Pointer;
    LineNumber: DWORD;
    FileName: PAnsiChar;
    Address: UInt64;
  end;

  PIMAGEHLP_STACK_FRAME = ^IMAGEHLP_STACK_FRAME;
  IMAGEHLP_STACK_FRAME = record
    InstructionOffset: UInt64;
    ReturnOffset: UInt64;
    FrameOffset: UInt64;
    StackOffset: UInt64;
    BackingStoreOffset: UInt64;
    FuncTableEntry: UInt64;
    Params: array[0..3] of UInt64;
    Reserved: array[0..4] of UInt64;
    Virtual: BOOL;
    Reserved2: ULONG;
  end;

  // ADDRESS64 - used by STACKFRAME64 for StackWalk64
  PADDRESS64 = ^ADDRESS64;
  ADDRESS64 = record
    Offset: UInt64;
    Segment: Word;
    Mode: DWORD;  // ADDRESS_MODE enum (AddrModeFlat = 3)
  end;

  // KDHELP64 - kernel callback helper data for StackWalk64
  KDHELP64 = record
    Thread: UInt64;
    ThCallbackStack: DWORD;
    ThCallbackBStore: DWORD;
    NextCallback: DWORD;
    FramePointer: DWORD;
    KiCallUserMode: UInt64;
    KeUserCallbackDispatcher: UInt64;
    SystemRangeStart: UInt64;
    KiUserExceptionDispatcher: UInt64;
    StackBase: UInt64;
    StackLimit: UInt64;
    Reserved2: array[0..4] of UInt64;
  end;

  // STACKFRAME64 - stack frame for StackWalk64
  PSTACKFRAME64 = ^STACKFRAME64;
  STACKFRAME64 = record
    AddrPC: ADDRESS64;
    AddrReturn: ADDRESS64;
    AddrFrame: ADDRESS64;
    AddrStack: ADDRESS64;
    AddrBStore: ADDRESS64;
    FuncTableEntry: Pointer;
    Params: array[0..3] of UInt64;
    bFar: BOOL;
    bVirtual: BOOL;
    Reserved: array[0..2] of UInt64;
    KdHelp: KDHELP64;
  end;

  TSymEnumSymbolsCallback = function(
    const ASymInfo: PSYMBOL_INFO;
    const ASymbolSize: ULONG;
    const AUserContext: Pointer
  ): BOOL; stdcall;

  //============================================================================
  // DbgHelp external function declarations
  //============================================================================

function SymInitialize(
  AProcess: THandle;
  AUserSearchPath: PAnsiChar;
  AInvadeProcess: BOOL
): BOOL; stdcall; external DbgHelpDLL;

function SymCleanup(
  AProcess: THandle
): BOOL; stdcall; external DbgHelpDLL;

function SymSetOptions(
  ASymOptions: DWORD
): DWORD; stdcall; external DbgHelpDLL;

function SymLoadModuleEx(
  AProcess: THandle;
  AFile: THandle;
  AImageName: PAnsiChar;
  AModuleName: PAnsiChar;
  ABaseOfDll: UInt64;
  ADllSize: DWORD;
  AData: Pointer;
  AFlags: DWORD
): UInt64; stdcall; external DbgHelpDLL;

function SymFromAddr(
  AProcess: THandle;
  AAddress: UInt64;
  ADisplacement: PUInt64;
  ASymbol: PSYMBOL_INFO
): BOOL; stdcall; external DbgHelpDLL;

function SymGetLineFromAddr64(
  AProcess: THandle;
  AAddr: UInt64;
  ADisplacement: PDWORD;
  ALine: PIMAGEHLP_LINE64
): BOOL; stdcall; external DbgHelpDLL;

function SymGetLineFromName64(
  AProcess: THandle;
  AModuleName: PAnsiChar;
  AFileName: PAnsiChar;
  ALineNumber: DWORD;
  ADisplacement: PLONG;
  ALine: PIMAGEHLP_LINE64
): BOOL; stdcall; external DbgHelpDLL;

function SymEnumSymbols(
  AProcess: THandle;
  ABaseOfDll: UInt64;
  AMask: PAnsiChar;
  AEnumSymbolsCallback: TSymEnumSymbolsCallback;
  AUserContext: Pointer
): BOOL; stdcall; external DbgHelpDLL;

function SymSetContext(
  AProcess: THandle;
  AStackFrame: PIMAGEHLP_STACK_FRAME;
  AContext: Pointer
): BOOL; stdcall; external DbgHelpDLL;

function StackWalk64(
  AMachineType: DWORD;
  AProcess: THandle;
  AThread: THandle;
  AStackFrame: PSTACKFRAME64;
  AContextRecord: Pointer;
  AReadMemoryRoutine: Pointer;
  AFunctionTableAccessRoutine: Pointer;
  AGetModuleBaseRoutine: Pointer;
  ATranslateAddress: Pointer
): BOOL; stdcall; external DbgHelpDLL;

function SymFunctionTableAccess64(
  AProcess: THandle;
  AAddrBase: UInt64
): Pointer; stdcall; external DbgHelpDLL;

function SymGetModuleBase64(
  AProcess: THandle;
  AAddr: UInt64
): UInt64; stdcall; external DbgHelpDLL;

function EnumSymbolsCallback(
  const ASymInfo: PSYMBOL_INFO;
  const ASymbolSize: ULONG;
  const AUserContext: Pointer
): BOOL; stdcall;
var
  LList: TList<TMorDebugVariable>;
  LVar: TMorDebugVariable;
  LNameLen: Integer;
begin
  Result := True;  // Continue enumeration

  if AUserContext = nil then
    Exit;

  LList := TList<TMorDebugVariable>(AUserContext);

  LNameLen := ASymInfo.NameLen;
  if LNameLen > MAX_SYM_NAME then
    LNameLen := MAX_SYM_NAME;

  LVar := Default(TMorDebugVariable);
  SetString(LVar.VarName, PAnsiChar(@ASymInfo.SymName[0]), LNameLen);
  LVar.IsParameter := (ASymInfo.Flags and SYMFLAG_PARAMETER) <> 0;
  LVar.Address := ASymInfo.Address;
  LVar.Size := ASymInfo.Size;
  LVar.VarType := '';   // v2: use SymGetTypeInfo
  LVar.VarValue := '';  // Filled later by reading process memory

  LList.Add(LVar);
end;

constructor TMorPDBSourceMap.Create();
begin
  inherited Create();
  FProcessHandle := 0;
  FModuleBase := 0;
  FInitialized := False;
  FPDBPath := '';
  FLock := TCriticalSection.Create();
end;

destructor TMorPDBSourceMap.Destroy();
begin
  Cleanup();
  FreeAndNil(FLock);
  inherited Destroy();
end;

function TMorPDBSourceMap.Initialize(const AProcessHandle: THandle;
  const AExePath: string; const APDBPath: string;
  const ABaseAddress: UInt64): Boolean;
var
  LSearchPathAnsi: AnsiString;
  LExePathAnsi: AnsiString;
  LSearchDir: string;
begin
  Result := False;

  if FInitialized then
    Cleanup();

  FProcessHandle := AProcessHandle;
  FPDBPath := APDBPath;

  FLock.Enter();
  try
    // Set symbol options: load line info, undecorate names
    SymSetOptions(SYMOPT_LOAD_LINES or SYMOPT_UNDNAME or SYMOPT_DEFERRED_LOADS);

    // Use PDB directory as search path
    LSearchDir := ExtractFilePath(APDBPath);
    LSearchPathAnsi := AnsiString(LSearchDir);

    // Initialize symbol handler for the process
    if not SymInitialize(FProcessHandle, PAnsiChar(LSearchPathAnsi), False) then
      Exit;

    // Load the module using the EXE path at the actual image base
    LExePathAnsi := AnsiString(AExePath);
    FModuleBase := SymLoadModuleEx(
      FProcessHandle,
      0,
      PAnsiChar(LExePathAnsi),
      nil,
      ABaseAddress, 0, nil, 0
    );

    if FModuleBase = 0 then
    begin
      SymCleanup(FProcessHandle);
      Exit;
    end;

    FInitialized := True;
    Result := True;
  finally
    FLock.Leave();
  end;
end;

procedure TMorPDBSourceMap.Cleanup();
begin
  if not FInitialized then
    Exit;

  FLock.Enter();
  try
    SymCleanup(FProcessHandle);
    FInitialized := False;
    FModuleBase := 0;
    FProcessHandle := 0;
  finally
    FLock.Leave();
  end;
end;

function TMorPDBSourceMap.AddressToSourceLine(const AAddress: UInt64;
  out AFile: string; out ALine: Integer): Boolean;
var
  LLineInfo: IMAGEHLP_LINE64;
  LDisplacement: DWORD;
begin
  Result := False;
  AFile := '';
  ALine := 0;

  if not FInitialized then
    Exit;

  FLock.Enter();
  try
    FillChar(LLineInfo, SizeOf(LLineInfo), 0);
    LLineInfo.SizeOfStruct := SizeOf(IMAGEHLP_LINE64);
    LDisplacement := 0;

    if SymGetLineFromAddr64(FProcessHandle, AAddress,
      @LDisplacement, @LLineInfo) then
    begin
      AFile := string(AnsiString(LLineInfo.FileName));
      ALine := Integer(LLineInfo.LineNumber);
      Result := True;
    end;
  finally
    FLock.Leave();
  end;
end;

function TMorPDBSourceMap.SourceLineToAddress(const AFile: string;
  const ALine: Integer; out AAddress: UInt64): Boolean;
var
  LLineInfo: IMAGEHLP_LINE64;
  LDisplacement: LONG;
  LFileAnsi: AnsiString;
begin
  Result := False;
  AAddress := 0;

  if not FInitialized then
    Exit;

  FLock.Enter();
  try
    FillChar(LLineInfo, SizeOf(LLineInfo), 0);
    LLineInfo.SizeOfStruct := SizeOf(IMAGEHLP_LINE64);
    LDisplacement := 0;
    LFileAnsi := AnsiString(StringReplace(AFile, '/', '\', [rfReplaceAll]));

    if SymGetLineFromName64(FProcessHandle, nil,
      PAnsiChar(LFileAnsi), DWORD(ALine),
      @LDisplacement, @LLineInfo) then
    begin
      AAddress := LLineInfo.Address;
      Result := True;
    end;
  finally
    FLock.Leave();
  end;
end;

function TMorPDBSourceMap.GetFunctionAtAddress(const AAddress: UInt64;
  out AFuncName: string; out AFuncStart: UInt64;
  out AFuncSize: DWORD): Boolean;
var
  LSymBuf: array[0..SizeOf(SYMBOL_INFO) + MAX_SYM_NAME * SizeOf(AnsiChar) - 1] of Byte;
  LSymbol: PSYMBOL_INFO;
  LDisplacement: UInt64;
begin
  Result := False;
  AFuncName := '';
  AFuncStart := 0;
  AFuncSize := 0;

  if not FInitialized then
    Exit;

  FLock.Enter();
  try
    FillChar(LSymBuf, SizeOf(LSymBuf), 0);
    LSymbol := @LSymBuf[0];
    LSymbol.SizeOfStruct := SizeOf(SYMBOL_INFO);
    LSymbol.MaxNameLen := MAX_SYM_NAME;
    LDisplacement := 0;

    if SymFromAddr(FProcessHandle, AAddress, @LDisplacement, LSymbol) then
    begin
      SetString(AFuncName, PAnsiChar(@LSymbol.SymName[0]), LSymbol.NameLen);
      AFuncStart := LSymbol.Address;
      AFuncSize := LSymbol.Size;
      Result := True;
    end;
  finally
    FLock.Leave();
  end;
end;

function TMorPDBSourceMap.GetVariablesAtAddress(
  const AAddress: UInt64): TArray<TMorDebugVariable>;
var
  LStackFrame: IMAGEHLP_STACK_FRAME;
  LList: TList<TMorDebugVariable>;
begin
  Result := nil;

  if not FInitialized then
    Exit;

  LList := TList<TMorDebugVariable>.Create();
  try
    FLock.Enter();
    try
      // Set the context to this instruction address so SymEnumSymbols
      // returns locals/params for the containing function
      FillChar(LStackFrame, SizeOf(LStackFrame), 0);
      LStackFrame.InstructionOffset := AAddress;

      if not SymSetContext(FProcessHandle, @LStackFrame, nil) then
        Exit;

      // Enumerate all symbols in the current context (BaseOfDll=0 when using context)
      SymEnumSymbols(
        FProcessHandle,
        0,
        PAnsiChar(AnsiString('*')),
        @EnumSymbolsCallback,
        LList
      );
    finally
      FLock.Leave();
    end;

    Result := LList.ToArray();
  finally
    FreeAndNil(LList);
  end;
end;

function TMorPDBSourceMap.IsInitialized(): Boolean;
begin
  Result := FInitialized;
end;

function TMorPDBSourceMap.GetModuleBase(): UInt64;
begin
  Result := FModuleBase;
end;

function TMorPDBSourceMap.GetProcessHandle(): THandle;
begin
  Result := FProcessHandle;
end;

function TMorPDBSourceMap.GetCallerReturnAddress(const AThreadHandle: THandle;
  const AContext: TContext; out AReturnAddr: UInt64): Boolean;
var
  LLocalContext: TContext;
  LStackFrame: STACKFRAME64;
begin
  Result := False;
  AReturnAddr := 0;

  if not FInitialized then
    Exit;

  // StackWalk64 modifies the context, so work on a local copy
  LLocalContext := AContext;

  // Initialize stack frame for x64
  FillChar(LStackFrame, SizeOf(LStackFrame), 0);
  LStackFrame.AddrPC.Offset := AContext.Rip;
  LStackFrame.AddrPC.Mode := AddrModeFlat;
  LStackFrame.AddrFrame.Offset := AContext.Rsp;  // RSP on x64 (not RBP)
  LStackFrame.AddrFrame.Mode := AddrModeFlat;
  LStackFrame.AddrStack.Offset := AContext.Rsp;
  LStackFrame.AddrStack.Mode := AddrModeFlat;

  FLock.Enter();
  try
    // First call: walk to current frame, fills in AddrReturn
    if not StackWalk64(IMAGE_FILE_MACHINE_AMD64, FProcessHandle,
      AThreadHandle, @LStackFrame, @LLocalContext,
      nil, @SymFunctionTableAccess64, @SymGetModuleBase64, nil) then
      Exit;

    // AddrReturn now contains the return address to the caller
    AReturnAddr := LStackFrame.AddrReturn.Offset;

    // If AddrReturn is 0, try second call and use AddrPC (caller's RIP)
    if AReturnAddr = 0 then
    begin
      if not StackWalk64(IMAGE_FILE_MACHINE_AMD64, FProcessHandle,
        AThreadHandle, @LStackFrame, @LLocalContext,
        nil, @SymFunctionTableAccess64, @SymGetModuleBase64, nil) then
        Exit;
      AReturnAddr := LStackFrame.AddrPC.Offset;
    end;
  finally
    FLock.Leave();
  end;

  Result := AReturnAddr <> 0;
end;

end.
