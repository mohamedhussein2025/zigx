const std = @import("std");
const builtin = @import("builtin");

pub const VERSION = "0.1.0";

/// Configuration loaded from pyproject.toml [tool.zigx] section
pub const ZigxConfig = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    authors: []const []const u8,
    license: []const u8,
    python_requires: []const u8,
    src_path: []const u8,
    functions: []const FunctionConfig,

    pub const FunctionConfig = struct {
        name: []const u8,
        args: []const ArgConfig,
        return_type: []const u8,
        gil_release: bool,
        doc: []const u8,
    };

    pub const ArgConfig = struct {
        name: []const u8,
        zig_type: []const u8,
        py_type: []const u8,
    };

    pub fn deinit(self: *ZigxConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.description);
        for (self.authors) |author| {
            allocator.free(author);
        }
        allocator.free(self.authors);
        allocator.free(self.license);
        allocator.free(self.python_requires);
        allocator.free(self.src_path);
        for (self.functions) |func| {
            allocator.free(func.name);
            for (func.args) |arg| {
                allocator.free(arg.name);
                allocator.free(arg.zig_type);
                allocator.free(arg.py_type);
            }
            allocator.free(func.args);
            allocator.free(func.return_type);
            allocator.free(func.doc);
        }
        allocator.free(self.functions);
    }
};

/// Default configuration values
pub const defaults = struct {
    pub const src_path = "src/lib.zig";
    pub const python_requires = ">=3.8";
    pub const version = "0.1.0";
    pub const description = "";
    pub const license = "MIT";
};

pub fn loadConfig(allocator: std.mem.Allocator, project_dir: []const u8) !ZigxConfig {
    const pyproject_path = try std.fs.path.join(allocator, &.{ project_dir, "pyproject.toml" });
    defer allocator.free(pyproject_path);

    const file = std.fs.cwd().openFile(pyproject_path, .{}) catch |err| {
        std.debug.print("Error: Could not open pyproject.toml: {}\n", .{err});
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    return parseToml(allocator, content);
}

fn parseToml(allocator: std.mem.Allocator, content: []const u8) !ZigxConfig {
    var config_out = ZigxConfig{
        .name = try allocator.dupe(u8, ""),
        .version = try allocator.dupe(u8, defaults.version),
        .description = try allocator.dupe(u8, defaults.description),
        .authors = &[_][]const u8{},
        .license = try allocator.dupe(u8, defaults.license),
        .python_requires = try allocator.dupe(u8, defaults.python_requires),
        .src_path = try allocator.dupe(u8, defaults.src_path),
        .functions = &[_]ZigxConfig.FunctionConfig{},
    };

    var in_tool_zigx = false;
    var in_project = false;
    var functions_list: std.ArrayListUnmanaged(ZigxConfig.FunctionConfig) = .empty;
    defer functions_list.deinit(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Section headers
        if (std.mem.startsWith(u8, trimmed, "[tool.zigx]")) {
            in_tool_zigx = true;
            in_project = false;
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "[project]")) {
            in_project = true;
            in_tool_zigx = false;
            continue;
        } else if (trimmed[0] == '[') {
            // Check for [[tool.zigx.functions]]
            if (std.mem.startsWith(u8, trimmed, "[[tool.zigx.functions]]")) {
                // Start a new function config
                try functions_list.append(allocator, ZigxConfig.FunctionConfig{
                    .name = try allocator.dupe(u8, ""),
                    .args = &[_]ZigxConfig.ArgConfig{},
                    .return_type = try allocator.dupe(u8, "void"),
                    .gil_release = true,
                    .doc = try allocator.dupe(u8, ""),
                });
                in_tool_zigx = true;
                continue;
            }
            in_tool_zigx = false;
            in_project = false;
            continue;
        }

        // Parse key = value
        if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
            const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
            const value_raw = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");
            const value = stripQuotes(value_raw);

            if (in_project) {
                if (std.mem.eql(u8, key, "name")) {
                    allocator.free(config_out.name);
                    config_out.name = try allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, key, "version")) {
                    allocator.free(config_out.version);
                    config_out.version = try allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, key, "description")) {
                    allocator.free(config_out.description);
                    config_out.description = try allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, key, "requires-python")) {
                    allocator.free(config_out.python_requires);
                    config_out.python_requires = try allocator.dupe(u8, value);
                }
            } else if (in_tool_zigx) {
                if (std.mem.eql(u8, key, "src")) {
                    allocator.free(config_out.src_path);
                    config_out.src_path = try allocator.dupe(u8, value);
                } else if (functions_list.items.len > 0) {
                    // We're in a function definition
                    const idx = functions_list.items.len - 1;
                    if (std.mem.eql(u8, key, "name")) {
                        allocator.free(functions_list.items[idx].name);
                        functions_list.items[idx].name = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "return_type")) {
                        allocator.free(functions_list.items[idx].return_type);
                        functions_list.items[idx].return_type = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "gil_release")) {
                        functions_list.items[idx].gil_release = std.mem.eql(u8, value, "true");
                    } else if (std.mem.eql(u8, key, "doc")) {
                        allocator.free(functions_list.items[idx].doc);
                        functions_list.items[idx].doc = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "args")) {
                        // Parse args like "a:i32:int, b:i32:int"
                        functions_list.items[idx].args = try parseArgs(allocator, value);
                    }
                }
            }
        }
    }

    config_out.functions = try functions_list.toOwnedSlice(allocator);
    return config_out;
}

