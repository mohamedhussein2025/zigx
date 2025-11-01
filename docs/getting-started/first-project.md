# Your First Project

This guide walks you through creating a complete Python extension with ZigX.

## Project Structure

A typical ZigX project looks like:

```
myproject/
├── pyproject.toml       # Project metadata and build configuration
├── src/
│   └── lib.zig          # Main Zig source file
├── myproject/
│   └── __init__.py      # Python package (bindings generated here)
└── tests/
    └── test_myproject.py  # Tests for your extension
```

## Understanding the Build Process

When you run `zigx develop` or `zigx build`, ZigX:

1. **Parses Zig Source** - Scans `src/lib.zig` for `pub export` functions
2. **Compiles to Shared Library** - Builds a `.pyd` (Windows) or `.so` (Linux/macOS) file
3. **Generates Python Bindings** - Creates ctypes-based bindings in `__init__.py`
4. **Generates Type Stubs** - Creates `.pyi` files for IDE support

## Writing Exported Functions

Functions must be marked with `pub export` to be accessible from Python:

```zig
// This function will be exported
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

// This function is NOT exported (no 'export' keyword)
pub fn internal_helper(x: i32) i32 {
    return x * 2;
}

// This function is also NOT exported (not 'pub')
export fn private_export(x: i32) i32 {
    return x;
}
```

## Function Signatures

ZigX supports common Zig types:

```zig
// Integer types
pub export fn process_int(value: i32) i32 { return value; }
pub export fn process_uint(value: u64) u64 { return value; }

// Floating point
pub export fn process_float(value: f64) f64 { return value; }

// Boolean
pub export fn is_valid(x: i32) bool { return x > 0; }

// Void return
pub export fn do_something() void { }
```

## Adding Tests

Create `tests/test_myproject.py`:

```python
import myproject

def test_add():
    assert myproject.add(1, 2) == 3
    assert myproject.add(-1, 1) == 0
    assert myproject.add(0, 0) == 0

def test_multiply():
    assert abs(myproject.multiply(2.0, 3.0) - 6.0) < 1e-10

def test_fibonacci():
    assert myproject.fibonacci(0) == 0
    assert myproject.fibonacci(1) == 1
    assert myproject.fibonacci(10) == 55
```

Run tests:

```bash
pytest tests/
```

## Building for Distribution

### Development Build

For local development with hot-reload:

```bash
zigx develop
```

### Release Build

For distribution:

```bash
zigx build --release
```

The wheel will be optimized and ready for PyPI.

## Next Steps

- [Writing Zig Code](../guide/writing-zig.md) - Advanced Zig patterns
- [Type Mappings](../guide/type-mappings.md) - Complete type reference
- [Publishing](../guide/publishing.md) - Upload to PyPI
