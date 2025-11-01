"""
ZigX Build Backend - PEP 517/660 compliant build system for Zig Python extensions.

This module provides a maturin-like build system for creating Python extensions
written in Zig. It automatically detects exported functions, handles GIL release,
and creates proper wheels without requiring intermediate _native.py files.

Copyright 2025 Muhammad Fiaz
Licensed under the Apache License, Version 2.0
Repository: https://github.com/muhammad-fiaz/zigx
"""

from __future__ import annotations

import hashlib
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from base64 import urlsafe_b64encode
from pathlib import Path
from typing import Any, cast

__all__ = [
    "build_wheel",
    "build_sdist",
    "build_editable",
    "get_requires_for_build_wheel",
    "get_requires_for_build_sdist",
    "get_requires_for_build_editable",
    "prepare_metadata_for_build_wheel",
    "prepare_metadata_for_build_editable",
]


# =============================================================================
# Python Version Detection
# =============================================================================


def get_python_version_info() -> tuple[int, int, int]:
    """Get the current Python version as a tuple."""
    return (sys.version_info.major, sys.version_info.minor, sys.version_info.micro)


def get_python_tag() -> str:
    """Get the Python implementation tag (e.g., 'cp314' for CPython 3.14)."""
    impl = sys.implementation.name
    if impl == "cpython":
        prefix = "cp"
    elif impl == "pypy":
        prefix = "pp"
    else:
        prefix = impl[:2]

    major, minor, _ = get_python_version_info()
    return f"{prefix}{major}{minor}"


def get_abi_tag() -> str:
    """Get the ABI tag for the current Python."""
    # For Python 3.8+, the ABI tag matches the Python tag
    return get_python_tag()


def get_platform_tag() -> str:
    """Get the platform tag for wheels."""
    system = platform.system().lower()
    machine = platform.machine().lower()

    if system == "windows":
        if machine in ("amd64", "x86_64"):
            return "win_amd64"
        elif machine == "arm64":
            return "win_arm64"
        else:
            return "win32"
    elif system == "darwin":
        # macOS - use universal2 or specific arch
        if machine == "arm64":
            return "macosx_11_0_arm64"
        elif machine == "x86_64":
            return "macosx_10_9_x86_64"
        else:
            return f"macosx_10_9_{machine}"
    elif system == "linux":
        # Use manylinux2014 for broad compatibility
        if machine == "x86_64":
            return "manylinux2014_x86_64"
        elif machine == "aarch64":
            return "manylinux2014_aarch64"
        else:
            return f"linux_{machine}"
    else:
        return f"{system}_{machine}"


# =============================================================================
# Project Configuration
# =============================================================================


def read_pyproject_toml(project_dir: Path) -> dict[str, Any]:
    """Read and parse pyproject.toml."""
    pyproject_path = project_dir / "pyproject.toml"
    if not pyproject_path.exists():
        raise FileNotFoundError(f"pyproject.toml not found in {project_dir}")

    try:
        import tomllib  # type: ignore[import]
    except ImportError:
        import tomli as tomllib  # type: ignore[import]

    with open(pyproject_path, "rb") as f:
        data = tomllib.load(f)
        return cast(dict[str, Any], data)


def get_project_metadata(project_dir: Path) -> dict[str, Any]:
    """Extract project metadata from pyproject.toml."""
    config = read_pyproject_toml(project_dir)
    project = config.get("project", {})

    return {
        "name": project.get("name", project_dir.name),
        "version": project.get("version", "0.1.0"),
        "description": project.get("description", ""),
        "authors": project.get("authors", []),
        "license": project.get("license", {}),
        "readme": project.get("readme", ""),
        "requires_python": project.get("requires-python", ">=3.8"),
        "dependencies": project.get("dependencies", []),
        "optional_dependencies": project.get("optional-dependencies", {}),
        "classifiers": project.get("classifiers", []),
        "urls": project.get("urls", {}),
    }


def get_zigx_config(project_dir: Path) -> dict[str, Any]:
    """Get ZigX-specific configuration from pyproject.toml."""
    config = read_pyproject_toml(project_dir)
    tool_zigx = config.get("tool", {}).get("zigx", {})

    return {
        "src_dir": tool_zigx.get("src", "src"),
        "module_name": tool_zigx.get("module", None),  # Auto-detect if not specified
        "release": tool_zigx.get("release", True),
        "strip": tool_zigx.get("strip", True),
        "gil_release": tool_zigx.get("gil-release", True),
        "features": tool_zigx.get("features", []),
    }


