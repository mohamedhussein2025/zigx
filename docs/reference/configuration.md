# Configuration Reference

ZigX can be configured through `pyproject.toml`.

## Basic Configuration

```toml
[project]
name = "myproject"
version = "0.1.0"
description = "My Zig-powered Python extension"
requires-python = ">=3.8"
```

## Build System

ZigX works as a PEP 517 build backend:

```toml
[build-system]
requires = ["zigx"]
build-backend = "zigx.build"
```

## ZigX-Specific Settings

```toml
[tool.zigx]
# Source file location (default: src/lib.zig)
source = "src/lib.zig"

# Optimization level for release builds
optimize = "ReleaseSafe"  # Options: ReleaseSafe, ReleaseFast, ReleaseSmall

# Package name for the Python module (default: project name)
module-name = "myproject"
```

## Full Example

```toml
[project]
name = "myproject"
version = "0.1.0"
description = "A high-performance math library"
readme = "README.md"
requires-python = ">=3.8"
license = { text = "MIT" }
authors = [
    { name = "Your Name", email = "you@example.com" }
]
keywords = ["math", "performance", "zig"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Programming Language :: Python :: 3.13",
    "Programming Language :: Python :: 3.14",
]
dependencies = []

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "mypy>=1.0",
]

[project.urls]
Homepage = "https://github.com/yourname/myproject"
Documentation = "https://yourname.github.io/myproject"
Repository = "https://github.com/yourname/myproject"
Issues = "https://github.com/yourname/myproject/issues"

[build-system]
requires = ["zigx"]
build-backend = "zigx.build"

[tool.zigx]
source = "src/lib.zig"
optimize = "ReleaseSafe"
module-name = "myproject"
```

## Optimization Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `Debug` | No optimization, full debug info | Development |
| `ReleaseSafe` | Optimized with safety checks | Default for release |
| `ReleaseFast` | Maximum optimization | Performance-critical |
| `ReleaseSmall` | Size optimization | Size-constrained |

## Source File Location

By default, ZigX looks for `src/lib.zig`. Customize with:

```toml
[tool.zigx]
source = "zig/mylib.zig"
```

## Module Name

If your project name differs from the desired import name:

```toml
[project]
name = "my-project"  # PyPI name

[tool.zigx]
module-name = "myproject"  # Import name
```

```python
# Python
import myproject  # Not my-project
```

## Dependencies

ZigX projects typically have no runtime Python dependencies:

```toml
[project]
dependencies = []
```

For development dependencies:

```toml
[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "mypy>=1.0",
    "ruff>=0.1.0",
]
```

## Entry Points

If your project provides console scripts:

```toml
[project.scripts]
mycommand = "myproject:main"
```
