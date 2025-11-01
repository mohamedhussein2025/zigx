# Multithreading Example

This example demonstrates how to leverage ZigX's automatic GIL release for parallel computing.

## The Power of Automatic GIL Release

When you call a ZigX function from Python, the GIL is automatically released. This means:

1. Multiple Python threads can call Zig functions simultaneously
2. Your Zig code runs in true parallel
3. No special configuration needed

## CPU-Bound Work Example

### src/lib.zig

```zig
const std = @import("std");

/// Compute-intensive function that benefits from parallelism
pub export fn compute_pi_leibniz(iterations: u64) f64 {
    var sum: f64 = 0;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const term = std.math.pow(f64, -1, @as(f64, @floatFromInt(i))) /
                     @as(f64, @floatFromInt(2 * i + 1));
        sum += term;
    }
    return sum * 4;
}

/// Process a chunk of data
pub export fn process_chunk(
    data: [*]f64,
    len: usize,
    operation: u32,  // 0=square, 1=sqrt, 2=sin, 3=cos
) void {
    for (0..len) |i| {
        data[i] = switch (operation) {
            0 => data[i] * data[i],
            1 => @sqrt(@abs(data[i])),
            2 => @sin(data[i]),
            3 => @cos(data[i]),
            else => data[i],
        };
    }
}

/// Parallel-friendly matrix operation
pub export fn matrix_power_sum(
    matrix: [*]const f64,
    rows: usize,
    cols: usize,
    power: u32,
) f64 {
    var sum: f64 = 0;
    for (0..rows * cols) |i| {
        var val = matrix[i];
        var p: u32 = 1;
        while (p < power) : (p += 1) {
            val *= matrix[i];
        }
        sum += val;
    }
    return sum;
}

/// Simulate heavy I/O-like operation
pub export fn heavy_simulation(steps: u64, seed: u64) f64 {
    var state = seed;
    var result: f64 = 0;
    
    for (0..steps) |_| {
        // Simple PRNG
        state = state *% 6364136223846793005 +% 1442695040888963407;
        const random = @as(f64, @floatFromInt(state >> 33)) / @as(f64, @floatFromInt(@as(u64, 1) << 31));
        result += @sin(random * std.math.pi);
    }
    
    return result / @as(f64, @floatFromInt(steps));
}
```

### Python Multithreading

```python
import threading
import time
import ctypes
import multithread_example

def benchmark_single_thread():
    """Run computations sequentially."""
    start = time.perf_counter()
    
    results = []
    for i in range(4):
        result = multithread_example.compute_pi_leibniz(10_000_000)
        results.append(result)
    
    elapsed = time.perf_counter() - start
    print(f"Single-threaded: {elapsed:.3f}s")
    return results

def benchmark_multi_thread():
    """Run computations in parallel."""
    start = time.perf_counter()
    
    results = [None] * 4
    threads = []
    
    def worker(index):
        results[index] = multithread_example.compute_pi_leibniz(10_000_000)
    
    for i in range(4):
        t = threading.Thread(target=worker, args=(i,))
        threads.append(t)
        t.start()
    
    for t in threads:
        t.join()
    
    elapsed = time.perf_counter() - start
    print(f"Multi-threaded (4 threads): {elapsed:.3f}s")
    return results

# Run benchmarks
print("Computing π using Leibniz formula (10M iterations × 4):\n")
single_results = benchmark_single_thread()
multi_results = benchmark_multi_thread()

print(f"\nResults match: {single_results == multi_results}")
print(f"π approximation: {multi_results[0]:.10f}")
```

### Expected Output

```
Computing π using Leibniz formula (10M iterations × 4):

Single-threaded: 2.847s
Multi-threaded (4 threads): 0.756s

Results match: True
π approximation: 3.1415925536
```

## Parallel Data Processing

```python
import threading
import ctypes
import multithread_example

def parallel_process_array():
    """Process large array in parallel chunks."""
    # Create large array
    size = 10_000_000
    data = (ctypes.c_double * size)()
    
    # Initialize with values
    for i in range(size):
        data[i] = float(i) * 0.001
    
    # Split into chunks for parallel processing
    num_threads = 4
    chunk_size = size // num_threads
    threads = []
    
    def process_chunk(start_idx, length, operation):
        # Get pointer to start of chunk
        ptr = ctypes.cast(
            ctypes.addressof(data) + start_idx * ctypes.sizeof(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double)
        )
        multithread_example.process_chunk(ptr, length, operation)
    
    # Process chunks in parallel
    import time
    start = time.perf_counter()
    
    for i in range(num_threads):
        start_idx = i * chunk_size
        length = chunk_size if i < num_threads - 1 else size - start_idx
        t = threading.Thread(target=process_chunk, args=(start_idx, length, 2))  # sin
        threads.append(t)
        t.start()
    
    for t in threads:
        t.join()
    
    elapsed = time.perf_counter() - start
    print(f"Processed {size:,} elements in {elapsed:.3f}s")
    print(f"Sample results: {data[0]:.4f}, {data[1000]:.4f}, {data[5000000]:.4f}")

parallel_process_array()
```

## Thread Safety Considerations

### DO: Use Thread-Local Storage

```zig
threadlocal var thread_state: u64 = 0;

pub export fn thread_safe_operation(input: u64) u64 {
    thread_state = input;
    // Each thread has its own thread_state
    return thread_state * 2;
}
```

### DO: Use Atomics for Shared State

```zig
const std = @import("std");

var global_counter = std.atomic.Value(u64).init(0);

pub export fn atomic_increment() u64 {
    return global_counter.fetchAdd(1, .seq_cst);
}

pub export fn atomic_get() u64 {
    return global_counter.load(.seq_cst);
}
```

```python
# Safe parallel incrementing
import threading

def increment_worker():
    for _ in range(10000):
        multithread_example.atomic_increment()

threads = [threading.Thread(target=increment_worker) for _ in range(10)]
for t in threads:
    t.start()
for t in threads:
    t.join()

print(f"Final counter: {multithread_example.atomic_get()}")  # Should be 100000
```

### DON'T: Share Mutable State Without Synchronization

```zig
// BAD - Data race!
var shared_value: i32 = 0;

pub export fn unsafe_increment() void {
    shared_value += 1;  // Race condition!
}
```

## Best Practices

1. **Chunk large data** - Split arrays for parallel processing
2. **Use atomics** - For any shared counters or flags
3. **Prefer thread-local** - When threads don't need to share state
4. **Profile first** - Threading overhead can hurt small workloads
5. **Test with ThreadSanitizer** - Catch race conditions early

## Performance Tips

- Minimum chunk size ~10,000 elements to overcome threading overhead
- For CPU-bound work, use `num_threads = cpu_count`
- For mixed I/O work, can use more threads
- Always benchmark both sequential and parallel versions
