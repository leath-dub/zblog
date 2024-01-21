const std = @import("std");
const MarkdownParser = @import("markdown_parser.zig");

const string_literal = std.zig.string_literal;

const File = std.fs.File;
const Ast = std.zig.Ast;
const Index = std.zig.Ast.Node.Index;
const Allocator = std.mem.Allocator;
const Build = std.Build;
const LazyPath = Build.LazyPath;
const Shake256 = std.crypto.hash.sha3.Shake256;
const Base64Encoder = std.base64.Base64Encoder;
const ArrayList = std.ArrayList;

const meta = std.meta;
const mem = std.mem;
const log = std.log;
const fs = std.fs;
const heap = std.heap;

pub const StaticEndpoint = struct {
    name: []const u8,
    data: LazyPath,
};

const encoder = Base64Encoder.init(std.base64.standard_alphabet_chars, null);
const hash_length: usize = 32;
const Hash = [encoder.calcSize(hash_length) + 1]u8;

inline fn hash(name: []const u8) Hash {
    var result: Hash = undefined;

    @setEvalBranchQuota(100000);

    var shake256 = Shake256.init(.{});
    var bytes: [hash_length]u8 = undefined;

    shake256.update(name);
    shake256.final(&bytes);

    result[0] = '/';
    _ = encoder.encode(result[1..], &bytes);

    return result;
}

pub const StaticFile = struct {
    pub const Type = enum {
        markdown,
        css,
        csv,
        html,
        js,
        txt,
        xml,
    };

    type: Type = .markdown,
    path: []const u8,
    hash_path: bool = true,

    pub fn resolve(self: *const @This(), b: *Build, md2html: *MarkdownParser) ![]StaticEndpoint {
        const stat = fs.cwd().statFile(self.path) catch {
            log.err("File or directory `{s}` does not exist", .{self.path});
            @panic("File not found");
        };

        var paths = ArrayList(StaticEndpoint).init(b.allocator);
        var wt = b.addWriteFiles();

        switch (stat.kind) {
            .directory => {
                var open_dir = try fs.cwd().openIterableDir(self.path, .{});
                defer open_dir.close();

                var walk = open_dir.iterate();
                while (try walk.next()) |entry| {
                    if (entry.kind == .directory) continue;

                    var dest = try fs.path.join(b.allocator, &.{ self.path, entry.name });
                    var dest_lp = wt.addCopyFile(.{ .path = dest }, dest);

                    if (self.type == .markdown) {
                        dest_lp = md2html.toHtml(dest_lp);
                    }

                    var name = if (dest[0] == '/') dest else b.fmt("/{s}", .{dest});

                    if (self.hash_path) {
                        name = b.dupe(&hash(name));
                    }

                    try paths.append(.{
                        .name = name,
                        .data = dest_lp,
                    });
                }
            },
            .file => {
                var dest = self.path;
                var dest_lp = wt.addCopyFile(.{ .path = dest }, dest);

                if (self.type == .markdown) {
                    dest_lp = md2html.toHtml(dest_lp);
                }

                var name = if (dest[0] == '/') dest else b.fmt("/{s}", .{dest});

                if (self.hash_path) {
                    name = b.dupe(&hash(name));
                }

                try paths.append(.{
                    .name = name,
                    .data = dest_lp,
                });
            },
            else => {},
        }

        return paths.toOwnedSlice();
    }
};

pub const Field = struct {
    key: []const u8,
    value: union(enum) {
        str: []const u8,
        file: StaticFile,
    },
};

const Self = @This();

arena: heap.ArenaAllocator,
fields: []Field,

pub fn init(child_allocator: Allocator, zon_file_path: []const u8) !Self {
    var arena = heap.ArenaAllocator.init(child_allocator);
    const allocator = arena.allocator();

    const zon_file = try fs.cwd().openFile(zon_file_path, .{});
    defer zon_file.close();

    const fields = try parse(allocator, zon_file);

    return .{
        .arena = arena,
        .fields = fields,
    };
}

