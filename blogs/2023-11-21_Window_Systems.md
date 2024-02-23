<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

# Window Systems and Input

Hi, Cathal here.

## Window Systems

I just finished replacing my old mouse input logic with a much simpler though less conventional approach and I think It is a good time to talk about _Window Systems_ and _handling user input_.

When making a game engine (renderer) handling windows is a must as the graphics API needs to have a surface that it can draw on. Initially I was using glfw to handle window and surface creation which worked however it raised a weird libc missing symbol error on de-initialisation. After not finding a solution to the problem I just ignored it so as not to stunt development momentum, however it finally wore we down enough to strip out glfw entirely.

A big reason for removing glfw is that I already had experience with Xcb, which is a near direct mapping of the x11 protocol. The x11 protocol is the most common Window System protocol in use in Linux. But what is a _Window System_ ? - a Window System is simply something that handles the primitive operations on windows, e.g. creation, deletion, resize, move, etc. On top of providing functions that apply to windows on your desktop, Window Systems usually also provide input channels that all applications to read user input through the Window System API.

After removing glfw I put in place calls to Xcb. The new code was much lower level and also didn't raise the libc trace errors ! The fact that this fixed the errors re-enforces my suspicion of there being a glfw bug at play. Though I wish I could have got glfw working as it would have been easier to port to other platforms should we extend our NFR's, either way Xcb was working and it was also a smaller dependency to pull !

## Input

When I got to implementing camera movement, I had to interact with Xcb a bit more and I stumbled across a slight issue with Mouse input - Xcb only provides absolute mouse positioning. Absolute mouse positioning isn't much use in a game engine as you need to know where the mouse is going, not where it is ! This was solved by just storing the previous mouse position and computing the difference.

The big problem with this was that I also had to use a hack to get "infinite" mouse movement. If the mouse cursor reached the edge of the window I had to warp the cursor back to the center of the window and drop the latest mouse event. Though the even bigger problem was that the mouse position data I was receiving on some Linux desktop environments had negative positions (likely a bug) and on others the mouse would not reach the absolute bounds of the window (likely also a bug) when you confined it to the window. This bigger problem made the former problem of when to warp the cursor pretty much unsolvable. This issue was very surprising to me and I decided to look elsewhere for reading mouse input (keyboard input was working fine). 

After some research, I found that many of the other libraries that produces relative mouse positioning also have their own window handles and I didn't want to get into sharing the handle between Xcb and another library on top of Vulkan. This brought me to the other idea of just reading the mouse input from the kernel directly, this had the following benefits:

* Lowest overhead
* Zero dependencies
* By default produces relative mouse positioning so no window bounds madness

The only downside was that now the engine needed to be run as root or a user in the `input` group, a reasonable tradeoff to the lovely benefits. That brings us to our less conventional approach, reading directly from the kernel in a separate thread that reads `relx` and `rely` which can them be returned and reset when the main thread reads the mouse input in the frame. This is a bufferless solution too, events are just keeping running totals for `relx` and `rely` until the `reset` is called ! all you need is a `RwLock` when writing or reading from the `relx` and `rely`.

For those that are interested, the code came out to be quite tidy and quite simple - much simpler than translating absolute positions and handling the bug edge cases :).

```zig
const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const heap = std.heap;

const File = fs.File;
const ReadError = fs.File.ReadError;
const Thread = std.Thread;
const RwLock = Thread.RwLock;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = mem.Allocator;

const c = @cImport({
    @cInclude("linux/input.h");
});

pub const device_path = "/dev/input/mice";

const Event = packed struct {
    button_mask: u8 = 0,
    relx: i8 = 0,
    rely: i8 = 0,
};

allocator: Allocator,
device: File,

thread: Thread,
lock: RwLock,
relx: f32,
rely: f32,

pub fn listen(allocator: Allocator) !*@This() {
    const device = try fs.openFileAbsolute(device_path, .{ .mode = .read_only });

    var ptr = try allocator.create(@This());
    ptr.* = .{
        .allocator = allocator,
        .device = device,

        .thread = try Thread.spawn(.{}, threadFn, .{ptr}),
        .lock = .{},
        .relx = 0,
        .rely = 0,
    };

    return ptr;
}

pub const Reading = struct {
    relx: f32 = 0,
    rely: f32 = 0,
};

pub inline fn reset(context: *@This()) Reading {
    context.lock.lock();

    const reading = .{
        .relx = context.relx,
        .rely = context.rely,
    };

    context.relx = 0;
    context.rely = 0;

    context.lock.unlock();

    return reading;
}

pub fn stop(context: *@This()) void {
    context.thread.detach();
    context.device.close();
    context.allocator.destroy(context);
}

fn threadFn(context: *@This()) !void {
    var event: Event = undefined;
    const bytes = mem.asBytes(&event);

    var read = try context.device.read(bytes);
    while (read != 0) : (read = try context.device.read(bytes)) {
        context.lock.lock();
        context.relx += @as(f32, @floatFromInt(event.relx));
        context.rely += @as(f32, @floatFromInt(event.rely));
        context.lock.unlock();
    }
}
```
