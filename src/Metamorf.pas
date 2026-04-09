{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

/// <summary>
///   Delphi and Free Pascal import wrapper for Metamorf.dll. Provides
///   complete access to the Metamorf compilation pipeline through opaque
///   handles and flat function calls with no dependencies on Metamorf
///   internals.
/// </summary>
/// <remarks>
///   All interaction is through UInt64 handles (TMorHandle, TMorNode) and
///   null-terminated UTF-8 strings (PUTF8Char). No Metamorf source units are
///   required to compile against this unit.
///   <para>
///   <b>String contract:</b> All strings crossing the DLL boundary are
///   null-terminated UTF-8. Strings returned by the DLL point into an
///   internal buffer that is valid only until the next string-returning call
///   on the same TMorHandle. Copy immediately with UTF8ToString() if you need
///   the value to persist. Strings passed to callbacks are valid only for the
///   duration of that callback invocation.
///   </para>
///   <para>
///   <b>Pipeline overview:</b> The stepped pipeline decomposes compilation
///   into discrete phases: mor_load_mor (parse .mor grammar),
///   mor_parse_source (lex and parse user source), mor_run_semantics
///   (type checking and semantic analysis), mor_run_emitters (C++ code
///   generation), and mor_build (invoke Zig/Clang to produce a native
///   binary). Each step requires the previous step to have succeeded. The
///   grammar loaded by mor_load_mor survives mor_reset, so multiple
///   source files can be compiled against the same grammar without re-parsing
///   the .mor file.
///   </para>
///   <para>
///   <b>One-shot compilation:</b>
///   </para>
///   <code>
///   var
///     LHandle: TMorHandle;
///   begin
///     LHandle := mor_create();
///     try
///       if mor_compile(LHandle,
///         PUTF8Char(UTF8Encode('langs\pascal.mor')),
///         PUTF8Char(UTF8Encode('hello.pas')),
///         PUTF8Char(UTF8Encode('output')), MOR_RUN_EXECUTE) then
///         WriteLn('Success')
///       else
///         WriteLn('Failed with ', mor_error_count(LHandle), ' error(s)');
///     finally
///       mor_destroy(LHandle);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Stepped pipeline with grammar reuse:</b>
///   </para>
///   <code>
///   var
///     LHandle: TMorHandle;
///   begin
///     LHandle := mor_create();
///     try
///       if mor_load_mor(LHandle, PUTF8Char(UTF8Encode('langs\pascal.mor'))) then
///       begin
///         if mor_parse_source(LHandle, PUTF8Char(UTF8Encode('hello.pas'))) then
///           if mor_run_semantics(LHandle) then
///             if mor_run_emitters(LHandle) then
///               mor_build(LHandle, PUTF8Char(UTF8Encode('output')), MOR_RUN_EXECUTE);
///
///         mor_reset(LHandle);  // clear pipeline state, keep grammar
///
///         if mor_parse_source(LHandle, PUTF8Char(UTF8Encode('world.pas'))) then
///           if mor_run_semantics(LHandle) then
///             if mor_run_emitters(LHandle) then
///               mor_build(LHandle, PUTF8Char(UTF8Encode('output')), MOR_RUN_EXECUTE);
///       end;
///     finally
///       mor_destroy(LHandle);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Custom code generation:</b> Call mor_load_mor, mor_parse_source,
///   and mor_run_semantics to obtain a fully typed, semantically analyzed
///   AST. Then walk the AST yourself using mor_get_master_root,
///   mor_node_child_count, mor_node_child, mor_node_kind,
///   mor_node_get_attr, and mor_node_set_attr. Skip
///   mor_run_emitters and mor_build entirely to emit any target
///   language you choose.
///   </para>
///   <para>
///   <b>Thread safety:</b> Each TMorHandle is an independent instance with no
///   shared state. Multiple handles may be used concurrently from different
///   threads. A single handle must not be accessed from multiple threads
///   simultaneously.
///   </para>
///   <para>
///   <b>Compatibility:</b> This unit compiles with Delphi (any recent version)
///   and Free Pascal (with MODE DELPHIUNICODE enabled automatically). It uses
///   only standard types: UInt64, PUTF8Char, Pointer, Boolean, Integer.
///   </para>
/// </remarks>
unit Metamorf;

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}

