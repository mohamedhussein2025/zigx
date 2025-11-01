# GIL Support

The Global Interpreter Lock (GIL) is Python's mechanism for thread safety. Understanding how ZigX handles the GIL is crucial for writing performant, thread-safe extensions.

## Automatic GIL Release

**Good news:** ZigX uses ctypes, which automatically releases the GIL during native function calls!

This means your Zig code runs without holding the GIL, allowing other Python threads to execute concurrently.

```python
import threading
import myproject

def compute_heavy():
    # GIL is automatically released during this call
    result = myproject.heavy_computation(data)
    return result

# These threads can run in parallel!
threads = [threading.Thread(target=compute_heavy) for _ in range(4)]
for t in threads:
    t.start()
for t in threads:
    t.join()
```

## How It Works

1. Python calls your function through ctypes
2. ctypes releases the GIL before calling the native code
3. Your Zig code runs without blocking Python
4. ctypes reacquires the GIL after the call returns
5. Python continues execution

This is similar to how maturin/pyo3 works with its `#[pyo3(gil_safe)]` attribute, but it's automatic with ZigX.

## Thread-Safe Zig Code

While the GIL is released, your Zig code must be thread-safe:

### DO: Use Thread-Local Storage

```zig
threadlocal var thread_buffer: [1024]u8 = undefined;

pub export fn process_with_buffer(input: [*]const u8, len: usize) i32 {
    // Safe: each thread has its own buffer
    @memcpy(thread_buffer[0..len], input[0..len]);
    // Process...
    return 0;
}
```

### DO: Use Atomic Operations

```zig
const std = @import("std");

var counter = std.atomic.Value(u64).init(0);

pub export fn increment_counter() u64 {
    return counter.fetchAdd(1, .seq_cst);
}

pub export fn get_counter() u64 {
    return counter.load(.seq_cst);
}
```

### DON'T: Share Mutable State Without Synchronization

```zig
// BAD: Race condition!
var shared_value: i32 = 0;

pub export fn bad_increment() void {
    shared_value += 1;  // Not thread-safe!
}
```

## Performance Considerations

### Long-Running Operations

The automatic GIL release is perfect for:

- Heavy computations
- I/O operations
- Sleep/wait operations

```zig
const std = @import("std");

pub export fn compute_pi(iterations: u64) f64 {
    // This runs for a long time without blocking Python
    var sum: f64 = 0;
    for (0..iterations) |k| {
        const term = std.math.pow(f64, -1, @as(f64, @floatFromInt(k))) / 
                     @as(f64, @floatFromInt(2 * k + 1));
        sum += term;
    }
    return sum * 4;
}
```

### Short Operations

For very short operations, the GIL release/acquire overhead might be noticeable. Consider batching:

```zig
// Instead of calling add() 1000 times...
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

// ...batch the operation
pub export fn add_arrays(
    a: [*]const i32,
    b: [*]const i32,
    result: [*]i32,
    len: usize
) void {
    for (0..len) |i| {
        result[i] = a[i] + b[i];
    }
}
```

## Comparison with Other Tools

| Tool | GIL Handling | Configuration |
|------|--------------|---------------|
| ZigX | Automatic release | None needed |
| maturin/pyo3 | Manual with `#[pyo3(gil_safe)]` | Per-function attribute |
| cffi | Automatic with `release_gil=True` | Configuration option |
| Cython | Manual with `nogil` | Per-block directive |

## Best Practices

1. **Batch operations** - Minimize call overhead by processing arrays instead of scalars
2. **Use thread-local storage** - Avoid shared mutable state
3. **Use atomics** - When shared state is necessary
4. **Profile** - Measure actual performance, don't assume
5. **Test with threads** - Verify thread safety in your tests

```python
def test_thread_safety():
    import threading
    results = []
    
    def worker():
        for _ in range(1000):
            results.append(myproject.thread_safe_function())
    
    threads = [threading.Thread(target=worker) for _ in range(10)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    
    assert len(results) == 10000
```
