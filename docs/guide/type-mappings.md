# Type Mappings

This reference documents how Zig types map to Python and ctypes types.

## Primitive Types

| Zig Type | Python Type | ctypes Type | Notes |
|----------|-------------|-------------|-------|
| `i8` | `int` | `c_int8` | Signed 8-bit |
| `i16` | `int` | `c_int16` | Signed 16-bit |
| `i32` | `int` | `c_int32` | Signed 32-bit |
| `i64` | `int` | `c_int64` | Signed 64-bit |
| `u8` | `int` | `c_uint8` | Unsigned 8-bit |
| `u16` | `int` | `c_uint16` | Unsigned 16-bit |
| `u32` | `int` | `c_uint32` | Unsigned 32-bit |
| `u64` | `int` | `c_uint64` | Unsigned 64-bit |
| `f32` | `float` | `c_float` | 32-bit float |
| `f64` | `float` | `c_double` | 64-bit float |
| `bool` | `bool` | `c_bool` | Boolean |
| `void` | `None` | `None` | No return value |

## Size Types

| Zig Type | Python Type | ctypes Type | Notes |
|----------|-------------|-------------|-------|
| `usize` | `int` | `c_size_t` | Platform-dependent |
| `isize` | `int` | `c_ssize_t` | Platform-dependent |

## Pointer Types

| Zig Type | Python Type | ctypes Type | Notes |
|----------|-------------|-------------|-------|
| `[*]u8` | `bytes` | `c_char_p` | String pointer |
| `[*]T` | Array | `POINTER(T)` | Array pointer |
| `*T` | Reference | `POINTER(T)` | Single pointer |
| `?*T` | Optional | `POINTER(T)` | Nullable pointer |

## Using Pointers in Python

### String Pointers

```zig
// Zig
pub export fn string_length(s: [*:0]const u8) usize {
    var len: usize = 0;
    while (s[len] != 0) : (len += 1) {}
    return len;
}
```

```python
# Python
length = myproject.string_length(b"Hello, World!")
print(length)  # Output: 13
```

### Array Pointers

```zig
// Zig
pub export fn process_array(data: [*]f64, len: usize) f64 {
    var sum: f64 = 0;
    for (0..len) |i| {
        sum += data[i];
    }
    return sum;
}
```

```python
# Python
import ctypes

# Create array
arr = (ctypes.c_double * 5)(1.0, 2.0, 3.0, 4.0, 5.0)
result = myproject.process_array(arr, 5)
```

### Output Parameters

```zig
// Zig
pub export fn divide(a: f64, b: f64, result: *f64) bool {
    if (b == 0) return false;
    result.* = a / b;
    return true;
}
```

```python
# Python
import ctypes

result = ctypes.c_double()
success = myproject.divide(10.0, 2.0, ctypes.byref(result))
if success:
    print(f"Result: {result.value}")  # Output: 5.0
```

## Working with Structs

Zig structs can be mapped to ctypes structures:

```zig
// Zig
const Point = extern struct {
    x: f64,
    y: f64,
};

pub export fn distance(a: *const Point, b: *const Point) f64 {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    return @sqrt(dx * dx + dy * dy);
}
```

```python
# Python
import ctypes

class Point(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]

a = Point(0.0, 0.0)
b = Point(3.0, 4.0)
dist = myproject.distance(ctypes.byref(a), ctypes.byref(b))
print(f"Distance: {dist}")  # Output: 5.0
```

!!! note
    Structs must be declared as `extern struct` in Zig to ensure C ABI compatibility.

## Type Safety

ZigX generates type stubs (`.pyi` files) for IDE support:

```python
# myproject.pyi (generated)
def add(a: int, b: int) -> int: ...
def multiply(a: float, b: float) -> float: ...
def fibonacci(n: int) -> int: ...
```

This provides:

- Autocompletion in IDEs
- Type checking with mypy/pyright
- Documentation hints
