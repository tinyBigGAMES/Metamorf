/*******************************************************************************
 * mor_runtime.h - Metamorf Programming Language Runtime Header
 *
 * Copyright (c) 2025-present tinyBigGAMES LLC, All Rights Reserved.
 * All Rights Reserved.
 *
 * https://metamorf.dev
 *
 * Minimal C++ runtime support for Metamorf language features.
 ******************************************************************************/

#include "mor_runtime.h"

#include <locale>
#include <codecvt>
#include <cstdlib>
#include <csetjmp>
#include <cstring>
#include <exception>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #include <io.h>
    #include <fcntl.h>
#else
    #include <signal.h>
#endif

/*******************************************************************************
 * Exception Handling Implementation
 ******************************************************************************/

/** Internal C++ exception type for software exceptions. */
struct PaxException {
    int32_t code;
    const char* msg;
};

// Thread-local exception state
static thread_local int32_t g_exc_code = 0;
static thread_local const char* g_exc_msg = nullptr;
static thread_local jmp_buf* g_jmp_target = nullptr;

#ifdef _WIN32

// Check if exception code is a real hardware fault
static bool IsHardwareException(DWORD code) {
    switch (code) {
        case EXCEPTION_ACCESS_VIOLATION:
        case EXCEPTION_INT_DIVIDE_BY_ZERO:
        case EXCEPTION_FLT_DIVIDE_BY_ZERO:
        case EXCEPTION_STACK_OVERFLOW:
        case EXCEPTION_INT_OVERFLOW:
        case EXCEPTION_ILLEGAL_INSTRUCTION:
        case EXCEPTION_PRIV_INSTRUCTION:
        case EXCEPTION_IN_PAGE_ERROR:
        case EXCEPTION_FLT_INVALID_OPERATION:
        case EXCEPTION_FLT_OVERFLOW:
        case EXCEPTION_FLT_UNDERFLOW:
            return true;
        default:
            return false;
    }
}

// Vectored Exception Handler for Windows
static LONG WINAPI PaxVehHandler(PEXCEPTION_POINTERS ep) {
    DWORD code = ep->ExceptionRecord->ExceptionCode;
    
    if (g_jmp_target == nullptr)
        return EXCEPTION_CONTINUE_SEARCH;
    
    if (!IsHardwareException(code))
        return EXCEPTION_CONTINUE_SEARCH;
    
    // Map Windows exception codes to Mor codes
    switch (code) {
        case EXCEPTION_ACCESS_VIOLATION:
        case EXCEPTION_IN_PAGE_ERROR:
            g_exc_code = MOR_EXC_ACCESS_VIOLATION;
            g_exc_msg = "Access violation";
            break;
        case EXCEPTION_INT_DIVIDE_BY_ZERO:
        case EXCEPTION_FLT_DIVIDE_BY_ZERO:
            g_exc_code = MOR_EXC_DIV_BY_ZERO;
            g_exc_msg = "Divide by zero";
            break;
        case EXCEPTION_STACK_OVERFLOW:
            g_exc_code = MOR_EXC_STACK_OVERFLOW;
            g_exc_msg = "Stack overflow";
            break;
        case EXCEPTION_INT_OVERFLOW:
        case EXCEPTION_FLT_OVERFLOW:
        case EXCEPTION_FLT_UNDERFLOW:
            g_exc_code = MOR_EXC_INTEGER_OVERFLOW;
            g_exc_msg = "Numeric overflow";
            break;
        case EXCEPTION_ILLEGAL_INSTRUCTION:
        case EXCEPTION_PRIV_INSTRUCTION:
            g_exc_code = MOR_EXC_ILLEGAL_INSTRUCTION;
            g_exc_msg = "Illegal instruction";
            break;
        default:
            g_exc_code = MOR_EXC_UNKNOWN;
            g_exc_msg = "Hardware exception";
            break;
    }
    
    longjmp(*g_jmp_target, 2);
    return EXCEPTION_CONTINUE_SEARCH;
}

