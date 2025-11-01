# Advanced Example

This example demonstrates advanced ZigX features including arrays, structs, and memory management.

## Working with Arrays

### src/lib.zig

```zig
const std = @import("std");

/// Sum all elements in an array
pub export fn sum_array(data: [*]const f64, len: usize) f64 {
    var sum: f64 = 0;
    for (0..len) |i| {
        sum += data[i];
    }
    return sum;
}

/// Calculate mean of an array
pub export fn mean_array(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0;
    return sum_array(data, len) / @as(f64, @floatFromInt(len));
}

/// Calculate standard deviation
pub export fn std_dev(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0;
    
    const avg = mean_array(data, len);
    var sum_sq: f64 = 0;
    
    for (0..len) |i| {
        const diff = data[i] - avg;
        sum_sq += diff * diff;
    }
    
    return @sqrt(sum_sq / @as(f64, @floatFromInt(len)));
}

/// Scale all elements in-place
pub export fn scale_array(data: [*]f64, len: usize, factor: f64) void {
    for (0..len) |i| {
        data[i] *= factor;
    }
}

/// Dot product of two arrays
pub export fn dot_product(a: [*]const f64, b: [*]const f64, len: usize) f64 {
    var result: f64 = 0;
    for (0..len) |i| {
        result += a[i] * b[i];
    }
    return result;
}

/// Matrix multiplication (row-major order)
/// C[m×n] = A[m×k] × B[k×n]
pub export fn matrix_multiply(
    a: [*]const f64,
    b: [*]const f64,
    c: [*]f64,
    m: usize,
    k: usize,
    n: usize,
) void {
    for (0..m) |i| {
        for (0..n) |j| {
            var sum: f64 = 0;
            for (0..k) |l| {
                sum += a[i * k + l] * b[l * n + j];
            }
            c[i * n + j] = sum;
        }
    }
}

/// Sort array in-place (quicksort)
pub export fn sort_array(data: [*]f64, len: usize) void {
    if (len <= 1) return;
    quicksort(data[0..len]);
}

fn quicksort(arr: []f64) void {
    if (arr.len <= 1) return;
    
    const pivot = arr[arr.len / 2];
    var left: usize = 0;
    var right: usize = arr.len - 1;
    
    while (left <= right) {
        while (arr[left] < pivot) left += 1;
        while (arr[right] > pivot) right -= 1;
        
        if (left <= right) {
            const temp = arr[left];
            arr[left] = arr[right];
            arr[right] = temp;
            left += 1;
            if (right > 0) right -= 1;
        }
    }
    
    if (right > 0) quicksort(arr[0..right + 1]);
    if (left < arr.len) quicksort(arr[left..]);
}
```

### Python Usage

```python
import ctypes
import advanced_example

# Create arrays using ctypes
data = (ctypes.c_double * 10)(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0)

# Statistical functions
print(f"Sum: {advanced_example.sum_array(data, 10)}")
print(f"Mean: {advanced_example.mean_array(data, 10)}")
print(f"Std Dev: {advanced_example.std_dev(data, 10):.4f}")

# In-place modification
advanced_example.scale_array(data, 10, 2.0)
print(f"Scaled: {list(data)}")

# Dot product
a = (ctypes.c_double * 3)(1.0, 2.0, 3.0)
b = (ctypes.c_double * 3)(4.0, 5.0, 6.0)
print(f"Dot product: {advanced_example.dot_product(a, b, 3)}")

# Matrix multiplication (2x3 × 3x2 = 2x2)
A = (ctypes.c_double * 6)(1, 2, 3, 4, 5, 6)  # 2×3
B = (ctypes.c_double * 6)(7, 8, 9, 10, 11, 12)  # 3×2
C = (ctypes.c_double * 4)()  # 2×2 result

advanced_example.matrix_multiply(A, B, C, 2, 3, 2)
print(f"Matrix result: {list(C)}")

# Sorting
unsorted = (ctypes.c_double * 8)(3.14, 1.0, 4.15, 9.26, 5.35, 8.97, 2.0, 6.0)
advanced_example.sort_array(unsorted, 8)
print(f"Sorted: {list(unsorted)}")
```

## Working with Strings

```zig
/// Count occurrences of a character
pub export fn count_char(s: [*:0]const u8, c: u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (s[i] != 0) : (i += 1) {
        if (s[i] == c) count += 1;
    }
    return count;
}

/// Get string length
pub export fn string_length(s: [*:0]const u8) usize {
    var len: usize = 0;
    while (s[len] != 0) : (len += 1) {}
    return len;
}

/// Convert string to uppercase in-place
pub export fn to_uppercase(s: [*:0]u8) void {
    var i: usize = 0;
    while (s[i] != 0) : (i += 1) {
        if (s[i] >= 'a' and s[i] <= 'z') {
            s[i] -= 32;
        }
    }
}
```

```python
# String operations
text = b"Hello, World!"
print(f"Length: {advanced_example.string_length(text)}")
print(f"Count 'l': {advanced_example.count_char(text, ord('l'))}")

# In-place modification requires mutable buffer
buf = ctypes.create_string_buffer(b"hello world")
advanced_example.to_uppercase(buf)
print(f"Uppercase: {buf.value.decode()}")
```

## Memory Management

```zig
const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

/// Allocate a buffer
pub export fn alloc_buffer(size: usize) ?[*]u8 {
    const allocator = gpa.allocator();
    const buf = allocator.alloc(u8, size) catch return null;
    return buf.ptr;
}

/// Free a buffer
pub export fn free_buffer(ptr: [*]u8, size: usize) void {
    const allocator = gpa.allocator();
    allocator.free(ptr[0..size]);
}

/// Create and return a dynamically sized array
pub export fn create_range(start: i32, end: i32) ?[*]i32 {
    if (end <= start) return null;
    
    const allocator = gpa.allocator();
    const size = @as(usize, @intCast(end - start));
    const arr = allocator.alloc(i32, size) catch return null;
    
    for (0..size) |i| {
        arr[i] = start + @as(i32, @intCast(i));
    }
    
    return arr.ptr;
}

/// Get range size (for freeing)
pub export fn range_size(start: i32, end: i32) usize {
    if (end <= start) return 0;
    return @as(usize, @intCast(end - start));
}

/// Free a range array
pub export fn free_range(ptr: [*]i32, size: usize) void {
    const allocator = gpa.allocator();
    const slice = @as([*]u8, @ptrCast(ptr))[0 .. size * @sizeOf(i32)];
    allocator.free(@as([]align(1) u8, @alignCast(slice)));
}
```

```python
# Manual memory management
buf_ptr = advanced_example.alloc_buffer(1024)
if buf_ptr:
    # Use the buffer...
    advanced_example.free_buffer(buf_ptr, 1024)

# Dynamic arrays
start, end = 0, 10
ptr = advanced_example.create_range(start, end)
if ptr:
    size = advanced_example.range_size(start, end)
    # Access as array
    arr = ctypes.cast(ptr, ctypes.POINTER(ctypes.c_int32 * size)).contents
    print(f"Range: {list(arr)}")
    # Free when done
    advanced_example.free_range(ptr, size)
```

!!! warning
    Always free allocated memory to prevent leaks!