interface

const
  /// <summary>
  ///   The filename of the Metamorf shared library that all imports in this
  ///   unit bind to at load time. Change this constant if the DLL is renamed.
  /// </summary>
  METAMORF_DLL = 'Metamorf.dll';

  /// <summary>
  ///   Build only. The compiled binary is not executed after a successful
  ///   build.
  /// </summary>
  MOR_RUN_NONE = 0;

  /// <summary>
  ///   Build and execute. The compiled binary is launched automatically
  ///   after a successful build.
  /// </summary>
  MOR_RUN_EXECUTE = 1;

  /// <summary>
  ///   Build and debug. The compiled binary is launched under the lldb-dap
  ///   debugger with an interactive REPL after a successful build. Only
  ///   supported for Win64 targets.
  /// </summary>
  MOR_RUN_DEBUG = 2;

  // Build mode (maps to TMorBuildMode)
  MOR_BUILD_EXE = 0;
  MOR_BUILD_LIB = 1;
  MOR_BUILD_DLL = 2;

  // Optimize level (maps to TMorOptimizeLevel)
  MOR_OPT_DEBUG        = 0;
  MOR_OPT_RELEASE_SAFE = 1;
  MOR_OPT_RELEASE_FAST = 2;
  MOR_OPT_RELEASE_SMALL = 3;

  // Target platform (maps to TMorTargetPlatform)
  MOR_TARGET_WIN64   = 0;
  MOR_TARGET_LINUX64 = 1;

  // Subsystem type (maps to TMorSubsystemType)
  MOR_SUBSYSTEM_CONSOLE = 0;
  MOR_SUBSYSTEM_GUI     = 1;

type

  /// <summary>
  ///   Opaque handle to a Metamorf engine instance. Returned by
  ///   mor_create and accepted by all API functions that operate on an
  ///   engine. Must be freed with mor_destroy when no longer needed.
  /// </summary>
  /// <remarks>
  ///   Internally represents a 64-bit object pointer. Do not interpret,
  ///   dereference, or cast this value. Pass it back to the API exactly as
  ///   received. The handle becomes invalid after mor_destroy.
  /// </remarks>
  TMorHandle = UInt64;

  /// <summary>
  ///   Opaque handle to an AST node within a Metamorf engine instance.
  ///   Returned by mor_get_master_root, mor_node_child, and passed
  ///   to all metamorf_node_* query and mutation functions.
  /// </summary>
  /// <remarks>
  ///   Internally represents a 64-bit object pointer. Do not interpret,
  ///   dereference, or cast this value. Node handles are owned by the engine
  ///   and become invalid after mor_reset or mor_destroy. A value
  ///   of zero indicates a nil node (no node).
  /// </remarks>
  TMorNode = UInt64;

  /// <summary>
  ///   Callback procedure invoked by the engine to report pipeline progress
  ///   messages such as "Tokenizing hello.pas..." or "Building output...".
  /// </summary>
  /// <remarks>
  ///   The AMessage pointer is valid only for the duration of this callback
  ///   invocation. Copy the string with UTF8ToString() inside the callback
  ///   body if you need to store or display it later.
  ///   <para>
  ///   Register with mor_set_status_callback before calling any pipeline
  ///   steps.
  ///   </para>
  ///   <code>
  ///   procedure MyStatus(const AMessage: PUTF8Char;
  ///     const AUserData: Pointer);
  ///   begin
  ///     WriteLn(UTF8ToString(AMessage));
  ///   end;
  ///   </code>
  /// </remarks>
  /// <param name="AMessage">
  ///   Null-terminated UTF-8 status message. Valid only during the callback.
  /// </param>
  /// <param name="AUserData">
  ///   The user data pointer that was passed to mor_set_status_callback.
  ///   May be nil.
  /// </param>
  TMorStatusProc = procedure(const AMessage: PUTF8Char;
    const AUserData: Pointer);

  /// <summary>
  ///   Callback procedure invoked during code emission for AST node kinds
  ///   that have been registered via mor_register_emit_handler. Allows
  ///   external consumers to override the .mor-defined emitter for specific
  ///   node kinds and generate custom output.
  /// </summary>
  /// <remarks>
  ///   The ANodeHandle can be queried using mor_node_kind,
  ///   mor_node_get_attr, mor_node_child_count, and
  ///   mor_node_child to walk the subtree and produce whatever output
  ///   format you require. Note that string-returning node query functions
  ///   (mor_node_kind, mor_node_get_attr) require the TMorHandle
  ///   to store the returned UTF-8 string. You must provide the handle via
  ///   AUserData or through a captured variable.
  /// </remarks>
  /// <param name="ANodeHandle">
  ///   Opaque handle to the AST node being emitted. Query it with the
  ///   metamorf_node_* functions.
  /// </param>
  /// <param name="AUserData">
  ///   The user data pointer that was passed to mor_register_emit_handler.
  ///   Typically points to a context record containing the TMorHandle and an
  ///   output buffer.
  /// </param>
  TMorEmitProc = procedure(const ANodeHandle: UInt64;
    const AUserData: Pointer);

  /// <summary>
  ///   Callback procedure invoked to deliver compiler and program output lines,
  ///   such as build tool output or the stdout of an auto-run executable.
  /// </summary>
  /// <remarks>
  ///   The ALine pointer is valid only for the duration of this callback
  ///   invocation. Copy the string with UTF8ToString() inside the callback
  ///   body if you need to store or display it later.
  ///   <para>
  ///   Register with mor_set_output_callback before calling pipeline steps.
  ///   </para>
  ///   <code>
  ///   procedure MyOutput(const ALine: PUTF8Char;
  ///     const AUserData: Pointer);
  ///   begin
  ///     Write(UTF8ToString(ALine));
  ///   end;
  ///   </code>
  /// </remarks>
  /// <param name="ALine">
  ///   Null-terminated UTF-8 output line. Valid only during the callback.
  /// </param>
  /// <param name="AUserData">
  ///   The user data pointer that was passed to mor_set_output_callback.
  ///   May be nil.
  /// </param>
  TMorOutputProc = procedure(const ALine: PUTF8Char;
    const AUserData: Pointer);

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// <summary>
///   Creates a new Metamorf engine instance and returns its opaque handle.
///   The instance is fully independent and may be used concurrently with
///   other instances from different threads.
/// </summary>
/// <returns>
///   An opaque TMorHandle that must be passed to all subsequent API calls
///   and freed with mor_destroy when no longer needed.
/// </returns>
function mor_create(): TMorHandle;
  external METAMORF_DLL;