static PVOID g_veh_handle = nullptr;

static void mor_install_hw_handler() {
    if (g_veh_handle == nullptr) {
        g_veh_handle = AddVectoredExceptionHandler(1, PaxVehHandler);
    }
}

#else

// Signal handler for POSIX systems
static void mor_signal_handler(int sig) {
    if (g_jmp_target == nullptr)
        return;
    
    switch (sig) {
        case SIGFPE:
            g_exc_code = MOR_EXC_DIV_BY_ZERO;
            g_exc_msg = "Divide by zero";
            break;
        case SIGSEGV:
            g_exc_code = MOR_EXC_ACCESS_VIOLATION;
            g_exc_msg = "Segmentation fault";
            break;
        case SIGBUS:
            g_exc_code = MOR_EXC_BUS_ERROR;
            g_exc_msg = "Bus error";
            break;
        case SIGILL:
            g_exc_code = MOR_EXC_ILLEGAL_INSTRUCTION;
            g_exc_msg = "Illegal instruction";
            break;
        default:
            g_exc_code = MOR_EXC_UNKNOWN;
            g_exc_msg = "Hardware exception";
            break;
    }
    
    longjmp(*g_jmp_target, 2);
}

static void mor_install_hw_handler() {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = mor_signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    
    sigaction(SIGFPE, &sa, nullptr);
    sigaction(SIGSEGV, &sa, nullptr);
    sigaction(SIGBUS, &sa, nullptr);
    sigaction(SIGILL, &sa, nullptr);
}

#endif

int32_t mor_try_call(PaxTryFn try_fn, void* context) {
    mor_install_hw_handler();
    
    jmp_buf buf;
    jmp_buf* old_target = g_jmp_target;
    g_jmp_target = &buf;
    
    int jmp_result = setjmp(buf);
    
    if (jmp_result == 0) {
        try {
            try_fn(context);
            g_jmp_target = old_target;
            return 0;  // No exception
        } 
        catch (const PaxException& e) {
            g_exc_code = e.code;
            g_exc_msg = e.msg;
            g_jmp_target = old_target;
            return 1;  // Software exception
        } 
        catch (const std::exception& e) {
            g_exc_code = -1;
            g_exc_msg = e.what();
            g_jmp_target = old_target;
            return 1;  // Software exception
        } 
        catch (...) {
            g_exc_code = -1;
            g_exc_msg = "Unknown C++ exception";
            g_jmp_target = old_target;
            return 1;  // Software exception
        }
    } 
    else {
        g_jmp_target = old_target;
        return 2;  // Hardware exception
    }
}

void mor_throw(int32_t code, const char* msg) {
    throw PaxException{code, msg};
}

int32_t mor_exc_code() {
    return g_exc_code;
}

const char* mor_exc_msg() {
    return g_exc_msg ? g_exc_msg : "";
}

void mor_exc_clear() {
    g_exc_code = 0;
    g_exc_msg = nullptr;
}

/*******************************************************************************
 * Console Initialization
 ******************************************************************************/

void mor_initconsole() {
#ifdef _WIN32
    // Set console to UTF-8
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
    
    // Set stdout/stderr to binary mode for UTF-8
    _setmode(_fileno(stdout), _O_BINARY);
    _setmode(_fileno(stderr), _O_BINARY);
    
    // Enable ANSI escape sequences (for colors, etc.)
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hOut != INVALID_HANDLE_VALUE) {
        DWORD dwMode = 0;
        if (GetConsoleMode(hOut, &dwMode)) {
            dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            SetConsoleMode(hOut, dwMode);
        }
    }
#endif
}

/*******************************************************************************
 * String Conversion
 ******************************************************************************/

std::string mor_utf8(const std::wstring& s) {
    if (s.empty()) {
        return std::string();
    }
    
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    return converter.to_bytes(s);
}

