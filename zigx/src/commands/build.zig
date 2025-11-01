const std = @import("std");
const config = @import("config");
const platform = @import("platform");
const generator = @import("generator");
const builder = @import("builder");
const wheel = @import("wheel");

pub fn execute(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    std.debug.print("📦 Building wheel package...\n", .{});

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

    // Build the shared library (release mode for wheels)
    std.debug.print("\n🔨 Building shared library (release)...\n", .{});
    const lib_path = try builder.buildSharedLibrary(allocator, cwd, &cfg, &plat, true);
    defer allocator.free(lib_path);
    std.debug.print("  Built: {s}\n", .{lib_path});

    // Generate Python loader
    std.debug.print("\n📝 Generating Python bindings...\n", .{});
    try generator.generateNativePy(allocator, cwd, &cfg);
    try generator.generatePyi(allocator, cwd, &cfg);
    try generator.generateInitPy(allocator, cwd, &cfg);
    std.debug.print("  Generated _native.py, .pyi stubs, and __init__.py\n", .{});

    // Create the wheel
    std.debug.print("\n📦 Creating wheel...\n", .{});
    const wheel_path = try wheel.createWheel(allocator, cwd, &cfg, &plat, lib_path);
    defer allocator.free(wheel_path);

    std.debug.print("\n✅ Successfully built wheel: {s}\n", .{wheel_path});
}
