const std = @import("std");

const Build = std.Build;
const Compile = Build.Step.Compile;
const ArrayList = std.ArrayList;
const InputVars = @import("vars_parser.zig");
const MarkdownParser = @import("markdown_parser.zig");
const Self = @This();

fn Var(comptime V: type) type {
    return struct {
        name: []const u8,
        value: V,
    };
}

vars: InputVars,

pub fn init(b: *Build, vars_file_path: []const u8, on: *Compile) !Self {
    const in_vars = try InputVars.init(b.allocator, vars_file_path);
    var parser = MarkdownParser.init(b);

    const field_names = b.addOptions();

    for (in_vars.fields) |field| {
        if (field.value == .file) {
            const eps = try field.value.file.resolve(b, &parser);

            var ep_names = ArrayList([]const u8).init(b.allocator);

            for (eps) |ep| {
                on.addModule(ep.name, b.createModule(.{
                    .source_file = ep.data,
                }));
                try ep_names.append(ep.name);
            }

            field_names.addOption([]const []const u8, field.key, try ep_names.toOwnedSlice());
        } else {
            field_names.addOption([]const u8, field.key, field.value.str);
        }
    }

    on.addOptions("field-names", field_names);

    return .{
        .vars = in_vars,
    };
}

pub fn deinit(self: *const Self) void {
    self.vars.deinit();
}