/// <summary>
///   Destroys a Metamorf engine instance and releases all associated memory,
///   including the loaded grammar, AST, scopes, and output buffers. The
///   handle becomes invalid after this call.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
procedure mor_destroy(const AHandle: TMorHandle);
  external METAMORF_DLL;

/// <summary>
///   Resets the pipeline state of a Metamorf engine instance, freeing the
///   parsed AST, scopes, and output from the most recent compilation. The
///   loaded .mor grammar is preserved so that mor_parse_source can be
///   called again without re-parsing the .mor file.
/// </summary>
/// <remarks>
///   Call this between successive compilations of different source files
///   against the same grammar. All TMorNode handles obtained from the
///   previous compilation become invalid after this call.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
procedure mor_reset(const AHandle: TMorHandle);
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Callbacks
// ---------------------------------------------------------------------------

/// <summary>
///   Registers a callback that receives pipeline progress messages such as
///   "Tokenizing hello.pas..." and "Building output...". Pass nil for AProc
///   to unregister a previously registered callback.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AProc">
///   The callback procedure to invoke, or nil to unregister.
/// </param>
/// <param name="AUserData">
///   An arbitrary pointer passed through to every invocation of AProc.
///   May be nil.
/// </param>
procedure mor_set_status_callback(const AHandle: TMorHandle;
  const AProc: TMorStatusProc; const AUserData: Pointer);
  external METAMORF_DLL;

/// <summary>
///   Registers a callback that receives real-time error, warning, and hint
///   notifications as they are produced during pipeline steps. Pass nil for
///   AProc to unregister a previously registered callback.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AProc">
///   The callback procedure to invoke, or nil to unregister.
/// </param>
/// <param name="AUserData">
///   An arbitrary pointer passed through to every invocation of AProc.
///   May be nil.
/// </param>
procedure mor_set_output_callback(const AHandle: TMorHandle;
  const AProc: TMorOutputProc; const AUserData: Pointer);
  external METAMORF_DLL;

