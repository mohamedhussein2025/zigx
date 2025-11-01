const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create shared modules for the core functionality
    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
        .target = target,
        .optimize = optimize,
    });

    const platform_mod = b.createModule(.{
        .root_source_file = b.path("src/platform.zig"),
        .target = target,
        .optimize = optimize,
    });

    const generator_mod = b.createModule(.{
        .root_source_file = b.path("src/generator.zig"),
        .target = target,
        .optimize = optimize,
    });
    generator_mod.addImport("config", config_mod);

    const builder_mod = b.createModule(.{
        .root_source_file = b.path("src/builder.zig"),
        .target = target,
        .optimize = optimize,
    });
    builder_mod.addImport("config", config_mod);
    builder_mod.addImport("platform", platform_mod);

    const wheel_mod = b.createModule(.{
        .root_source_file = b.path("src/wheel.zig"),
        .target = target,
        .optimize = optimize,
    });
    wheel_mod.addImport("config", config_mod);
    wheel_mod.addImport("platform", platform_mod);

    // Create command modules
    const new_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/commands/new.zig"),
        .target = target,
        .optimize = optimize,
    });

    const develop_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/commands/develop.zig"),
        .target = target,
        .optimize = optimize,
    });
    develop_cmd_mod.addImport("config", config_mod);
    develop_cmd_mod.addImport("platform", platform_mod);
    develop_cmd_mod.addImport("generator", generator_mod);
    develop_cmd_mod.addImport("builder", builder_mod);

    const build_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/commands/build.zig"),
        .target = target,
        .optimize = optimize,
    });
    build_cmd_mod.addImport("config", config_mod);
    build_cmd_mod.addImport("platform", platform_mod);
    build_cmd_mod.addImport("generator", generator_mod);
    build_cmd_mod.addImport("builder", builder_mod);
    build_cmd_mod.addImport("wheel", wheel_mod);

    const publish_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/commands/publish.zig"),
        .target = target,
        .optimize = optimize,
    });
    publish_cmd_mod.addImport("config", config_mod);
    publish_cmd_mod.addImport("build_cmd", build_cmd_mod);

    // Build the zigx executable - main module imports commands
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("config", config_mod);
    exe_mod.addImport("platform", platform_mod);
    exe_mod.addImport("new_cmd", new_cmd_mod);
    exe_mod.addImport("develop_cmd", develop_cmd_mod);
    exe_mod.addImport("build_cmd", build_cmd_mod);
    exe_mod.addImport("publish_cmd", publish_cmd_mod);

    const exe = b.addExecutable(.{
        .name = "zigx",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the ZigX CLI");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("config", config_mod);
    test_mod.addImport("platform", platform_mod);
    test_mod.addImport("new_cmd", new_cmd_mod);
    test_mod.addImport("develop_cmd", develop_cmd_mod);
    test_mod.addImport("build_cmd", build_cmd_mod);
    test_mod.addImport("publish_cmd", publish_cmd_mod);

    const main_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_main_tests.step);
}
