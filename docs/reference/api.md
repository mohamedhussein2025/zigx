# API Reference

This page documents the Python API for ZigX.

## Module: `zigx`

### `zigx.main()`

Entry point for the ZigX CLI.

```python
import zigx
zigx.main()
```

### `zigx.run(*args)`

Run a ZigX command programmatically.

```python
import zigx

# Create a new project
zigx.run("new", "myproject")

# Build in development mode
zigx.run("develop")

# Build a release wheel
zigx.run("build", "--release")
```

**Arguments:**

- `*args`: Command-line arguments to pass to ZigX

**Returns:**

- `int`: Exit code (0 for success)

## Build Backend API

ZigX implements the PEP 517 build backend interface.

### `zigx.build.build_wheel()`

Build a wheel from the project.

```python
from zigx.build import build_wheel

wheel_name = build_wheel(
    wheel_directory="dist",
    config_settings=None,
    metadata_directory=None
)
```

**Arguments:**

- `wheel_directory`: Directory to place the built wheel
- `config_settings`: Optional configuration dictionary
- `metadata_directory`: Optional directory with pre-generated metadata

**Returns:**

- `str`: Name of the built wheel file

### `zigx.build.build_editable()`

Build an editable wheel for development.

```python
from zigx.build import build_editable

wheel_name = build_editable(
    wheel_directory="dist",
    config_settings=None,
    metadata_directory=None
)
```

### `zigx.build.get_requires_for_build_wheel()`

Get build dependencies.

```python
from zigx.build import get_requires_for_build_wheel

requirements = get_requires_for_build_wheel()
# Returns: []
```

## Generated Module API

After building with ZigX, your module exports functions based on your Zig code.

### Example

Given this Zig code:

```zig
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn multiply(a: f64, b: f64) f64 {
    return a * b;
}
```

The generated Python module:

```python
import myproject

# Function signatures match Zig exports
result: int = myproject.add(1, 2)
product: float = myproject.multiply(3.14, 2.0)
```

### Type Stubs

ZigX generates `.pyi` files for IDE support:

```python
# myproject.pyi
def add(a: int, b: int) -> int: ...
def multiply(a: float, b: float) -> float: ...
```

## Internal APIs

!!! warning
    These APIs are internal and may change without notice.

### `zigx.build.ZigXBuilder`

Internal class that handles the build process.

### `zigx.build.parse_zig_exports()`

Parse exported functions from Zig source code.

```python
from zigx.build import parse_zig_exports

exports = parse_zig_exports("src/lib.zig")
# Returns list of (name, args, return_type) tuples
```
