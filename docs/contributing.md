# Contributing to ZigX

Thank you for your interest in contributing to ZigX! This guide will help you get started.

## Getting Started

### Prerequisites

- Python 3.8+
- Zig 0.14.0+ (0.15.0+ recommended)
- Git

### Development Setup

1. Fork the repository on GitHub
2. Clone your fork:

```bash
git clone https://github.com/YOUR-USERNAME/zigx.git
cd zigx
```

3. Install development dependencies:

```bash
pip install -e ".[dev,docs]"
```

4. Build the Zig CLI:

```bash
cd zigx
zig build
```

## Development Workflow

### Running Tests

```bash
pytest tests/
```

### Running Lints

```bash
ruff check .
mypy zigx/
```

### Building Documentation

```bash
mkdocs serve
```

Visit `http://localhost:8000` to preview.

## Code Style

### Python

- Follow PEP 8
- Use type hints
- Use ruff for formatting and linting

### Zig

- Follow Zig style guide
- Use `zig fmt` for formatting
- Keep functions small and focused

## Pull Request Process

1. Create a feature branch:

```bash
git checkout -b feature/my-feature
```

2. Make your changes

3. Write tests for new functionality

4. Update documentation if needed

5. Run tests and lints:

```bash
pytest tests/
ruff check .
```

6. Commit with descriptive messages:

```bash
git commit -m "Add support for X"
```

7. Push and create a Pull Request:

```bash
git push origin feature/my-feature
```

## Issue Guidelines

### Bug Reports

Include:
- Python version
- Zig version
- Operating system
- Minimal reproduction code
- Expected vs actual behavior
- Full error traceback

### Feature Requests

Include:
- Use case description
- Proposed API/behavior
- Alternatives considered

## Project Structure

```
zigx/
├── zigx/
│   ├── __init__.py      # CLI entry point
│   ├── build.py         # PEP 517 build backend
│   ├── src/             # Zig source code
│   │   ├── main.zig     # CLI implementation
│   │   └── ...
│   └── build.zig        # Zig build configuration
├── tests/               # Python tests
├── docs/                # Documentation (MkDocs)
├── pyproject.toml       # Project configuration
└── README.md
```

## Areas for Contribution

- **Documentation** - Improve guides and examples
- **Testing** - Add test coverage
- **Features** - Implement new functionality
- **Bug fixes** - Fix reported issues
- **Performance** - Optimize build times and runtime
- **Cross-compilation** - Improve multi-platform support

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

## Questions?

- Open an issue for discussion
- Check existing issues for answers
- Review the documentation

Thank you for contributing to ZigX! 🚀
