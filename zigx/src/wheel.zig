const std = @import("std");
const fs = std.fs;
const config = @import("config");
const platform = @import("platform");

pub fn createWheel(
    allocator: std.mem.Allocator,
    project_dir: []const u8,
    cfg: *const config.ZigxConfig,
    plat: *const platform.Platform,
    lib_path: []const u8,
) ![]const u8 {
    // Get wheel filename components
    const abi_tag = try plat.python_version.abiTag(allocator);
    defer allocator.free(abi_tag);

    const platform_tag = try plat.wheelPlatformTag(allocator);
    defer allocator.free(platform_tag);

    // Wheel filename: {name}-{version}-{python_tag}-{abi_tag}-{platform_tag}.whl
    const wheel_name = try std.fmt.allocPrint(
        allocator,
        "{s}-{s}-{s}-{s}-{s}.whl",
        .{ cfg.name, cfg.version, abi_tag, abi_tag, platform_tag },
    );
    defer allocator.free(wheel_name);

    const dist_dir = try std.fs.path.join(allocator, &.{ project_dir, "dist" });
    defer allocator.free(dist_dir);

    // Ensure dist directory exists
    fs.cwd().makeDir(dist_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const wheel_path = try std.fs.path.join(allocator, &.{ dist_dir, wheel_name });
    errdefer allocator.free(wheel_path);

    // Create the wheel as a ZIP file
    try createWheelZip(allocator, wheel_path, project_dir, cfg, plat, lib_path, abi_tag, platform_tag);

    return wheel_path;
}

fn createWheelZip(
    allocator: std.mem.Allocator,
    wheel_path: []const u8,
    project_dir: []const u8,
    cfg: *const config.ZigxConfig,
    plat: *const platform.Platform,
    lib_path: []const u8,
    abi_tag: []const u8,
    platform_tag: []const u8,
) !void {
    // For now, we'll create the wheel structure and use Python's zipfile
    // to create the actual wheel. This is a pragmatic approach that ensures
    // the wheel is valid.

    // Create a temporary directory for wheel contents
    const temp_dir = try std.fs.path.join(allocator, &.{ project_dir, ".zigx_build", "wheel_temp" });
    defer allocator.free(temp_dir);

    // Clean and recreate temp dir
    fs.cwd().deleteTree(temp_dir) catch {};
    try fs.cwd().makePath(temp_dir);
    defer fs.cwd().deleteTree(temp_dir) catch {};

    // Create package directory inside temp
    const pkg_dir = try std.fs.path.join(allocator, &.{ temp_dir, cfg.name });
    defer allocator.free(pkg_dir);
    try fs.cwd().makePath(pkg_dir);

    // Copy Python files from project
    try copyPythonFiles(allocator, project_dir, cfg, pkg_dir);

    // Copy the native extension
    const ext_name = try std.fmt.allocPrint(allocator, "_{s}_ext{s}", .{ cfg.name, plat.ext_suffix });
    defer allocator.free(ext_name);

    const ext_dest = try std.fs.path.join(allocator, &.{ pkg_dir, ext_name });
    defer allocator.free(ext_dest);

    try fs.cwd().copyFile(lib_path, fs.cwd(), ext_dest, .{});

    // Create .dist-info directory
    const dist_info_name = try std.fmt.allocPrint(allocator, "{s}-{s}.dist-info", .{ cfg.name, cfg.version });
    defer allocator.free(dist_info_name);

    const dist_info_dir = try std.fs.path.join(allocator, &.{ temp_dir, dist_info_name });
    defer allocator.free(dist_info_dir);
    try fs.cwd().makePath(dist_info_dir);

    // Write METADATA
    try writeMetadata(allocator, dist_info_dir, cfg);

    // Write WHEEL
    try writeWheelFile(allocator, dist_info_dir, abi_tag, platform_tag);

    // Write RECORD (empty for now, Python's pip will handle this)
    try writeRecord(allocator, dist_info_dir);

    // Write top_level.txt
    try writeTopLevel(allocator, dist_info_dir, cfg);

    // Create the wheel ZIP using Python
    try createZipWithPython(allocator, temp_dir, wheel_path);
}

fn copyPythonFiles(
    allocator: std.mem.Allocator,
    project_dir: []const u8,
    cfg: *const config.ZigxConfig,
    dest_dir: []const u8,
) !void {
    const src_pkg_dir = try std.fs.path.join(allocator, &.{ project_dir, cfg.name });
    defer allocator.free(src_pkg_dir);

    var dir = fs.cwd().openDir(src_pkg_dir, .{ .iterate = true }) catch {
        return; // Package directory might not exist yet
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        // Copy .py and .pyi files
        const name = entry.name;
        if (std.mem.endsWith(u8, name, ".py") or std.mem.endsWith(u8, name, ".pyi")) {
            const src_path = try std.fs.path.join(allocator, &.{ src_pkg_dir, name });
            defer allocator.free(src_path);

            const dest_path = try std.fs.path.join(allocator, &.{ dest_dir, name });
            defer allocator.free(dest_path);

            fs.cwd().copyFile(src_path, fs.cwd(), dest_path, .{}) catch |err| {
                std.debug.print("Warning: Could not copy {s}: {}\n", .{ name, err });
            };
        }
    }
}

fn writeMetadata(allocator: std.mem.Allocator, dist_info_dir: []const u8, cfg: *const config.ZigxConfig) !void {
    const path = try std.fs.path.join(allocator, &.{ dist_info_dir, "METADATA" });
    defer allocator.free(path);

    const file = try fs.cwd().createFile(path, .{});
    defer file.close();

    const content = try std.fmt.allocPrint(allocator,
        \\Metadata-Version: 2.1
        \\Name: {s}
        \\Version: {s}
        \\Summary: {s}
        \\License: {s}
        \\Requires-Python: {s}
        \\
    , .{ cfg.name, cfg.version, cfg.description, cfg.license, cfg.python_requires });
    defer allocator.free(content);
    try file.writeAll(content);
}

fn writeWheelFile(
    allocator: std.mem.Allocator,
    dist_info_dir: []const u8,
    abi_tag: []const u8,
    platform_tag: []const u8,
) !void {
    const path = try std.fs.path.join(allocator, &.{ dist_info_dir, "WHEEL" });
    defer allocator.free(path);

    const file = try fs.cwd().createFile(path, .{});
    defer file.close();

    const content = try std.fmt.allocPrint(allocator,
        \\Wheel-Version: 1.0
        \\Generator: zigx
        \\Root-Is-Purelib: false
        \\Tag: {s}-{s}-{s}
        \\
    , .{ abi_tag, abi_tag, platform_tag });
    defer allocator.free(content);
    try file.writeAll(content);
}

fn writeRecord(allocator: std.mem.Allocator, dist_info_dir: []const u8) !void {
    const path = try std.fs.path.join(allocator, &.{ dist_info_dir, "RECORD" });
    defer allocator.free(path);

    const file = try fs.cwd().createFile(path, .{});
    defer file.close();
    // RECORD will be populated by pip install
}

fn writeTopLevel(allocator: std.mem.Allocator, dist_info_dir: []const u8, cfg: *const config.ZigxConfig) !void {
    const path = try std.fs.path.join(allocator, &.{ dist_info_dir, "top_level.txt" });
    defer allocator.free(path);

    const file = try fs.cwd().createFile(path, .{});
    defer file.close();

    const content = try std.fmt.allocPrint(allocator, "{s}\n", .{cfg.name});
    defer allocator.free(content);
    try file.writeAll(content);
}

fn createZipWithPython(allocator: std.mem.Allocator, source_dir: []const u8, wheel_path: []const u8) !void {
    // Use Python to create a proper ZIP file
    const script = try std.fmt.allocPrint(allocator,
        \\import zipfile
        \\import os
        \\source = r'{s}'
        \\output = r'{s}'
        \\with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as zf:
        \\    for root, dirs, files in os.walk(source):
        \\        for file in files:
        \\            file_path = os.path.join(root, file)
        \\            arc_name = os.path.relpath(file_path, source)
        \\            zf.write(file_path, arc_name)
        \\print('Created wheel:', output)
    , .{ source_dir, wheel_path });
    defer allocator.free(script);

    const argv = [_][]const u8{ "python", "-c", script };
    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                return error.WheelCreationFailed;
            }
        },
        else => return error.WheelCreationFailed,
    }
}
