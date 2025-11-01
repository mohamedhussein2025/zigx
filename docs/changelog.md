# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of ZigX
- `zigx new` command to create new projects
- `zigx develop` command for development builds
- `zigx build` command for creating wheels
- `zigx publish` command for PyPI publishing
- Automatic export detection from Zig source
- Type stub (`.pyi`) generation
- GIL-safe operation (automatic release via ctypes)
- Cross-platform support (Windows, Linux, macOS)
- PEP 517 build backend integration
- Comprehensive documentation with MkDocs

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

## [0.0.1] - 2025-11-27

### Added
- Initial public release
- Full CLI implementation in Zig
- Python bindings via ctypes
- Automatic wheel building
- Documentation site

**Note:** For detailed release notes, see [GitHub Releases](https://github.com/muhammad-fiaz/zigx/releases), though they may not have changelog descriptions.

[Unreleased]: https://github.com/muhammad-fiaz/zigx/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/muhammad-fiaz/zigx/releases/tag/v0.0.1
