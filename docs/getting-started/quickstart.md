# Quick Start

This guide will help you create your first Python extension with ZigX in under 5 minutes.

## Create a New Project

```bash
zigx new myproject
cd myproject
```

This creates the following structure:

```
myproject/
├── pyproject.toml       # Project configuration
├── src/
│   └── lib.zig          # Your Zig source code
└── myproject/
    └── __init__.py      # Python package
```

## Write Zig Code

Edit `src/lib.zig`:

```zig
const std = @import("std");

/// Add two integers together
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Multiply two floating point numbers
pub export fn multiply(a: f64, b: f64) f64 {
    return a * b;
}

/// Calculate the nth Fibonacci number
pub export fn fibonacci(n: u32) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const c = a + b;
        a = b;
        b = c;
    }
    return b;
}
```

## Build in Development Mode

```bash
zigx develop
```

This compiles your Zig code and installs the package in development mode.

## Use in Python

```python
import myproject

# Call your Zig functions
print(myproject.add(1, 2))        # Output: 3
print(myproject.multiply(3.14, 2.0))  # Output: 6.28
print(myproject.fibonacci(10))    # Output: 55
```

## Build a Release Wheel

When you're ready to distribute:

```bash
zigx build --release
```

This creates a wheel in the `dist/` directory:

```
dist/myproject-0.1.0-cp314-cp314-win_amd64.whl
```

## What's Next?

- Learn about [Type Mappings](../guide/type-mappings.md) between Zig and Python
- Understand [GIL Support](../guide/gil-support.md) for multithreaded applications
- Explore [Configuration Options](../reference/configuration.md)