# =============================================================================
# Zig Export Detection
# =============================================================================


class ZigFunction:
    """Represents an exported Zig function."""

    def __init__(
        self,
        name: str,
        return_type: str,
        params: list[tuple[str, str]],
        doc: str = "",
        release_gil: bool = True,
    ):
        self.name = name
        self.return_type = return_type
        self.params = params  # List of (name, type) tuples
        self.doc = doc
        self.release_gil = release_gil

    def __repr__(self) -> str:
        return f"ZigFunction({self.name}, {self.return_type}, {self.params})"


# Zig to ctypes type mapping
ZIG_TO_CTYPES: dict[str, str] = {
    "i8": "ctypes.c_int8",
    "i16": "ctypes.c_int16",
    "i32": "ctypes.c_int32",
    "i64": "ctypes.c_int64",
    "u8": "ctypes.c_uint8",
    "u16": "ctypes.c_uint16",
    "u32": "ctypes.c_uint32",
    "u64": "ctypes.c_uint64",
    "f16": "ctypes.c_float",  # Approximation
    "f32": "ctypes.c_float",
    "f64": "ctypes.c_double",
    "bool": "ctypes.c_bool",
    "c_int": "ctypes.c_int",
    "c_uint": "ctypes.c_uint",
    "c_long": "ctypes.c_long",
    "c_ulong": "ctypes.c_ulong",
    "c_longlong": "ctypes.c_longlong",
    "c_ulonglong": "ctypes.c_ulonglong",
    "c_char": "ctypes.c_char",
    "c_short": "ctypes.c_short",
    "c_ushort": "ctypes.c_ushort",
    "usize": "ctypes.c_size_t",
    "isize": "ctypes.c_ssize_t",
    "void": "None",
    "[*c]const u8": "ctypes.c_char_p",
    "[*c]u8": "ctypes.c_char_p",
    "*const u8": "ctypes.c_char_p",
    "*u8": "ctypes.c_char_p",
    "[*]const u8": "ctypes.c_char_p",
    "[*]u8": "ctypes.c_char_p",
}


def parse_zig_type(zig_type: str) -> str:
    """Convert a Zig type to its ctypes equivalent."""
    zig_type = zig_type.strip()

    # Direct mapping
    if zig_type in ZIG_TO_CTYPES:
        return ZIG_TO_CTYPES[zig_type]

    # Pointer types
    if zig_type.startswith("*") or zig_type.startswith("[*"):
        return "ctypes.c_void_p"

    # Optional types
    if zig_type.startswith("?"):
        inner = zig_type[1:].strip()
        if inner.startswith("*") or inner.startswith("[*"):
            return "ctypes.c_void_p"

    # Default to void pointer for unknown types
    return "ctypes.c_void_p"


def parse_zig_exports(zig_source: str) -> list[ZigFunction]:
    """
    Parse Zig source code to automatically detect exported functions.

    This handles various export patterns:
    - `export fn name(...) ReturnType { ... }`
    - `pub export fn name(...) ReturnType { ... }`
    - With doc comments (///)
    """
    functions: list[ZigFunction] = []

    # Pattern for export functions with optional doc comments
    # Matches: [doc comments] [pub] export fn name(params) ReturnType
    export_pattern = re.compile(
        r"(?P<doc>(?:///[^\n]*\n)*)"  # Optional doc comments
        r"\s*(?:pub\s+)?"  # Optional pub
        r"export\s+fn\s+"  # export fn
        r"(?P<name>\w+)"  # Function name
        r"\s*\("  # Opening paren
        r"(?P<params>[^)]*)"  # Parameters
        r"\)\s*"  # Closing paren
        r"(?P<return>[^{]+?)"  # Return type
        r"\s*\{",  # Opening brace
        re.MULTILINE,
    )

    for match in export_pattern.finditer(zig_source):
        name = match.group("name")
        doc_lines = match.group("doc").strip()
        params_str = match.group("params").strip()
        return_type = match.group("return").strip()

        # Parse doc comments
        doc = ""
        if doc_lines:
            doc = "\n".join(
                line.lstrip("/").strip()
                for line in doc_lines.split("\n")
                if line.strip().startswith("///")
            )

        # Parse parameters
        params: list[tuple[str, str]] = []
        if params_str:
            for param in params_str.split(","):
                param = param.strip()
                if not param or param == "...":
                    continue

                # Handle comptime params (skip them)
                if param.startswith("comptime"):
                    continue

                # Parse "name: type" format
                if ":" in param:
                    parts = param.split(":", 1)
                    param_name = parts[0].strip()
                    param_type = parts[1].strip()
                    params.append((param_name, param_type))

        functions.append(
            ZigFunction(
                name=name,
                return_type=return_type,
                params=params,
                doc=doc,
                release_gil=True,  # Default to releasing GIL
            )
        )

    return functions


