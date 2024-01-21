const std = @import("std");
const io = std.io;
const mem = std.mem;
const Thread = std.Thread;
const md = @import("md4c");

const Self = @This();
const Writer = std.fs.File.Writer;

fn callback(input_raw: [*c]const u8, input_size: c_uint, userdata: ?*anyopaque) callconv(.C) void {
    if (input_raw == null) return;

    const html: *Writer = @ptrCast(@alignCast(userdata));
    html.writeAll(@as([*]const u8, @ptrCast(input_raw))[0..input_size]) catch unreachable;
}

fn mdToHtml(markdown: []const u8, context: *Writer) !void {
    if (md.md_html(markdown.ptr, @intCast(markdown.len), callback, @ptrCast(context), 0, 0) == -1) {
        return (error{ParseError}).ParseError;
    }
}

pub fn yield(markdown: []const u8, writer: *Writer) !void {
    try mdToHtml(markdown, writer);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer switch (gpa.deinit()) {
        .ok => {},
        .leak => std.log.err("Memory Leak detected", .{}),
    };
    const allocator = gpa.allocator();

    var args = std.process.args();
    var stdout = std.io.getStdOut().writer();
    _ = args.next();

    while (args.next()) |arg| {
        const fname = try std.fs.cwd().readFileAlloc(allocator, arg, std.math.maxInt(u32));
        defer allocator.free(fname);
        try yield(fname, &stdout);
    }
}