/// <summary>
///   Registers a custom emit handler for a specific AST node kind. When
///   mor_run_emitters encounters a node whose kind matches ANodeKind,
///   AProc is called instead of the .mor-defined emitter. This allows
///   external consumers to override code generation for selected node kinds
///   while letting the .mor grammar handle the rest.
/// </summary>
/// <remarks>
///   Register handlers after mor_load_mor and before
///   mor_run_emitters. Native handlers take priority over .mor-defined
///   emitters for the same node kind.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="ANodeKind">
///   Null-terminated UTF-8 string identifying the AST node kind to handle
///   (e.g. 'stmt.print', 'decl.program').
/// </param>
/// <param name="AProc">
///   The callback procedure to invoke when a matching node is emitted.
/// </param>
/// <param name="AUserData">
///   An arbitrary pointer passed through to every invocation of AProc.
///   Typically points to a context record containing the TMorHandle and an
///   output buffer.
/// </param>
procedure mor_register_emit_handler(const AHandle: TMorHandle;
  const ANodeKind: PUTF8Char; const AProc: TMorEmitProc;
  const AUserData: Pointer);
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Stepped pipeline
// ---------------------------------------------------------------------------

/// <summary>
///   Loads and parses a .mor grammar file, populates the interpreter dispatch
///   tables, processes any .mor imports, and registers the C++ passthrough
///   layer. This is the most expensive pipeline step and only needs to be
///   performed once per grammar. After a successful call, mor_parse_source
///   may be called repeatedly against different source files.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AMorFile">
///   Null-terminated UTF-8 path to the .mor grammar file.
/// </param>
/// <returns>
///   True if the grammar was loaded successfully; False if errors occurred.
///   Query errors with mor_error_count and metamorf_error_get_*.
/// </returns>
function mor_load_mor(const AHandle: TMorHandle;
  const AMorFile: PUTF8Char): Boolean;
  external METAMORF_DLL;

/// <summary>
///   Lexes and parses a user source file using the table-driven lexer and
///   Pratt parser configured by the loaded .mor grammar. Produces an AST
///   rooted at the master root node.
/// </summary>
/// <remarks>
///   Requires mor_load_mor to have been called successfully. May be
///   called multiple times after a single mor_load_mor, with
///   mor_reset between calls to clear the previous AST.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="ASourceFile">
///   Null-terminated UTF-8 path to the user source file.
/// </param>
/// <returns>
///   True if the source was parsed successfully; False if errors occurred.
/// </returns>
function mor_parse_source(const AHandle: TMorHandle;
  const ASourceFile: PUTF8Char): Boolean;
  external METAMORF_DLL;

/// <summary>
///   Runs multi-pass semantic analysis on the parsed AST. This includes type
///   checking, symbol resolution, scope management, and module import
///   processing. After a successful call, the AST is fully typed and ready
///   for code generation or external traversal.
/// </summary>
/// <remarks>
///   Requires mor_parse_source to have been called successfully. Module
///   imports discovered during semantic analysis are automatically compiled
///   and attached to the master root as additional branches.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <returns>
///   True if semantic analysis succeeded; False if errors occurred.
/// </returns>
function mor_run_semantics(const AHandle: TMorHandle): Boolean;
  external METAMORF_DLL;

/// <summary>
///   Runs the .mor-defined code emitters (and any registered native emit
///   handlers) over all AST branches, producing .h and .cpp files in the
///   output directory. Module branches are emitted first, followed by the
///   main program branch so that the main program's build settings are
///   applied last.
/// </summary>
/// <remarks>
///   Requires mor_run_semantics to have been called successfully. If you
///   intend to perform your own code generation by walking the AST, skip this
///   step and mor_build entirely.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <returns>
///   True if emission succeeded; False if errors occurred.
/// </returns>
function mor_run_emitters(const AHandle: TMorHandle): Boolean;
  external METAMORF_DLL;

