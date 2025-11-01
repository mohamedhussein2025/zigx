# CLI Reference

Complete reference for ZigX command-line interface.

## Commands Overview

| Command | Description |
|---------|-------------|
| `zigx new <name>` | Create a new ZigX project |
| `zigx develop` | Build and install in development mode |
| `zigx build` | Build a wheel |
| `zigx publish` | Build and upload to PyPI |
| `zigx --help` | Show help information |
| `zigx --version` | Show version |

## `zigx new`

Create a new ZigX project.

### Usage

```bash
zigx new <project_name>
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `project_name` | Yes | Name of the project to create |

### Example

```bash
zigx new myproject
```

Creates:
```
myproject/
├── pyproject.toml
├── src/
│   └── lib.zig
└── myproject/
    └── __init__.py
```

## `zigx develop`

Build and install the project in development mode.

### Usage

```bash
zigx develop
```

### Behavior

- Compiles Zig code with debug info
- Generates Python bindings
- Installs in editable mode
- Creates type stubs (`.pyi`)

### Example

```bash
cd myproject
zigx develop
```

## `zigx build`

Build a distribution wheel.

### Usage

```bash
zigx build [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--release` | Build with optimizations |

### Example

```bash
# Debug build
zigx build

# Release build
zigx build --release
```

Output:
```
dist/myproject-0.1.0-cp314-cp314-win_amd64.whl
```

## `zigx publish`

Build and upload the package to PyPI.

### Usage

```bash
zigx publish
```

### Requirements

- PyPI account
- API token configured

### Behavior

1. Builds a release wheel
2. Uploads using twine

## `zigx --help`

Show help information.

```bash
zigx --help
```

Output:
```
ZigX - A maturin-like Python binding system for Zig

Usage: zigx <command> [options]

Commands:
    new <name>     Create a new ZigX project
    develop        Build and install in development mode
    build          Build a wheel
    publish        Build and upload to PyPI

Options:
    --help         Show this help message
    --version      Show version information
```

## `zigx --version`

Show version information.

```bash
zigx --version
```

Output:
```
zigx 0.1.0
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Command not found |
| 3 | Build failure |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ZIG_PATH` | Path to Zig compiler |
| `ZIGX_DEBUG` | Enable debug output |
