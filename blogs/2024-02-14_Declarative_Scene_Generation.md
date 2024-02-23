<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

# Declarative scene definition

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
