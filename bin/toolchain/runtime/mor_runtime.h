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

#ifndef MOR_RUNTIME_H
#define MOR_RUNTIME_H

#include <string>
#include <cstdint>
#include <algorithm>
#include <type_traits>

/*******************************************************************************
 * Exception Codes (Platform-Independent)
 ******************************************************************************/

#define MOR_EXC_NONE               0   // No exception
#define MOR_EXC_SOFTWARE           1   // Software exception (raiseexception)
#define MOR_EXC_DIV_BY_ZERO        2   // Integer or float divide by zero
#define MOR_EXC_ACCESS_VIOLATION   3   // Invalid memory access
#define MOR_EXC_STACK_OVERFLOW     4   // Stack overflow
#define MOR_EXC_INTEGER_OVERFLOW   5   // Integer overflow
#define MOR_EXC_ILLEGAL_INSTRUCTION 6  // Invalid CPU instruction
#define MOR_EXC_BUS_ERROR          7   // Bus error
#define MOR_EXC_UNKNOWN            99  // Unknown hardware exception

/*******************************************************************************
 * Exception Handling API
 ******************************************************************************/

/** Function pointer type for try blocks. */
typedef void (*PaxTryFn)(void* context);

/**
 * Execute a try block with full exception handling.
 * Catches BOTH software exceptions AND hardware exceptions.
 * @param try_fn  Function pointer to the try block code
 * @param context User context passed to try_fn (can be NULL)
 * @return 0 = no exception, 1 = software exception, 2 = hardware exception
 */
int32_t mor_try_call(PaxTryFn try_fn, void* context);

/**
 * Throw a software exception.
 * @param code  Exception code (user-defined)
 * @param msg   Exception message
 */
void mor_throw(int32_t code, const char* msg);

/**
 * Get the code of the last caught exception.
 * @return Exception code, or 0 if no exception
 */
int32_t mor_exc_code();

/**
 * Get the message of the last caught exception.
 * @return Exception message, or empty string if no exception
 */
const char* mor_exc_msg();

/**
 * Clear the exception state.
 */
void mor_exc_clear();

/*******************************************************************************
 * Console Initialization
 ******************************************************************************/

/**
 * Initialize console for UTF-8 output.
 * Call at the start of main() for exe modules.
 */
void mor_initconsole();

/*******************************************************************************
 * String Conversion
 ******************************************************************************/

/**
 * Convert wide string (UTF-16) to UTF-8.
 * @param s  Wide string to convert
 * @return UTF-8 encoded string
 */
std::string mor_utf8(const std::wstring& s);

/**
 * Return length of a container (.size()) or C-style array (element count).
 */
template<typename T>
auto mor_len(const T& container) -> decltype(container.size()) {
    return container.size();
}

template<typename T, size_t N>
constexpr size_t mor_len(const T(&)[N]) {
    return N;
}

/*******************************************************************************
 * Command Line API
 ******************************************************************************/

/**
 * Initialize command line arguments (call at program start).
 * @param argc Argument count from main()
 * @param argv Argument vector from main()
 */
void mor_init_args(int argc, char** argv);

/**
 * Get number of command line arguments (excludes program name).
 * @return Number of arguments (argc - 1)
 */
int32_t mor_paramcount();

/**
 * Get command line argument by index.
 * @param index 0 = program name, 1..n = arguments
 * @return Pointer to argument string (valid for program lifetime)
 */
const char* mor_paramstr(int32_t index);

/*******************************************************************************
 * Memory Management
 ******************************************************************************/

/**
 * Allocate memory.
 * @param size Number of bytes to allocate
 * @return Pointer to allocated memory, or nullptr on failure
 */
void* mor_getmem(size_t size);

/**
 * Resize previously allocated memory.
 * @param ptr Pointer to memory block (may be nullptr)
 * @param size New size in bytes
 * @return Pointer to resized memory, or nullptr on failure
 */
void* mor_resizemem(void* ptr, size_t size);

/**
 * Free previously allocated memory.
 * @param ptr Pointer to memory block (may be nullptr)
 */
void mor_freemem(void* ptr);