/// <summary>
///   Invokes the Zig/Clang build toolchain to compile the emitted C++ source
///   files into a native Win64 or Linux64 binary (executable, DLL, or static
///   library depending on the .mor grammar's build mode).
/// </summary>
/// <remarks>
///   Requires mor_run_emitters to have been called successfully. Reports
///   the target platform, build mode, and optimization level via the status
///   callback before starting the build.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AOutputPath">
///   Null-terminated UTF-8 path to the output directory. If empty, uses the
///   output path established during mor_run_emitters.
/// </param>
/// <param name="ARunMode">
///   Controls post-build behavior. MOR_RUN_NONE (0) builds only.
///   MOR_RUN_EXECUTE (1) builds and runs the binary. MOR_RUN_DEBUG (2)
///   builds and launches the interactive debugger (Win64 targets only).
/// </param>
/// <returns>
///   True if the build succeeded; False if errors occurred.
/// </returns>
function mor_build(const AHandle: TMorHandle;
  const AOutputPath: PUTF8Char; const ARunMode: Integer): Boolean;
  external METAMORF_DLL;

/// <summary>
///   One-shot convenience function that executes the entire compilation
///   pipeline: LoadMor, ParseSource, RunSemantics, RunEmitters, and Build
///   in sequence. Returns False on the first step that fails.
/// </summary>
/// <remarks>
///   Equivalent to calling each stepped function in order. For compiling
///   multiple source files against the same grammar, use the stepped
///   functions with mor_reset between runs to avoid re-parsing the
///   .mor file.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AMorFile">
///   Null-terminated UTF-8 path to the .mor grammar file.
/// </param>
/// <param name="ASourceFile">
///   Null-terminated UTF-8 path to the user source file.
/// </param>
/// <param name="AOutputPath">
///   Null-terminated UTF-8 path to the output directory.
/// </param>
/// <param name="ARunMode">
///   Controls post-build behavior. MOR_RUN_NONE (0) builds only.
///   MOR_RUN_EXECUTE (1) builds and runs the binary. MOR_RUN_DEBUG (2)
///   builds and launches the interactive debugger (Win64 targets only).
/// </param>
/// <returns>
///   True if all pipeline steps succeeded; False if any step failed.
/// </returns>
function mor_compile(const AHandle: TMorHandle;
  const AMorFile: PUTF8Char; const ASourceFile: PUTF8Char;
  const AOutputPath: PUTF8Char; const ARunMode: Integer): Boolean;
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// AST query
// ---------------------------------------------------------------------------

/// <summary>
///   Returns the master root node of the parsed AST. The master root has kind
///   'master.root' and contains one child branch per compiled source file
///   (the main program at index 0, imported modules at index 1+).
/// </summary>
/// <remarks>
///   Requires mor_parse_source to have been called successfully. The
///   returned node handle becomes invalid after mor_reset or
///   mor_destroy.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <returns>
///   An opaque TMorNode handle to the master root, or zero if no AST exists.
/// </returns>
function mor_get_master_root(
  const AHandle: TMorHandle): TMorNode;
  external METAMORF_DLL;

/// <summary>
///   Returns the kind string of an AST node (e.g. 'decl.program',
///   'stmt.print', 'expr.string_literal'). The kind determines how the node
///   should be interpreted and what attributes and children it carries.
/// </summary>
/// <remarks>
///   The returned PUTF8Char points into an internal buffer on the TMorHandle
///   and is valid only until the next string-returning call on the same
///   handle. Copy immediately with UTF8ToString() if needed.
/// </remarks>
/// <param name="AHandle">
///   The engine handle (needed to store the returned UTF-8 string).
/// </param>
/// <param name="ANode">
///   The node handle to query.
/// </param>
/// <returns>
///   Null-terminated UTF-8 node kind string.
/// </returns>
function mor_node_kind(const AHandle: TMorHandle;
  const ANode: TMorNode): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the value of a named attribute on an AST node. Attributes store
