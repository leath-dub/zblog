const std = @import("std");

const Build = std.Build;
const Compile = Build.Step.Compile;
const Allocator = std.mem.Allocator;
const LazyPath = Build.LazyPath;
const Self = @This();

b: *Build,
cmd: *Compile,

pub fn init(b: *Build) Self {
    const md4c_dep = b.anonymousDependency("src/generator/libs/md4c", @import("libs/md4c/build.zig"), .{});
    var cmd = md4c_dep.artifact("md4c");

    return .{
        .b = b,
        .cmd = cmd,
    };
}

pub fn toHtml(self: *Self, md: LazyPath) LazyPath {
    const run = self.b.addRunArtifact(self.cmd);
    run.addFileArg(md);
    return run.captureStdOut();
}
