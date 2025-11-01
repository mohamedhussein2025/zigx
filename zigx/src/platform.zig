const std = @import("std");
const builtin = @import("builtin");

pub const Platform = struct {
    os: Os,
    arch: Arch,
    python_version: PythonVersion,
    ext_suffix: []const u8,
    site_packages: []const u8,
    python_path: []const u8,
    include_path: []const u8,
    lib_path: []const u8,

    pub const Os = enum {
        linux,
        windows,
        macos,

        pub fn toString(self: Os) []const u8 {
            return switch (self) {
                .linux => "linux",
                .windows => "windows",
                .macos => "macos",
            };
        }

        pub fn zigTarget(self: Os) []const u8 {
            return switch (self) {
                .linux => "linux",
                .windows => "windows",
                .macos => "macos",
            };
        }
    };

    pub const Arch = enum {
        x86_64,
        aarch64,
        x86,

        pub fn toString(self: Arch) []const u8 {
            return switch (self) {
                .x86_64 => "x86_64",
                .aarch64 => "aarch64",
                .x86 => "x86",
            };
        }

        pub fn zigTarget(self: Arch) []const u8 {
            return switch (self) {
                .x86_64 => "x86_64",
                .aarch64 => "aarch64",
                .x86 => "x86",
            };
        }

        pub fn wheelTag(self: Arch) []const u8 {
            return switch (self) {
                .x86_64 => "x86_64",
                .aarch64 => "aarch64",
                .x86 => "i686",
            };
        }
    };

    pub const PythonVersion = struct {
        major: u32,
        minor: u32,
        patch: u32,

        pub fn abiTag(self: PythonVersion, allocator: std.mem.Allocator) ![]const u8 {
            return std.fmt.allocPrint(allocator, "cp{d}{d}", .{ self.major, self.minor });
        }
    };

    pub fn deinit(self: *Platform, allocator: std.mem.Allocator) void {
        allocator.free(self.ext_suffix);
        allocator.free(self.site_packages);
        allocator.free(self.python_path);
        allocator.free(self.include_path);
        allocator.free(self.lib_path);
    }

    pub fn wheelPlatformTag(self: Platform, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.os) {
            .linux => std.fmt.allocPrint(allocator, "manylinux_2_17_{s}", .{self.arch.wheelTag()}),
            .windows => std.fmt.allocPrint(allocator, "win_{s}", .{if (self.arch == .x86_64) "amd64" else "32"}),
            .macos => std.fmt.allocPrint(allocator, "macosx_11_0_{s}", .{self.arch.wheelTag()}),
        };
    }

    pub fn sharedLibExt(self: Platform) []const u8 {
        return switch (self.os) {
            .linux => ".so",
            .macos => ".so", // Python uses .so even on macOS
            .windows => ".pyd",
        };
    }
};

pub fn detectPlatform(allocator: std.mem.Allocator) !Platform {
    // Detect OS and architecture from builtin
    const os: Platform.Os = switch (builtin.os.tag) {
        .linux => .linux,
        .windows => .windows,
        .macos => .macos,
        else => {
            std.debug.print("Unsupported operating system\n", .{});
            return error.UnsupportedPlatform;
        },
    };

    const arch: Platform.Arch = switch (builtin.cpu.arch) {
        .x86_64 => .x86_64,
        .aarch64 => .aarch64,
        .x86 => .x86,
        else => {
            std.debug.print("Unsupported architecture\n", .{});
            return error.UnsupportedPlatform;
        },
    };

    // Query Python for configuration
    const python_info = try queryPython(allocator);

    return Platform{
        .os = os,
        .arch = arch,
        .python_version = python_info.version,
        .ext_suffix = python_info.ext_suffix,
        .site_packages = python_info.site_packages,
        .python_path = python_info.python_path,
        .include_path = python_info.include_path,
        .lib_path = python_info.lib_path,
    };
}

const PythonInfo = struct {
    version: Platform.PythonVersion,
    ext_suffix: []const u8,
    site_packages: []const u8,
    python_path: []const u8,
    include_path: []const u8,
    lib_path: []const u8,
};

