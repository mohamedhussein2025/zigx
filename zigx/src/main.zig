const std = @import("std");
const builtin = @import("builtin");

// Core modules (imported via build.zig module system)
const config = @import("config");
const platform = @import("platform");

// Command modules (imported via build.zig module system)
const new_cmd = @import("new_cmd");
const develop_cmd = @import("develop_cmd");
const build_cmd = @import("build_cmd");
const publish_cmd = @import("publish_cmd");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "new")) {
        if (args.len < 3) {
            printError("Error: 'new' command requires a project name\n");
            printError("Usage: zigx new <project-name>\n");
            std.process.exit(1);
        }
        try new_cmd.execute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "develop")) {
        try develop_cmd.execute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "build")) {
        try build_cmd.execute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "publish")) {
        try publish_cmd.execute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        printUsage();
    } else if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-V")) {
        printVersion();
    } else {
        printError("Unknown command: ");
        printError(command);
        printError("\n");
        printUsage();
        std.process.exit(1);
    }
}

fn printUsage() void {
    const usage =
        \\ZigX - Build Python extensions with Zig
        \\
        \\USAGE:
        \\    zigx <COMMAND> [OPTIONS]
        \\
        \\COMMANDS:
        \\    new <name>       Create a new ZigX project
        \\    develop          Build and install in development mode
        \\    build            Build a wheel package
        \\    publish          Build and publish to PyPI
        \\
        \\OPTIONS:
        \\    -h, --help       Print help information
        \\    -V, --version    Print version information
        \\
        \\EXAMPLES:
        \\    zigx new myproject       Create new project 'myproject'
        \\    zigx develop             Build and install for development
        \\    zigx build --release     Build optimized wheel
        \\
        \\For more information, visit: https://github.com/zigx
        \\
    ;
    std.debug.print("{s}", .{usage});
}

fn printVersion() void {
    std.debug.print("zigx {s}\n", .{config.VERSION});
}

fn printError(msg: []const u8) void {
    std.debug.print("{s}", .{msg});
}

test "basic test" {
    // Basic sanity test
    try std.testing.expect(true);
}
