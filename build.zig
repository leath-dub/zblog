const std = @import("std");
const Site = @import("src/generator/site.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zblog",
        .root_source_file = .{ .path = "src/backend/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const site = try Site.init(b, "vars.zon", exe);
    defer site.deinit();

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });
    exe.addModule("zap", zap.module("zap"));
    exe.linkLibrary(zap.artifact("facil.io"));

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
