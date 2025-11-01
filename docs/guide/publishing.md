# Publishing to PyPI

This guide covers how to publish your ZigX project to PyPI.

## Prerequisites

1. Create a PyPI account at [pypi.org](https://pypi.org)
2. Set up API tokens for authentication

## Using `zigx publish`

The simplest way to publish:

```bash
zigx publish
```

This:
1. Builds a release wheel
2. Uploads to PyPI using twine

## Manual Publishing

### Step 1: Build the Wheel

```bash
zigx build --release
```

### Step 2: Install Twine

```bash
pip install twine
```

### Step 3: Upload

```bash
twine upload dist/*
```

## Authentication

### Using API Tokens (Recommended)

1. Go to PyPI → Account Settings → API tokens
2. Create a token with upload permissions
3. Configure in `~/.pypirc`:

```ini
[pypi]
username = __token__
password = pypi-YOUR-API-TOKEN-HERE
```

### Using Environment Variables

```bash
export TWINE_USERNAME=__token__
export TWINE_PASSWORD=pypi-YOUR-API-TOKEN-HERE
twine upload dist/*
```

## Test PyPI

Test your package on TestPyPI first:

```bash
twine upload --repository testpypi dist/*
```

Then install from TestPyPI:

```bash
pip install --index-url https://test.pypi.org/simple/ myproject
```

## Version Management

Update version in `pyproject.toml`:

```toml
[project]
name = "myproject"
version = "0.2.0"  # Bump version before publishing
```

ZigX follows semantic versioning:
- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

## Multi-Platform Builds

For true cross-platform distribution, build on each platform:

### GitHub Actions Example

```yaml
name: Build and Publish

on:
  release:
    types: [published]

jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        python: ['3.10', '3.11', '3.12', '3.13', '3.14']
    
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      
      - name: Install Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.15.2
      
      - name: Install ZigX
        run: pip install zigx
      
      - name: Build wheel
        run: zigx build --release
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: wheels-${{ matrix.os }}-${{ matrix.python }}
          path: dist/*.whl

  publish:
    needs: build
    runs-on: ubuntu-latest
    
    steps:
      - name: Download all wheels
        uses: actions/download-artifact@v4
        with:
          path: dist
          merge-multiple: true
      
      - name: Publish to PyPI
        uses: pypa/gh-action-pypi-publish@release/v1
        with:
          password: ${{ secrets.PYPI_API_TOKEN }}
```

## Best Practices

1. **Test locally first** - Ensure the package works
2. **Use TestPyPI** - Validate the upload process
3. **Use CI/CD** - Automate multi-platform builds
4. **Keep tokens secure** - Never commit API tokens
5. **Update documentation** - Keep README and docs current
