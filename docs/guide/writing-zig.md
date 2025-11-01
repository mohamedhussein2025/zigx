# Writing Zig Code

This guide covers best practices for writing Zig code that works seamlessly with ZigX.

## Exported Functions

Mark functions with `pub export` to make them callable from Python:

```zig
pub export fn my_function(x: i32) i32 {
    return x * 2;
}
```

## Standard Library

Use Zig's standard library for common operations:

```zig
const std = @import("std");

pub export fn sqrt_f64(x: f64) f64 {
    return @sqrt(x);
}

pub export fn sin_f64(x: f64) f64 {
    return @sin(x);
}

pub export fn cos_f64(x: f64) f64 {
    return @cos(x);
}
```

## Working with Arrays

Pass array pointers and lengths:

```zig
pub export fn sum_array(data: [*]const f64, len: usize) f64 {
    var sum: f64 = 0;
    for (0..len) |i| {
        sum += data[i];
    }
    return sum;
}

pub export fn scale_array(data: [*]f64, len: usize, scale: f64) void {
    for (0..len) |i| {
        data[i] *= scale;
    }
}
```

From Python:

```python
import ctypes
import myproject

# Create an array
arr = (ctypes.c_double * 5)(1.0, 2.0, 3.0, 4.0, 5.0)

# Pass to Zig
total = myproject.sum_array(arr, 5)
print(f"Sum: {total}")  # Output: 15.0

# Modify in-place
myproject.scale_array(arr, 5, 2.0)
print(list(arr))  # Output: [2.0, 4.0, 6.0, 8.0, 10.0]
```

## Error Handling

Zig errors cannot be directly passed to Python. Use error codes or optional types:

```zig
// Using error codes
pub export fn divide(a: f64, b: f64, result: *f64) i32 {
    if (b == 0) {
        return -1;  // Error code for division by zero
    }
    result.* = a / b;
    return 0;  // Success
}

// Using optional (returns 0 for null)
pub export fn safe_sqrt(x: f64) f64 {
    if (x < 0) {
        return std.math.nan(f64);
    }
    return @sqrt(x);
}
```

## Memory Management

For persistent allocations, use a global allocator:

```zig
const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub export fn create_buffer(size: usize) ?[*]u8 {
    const allocator = gpa.allocator();
    const buf = allocator.alloc(u8, size) catch return null;
    return buf.ptr;
}

pub export fn free_buffer(ptr: [*]u8, size: usize) void {
    const allocator = gpa.allocator();
    allocator.free(ptr[0..size]);
}
```

!!! warning
    Be careful with memory! Python won't automatically free Zig allocations.

## Performance Tips

### Use SIMD

Zig supports SIMD operations:

```zig
pub export fn dot_product(a: [*]const f64, b: [*]const f64, len: usize) f64 {
    const Vec4 = @Vector(4, f64);
    var sum = Vec4{ 0, 0, 0, 0 };
    
    const vec_len = len / 4;
    for (0..vec_len) |i| {
        const va: Vec4 = a[i*4..][0..4].*;
        const vb: Vec4 = b[i*4..][0..4].*;
        sum += va * vb;
    }
    
    var result = @reduce(.Add, sum);
    
    // Handle remainder
    for (vec_len*4..len) |i| {
        result += a[i] * b[i];
    }
    
    return result;
}
```

### Release Build

Always use `--release` for production:

```bash
zigx build --release
```

This enables optimizations like:
- ReleaseSafe: Safety checks + optimizations
- ReleaseFast: Maximum speed (no safety)
- ReleaseSmall: Minimum size
