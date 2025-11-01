//! ZigX Runtime Library
//!
//! This module provides utilities for Zig code that will be called from Python.
//! It includes GIL management, error handling, and type conversion utilities.
//!
//! Usage in user code:
//! ```zig
//! const zigx = @import("zigx");
//!
//! pub export fn my_function() i32 {
//!     return zigx.withGilReleased(computeHeavy);
//! }
//! ```

const std = @import("std");

/// Opaque type representing Python's GIL state
pub const PyGILState_STATE = enum(c_int) {
    LOCKED = 0,
    UNLOCKED = 1,
};

/// Python thread state - opaque pointer
pub const PyThreadState = opaque {};

/// Function pointers for Python C API
/// These are loaded dynamically at runtime
pub const PythonAPI = struct {
    PyGILState_Ensure: ?*const fn () callconv(.C) PyGILState_STATE = null,
    PyGILState_Release: ?*const fn (PyGILState_STATE) callconv(.C) void = null,
    PyEval_SaveThread: ?*const fn () callconv(.C) ?*PyThreadState = null,
    PyEval_RestoreThread: ?*const fn (?*PyThreadState) callconv(.C) void = null,
    Py_IsInitialized: ?*const fn () callconv(.C) c_int = null,

    var global: ?PythonAPI = null;
    var init_attempted: bool = false;

    /// Initialize the Python API by loading function pointers
    /// This is called automatically on first use
    pub fn init() !*PythonAPI {
        if (global != null) return &global.?;
        if (init_attempted) return error.PythonNotFound;

        init_attempted = true;
        global = PythonAPI{};

        // Try to load Python library
        const lib = std.DynLib.open(getPythonLibName()) catch {
            global = null;
            return error.PythonNotFound;
        };

        global.?.PyGILState_Ensure = lib.lookup(@TypeOf(global.?.PyGILState_Ensure), "PyGILState_Ensure");
        global.?.PyGILState_Release = lib.lookup(@TypeOf(global.?.PyGILState_Release), "PyGILState_Release");
        global.?.PyEval_SaveThread = lib.lookup(@TypeOf(global.?.PyEval_SaveThread), "PyEval_SaveThread");
        global.?.PyEval_RestoreThread = lib.lookup(@TypeOf(global.?.PyEval_RestoreThread), "PyEval_RestoreThread");
        global.?.Py_IsInitialized = lib.lookup(@TypeOf(global.?.Py_IsInitialized), "Py_IsInitialized");

        return &global.?;
    }

    fn getPythonLibName() [:0]const u8 {
        return switch (@import("builtin").os.tag) {
            .windows => "python3.dll",
            .macos => "libpython3.dylib",
            else => "libpython3.so",
        };
    }
};

/// RAII guard for GIL acquisition
/// Acquires the GIL on construction, releases on destruction
pub const GilGuard = struct {
    state: PyGILState_STATE,
    api: *PythonAPI,

    pub fn acquire() !GilGuard {
        const api = try PythonAPI.init();
        if (api.PyGILState_Ensure) |ensure| {
            return GilGuard{
                .state = ensure(),
                .api = api,
            };
        }
        return error.GilNotAvailable;
    }

    pub fn release(self: GilGuard) void {
        if (self.api.PyGILState_Release) |rel| {
            rel(self.state);
        }
    }
};

/// RAII guard for releasing the GIL
/// Releases the GIL on construction, reacquires on destruction
/// Use this for long-running computations to allow other Python threads to run
pub const GilReleaseGuard = struct {
    thread_state: ?*PyThreadState,
    api: *PythonAPI,

    pub fn release() !GilReleaseGuard {
        const api = try PythonAPI.init();
        if (api.PyEval_SaveThread) |save| {
            return GilReleaseGuard{
                .thread_state = save(),
                .api = api,
            };
        }
        return error.GilNotAvailable;
    }

    pub fn reacquire(self: GilReleaseGuard) void {
        if (self.api.PyEval_RestoreThread) |restore| {
            restore(self.thread_state);
        }
    }
};

/// Execute a function with the GIL released
/// This allows other Python threads to run during the computation
pub fn withGilReleased(comptime func: anytype, args: anytype) @TypeOf(@call(.auto, func, args)) {
    const guard = GilReleaseGuard.release() catch {
        // If GIL management isn't available, just run the function
        return @call(.auto, func, args);
    };
    defer guard.reacquire();
    return @call(.auto, func, args);
}

/// Execute a function with the GIL held
/// Use this when calling Python C API functions
pub fn withGil(comptime func: anytype, args: anytype) !@TypeOf(@call(.auto, func, args)) {
    const guard = try GilGuard.acquire();
    defer guard.release();
    return @call(.auto, func, args);
}

/// Check if Python is initialized
pub fn isPythonInitialized() bool {
    const api = PythonAPI.init() catch return false;
    if (api.Py_IsInitialized) |is_init| {
        return is_init() != 0;
    }
    return false;
}

// =============================================================================
// Type Conversion Utilities
// =============================================================================

/// Error type for conversion failures
pub const ConversionError = error{
    NullPointer,
    InvalidType,
    OutOfMemory,
    Overflow,
    InvalidUtf8,
};