///   semantic data such as 'value' (literal value), 'identifier' (name),
///   'type_name' (resolved type), and 'source_name' (originating filename).
/// </summary>
/// <remarks>
///   Returns an empty string if the attribute does not exist. The returned
///   PUTF8Char is valid only until the next string-returning call on the same
///   handle.
/// </remarks>
/// <param name="AHandle">
///   The engine handle (needed to store the returned UTF-8 string).
/// </param>
/// <param name="ANode">
///   The node handle to query.
/// </param>
/// <param name="AAttrName">
///   Null-terminated UTF-8 attribute name.
/// </param>
/// <returns>
///   Null-terminated UTF-8 attribute value, or empty string if not found.
/// </returns>
function mor_node_get_attr(const AHandle: TMorHandle;
  const ANode: TMorNode; const AAttrName: PUTF8Char): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Tests whether a named attribute exists on an AST node.
/// </summary>
/// <param name="ANode">
///   The node handle to query.
/// </param>
/// <param name="AAttrName">
///   Null-terminated UTF-8 attribute name to test for.
/// </param>
/// <returns>
///   True if the attribute exists on the node; False otherwise.
/// </returns>
function mor_node_has_attr(const ANode: TMorNode;
  const AAttrName: PUTF8Char): Boolean;
  external METAMORF_DLL;

/// <summary>
///   Returns the number of child nodes attached to an AST node. Use with
///   mor_node_child to iterate all children.
/// </summary>
/// <param name="ANode">
///   The node handle to query.
/// </param>
/// <returns>
///   The number of children (zero or more).
/// </returns>
function mor_node_child_count(const ANode: TMorNode): Integer;
  external METAMORF_DLL;

/// <summary>
///   Returns the child node at the given zero-based index. Use
///   mor_node_child_count to determine valid index bounds.
/// </summary>
/// <param name="ANode">
///   The parent node handle.
/// </param>
/// <param name="AIndex">
///   Zero-based child index. Must be in the range
///   0..mor_node_child_count-1.
/// </param>
/// <returns>
///   An opaque TMorNode handle to the child node.
/// </returns>
function mor_node_child(const ANode: TMorNode;
  const AIndex: Integer): TMorNode;
  external METAMORF_DLL;

/// <summary>
///   Sets or creates a named attribute on an AST node. This can be used by
///   external semantic passes or emit handlers to annotate nodes with custom
///   metadata before or during code generation.
/// </summary>
/// <param name="ANode">
///   The node handle to modify.
/// </param>
/// <param name="AAttrName">
///   Null-terminated UTF-8 attribute name.
/// </param>
/// <param name="AValue">
///   Null-terminated UTF-8 attribute value.
/// </param>
procedure mor_node_set_attr(const ANode: TMorNode;
  const AAttrName: PUTF8Char; const AValue: PUTF8Char);
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Error query
// ---------------------------------------------------------------------------

/// <summary>
///   Returns the total number of diagnostics (hints, warnings, errors, and
///   fatals) accumulated during pipeline steps on this handle. Use as an
///   upper bound for indexing into metamorf_error_get_* functions.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <returns>
///   The number of diagnostics (zero or more).
/// </returns>
function mor_error_count(const AHandle: TMorHandle): Integer;
  external METAMORF_DLL;

/// <summary>
///   Tests whether any diagnostics with severity Error or Fatal have been
///   recorded on this handle. Equivalent to checking whether the pipeline
///   should stop.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <returns>
///   True if at least one error or fatal diagnostic exists; False otherwise.
/// </returns>
function mor_has_errors(const AHandle: TMorHandle): Boolean;
  external METAMORF_DLL;

/// <summary>
///   Clears all accumulated diagnostics on this handle, resetting the error
///   count to zero.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
procedure mor_clear_errors(const AHandle: TMorHandle);
  external METAMORF_DLL;

/// <summary>
///   Returns the maximum number of errors the engine will accumulate before
///   halting. The default is 1, meaning the pipeline stops after the first
///   error. Increase this for IDE-style workflows where you want to collect
///   multiple errors in a single pass.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <returns>
///   The current maximum error count.
/// </returns>
function mor_get_max_errors(const AHandle: TMorHandle): Integer;
  external METAMORF_DLL;

/// <summary>
///   Sets the maximum number of errors the engine will accumulate before
///   halting. The default is 1.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AMaxErrors">
///   The new maximum error count. Set to a higher value (e.g. 20) to collect
///   multiple errors before halting.
/// </param>
procedure mor_set_max_errors(const AHandle: TMorHandle;
  const AMaxErrors: Integer);
  external METAMORF_DLL;

