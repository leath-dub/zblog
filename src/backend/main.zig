const zap = @import("zap");
const std = @import("std");

const static = @import("static.zig");
pub const vars = static.StaticVars(){};

const Mustache = zap.Mustache;

const index = result: {
    if (@hasField(static.StaticVars(), "index.html")) {
        break :result @embedFile(vars.@"index.html");
    } else break :result 
    \\ <h1>
    \\ Set "index.html" variable e.g.:
    \\ <pre>
    \\   <code>
    \\   .@"index.html" = .{
    \\       .type = .html,
    \\       .path = "index.html",
    \\       .hash_path = false,
    \\   },
    \\   </code>
    \\ </pre>
    ;
};

fn on_request(r: zap.Request) void {
    r.setContentType(.HTML) catch return;
    var mustache = Mustache.fromData(index) catch return;
    defer mustache.deinit();

    const ret = mustache.build(vars);
    defer ret.deinit();

    if (ret.str()) |str| {
        r.sendBody(str) catch return;
    } else {
        r.sendBody("<html><body><h1>mustacheBuild() failed!</h1></body></html>") catch return;
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var listener = zap.Endpoint.Listener.init(allocator, .{
        .port = 3000,
        .on_request = on_request,
        .log = true,
        .max_clients = 100000,
        .max_body_size = 100 * 1024 * 1024,
    });
    defer listener.deinit();

    const eps = try static.setupEndpoints(allocator);
    defer allocator.free(eps);

    for (eps) |*ep| {
        try listener.register(ep.endpoint());
    }

    try listener.listen();

    zap.start(.{
        .threads = 16,
        .workers = 1,
    });
}