/**
 * Create (allocate and default-construct) a typed object.
 * Works for both classes and records. The variable must be a pointer type.
 * @param p Pointer variable to receive the new instance
 */
#define mor_create(p) ((p) = new std::remove_pointer_t<decltype(p)>())

/**
 * Destroy (delete and null) a typed object.
 * Works for both classes and records. Safe to call on nullptr.
 * @param p Pointer variable to delete and set to nullptr
 */
#define mor_destroy(p) do { delete (p); (p) = nullptr; } while(0)

/*******************************************************************************
 * Unit Testing API
 ******************************************************************************/

#define MOR_MAX_TESTS 256
#define MOR_ERROR_BUFFER_SIZE 4096

/**
 * Test function signature.
 */
typedef void (*PaxTestFn)(void);

/**
 * Register a test function.
 * @param name  Test name (displayed in output)
 * @param func  Test function pointer
 * @param file  Source file path
 * @param line  Source line number
 * @return 1 on success, 0 if max tests exceeded
 */
int32_t mor_test_register(const char* name, PaxTestFn func, const char* file, int32_t line);

/**
 * Run all registered tests.
 * @return 0 if all tests pass, 1 if any test fails
 */
int32_t mor_test_run_all(void);

/*******************************************************************************
 * Test Assertion Functions
 *
 * Called by generated code with Mor source file/line for error reporting.
 * Assertions continue after failure (all failures accumulate per test).
 ******************************************************************************/

void mor_test_assert_impl(bool condition, const char* file, int32_t line);
void mor_test_assert_true_impl(bool condition, const char* file, int32_t line);
void mor_test_assert_false_impl(bool condition, const char* file, int32_t line);
void mor_test_assert_equal_int_impl(int64_t expected, int64_t actual, const char* file, int32_t line);
void mor_test_assert_equal_uint_impl(uint64_t expected, uint64_t actual, const char* file, int32_t line);
void mor_test_assert_equal_float_impl(double expected, double actual, const char* file, int32_t line);
void mor_test_assert_equal_str_impl(const char* expected, const char* actual, const char* file, int32_t line);
void mor_test_assert_equal_bool_impl(bool expected, bool actual, const char* file, int32_t line);
void mor_test_assert_equal_ptr_impl(void* expected, void* actual, const char* file, int32_t line);
void mor_test_assert_nil_impl(void* ptr, const char* file, int32_t line);
void mor_test_assert_not_nil_impl(void* ptr, const char* file, int32_t line);
void mor_test_fail_impl(const char* message, const char* file, int32_t line);

/*******************************************************************************
 * Variadic Arguments Support
 ******************************************************************************/

#include <cstdarg>

/**
 * Type-safe variadic arguments wrapper.
 * Provides object-style access to variadic function arguments.
 * Automatically cleans up va_list when destroyed.
 *
 * Usage in Pax:
 *   routine myFunc(const count: int32; ...): int32;
 *   begin
 *     x := varargs.next(int32);   // get next arg as int32
 *     args2 := varargs.copy();    // save cursor position
 *   end;
 */
struct mor_varargs {
    va_list ap;
    bool active = false;
    int32_t count = 0;

    /**
     * Get next argument as specified type and advance cursor.
     * @tparam T The type to retrieve
     * @return The next argument cast to type T
     */
    template<typename T>
    T next() {
        return va_arg(ap, T);
    }

    /**
     * Copy current cursor position for multi-pass iteration.
     * @return New mor_varargs with copied cursor position
     */
    mor_varargs copy() {
        mor_varargs result;
        va_copy(result.ap, ap);
        result.active = true;
        result.count = count;
        return result;
    }

    /**
     * Destructor - automatically calls va_end if active.
     */
    ~mor_varargs() {
        if (active) va_end(ap);
    }
};

/**
 * Initialize a mor_varargs from the hidden count parameter.
 * The compiler injects __mor_vararg_count as a hidden first parameter.
 * @param va The mor_varargs variable to initialize
 * @param count_param The hidden count parameter (__mor_vararg_count)
 */
