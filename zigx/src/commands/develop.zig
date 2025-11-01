const std = @import("std");
const fs = std.fs;

// Modules imported via build.zig
const config = @import("config");
const platform = @import("platform");
const generator = @import("generator");
const builder = @import("builder");

pub fn execute(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    std.debug.print("🔧 Building and installing in development mode...\n", .{});

    // Get current directory as project root
    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);

    // Load configuration
    var cfg = config.loadConfig(allocator, cwd) catch {
        std.debug.print("Error: Could not load pyproject.toml. Make sure you're in a ZigX project directory.\n", .{});
        return error.ConfigNotFound;
    };
    defer cfg.deinit(allocator);

    std.debug.print("  Project: {s}\n", .{cfg.name});
    std.debug.print("  Version: {s}\n", .{cfg.version});

    // Detect platform
    var plat = try platform.detectPlatform(allocator);
    defer plat.deinit(allocator);

    std.debug.print("  Python: {d}.{d}.{d}\n", .{ plat.python_version.major, plat.python_version.minor, plat.python_version.patch });
    std.debug.print("  Extension suffix: {s}\n", .{plat.ext_suffix});

    // Build the shared library
    std.debug.print("\n📦 Building shared library (debug)...\n", .{});
    const lib_path = try builder.buildSharedLibrary(allocator, cwd, &cfg, &plat, false);
    defer allocator.free(lib_path);
    std.debug.print("  Built: {s}\n", .{lib_path});

    // Generate Python loader
    std.debug.print("\n📝 Generating Python bindings...\n", .{});
    try generator.generateNativePy(allocator, cwd, &cfg);
    try generator.generatePyi(allocator, cwd, &cfg);
    std.debug.print("  Generated _native.py and .pyi stubs\n", .{});

    // Copy to package directory
    std.debug.print("\n📋 Installing to package directory...\n", .{});
    try installToPackage(allocator, cwd, &cfg, lib_path, &plat);

    std.debug.print("\n✅ Development install complete!\n", .{});
    std.debug.print("\nYou can now use:\n", .{});
    std.debug.print("  python -c \"import {s}; print({s}.add(1, 2))\"\n", .{ cfg.name, cfg.name });
}

fn installToPackage(
    allocator: std.mem.Allocator,
    project_dir: []const u8,
    cfg: *const config.ZigxConfig,
    lib_path: []const u8,
    plat: *const platform.Platform,
) !void {
    // Construct extension filename
    const ext_name = try std.fmt.allocPrint(allocator, "_{s}_ext{s}", .{ cfg.name, plat.ext_suffix });
    defer allocator.free(ext_name);

    // Destination: <project>/<name>/<ext_name>
    const dest_path = try std.fs.path.join(allocator, &.{ project_dir, cfg.name, ext_name });
    defer allocator.free(dest_path);

    // Copy the library
    try fs.cwd().copyFile(lib_path, fs.cwd(), dest_path, .{});
    std.debug.print("  Copied to: {s}\n", .{dest_path});
}