def scan_zig_sources(src_dir: Path) -> list[ZigFunction]:
    """Scan all Zig source files in a directory for exported functions."""
    all_functions: list[ZigFunction] = []

    for zig_file in src_dir.rglob("*.zig"):
        try:
            source = zig_file.read_text(encoding="utf-8")
            functions = parse_zig_exports(source)
            all_functions.extend(functions)
        except Exception as e:
            print(f"Warning: Failed to parse {zig_file}: {e}", file=sys.stderr)

    return all_functions


# =============================================================================
# Python Module Generation (Maturin-like approach)
# =============================================================================


def generate_init_py(
    module_name: str,
    functions: list[ZigFunction],
    lib_filename: str,
    gil_release: bool = True,
) -> str:
    """
    Generate __init__.py that directly loads the extension.

    This is the maturin-like approach where __init__.py contains
    all the ctypes bindings directly, no intermediate _native.py needed.
    """
    lines = [
        '"""',
        f"{module_name} - Python bindings for Zig library.",
        "",
        "This module was automatically generated by ZigX.",
        "https://github.com/muhammad-fiaz/zigx",
        '"""',
        "",
        "from __future__ import annotations",
        "",
        "import ctypes",
        "import os",
        "import sys",
        "from pathlib import Path",
        "from typing import Any, Optional",
        "",
        "# Module metadata",
        '__version__ = "0.1.0"',
        "__all__ = [",
    ]

    # Add function names to __all__
    for func in functions:
        lines.append(f'    "{func.name}",')
    lines.append("]")
    lines.append("")

    # Library loading code
    lines.extend(
        [
            "# =============================================================================",
            "# Library Loading",
            "# =============================================================================",
            "",
            "_lib: Optional[ctypes.CDLL] = None",
            "",
            "",
            "def _get_lib_path() -> Path:",
            '    """Find the native library path."""',
            "    module_dir = Path(__file__).parent",
            "    ",
            "    # Platform-specific library names",
            '    if sys.platform == "win32":',
            f'        lib_names = ["{lib_filename}", "{module_name}.dll", "lib{module_name}.dll"]',
            '    elif sys.platform == "darwin":',
            f'        lib_names = ["{lib_filename}", "lib{module_name}.dylib", "{module_name}.dylib"]',
            "    else:",
            f'        lib_names = ["{lib_filename}", "lib{module_name}.so", "{module_name}.so"]',
            "    ",
            "    for name in lib_names:",
            "        lib_path = module_dir / name",
            "        if lib_path.exists():",
            "            return lib_path",
            "    ",
            "    raise OSError(",
            f'        f"Could not find {module_name} native library. "',
            '        f"Searched in {{module_dir}} for: {{lib_names}}"',
            "    )",
            "",
            "",
            "def _load_library() -> ctypes.CDLL:",
            '    """Load the native library."""',
            "    global _lib",
            "    if _lib is not None:",
            "        return _lib",
            "    ",
            "    lib_path = _get_lib_path()",
            "    ",
            "    try:",
            "        _lib = ctypes.CDLL(str(lib_path))",
            "    except OSError as e:",
            "        raise OSError(",
            f'            f"Failed to load {module_name} native library from {{lib_path}}: {{e}}"',
            "        ) from e",
            "    ",
            "    return _lib",
            "",
            "",
        ]
    )

    # GIL release context manager if enabled
    if gil_release:
        lines.extend(
            [
                "# =============================================================================",
                "# GIL Management",
                "# =============================================================================",
                "",
                "class _ReleaseGIL:",
                '    """Context manager for releasing the GIL during native calls."""',
                "    ",
                '    __slots__ = ("_state",)',
                "    ",
                '    def __enter__(self) -> "_ReleaseGIL":',
                "        # For ctypes calls, the GIL is automatically released",
                "        # This is a marker for documentation purposes",
                "        return self",
                "    ",
                "    def __exit__(self, *args: Any) -> None:",
                "        pass",
                "",
                "",
                "_release_gil = _ReleaseGIL()",
                "",
                "",
            ]
        )

    # Generate function wrappers
    lines.extend(
        [
            "# =============================================================================",
            "# Function Bindings",
            "# =============================================================================",
            "",
        ]
    )

    for func in functions:
        # Generate docstring
        doc_lines = [f'    """{func.name}']
        if func.doc:
            doc_lines.append("")
            for doc_line in func.doc.split("\n"):
                doc_lines.append(f"    {doc_line}")
        if func.params:
            doc_lines.append("")
            doc_lines.append("    Args:")
            for param_name, param_type in func.params:
                doc_lines.append(f"        {param_name}: {param_type}")
        if func.return_type and func.return_type != "void":
            doc_lines.append("")
            doc_lines.append("    Returns:")
            doc_lines.append(f"        {func.return_type}")
        doc_lines.append('    """')

        # Generate function signature
        param_list = ", ".join(name for name, _ in func.params)
        lines.append(f"def {func.name}({param_list}):")
        lines.extend(doc_lines)

        # Generate function body
        lines.append("    lib = _load_library()")
        lines.append(f"    func = lib.{func.name}")

        # Set argument types
        if func.params:
            argtypes = ", ".join(parse_zig_type(t) for _, t in func.params)
            lines.append(f"    func.argtypes = [{argtypes}]")
        else:
            lines.append("    func.argtypes = []")

        # Set return type
        restype = parse_zig_type(func.return_type)
        lines.append(f"    func.restype = {restype}")

        # Call function
        if gil_release and func.release_gil:
            lines.append("    with _release_gil:")
            if param_list:
                lines.append(f"        return func({param_list})")
            else:
                lines.append("        return func()")
        else:
            if param_list:
                lines.append(f"    return func({param_list})")
            else:
                lines.append("    return func()")

        lines.append("")
        lines.append("")

    # Module initialization
    lines.extend(
        [
            "# =============================================================================",
            "# Module Initialization",
            "# =============================================================================",
            "",
            "# Pre-load library on import for faster first call",
            "try:",
            "    _load_library()",
            "except OSError:",
            "    # Library will be loaded on first function call",
            "    pass",
        ]
    )

    return "\n".join(lines)


