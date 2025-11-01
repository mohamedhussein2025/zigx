const std = @import("std");
const fs = std.fs;

// Modules imported via build.zig
const config = @import("config");
const build_cmd = @import("build_cmd");

pub fn execute(allocator: std.mem.Allocator, args: []const []const u8) !void {
    std.debug.print("📤 Publishing to PyPI...\n", .{});

    // First build the wheel in release mode
    const build_args = [_][]const u8{"--release"};
    try build_cmd.execute(allocator, &build_args);

    // Get wheel path
    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);

    var cfg = config.loadConfig(allocator, cwd) catch {
        std.debug.print("Error: Could not load pyproject.toml.\n", .{});
        return error.ConfigNotFound;
    };
    defer cfg.deinit(allocator);

    // Check for repository argument
    var repository: []const u8 = "pypi";
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--repository=")) {
            repository = arg[13..];
        }
    }

    // Run twine upload
    std.debug.print("\n📤 Uploading to {s}...\n", .{repository});

    const dist_pattern = try std.fmt.allocPrint(allocator, "dist/{s}-*.whl", .{cfg.name});
    defer allocator.free(dist_pattern);

    const twine_args = [_][]const u8{
        "python",
        "-m",
        "twine",
        "upload",
        "--repository",
        repository,
        dist_pattern,
    };

    var child = std.process.Child.init(&twine_args, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code == 0) {
                std.debug.print("\n✅ Published successfully!\n", .{});
            } else {
                std.debug.print("\n❌ Failed to publish (exit code: {d})\n", .{code});
                std.debug.print("Make sure twine is installed: pip install twine\n", .{});
                return error.PublishFailed;
            }
        },
        else => {
            std.debug.print("\n❌ Failed to publish\n", .{});
            return error.PublishFailed;
        },
    }
}
