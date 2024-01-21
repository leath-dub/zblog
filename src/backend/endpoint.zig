const std = @import("std");
const zap = @import("zap");
const vars = @import("main.zig").vars;

const Mustache = zap.Mustache;
pub const Self = @This();

const meta = std.meta;
const static = @import("static");

ep: zap.Endpoint = undefined,
content: []const u8,

pub fn init(
    path: []const u8,
    content: []const u8,
) Self {
    return .{
        .ep = zap.Endpoint.init(.{
            .path = path,
            .get = get,
        }),
        .content = content,
    };
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

pub const Ext = enum {
    @".css",
    @".csv",
    @".html",
    @".js",
    @".txt",
    @".xml",
};

fn get(e: *zap.Endpoint, r: zap.Request) void {
    const self = @fieldParentPtr(Self, "ep", e);

    // Set content type, if no extension assume html
    const ext = std.fs.path.extension(self.ep.settings.path);
    const extn = meta.stringToEnum(Ext, ext) orelse .@".html";
    const content_type = switch (extn) {
        .@".css" => "text/css",
        .@".csv" => "text/csv",
        .@".html" => "text/html",
        .@".js" => "text/javascript",
        .@".txt" => "text/plain",
        .@".xml" => "text/xml",
    };
    r.setHeader("content-type", content_type) catch return;

    var mustache = Mustache.fromData(self.content) catch return;
    defer mustache.deinit();

    const ret = mustache.build(vars);
    defer ret.deinit();

    if (ret.str()) |str| {
        r.sendBody(str) catch return;
    } else {
        r.sendBody("<html><body><h1>mustacheBuild() failed!</h1></body></html>") catch return;
    }
}