fn queryPython(allocator: std.mem.Allocator) !PythonInfo {
    // Python script to query all needed information
    const query_script =
        \\import sys
        \\import sysconfig
        \\print(f"{sys.version_info.major}")
        \\print(f"{sys.version_info.minor}")
        \\print(f"{sys.version_info.micro}")
        \\print(sysconfig.get_config_var("EXT_SUFFIX") or "")
        \\print(sysconfig.get_path("purelib"))
        \\print(sys.executable)
        \\print(sysconfig.get_path("include"))
        \\libdir = sysconfig.get_config_var("LIBDIR") or ""
        \\if not libdir and sys.platform == "win32":
        \\    import os
        \\    libdir = os.path.join(sys.prefix, "libs")
        \\print(libdir)
    ;

    // Try different python commands
    const python_commands = [_][]const u8{ "python", "python3" };

    for (python_commands) |python_cmd| {
        const result = runPythonScript(allocator, python_cmd, query_script) catch continue;
        defer allocator.free(result);

        var lines = std.mem.splitScalar(u8, result, '\n');

        const major_str = lines.next() orelse continue;
        const minor_str = lines.next() orelse continue;
        const patch_str = lines.next() orelse continue;
        const ext_suffix_raw = lines.next() orelse continue;
        const site_packages_raw = lines.next() orelse continue;
        const python_path_raw = lines.next() orelse continue;
        const include_path_raw = lines.next() orelse continue;
        const lib_path_raw = lines.next() orelse continue;

        const major = std.fmt.parseInt(u32, std.mem.trim(u8, major_str, " \t\r\n"), 10) catch continue;
        const minor = std.fmt.parseInt(u32, std.mem.trim(u8, minor_str, " \t\r\n"), 10) catch continue;
        const patch = std.fmt.parseInt(u32, std.mem.trim(u8, patch_str, " \t\r\n"), 10) catch continue;

        return PythonInfo{
            .version = .{
                .major = major,
                .minor = minor,
                .patch = patch,
            },
            .ext_suffix = try allocator.dupe(u8, std.mem.trim(u8, ext_suffix_raw, " \t\r\n")),
            .site_packages = try allocator.dupe(u8, std.mem.trim(u8, site_packages_raw, " \t\r\n")),
            .python_path = try allocator.dupe(u8, std.mem.trim(u8, python_path_raw, " \t\r\n")),
            .include_path = try allocator.dupe(u8, std.mem.trim(u8, include_path_raw, " \t\r\n")),
            .lib_path = try allocator.dupe(u8, std.mem.trim(u8, lib_path_raw, " \t\r\n")),
        };
    }

    std.debug.print("Error: Could not find Python. Make sure Python is installed and in PATH.\n", .{});
    return error.PythonNotFound;
}

fn runPythonScript(allocator: std.mem.Allocator, python_cmd: []const u8, script: []const u8) ![]const u8 {
    const argv = [_][]const u8{ python_cmd, "-c", script };
    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Read stdout before waiting
    var stdout_list: std.ArrayListUnmanaged(u8) = .empty;
    defer stdout_list.deinit(allocator);

    if (child.stdout) |stdout| {
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = stdout.read(&buf) catch break;
            if (n == 0) break;
            try stdout_list.appendSlice(allocator, buf[0..n]);
        }
    }

    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                return error.PythonError;
            }
        },
        else => {
            return error.PythonError;
        },
    }

    // Return owned slice
    return try allocator.dupe(u8, stdout_list.items);
}

pub fn getZigBuildTarget(platform: Platform, allocator: std.mem.Allocator) ![]const u8 {
    const arch_str = platform.arch.zigTarget();
    const os_str = platform.os.zigTarget();

    return switch (platform.os) {
        .linux => std.fmt.allocPrint(allocator, "{s}-{s}-gnu", .{ arch_str, os_str }),
        .macos => std.fmt.allocPrint(allocator, "{s}-{s}", .{ arch_str, os_str }),
        .windows => std.fmt.allocPrint(allocator, "{s}-{s}-msvc", .{ arch_str, os_str }),
    };
}

pub fn findZigExecutable(allocator: std.mem.Allocator) ![]const u8 {
    // Try to find zig in PATH
    const zig_commands = [_][]const u8{ "zig", "zig.exe" };

    for (zig_commands) |zig_cmd| {
        const argv = [_][]const u8{ zig_cmd, "version" };
        var child = std.process.Child.init(&argv, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch continue;
        const term = child.wait() catch continue;
        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    return try allocator.dupe(u8, zig_cmd);
                }
            },
            else => {},
        }
    }

    return error.ZigNotFound;
}

test "platform detection" {
    // Basic compile test
    const allocator = std.testing.allocator;
    _ = allocator;
}