#define mor_varargs_start(va, count_param) \
    va_start((va).ap, count_param); \
    (va).count = count_param; \
    (va).active = true


/*******************************************************************************
 * Set Support (bitmask-based, up to 64 elements with base offset)
 ******************************************************************************/

/**
 * MorSet - Bitmask-based set type supporting up to 64 elements.
 *
 * Elements are stored relative to a base offset, allowing sets like
 * set of 100..163 to work within a 64-bit bitmask.
 *
 * Arithmetic operators are overloaded for set semantics:
 *   + = union (bitwise OR)
 *   * = intersection (bitwise AND)
 *   - = difference (AND NOT)
 */
struct MorSet {
  uint64_t bits;
  int32_t base;

  MorSet() : bits(0), base(0) {}
  MorSet(uint64_t b, int32_t base) : bits(b), base(base) {}

  // Union: reconcile bases and OR
  MorSet operator+(const MorSet& rhs) const {
    if (bits == 0) return rhs;
    if (rhs.bits == 0) return *this;
    int32_t nb = std::min(base, rhs.base);
    return MorSet((bits << (base - nb)) | (rhs.bits << (rhs.base - nb)), nb);
  }

  // Intersection: reconcile bases and AND
  MorSet operator*(const MorSet& rhs) const {
    if (bits == 0 || rhs.bits == 0) return MorSet();
    int32_t nb = std::min(base, rhs.base);
    return MorSet((bits << (base - nb)) & (rhs.bits << (rhs.base - nb)), nb);
  }

  // Difference: reconcile bases and AND NOT
  MorSet operator-(const MorSet& rhs) const {
    if (bits == 0) return MorSet();
    if (rhs.bits == 0) return *this;
    int32_t nb = std::min(base, rhs.base);
    return MorSet((bits << (base - nb)) & ~(rhs.bits << (rhs.base - nb)), nb);
  }

  // Equality: reconcile bases and compare
  bool operator==(const MorSet& rhs) const {
    if (bits == 0 && rhs.bits == 0) return true;
    if (bits == 0 || rhs.bits == 0) return false;
    int32_t nb = std::min(base, rhs.base);
    return (bits << (base - nb)) == (rhs.bits << (rhs.base - nb));
  }
  bool operator!=(const MorSet& rhs) const { return !(*this == rhs); }

  // Assignment from uint64_t (base-0 set)
  MorSet& operator=(uint64_t b) { bits = b; base = 0; return *this; }

  // Conversion to integer types for casting
  explicit operator int8_t() const { return static_cast<int8_t>(bits); }
  explicit operator int16_t() const { return static_cast<int16_t>(bits); }
  explicit operator int32_t() const { return static_cast<int32_t>(bits); }
  explicit operator int64_t() const { return static_cast<int64_t>(bits); }
  explicit operator uint8_t() const { return static_cast<uint8_t>(bits); }
  explicit operator uint16_t() const { return static_cast<uint16_t>(bits); }
  explicit operator uint32_t() const { return static_cast<uint32_t>(bits); }
  explicit operator uint64_t() const { return bits; }
};

/**
 * Create a single-element set from an element value.
 * Elements 0..63 use base=0 (traditional bitmask).
 * Elements >= 64 use element value as base (offset sets).
 */
inline MorSet mor_elem(int32_t val) {
  if (val < 64) {
    return MorSet(1ULL << val, 0);
  } else {
    return MorSet(1ULL, val);
  }
}

/**
 * Create a set for a range of elements [low..high].
 * Ranges starting < 64 use base=0; ranges >= 64 use low as base.
 */
inline MorSet mor_range(int32_t low, int32_t high) {
  int32_t b = (low < 64) ? 0 : low;
  uint64_t r = 0;
  for (int32_t i = low; i <= high; i++) r |= (1ULL << (i - b));
  return MorSet(r, b);
}

/**
 * Test whether an element is in a set.
 */
inline bool mor_contains(MorSet s, int32_t elem) {
  int32_t bit = elem - s.base;
  if (bit < 0 || bit >= 64) return false;
  return (s.bits & (1ULL << bit)) != 0;
}

#endif /* MOR_RUNTIME_H */