/// Convert a Zig slice to a null-terminated C string
/// The returned string is allocated and must be freed
pub fn toCString(allocator: std.mem.Allocator, slice: []const u8) ![:0]u8 {
    return allocator.dupeZ(u8, slice);
}

/// Convert a null-terminated C string to a Zig slice
/// The returned slice references the original memory
pub fn fromCString(c_str: [*:0]const u8) []const u8 {
    return std.mem.span(c_str);
}

// =============================================================================
// Export Helpers
// =============================================================================

/// Helper to define an exported function with proper calling convention
/// Use like: pub const add = exportFn(addImpl);
pub fn exportFn(comptime func: anytype) @TypeOf(func) {
    return func;
}

/// Create an allocator suitable for use in exported functions
/// This uses the C allocator for compatibility with Python memory management
pub fn getExportAllocator() std.mem.Allocator {
    return std.heap.c_allocator;
}

// =============================================================================
// Buffer Management
// =============================================================================

/// A buffer for returning dynamically sized data to Python
/// The buffer is allocated with the C allocator and must be freed by Python
pub const ExportBuffer = struct {
    ptr: [*]u8,
    len: usize,
    capacity: usize,

    pub fn init(data: []const u8) !ExportBuffer {
        const allocator = std.heap.c_allocator;
        const buf = try allocator.alloc(u8, data.len);
        @memcpy(buf, data);
        return ExportBuffer{
            .ptr = buf.ptr,
            .len = data.len,
            .capacity = data.len,
        };
    }

    pub fn initEmpty(capacity: usize) !ExportBuffer {
        const allocator = std.heap.c_allocator;
        const buf = try allocator.alloc(u8, capacity);
        return ExportBuffer{
            .ptr = buf.ptr,
            .len = 0,
            .capacity = capacity,
        };
    }

    pub fn deinit(self: *ExportBuffer) void {
        if (self.capacity > 0) {
            std.heap.c_allocator.free(self.ptr[0..self.capacity]);
        }
        self.* = undefined;
    }

    pub fn slice(self: ExportBuffer) []u8 {
        return self.ptr[0..self.len];
    }
};

/// Free a buffer allocated by Zig
/// This should be called from Python when done with the buffer
pub export fn zigx_free_buffer(ptr: ?[*]u8, len: usize) void {
    if (ptr) |p| {
        std.heap.c_allocator.free(p[0..len]);
    }
}

// =============================================================================
// Error Handling
// =============================================================================

/// Thread-local error message storage
threadlocal var last_error: ?[]const u8 = null;
threadlocal var error_buf: [1024]u8 = undefined;

/// Set the last error message
pub fn setError(comptime fmt: []const u8, args: anytype) void {
    const len = std.fmt.bufPrint(&error_buf, fmt, args) catch |err| {
        _ = std.fmt.bufPrint(&error_buf, "Error formatting error: {}", .{err}) catch {
            return;
        };
        last_error = error_buf[0..];
        return;
    };
    last_error = error_buf[0..len.len];
}

/// Get the last error message
pub export fn zigx_get_last_error() ?[*:0]const u8 {
    if (last_error) |err| {
        // Null terminate if possible
        if (err.len < error_buf.len) {
            error_buf[err.len] = 0;
            return @ptrCast(err.ptr);
        }
    }
    return null;
}

/// Clear the last error
pub export fn zigx_clear_error() void {
    last_error = null;
}

// =============================================================================
// Array/Slice Utilities for FFI
// =============================================================================

/// Wrapper for passing arrays across FFI boundary
pub fn ArrayView(comptime T: type) type {
    return extern struct {
        ptr: ?[*]T,
        len: usize,

        pub fn fromSlice(slice: []T) @This() {
            return .{
                .ptr = if (slice.len > 0) slice.ptr else null,
                .len = slice.len,
            };
        }

        pub fn fromConstSlice(slice: []const T) @This() {
            return .{
                .ptr = if (slice.len > 0) @constCast(slice.ptr) else null,
                .len = slice.len,
            };
        }

        pub fn toSlice(self: @This()) []T {
            if (self.ptr) |p| {
                return p[0..self.len];
            }
            return &[_]T{};
        }

        pub fn toConstSlice(self: @This()) []const T {
            if (self.ptr) |p| {
                return p[0..self.len];
            }
            return &[_]T{};
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

test "ExportBuffer basic usage" {
    var buf = try ExportBuffer.init("hello");
    defer buf.deinit();

    try std.testing.expectEqualStrings("hello", buf.slice());
}

test "ArrayView conversion" {
    var data = [_]i32{ 1, 2, 3, 4, 5 };
    const view = ArrayView(i32).fromSlice(&data);

    try std.testing.expectEqual(@as(usize, 5), view.len);
    try std.testing.expectEqual(@as(i32, 1), view.toSlice()[0]);
}

test "C string conversion" {
    const allocator = std.testing.allocator;
    const c_str = try toCString(allocator, "hello");
    defer allocator.free(c_str);

    try std.testing.expectEqualStrings("hello", c_str);
}
