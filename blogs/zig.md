# Zig - the prologue

In the world of graphics API's you are basically bound to use either C, C++ or other systems languages with bindings to the underlying C and C++ libraries. Given that Vulkan's canonical API is a C API there is merit in choosing C as the language for writing our Vulkan renderer -- This would be my stance on many things, however there are more ergonomic languages available nowadays and while C has a soft spot in my heart as the second programming language that I ever learnt, the options for us were really between Rust, C++ and Zig (Not all the options, but the ones I will discuss). In the case of Rust, I have had some experience in writing it and in general when trying to use C API's you were bound to manually create bindings or pull somebody else's possibly broken bindings, so this option was discarded. In the case of C++, I have a personal disdain for the exorbitant feature set and unpleasant foot guns. At this point you may think that I am too indecisive that the language shouldn't be this much of a concern; though I anticipated quite a lot of code to be written, so such investigation was a matter of sanity maintenance.

Anyhow I had some experience using another systems programming language, Zig. In fact Zig seemed to quench my thirst for native API access with a more ergonomic feature set than C, you see Zig allows you to translate C headers to Zig modules with the use of builtin functions `@cInclude` and `@cImport` which provides essentially first class C API support, allowing you to just use Vulkan functions under and "c" namespace:

```zig
const c = @cImport({
  @cInclude("vulkan/vulkan.h")
});
```

This was the killer feature that finalized the decision and cemented a template project that would hopefully blossom.

# Zig - the honeymoon

Overall Zig has been quite nice to use when compared to C and it feels like a worthy predecessor. While Zig does push memory management to the programmer like C and C++ the use of abstract allocators and `defer` make the sacrifice of possible leaks and other memory errors more compelling, for example you can create a arraylist that will free outside the block like so:

```zig
{
  var list = std.ArrayList(usize).init(allocator);
  defer list.deinit();

  inline for (0..10) |n| {
      try list.append(n);
  }
}
// Array list is freed
```

Another thing you may notice here is the `inline`, this is part of a broader topic in Zig - comptime. Comptime represents code that is run at compile time (think meta-programming) - type constraints, generics and much more. Inline basically allows multi line code generation, it will unravel the loop so long as the range is "comptime" known. This still may seem a bit unclear, hopefully a code snippet from the renderer that exploits the deepest of meta-programming - type construction:

```zig
// A entirely "compile time map", often we want to create maps that are completely comptime. In zig
// We can do this by constructing a type with the keys as fields
pub fn Map(comptime keys: []const []const u8, comptime V: type) type {
    var fields: [keys.len]t.StructField = undefined;

    for (keys, 0..) |key, i| {
        fields[i] = t.StructField{
            .name = key,
            .type = V,
            .default_value = null,
            .is_comptime = false,
            .alignment = 16,
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}
...
// How you use it
Map(&.{"x", "y", "z"}, usize)
```

This is "0-overhead" as it is simply a struct, no hashing involved ! The only caveat is that you need to declare all the fields you need at comptime - in fact this limitation is irrelevant to how it is used in the renderer; as a map template for [X atoms](https://man.archlinux.org/man/xcb_intern_atom.3.en) which will be filled at runtime by calling `xcb_intern_atom`.

# Zig - the postmortem

After using Zig for a decent sized project (the renderer), there have been a few take aways. Firstly Zig is not really "production" ready; I encountered compiler bugs throughout development, which wasted at some times hours of my time. Compiler bugs are rare but you eventually learn to recognise them as you become more familiar with the language. One such bug was more of a coincidence of Zig's comptime and C libraries love for `void *`, you can find the issue I made [here](https://github.com/ziglang/zig/issues/18522); it is essentially a problem of `void *` type erasing a comptime array meaning the compiler does not make the array available at runtime, ultimately causing a segmentation fault.

Secondly is in regard to translate-c, while not final in the renderer, I was using [tinyobjloader-c](https://github.com/syoyo/tinyobjloader-c) by translating the header with Zig's translate-c. It was then that I found out about "translate-c"'s incompleteness, forcing me to rewrite some of the functions of the library from scratch in Zig. Again a small gripe, but its just another one on the pile.

Thirdly, and most unfortunately is the cryptic compile time errors. Part of programming in Zig at its current stage is familiarizing yourself with the actual standard library source code, as if you didn't you would not be able to understand the side effects of misusing certain functions. While the standard library is very well written, it is dotted with `assert` statements and `@compileError`, which both leave no trace to the root source code - meaning that when raised the actual source of the error is lost. This fact is of Zig is miserable, and in the renderer I came accustomed to a very particular error in the `std.mem.zeroInit` function. This function seems innocent at first glance, it allows you to initialize a type while default zeroing any unset fields. The problem presents itself however when you assign a field to the wrong type, for example:

```zig
const std = @import("std");

const PointE = enum { X, Y };
const Point = struct {
    x: usize,
    y: usize,
};

pub fn main() void {
    const point = std.mem.zeroInit(Point, .{
        .x = .X,
        .y = .Y,
    });
    std.debug.print("{}\n", .{point});
}
```

This code when run produces the following error:

```
/home/cathal/.local/bin/zig-linux-x86_64-0.11.0/lib/std/mem.zig:456:65: error: expected type 'usize', found '@TypeOf(.enum_literal)'
                                    @field(value, field.name) = @field(init, field.name);
                                                                ^~~~~~~~~~~~~~~~~~~~~~~~
```

Which to an untrained eye seems strange, what is `@field` ? you may ask; it is basically part of the meta-programming I praised in "Zig - the honeymoon". Basically the root of the issue is that `std.mem.zeroInit` is run entirely at comptime so no trace in the root source code is made. The `@field` business is just raising a comptime error when `std.mem.zeroInit` enumerates the `Point` argument against the anonymous struct literal argument `.{ .x = .X, .y = .Y }` and finds that there is a type mismatch. This problem was really annoying in a >3000 lines of code project as I would have to remember what I was changing to find the source of the problem or enjoy another focused read of the codebase.

Lastly I will just say that there were many other issues like a poor and buggy language server, buggy debugger support (lldb) as well as a lack of language level support for dynamic-dispatch (interface virtual tables need to be manually created by the programmer). And while all of the issues I have covered seem like too much work, I am still very happy I used Zig for the renderer as it made me fine tune my debugging skills and also thought me about dynamic-dispatch, unique allocation methods and how simple models of meta-programming can enable a strict but flexible type system with macroless meta-programming.

Another important thing to note is that Zig is not even version 1.0 yet and a lot of these issues are derived from its infancy, I am hopeful for the languages future and at the end of the day at least it tells me when I get a memory leak :).