# =============================================================================
# Zig Compilation
# =============================================================================


def find_zig() -> str:
    """Find the Zig compiler executable."""
    # Check if zig is in PATH
    zig_path = shutil.which("zig")
    if zig_path:
        return zig_path

    # Check common installation locations
    if sys.platform == "win32":
        common_paths = [
            Path(os.environ.get("LOCALAPPDATA", "")) / "zig" / "zig.exe",
            Path(os.environ.get("PROGRAMFILES", "")) / "zig" / "zig.exe",
            Path.home() / ".zig" / "zig.exe",
        ]
    else:
        common_paths = [
            Path.home() / ".local" / "bin" / "zig",
            Path("/usr/local/bin/zig"),
            Path("/usr/bin/zig"),
            Path.home() / ".zig" / "zig",
        ]

    for path in common_paths:
        if path.exists():
            return str(path)

    raise FileNotFoundError(
        "Could not find Zig compiler. Please install Zig and ensure it's in your PATH. "
        "Visit https://ziglang.org/download/ for installation instructions."
    )


def get_zig_target() -> str:
    """Get the Zig target triple for the current platform."""
    system = platform.system().lower()
    machine = platform.machine().lower()

    # Normalize architecture names
    arch_map = {
        "x86_64": "x86_64",
        "amd64": "x86_64",
        "arm64": "aarch64",
        "aarch64": "aarch64",
        "i386": "x86",
        "i686": "x86",
    }
    arch = arch_map.get(machine, machine)

    # Normalize OS names
    os_map = {
        "windows": f"{arch}-windows-gnu",
        "darwin": f"{arch}-macos",
        "linux": f"{arch}-linux-gnu",
    }
    return os_map.get(system, f"{arch}-{system}-gnu")


