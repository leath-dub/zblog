<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

# The core renderer setup

For the purposes of the project a very simple rendering system was in needed. The solution I landed on was a hybrid game object and ecs render system, each object you attach to a `Scene` which stores a `MultiArrayList` of the fields in a `Model` -- A multi arraylist rather than storing a array of structs, stores multiple arrays of the given struct's fields, this reduces wasted padding memory from the former approach aswell as making iteration of single fields more cacheable as memory is not jumped as large an offset at each iteration.

To create a object in the scene you call the `register` function which crucially takes a path to the file of the model you want to load. This function just returns a 0 based index into the `MultiArrayList` of objects in the scene. After you register a model you can attach transformations to the model using the `addTransform` function which will take each matrix as a different instance of the model, this allows you to render multiple objects of the same model in different places while sharing the vertex and index buffer. This multiple object "instancing" is facilitated by the `instanceCount` parameter to `vkCmdDrawIndexed`:

```zig
c.vkCmdDrawIndexed(buffer, @intCast(self.scene.objects.items(.index_buffer)[oi].size / @sizeOf(u32)), @intCast(transforms.len), 0, 0, 0);
```

Then in the vertex shader we can access the model transform like so:

```glsl
mat4 model = models_buffer.models[push.model_offset + gl_InstanceIndex];
```

# Textures

Just finished my implementation of multiple textures for the renderer. In general I was surprised by the nuance of implementing textures in vulkan, many solution paths that I went down involved bindless support which my development machine did not support and aside from that working with descriptor sets can get a bit messy and confusing.

First off I'll show the relevant pieces of the fragment shader:

```glsl
const uint max_textures = 32;

layout(binding = 1) uniform sampler sampler_;
layout(set = 2, binding = 0) uniform texture2D texture_[max_textures];
```

Then you just use a push constant to specify the index into the texture array in the fragment shader:

```glsl
layout(push_constant) uniform Push {
    layout(offset = 4) uint texture_offset;
} push;
```

The offset here is because we have another push constant in the vertex shader that specifies the model index. As you can already see from the first code snippet there is an unfortunate constant declaration of the maximum textures we are storing, this also needs to be put in our main zig code as well:

```zig
// @ src/texture.zig
pub const max_textures = 32;
```

Nonetheless this solution is not uncommon especially for low extension support devices, such as my development machine (Thinkpad x230). While I could have pulled out one of my newer devices that support `descriptorBindingPartiallyBound` and `runtimeDescriptorArray` (see [this](https://jorenjoestar.github.io/post/vulkan_bindless_texture/) for details) I thought it better to just run with a more compatible solution that is also quite simple and easy to reason about. Anyhow the renderer uses a single descriptor pool so its instanciation involved adding a new pool size to store frame number of texture arrays as well as a single sampler.

```zig
self.descriptor_sets = try DescriptorSets.init(allocator, self.device.logical, &.{
    c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .descriptorCount = frames_in_flight },
    c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLER, .descriptorCount = frames_in_flight },
    c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, .descriptorCount = frames_in_flight * max_textures }, // +Here
    c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = frames_in_flight * max_objects },
}, frames_in_flight + frames_in_flight * max_objects + frames_in_flight * max_objects);
```

With that it was a matter of simply adding a new function to allow you to attach textures to objects in the scene:

```zig
pub fn addTexture(scene: *@This(), device: *const Device, model_idx: usize, path: []const u8, pool: *const DescriptorSets, factory: *const CommandBufferFactory) !void {
    if (scene.textures_index == scene.textures.len) {
        log.warn("Ran out of textures", .{});
        return;
    }

    scene.objects.items(.texture_index)[model_idx] = scene.textures_index;
    const texture = try Tex.init(scene.allocator, device, path, factory);
    scene.textures[scene.textures_index] = texture;
    const texture_infos = Tex.getImageInfos(texture.handle.view, 1);

    for (scene.texture_descriptor_sets.realise(pool.descriptor_sets.items)) |set| {
        var texture_write = std.mem.zeroInit(c.VkWriteDescriptorSet, .{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = set,
            .dstArrayElement = @as(u32, @intCast(scene.textures_index)),
            .descriptorCount = 1,
            .dstBinding = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
            .pImageInfo = &texture_infos,
        });

        c.vkUpdateDescriptorSets(device.logical, 1, &texture_write, 0, null);
    }

    scene.textures_index += 1;
}
```

This just uses the descriptor sets from the "view" `texture_descriptor_sets`, The `realise` is a method that takes a actual reference and gets a pointer slice into the memory based on the offset and length in the "view" - this is done because the underlying data array in `pool.descriptor_sets` is dynamic and its reference can change when a resize is needed. The descriptor sets are written to with the texture initialized by the passed path.


# Llvm pipe device

After switching to fedora I came across the beloved "llvmpipe" software vulkan implementation. Funnily enough my device ranking system took this device over a actual hardware device because it literally had better support. The fix fortunately was simple just look for the device named "llvmpipe" and add a serious decrease in score.

```zig
// llvmpipe is a software implementation of vulkan so we really ought to put the score down
if (std.mem.containsAtLeast(u8, &dev_props.deviceName, 1, "llvmpipe")) {
    score -= 10000;
}
```

## Declarative scene definition

In trying to make the renderer more flexible at runtime you can define the scene in JSON, e.g:

```json
{
  "scene": {
    "ambient_light": [1, 1, 1, 0.2],
    "objects": [
      {
        "model": { "name": "./plane.obj" }
      },
      {
        "model": { "name": "./sphere.obj" },
        "instances": [[{"translation": [10, -40, 15]}, {"scaling": [0.1, 0.1, 0.1]}]], 
        "light": { "color": [1, 1, 1, 1] }
      },
      {
        "model": {
          "lod": {
            "final_clamp": 100,
            "lods": ["monkey/monkey0.obj", "monkey/monkey1.obj", "monkey/monkey2.obj", "monkey/monkey3.obj", "monkey/monkey4.obj"]
          }
        },
        "texture": "monkey/monkey.ff",
        "instances": [[{"rotationX": 180}, {"translation": [1, 1, 1]}]]
      }
    ]
  }
}
```

While this approach is maybe not scalable to making a game, it is perfect for our use case in testing our algorithm in reasonably complex scenes.

