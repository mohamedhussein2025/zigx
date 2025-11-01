# Installation

## Requirements

Before installing ZigX, ensure you have the following:

- **Python** 3.8 or later
- **Zig** 0.14.0 or later (0.15.0+ recommended)
- **uv** (recommended) or pip

## Installing Zig

### Windows

Download from [ziglang.org/download](https://ziglang.org/download/) or use:

```powershell
# Using winget
winget install zig.zig

# Or using scoop
scoop install zig
```

### macOS

```bash
# Using Homebrew
brew install zig
```

### Linux

```bash
# Using package manager (Ubuntu/Debian)
sudo apt install zig

# Or download directly
curl -L https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar xJ
export PATH="$PATH:$(pwd)/zig-linux-x86_64-0.15.2"
```

Verify installation:

```bash
zig version
```

## Installing ZigX

### Using pip

```bash
pip install zigx
```

### Using uv (Recommended)

```bash
uv pip install zigx
```

### From Source

```bash
git clone https://github.com/muhammad-fiaz/zigx.git
cd zigx
pip install -e .
```

## Verify Installation

```bash
zigx --help
```

You should see the help message with available commands.

## Development Installation

For contributing to ZigX:

```bash
git clone https://github.com/muhammad-fiaz/zigx.git
cd zigx
pip install -e ".[dev,docs]"
```

This installs development dependencies including:

- pytest for testing
- ruff for linting
- mkdocs for documentation