def get_lib_extension() -> str:
    """Get the shared library extension for the current platform."""
    if sys.platform == "win32":
        return ".dll"
    elif sys.platform == "darwin":
        return ".dylib"
    else:
        return ".so"


def compile_zig(
    src_dir: Path,
    output_dir: Path,
    module_name: str,
    release: bool = True,
    strip: bool = True,
) -> Path:
    """Compile Zig source to a shared library."""
    zig = find_zig()

    # Find the main Zig file
    main_files = ["lib.zig", "main.zig", f"{module_name}.zig"]
    main_file = None

    for name in main_files:
        candidate = src_dir / name
        if candidate.exists():
            main_file = candidate
            break

    if main_file is None:
        # Look for any .zig file
        zig_files = list(src_dir.glob("*.zig"))
        if zig_files:
            main_file = zig_files[0]
        else:
            raise FileNotFoundError(f"No Zig source files found in {src_dir}")

    # Output library name
    lib_name = f"lib{module_name}"
    lib_ext = get_lib_extension()
    output_file = output_dir / f"{lib_name}{lib_ext}"

    # Build command
    cmd = [
        zig,
        "build-lib",
        str(main_file),
        "-dynamic",
        f"-femit-bin={output_file}",
        "-fno-emit-h",
        "-OReleaseFast" if release else "-ODebug",
    ]

    if strip:
        cmd.append("-fstrip")

    # Set target
    target = get_zig_target()
    cmd.extend(["-target", target])

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Run Zig compiler
    print(f"Compiling {main_file} -> {output_file}")
    result = subprocess.run(
        cmd,
        cwd=src_dir.parent,
        capture_output=True,
        text=True,
        check=False,  # Handle error manually for better messages
    )

    if result.returncode != 0:
        error_msg = result.stderr or result.stdout
        raise subprocess.CalledProcessError(
            result.returncode,
            cmd,
            output=result.stdout,
            stderr=f"Zig compilation failed:\n{error_msg}",
        )

    if not output_file.exists():
        raise FileNotFoundError(f"Compilation completed but output file not found: {output_file}")

    return output_file


# =============================================================================
# Wheel Building
# =============================================================================


def create_wheel_record(wheel_dir: Path) -> str:
    """Create RECORD file content for wheel."""
    records = []

    for file_path in wheel_dir.rglob("*"):
        if file_path.is_file() and file_path.name != "RECORD":
            rel_path = file_path.relative_to(wheel_dir)
            # Use forward slashes in wheel paths
            rel_path_str = str(rel_path).replace("\\", "/")

            # Calculate hash
            content = file_path.read_bytes()
            hash_digest = hashlib.sha256(content).digest()
            hash_b64 = urlsafe_b64encode(hash_digest).rstrip(b"=").decode("ascii")

            records.append(f"{rel_path_str},sha256={hash_b64},{len(content)}")

    # RECORD itself has no hash
    records.append("RECORD,,")

    return "\n".join(records)


def create_wheel_metadata(
    metadata: dict[str, Any],
    python_tag: str,
    abi_tag: str,
    platform_tag: str,
) -> tuple[str, str]:
    """Create METADATA and WHEEL file contents."""
    name = metadata["name"]
    version = metadata["version"]

    # METADATA content
    meta_lines = [
        "Metadata-Version: 2.1",
        f"Name: {name}",
        f"Version: {version}",
    ]

    if metadata.get("description"):
        meta_lines.append(f"Summary: {metadata['description']}")

    if metadata.get("requires_python"):
        meta_lines.append(f"Requires-Python: {metadata['requires_python']}")

    if metadata.get("license"):
        license_info = metadata["license"]
        if isinstance(license_info, dict):
            meta_lines.append(f"License: {license_info.get('text', '')}")
        else:
            meta_lines.append(f"License: {license_info}")

    for author in metadata.get("authors", []):
        if isinstance(author, dict):
            name_str = author.get("name", "")
            email_str = author.get("email", "")
            if name_str and email_str:
                meta_lines.append(f"Author-Email: {name_str} <{email_str}>")
            elif name_str:
                meta_lines.append(f"Author: {name_str}")

    for classifier in metadata.get("classifiers", []):
        meta_lines.append(f"Classifier: {classifier}")

    for dep in metadata.get("dependencies", []):
        meta_lines.append(f"Requires-Dist: {dep}")

    urls = metadata.get("urls", {})
    for url_name, url_value in urls.items():
        meta_lines.append(f"Project-URL: {url_name}, {url_value}")

    metadata_content = "\n".join(meta_lines)

    # WHEEL content
    wheel_content = "\n".join(
        [
            "Wheel-Version: 1.0",
            "Generator: zigx",
            "Root-Is-Purelib: false",
            f"Tag: {python_tag}-{abi_tag}-{platform_tag}",
        ]
    )

    return metadata_content, wheel_content