pub fn parse(allocator: Allocator, zon: File) ![]Field {
    const content = try allocator.allocSentinel(u8, try zon.getEndPos(), 0);
    _ = try zon.reader().readAll(content);

    var ast = try Ast.parse(allocator, content, .zon);
    defer ast.deinit(allocator);

    var buf: [2]Index = undefined;
    const root_init = ast.fullStructInit(&buf, ast.nodes.items(.data)[0].lhs) orelse {
        log.err("The zon file was not a struct", .{});
        return error.ParseError;
    };

    var fields = std.ArrayList(Field).init(allocator);

    for (root_init.ast.fields) |fi| {
        var kv: Field = undefined;

        kv.key = try parseFieldName(allocator, ast, fi);

        const root_class = ast.nodes.items(.tag)[fi];
        switch (root_class) {
            .struct_init_dot, .struct_init_dot_two, .struct_init_dot_two_comma, .struct_init_dot_comma => {
                const file_init = ast.fullStructInit(&buf, fi) orelse unreachable;
                var file: StaticFile = undefined;

                for (file_init.ast.fields) |sfi| {
                    const field_name = try parseFieldName(allocator, ast, sfi);
                    defer allocator.free(field_name);

                    if (mem.eql(u8, field_name, "type")) {
                        switch (ast.nodes.items(.tag)[sfi]) {
                            .enum_literal => {
                                const raw = ast.tokenSlice(ast.nodes.items(.main_token)[sfi]);
                                const tag = meta.stringToEnum(StaticFile.Type, raw) orelse {
                                    log.err("Unknown enum literal `{s}`", .{raw});
                                    return error.ParseError;
                                };
                                file.type = tag;
                            },
                            else => {
                                log.err("Parent struct named `{s}`'s `path` field must be a enum literal representing the type of the file", .{kv.key});
                                return error.ParseError;
                            },
                        }
                        continue;
                    }

                    if (mem.eql(u8, field_name, "path")) {
                        switch (ast.nodes.items(.tag)[sfi]) {
                            .string_literal => {
                                const raw = ast.tokenSlice(ast.nodes.items(.main_token)[sfi]);

                                var str = std.ArrayList(u8).init(allocator);
                                const result = try string_literal.parseWrite(str.writer(), raw);
                                if (result == .failure) {
                                    log.err("Failed parsing string literal value of field `{s}`", .{field_name});
                                    return error.ParseError;
                                }
                                file.path = try str.toOwnedSlice();
                            },
                            else => {
                                log.err("Parent struct named `{s}`'s `path` field must be a string literal representing a path to a file or directory", .{kv.key});
                                return error.ParseError;
                            },
                        }
                        continue;
                    }

                    if (mem.eql(u8, field_name, "hash_path")) {
                        const raw = ast.tokenSlice(ast.nodes.items(.main_token)[sfi]);
                        if (mem.eql(u8, raw, "true")) {
                            file.hash_path = true;
                            continue;
                        }

                        if (mem.eql(u8, raw, "false")) {
                            file.hash_path = false;
                            continue;
                        }

                        log.err("Field `hash_path` must have type of boolean ('true' or 'false')", .{});
                        return error.ParseError;
                    }

                    log.err("Parent struct named `{s}` has unknown field name `{s}`", .{ kv.key, field_name });
                    return error.ParseError;
                }

                kv.value = .{
                    .file = file,
                };
            },
            .string_literal => {
                var str = std.ArrayList(u8).init(allocator);
                const result = try string_literal.parseWrite(str.writer(), ast.tokenSlice(ast.nodes.items(.main_token)[fi]));
                if (result == .failure) {
                    log.err("Failed parsing string literal value of field `{s}`", .{kv.key});
                    return error.ParseError;
                }
                kv.value = .{ .str = try str.toOwnedSlice() };
            },
            else => {
                log.err("Top level field name `{s}` can either be a struct or a string literal, however it has type `{}`", .{ kv.key, root_class });
                return error.ParseError;
            },
        }

        try fields.append(kv);
    }

    return fields.toOwnedSlice();
}

pub fn deinit(self: *const Self) void {
    self.arena.deinit();
}

fn parseFieldName(alloc: Allocator, ast: Ast, idx: Index) ![]const u8 {
    const name = ast.tokenSlice(ast.firstToken(idx) - 2);
    return if (name[0] == '@') string_literal.parseAlloc(alloc, name[1..]) else name;
}