/*******************************************************************************
 * Command Line API
 ******************************************************************************/

static int g_argc = 0;
static char** g_argv = nullptr;

void mor_init_args(int argc, char** argv) {
    g_argc = argc;
    g_argv = argv;
}

int32_t mor_paramcount() {
    return g_argc > 0 ? g_argc - 1 : 0;
}

const char* mor_paramstr(int32_t index) {
    if (index < 0 || index >= g_argc || g_argv == nullptr) {
        return "";
    }
    return g_argv[index];
}

/*******************************************************************************
 * Memory Management
 ******************************************************************************/

void* mor_getmem(size_t size) {
    return std::malloc(size);
}

void* mor_resizemem(void* ptr, size_t size) {
    return std::realloc(ptr, size);
}

void mor_freemem(void* ptr) {
    std::free(ptr);
}

/*******************************************************************************
 * Unit Testing Implementation
 ******************************************************************************/

struct PaxTestInfo {
    const char* name;
    PaxTestFn func;
    const char* file;
    int32_t line;
};

static PaxTestInfo mor_tests[MOR_MAX_TESTS];
static int mor_test_count = 0;
static bool mor_test_failed = false;
static char mor_test_error_buffer[MOR_ERROR_BUFFER_SIZE];
static int mor_test_error_pos = 0;

int32_t mor_test_register(const char* name, PaxTestFn func, const char* file, int32_t line) {
    if (mor_test_count >= MOR_MAX_TESTS) {
        std::fprintf(stderr, "ERROR: Maximum test count (%d) exceeded\n", MOR_MAX_TESTS);
        return 0;
    }
    mor_tests[mor_test_count].name = name;
    mor_tests[mor_test_count].func = func;
    mor_tests[mor_test_count].file = file;
    mor_tests[mor_test_count].line = line;
    mor_test_count++;
    return 1;
}

int32_t mor_test_run_all(void) {
    int passed = 0;
    int failed = 0;
    
    // Box-drawing header (UTF-8 encoded)
    std::printf("\n");
    std::printf("\xE2\x95\x94");  // ╔
    for (int i = 0; i < 62; i++) std::printf("\xE2\x95\x90");  // ═
    std::printf("\xE2\x95\x97\n");  // ╗
    
    std::printf("\xE2\x95\x91                     Mor Unit Test Runner                     \xE2\x95\x91\n");  // ║...║
    
    std::printf("\xE2\x95\x9A");  // ╚
    for (int i = 0; i < 62; i++) std::printf("\xE2\x95\x90");  // ═
    std::printf("\xE2\x95\x9D\n");  // ╝
    
    std::printf("\n");
    std::printf("Running %d test(s)...\n\n", mor_test_count);
    
    // Run each test
    for (int i = 0; i < mor_test_count; i++) {
        // Reset test state
        mor_test_failed = false;
        mor_test_error_buffer[0] = '\0';
        mor_test_error_pos = 0;
        
        // Run the test
        mor_tests[i].func();
        
        // Report result
        if (mor_test_failed) {
            std::printf("\xE2\x9D\x8C FAIL: %s\n", mor_tests[i].name);  // ❌
            if (mor_test_error_buffer[0] != '\0') {
                std::printf("%s", mor_test_error_buffer);
            }
            failed++;
        } else {
            std::printf("\xE2\x9C\x85 PASS: %s\n", mor_tests[i].name);  // ✅
            passed++;
        }
    }
    
    // Results footer
    std::printf("\n");
    for (int i = 0; i < 64; i++) std::printf("\xE2\x95\x90");  // ═
    std::printf("\n");
    std::printf("Results: %d passed, %d failed, %d total\n", passed, failed, mor_test_count);
    for (int i = 0; i < 64; i++) std::printf("\xE2\x95\x90");  // ═
    std::printf("\n");
    
    return (failed > 0) ? 1 : 0;
}