def build_wheel_impl(
    project_dir: Path,
    wheel_dir: Path,
    config_settings: dict[str, Any] | None = None,
    editable: bool = False,
) -> str:
    """Implementation of wheel building."""
    # Get configuration
    metadata = get_project_metadata(project_dir)
    zigx_config = get_zigx_config(project_dir)

    name = metadata["name"]
    version = metadata["version"]
    module_name = zigx_config.get("module_name") or name.replace("-", "_")
    src_dir = project_dir / zigx_config["src_dir"]

    # Get wheel tags
    python_tag = get_python_tag()
    abi_tag = get_abi_tag()
    platform_tag = get_platform_tag()

    # Wheel filename
    wheel_name = f"{name}-{version}-{python_tag}-{abi_tag}-{platform_tag}.whl"
    wheel_path = wheel_dir / wheel_name

    # Create temp directory for wheel contents
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        pkg_dir = temp_path / module_name
        pkg_dir.mkdir(parents=True)

        if editable:
            # For editable installs, create .pth file
            pth_content = str(project_dir)
            pth_file = temp_path / f"{module_name}.pth"
            pth_file.write_text(pth_content, encoding="utf-8")
        else:
            # Compile Zig source
            lib_path = compile_zig(
                src_dir=src_dir,
                output_dir=pkg_dir,
                module_name=module_name,
                release=zigx_config.get("release", True),
                strip=zigx_config.get("strip", True),
            )
            lib_filename = lib_path.name

            # Detect exported functions
            functions = scan_zig_sources(src_dir)
            print(f"Detected {len(functions)} exported functions: {[f.name for f in functions]}")

            # Generate __init__.py (maturin-like, no _native.py)
            init_content = generate_init_py(
                module_name=module_name,
                functions=functions,
                lib_filename=lib_filename,
                gil_release=zigx_config.get("gil_release", True),
            )
            init_file = pkg_dir / "__init__.py"
            init_file.write_text(init_content, encoding="utf-8")

            # Create py.typed marker for type checkers
            py_typed = pkg_dir / "py.typed"
            py_typed.write_text("", encoding="utf-8")

        # Create dist-info directory
        dist_info_name = f"{name}-{version}.dist-info"
        dist_info = temp_path / dist_info_name
        dist_info.mkdir(parents=True)

        # Create metadata files
        metadata_content, wheel_content = create_wheel_metadata(
            metadata, python_tag, abi_tag, platform_tag
        )

        (dist_info / "METADATA").write_text(metadata_content, encoding="utf-8")
        (dist_info / "WHEEL").write_text(wheel_content, encoding="utf-8")
        (dist_info / "top_level.txt").write_text(module_name, encoding="utf-8")

        # Create RECORD
        record_content = create_wheel_record(temp_path)
        (dist_info / "RECORD").write_text(record_content, encoding="utf-8")

        # Create wheel zip
        wheel_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(wheel_path, "w", zipfile.ZIP_DEFLATED) as whl:
            for file_path in temp_path.rglob("*"):
                if file_path.is_file():
                    rel_path = file_path.relative_to(temp_path)
                    # Use forward slashes in zip paths
                    arc_name = str(rel_path).replace("\\", "/")
                    whl.write(file_path, arc_name)

    return wheel_name


# =============================================================================
# PEP 517 Interface
# =============================================================================


def get_requires_for_build_wheel(
    config_settings: dict[str, Any] | None = None,
) -> list[str]:
    """Return build requirements for wheel."""
    return []