/// <summary>
///   Returns the severity of the diagnostic at the given index as an integer
///   ordinal: 0 = Hint, 1 = Warning, 2 = Error, 3 = Fatal.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AIndex">
///   Zero-based index into the diagnostics list. Must be in the range
///   0..mor_error_count-1.
/// </param>
/// <returns>
///   Integer severity ordinal (0=Hint, 1=Warning, 2=Error, 3=Fatal).
/// </returns>
function mor_error_get_severity(const AHandle: TMorHandle;
  const AIndex: Integer): Integer;
  external METAMORF_DLL;

/// <summary>
///   Returns the error code string of the diagnostic at the given index
///   (e.g. 'E001', 'EA002', 'UL001').
/// </summary>
/// <remarks>
///   The returned PUTF8Char is valid only until the next string-returning
///   call on the same handle.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AIndex">
///   Zero-based index into the diagnostics list.
/// </param>
/// <returns>
///   Null-terminated UTF-8 error code string.
/// </returns>
function mor_error_get_code(const AHandle: TMorHandle;
  const AIndex: Integer): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the human-readable message of the diagnostic at the given index
///   (e.g. "File not found: 'hello.pas'").
/// </summary>
/// <remarks>
///   The returned PUTF8Char is valid only until the next string-returning
///   call on the same handle.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AIndex">
///   Zero-based index into the diagnostics list.
/// </param>
/// <returns>
///   Null-terminated UTF-8 error message string.
/// </returns>
function mor_error_get_message(const AHandle: TMorHandle;
  const AIndex: Integer): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the source filename associated with the diagnostic at the given
///   index. May be empty if the diagnostic has no source location (e.g.
///   pipeline precondition errors).
/// </summary>
/// <remarks>
///   The returned PUTF8Char is valid only until the next string-returning
///   call on the same handle.
/// </remarks>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AIndex">
///   Zero-based index into the diagnostics list.
/// </param>
/// <returns>
///   Null-terminated UTF-8 filename string, or empty if no location.
/// </returns>
function mor_error_get_filename(const AHandle: TMorHandle;
  const AIndex: Integer): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the one-based source line number of the diagnostic at the given
///   index. Returns zero if the diagnostic has no source location.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AIndex">
///   Zero-based index into the diagnostics list.
/// </param>
/// <returns>
///   One-based line number, or zero if no location.
/// </returns>
function mor_error_get_line(const AHandle: TMorHandle;
  const AIndex: Integer): Integer;
  external METAMORF_DLL;

/// <summary>
///   Returns the one-based source column number of the diagnostic at the
///   given index. Returns zero if the diagnostic has no source location.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AIndex">
///   Zero-based index into the diagnostics list.
/// </param>
/// <returns>
///   One-based column number, or zero if no location.
/// </returns>
function mor_error_get_col(const AHandle: TMorHandle;
  const AIndex: Integer): Integer;
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------

/// <summary>
///   Launches the DAP debug server for a previously built executable. Call
///   this after a successful mor_build with MOR_RUN_NONE to debug the binary
///   interactively. Only supported for Win64 targets.
/// </summary>
/// <param name="AHandle">
///   The engine handle returned by mor_create.
/// </param>
/// <param name="AExePath">
///   Null-terminated UTF-8 path to the executable to debug.
/// </param>
/// <param name="APort">
///   TCP port for the DAP server (default: 4711).
/// </param>
/// <returns>
///   True if the debug session completed successfully; False on error.
/// </returns>
function mor_debug_exe(const AHandle: TMorHandle;
  const AExePath: PUTF8Char; const APort: Integer): Boolean;
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Build configuration
// ---------------------------------------------------------------------------

/// <summary>
///   Sets the target platform for compilation. Use MOR_TARGET_* constants.
/// </summary>
procedure mor_set_target(const AHandle: TMorHandle;
  const ATarget: Integer);
  external METAMORF_DLL;

/// <summary>
///   Returns the current target platform as a MOR_TARGET_* integer.
/// </summary>
function mor_get_target(const AHandle: TMorHandle): Integer;
  external METAMORF_DLL;

