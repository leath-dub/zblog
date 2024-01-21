const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "md4c-lib",
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.addIncludePath(.{ .path = "src/" });
    lib.addCSourceFiles(&.{
        "src/md4c-html.c",
        "src/md4c.c",
        "src/entity.c",
    }, &.{});

    const md4c_html_bindings = b.addTranslateC(.{
        .source_file = .{ .path = "src/md4c-html.h" },
        .target = target,
        .optimize = optimize,
    });

    // try b.modules.put("md4c-html", md4c_html_bindings.createModule());

    const exe = b.addExecutable(.{
        .name = "md4c",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("md4c", md4c_html_bindings.createModule());
    exe.linkLibrary(lib);

    b.installArtifact(lib);
    b.installArtifact(exe);
}
