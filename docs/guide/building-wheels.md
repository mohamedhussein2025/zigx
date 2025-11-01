# Building Wheels

ZigX creates platform-specific Python wheels ready for distribution.

## Development Build

For local development with quick iteration:

```bash
zigx develop
```

This:
- Compiles with debug info
- Installs in editable mode
- Enables fast rebuilds

## Release Build

For distribution:

```bash
zigx build --release
```

This:
- Compiles with optimizations (`-Doptimize=ReleaseSafe`)
- Creates a proper wheel in `dist/`
- Includes all necessary metadata

## Wheel Structure

A ZigX wheel contains:

```
myproject-0.1.0-cp314-cp314-win_amd64.whl
├── myproject/
│   ├── __init__.py           # Python bindings
│   ├── myproject.pyi         # Type stubs
│   └── myproject.cp314-win_amd64.pyd  # Native library
├── myproject-0.1.0.dist-info/
│   ├── METADATA
│   ├── WHEEL
│   └── RECORD
```

## Platform Tags

ZigX automatically generates correct platform tags:

| Platform | Tag Example |
|----------|-------------|
| Windows x64 | `cp314-cp314-win_amd64` |
| Linux x64 | `cp314-cp314-linux_x86_64` |
| macOS x64 | `cp314-cp314-macosx_10_9_x86_64` |
| macOS ARM | `cp314-cp314-macosx_11_0_arm64` |

## Python Version Detection

ZigX detects your Python version automatically:

```bash
# Uses current Python
zigx build --release

# The wheel will match your Python version
# Python 3.14 → cp314
# Python 3.13 → cp313
# etc.
```

## Build Options

### Optimization Levels

ZigX uses Zig's optimization modes:

- **Debug** (default for develop): Full debug info, no optimization
- **ReleaseSafe** (default for --release): Optimized with safety checks
- **ReleaseFast**: Maximum performance, no safety checks
- **ReleaseSmall**: Minimize binary size

### Custom Build Configuration

Configure in `pyproject.toml`:

```toml
[tool.zigx]
optimize = "ReleaseSafe"  # or "ReleaseFast", "ReleaseSmall"
```

## Cross-Compilation

Zig's cross-compilation support makes it easy to build for different platforms:

```bash
# Build for Linux from Windows (future feature)
zigx build --target x86_64-linux-gnu
```

!!! note
    Cross-compilation support is planned for future releases.

## Troubleshooting

### Build Fails with Zig Errors

Ensure your Zig version is compatible:

```bash
zig version
# Should be 0.14.0 or later
```

### Wrong Python Version in Wheel Name

Check your active Python:

```bash
python --version
# Should match the wheel tag
```

### Missing Type Stubs

Type stubs are generated automatically. If missing:

```bash
zigx develop
# Regenerates all files including .pyi
```
