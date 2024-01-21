const std = @import("std");
const fields_names = @import("field-names");
const Ep = @import("endpoint.zig");

const Type = std.builtin.Type;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Mustache = @import("zap").Mustache;

const meta = std.meta;
pub const svars = StaticVars(){};

pub fn setupEndpoints(allocator: Allocator) ![]Ep {
    const decls = comptime meta.declarations(fields_names);
    var eps = ArrayList(Ep).init(allocator);

    inline for (decls) |decl| {
        const val = @field(fields_names, decl.name);
        if (@TypeOf(val) != []const u8) { // normal variable
            if (val.len == 1) { // []const u8
                const data = @embedFile(val[0]);
                try eps.append(Ep.init(val[0], data));
            } else {
                inline for (val) |epn| {
                    const data = @embedFile(epn);
                    try eps.append(Ep.init(epn, data));
                }
            }
        }
    }

    return eps.toOwnedSlice();
}

pub fn StaticVars() type {
    const decls = comptime meta.declarations(fields_names);
    var vars: [decls.len]Type.StructField = undefined;

    inline for (decls, 0..) |decl, i| {
        const val = @field(fields_names, decl.name);
        if (@TypeOf(val) == []const u8) { // normal variable
            vars[i] = .{
                .name = decl.name,
                .type = []const u8,
                .default_value = @ptrCast(&val),
                .is_comptime = false,
                .alignment = 1,
            };
        } else { // 1 or more endpoints attached to variable name
            if (val.len == 1) { // []const u8
                vars[i] = .{
                    .name = decl.name,
                    .type = []const u8,
                    .default_value = @ptrCast(&val[0]),
                    .is_comptime = false,
                    .alignment = 1,
                };
            } else {
                const Elem = struct {
                    e: []const u8 = undefined,
                };

                var elems: [val.len]Elem = undefined;
                inline for (val, 0..) |ep, j| {
                    elems[j] = .{
                        .e = ep,
                    };
                }

                vars[i] = .{
                    .name = decl.name,
                    .type = @TypeOf(elems),
                    .default_value = &elems,
                    .is_comptime = false,
                    .alignment = 1,
                };
            }
        }
    }

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &vars,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}
