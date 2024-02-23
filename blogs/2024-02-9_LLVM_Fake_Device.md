<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

# Llvm pipe device

Hi, Cathal here.

After switching to fedora I came across the beloved "llvmpipe" software vulkan implementation. Funnily enough my device ranking system took this device over a actual hardware device because it literally had better support. The fix fortunately was simple just look for the device named "llvmpipe" and add a serious decrease in score.

```zig
// llvmpipe is a software implementation of vulkan so we really ought to put the score down
if (std.mem.containsAtLeast(u8, &dev_props.deviceName, 1, "llvmpipe")) {
    score -= 10000;
}
```
