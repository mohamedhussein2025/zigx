const std = @import("std");
const fs = std.fs;
const config = @import("config");
const platform = @import("platform");

pub fn buildSharedLibrary(
    allocator: std.mem.Allocator,
    project_dir: []const u8,
    cfg: *const config.ZigxConfig,
    plat: *const platform.Platform,
    release: bool,
) ![]const u8 {
    // Create build directory
    const build_dir = try std.fs.path.join(allocator, &.{ project_dir, ".zigx_build" });
    defer allocator.free(build_dir);

    fs.cwd().makeDir(build_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Source file path
    const src_path = try std.fs.path.join(allocator, &.{ project_dir, cfg.src_path });
    defer allocator.free(src_path);

    // Output library name
    const lib_name = try std.fmt.allocPrint(allocator, "_{s}_ext", .{cfg.name});
    defer allocator.free(lib_name);

    // Output path (the file Zig will create)
    const output_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ lib_name, plat.sharedLibExt() });
    defer allocator.free(output_name);

    const output_path = try std.fs.path.join(allocator, &.{ build_dir, output_name });
    errdefer allocator.free(output_path);

    // Find zig executable
    const zig_exe = platform.findZigExecutable(allocator) catch {
        std.debug.print("Error: Could not find zig. Make sure it's installed and in PATH.\n", .{});
        return error.ZigNotFound;
    };
    defer allocator.free(zig_exe);

    // Build command
    var argv: std.ArrayListUnmanaged([]const u8) = .empty;
    defer argv.deinit(allocator);

    try argv.append(allocator, zig_exe);
    try argv.append(allocator, "build-lib");
    try argv.append(allocator, src_path);
    try argv.append(allocator, "-dynamic");
    try argv.append(allocator, "-fPIC");

    // Optimization level
    if (release) {
        try argv.append(allocator, "-O");
        try argv.append(allocator, "ReleaseFast");
    } else {
        try argv.append(allocator, "-O");
        try argv.append(allocator, "Debug");
    }

    // Output path
    const emit_arg = try std.fmt.allocPrint(allocator, "-femit-bin={s}", .{output_path});
    defer allocator.free(emit_arg);
    try argv.append(allocator, emit_arg);

    // Run the build
    std.debug.print("  Running: ", .{});
    for (argv.items) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});

    var child = std.process.Child.init(argv.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Read stderr for error messages
    var stderr_list: std.ArrayListUnmanaged(u8) = .empty;
    defer stderr_list.deinit(allocator);

    if (child.stderr) |stderr| {
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = stderr.read(&buf) catch break;
            if (n == 0) break;
            try stderr_list.appendSlice(allocator, buf[0..n]);
        }
    }

    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("Build failed:\n{s}\n", .{stderr_list.items});
                return error.BuildFailed;
            }
        },
        else => {
            std.debug.print("Build process terminated abnormally\n", .{});
            return error.BuildFailed;
        },
    }

    return output_path;
}

pub fn getTargetTriple(allocator: std.mem.Allocator, plat: *const platform.Platform) ![]const u8 {
    return platform.getZigBuildTarget(plat.*, allocator);
}