fn parseArgs(allocator: std.mem.Allocator, args_str: []const u8) ![]const ZigxConfig.ArgConfig {
    var args: std.ArrayListUnmanaged(ZigxConfig.ArgConfig) = .empty;
    defer args.deinit(allocator);

    var arg_iter = std.mem.splitScalar(u8, args_str, ',');
    while (arg_iter.next()) |arg_part| {
        const trimmed = std.mem.trim(u8, arg_part, " \t");
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ':');
        const name = parts.next() orelse continue;
        const zig_type = parts.next() orelse "i32";
        const py_type = parts.next() orelse "int";

        try args.append(allocator, ZigxConfig.ArgConfig{
            .name = try allocator.dupe(u8, std.mem.trim(u8, name, " \t")),
            .zig_type = try allocator.dupe(u8, std.mem.trim(u8, zig_type, " \t")),
            .py_type = try allocator.dupe(u8, std.mem.trim(u8, py_type, " \t")),
        });
    }

    return try args.toOwnedSlice(allocator);
}

fn stripQuotes(s: []const u8) []const u8 {
    if (s.len < 2) return s;
    if ((s[0] == '"' and s[s.len - 1] == '"') or (s[0] == '\'' and s[s.len - 1] == '\'')) {
        return s[1 .. s.len - 1];
    }
    return s;
}

pub fn generatePyprojectToml(name: []const u8, version: []const u8) []const u8 {
    _ = name;
    _ = version;
    return 
    \\[build-system]
    \\requires = ["zigx"]
    \\build-backend = "zigx.build"
    \\
    \\[project]
    \\name = "{name}"
    \\version = "{version}"
    \\description = "A Python extension built with ZigX"
    \\readme = "README.md"
    \\requires-python = ">=3.8"
    \\classifiers = [
    \\    "Programming Language :: Python :: 3",
    \\    "Programming Language :: Zig",
    \\    "License :: OSI Approved :: MIT License",
    \\    "Operating System :: OS Independent",
    \\]
    \\
    \\[tool.zigx]
    \\src = "src/lib.zig"
    \\
    \\# Define your exported functions here
    \\# Each function needs: name, args (name:zig_type:py_type), return_type
    \\[[tool.zigx.functions]]
    \\name = "add"
    \\args = "a:i32:int, b:i32:int"
    \\return_type = "i32"
    \\gil_release = true
    \\doc = "Add two integers"
    \\
    \\[[tool.zigx.functions]]
    \\name = "fib"
    \\args = "n:u64:int"
    \\return_type = "u64"
    \\gil_release = true
    \\doc = "Calculate the nth Fibonacci number"
    \\
    ;
}

test "stripQuotes" {
    try std.testing.expectEqualStrings("hello", stripQuotes("\"hello\""));
    try std.testing.expectEqualStrings("hello", stripQuotes("'hello'"));
    try std.testing.expectEqualStrings("hello", stripQuotes("hello"));
}