def get_requires_for_build_sdist(
    config_settings: dict[str, Any] | None = None,
) -> list[str]:
    """Return build requirements for sdist."""
    return []


def get_requires_for_build_editable(
    config_settings: dict[str, Any] | None = None,
) -> list[str]:
    """Return build requirements for editable install."""
    return []


def build_wheel(
    wheel_directory: str,
    config_settings: dict[str, Any] | None = None,
    metadata_directory: str | None = None,
) -> str:
    """Build a wheel distribution."""
    project_dir = Path.cwd()
    wheel_dir = Path(wheel_directory)

    return build_wheel_impl(
        project_dir=project_dir,
        wheel_dir=wheel_dir,
        config_settings=config_settings,
        editable=False,
    )


def build_editable(
    wheel_directory: str,
    config_settings: dict[str, Any] | None = None,
    metadata_directory: str | None = None,
) -> str:
    """Build an editable wheel distribution (PEP 660)."""
    project_dir = Path.cwd()
    wheel_dir = Path(wheel_directory)

    return build_wheel_impl(
        project_dir=project_dir,
        wheel_dir=wheel_dir,
        config_settings=config_settings,
        editable=True,
    )


def build_sdist(
    sdist_directory: str,
    config_settings: dict[str, Any] | None = None,
) -> str:
    """Build a source distribution."""
    project_dir = Path.cwd()
    sdist_dir = Path(sdist_directory)

    metadata = get_project_metadata(project_dir)
    name = metadata["name"]
    version = metadata["version"]

    sdist_name = f"{name}-{version}.tar.gz"
    sdist_path = sdist_dir / sdist_name

    sdist_dir.mkdir(parents=True, exist_ok=True)

    # Files to include in sdist
    include_patterns = [
        "pyproject.toml",
        "README.md",
        "README.rst",
        "LICENSE",
        "LICENSE.txt",
        "CHANGELOG.md",
        "src/**/*.zig",
        "*.zig",
    ]

    with tarfile.open(sdist_path, "w:gz") as tar:
        base_dir = f"{name}-{version}"

        for pattern in include_patterns:
            for file_path in project_dir.glob(pattern):
                if file_path.is_file():
                    rel_path = file_path.relative_to(project_dir)
                    arc_name = f"{base_dir}/{rel_path}"
                    tar.add(file_path, arcname=arc_name)

    return sdist_name


def prepare_metadata_for_build_wheel(
    metadata_directory: str,
    config_settings: dict[str, Any] | None = None,
) -> str:
    """Prepare wheel metadata directory."""
    project_dir = Path.cwd()
    meta_dir = Path(metadata_directory)

    metadata = get_project_metadata(project_dir)
    name = metadata["name"]
    version = metadata["version"]

    python_tag = get_python_tag()
    abi_tag = get_abi_tag()
    platform_tag = get_platform_tag()

    dist_info_name = f"{name}-{version}.dist-info"
    dist_info = meta_dir / dist_info_name
    dist_info.mkdir(parents=True, exist_ok=True)

    metadata_content, wheel_content = create_wheel_metadata(
        metadata, python_tag, abi_tag, platform_tag
    )

    (dist_info / "METADATA").write_text(metadata_content, encoding="utf-8")
    (dist_info / "WHEEL").write_text(wheel_content, encoding="utf-8")

    return dist_info_name


def prepare_metadata_for_build_editable(
    metadata_directory: str,
    config_settings: dict[str, Any] | None = None,
) -> str:
    """Prepare editable wheel metadata directory."""
    return prepare_metadata_for_build_wheel(metadata_directory, config_settings)


# =============================================================================
# CLI Entry Point
# =============================================================================

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="ZigX Build Backend")
    parser.add_argument("command", choices=["wheel", "sdist", "develop"])
    parser.add_argument("--output", "-o", default="dist", help="Output directory")

    args = parser.parse_args()

    if args.command == "wheel":
        wheel_name = build_wheel(args.output)
        print(f"Built wheel: {wheel_name}")
    elif args.command == "sdist":
        sdist_name = build_sdist(args.output)
        print(f"Built sdist: {sdist_name}")
    elif args.command == "develop":
        wheel_name = build_editable(args.output)
        print(f"Built editable wheel: {wheel_name}")