/// <summary>
///   Sets the optimization level. Use MOR_OPT_* constants.
/// </summary>
procedure mor_set_optimize_level(const AHandle: TMorHandle;
  const ALevel: Integer);
  external METAMORF_DLL;

/// <summary>
///   Returns the current optimization level as a MOR_OPT_* integer.
/// </summary>
function mor_get_optimize_level(const AHandle: TMorHandle): Integer;
  external METAMORF_DLL;

/// <summary>
///   Sets the subsystem type (console or GUI). Use MOR_SUBSYSTEM_* constants.
/// </summary>
procedure mor_set_subsystem(const AHandle: TMorHandle;
  const ASubsystem: Integer);
  external METAMORF_DLL;

/// <summary>
///   Returns the current subsystem type as a MOR_SUBSYSTEM_* integer.
/// </summary>
function mor_get_subsystem(const AHandle: TMorHandle): Integer;
  external METAMORF_DLL;

/// <summary>
///   Sets the build mode (exe, lib, or dll). Use MOR_BUILD_* constants.
/// </summary>
procedure mor_set_build_mode(const AHandle: TMorHandle;
  const AMode: Integer);
  external METAMORF_DLL;

/// <summary>
///   Returns the current build mode as a MOR_BUILD_* integer.
/// </summary>
function mor_get_build_mode(const AHandle: TMorHandle): Integer;
  external METAMORF_DLL;

/// <summary>
///   Sets a preprocessor define. Pass nil for AValue to set a define
///   without a value; pass a non-nil PUTF8Char to set a define with a value.
/// </summary>
procedure mor_set_define(const AHandle: TMorHandle;
  const ADefineName: PUTF8Char; const AValue: PUTF8Char);
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Toolchain paths
// ---------------------------------------------------------------------------

/// <summary>
///   Sets the root path to the Zig/Clang toolchain.
/// </summary>
procedure mor_set_toolchain_path(const AHandle: TMorHandle;
  const APath: PUTF8Char);
  external METAMORF_DLL;

/// <summary>
///   Returns the current toolchain root path.
/// </summary>
function mor_get_toolchain_path(const AHandle: TMorHandle): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the path to the Zig executable directory, optionally combined
///   with AFilename.
/// </summary>
function mor_get_zig_path(const AHandle: TMorHandle;
  const AFilename: PUTF8Char): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the path to the Metamorf runtime directory, optionally combined
///   with AFilename.
/// </summary>
function mor_get_runtime_path(const AHandle: TMorHandle;
  const AFilename: PUTF8Char): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the path to the libs directory, optionally combined with
///   AFilename.
/// </summary>
function mor_get_libs_path(const AHandle: TMorHandle;
  const AFilename: PUTF8Char): PUTF8Char;
  external METAMORF_DLL;

/// <summary>
///   Returns the path to the assets directory, optionally combined with
///   AFilename.
/// </summary>
function mor_get_assets_path(const AHandle: TMorHandle;
  const AFilename: PUTF8Char): PUTF8Char;
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Process/build control
// ---------------------------------------------------------------------------

/// <summary>
///   Returns the exit code of the last process launched by mor_build with
///   MOR_RUN_EXECUTE.
/// </summary>
function mor_get_last_exit_code(const AHandle: TMorHandle): Integer;
  external METAMORF_DLL;

// ---------------------------------------------------------------------------
// Advanced pipeline
// ---------------------------------------------------------------------------

/// <summary>
///   Loads and configures a .mor grammar without compiling any user source.
///   After a successful call, the engine is ready for mor_parse_source.
///   This is equivalent to calling mor_load_mor but through the Engine's
///   SetupLanguage method which also validates the .mor AST.
/// </summary>
function mor_setup_language(const AHandle: TMorHandle;
  const AMorFile: PUTF8Char): Boolean;
  external METAMORF_DLL;

/// <summary>
///   Compiles user source using a baked (embedded) AST resource. The baked
///   AST is loaded from RT_RCDATA, the interpreter runs setup, and then the
///   user source is compiled through the standard pipeline.
/// </summary>
procedure mor_compile_baked(const AHandle: TMorHandle;
  const ASourceFile: PUTF8Char; const AOutputPath: PUTF8Char;
  const AAutoRun: Boolean);
  external METAMORF_DLL;


implementation

end.