/*******************************************************************************
 * Test Assertion Implementations
 ******************************************************************************/

void mor_test_assert_impl(bool condition, const char* file, int32_t line) {
    if (!condition) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssert failed at %s:%d\n", file, line);  // 🔴
    }
}

void mor_test_assert_true_impl(bool condition, const char* file, int32_t line) {
    if (!condition) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertTrue failed at %s:%d: expected TRUE, got FALSE\n", file, line);
    }
}

void mor_test_assert_false_impl(bool condition, const char* file, int32_t line) {
    if (condition) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertFalse failed at %s:%d: expected FALSE, got TRUE\n", file, line);
    }
}

void mor_test_assert_equal_int_impl(int64_t expected, int64_t actual, const char* file, int32_t line) {
    if (expected != actual) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertEqualInt failed at %s:%d: expected %lld, got %lld\n", 
            file, line, (long long)expected, (long long)actual);
    }
}

void mor_test_assert_equal_uint_impl(uint64_t expected, uint64_t actual, const char* file, int32_t line) {
    if (expected != actual) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertEqualUInt failed at %s:%d: expected %llu, got %llu\n", 
            file, line, (unsigned long long)expected, (unsigned long long)actual);
    }
}

void mor_test_assert_equal_float_impl(double expected, double actual, const char* file, int32_t line) {
    double diff = expected - actual;
    if (diff < 0) diff = -diff;
    
    // Use relative epsilon for larger values, absolute for small
    double epsilon = (expected != 0.0) ? 1e-9 * (expected < 0 ? -expected : expected) : 1e-9;
    
    if (diff > epsilon) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertEqualFloat failed at %s:%d: expected %g, got %g\n", 
            file, line, expected, actual);
    }
}

void mor_test_assert_equal_str_impl(const char* expected, const char* actual, const char* file, int32_t line) {
    // Both NULL is equal
    if (expected == nullptr && actual == nullptr) {
        return;
    }
    
    // One NULL, one not, or different strings
    if (expected == nullptr || actual == nullptr || std::strcmp(expected, actual) != 0) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertEqualStr failed at %s:%d: expected \"%s\", got \"%s\"\n", 
            file, line, expected ? expected : "(null)", actual ? actual : "(null)");
    }
}

void mor_test_assert_equal_bool_impl(bool expected, bool actual, const char* file, int32_t line) {
    if (expected != actual) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertEqualBool failed at %s:%d: expected %s, got %s\n", 
            file, line, expected ? "TRUE" : "FALSE", actual ? "TRUE" : "FALSE");
    }
}

void mor_test_assert_equal_ptr_impl(void* expected, void* actual, const char* file, int32_t line) {
    if (expected != actual) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertEqualPtr failed at %s:%d: expected %p, got %p\n", 
            file, line, expected, actual);
    }
}

void mor_test_assert_nil_impl(void* ptr, const char* file, int32_t line) {
    if (ptr != nullptr) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertNil failed at %s:%d: expected NIL, got %p\n", 
            file, line, ptr);
    }
}

void mor_test_assert_not_nil_impl(void* ptr, const char* file, int32_t line) {
    if (ptr == nullptr) {
        mor_test_failed = true;
        mor_test_error_pos += std::snprintf(
            mor_test_error_buffer + mor_test_error_pos,
            MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
            "  \xF0\x9F\x94\xB4 TestAssertNotNil failed at %s:%d: expected not NIL\n", 
            file, line);
    }
}

void mor_test_fail_impl(const char* message, const char* file, int32_t line) {
    mor_test_failed = true;
    mor_test_error_pos += std::snprintf(
        mor_test_error_buffer + mor_test_error_pos,
        MOR_ERROR_BUFFER_SIZE - mor_test_error_pos,
        "  \xF0\x9F\x94\xB4 TestFail at %s:%d: %s\n", 
        file, line, message ? message : "(no message)");
}
